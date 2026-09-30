import Accelerate
import AVFoundation
import SwiftUI
import BeckifyMath

/// Accumulates mic frames on the audio thread until a power-of-two FFT block is ready.
private final class AcousticFrameBuffer: @unchecked Sendable {
    private var left: [Float] = []
    private var right: [Float] = []
    private var hasRight = false

    func reset() {
        left.removeAll(keepingCapacity: true)
        right.removeAll(keepingCapacity: true)
        hasRight = false
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }
        left.append(contentsOf: UnsafeBufferPointer(start: channels[0], count: frames))
        if buffer.format.channelCount >= 2 {
            hasRight = true
            right.append(contentsOf: UnsafeBufferPointer(start: channels[1], count: frames))
        }
        let cap = 8192
        if left.count > cap {
            left.removeFirst(left.count - cap)
            if hasRight, right.count > cap { right.removeFirst(right.count - cap) }
        }
    }

    func pop(count: Int) -> (left: [Float], right: [Float]?)? {
        guard left.count >= count else { return nil }
        let leftBlock = Array(left.prefix(count))
        left.removeFirst(count)
        var rightBlock: [Float]?
        if hasRight, right.count >= count {
            rightBlock = Array(right.prefix(count))
            right.removeFirst(count)
        }
        return (leftBlock, rightBlock)
    }
}

@MainActor
final class AcousticImagerModel: ObservableObject {
    @Published var bands: [AcousticDisplayBand] = []
    @Published var history: [[Double]] = []
    @Published var overallDBFS: Double = SoundLevel.silenceFloorDBFS
    @Published var peakHz: Double?
    @Published var balance: Double?
    @Published var channelCount = 0
    @Published var permissionDenied = false
    @Published var running = false
    @Published var hasReading = false
    @Published var status = "Microphone idle"

    private let engine = AVAudioEngine()
    private var installed = false
    private var wantsRunning = false
    private var fftSetup: FFTSetup?
    private let fftLength = 1024
    private let frameBuffer = AcousticFrameBuffer()
    private var lastPublish = Date.distantPast

    func start() {
        wantsRunning = true
        requestThenRun()
    }

    func stop() {
        wantsRunning = false
        running = false
        status = "Microphone idle"
        if installed {
            engine.inputNode.removeTap(onBus: 0)
            installed = false
        }
        if engine.isRunning { engine.stop() }
        if let fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
            self.fftSetup = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestThenRun() {
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

    private func beginEngine() {
        guard wantsRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.mixWithOthers])
            try session.setActive(true)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                status = "No microphone format"
                running = false
                return
            }
            if fftSetup == nil {
                fftSetup = vDSP_create_fftsetup(10, FFTRadix(kFFTRadix2))
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
            channelCount = Int(format.channelCount)
            let scratch = frameBuffer
            let length = fftLength
            input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(length), format: format) { [weak self] buffer, _ in
                scratch.append(buffer)
                while let frame = scratch.pop(count: length) {
                    guard let magnitudes = Self.magnitudes(samples: frame.left, setup: fftSetup) else { continue }
                    let bands = AcousticSpectrum.fold(
                        linearMagnitudes: magnitudes,
                        sampleRate: sampleRate,
                        fftLength: length
                    )
                    let overall = SoundLevel.dbfs(rms: Self.rms(frame.left))
                    let balance: Double?
                    if let right = frame.right {
                        balance = AcousticSpectrum.channelBalance(
                            leftRMS: Self.rms(frame.left),
                            rightRMS: Self.rms(right)
                        )
                    } else {
                        balance = nil
                    }
                    let peak = AcousticSpectrum.peakBand(bands)?.centerHz
                    Task { @MainActor in
                        self?.publish(bands: bands, overall: overall, peakHz: peak, balance: balance)
                    }
                }
            }
            installed = true
            try engine.start()
            running = true
            status = channelCount >= 2
                ? "Spectrum on device · two channels · not a bearing"
                : "Spectrum on device · one mic · not a bearing"
        } catch {
            status = "Could not start audio: \(error.localizedDescription)"
            running = false
        }
    }

    private func publish(bands: [AcousticDisplayBand], overall: Double, peakHz: Double?, balance: Double?) {
        let now = Date()
        guard now.timeIntervalSince(lastPublish) >= 1.0 / 15.0 else { return }
        lastPublish = now
        self.bands = bands
        self.overallDBFS = overall
        self.peakHz = peakHz
        self.balance = balance
        hasReading = true
        var row = bands.map(\.dbFS)
        if row.isEmpty { row = [SoundLevel.silenceFloorDBFS] }
        history.append(row)
        if history.count > 36 { history.removeFirst(history.count - 36) }
    }

    nonisolated private static func rms(_ samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }
        var sum = 0.0
        for sample in samples {
            let value = Double(sample)
            sum += value * value
        }
        return sqrt(sum / Double(samples.count))
    }

    /// Real FFT magnitude per bin. Bin k is `k * sampleRate / 1024`.
    nonisolated private static func magnitudes(samples: [Float], setup: FFTSetup) -> [Double]? {
        let n = samples.count
        guard n == 1024 else { return nil }
        let half = n / 2
        var window = [Float](repeating: 0, count: n)
        for index in 0..<n {
            let phase = 2 * Float.pi * Float(index) / Float(n - 1)
            window[index] = 0.5 * (1 - cos(phase))
        }
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
                vDSP_fft_zrip(setup, &split, 1, 10, FFTDirection(kFFTDirection_Forward))
                vDSP_zvmags(&split, 1, &mags, 1, vDSP_Length(half))
            }
        }
        var rooted = [Float](repeating: 0, count: half)
        vDSP_vsqrt(mags, 1, &rooted, 1, vDSP_Length(half))
        return rooted.map(Double.init)
    }
}

struct AcousticImagerView: View {
    @EnvironmentObject private var jobs: JobStore
    @StateObject private var model = AcousticImagerModel()
    @StoredInput(.acousticImager, "jobName", default: "Acoustic snapshot") private var jobName
    @State private var notes = ""

    var body: some View {
        ToolScaffold(
            toolID: .acousticImager,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .sensor(extra: "Field visualization only. Not a Fluke acoustic camera, not ultrasonic beamforming, not a gas-leak certification, and not a calibrated SPL meter. Saving stores numbers — not a recording.")
        ) {
            ShowWorkCard(
                toolID: .acousticImager,
                symbolic: "Band dBFS from an on-device real FFT",
                substituted: sticky,
                meaning: "The microphone tap feeds an Accelerate FFT. Bars and the level map are relative energy in the audible band the phone actually captured. A left/right shift is channel balance when a second channel exists. It is not a bearing."
            )
            if model.permissionDenied {
                ToolEmptyState(
                    title: "Microphone is off",
                    detail: "Acoustic Imager needs the microphone for a live spectrum. Nothing is recorded or uploaded.",
                    systemImage: "mic.slash",
                    showsSettings: true
                )
            }
            ResultCard(title: "Spectrum", copyText: copyText) {
                ResultRow(label: "Level", value: Format.dbfs(model.overallDBFS), emphasis: true, tone: Theme.good)
                ResultRow(label: "Peak band", value: peakLabel, tone: Theme.copper)
                ResultRow(label: "Channels", value: model.channelCount >= 2 ? "2 · balance only" : "1 · no bearing")
                ResultRow(label: "Engine", value: model.status)
                AcousticSpectrumBars(bands: model.bands)
                    .padding(.top, 8)
            }
            ResultCard(title: "Level map") {
                Text("Recent audible bands. Brighter means more relative energy on this phone. Not SPL, not ultrasonic.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                AcousticLevelMap(history: model.history)
                    .padding(.top, 6)
            }
            ResultCard(title: "Directional-ish heat") {
                Text(directionCaption)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                AcousticBalanceHeat(balance: model.balance, level: model.overallDBFS, hasReading: model.hasReading)
                    .padding(.top, 6)
            }
            SaveJobBar(jobName: $jobName, notes: $notes, canSave: model.hasReading) { save() }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var sticky: String? {
        guard model.hasReading else { return nil }
        return "\(Format.dbfs(model.overallDBFS)) · \(peakLabel)"
    }

    private var copyText: String? {
        guard model.hasReading else { return nil }
        return "\(Format.dbfs(model.overallDBFS)), peak band \(peakLabel). Not SPL. Not ultrasonic. Not a gas-leak camera."
    }

    private var peakLabel: String {
        guard let hz = model.peakHz, hz.isFinite else { return "—" }
        return "\(Format.number(hz, digits: 0)) Hz"
    }

    private var directionCaption: String {
        if model.channelCount >= 2 {
            return "Dot shifts with left/right channel energy. That is not a sound-camera bearing and not beamforming."
        }
        return "This input is one microphone. The dot stays centered and only grows with level. Not a direction."
    }

    private func save() {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .acousticImager,
            notes: notes,
            inputs: ["formula": "on-device FFT bands, audible ceiling 8 kHz"],
            outputs: [
                "dBFS": Format.dbfs(model.overallDBFS),
                "peakHz": peakLabel,
                "channels": model.channelCount >= 2 ? "2" : "1",
                "balance": model.balance.map { Format.number($0, digits: 2) } ?? "none — not a bearing",
                "spl": "not claimed",
                "ultrasonic": "not claimed",
            ]
        ))
    }
}

private struct AcousticSpectrumBars: View {
    var bands: [AcousticDisplayBand]

    var body: some View {
        Canvas { context, size in
            let count = bands.count
            guard count > 0 else { return }
            let gap: CGFloat = 2
            let width = max(1, (size.width - gap * CGFloat(count - 1)) / CGFloat(count))
            for (index, band) in bands.enumerated() {
                let heat = CGFloat(AcousticSpectrum.heat(dbFS: band.dbFS))
                let bar = max(2, size.height * heat)
                let rect = CGRect(
                    x: CGFloat(index) * (width + gap),
                    y: size.height - bar,
                    width: width,
                    height: bar
                )
                context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(barColor(heat)))
            }
        }
        .frame(height: 112)
        .accessibilityLabel(bands.isEmpty ? "Spectrum idle" : "Audible spectrum, \(bands.count) bands")
    }

    private func barColor(_ heat: CGFloat) -> Color {
        if heat > 0.72 { return Theme.bad }
        if heat > 0.4 { return Theme.warn }
        return Theme.accent
    }
}

private struct AcousticLevelMap: View {
    var history: [[Double]]

    var body: some View {
        Canvas { context, size in
            let rows = history
            guard !rows.isEmpty else {
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.surfaceRaised))
                return
            }
            let rowH = size.height / CGFloat(rows.count)
            for (rowIndex, row) in rows.enumerated() {
                let cols = row.count
                guard cols > 0 else { continue }
                let colW = size.width / CGFloat(cols)
                for (colIndex, db) in row.enumerated() {
                    let heat = AcousticSpectrum.heat(dbFS: db)
                    let rect = CGRect(
                        x: CGFloat(colIndex) * colW,
                        y: CGFloat(rowIndex) * rowH,
                        width: colW + 0.5,
                        height: rowH + 0.5
                    )
                    context.fill(Path(rect), with: .color(cellColor(heat)))
                }
            }
        }
        .frame(height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel("Level map of recent audible bands")
    }

    private func cellColor(_ heat: Double) -> Color {
        if heat < 0.08 { return Theme.surfaceRaised }
        if heat > 0.72 { return Theme.bad.opacity(0.55 + heat * 0.4) }
        if heat > 0.4 { return Theme.warn.opacity(0.45 + heat * 0.4) }
        return Theme.accent.opacity(0.25 + heat * 0.7)
    }
}

private struct AcousticBalanceHeat: View {
    var balance: Double?
    var level: Double
    var hasReading: Bool

    var body: some View {
        GeometryReader { geo in
            let heat = hasReading ? AcousticSpectrum.heat(dbFS: level) : 0
            let xFraction = 0.5 + 0.34 * (balance ?? 0)
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.surfaceRaised)
                Circle()
                    .fill(Theme.energized.opacity(0.35 + heat * 0.6))
                    .frame(width: 18 + CGFloat(heat) * 28, height: 18 + CGFloat(heat) * 28)
                    .position(x: geo.size.width * xFraction, y: geo.size.height / 2)
            }
        }
        .frame(height: 72)
        .accessibilityLabel(balance == nil ? "Single microphone, no direction" : "Channel balance, not a bearing")
    }
}
