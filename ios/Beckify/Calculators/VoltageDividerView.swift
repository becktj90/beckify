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
    @State private var session = ExplicitCalculationState<VoltageDividerResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String { "\(solve)|\(vin)|\(vout)|\(r1)|\(r2)" }

    var body: some View {
        ToolScaffold(
            toolID: .voltageDivider,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .voltageDivider,
                symbolic: "Vout = Vin × R2 / (R1 + R2)",
                substituted: substituted,
                meaning: "Unloaded divider. R1 is top (from Vin), R2 is to ground. Not a loaded Thevenin model."
            )
            Picker("Solve", selection: $solve) {
                ForEach(Solve.allCases) { Text($0.rawValue).tag($0) }
            }
            .segmentedControlStyle()
            NumberField(title: "Vin", unit: "V", text: $vin, fieldID: "vin", onSubmit: calculate)
            if solve != .vout { NumberField(title: "Vout", unit: "V", text: $vout, fieldID: "vout", onSubmit: calculate) }
            if solve != .r1 { NumberField(title: "R1 (top)", unit: "Ω", text: $r1, fieldID: "r1", onSubmit: calculate) }
            if solve != .r2 { NumberField(title: "R2 (to GND)", unit: "Ω", text: $r2, fieldID: "r2", onSubmit: calculate) }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    solve = .vout
                    vin = "12"
                    r1 = "10000"
                    r2 = "10000"
                    session.prepareForNewInputs()
                },
                exampleTitle: "12 V in, 10 kΩ / 10 kΩ → 6 V"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Vin", value: Format.volts(r.vin))
                    ResultRow(label: "Vout", value: Format.volts(r.vout), emphasis: true, tone: Theme.good)
                    ResultRow(label: "R1", value: "\(Format.number(r.r1, digits: 3)) Ω", emphasis: true)
                    ResultRow(label: "R2", value: "\(Format.number(r.r2, digits: 3)) Ω", emphasis: true)
                    ResultRow(label: "I", value: Format.amps(r.current))
                }
                .opacity(session.isStale ? 0.72 : 1)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) { save(r) }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func calculate() {
        session.calculate {
            switch solve {
            case .vout:
                return try VoltageDivider.fromResistors(vin: vin.parsedDouble ?? .nan, r1: r1.parsedDouble ?? .nan, r2: r2.parsedDouble ?? .nan)
            case .r1:
                return try VoltageDivider.solveR1(vin: vin.parsedDouble ?? .nan, vout: vout.parsedDouble ?? .nan, r2: r2.parsedDouble ?? .nan)
            case .r2:
                return try VoltageDivider.solveR2(vin: vin.parsedDouble ?? .nan, vout: vout.parsedDouble ?? .nan, r1: r1.parsedDouble ?? .nan)
            }
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        vin = ""
        vout = ""
        r1 = ""
        r2 = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.volts(r.vout)) = \(Format.volts(r.vin)) × \(Format.number(r.r2, digits: 3)) / (\(Format.number(r.r1, digits: 3)) + \(Format.number(r.r2, digits: 3)))"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "Vout \(Format.volts(r.vout))  ·  R1 \(Format.number(r.r1, digits: 3)) Ω  ·  R2 \(Format.number(r.r2, digits: 3)) Ω"
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
