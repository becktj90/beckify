import SwiftUI
import BeckifyMath

struct OhmsLawView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.ohmsLaw, "voltage", default: "12") private var voltage
    @StoredInput(.ohmsLaw, "current", default: "2") private var current
    @StoredInput(.ohmsLaw, "resistance", default: "") private var resistance
    @StoredInput(.ohmsLaw, "jobName", default: "Ohm's Law") private var jobName
    @State private var session = ExplicitCalculationSession<OhmsLawResult>()
    @State private var successTick = 0

    private var fingerprint: String { "\(voltage)|\(current)|\(resistance)" }
    private var display: ExplicitCalculationSession<OhmsLawResult>.Display {
        session.display(for: fingerprint)
    }

    var body: some View {
        ToolScaffold(
            toolID: .ohmsLaw,
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
                toolID: .ohmsLaw,
                symbolic: "V = I × R     P = V × I",
                substituted: substituted,
                meaning: "Voltage across a resistor is current times resistance. Leave the unknown blank and the other two filled."
            )
            TryExampleButton(title: "12 V battery, 2 A load") {
                voltage = "12"
                current = "2"
                resistance = ""
            }
            NumberField(title: "Voltage", unit: "V", text: $voltage, optional: true)
            NumberField(title: "Current", unit: "A", text: $current, optional: true)
            NumberField(title: "Resistance", unit: "Ω", text: $resistance, optional: true)

            switch display {
            case .current(let r), .stale(let r):
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Voltage", value: Format.volts(r.voltage), emphasis: true)
                    ResultRow(label: "Current", value: Format.amps(r.current), emphasis: true)
                    ResultRow(label: "Resistance", value: "\(Format.number(r.resistance, digits: 3)) Ω", emphasis: true)
                    ResultRow(label: "Power", value: "\(Format.watts(r.power))  (\(Format.number(r.power / 1000, digits: 3)) kW)", tone: Theme.good)
                }
                if case .current = display {
                    SaveJobBar(jobName: $jobName, canSave: true) { save(r) }
                }
            case .idle:
                ToolEmptyState(
                    title: "Enter any two values",
                    detail: "Leave the unknown blank, then Calculate.",
                    systemImage: "function"
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
            try OhmsLaw.solve(
                voltage: voltage.parsedDouble,
                current: current.parsedDouble,
                resistance: resistance.parsedDouble
            )
        }
        if case .current = session.display(for: fingerprint) {
            successTick += 1
        }
    }

    private func reset() {
        session.reset()
        voltage = ""
        current = ""
        resistance = ""
    }

    private var substituted: String? {
        guard case .current(let r) = display else { return nil }
        return "\(Format.volts(r.voltage)) = \(Format.amps(r.current)) × \(Format.number(r.resistance, digits: 3)) Ω    P = \(Format.watts(r.power))"
    }

    private var sticky: String? {
        switch display {
        case .current(let r), .stale(let r):
            return "\(Format.volts(r.voltage))  ·  \(Format.amps(r.current))  ·  \(Format.number(r.resistance, digits: 3)) Ω  ·  \(Format.watts(r.power))"
        default:
            return nil
        }
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
