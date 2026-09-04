import SwiftUI
import BeckifyMath

struct OhmsLawView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.ohmsLaw, "voltage", default: "12") private var voltage
    @StoredInput(.ohmsLaw, "current", default: "2") private var current
    @StoredInput(.ohmsLaw, "resistance", default: "") private var resistance
    @StoredInput(.ohmsLaw, "jobName", default: "Ohm's Law") private var jobName
    @State private var session = ExplicitCalculationState<OhmsLawResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String { "\(voltage)|\(current)|\(resistance)" }

    var body: some View {
        ToolScaffold(
            toolID: .ohmsLaw,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .ohmsLaw,
                symbolic: "V = I × R     P = V × I",
                substituted: substituted,
                meaning: "Voltage across a resistor is current times resistance. Leave the unknown blank and the other two filled."
            )

            NumberField(title: "Voltage", unit: "V", text: $voltage, optional: true, fieldID: "voltage", onSubmit: calculate)
            NumberField(title: "Current", unit: "A", text: $current, optional: true, fieldID: "current", onSubmit: calculate)
            NumberField(title: "Resistance", unit: "Ω", text: $resistance, optional: true, fieldID: "resistance", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    voltage = "12"
                    current = "2"
                    resistance = ""
                    session.prepareForNewInputs()
                },
                exampleTitle: "12 V, 2 A"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Voltage", value: Format.volts(r.voltage), emphasis: true)
                    ResultRow(label: "Current", value: Format.amps(r.current), emphasis: true)
                    ResultRow(label: "Resistance", value: "\(Format.number(r.resistance, digits: 3)) Ω", emphasis: true)
                    ResultRow(label: "Power", value: "\(Format.watts(r.power))  (\(Format.number(r.power / 1000, digits: 3)) kW)", tone: Theme.good)
                }
                .opacity(session.isStale ? 0.72 : 1)
                if r.voltage.isFinite, r.current.isFinite, r.voltage > 0, r.current > 0 {
                    OhmsLawLoadLineChart(voltage: r.voltage, current: r.current, resistance: r.resistance)
                        .opacity(session.isStale ? 0.72 : 1)
                }
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
            try OhmsLaw.solve(
                voltage: voltage.parsedDouble,
                current: current.parsedDouble,
                resistance: resistance.parsedDouble
            )
        }
        if session.displayedResult != nil, !session.isStale {
            if !reduceMotion {
                successTick += 1
            }
        }
    }

    private func reset() {
        voltage = ""
        current = ""
        resistance = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.volts(r.voltage)) = \(Format.amps(r.current)) × \(Format.number(r.resistance, digits: 3)) Ω    P = \(Format.watts(r.power))"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.volts(r.voltage))  ·  \(Format.amps(r.current))  ·  \(Format.number(r.resistance, digits: 3)) Ω  ·  \(Format.watts(r.power))"
    }

    private var copyText: String? { sticky }

    private func save(_ r: OhmsLawResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .ohmsLaw,
            inputs: ["V": voltage, "I": current, "R": resistance],
            outputs: [
                "V": Format.volts(r.voltage),
                "I": Format.amps(r.current),
                "R": "\(Format.number(r.resistance)) Ω",
                "P": Format.watts(r.power),
            ]
        ))
    }
}

#Preview {
    NavigationStack {
        OhmsLawView()
            .environmentObject(JobStore())
            .environmentObject(FavoritesStore())
    }
}
