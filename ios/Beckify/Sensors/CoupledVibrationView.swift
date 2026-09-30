import Combine
import CoreMotion
import SwiftUI
import BeckifyMath

@MainActor
final class CoupledVibrationModel: ObservableObject {
    @Published var available = false
    @Published var hasReading = false
    @Published var status = "Waiting for device motion…"
    @Published var liveRMS = 0.0
    @Published var rmsX = 0.0
    @Published var rmsY = 0.0
    @Published var rmsZ = 0.0
    @Published var bands: [VibrationBand] = []
    @Published var peakHz: Double?
    @Published var peakMagnitude = 0.0
    @Published var sampleRateHz = 0.0
    @Published var signatureA: VibrationSignature?
    @Published var signatureB: VibrationSignature?
    @Published var trace: [Double] = []

    private let motion = CMMotionManager()
    private var started = false
    private var samples: [(t: Double, x: Double, y: Double, z: Double, mag: Double)] = []
    private let startedAt = Date()
    private var lastSpectrum = Date.distantPast

    func start() {
        guard motion.isDeviceMotionAvailable else {
            available = false
            status = "Device motion is not available."
            return
        }
        if started { return }
        available = true
        started = true
        motion.deviceMotionUpdateInterval = 1.0 / 100.0
        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let user = data.userAcceleration
            let g = MotionMath.magnitudeG(x: user.x, y: user.y, z: user.z)
            let t = Date().timeIntervalSince(self.startedAt)
            self.samples.append((t, user.x, user.y, user.z, g))
            if self.samples.count > 160 { self.samples.removeFirst(self.samples.count - 160) }
            self.trace = MagSweepMath.appendTrace(self.trace, sample: g, limit: 80)
            self.hasReading = true
            self.status = "CoreMotion user acceleration · relative spectrum"
            self.refreshSpectrumIfDue()
        }
    }

    func stop() {
        guard started else { return }
        started = false
        motion.stopDeviceMotionUpdates()
    }

    func captureA() {
        signatureA = currentSignature()
    }

    func captureB() {
        signatureB = currentSignature()
    }

    func resetCompare() {
        signatureA = nil
        signatureB = nil
    }

    var comparison: VibrationComparison? {
        guard let signatureA, let signatureB else { return nil }
        return CoupledVibrationMath.compare(signatureA, signatureB)
    }

    private func currentSignature() -> VibrationSignature? {
        CoupledVibrationMath.signature(samples: windowValues(), sampleRateHz: sampleRateHz)
    }

    private func refreshSpectrumIfDue() {
        let now = Date()
        guard now.timeIntervalSince(lastSpectrum) >= 0.12 else { return }
        lastSpectrum = now
        let window = Array(samples.suffix(128))
        guard window.count >= 16 else { return }
        let duration = window[window.count - 1].t - window[0].t
        guard let rate = CoupledVibrationMath.sampleRateHz(count: window.count, durationSeconds: duration) else { return }
        let values = window.map(\.mag)
        sampleRateHz = rate
        liveRMS = CoupledVibrationMath.rms(values)
        rmsX = CoupledVibrationMath.rms(window.map(\.x))
        rmsY = CoupledVibrationMath.rms(window.map(\.y))
        rmsZ = CoupledVibrationMath.rms(window.map(\.z))
        if let signature = CoupledVibrationMath.signature(samples: values, sampleRateHz: rate) {
            bands = signature.bands
        }
        if let peak = CoupledVibrationMath.peakBin(samples: values, sampleRateHz: rate), peak.magnitude >= 0.015 {
            peakHz = peak.hz
            peakMagnitude = peak.magnitude
        } else {
            peakHz = nil
            peakMagnitude = 0
        }
    }

    private func windowValues() -> [Double] {
        Array(samples.suffix(128)).map(\.mag)
    }
}

struct CoupledVibrationView: View {
    @EnvironmentObject private var jobs: JobStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = CoupledVibrationModel()
    @StoredInput(.coupledVibration, "jobName", default: "Coupled vibration") private var jobName
    @State private var notes = ""

    var body: some View {
        ToolScaffold(
            toolID: .coupledVibration,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .sensor(extra: CoupledVibrationMath.honestLimit + " Distinct from g-Force Snapshot.")
        ) {
            ShowWorkCard(
                toolID: .coupledVibration,
                symbolic: "RMS of user acceleration    Hann DFT, relative bins",
                substituted: sticky,
                meaning: "Press the phone to a machine or duct. The plot is the shape of this phone’s user acceleration, not a calibrated pickup and not ISO 10816. g-Force Snapshot is the separate one-reading tool."
            )
            Text(CoupledVibrationMath.honestLimit)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
            if !model.available {
                ToolEmptyState(title: "No device motion", detail: model.status, systemImage: "gyroscope")
            }
            ResultCard(title: "Live signature", copyText: copyText) {
                ResultRow(label: "RMS |a|", value: gText(model.liveRMS), emphasis: true, tone: Theme.good)
                ResultRow(label: "RMS x / y / z", value: "\(Format.number(model.rmsX, digits: 3)) / \(Format.number(model.rmsY, digits: 3)) / \(Format.number(model.rmsZ, digits: 3)) g")
                ResultRow(label: "Peak frequency", value: peakLabel, emphasis: true, tone: Theme.copper)
                ResultRow(label: "Relative rpm", value: rpmLabel)
                ResultRow(label: "Delivered fs", value: rateLabel(model.sampleRateHz))
                ResultRow(label: "Nyquist", value: nyquistLabel)
                ResultRow(label: "Source", value: model.status)
                Text(CoupledVibrationMath.rpmDisclaimer)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                Text("Plot stops at the delivered Nyquist (fs/2). This stream is not a 0–400 Hz analyzer.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
            }
            DiagramCard(
                title: "Vibration spectrum",
                accessibilitySummary: shareSummary,
                exportName: "beckify-coupled-vibration"
            ) {
                SpectrumPlot(
                    heights: plotHeights,
                    leadingCaption: "0 Hz",
                    trailingCaption: nyquistLabel,
                    footnote: "Magnitude FFT, Hann window. Peak dot is the tallest relative bin. Not ISO 10816.",
                    plotHeight: 140,
                    accessibilityLabel: "Live relative vibration spectrum",
                    peakIndex: plotHeights.indices.max { plotHeights[$0] < plotHeights[$1] }
                )
                TraceSparkline(samples: model.trace, accessibilityLabel: "Recent user-acceleration trace")
                    .padding(.top, 4)
            }
            ResultCard(title: "Session A / B") {
                ResultRow(label: "A RMS", value: model.signatureA.map { gText($0.rmsG) } ?? "—")
                ResultRow(label: "B RMS", value: model.signatureB.map { gText($0.rmsG) } ?? "—")
                if let comparison = model.comparison {
                    ResultRow(
                        label: "B − A",
                        value: signedG(comparison.rmsDelta),
                        emphasis: true,
                        tone: Theme.warn
                    )
                    ResultRow(
                        label: "Peak shift",
                        value: comparison.peakShiftHz.map { "\(Format.number($0, digits: 1)) Hz" } ?? "—"
                    )
                    SpectrumPlot(
                        heights: comparisonHeights(comparison),
                        leadingCaption: "A",
                        trailingCaption: "B",
                        plotHeight: 72,
                        accessibilityLabel: "Session B minus session A by band"
                    )
                } else {
                    Text("Capture two short presses. The difference is relative on this phone only.")
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                }
            }
            HStack {
                Button("Capture A") { model.captureA() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                Button("Capture B") { model.captureB() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                Button("Clear") { model.resetCompare() }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
            }
            .frame(minHeight: Theme.touchTarget)
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

    private var plotHeights: [Double] {
        let peak = model.bands.map(\.magnitudeG).max() ?? 0
        guard peak > 1e-6 else { return model.bands.map { _ in 0 } }
        return model.bands.map { min(1, max(0, $0.magnitudeG / peak)) }
    }

    private func comparisonHeights(_ comparison: VibrationComparison) -> [Double] {
        let span = comparison.bandDeltas.map(abs).max() ?? 0
        guard span > 1e-6 else { return comparison.bandDeltas.map { _ in 0 } }
        return comparison.bandDeltas.map { min(1, max(0, abs($0) / span)) }
    }

    private var peakLabel: String {
        guard let hz = model.peakHz, hz.isFinite else { return "—" }
        return "\(Format.number(hz, digits: 1)) Hz"
    }

    private var rpmLabel: String {
        guard let hz = model.peakHz, let rpm = CoupledVibrationMath.relativeRPM(frequencyHz: hz) else { return "—" }
        return "\(Format.number(rpm, digits: 0)) rpm"
    }

    private var nyquistLabel: String {
        guard let nyquist = CoupledVibrationMath.nyquistHz(sampleRateHz: model.sampleRateHz) else { return "—" }
        return "\(Format.number(nyquist, digits: 0)) Hz"
    }

    private func rateLabel(_ hz: Double) -> String {
        hz > 0 ? "\(Format.number(hz, digits: 0)) Hz" : "—"
    }

    private var shareSummary: String {
        let stamp = CoupledVibrationView.stamp.string(from: Date())
        return "\(stamp). Delivered fs \(rateLabel(model.sampleRateHz)), Nyquist \(nyquistLabel), peak \(peakLabel), relative \(rpmLabel). \(CoupledVibrationMath.rpmDisclaimer) No location."
    }

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    private func gText(_ value: Double) -> String {
        "\(Format.number(value, digits: 3)) g"
    }

    private func signedG(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "−"
        return "\(sign)\(Format.number(abs(value), digits: 3)) g"
    }

    private var sticky: String? {
        guard model.hasReading else { return nil }
        return "RMS \(gText(model.liveRMS)) · \(peakLabel)"
    }

    private var copyText: String? {
        guard model.hasReading else { return nil }
        return "Coupled vibration RMS \(gText(model.liveRMS)), peak \(peakLabel). Relative signature, not ISO 10816."
    }

    private func save() {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .coupledVibration,
            notes: notes,
            inputs: ["sensor": "user acceleration"],
            outputs: [
                "rms g": Format.number(model.liveRMS, digits: 3),
                "peak Hz": peakLabel,
                "A rms": model.signatureA.map { Format.number($0.rmsG, digits: 3) } ?? "—",
                "B rms": model.signatureB.map { Format.number($0.rmsG, digits: 3) } ?? "—",
                "standard": "not ISO 10816",
            ]
        ))
    }
}
