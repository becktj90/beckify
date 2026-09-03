import SwiftUI
import BeckifyMath

struct VoltageDividerView: View {
    enum Solve: String, CaseIterable, Identifiable {
        case vout = "Vout"
        case r1 = "R1"
        case r2 = "R2"
        var id: String { rawValue }
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.voltageDivider, "solve", default: Solve.vout) private var solve
    @StoredInput(.voltageDivider, "vin", default: "12") private var vin
    @StoredInput(.voltageDivider, "vout", default: "6") private var vout
    @StoredInput(.voltageDivider, "r1", default: "10000") private var r1
    @StoredInput(.voltageDivider, "r2", default: "10000") private var r2
    @StoredInput(.voltageDivider, "jobName", default: "Voltage divider") private var jobName
    @State private var session = ExplicitCalculationSession<VoltageDividerResult>()
    @State private var successTick = 0

    private var fingerprint: String { "\(solve.rawValue)|\(vin)|\(vout)|\(r1)|\(r2)" }
    private var display: ExplicitCalculationSession<VoltageDividerResult>.Display {
        session.display(for: fingerprint)
    }

    var body: some View {
        ToolScaffold(
            toolID: .voltageDivider,
            stickyAnswer: sticky,
            copyText: copyText,
            dock: {
                CalculateActionBar(
                    isStale: isStale,
                    errorMessage: session.visibleError(for: fingerprint),
                    successTick: successTick,
                    onCalculate: calculate,
                    onReset: reset
                )
            }
        ) {
            ShowWorkCard(
                toolID: .voltageDivider,
                symbolic: "Vout = Vin × R2 / (R1 + R2)",
                substituted: substituted,
                meaning: "Unloaded divider. R1 is top (from Vin), R2 is to ground. Not a loaded Thevenin model."
            )
            TryExampleButton(title: "12 V in, 10 kΩ / 10 kΩ → 6 V") {
                solve = .vout
                vin = "12"
                r1 = "10000"
                r2 = "10000"
            }
            Picker("Solve", selection: $solve) {
                ForEach(Solve.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            NumberField(title: "Vin", unit: "V", text: $vin)
            if solve != .vout { NumberField(title: "Vout", unit: "V", text: $vout) }
            if solve != .r1 { NumberField(title: "R1 (top)", unit: "Ω", text: $r1) }
            if solve != .r2 { NumberField(title: "R2 (to GND)", unit: "Ω", text: $r2) }
            switch display {
            case .current(let r), .stale(let r):
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Vin", value: Format.volts(r.vin))
                    ResultRow(label: "Vout", value: Format.volts(r.vout), emphasis: true, tone: Theme.good)
                    ResultRow(label: "R1", value: "\(Format.number(r.r1, digits: 3)) Ω", emphasis: true)
                    ResultRow(label: "R2", value: "\(Format.number(r.r2, digits: 3)) Ω", emphasis: true)
                    ResultRow(label: "I", value: Format.amps(r.current))
                }
                SaveJobBar(jobName: $jobName, canSave: { if case .current = display { true } else { false } }()) { save(r) }
            case .idle:
                ToolEmptyState(
                    title: "Enter divider values",
                    detail: "Fill known fields for Vout, R1, or R2, then Calculate.",
                    systemImage: "slider.horizontal.3"
                )
            case .failed:
                EmptyView()
            }
        }
    }

    private var isStale: Bool {
        if case .stale = display { return true }
        return false
    }

    private func calculate() {
        session.calculate(fingerprint: fingerprint) {
            switch solve {
            case .vout:
                return try VoltageDivider.fromResistors(vin: vin.parsedDouble ?? .nan, r1: r1.parsedDouble ?? .nan, r2: r2.parsedDouble ?? .nan)
            case .r1:
                return try VoltageDivider.solveR1(vin: vin.parsedDouble ?? .nan, vout: vout.parsedDouble ?? .nan, r2: r2.parsedDouble ?? .nan)
            case .r2:
                return try VoltageDivider.solveR2(vin: vin.parsedDouble ?? .nan, vout: vout.parsedDouble ?? .nan, r1: r1.parsedDouble ?? .nan)
            }
        }
        if case .current = session.display(for: fingerprint) {
            successTick += 1
        }
    }

    private func reset() {
        session.reset()
        solve = .vout
        vin = "12"
        vout = "6"
        r1 = "10000"
        r2 = "10000"
    }

    private var substituted: String? {
        guard case .current(let r) = display else { return nil }
        return "\(Format.volts(r.vout)) = \(Format.volts(r.vin)) × \(Format.number(r.r2, digits: 3)) / (\(Format.number(r.r1, digits: 3)) + \(Format.number(r.r2, digits: 3)))"
    }

    private var sticky: String? {
        switch display {
        case .current(let r), .stale(let r):
            return "Vout \(Format.volts(r.vout))  ·  R1 \(Format.number(r.r1, digits: 3)) Ω  ·  R2 \(Format.number(r.r2, digits: 3)) Ω"
        default:
            return nil
        }
    }

    private var copyText: String? { sticky }

    private func save(_ r: VoltageDividerResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .voltageDivider,
            inputs: ["solve": solve.rawValue, "Vin": vin, "Vout": vout, "R1": r1, "R2": r2],
            outputs: [
                "Vout": Format.volts(r.vout),
                "R1": "\(Format.number(r.r1)) Ω",
                "R2": "\(Format.number(r.r2)) Ω",
                "I": Format.amps(r.current),
            ]
        ))
    }
}
