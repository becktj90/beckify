import Accelerate
import AVFoundation
import Combine
import os
import SwiftUI
import BeckifyMath

/// One microphone tap for Noise Meter, Acoustic Imager, and Stillness Anomaly Watch.
///
/// A second screen that wants the mic joins this tap instead of installing another
/// `AVAudioEngine` tap. Breath Flute calls `suspendForTone()` so a play-along
/// tone does not fight the metering engine.
@MainActor
final class MicrophoneSpectrumCenter: ObservableObject {
    static let shared = MicrophoneSpectrumCenter()

    @Published private(set) var bands: [AcousticDisplayBand] = []
    @Published private(set) var rmsDBFS: Double = SoundLevel.silenceFloorDBFS
    @Published private(set) var peakDBFS: Double = SoundLevel.silenceFloorDBFS
    @Published private(set) var peakHz: Double?
    @Published private(set) var sampleRateHz: Double = 0
    @Published private(set) var harmonicRatio: Double?
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
            try session.setCategory(.record, mode: .measurement, options: [.mixWithOthers])
            try session.setActive(true)
            sessionActive = true
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                status = "No microphone format"
                running = false
                return
            }
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
            input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(length), format: format) { [weak self] buffer, _ in
                scratch.append(buffer)
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
                    let levels = BreathFluteMath.levelDBFS(samples: frame)
                    let peak = AcousticSpectrum.peakBand(bands)?.centerHz
                    let ratio = RelativeHarmonicEnergy.ratio(linearMagnitudes: magnitudes)
                    Task { @MainActor in
                        self?.publish(
                            bands: bands,
                            rms: levels.rms,
                            peak: levels.peak,
                            peakHz: peak,
                            sampleRateHz: sampleRate,
                            harmonicRatio: ratio
                        )
                    }
                }
            }
            installed = true
            try engine.start()
            running = true
            status = sharing ? "Shared microphone tap · audible FFT" : "Metering (uncalibrated dBFS)"
        } catch {
            status = "Could not start audio: \(error.localizedDescription)"
            running = false
        }
    }

    private func publish(
        bands: [AcousticDisplayBand],
        rms: Double,
        peak: Double,
        peakHz: Double?,
        sampleRateHz: Double,
        harmonicRatio: Double?
    ) {
        let now = Date()
        guard now.timeIntervalSince(lastPublish) >= 1.0 / 20.0 else { return }
        lastPublish = now
        self.bands = bands
        rmsDBFS = rms
        peakDBFS = peak
        self.peakHz = peakHz
        self.sampleRateHz = sampleRateHz
        self.harmonicRatio = harmonicRatio
        hasReading = true
        if sharing, running {
            status = "Shared microphone tap · audible FFT"
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
        var window = CoupledVibrationMath.window(count: n, kind: kind).map { Float($0) }
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
