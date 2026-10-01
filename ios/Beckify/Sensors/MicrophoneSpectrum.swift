import Accelerate
import AVFoundation
import Combine
import os
import SwiftUI
import BeckifyMath

/// One microphone tap for Noise Meter, Acoustic Imager, Stillness Anomaly Watch, and Room & Rig Check.
///
/// A second screen that wants the mic joins this tap instead of installing another
/// `AVAudioEngine` tap. Breath Flute calls `suspendForTone()` so a play-along
/// tone does not fight the metering engine. Room & Rig Check plays pink noise, a log
/// sweep, or a tone burst on this same engine — it does not start a second FFT.
///
/// # Measurement path (Setup Check PR1)
/// The audio tap only copies samples into a preallocated ring buffer and advances a
/// sample counter. A serial DSP worker aggregates timestamped / sample-counted frames,
/// runs the live FFT (and optional longer overlapping bass FFT), and publishes.
/// SwiftUI `.onChange(of: rmsDBFS)` is not the sample clock.
@MainActor
final class MicrophoneSpectrumCenter: ObservableObject {
    static let shared = MicrophoneSpectrumCenter()

    @Published private(set) var bands: [AcousticDisplayBand] = []
    @Published private(set) var rmsDBFS: Double = SoundLevel.silenceFloorDBFS
    @Published private(set) var peakDBFS: Double = SoundLevel.silenceFloorDBFS
    @Published private(set) var peakHz: Double?
    @Published private(set) var sampleRateHz: Double = 0
    @Published private(set) var harmonicRatio: Double?
    @Published private(set) var rtaBands: [AcousticDisplayBand] = []
    @Published private(set) var crestDB: Double?
    @Published private(set) var clipFraction: Double = 0
    @Published private(set) var stimulus: RoomRigStimulusKind = .listen
    @Published private(set) var stimulusHz: Double?
    @Published private(set) var inputChannelCount: Int = 0
    @Published private(set) var channelBalance: Double?
    @Published private(set) var latencySeconds: Double?
    @Published private(set) var harmonicOrders: [RoomRigHarmonic] = []
    /// Latest DSP-worker frame. Setup Check aggregates from `frameID`, not rms onChange.
    @Published private(set) var latestFrame: RoomRigMeasurementFrame?
    @Published private(set) var frameID: UInt64 = 0
    @Published private(set) var totalSampleCount: UInt64 = 0
    @Published private(set) var routeFingerprint: RoomRigRouteFingerprint?
    @Published private(set) var routeEpoch: UInt64 = 0
    @Published private(set) var bassBands: [AcousticDisplayBand] = []
    @Published private(set) var bassFFTLength: Int = 0
    @Published var enableBassAnalysis = true
    @Published var windowKind: SpectrumWindowKind = .hann {
        didSet { windowBox.set(windowKind) }
    }
    @Published private(set) var permissionDenied = false
    @Published private(set) var running = false
    @Published private(set) var hasReading = false
    @Published private(set) var status = "Microphone idle"
    @Published private(set) var sharing = false

    private var tokens: [UUID: String] = [:]
    private var playbackHolds = 0
    private let engine = AVAudioEngine()
    private let player = RoomStimulusPlayer()
    private var sourceNode: AVAudioSourceNode?
    private var playAndRecord = false
    private var installed = false
    private var sessionActive = false
    private var fftSetupLive: FFTSetup?
    private var fftSetupBass: FFTSetup?
    private let ring = AudioRingBuffer(capacity: RoomRigMath.bassFFTLengthLong * 2)
    private let windowBox = WindowBox()
    private let worker = DispatchQueue(label: "com.beckify.toolbox.mic-dsp", qos: .userInitiated)
    private let workerLock = OSAllocatedUnfairLock(initialState: WorkerFlags())
    private var lastPublish = Date.distantPast
    private var routeObserver: NSObjectProtocol?
    private var mediaResetObserver: NSObjectProtocol?
    private var nextFrameID: UInt64 = 0

    private struct WorkerFlags: Sendable {
        var running = false
        var enableBass = true
        var fingerprint = RoomRigRouteFingerprint(
            sampleRateHz: 0,
            channelCount: 0,
            routeUID: "unknown",
            inputGain: 0
        )
    }

    private init() {
        observeRouteChanges()
    }

    deinit {
        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
        }
        if let mediaResetObserver {
            NotificationCenter.default.removeObserver(mediaResetObserver)
        }
    }

    func retain(_ token: UUID, role: String) {
        tokens[token] = role
        sharing = tokens.count > 1
        guard playbackHolds == 0 else {
            status = "Microphone paused while a tone plays"
            return
        }
        startEngineIfNeeded()
    }

    func release(_ token: UUID) {
        tokens.removeValue(forKey: token)
        sharing = tokens.count > 1
        guard tokens.isEmpty else { return }
        stopEngine(status: "Microphone idle")
    }

    func suspendForTone() {
        playbackHolds += 1
        stopEngine(status: tokens.isEmpty ? "Microphone idle" : "Microphone paused while a tone plays")
    }

    func resumeAfterTone() {
        playbackHolds = max(0, playbackHolds - 1)
        guard playbackHolds == 0, !tokens.isEmpty else { return }
        startEngineIfNeeded()
    }

    func setStimulus(_ kind: RoomRigStimulusKind) {
        let needsPlay = kind != .listen
        player.setKind(kind)
        stimulus = kind
        if kind == .listen {
            stimulusHz = nil
            harmonicOrders = []
        }
        latencySeconds = nil
        guard playbackHolds == 0, !tokens.isEmpty, running || installed else { return }
        if needsPlay != playAndRecord {
            recycleAndStart()
        }
    }

    func endStimulus() {
        player.setKind(.listen)
        stimulus = .listen
        stimulusHz = nil
        harmonicOrders = []
        latencySeconds = nil
    }

    private func observeRouteChanges() {
        let center = NotificationCenter.default
        routeObserver = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.noteRouteOrGainChange() }
        }
        mediaResetObserver = center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.noteRouteOrGainChange() }
        }
    }

    private func noteRouteOrGainChange() {
        routeEpoch &+= 1
        let fingerprint = currentFingerprint()
        routeFingerprint = fingerprint
        workerLock.withLock { $0.fingerprint = fingerprint }
        if running {
            status = engineStatus(playing: playAndRecord) + " · route changed"
        }
    }

    private func currentFingerprint() -> RoomRigRouteFingerprint {
        let session = AVAudioSession.sharedInstance()
        let inputs = session.currentRoute.inputs.map(\.portName).joined(separator: "+")
        let outputs = session.currentRoute.outputs.map(\.portName).joined(separator: "+")
        let routeUID = [inputs, outputs].filter { !$0.isEmpty }.joined(separator: "→")
        let gain = Double(session.inputGain)
        return RoomRigRouteFingerprint(
            sampleRateHz: sampleRateHz > 0 ? sampleRateHz : session.sampleRate,
            channelCount: max(inputChannelCount, Int(session.inputNumberOfChannels)),
            routeUID: routeUID.isEmpty ? "unknown" : routeUID,
            inputGain: gain.isFinite ? gain : 0
        )
    }

    private func startEngineIfNeeded() {
        guard playbackHolds == 0, !tokens.isEmpty else { return }
        if running, installed { return }
        requestThenRun()
    }

    private func stopEngine(status: String) {
        workerLock.withLock { $0.running = false }
        running = false
        self.status = status
        if installed {
            engine.inputNode.removeTap(onBus: 0)
            installed = false
        }
        if engine.isRunning { engine.stop() }
        detachStimulus()
        if let fftSetupLive {
            vDSP_destroy_fftsetup(fftSetupLive)
            self.fftSetupLive = nil
        }
        if let fftSetupBass {
            vDSP_destroy_fftsetup(fftSetupBass)
            self.fftSetupBass = nil
        }
        ring.reset()
        if sessionActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            sessionActive = false
        }
    }

    private func recycleAndStart() {
        workerLock.withLock { $0.running = false }
        if installed {
            engine.inputNode.removeTap(onBus: 0)
            installed = false
        }
        if engine.isRunning { engine.stop() }
        detachStimulus()
        running = false
        beginEngine()
    }

    private func detachStimulus() {
        if let sourceNode {
            engine.disconnectNodeOutput(sourceNode)
            engine.detach(sourceNode)
            self.sourceNode = nil
        }
        playAndRecord = false
    }

    private func requestThenRun() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self, !self.tokens.isEmpty, self.playbackHolds == 0 else { return }
                if granted {
                    self.permissionDenied = false
                    self.beginEngine()
                } else {
                    self.permissionDenied = true
                    self.running = false
                    self.status = "Microphone permission denied"
                }
            }
        }
    }

    private func beginEngine() {
        guard playbackHolds == 0, !tokens.isEmpty else { return }
        if running, installed { return }
        do {
            let session = AVAudioSession.sharedInstance()
            let wantsPlay = player.kind != .listen
            if wantsPlay {
                try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
            } else {
                try session.setCategory(.record, mode: .measurement, options: [.mixWithOthers])
            }
            try session.setActive(true)
            sessionActive = true
            playAndRecord = wantsPlay
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                status = "No microphone format"
                running = false
                return
            }
            inputChannelCount = Int(format.channelCount)
            sampleRateHz = format.sampleRate
            let fingerprint = currentFingerprint()
            routeFingerprint = fingerprint
            workerLock.withLock {
                $0.fingerprint = fingerprint
                $0.enableBass = enableBassAnalysis
            }
            if fftSetupLive == nil {
                fftSetupLive = AudioBlockFFT.makeSetup(length: RoomRigMath.liveFFTLength)
            }
            if enableBassAnalysis, fftSetupBass == nil {
                fftSetupBass = AudioBlockFFT.makeSetup(length: RoomRigMath.bassFFTLengthPreferred)
            }
            guard let fftSetupLive else {
                status = "FFT setup failed"
                running = false
                return
            }
            if installed {
                input.removeTap(onBus: 0)
                installed = false
            }
            ring.reset()
            let sampleRate = format.sampleRate
            let scratch = ring
            // Minimal callback: copy + count only. No FFT on the audio thread.
            input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(RoomRigMath.liveFFTLength), format: format) { buffer, _ in
                scratch.append(buffer)
            }
            installed = true
            if wantsPlay {
                attachStimulus(format: format)
            }
            try engine.start()
            running = true
            workerLock.withLock { $0.running = true }
            status = engineStatus(playing: wantsPlay)
            kickWorker(sampleRate: sampleRate, liveSetup: fftSetupLive, bassSetup: fftSetupBass)
        } catch {
            status = "Could not start audio: \(error.localizedDescription)"
            running = false
        }
    }

    private func kickWorker(sampleRate: Double, liveSetup: FFTSetup, bassSetup: FFTSetup?) {
        let liveLength = RoomRigMath.liveFFTLength
        let bassLength = RoomRigMath.bassFFTLengthPreferred
        let bassHop = bassLength / 4
        let windows = windowBox
        let stimulusPlayer = player
        let ringBuffer = ring
        let flags = workerLock
        worker.async { [weak self] in
            var bassCursor: UInt64 = 0
            while flags.withLock({ $0.running }) {
                let kind = windows.get()
                let enableBass = flags.withLock { $0.enableBass }
                let fingerprint = flags.withLock { $0.fingerprint }
                guard let block = ringBuffer.popLiveBlock(count: liveLength) else {
                    Thread.sleep(forTimeInterval: 0.004)
                    continue
                }
                let gain = AcousticSpectrum.coherentGain(count: liveLength, kind: kind)
                guard let magnitudes = AudioBlockFFT.magnitudes(
                    samples: block.samples,
                    setup: liveSetup,
                    length: liveLength,
                    window: kind,
                    coherentGain: gain
                ) else { continue }

                let bands = AcousticSpectrum.fold(
                    linearMagnitudes: magnitudes,
                    sampleRate: sampleRate,
                    fftLength: liveLength
                )
                let rta = RoomRigMath.thirdOctaveBands(
                    linearMagnitudes: magnitudes,
                    sampleRate: sampleRate,
                    fftLength: liveLength
                )
                let stats = RoomRigMath.frameStats(samples: block.samples.map(Double.init))
                let snap = stimulusPlayer.snapshot()
                let heardAt = Date().timeIntervalSinceReferenceDate
                let latency = stimulusPlayer.noteHeard(at: heardAt, linearPeak: stats.linearPeak)
                let peak = AcousticSpectrum.peakBand(bands)?.centerHz
                let ratio = RelativeHarmonicEnergy.ratio(linearMagnitudes: magnitudes)
                let harmonics: [RoomRigHarmonic]
                if let hz = snap.hz, snap.kind == .sweep || snap.kind == .burst {
                    harmonics = RoomRigMath.harmonicOrders(
                        linearMagnitudes: magnitudes,
                        fundamentalHz: hz,
                        sampleRate: sampleRate,
                        fftLength: liveLength
                    ) ?? []
                } else {
                    harmonics = []
                }

                var bassResult: (bands: [AcousticDisplayBand], length: Int)?
                if enableBass, let bassSetup {
                    let total = block.endSampleCount
                    if total >= UInt64(bassLength), total &- bassCursor >= UInt64(bassHop) {
                        if let bassSamples = ringBuffer.latest(count: bassLength) {
                            let bassGain = AcousticSpectrum.coherentGain(count: bassLength, kind: kind)
                            if let bassMags = AudioBlockFFT.magnitudes(
                                samples: bassSamples,
                                setup: bassSetup,
                                length: bassLength,
                                window: kind,
                                coherentGain: bassGain
                            ) {
                                bassResult = (
                                    AcousticSpectrum.fold(
                                        linearMagnitudes: bassMags,
                                        sampleRate: sampleRate,
                                        fftLength: bassLength,
                                        bandCount: 24
                                    ),
                                    bassLength
                                )
                            }
                        }
                        bassCursor = total
                    }
                }

                let frame = RoomRigMeasurementFrame(
                    frameID: 0,
                    sampleCount: block.endSampleCount,
                    hostTimeSeconds: heardAt,
                    rmsDBFS: stats.rmsDBFS,
                    peakDBFS: stats.peakDBFS,
                    crestDB: stats.crestDB,
                    clipFraction: stats.clipFraction,
                    peakHz: peak,
                    bands: bands,
                    rtaBands: rta,
                    fingerprint: fingerprint,
                    headroomDB: RoomRigMeasurementFrame.headroomDB(peakDBFS: stats.peakDBFS)
                )

                DispatchQueue.main.async {
                    self?.publish(
                        frame: frame,
                        harmonicRatio: ratio,
                        harmonics: harmonics,
                        stimulusHz: snap.hz,
                        channelCount: block.channelCount,
                        balance: block.balance,
                        latency: latency,
                        sampleRateHz: sampleRate,
                        bass: bassResult
                    )
                }
            }
        }
    }

    private func attachStimulus(format: AVAudioFormat) {
        detachStimulus()
        playAndRecord = true
        let stimulusPlayer = player
        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for buffer in buffers {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                stimulusPlayer.fill(data, frames: Int(frameCount), sampleRate: format.sampleRate)
            }
            return noErr
        }
        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }

    private func engineStatus(playing: Bool) -> String {
        if playing {
            return sharing ? "Shared tap · phone speaker demo" : "Phone speaker demo · relative mic"
        }
        return sharing ? "Shared microphone tap · audible FFT" : "Metering (uncalibrated dBFS)"
    }

    private func publish(
        frame: RoomRigMeasurementFrame,
        harmonicRatio: Double?,
        harmonics: [RoomRigHarmonic],
        stimulusHz: Double?,
        channelCount: Int,
        balance: Double?,
        latency: Double?,
        sampleRateHz: Double,
        bass: (bands: [AcousticDisplayBand], length: Int)?
    ) {
        if let latency {
            latencySeconds = latency
        }
        nextFrameID &+= 1
        var stamped = frame
        stamped.frameID = nextFrameID
        latestFrame = stamped
        frameID = nextFrameID
        totalSampleCount = stamped.sampleCount
        self.harmonicRatio = harmonicRatio
        harmonicOrders = harmonics
        self.stimulusHz = stimulusHz
        if channelCount > 0 { inputChannelCount = channelCount }
        channelBalance = balance
        self.sampleRateHz = sampleRateHz
        hasReading = true
        if let bass {
            bassBands = bass.bands
            bassFFTLength = bass.length
        }
        workerLock.withLock { $0.enableBass = enableBassAnalysis }

        let now = Date()
        guard now.timeIntervalSince(lastPublish) >= 1.0 / 20.0 else { return }
        lastPublish = now
        bands = stamped.bands
        rtaBands = stamped.rtaBands
        rmsDBFS = stamped.rmsDBFS
        peakDBFS = stamped.peakDBFS
        crestDB = stamped.crestDB
        clipFraction = stamped.clipFraction
        peakHz = stamped.peakHz
        if running {
            status = engineStatus(playing: playAndRecord)
        }
    }
}

private func roomRigChannelReading(_ buffer: AVAudioPCMBuffer) -> (count: Int, balance: Double?) {
    let count = Int(buffer.format.channelCount)
    guard let channels = buffer.floatChannelData else { return (count, nil) }
    let frames = Int(buffer.frameLength)
    guard frames > 0, count >= 2 else { return (count, nil) }
    func rms(_ index: Int) -> Double {
        guard index < count else { return 0 }
        var sum = 0.0
        let pointer = channels[index]
        for offset in 0..<frames {
            let value = Double(pointer[offset])
            if value.isFinite { sum += value * value }
        }
        return sqrt(sum / Double(frames))
    }
    return (count, AcousticSpectrum.channelBalance(leftRMS: rms(0), rightRMS: rms(1)))
}

/// Thread-safe test-signal player for the shared microphone engine.
private final class RoomStimulusPlayer: @unchecked Sendable {
    struct Snapshot: Sendable {
        var kind: RoomRigStimulusKind
        var hz: Double?
    }

    private struct State {
        var kind: RoomRigStimulusKind = .listen
        var pink = PinkNoiseGenerator(seed: 0xBEC5_5101)
        var phase = 0.0
        var sweepSamples = 0
        var burstCursor = 0
        var hz: Double?
        var armedAt: Double?
        var generation = 0
        var heardGeneration = -1
    }

    private let lock = OSAllocatedUnfairLock(initialState: State())

    var kind: RoomRigStimulusKind {
        lock.withLock { $0.kind }
    }

    func setKind(_ kind: RoomRigStimulusKind) {
        lock.withLock { state in
            state.kind = kind
            state.phase = 0
            state.sweepSamples = 0
            state.burstCursor = 0
            state.pink = PinkNoiseGenerator(seed: 0xBEC5_5101)
            state.hz = kind == .burst ? RoomRigMath.burstHz : nil
            state.armedAt = nil
            state.generation = 0
            state.heardGeneration = -1
        }
    }

    func snapshot() -> Snapshot {
        lock.withLock { Snapshot(kind: $0.kind, hz: $0.hz) }
    }

    /// Latch the first loud input after a burst leaves the speaker. One estimate per burst.
    func noteHeard(at heardAt: Double, linearPeak: Double) -> Double? {
        lock.withLock { state in
            guard state.kind == .burst, let armed = state.armedAt, state.heardGeneration != state.generation else {
                return nil
            }
            guard linearPeak >= 0.08 else { return nil }
            guard let latency = RoomRigMath.latencySeconds(playedAt: armed, heardAt: heardAt) else { return nil }
            state.heardGeneration = state.generation
            return latency
        }
    }

    func fill(_ data: UnsafeMutablePointer<Float>, frames: Int, sampleRate: Double) {
        // OSAllocatedUnfairLock.withLock is @Sendable. The render pointer is not.
        // Render into Sendable storage, then copy into the buffer on this thread.
        let rendered: ContiguousArray<Float> = lock.withLock { state in
            var samples = ContiguousArray<Float>(repeating: 0, count: frames)
            let rate = sampleRate.isFinite && sampleRate > 0 ? sampleRate : 48_000
            let gap = Int(rate * 0.65)
            let period = RoomRigMath.burstLength + max(gap, 1)
            for index in 0..<frames {
                let sample: Double
                switch state.kind {
                case .listen:
                    sample = 0
                    state.hz = nil
                case .pink:
                    sample = state.pink.next(amplitude: RoomRigMath.playbackAmplitude)
                    state.hz = nil
                case .sweep:
                    let elapsed = Double(state.sweepSamples) / rate
                    let hz = RoomRigMath.sweepHz(elapsed: elapsed)
                    let step = BreathFluteMath.sineSample(
                        phase: state.phase,
                        frequencyHz: hz,
                        sampleRate: rate,
                        amplitude: RoomRigMath.playbackAmplitude
                    )
                    state.phase = step.nextPhase
                    state.hz = hz
                    state.sweepSamples += 1
                    sample = step.sample
                case .burst:
                    let position = state.burstCursor % period
                    if position < RoomRigMath.burstLength {
                        if position == 0 {
                            state.armedAt = Date().timeIntervalSinceReferenceDate
                            state.generation &+= 1
                        }
                        let envelope = RoomRigMath.burstEnvelope(index: position, length: RoomRigMath.burstLength)
                        let step = BreathFluteMath.sineSample(
                            phase: state.phase,
                            frequencyHz: RoomRigMath.burstHz,
                            sampleRate: rate,
                            amplitude: RoomRigMath.playbackAmplitude * envelope
                        )
                        state.phase = step.nextPhase
                        state.hz = RoomRigMath.burstHz
                        sample = step.sample
                    } else {
                        sample = 0
                        state.hz = RoomRigMath.burstHz
                    }
                    state.burstCursor += 1
                }
                samples[index] = Float(sample)
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

/// Accumulates the first mic channel until a power-of-two FFT block is ready.
final class AudioFrameBuffer: @unchecked Sendable {
    private var samples: [Float] = []

    func reset() {
        samples.removeAll(keepingCapacity: true)
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }
        samples.append(contentsOf: UnsafeBufferPointer(start: channels[0], count: frames))
        let cap = 8192
        if samples.count > cap {
            samples.removeFirst(samples.count - cap)
        }
    }

    func pop(count: Int) -> [Float]? {
        guard samples.count >= count else { return nil }
        let block = Array(samples.prefix(count))
        samples.removeFirst(count)
        return block
    }
}


/// Real FFT with documented vDSP packing and coherent-gain normalization.
///
/// After `vDSP_fft_zrip` forward:
/// - `realp[0]` = DC (real), `imagp[0]` = Nyquist (real)
/// - `realp[k], imagp[k]` for k = 1…N/2−1 are the complex bins
///
/// Magnitudes returned here are **one-sided peak amplitudes** (sample units),
/// matching `CoupledVibrationMath.magnitudeSpectrum` and the
/// `AcousticSpectrum` contract. Do not feed packed splits into `vDSP_zvmags`.
enum AudioBlockFFT {
    static let length = RoomRigMath.liveFFTLength

    static func log2n(for length: Int) -> vDSP_Length? {
        guard length > 1, length & (length - 1) == 0 else { return nil }
        return vDSP_Length(log2(Double(length)))
    }

    static func makeSetup(length: Int = RoomRigMath.liveFFTLength) -> FFTSetup? {
        guard let log2n = log2n(for: length) else { return nil }
        return vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
    }

    /// Breath Flute / legacy call site. Amplitude-normalized Hann (or chosen window).
    static func magnitudes(
        samples: [Float],
        setup: FFTSetup,
        window kind: SpectrumWindowKind = .hann
    ) -> [Double]? {
        let gain = AcousticSpectrum.coherentGain(count: samples.count, kind: kind)
        return magnitudes(
            samples: samples,
            setup: setup,
            length: samples.count,
            window: kind,
            coherentGain: gain
        )
    }

    static func magnitudes(
        samples: [Float],
        setup: FFTSetup,
        length: Int,
        window kind: SpectrumWindowKind = .hann,
        coherentGain: Double
    ) -> [Double]? {
        let n = samples.count
        guard n == length, let log2n = log2n(for: n) else { return nil }
        let half = n / 2
        let window = CoupledVibrationMath.window(count: n, kind: kind).map { Float($0) }
        var windowed = [Float](repeating: 0, count: n)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(n))

        var realp = [Float](repeating: 0, count: half)
        var imagp = [Float](repeating: 0, count: half)
        realp.withUnsafeMutableBufferPointer { realBuf in
            imagp.withUnsafeMutableBufferPointer { imagBuf in
                guard let realBase = realBuf.baseAddress, let imagBase = imagBuf.baseAddress else { return }
                var split = DSPSplitComplex(realp: realBase, imagp: imagBase)
                windowed.withUnsafeBufferPointer { samplesBuf in
                    samplesBuf.baseAddress?.withMemoryRebound(to: DSPComplex.self, capacity: half) { complex in
                        vDSP_ctoz(complex, 2, &split, 1, vDSP_Length(half))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }

        let dc = Double(realp[0])
        let nyquist = Double(imagp[0])
        var amplitudes = [Double](repeating: 0, count: half + 1)
        amplitudes[0] = AcousticSpectrum.amplitudeFromRawVDSP(
            rawMagnitude: abs(dc),
            fftLength: n,
            coherentGain: coherentGain,
            isNyquistOrDC: true
        )
        amplitudes[half] = AcousticSpectrum.amplitudeFromRawVDSP(
            rawMagnitude: abs(nyquist),
            fftLength: n,
            coherentGain: coherentGain,
            isNyquistOrDC: true
        )
        if half > 1 {
            for k in 1..<half {
                let re = Double(realp[k])
                let im = Double(imagp[k])
                let raw = sqrt(re * re + im * im)
                amplitudes[k] = AcousticSpectrum.amplitudeFromRawVDSP(
                    rawMagnitude: raw,
                    fftLength: n,
                    coherentGain: coherentGain,
                    isNyquistOrDC: false
                )
            }
        }
        return amplitudes
    }
}

/// Preallocated mono ring. The audio tap only writes here.
final class AudioRingBuffer: @unchecked Sendable {
    struct LiveBlock {
        var samples: [Float]
        var endSampleCount: UInt64
        var channelCount: Int
        var balance: Double?
    }

    private struct State {
        var storage: [Float]
        var total: UInt64
        var write: Int
        var count: Int
        var channelCount: Int
        var balance: Double?
        let capacity: Int
    }

    private let lock: OSAllocatedUnfairLock<State>

    init(capacity: Int) {
        let cap = max(capacity, RoomRigMath.liveFFTLength * 2)
        lock = OSAllocatedUnfairLock(initialState: State(
            storage: [Float](repeating: 0, count: cap),
            total: 0,
            write: 0,
            count: 0,
            channelCount: 0,
            balance: nil,
            capacity: cap
        ))
    }

    func reset() {
        lock.withLock { state in
            state.total = 0
            state.write = 0
            state.count = 0
            state.channelCount = 0
            state.balance = nil
        }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        let reading = roomRigChannelReading(buffer)
        guard let channels = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }
        let source = UnsafeBufferPointer(start: channels[0], count: frames)
        lock.withLock { state in
            state.channelCount = reading.count
            state.balance = reading.balance
            for sample in source {
                state.storage[state.write] = sample
                state.write += 1
                if state.write >= state.capacity { state.write = 0 }
                if state.count < state.capacity {
                    state.count += 1
                }
                state.total &+= 1
            }
        }
    }

    func popLiveBlock(count: Int) -> LiveBlock? {
        lock.withLock { state in
            guard state.count >= count else { return nil }
            var samples = [Float](repeating: 0, count: count)
            // Oldest sample index in the filled region.
            let oldest = (state.write - state.count + state.capacity) % state.capacity
            for index in 0..<count {
                samples[index] = state.storage[(oldest + index) % state.capacity]
            }
            state.count -= count
            return LiveBlock(
                samples: samples,
                endSampleCount: state.total - UInt64(state.count),
                channelCount: state.channelCount,
                balance: state.balance
            )
        }
    }

    func latest(count: Int) -> [Float]? {
        lock.withLock { state in
            guard state.count >= count else { return nil }
            var samples = [Float](repeating: 0, count: count)
            let start = (state.write - count + state.capacity) % state.capacity
            for index in 0..<count {
                samples[index] = state.storage[(start + index) % state.capacity]
            }
            return samples
        }
    }
}

final class WindowBox: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: SpectrumWindowKind.hann)

    func get() -> SpectrumWindowKind {
        lock.withLock { $0 }
    }

    func set(_ kind: SpectrumWindowKind) {
        lock.withLock { $0 = kind }
    }
}
