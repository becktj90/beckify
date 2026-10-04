import Accelerate
import AVFoundation
import Combine
import os
import SwiftUI
import UIKit
import BeckifyMath

@MainActor
final class BreathFluteModel: ObservableObject {
    @Published var rmsDBFS = SoundLevel.silenceFloorDBFS
    @Published var peakDBFS = SoundLevel.silenceFloorDBFS
    @Published var noiseFloor = SoundLevel.silenceFloorDBFS
    @Published var gateOpen = false
    @Published var frequencyHz = BreathFluteMath.rootHz
    @Published var permissionDenied = false
    @Published var running = false
    @Published var status = "Microphone idle"
    @Published var hasReading = false
    @Published var blowBands: [AcousticDisplayBand] = []
    @Published var micRoute = "Mic route pending"

    private let engine = AVAudioEngine()
    private let frameBuffer = AudioFrameBuffer()
    private var fftSetup: FFTSetup?
    private let synth = FluteSynth()
    private var source: AVAudioSourceNode?
    private var installed = false
    private var wantsRunning = false
    private var didSuspendSpectrum = false
    private var sampleRate = 44_100.0
    private var triedVoiceFallback = false
    /// Quiet-air samples collected before the gate may open.
    private var calibrationSamples: [Double] = []
    /// Nil until calibration finishes with a usable quiet floor.
    private var trackedFloor: Double?
    @Published var breathDBFS = SoundLevel.silenceFloorDBFS
    @Published var isCalibrating = true

    func start() {
        wantsRunning = true
        if !didSuspendSpectrum {
            MicrophoneSpectrumCenter.shared.suspendForTone()
            didSuspendSpectrum = true
        }
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self, self.wantsRunning else { return }
                if granted {
                    self.permissionDenied = false
                    self.beginEngine()
                } else {
                    self.permissionDenied = true
                    self.status = "Microphone permission denied"
                }
            }
        }
    }

    func stop() {
        wantsRunning = false
        running = false
        gateOpen = false
        synth.set(gate: false, hz: frequencyHz, amplitude: 0)
        status = "Microphone idle"
        if installed {
            engine.inputNode.removeTap(onBus: 0)
            installed = false
        }
        if engine.isRunning { engine.stop() }
        if let source {
            engine.detach(source)
            self.source = nil
        }
        frameBuffer.reset()
        if let fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
            self.fftSetup = nil
        }
        blowBands = []
        micRoute = "Mic route pending"
        triedVoiceFallback = false
        calibrationSamples = []
        trackedFloor = nil
        isCalibrating = true
        breathDBFS = SoundLevel.silenceFloorDBFS
        noiseFloor = SoundLevel.silenceFloorDBFS
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if didSuspendSpectrum {
            didSuspendSpectrum = false
            MicrophoneSpectrumCenter.shared.resumeAfterTone()
        }
    }

    func setFrequency(_ hz: Double) {
        guard hz.isFinite, hz > 0 else { return }
        frequencyHz = hz
        pushSynth()
    }

    private func beginEngine() {
        guard wantsRunning else { return }
        if running, installed {
            pushSynth()
            return
        }
        // Measurement first: voice-chat noise suppression treats a blow like wind and
        // can zero the mic. Breath gating uses high bands so the speaker sine does not
        // hold the gate. Voice-chat is only a boot fallback.
        let plan: SessionPlan = triedVoiceFallback ? .voiceChat : .measurement
        do {
            try boot(plan)
        } catch {
            tearDownPartial()
            if !plan.voiceProcessing, !triedVoiceFallback {
                triedVoiceFallback = true
                do {
                    try boot(.voiceChat)
                } catch {
                    reportStartFailure(error)
                }
            } else {
                reportStartFailure(error)
            }
        }
    }

    private func reportStartFailure(_ error: Error) {
        running = false
        if error is FluteAudioError {
            status = "No microphone format"
        } else {
            status = "Could not start audio: \(error.localizedDescription)"
        }
    }

    /// Measurement is preferred so a blow is not noise-suppressed. Voice chat is only
    /// a boot fallback. Neither mode is a calibration.
    private struct SessionPlan {
        var mode: AVAudioSession.Mode
        var voiceProcessing: Bool
        var echoLabel: String

        static let voiceChat = SessionPlan(mode: .voiceChat, voiceProcessing: true, echoLabel: "echo cancel on")
        static let measurement = SessionPlan(mode: .measurement, voiceProcessing: false, echoLabel: "echo cancel off")
    }

    private func boot(_ plan: SessionPlan) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: plan.mode, options: [.defaultToSpeaker, .mixWithOthers])
        try session.setActive(true)
        try? session.overrideOutputAudioPort(.speaker)
        let route = preferBottomBuiltInMic(session)
        let input = engine.inputNode
        var echoLabel = plan.echoLabel
        if plan.voiceProcessing {
            do {
                try input.setVoiceProcessingEnabled(true)
            } catch {
                echoLabel = "echo cancel unavailable"
            }
        } else {
            try? input.setVoiceProcessingEnabled(false)
        }
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            micRoute = route
            status = "No microphone format"
            running = false
            throw FluteAudioError.noFormat
        }
        sampleRate = format.sampleRate
        if installed {
            input.removeTap(onBus: 0)
            installed = false
        }
        if fftSetup == nil {
            fftSetup = AudioBlockFFT.makeSetup()
        }
        let setup = fftSetup
        let scratch = frameBuffer
        let rate = format.sampleRate
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let channel = buffer.floatChannelData?[0] else { return }
            let frames = Int(buffer.frameLength)
            guard frames > 0 else { return }
            let samples = Array(UnsafeBufferPointer(start: channel, count: frames))
            let levels = BreathFluteMath.levelDBFS(samples: samples)
            scratch.append(buffer)
            var bands: [AcousticDisplayBand]?
            if let setup, let frame = scratch.pop(count: AudioBlockFFT.length),
               let magnitudes = AudioBlockFFT.magnitudes(samples: frame, setup: setup) {
                bands = AcousticSpectrum.fold(
                    linearMagnitudes: magnitudes,
                    sampleRate: rate,
                    fftLength: AudioBlockFFT.length,
                    bandCount: 12
                )
            }
            Task { @MainActor in
                self?.apply(levels, bands: bands)
            }
        }
        installed = true
        if source == nil {
            // Play in the mixer/output format. Wiring the mic format into the mixer
            // can leave the tone silent on some routes after category changes.
            let mixerFormat = engine.mainMixerNode.outputFormat(forBus: 0)
            let playFormat = mixerFormat.sampleRate > 0 && mixerFormat.channelCount > 0 ? mixerFormat : format
            let playRate = playFormat.sampleRate
            let node = AVAudioSourceNode { [synth] _, _, frameCount, audioBufferList -> OSStatus in
                let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for buffer in buffers {
                    guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    synth.fill(data, frames: Int(frameCount), sampleRate: playRate)
                }
                return noErr
            }
            source = node
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: playFormat)
        }
        try engine.start()
        try? session.overrideOutputAudioPort(.speaker)
        running = true
        micRoute = route
        status = "Ready · \(echoLabel)"
        pushSynth()
    }

    /// Prefer the built-in mic at the bottom of the phone when iOS lists that data source.
    /// The string stays honest when the source is missing or the call fails.
    private func preferBottomBuiltInMic(_ session: AVAudioSession) -> String {
        guard let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) else {
            return "System input · no built-in mic listed"
        }
        do {
            try session.setPreferredInput(builtIn)
        } catch {
            return "System input · built-in mic not selected"
        }
        guard let bottom = builtIn.dataSources?.first(where: { $0.orientation == .bottom }) else {
            return "Built-in mic · no bottom source on this device"
        }
        do {
            try builtIn.setPreferredDataSource(bottom)
            // Nil means this source lists no pattern; skip rather than force one.
            if bottom.supportedPolarPatterns?.contains(.omnidirectional) == true {
                try bottom.setPreferredPolarPattern(.omnidirectional)
            }
            return "Built-in bottom mic"
        } catch {
            return "Built-in mic · bottom source listed, not selected"
        }
    }

    private func tearDownPartial() {
        if installed {
            engine.inputNode.removeTap(onBus: 0)
            installed = false
        }
        if engine.isRunning { engine.stop() }
        if let source {
            engine.detach(source)
            self.source = nil
        }
        running = false
        try? engine.inputNode.setVoiceProcessingEnabled(false)
    }

    private func apply(_ levels: (rms: Double, peak: Double), bands: [AcousticDisplayBand]?) {
        hasReading = true
        rmsDBFS = levels.rms
        peakDBFS = levels.peak
        if let bands {
            blowBands = bands
        }
        // Wait for an FFT block so the gate can ignore the speaker fundamental.
        guard let bands, !bands.isEmpty else {
            pushSynth()
            return
        }
        let breath = BreathFluteMath.breathLevelDBFS(bands: bands)
        breathDBFS = breath
        // Missing HF bands return digital silence — never seed the floor from that.
        guard BreathFluteMath.isUsableBreathLevel(breath) else {
            gateOpen = false
            pushSynth()
            return
        }

        if trackedFloor == nil {
            BreathFluteMath.appendCalibrationSample(breath, into: &calibrationSamples)
            if calibrationSamples.count >= BreathFluteMath.calibrationSampleCount,
               let seeded = BreathFluteMath.calibrationFloor(samples: calibrationSamples) {
                trackedFloor = seeded
                isCalibrating = false
            } else {
                isCalibrating = true
                noiseFloor = BreathFluteMath.calibrationFloor(samples: calibrationSamples) ?? breath
                gateOpen = false
                pushSynth()
                return
            }
        }

        trackedFloor = BreathFluteMath.updateNoiseFloor(currentDBFS: breath, floor: trackedFloor)
        let floor = trackedFloor ?? breath
        noiseFloor = floor
        let wasOpen = gateOpen
        gateOpen = BreathFluteMath.breathGateOpen(
            breathDBFS: breath,
            noiseFloorDBFS: floor,
            wasOpen: wasOpen
        )
        let above = breath - floor
        synth.set(
            gate: gateOpen,
            hz: frequencyHz,
            amplitude: gateOpen ? BreathFluteMath.amplitude(aboveFloorDB: above) : 0
        )
    }

    private func pushSynth() {
        let above = breathDBFS - noiseFloor
        synth.set(
            gate: gateOpen,
            hz: frequencyHz,
            amplitude: gateOpen ? BreathFluteMath.amplitude(aboveFloorDB: above) : 0
        )
    }
}

private enum FluteAudioError: Error {
    case noFormat
}

private final class FluteSynth: @unchecked Sendable {
    struct State {
        var gate = false
        var hz = BreathFluteMath.rootHz
        /// Target gain from the blow gate. Finger covers never raise this alone.
        var amplitude = 0.0
        var envelope = 0.0
        var phase = 0.0
        var phase2 = 0.0
        var phase3 = 0.0
        var phase4 = 0.0
        var phase5 = 0.0
        var noise = 0.0
        var noiseSeed: UInt64 = 0xC0FF_EE12_3456_789A
    }

    private let lock = OSAllocatedUnfairLock(initialState: State())

    func set(gate: Bool, hz: Double, amplitude: Double) {
        lock.withLock { state in
            // Touching holes only changes pitch via setFrequency; it cannot open
            // the gate. While gated off we keep the last amplitude briefly so the
            // envelope can release — then hard-zero so idle stays silent.
            state.gate = gate
            state.hz = hz
            if gate {
                state.amplitude = amplitude
            } else if state.envelope <= 1e-3 {
                state.amplitude = 0
                state.envelope = 0
            }
        }
    }

    func fill(_ data: UnsafeMutablePointer<Float>, frames: Int, sampleRate: Double) {
        // OSAllocatedUnfairLock.withLock is @Sendable. The render pointer is not.
        // Render into Sendable storage, then copy into the buffer on this thread.
        let rendered: ContiguousArray<Float> = lock.withLock { state in
            var samples = ContiguousArray<Float>(repeating: 0, count: frames)
            // Fully closed and released — leave the zeroed buffer (no hiss/click loops).
            if !state.gate && state.envelope <= 1e-4 {
                state.amplitude = 0
                state.envelope = 0
                return samples
            }
            for index in 0..<frames {
                let target = (state.gate && state.amplitude > 0 && state.hz > 0) ? 1.0 : 0.0
                let light = state.amplitude > 0
                    && state.amplitude <= BreathFluteMath.quietAmplitude * 1.35
                state.envelope = BreathFluteMath.envelopeStep(
                    current: state.envelope,
                    target: target,
                    sampleRate: sampleRate,
                    lightBlow: light
                )
                let step = BreathFluteMath.angelicSample(
                    phase: state.phase,
                    phase2: state.phase2,
                    phase3: state.phase3,
                    phase4: state.phase4,
                    phase5: state.phase5,
                    noise: state.noise,
                    noiseSeed: state.noiseSeed,
                    frequencyHz: state.hz,
                    sampleRate: sampleRate,
                    amplitude: state.amplitude,
                    envelope: state.envelope
                )
                samples[index] = Float(step.sample)
                state.phase = step.nextPhase
                state.phase2 = step.nextPhase2
                state.phase3 = step.nextPhase3
                state.phase4 = step.nextPhase4
                state.phase5 = step.nextPhase5
                state.noise = step.nextNoise
                state.noiseSeed = step.nextSeed
            }
            return samples
        }
        guard frames > 0 else { return }
        rendered.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            data.update(from: base, count: frames)
        }
    }
}

struct BreathFluteView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var model = BreathFluteModel()
    /// Press-and-hold covers. Index 0 is nearest the embouchure (bottom of the screen).
    /// VoiceOver adjustable action also writes consecutive covers here.
    @State private var covering = Array(repeating: false, count: BreathFluteMath.fingerHoleCount)

    var body: some View {
        ToolScaffold(
            toolID: .breathFlute,
            stickyAnswer: nil,
            copyText: nil,
            disclaimer: .none,
            showsIdentityHeader: false,
            showsRelatedTools: false,
            immersivePlay: true
        ) {
            if model.permissionDenied {
                ToolEmptyState(
                    title: "Microphone is off",
                    detail: "Breath Flute uses the same microphone permission as Noise Meter to hear a blow. The tone stays on this phone. Nothing is recorded or uploaded.",
                    systemImage: "mic.slash",
                    showsSettings: true
                )
            } else {
                playStage
            }
        }
        .onAppear {
            applyFingering()
            model.start()
        }
        .onDisappear { model.stop() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.start()
            case .background: model.stop()
            default: break
            }
        }
    }

    /// Deepest held hole from embouchure — each hole is a distinct pitch on phone.
    private var coveredCount: Int {
        BreathFluteMath.coveredDepth(holesCovered: covering)
    }

    /// Fill covers from embouchure through the deepest press (flute tube length).
    private var displayCovered: [Bool] {
        BreathFluteMath.coversForDepth(coveredCount)
    }

    private var noteName: String {
        BreathFluteMath.noteName(coveredFromEmbouchure: coveredCount)
    }

    private var breathWord: String {
        if model.isCalibrating { return "…" }
        let above = model.breathDBFS - model.noiseFloor
        let amplitude = BreathFluteMath.amplitude(aboveFloorDB: above)
        if amplitude >= BreathFluteMath.loudAmplitude * 0.75 { return "Loud" }
        if model.gateOpen { return "Playing" }
        return "Silent"
    }

    /// Immersive play: fill nearly the whole phone under the nav bar.
    private var fluteCanvasHeight: CGFloat {
        if verticalSizeClass == .compact { return 220 }
        let screen = Self.windowScreenHeight
        if horizontalSizeClass == .regular {
            return min(640, max(400, screen * 0.72))
        }
        return min(720, max(480, screen * 0.78))
    }

    /// Prefer the foreground window scene so Archive SDKs do not warn on `UIScreen.main`.
    private static var windowScreenHeight: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let screen = scenes.first(where: { $0.activationState == .foregroundActive })?.screen
            ?? scenes.first?.screen
        return screen?.bounds.height ?? 844
    }

    private var landscapeFlute: Bool {
        verticalSizeClass == .compact
    }

    /// Instrument + tiny note/loudness affordance. How-it-works stays behind the toolbar `i`.
    private var playStage: some View {
        VStack(spacing: Theme.Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(noteName)
                    .font(Theme.TypeRole.numericHero)
                    .foregroundStyle(Theme.copper)
                    .accessibilityLabel("Note \(noteName)")
                Text(breathWord)
                    .font(Theme.TypeRole.numericEmphasis)
                    .foregroundStyle(model.gateOpen ? Theme.good : Theme.muted)
                    .accessibilityLabel(model.gateOpen ? breathWord : "Silent until you blow")
                Spacer(minLength: 0)
            }
            FingerFlute(
                covered: displayCovered,
                landscape: landscapeFlute,
                onTouching: { next in
                    covering = next
                    applyFingering()
                }
            )
            .frame(height: fluteCanvasHeight)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Handmade relic flute. Hold finger holes and blow at the bottom edge of the phone.")
            .accessibilityValue("\(noteName), \(model.gateOpen ? breathWord : "silent"). \(coveredCount) holes covered from the mouthpiece.")
            .accessibilityAdjustableAction { direction in
                let count = coveredCount
                let target: Int
                switch direction {
                case .increment:
                    target = max(0, count - 1)
                case .decrement:
                    target = min(BreathFluteMath.fingerHoleCount, count + 1)
                @unknown default:
                    target = count
                }
                // VoiceOver: cover through target depth (same as press-and-hold deepest hole).
                covering = BreathFluteMath.coversForDepth(target)
                applyFingering()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func applyFingering() {
        let count = BreathFluteMath.coveredDepth(holesCovered: covering)
        // Pitch only — remaps immediately while the blow gate is open.
        // Gate stays closed until breath clears the mic margin.
        model.setFrequency(BreathFluteMath.frequencyHz(coveredFromEmbouchure: count))
    }
}

/// Handmade wood / bone / clay relic. Embouchure toward the phone bottom mic.
private struct FingerFlute: View {
    var covered: [Bool]
    var landscape: Bool
    var onTouching: ([Bool]) -> Void

    var body: some View {
        GeometryReader { geo in
            let layout = FingerFluteLayout(size: geo.size, holeCount: covered.count, landscape: landscape)
            ZStack {
                RelicFluteCanvas(layout: layout, covered: covered)
                FluteTouchOverlay(
                    centers: (0..<covered.count).map { layout.holeCenter($0) },
                    hitRadius: layout.hitRadius,
                    onTouching: onTouching
                )
            }
        }
    }
}

/// Canvas drawing — aged wood body, bone ends, clay-dark holes. No SF Symbol chrome.
private struct RelicFluteCanvas: View {
    var layout: FingerFluteLayout
    var covered: [Bool]

    var body: some View {
        Canvas { context, _ in
            let tube = layout.tubeRect
            drawBody(context: context, tube: tube)
            drawGrain(context: context, tube: tube)
            drawEnds(context: context, tube: tube)
            drawHoles(context: context)
            drawEmbouchure(context: context)
            drawBlowCue(context: context)
        }
        .allowsHitTesting(false)
    }

    private func drawBody(context: GraphicsContext, tube: CGRect) {
        let path = Path(roundedRect: tube, cornerRadius: layout.tubeCorner, style: .continuous)
        // Warm hardwood → bone highlight → clay shadow.
        context.fill(
            path,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.42, green: 0.26, blue: 0.14),
                    Color(red: 0.72, green: 0.52, blue: 0.32),
                    Color(red: 0.88, green: 0.78, blue: 0.58),
                    Color(red: 0.55, green: 0.36, blue: 0.20),
                    Color(red: 0.36, green: 0.22, blue: 0.12),
                ]),
                startPoint: layout.landscape
                    ? CGPoint(x: tube.midX, y: tube.minY)
                    : CGPoint(x: tube.minX, y: tube.midY),
                endPoint: layout.landscape
                    ? CGPoint(x: tube.midX, y: tube.maxY)
                    : CGPoint(x: tube.maxX, y: tube.midY)
            )
        )
        context.stroke(
            path,
            with: .color(Color(red: 0.22, green: 0.12, blue: 0.06).opacity(0.85)),
            lineWidth: 1.5
        )
        // Soft clay wash along one edge — handmade, not CNC.
        var wash = Path()
        if layout.landscape {
            wash.addEllipse(in: CGRect(
                x: tube.minX + tube.width * 0.08,
                y: tube.minY - 2,
                width: tube.width * 0.7,
                height: tube.height * 0.35
            ))
        } else {
            wash.addEllipse(in: CGRect(
                x: tube.minX - 2,
                y: tube.minY + tube.height * 0.1,
                width: tube.width * 0.38,
                height: tube.height * 0.7
            ))
        }
        context.fill(wash, with: .color(Color(red: 0.62, green: 0.42, blue: 0.28).opacity(0.22)))
    }

    private func drawGrain(context: GraphicsContext, tube: CGRect) {
        var grain = Path()
        let lines = 7
        for i in 0..<lines {
            let t = CGFloat(i + 1) / CGFloat(lines + 1)
            if layout.landscape {
                let y = tube.minY + tube.height * t
                grain.move(to: CGPoint(x: tube.minX + 10, y: y))
                grain.addQuadCurve(
                    to: CGPoint(x: tube.maxX - 10, y: y + (i.isMultiple(of: 2) ? 1.5 : -1.2)),
                    control: CGPoint(x: tube.midX, y: y + (i.isMultiple(of: 2) ? -2 : 2))
                )
            } else {
                let x = tube.minX + tube.width * t
                grain.move(to: CGPoint(x: x, y: tube.minY + 12))
                grain.addQuadCurve(
                    to: CGPoint(x: x + (i.isMultiple(of: 2) ? 1.4 : -1.1), y: tube.maxY - 12),
                    control: CGPoint(x: x + (i.isMultiple(of: 2) ? -2 : 2), y: tube.midY)
                )
            }
        }
        context.stroke(
            grain,
            with: .color(Color(red: 0.28, green: 0.16, blue: 0.08).opacity(0.28)),
            lineWidth: 0.8
        )
    }

    private func drawEnds(context: GraphicsContext, tube: CGRect) {
        let bone = Color(red: 0.90, green: 0.84, blue: 0.70)
        let boneEdge = Color(red: 0.55, green: 0.45, blue: 0.30)
        if layout.landscape {
            let left = CGRect(x: tube.minX - 4, y: tube.minY + 2, width: 18, height: tube.height - 4)
            let right = CGRect(x: tube.maxX - 14, y: tube.minY + 2, width: 18, height: tube.height - 4)
            for rect in [left, right] {
                let path = Path(roundedRect: rect, cornerRadius: rect.height / 2, style: .continuous)
                context.fill(path, with: .color(bone))
                context.stroke(path, with: .color(boneEdge.opacity(0.7)), lineWidth: 1)
            }
        } else {
            let top = CGRect(x: tube.minX + 2, y: tube.minY - 4, width: tube.width - 4, height: 18)
            let bottom = CGRect(x: tube.minX + 2, y: tube.maxY - 14, width: tube.width - 4, height: 18)
            for rect in [top, bottom] {
                let path = Path(roundedRect: rect, cornerRadius: rect.width / 2, style: .continuous)
                context.fill(path, with: .color(bone))
                context.stroke(path, with: .color(boneEdge.opacity(0.7)), lineWidth: 1)
            }
        }
    }

    private func drawHoles(context: GraphicsContext) {
        for index in covered.indices {
            let center = layout.holeCenter(index)
            let r = layout.holeRadius
            let rim = Path(ellipseIn: CGRect(x: center.x - r - 2, y: center.y - r - 2, width: (r + 2) * 2, height: (r + 2) * 2))
            context.fill(rim, with: .color(Color(red: 0.30, green: 0.18, blue: 0.10).opacity(0.9)))
            let pit = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            context.fill(
                pit,
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 0.08, green: 0.05, blue: 0.03),
                        Color(red: 0.18, green: 0.10, blue: 0.06),
                        Color.black.opacity(0.95),
                    ]),
                    center: CGPoint(x: center.x - r * 0.2, y: center.y - r * 0.25),
                    startRadius: 0,
                    endRadius: r
                )
            )
            if covered[index] {
                let finger = Path(ellipseIn: CGRect(
                    x: center.x - r * 0.92,
                    y: center.y - r * 0.92,
                    width: r * 1.84,
                    height: r * 1.84
                ))
                context.fill(
                    finger,
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 0.78, green: 0.58, blue: 0.42),
                            Color(red: 0.55, green: 0.36, blue: 0.26),
                        ]),
                        center: CGPoint(x: center.x - r * 0.15, y: center.y - r * 0.2),
                        startRadius: 0,
                        endRadius: r
                    )
                )
            }
        }
    }

    private func drawEmbouchure(context: GraphicsContext) {
        let c = layout.embouchureCenter
        let slot = layout.landscape
            ? CGRect(x: c.x - 8, y: c.y - 14, width: 16, height: 28)
            : CGRect(x: c.x - 14, y: c.y - 8, width: 28, height: 16)
        let oval = Path(ellipseIn: slot)
        context.fill(oval, with: .color(Color.black.opacity(0.9)))
        context.stroke(oval, with: .color(Color(red: 0.92, green: 0.86, blue: 0.72).opacity(0.85)), lineWidth: 1.5)
    }

    private func drawBlowCue(context: GraphicsContext) {
        // Tiny embouchure cue only — no how-to plate on the play surface.
        let c = layout.blowLabelCenter
        var chevron = Path()
        let tip = CGPoint(x: c.x, y: c.y + 6)
        chevron.move(to: CGPoint(x: c.x - 7, y: tip.y - 9))
        chevron.addLine(to: tip)
        chevron.addLine(to: CGPoint(x: c.x + 7, y: tip.y - 9))
        context.stroke(
            chevron,
            with: .color(Color(red: 0.92, green: 0.78, blue: 0.48).opacity(0.85)),
            style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round)
        )
    }
}

private struct FingerFluteLayout {
    var size: CGSize
    var holeCount: Int
    var landscape: Bool

    var tubeCorner: CGFloat { landscape ? tubeRect.height / 2 : tubeRect.width / 2 }

    var tubeRect: CGRect {
        if landscape {
            let height: CGFloat = min(72, max(52, size.height * 0.42))
            let width = max(220, size.width - 16)
            return CGRect(
                x: (size.width - width) / 2,
                y: (size.height - height) / 2 - 8,
                width: width,
                height: height
            )
        }
        let width: CGFloat = min(108, max(72, size.width * 0.34))
        // Tall play canvas: leave a slim embouchure cue under the tube.
        let height = max(160, size.height - 36)
        return CGRect(x: (size.width - width) / 2, y: 8, width: width, height: height)
    }

    var holeRadius: CGFloat {
        if landscape {
            return min(16, max(11, tubeRect.height * 0.22))
        }
        let span = max(holeSpanLength, 1)
        let fit = span / CGFloat(max(holeCount, 1)) * 0.34
        return min(22, max(13, fit))
    }

    var hitRadius: CGFloat { holeRadius + 14 }

    private var holeSpanLength: CGFloat {
        if landscape {
            return max(tubeRect.width - 110, 40)
        }
        return max(tubeRect.height - 96, 40)
    }

    func holeCenter(_ index: Int) -> CGPoint {
        let t = holeCount <= 1 ? 0 : CGFloat(index) / CGFloat(max(holeCount - 1, 1))
        if landscape {
            // Index 0 nearest embouchure (toward trailing / bottom-mic side).
            let trailing = tubeRect.maxX - 58
            let leading = tubeRect.minX + 52
            return CGPoint(x: trailing - t * (trailing - leading), y: tubeRect.midY)
        }
        let top = tubeRect.minY + 22
        let bottom = tubeRect.maxY - 52
        let span = max(bottom - top, 1)
        return CGPoint(x: tubeRect.midX, y: bottom - t * span)
    }

    var embouchureCenter: CGPoint {
        if landscape {
            return CGPoint(x: tubeRect.maxX - 28, y: tubeRect.midY)
        }
        return CGPoint(x: tubeRect.midX, y: tubeRect.maxY - 26)
    }

    var blowLabelCenter: CGPoint {
        if landscape {
            return CGPoint(x: size.width / 2, y: min(size.height - 24, tubeRect.maxY + 28))
        }
        return CGPoint(x: size.width / 2, y: min(size.height - 22, tubeRect.maxY + 28))
    }
}

private struct FluteTouchOverlay: UIViewRepresentable {
    var centers: [CGPoint]
    var hitRadius: CGFloat
    var onTouching: ([Bool]) -> Void

    func makeUIView(context: Context) -> FluteTouchView {
        let view = FluteTouchView()
        view.onTouching = onTouching
        return view
    }

    func updateUIView(_ uiView: FluteTouchView, context: Context) {
        uiView.centers = centers
        uiView.hitRadius = hitRadius
        uiView.onTouching = onTouching
    }
}

private final class FluteTouchView: UIView {
    var centers: [CGPoint] = []
    var hitRadius: CGFloat = 28
    var onTouching: (([Bool]) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        publish(event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        publish(event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        publish(event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        publish(event)
    }

    private func publish(_ event: UIEvent?) {
        var covered = Array(repeating: false, count: centers.count)
        let active = event?.allTouches?.filter { touch in
            touch.phase != .ended && touch.phase != .cancelled
        } ?? []
        for touch in active {
            if let index = holeIndex(at: touch.location(in: self)) {
                covered[index] = true
            }
        }
        onTouching?(covered)
    }

    private func holeIndex(at point: CGPoint) -> Int? {
        var best: (index: Int, distance: CGFloat)?
        for (index, center) in centers.enumerated() {
            let distance = hypot(point.x - center.x, point.y - center.y)
            guard distance <= hitRadius else { continue }
            if best == nil || distance < best!.distance {
                best = (index, distance)
            }
        }
        return best?.index
    }
}
