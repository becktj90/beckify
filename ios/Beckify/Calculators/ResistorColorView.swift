import SwiftUI
import BeckifyMath

struct ResistorColorView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case decode4 = "4-band"
        case decode5 = "5-band"
        case encode = "Encode"
        var id: String { rawValue }
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.resistorColor, "mode", default: Mode.decode4) private var mode
    @StoredChoice(.resistorColor, "d1", default: ResistorBand.yellow) private var d1
    @StoredChoice(.resistorColor, "d2", default: ResistorBand.violet) private var d2
    @StoredChoice(.resistorColor, "d3", default: ResistorBand.black) private var d3
    @StoredChoice(.resistorColor, "multiplier", default: ResistorBand.red) private var multiplier
    @StoredChoice(.resistorColor, "tolerance", default: ResistorBand.gold) private var tolerance
    @StoredInput(.resistorColor, "ohms", default: "4700") private var ohms
    @StoredCount(.resistorColor, "encodeBands", default: 4) private var encodeBands
    @StoredInput(.resistorColor, "jobName", default: "Color code") private var jobName
    @State private var live = LiveCalculationState<ColorCodeResult>()

    private var digitBands: [ResistorBand] { ResistorBand.allCases.filter { $0.digit != nil } }
    private var multiplierBands: [ResistorBand] { ResistorBand.allCases.filter { $0.multiplier != nil } }
    private var toleranceBands: [ResistorBand] { ResistorBand.allCases.filter { $0.tolerancePercent != nil } }

    private var inputFingerprint: String {
        "\(mode)|\(d1)|\(d2)|\(d3)|\(multiplier)|\(tolerance)|\(ohms)|\(encodeBands)"
    }

    var body: some View {
        ToolScaffold(toolID: .resistorColor, stickyAnswer: sticky, copyText: copyText) {
            ShowWorkCard(
                toolID: .resistorColor,
                symbolic: "4-band: (10×d1 + d2) × 10^n    5-band: (100×d1 + 10×d2 + d3) × 10^n",
                substituted: substituted,
                meaning: "IEC 60062 colors. Encode rounds the significand to integer digits. Yellow-violet-red-gold is the classic 4.7 kΩ 5%."
            )
            TryExampleButton(title: "Yellow · violet · red · gold = 4.7 kΩ") {
                mode = .decode4
                d1 = .yellow
                d2 = .violet
                multiplier = .red
                tolerance = .gold
                live.update { try computeResult() }
            }
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .segmentedControlStyle()
            if mode == .encode {
                NumberField(title: "Resistance", unit: "Ω", text: $ohms)
                Picker("Bands", selection: $encodeBands) {
                    Text("4").tag(4)
                    Text("5").tag(5)
                }
                .segmentedControlStyle()
                MenuField(title: "Tolerance", selection: $tolerance, options: toleranceBands) { $0.displayName }
            } else {
                MenuField(title: "Digit 1", selection: $d1, options: digitBands) { $0.displayName }
                MenuField(title: "Digit 2", selection: $d2, options: digitBands) { $0.displayName }
                if mode == .decode5 {
                    MenuField(title: "Digit 3", selection: $d3, options: digitBands) { $0.displayName }
                }
                MenuField(title: "Multiplier", selection: $multiplier, options: multiplierBands) { $0.displayName }
                MenuField(title: "Tolerance", selection: $tolerance, options: toleranceBands) { $0.displayName }
            }

            if let error = live.error {
                ErrorText(message: error.message)
            } else if let r = live.result {
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Resistance", value: "\(Format.number(r.ohms, digits: 4)) Ω", emphasis: true, tone: Theme.good)
                    ResultRow(label: "Tolerance", value: "± \(Format.number(r.tolerancePercent, digits: 2)) %")
                    ResultRow(label: "Bands", value: r.bands.map(\.displayName).joined(separator: " · "))
                }
                SaveJobBar(jobName: $jobName, canSave: true) { save(r) }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            live.update { try computeResult() }
        }
        .onAppear {
            live.update { try computeResult() }
        }
    }

    private func computeResult() throws -> ColorCodeResult {
        switch mode {
        case .decode4:
            return try ResistorColorCode.decode4(d1: d1, d2: d2, multiplier: multiplier, tolerance: tolerance)
        case .decode5:
            return try ResistorColorCode.decode5(d1: d1, d2: d2, d3: d3, multiplier: multiplier, tolerance: tolerance)
        case .encode:
            return try ResistorColorCode.encode(ohms: ohms.parsedDouble ?? .nan, bands: encodeBands, tolerance: tolerance)
        }
    }

    private var substituted: String? {
        guard let r = live.result else { return nil }
        return "\(r.formula)  →  \(Format.number(r.ohms, digits: 4)) Ω ± \(Format.number(r.tolerancePercent, digits: 2)) %"
    }

    private var sticky: String? {
        guard let r = live.result else { return nil }
        return "\(Format.number(r.ohms, digits: 4)) Ω  ± \(Format.number(r.tolerancePercent, digits: 2)) %"
    }

    private var copyText: String? { sticky }

    private func save(_ r: ColorCodeResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .resistorColor,
            inputs: [
                "mode": mode.rawValue,
                "d1": d1.rawValue,
                "d2": d2.rawValue,
                "d3": d3.rawValue,
                "multiplier": multiplier.rawValue,
                "tolerance": tolerance.rawValue,
                "ohms": ohms,
                "encodeBands": "\(encodeBands)",
            ],
            outputs: [
                "R": "\(Format.number(r.ohms, digits: 4)) Ω",
                "tol": "± \(Format.number(r.tolerancePercent, digits: 2)) %",
                "bands": r.bands.map(\.displayName).joined(separator: " · "),
            ]
        ))
    }
}
