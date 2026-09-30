import Accelerate
import AVFoundation
import Combine
import os
import SwiftUI
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
        let plan: SessionPlan = triedVoiceFallback ? .measurement : .voiceChat
        do {
            try boot(plan)
        } catch {
            tearDownPartial()
            if plan.voiceProcessing, !triedVoiceFallback, !(error is FluteAudioError) {
                triedVoiceFallback = true
                do {
                    try boot(.measurement)
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

    /// Voice chat lets iOS echo-cancel the speaker so the gate follows breath.
    /// Measurement is the fallback when that route will not start. Neither mode is a calibration.
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
                self?.apply(levels)
                if let bands { self?.blowBands = bands }
            }
        }
        installed = true
        if source == nil {
            let node = AVAudioSourceNode { [synth] _, _, frameCount, audioBufferList -> OSStatus in
                let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for buffer in buffers {
                    guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    synth.fill(data, frames: Int(frameCount), sampleRate: format.sampleRate)
                }
                return noErr
            }
            source = node
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
        try engine.start()
        running = true
        micRoute = route
        status = "Play tool · \(route) · \(echoLabel) · not recording"
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

    private func apply(_ levels: (rms: Double, peak: Double)) {
        hasReading = true
        rmsDBFS = levels.rms
        peakDBFS = levels.peak
        let level = max(levels.rms, levels.peak)
        noiseFloor = BreathFluteMath.updateNoiseFloor(currentDBFS: levels.rms, floor: noiseFloor)
        gateOpen = BreathFluteMath.gateOpen(
            rmsDBFS: levels.rms,
            peakDBFS: levels.peak,
            noiseFloorDBFS: noiseFloor
        )
        let above = level - noiseFloor
        synth.set(
            gate: gateOpen,
            hz: frequencyHz,
            amplitude: gateOpen ? BreathFluteMath.amplitude(aboveFloorDB: above) : 0
        )
    }

    private func pushSynth() {
        let above = max(rmsDBFS, peakDBFS) - noiseFloor
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
        var amplitude = 0.0
        var phase = 0.0
    }

    private let lock = OSAllocatedUnfairLock(initialState: State())

    func set(gate: Bool, hz: Double, amplitude: Double) {
        lock.withLock { state in
            state.gate = gate
            state.hz = hz
            state.amplitude = amplitude
        }
    }

    func fill(_ data: UnsafeMutablePointer<Float>, frames: Int, sampleRate: Double) {
        // OSAllocatedUnfairLock.withLock is @Sendable. The render pointer is not.
        // Render into Sendable storage, then copy into the buffer on this thread.
        let rendered: ContiguousArray<Float> = lock.withLock { state in
            var samples = ContiguousArray<Float>(repeating: 0, count: frames)
            let silent = !state.gate || state.amplitude <= 0 || state.hz <= 0
            if !silent {
                for index in 0..<frames {
                    let step = BreathFluteMath.sineSample(
                        phase: state.phase,
                        frequencyHz: state.hz,
                        sampleRate: sampleRate,
                        amplitude: state.amplitude
                    )
                    samples[index] = Float(step.sample)
                    state.phase = step.nextPhase
                }
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
    @EnvironmentObject private var jobs: JobStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = BreathFluteModel()
    @StoredInput(.breathFlute, "jobName", default: "Breath flute") private var jobName
    @State private var notes = ""
    /// Sticky covers. Index 0 is the hole nearest the embouchure (bottom of the screen).
    @State private var latched = Array(repeating: false, count: BreathFluteMath.fingerHoleCount)
    @State private var touching = Array(repeating: false, count: BreathFluteMath.fingerHoleCount)

    var body: some View {
        ToolScaffold(
            toolID: .breathFlute,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .sensor(extra: BreathFluteMath.honestLimit)
        ) {
            ShowWorkCard(
                toolID: .breathFlute,
                symbolic: "gate when RMS or peak > noise floor + margin    f = f₀ · 2^(n/12)",
                substituted: sticky,
                meaning: "Blow into the bottom edge of the phone. Cover the round holes with your fingers. Silence until you blow. A harder blow is louder. Play tool, not a calibrated wind instrument. Nothing is recorded or uploaded."
            )
            playSteps
            if model.permissionDenied {
                ToolEmptyState(
                    title: "Microphone is off",
                    detail: "Breath Flute uses the same microphone permission as Noise Meter to hear a blow. The tone stays on this phone. Nothing is recorded or uploaded.",
                    systemImage: "mic.slash",
                    showsSettings: true
                )
            }
            Text(model.gateOpen ? breathWord : "Silent")
                .font(Theme.TypeRole.numericHero)
                .foregroundStyle(model.gateOpen ? Theme.good : Theme.muted)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityLabel(model.gateOpen ? breathWord : "Silent until you blow")
            fingerFlute
            Text("Quiet until you blow. Blow harder, it gets louder.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(BreathFluteMath.honestLimit)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            SaveJobBar(jobName: $jobName, notes: $notes, canSave: model.hasReading) { save() }
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

    private var coveredHoles: [Bool] {
        zip(latched, touching).map { $0 || $1 }
    }

    private var coveredCount: Int {
        BreathFluteMath.coveredFromEmbouchure(holesCovered: coveredHoles)
    }

    private var noteName: String {
        BreathFluteMath.noteName(coveredFromEmbouchure: coveredCount)
    }

    private var breathWord: String {
        let above = max(model.rmsDBFS, model.peakDBFS) - model.noiseFloor
        let amplitude = BreathFluteMath.amplitude(aboveFloorDB: above)
        if amplitude >= BreathFluteMath.loudAmplitude * 0.75 { return "Loud" }
        return "Playing"
    }

    private var playSteps: some View {
        HStack(alignment: .top, spacing: 8) {
            playStep("1", "Blow the bottom")
            playStep("2", "Cover the holes")
            playStep("3", "Sound when you blow")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Blow the bottom of the phone. Cover the holes with your fingers. Sound only when you blow.")
    }

    private func playStep(_ index: String, _ words: String) -> some View {
        VStack(spacing: 4) {
            Text(index)
                .font(Theme.TypeRole.numericEmphasis)
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Theme.accent.opacity(0.15), in: Circle())
            Text(words)
                .font(Theme.TypeRole.fieldLabel)
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var fingerFlute: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(noteName)
                    .font(Theme.TypeRole.numericHero)
                    .foregroundStyle(Theme.copper)
                Spacer()
                Button("Clear fingers") {
                    latched = Array(repeating: false, count: BreathFluteMath.fingerHoleCount)
                    touching = latched
                    applyFingering(held: latched, down: touching)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
            }
            FingerFlute(
                covered: coveredHoles,
                onTouching: { next in
                    touching = next
                    applyFingering(down: next)
                },
                onTap: { index in
                    guard latched.indices.contains(index) else { return }
                    latched[index].toggle()
                    applyFingering(held: latched)
                }
            )
            .frame(height: 560)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Finger flute. Blow here, at the bottom edge of the phone.")
            .accessibilityValue("\(noteName), \(model.gateOpen ? breathWord : "silent"). \(coveredCount) holes covered from the mouthpiece.")
            .accessibilityAdjustableAction { direction in
                let count = BreathFluteMath.coveredFromEmbouchure(holesCovered: latched)
                switch direction {
                case .increment:
                    if count > 0 { latched[count - 1] = false }
                case .decrement:
                    if count < BreathFluteMath.fingerHoleCount { latched[count] = true }
                @unknown default:
                    break
                }
                applyFingering(held: latched)
            }
        }
    }

    private func applyFingering(held: [Bool]? = nil, down: [Bool]? = nil) {
        let holes = zip(held ?? latched, down ?? touching).map { $0 || $1 }
        let count = BreathFluteMath.coveredFromEmbouchure(holesCovered: holes)
        model.setFrequency(BreathFluteMath.frequencyHz(coveredFromEmbouchure: count))
    }

    private var aboveLabel: String {
        guard model.hasReading else { return "—" }
        let above = max(model.rmsDBFS, model.peakDBFS) - model.noiseFloor
        return String(format: "%+.1f dB", above)
    }

    private var sticky: String? {
        guard model.hasReading else { return nil }
        return "\(model.gateOpen ? "Tone" : "Silent") · \(Format.number(model.frequencyHz, digits: 0)) Hz"
    }

    private var copyText: String? { sticky }

    private func save() {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .breathFlute,
            notes: notes,
            inputs: ["kind": "play tool"],
            outputs: [
                "gate": model.gateOpen ? "open" : "silent",
                "Hz": Format.number(model.frequencyHz, digits: 1),
                "audio": "not recorded",
            ]
        ))
    }
}

/// Vertical flute. The embouchure sits at the bottom so it points at the phone mic.
private struct FingerFlute: View {
    var covered: [Bool]
    var onTouching: ([Bool]) -> Void
    var onTap: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let layout = FingerFluteLayout(size: geo.size, holeCount: covered.count)
            ZStack {
                fluteBody(layout)
                ForEach(covered.indices, id: \.self) { index in
                    hole(index, layout: layout)
                }
                embouchure(layout)
                FluteTouchOverlay(
                    centers: (0..<covered.count).map { layout.holeCenter($0) },
                    hitRadius: layout.hitRadius,
                    onTouching: onTouching,
                    onTap: onTap
                )
            }
        }
    }

    private func fluteBody(_ layout: FingerFluteLayout) -> some View {
        let tube = layout.tubeRect
        return ZStack {
            RoundedRectangle(cornerRadius: tube.width / 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.62),
                            Color(white: 0.94),
                            Color(white: 0.70),
                            Color(white: 0.84),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: tube.width / 2, style: .continuous)
                        .stroke(Color.black.opacity(0.28), lineWidth: 1)
                )
                .frame(width: tube.width, height: tube.height)
                .position(x: tube.midX, y: tube.midY)
            Capsule()
                .fill(Color(white: 0.78))
                .overlay(Capsule().stroke(Color.black.opacity(0.25), lineWidth: 1))
                .frame(width: tube.width * 1.16, height: 34)
                .position(x: tube.midX, y: tube.maxY - 22)
        }
    }

    private func hole(_ index: Int, layout: FingerFluteLayout) -> some View {
        let center = layout.holeCenter(index)
        let closed = covered.indices.contains(index) && covered[index]
        return ZStack {
            Circle()
                .fill(Color.black.opacity(0.88))
                .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 3))
                .frame(width: layout.holeRadius * 2, height: layout.holeRadius * 2)
            if closed {
                Circle()
                    .fill(Color(red: 0.76, green: 0.58, blue: 0.44))
                    .overlay(Circle().stroke(Color.white.opacity(0.45), lineWidth: 1))
                    .frame(width: layout.holeRadius * 1.9, height: layout.holeRadius * 1.9)
            }
        }
        .position(center)
        .allowsHitTesting(false)
    }

    private func embouchure(_ layout: FingerFluteLayout) -> some View {
        VStack(spacing: 4) {
            Ellipse()
                .fill(Color.black.opacity(0.92))
                .overlay(Ellipse().stroke(Color.white.opacity(0.9), lineWidth: 2))
                .frame(width: 36, height: 20)
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.accent)
            Text("Blow here")
                .font(Theme.TypeRole.lead)
                .foregroundStyle(Theme.foreground)
            Text("Bottom edge of the phone")
                .font(Theme.TypeRole.fieldLabel)
                .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.accent, lineWidth: 2)
        )
        .position(layout.embouchureCenter)
        .allowsHitTesting(false)
    }
}

private struct FingerFluteLayout {
    var size: CGSize
    var holeCount: Int

    var tubeRect: CGRect {
        let width: CGFloat = 112
        let height = max(160, size.height - 8)
        return CGRect(x: (size.width - width) / 2, y: 4, width: width, height: height)
    }

    /// Big enough for a fingertip. The hit target is larger than the drawn hole.
    var holeRadius: CGFloat { 22 }
    var hitRadius: CGFloat { 32 }

    func holeCenter(_ index: Int) -> CGPoint {
        let top = tubeRect.minY + 28
        let bottom = tubeRect.maxY - 168
        let span = max(bottom - top, 1)
        let t = holeCount <= 1 ? 0 : CGFloat(index) / CGFloat(max(holeCount - 1, 1))
        return CGPoint(x: tubeRect.midX, y: bottom - t * span)
    }

    var embouchureCenter: CGPoint {
        CGPoint(x: tubeRect.midX, y: tubeRect.maxY - 74)
    }
}

private struct FluteTouchOverlay: UIViewRepresentable {
    var centers: [CGPoint]
    var hitRadius: CGFloat
    var onTouching: ([Bool]) -> Void
    var onTap: (Int) -> Void

    func makeUIView(context: Context) -> FluteTouchView {
        let view = FluteTouchView()
        view.onTouching = onTouching
        view.onTap = onTap
        return view
    }

    func updateUIView(_ uiView: FluteTouchView, context: Context) {
        uiView.centers = centers
        uiView.hitRadius = hitRadius
        uiView.onTouching = onTouching
        uiView.onTap = onTap
    }
}

private final class FluteTouchView: UIView {
    var centers: [CGPoint] = []
    var hitRadius: CGFloat = 28
    var onTouching: (([Bool]) -> Void)?
    var onTap: ((Int) -> Void)?
    private var tracks: [ObjectIdentifier: Track] = [:]

    private struct Track {
        var start: CGPoint
        var time: TimeInterval
        var hole: Int?
    }

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
        for touch in touches {
            let point = touch.location(in: self)
            tracks[ObjectIdentifier(touch)] = Track(start: point, time: touch.timestamp, hole: holeIndex(at: point))
        }
        publish(event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        publish(event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let key = ObjectIdentifier(touch)
            let point = touch.location(in: self)
            if let track = tracks[key], let hole = track.hole ?? holeIndex(at: point) {
                let travel = hypot(point.x - track.start.x, point.y - track.start.y)
                if travel < 18, touch.timestamp - track.time < 0.28 {
                    onTap?(hole)
                }
            }
            tracks[key] = nil
        }
        publish(event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            tracks[ObjectIdentifier(touch)] = nil
        }
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
