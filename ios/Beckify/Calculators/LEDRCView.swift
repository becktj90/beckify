import SwiftUI
import BeckifyMath

struct LEDRCView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case led = "LED R"
        case rc = "RC τ"
        var id: String { rawValue }
    }

    private enum Output: Equatable, Sendable {
        case led(LEDResistorResult)
        case rc(RCTimeResult)
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.ledRC, "mode", default: Mode.led) private var mode
    @StoredInput(.ledRC, "supply", default: "5") private var supply
    @StoredInput(.ledRC, "vf", default: "2.0") private var vf
    @StoredInput(.ledRC, "current", default: "0.02") private var current
    @StoredInput(.ledRC, "resistance", default: "10000") private var resistance
    @StoredInput(.ledRC, "capacitance", default: "1e-6") private var capacitance
    @StoredInput(.ledRC, "jobName", default: "LED / RC") private var jobName
    @State private var session = ExplicitCalculationSession<Output>()
    @State private var successTick = 0

    private var fingerprint: String {
        "\(mode.rawValue)|\(supply)|\(vf)|\(current)|\(resistance)|\(capacitance)"
    }
    private var display: ExplicitCalculationSession<Output>.Display {
        session.display(for: fingerprint)
    }

    var body: some View {
        ToolScaffold(
            toolID: .ledRC,
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
                toolID: .ledRC,
                symbolic: mode == .led ? "R = (Vin − Vf) / If" : "τ = R × C    (~5τ to settle)",
                substituted: substituted,
                meaning: mode == .led
                    ? "Nearest E24 is a hint, not a guaranteed stocked part. Check the LED datasheet current."
                    : "First-order RC only. 555 astable/monostable lives in the 555 Timer tool (ln 2 / ln 3)."
            )
            TryExampleButton(title: mode == .led ? "5 V, 2.0 V LED, 20 mA" : "10 kΩ · 1 µF") {
                if mode == .led {
                    supply = "5"
                    vf = "2.0"
                    current = "0.02"
                } else {
                    resistance = "10000"
                    capacitance = "1e-6"
                }
            }
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            if mode == .led {
                NumberField(title: "Supply", unit: "V", text: $supply)
                NumberField(title: "LED Vf", unit: "V", text: $vf)
                NumberField(title: "LED current", unit: "A", text: $current, allowsScientific: true)
            } else {
                NumberField(title: "R", unit: "Ω", text: $resistance)
                NumberField(title: "C", unit: "F", text: $capacitance, allowsScientific: true)
            }

            switch display {
            case .current(let output), .stale(let output):
                resultCard(for: output)
                if case .current = display {
                    SaveJobBar(jobName: $jobName, canSave: true) { save(output) }
                }
            case .idle:
                ToolEmptyState(
                    title: "Enter LED or RC values",
                    detail: "Fill the fields for this mode, then Calculate.",
                    systemImage: "lightbulb"
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
            if mode == .led {
                return .led(try LEDResistor.size(
                    supply: supply.parsedDouble ?? .nan,
                    forward: vf.parsedDouble ?? .nan,
                    current: current.parsedDouble ?? .nan
                ))
            }
            return .rc(try RCTime.tau(
                resistance: resistance.parsedDouble ?? .nan,
                capacitance: capacitance.parsedDouble ?? .nan
            ))
        }
        if case .current = session.display(for: fingerprint) {
            successTick += 1
        }
    }

    private func reset() {
        session.reset()
        mode = .led
        supply = "5"
        vf = "2.0"
        current = "0.02"
        resistance = "10000"
        capacitance = "1e-6"
    }

    @ViewBuilder
    private func resultCard(for output: Output) -> some View {
        switch output {
        case .led(let r):
            ResultCard(copyText: copyText) {
                ResultRow(label: "R exact", value: "\(Format.number(r.resistance, digits: 3)) Ω", emphasis: true, tone: Theme.good)
                ResultRow(label: "Nearest E24", value: "\(Format.number(r.nearestE24, digits: 3)) Ω")
                ResultRow(label: "Drop", value: Format.volts(r.drop))
                ResultRow(label: "Resistor P", value: Format.watts(r.power))
            }
        case .rc(let r):
            ResultCard(copyText: copyText) {
                ResultRow(label: "τ", value: Format.time(r.tau), emphasis: true, tone: Theme.good)
                ResultRow(label: "5τ", value: Format.time(r.fiveTau), emphasis: true)
            }
        }
    }

    private func save(_ output: Output) {
        switch output {
        case .led(let r):
            saveLED(r)
        case .rc(let r):
            saveRC(r)
        }
    }

    private var substituted: String? {
        guard case .current(let output) = display else { return nil }
        switch output {
        case .led(let r):
            return "R = (\(supply) − \(vf)) / \(current) = \(Format.number(r.resistance, digits: 3)) Ω"
        case .rc(let r):
            return "τ = \(resistance) × \(capacitance) = \(Format.time(r.tau))"
        }
    }

    private var sticky: String? {
        switch display {
        case .current(let output), .stale(let output):
            switch output {
            case .led(let r):
                return "\(Format.number(r.resistance, digits: 3)) Ω  ·  E24 \(Format.number(r.nearestE24, digits: 3)) Ω"
            case .rc(let r):
                return Format.time(r.tau)
            }
        default:
            return nil
        }
    }

    private var copyText: String? { sticky }

    private func saveLED(_ r: LEDResistorResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .ledRC,
            inputs: ["mode": "LED", "Vin": supply, "Vf": vf, "If": current],
            outputs: [
                "R": "\(Format.number(r.resistance, digits: 3)) Ω",
                "E24": "\(Format.number(r.nearestE24, digits: 3)) Ω",
                "P": Format.watts(r.power),
            ]
        ))
    }

    private func saveRC(_ r: RCTimeResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .ledRC,
            inputs: ["mode": "RC", "R": resistance, "C": capacitance],
            outputs: ["tau": Format.time(r.tau), "5tau": Format.time(r.fiveTau)]
        ))
    }
}
