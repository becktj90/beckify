import Combine
import CoreMotion
import SwiftUI
import BeckifyMath

private enum MagnetometerMode: String, CaseIterable, Identifiable {
    case read = "Read"
    case sweep = "Sweep"
    var id: String { rawValue }
}

@MainActor
final class MagnetometerModel: ObservableObject {
    @Published var x = 0.0
    @Published var y = 0.0
    @Published var z = 0.0
    @Published var magnitude = 0.0
    @Published var heading = 0.0
    @Published var available = false
    @Published var hasReading = false
    @Published var status = "Waiting for magnetometer…"
    @Published var sweepBaseline: Double?
    @Published var sweepDelta = 0.0
    @Published var sweepPeak = 0.0
    @Published var sweepTrace: [Double] = []
    @Published var variationBands: [VibrationBand] = []
    @Published var variationFs = 0.0

    private var variationSamples: [(t: Double, value: Double)] = []
    private var lastVariation = Date.distantPast
    private let sweepClock = Date()

    private let motion = CMMotionManager()
    private var started = false

    init() {
        available = motion.isDeviceMotionAvailable
            && CMMotionManager.availableAttitudeReferenceFrames().contains(.xMagneticNorthZVertical)
    }

    func start() {
        guard motion.isDeviceMotionAvailable,
              CMMotionManager.availableAttitudeReferenceFrames().contains(.xMagneticNorthZVertical) else {
            available = false
            status = "Magnetic-north device motion is not available on this hardware."
            return
        }
        if started { return }
        started = true
        motion.deviceMotionUpdateInterval = 1.0 / 20.0
        motion.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { [weak self] data, error in
            guard let self else { return }
            if let error {
                self.status = error.localizedDescription
                return
            }
            guard let data else { return }
            let f = data.magneticField.field
            self.x = f.x
            self.y = f.y
            self.z = f.z
            self.magnitude = MagneticMath.magnitudeMicrotesla(x: f.x, y: f.y, z: f.z)
            if data.heading >= 0 {
                self.heading = data.heading
            } else {
                self.heading = MagneticMath.headingDegrees(x: f.x, y: f.y)
            }
            self.hasReading = true
            self.status = "CMDeviceMotion magnetic field (µT), DC only"
            self.noteSweep()
        }
    }

    func stop() {
        guard started else { return }
        started = false
        motion.stopDeviceMotionUpdates()
    }

    func captureSweepBaseline() {
        guard hasReading else { return }
        sweepBaseline = magnitude
        sweepDelta = 0
        sweepPeak = 0
        sweepTrace = []
        variationSamples = []
        variationBands = []
        variationFs = 0
    }

    func resetSweep() {
        sweepBaseline = nil
        sweepDelta = 0
        sweepPeak = 0
        sweepTrace = []
        variationSamples = []
        variationBands = []
        variationFs = 0
    }

    private func noteSweep() {
        guard let baseline = sweepBaseline,
              let delta = MagSweepMath.deltaMicrotesla(magnitude: magnitude, baseline: baseline) else { return }
        sweepDelta = delta
        sweepPeak = MagSweepMath.peakHold(delta: delta, peak: sweepPeak)
        sweepTrace = MagSweepMath.appendTrace(sweepTrace, sample: delta)
        variationSamples.append((Date().timeIntervalSince(sweepClock), delta))
        if variationSamples.count > 128 { variationSamples.removeFirst(variationSamples.count - 128) }
        let now = Date()
        guard now.timeIntervalSince(lastVariation) >= 0.5, variationSamples.count >= 32 else { return }
        lastVariation = now
        let duration = variationSamples[variationSamples.count - 1].t - variationSamples[0].t
        guard let rate = CoupledVibrationMath.sampleRateHz(count: variationSamples.count, durationSeconds: duration),
              let signature = CoupledVibrationMath.signature(
                samples: variationSamples.map(\.value),
                sampleRateHz: rate,
                bandCount: 8
              ) else { return }
        variationFs = rate
        variationBands = signature.bands
    }
}

struct MagnetometerView: View {
    @EnvironmentObject private var jobs: JobStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = MagnetometerModel()
    @StoredInput(.magnetometer, "jobName", default: "Magnetic field") private var jobName
    @State private var notes = ""
    @State private var mode: MagnetometerMode = .read

    var body: some View {
        ToolScaffold(
            toolID: .magnetometer,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .sensor(extra: mode == .sweep
                ? MagSweepMath.honestLimit
                : "DC field only. The phone’s magnetometer is not a lab probe, a stud finder, or a 60 Hz EMF meter.")
        ) {
            ShowWorkCard(
                toolID: .magnetometer,
                symbolic: mode == .sweep
                    ? "Δ|B| = |B| − baseline    peak hold of |Δ|B||"
                    : "|B| = √(x² + y² + z²) µT    heading from xMagneticNorthZVertical",
                substituted: sticky,
                meaning: mode == .sweep
                    ? "Walk or slide the phone. Steel, magnets, and speakers show up as a change from the baseline you captured. Phone magnets dominate. This is DC |B|, not AC mains EMF."
                    : "Earth’s field is roughly 25–65 µT. Sweep mode is the delta from a baseline. This is not a survey compass or a 60 Hz EMF probe."
            )
            Picker("Mode", selection: $mode) {
                ForEach(MagnetometerMode.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            if !model.available {
                ToolEmptyState(title: "No magnetometer", detail: model.status, systemImage: "location.north.circle")
            }
            if mode == .read {
                ResultCard(title: "Field", copyText: copyText) {
                    ResultRow(label: "Magnitude", value: Format.microtesla(model.magnitude), emphasis: true, tone: Theme.good)
                    ResultRow(label: "Gauss", value: "\(Format.number(MagneticMath.gauss(fromMicrotesla: model.magnitude), digits: 3)) G")
                    ResultRow(label: "Heading", value: Format.degrees(model.heading), emphasis: true)
                    ResultRow(label: "Bx", value: Format.microtesla(model.x))
                    ResultRow(label: "By", value: Format.microtesla(model.y))
                    ResultRow(label: "Bz", value: Format.microtesla(model.z))
                    ResultRow(label: "Source", value: model.status)
                }
            } else {
                ResultCard(title: "Mag Sweep", copyText: copyText) {
                    ResultRow(label: "|B| now", value: Format.microtesla(model.magnitude), emphasis: true)
                    ResultRow(
                        label: "Baseline",
                        value: model.sweepBaseline.map { Format.microtesla($0) } ?? "Not captured"
                    )
                    ResultRow(
                        label: "Δ|B|",
                        value: model.sweepBaseline == nil ? "—" : signedMicrotesla(model.sweepDelta),
                        emphasis: true,
                        tone: Theme.good
                    )
                    ResultRow(
                        label: "Peak |Δ|",
                        value: model.sweepBaseline == nil ? "—" : Format.microtesla(model.sweepPeak),
                        tone: Theme.warn
                    )
                    Text("DC field variation along the path. Not a 60 Hz EMF meter, not a stud finder, and not a live-wire detector.")
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                    TraceSparkline(
                        samples: model.sweepTrace,
                        accessibilityLabel: model.sweepTrace.count < 2
                            ? "Mag sweep trace waiting for a baseline. Vertical axis is field change in microtesla."
                            : "Mag sweep of DC field change in microtesla versus time.",
                        yAxis: PlotAxis(title: "Field change", unit: "µT", start: "", end: ""),
                        xAxis: PlotAxis(title: "Time", unit: "", start: "older", end: "now"),
                        fullscreenTitle: "Mag sweep"
                    )
                    .padding(.top, 6)
                    Text(MagSweepMath.variationSpectrumLabel)
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 8)
                    Text(variationCaption)
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                    SpectrumPlot(
                        heights: variationHeights,
                        leadingCaption: "0 Hz",
                        trailingCaption: variationNyquist,
                        footnote: "Slow change in DC |B|. Phone magnets dominate. Nyquist is half the delivered rate, far below 50/60 Hz, so this cannot isolate mains hum.",
                        plotHeight: 88,
                        accessibilityLabel: "Field variation spectrum. Frequency in hertz, height relative to the peak change. Not AC EMF.",
                        xAxis: PlotAxis(title: "Frequency", unit: "Hz", start: "0 Hz", end: variationNyquist),
                        yAxis: PlotAxis(title: "Relative change", unit: "relative", start: "0", end: "1"),
                        barReadouts: model.variationBands.map { band in
                            "\(Format.number(band.centerHz, digits: 2)) Hz, relative \(Format.number(band.magnitudeG, digits: 3))"
                        }
                    )
                }
                HStack {
                    Button("Capture baseline") { model.captureSweepBaseline() }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                    Button("Reset sweep") { model.resetSweep() }
                        .buttonStyle(.bordered)
                        .tint(Theme.accent)
                }
                .frame(minHeight: Theme.touchTarget)
            }
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

    private var sticky: String? {
        guard model.hasReading else { return nil }
        if mode == .sweep, model.sweepBaseline != nil {
            return "Δ \(signedMicrotesla(model.sweepDelta))  ·  peak \(Format.microtesla(model.sweepPeak))"
        }
        return "\(Format.microtesla(model.magnitude))  ·  \(Format.degrees(model.heading))"
    }

    private var copyText: String? {
        guard model.hasReading else { return nil }
        if mode == .sweep {
            let base = model.sweepBaseline.map { Format.microtesla($0) } ?? "—"
            return "Mag Sweep Δ \(model.sweepBaseline == nil ? "—" : signedMicrotesla(model.sweepDelta)), peak \(Format.microtesla(model.sweepPeak)), baseline \(base). DC only."
        }
        return sticky
    }

    private var variationHeights: [Double] {
        let peak = model.variationBands.map(\.magnitudeG).max() ?? 0
        guard peak > 1e-9 else { return model.variationBands.map { _ in 0 } }
        return model.variationBands.map { min(1, max(0, $0.magnitudeG / peak)) }
    }

    private var variationNyquist: String {
        guard let nyquist = CoupledVibrationMath.nyquistHz(sampleRateHz: model.variationFs) else { return "—" }
        return "\(Format.number(nyquist, digits: 1)) Hz"
    }

    private var variationCaption: String {
        guard model.variationFs > 0 else { return "Capture a baseline and move slowly. The spectrum appears after a short trace." }
        return "Delivered fs \(Format.number(model.variationFs, digits: 1)) Hz · Nyquist \(variationNyquist)."
    }

    private func signedMicrotesla(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "−"
        return "\(sign)\(Format.microtesla(abs(value)))"
    }

    private func save() {
        var outputs = [
            "|B|": Format.microtesla(model.magnitude),
            "G": "\(Format.number(MagneticMath.gauss(fromMicrotesla: model.magnitude), digits: 3)) G",
            "heading": Format.degrees(model.heading),
            "Bx": Format.microtesla(model.x),
            "By": Format.microtesla(model.y),
            "Bz": Format.microtesla(model.z),
        ]
        if let baseline = model.sweepBaseline {
            outputs["sweep baseline"] = Format.microtesla(baseline)
            outputs["sweep delta"] = signedMicrotesla(model.sweepDelta)
            outputs["sweep peak"] = Format.microtesla(model.sweepPeak)
        }
        jobs.save(SavedJob(
            name: jobName,
            toolID: .magnetometer,
            notes: notes,
            inputs: ["units": "µT", "mode": mode.rawValue],
            outputs: outputs
        ))
    }
}

