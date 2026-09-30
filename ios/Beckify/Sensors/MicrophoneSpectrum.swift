import Accelerate
import AVFoundation
import Combine
import os
import SwiftUI
import BeckifyMath

/// One microphone tap for Noise Meter, Acoustic Imager, Stillness Anomaly Watch, and Setup Check.
///
/// A second screen that wants the mic joins this tap instead of installing another
/// `AVAudioEngine` tap. Breath Flute calls `suspendForTone()` so a play-along
/// tone does not fight the metering engine. Setup Check plays pink noise, a log
/// sweep, or a tone burst on this same engine — it does not start a second FFT.
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
    private var fftSetup: FFTSetup?
    private let frameBuffer = AudioFrameBuffer()
    private let windowBox = WindowBox()
    private var lastPublish = Date.distantPast

    private init() {}

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

    /// Breath Flute owns playback. Drop the metering tap until the tone screen leaves.
    func suspendForTone() {
        playbackHolds += 1
        stopEngine(status: tokens.isEmpty ? "Microphone idle" : "Microphone paused while a tone plays")
    }

    func resumeAfterTone() {
        playbackHolds = max(0, playbackHolds - 1)
        guard playbackHolds == 0, !tokens.isEmpty else { return }
        startEngineIfNeeded()
    }

    /// Play a test signal on this engine, or return to listen-only metering.
    /// Crossing between listen and playback restarts the session category.
    /// Staying inside playback (pink → sweep) keeps the tap and only changes the player.
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

    /// Drop a test signal without restarting. Used when the screen is leaving
    /// and `release` is about to stop the engine.
    func endStimulus() {
        player.setKind(.listen)
        stimulus = .listen
        stimulusHz = nil
        harmonicOrders = []
        latencySeconds = nil
    }

    private func startEngineIfNeeded() {
        guard playbackHolds == 0, !tokens.isEmpty else { return }
        if running, installed { return }
        requestThenRun()
    }

    private func stopEngine(status: String) {
        running = false
        self.status = status
        if installed {
            engine.inputNode.removeTap(onBus: 0)
            installed = false
        }
        if engine.isRunning { engine.stop() }
        detachStimulus()
        if let fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
            self.fftSetup = nil
        }
        frameBuffer.reset()
        if sessionActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            sessionActive = false
        }
    }

    private func recycleAndStart() {
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
            if fftSetup == nil {
                fftSetup = AudioBlockFFT.makeSetup()
            }
            guard let fftSetup else {
                status = "FFT setup failed"
                running = false
                return
            }
            if installed {
                input.removeTap(onBus: 0)
                installed = false
            }
            frameBuffer.reset()
            let sampleRate = format.sampleRate
            let scratch = frameBuffer
            let length = AudioBlockFFT.length
            let windows = windowBox
            let stimulusPlayer = player
            input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(length), format: format) { [weak self] buffer, _ in
                scratch.append(buffer)
                let reading = roomRigChannelReading(buffer)
                while let frame = scratch.pop(count: length) {
                    guard let magnitudes = AudioBlockFFT.magnitudes(
                        samples: frame,
                        setup: fftSetup,
                        window: windows.get()
                    ) else { continue }
                    let bands = AcousticSpectrum.fold(
                        linearMagnitudes: magnitudes,
                        sampleRate: sampleRate,
                        fftLength: length
                    )
                    let rta = RoomRigMath.thirdOctaveBands(
                        linearMagnitudes: magnitudes,
                        sampleRate: sampleRate,
                        fftLength: length
                    )
                    let stats = RoomRigMath.frameStats(samples: frame.map(Double.init))
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
                            fftLength: length
                        ) ?? []
                    } else {
                        harmonics = []
                    }
                    Task { @MainActor in
                        self?.publish(
                            bands: bands,
                            rta: rta,
                            rms: stats.rmsDBFS,
                            peak: stats.peakDBFS,
                            crestDB: stats.crestDB,
                            clipFraction: stats.clipFraction,
                            peakHz: peak,
                            sampleRateHz: sampleRate,
                            harmonicRatio: ratio,
                            harmonics: harmonics,
                            stimulusHz: snap.hz,
                            channelCount: reading.count,
                            balance: reading.balance,
                            latency: latency
                        )
                    }
                }
            }
            installed = true
            if wantsPlay {
                attachStimulus(format: format)
            }
            try engine.start()
            running = true
            status = engineStatus(playing: wantsPlay)
        } catch {
            status = "Could not start audio: \(error.localizedDescription)"
            running = false
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
            return sharing ? "Shared tap · phone speaker test signal" : "Phone speaker · relative mic"
        }
        return sharing ? "Shared microphone tap · audible FFT" : "Metering (uncalibrated dBFS)"
    }

    private func publish(
        bands: [AcousticDisplayBand],
        rta: [AcousticDisplayBand],
        rms: Double,
        peak: Double,
        crestDB: Double?,
        clipFraction: Double,
        peakHz: Double?,
        sampleRateHz: Double,
        harmonicRatio: Double?,
        harmonics: [RoomRigHarmonic],
        stimulusHz: Double?,
        channelCount: Int,
        balance: Double?,
        latency: Double?
    ) {
        if let latency {
            latencySeconds = latency
        }
        let now = Date()
        guard now.timeIntervalSince(lastPublish) >= 1.0 / 20.0 else { return }
        lastPublish = now
        self.bands = bands
        rtaBands = rta
        rmsDBFS = rms
        peakDBFS = peak
        self.crestDB = crestDB
        self.clipFraction = clipFraction
        self.peakHz = peakHz
        self.sampleRateHz = sampleRateHz
        self.harmonicRatio = harmonicRatio
        harmonicOrders = harmonics
        self.stimulusHz = stimulusHz
        if channelCount > 0 { inputChannelCount = channelCount }
        channelBalance = balance
        hasReading = true
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

/// Real FFT of a 1024-sample mic block. Bin k is `k * sampleRate / 1024`.
enum AudioBlockFFT {
    static let length = 1024
    static let log2n: vDSP_Length = 10

    static func makeSetup() -> FFTSetup? {
        vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
    }

    static func magnitudes(
        samples: [Float],
        setup: FFTSetup,
        window kind: SpectrumWindowKind = .hann
    ) -> [Double]? {
        let n = samples.count
        guard n == length else { return nil }
        let half = n / 2
        let window = CoupledVibrationMath.window(count: n, kind: kind).map { Float($0) }
        var windowed = [Float](repeating: 0, count: n)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(n))

        var realp = [Float](repeating: 0, count: half)
        var imagp = [Float](repeating: 0, count: half)
        var mags = [Float](repeating: 0, count: half)
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
                vDSP_zvmags(&split, 1, &mags, 1, vDSP_Length(half))
            }
        }
        // vDSP squares (vDSP_vsq / vDSP_zvmags) but has no element-wise square
        // root. vDSP_vsqrt is not an Accelerate symbol, so Xcode Cloud reports
        // "Cannot find 'vDSP_vsqrt' in scope". vForce is the vector sqrt.
        var rooted = [Float](repeating: 0, count: half)
        vForce.sqrt(mags, result: &rooted)
        return rooted.map(Double.init)
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

final class WindowBox: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: SpectrumWindowKind.hann)

    func get() -> SpectrumWindowKind {
        lock.withLock { $0 }
    }

    func set(_ kind: SpectrumWindowKind) {
        lock.withLock { $0 = kind }
    }
}
