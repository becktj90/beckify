import Accelerate
import AVFoundation
import Combine
import os
import SwiftUI
import BeckifyMath

private struct FluteFret: Identifiable {
    var id: Int { fret }
    var label: String
    var fret: Int
}

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

    private let engine = AVAudioEngine()
    private let frameBuffer = AudioFrameBuffer()
    private var fftSetup: FFTSetup?
    private let synth = FluteSynth()
    private var source: AVAudioSourceNode?
    private var installed = false
    private var wantsRunning = false
    private var didSuspendSpectrum = false
    private var sampleRate = 44_100.0

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
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                status = "No microphone format"
                running = false
                return
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
            status = "Play tool · local tone · not recording"
            pushSynth()
        } catch {
            status = "Could not start audio: \(error.localizedDescription)"
            running = false
        }
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

    private let frets = [
        FluteFret(label: "C4", fret: 0),
        FluteFret(label: "D", fret: 2),
        FluteFret(label: "E", fret: 4),
        FluteFret(label: "F", fret: 5),
        FluteFret(label: "G", fret: 7),
        FluteFret(label: "A", fret: 9),
        FluteFret(label: "B", fret: 11),
        FluteFret(label: "C5", fret: 12),
    ]

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
                meaning: "Blow to open a tone generated on this phone. Touch height or a fret sets pitch. This is a play tool, not a meter. Nothing is recorded or uploaded."
            )
            Text("Play tool")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.accent)
            Text(BreathFluteMath.honestLimit)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
            if model.permissionDenied {
                ToolEmptyState(
                    title: "Microphone is off",
                    detail: "Breath Flute uses the same microphone permission as Noise Meter to hear a blow. The tone stays on this phone. Nothing is recorded or uploaded.",
                    systemImage: "mic.slash",
                    showsSettings: true
                )
            }
            ResultCard(title: "Tone", copyText: copyText) {
                ResultRow(label: "Gate", value: model.gateOpen ? "Open" : "Silent", emphasis: true, tone: model.gateOpen ? Theme.good : Theme.foreground)
                ResultRow(label: "Pitch", value: "\(Format.number(model.frequencyHz, digits: 1)) Hz", emphasis: true, tone: Theme.copper)
                ResultRow(label: "Above floor", value: aboveLabel)
                ResultRow(label: "Engine", value: model.status)
                pitchPad
                    .padding(.top, 8)
                Text("Tiny blow spectrum, relative dBFS. Play tool, not a meter.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 8)
                SpectrumPlot(
                    bands: model.blowBands,
                    plotHeight: 56,
                    accessibilityLabel: "Tiny relative blow spectrum",
                    footnote: "Same microphone, not recorded. Not an SLM."
                )
            }
            fretRow
            SaveJobBar(jobName: $jobName, notes: $notes, canSave: model.hasReading) { save() }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.start()
            case .background: model.stop()
            default: break
            }
        }
    }

    private var pitchPad: some View {
            GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.surfaceRaised)
                Text("Drag up for a higher pitch")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .padding(8)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let height = max(geo.size.height, 1)
                        let touch = 1 - min(1, max(0, value.location.y / height))
                        model.setFrequency(BreathFluteMath.frequencyHz(touchY: touch))
                    }
            )
        }
        .frame(height: 180)
        .accessibilityLabel("Pitch pad. Drag up for a higher tone.")
    }

    private var fretRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(frets) { fret in
                    Button(fret.label) {
                        model.setFrequency(BreathFluteMath.fretFrequencyHz(fret: fret.fret))
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                }
            }
        }
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
