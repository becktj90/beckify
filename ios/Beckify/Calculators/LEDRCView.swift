import SwiftUI
import BeckifyMath

struct LEDRCView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case led = "LED R"
        case rc = "RC τ"
        var id: String { rawValue }
    }

    private enum SessionResult: Equatable {
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
    @State private var session = ExplicitCalculationState<SessionResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(mode)|\(supply)|\(vf)|\(current)|\(resistance)|\(capacitance)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .ledRC,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .ledRC,
                symbolic: mode == .led ? "R = (Vin − Vf) / If" : "τ = R × C    (~5τ to settle)",
                substituted: substituted,
                meaning: mode == .led
                    ? "Nearest E24 is a hint, not a guaranteed stocked part. Check the LED datasheet current."
                    : "First-order RC only. 555 astable/monostable lives in the 555 Timer tool (ln 2 / ln 3)."
            )
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            if mode == .led {
                NumberField(title: "Supply", unit: "V", text: $supply, fieldID: "supply", onSubmit: calculate)
                NumberField(title: "LED Vf", unit: "V", text: $vf, fieldID: "vf", onSubmit: calculate)
                NumberField(title: "LED current", unit: "A", text: $current, allowsScientific: true, fieldID: "current", onSubmit: calculate)
            } else {
                NumberField(title: "R", unit: "Ω", text: $resistance, fieldID: "resistance", onSubmit: calculate)
                NumberField(title: "C", unit: "F", text: $capacitance, allowsScientific: true, fieldID: "capacitance", onSubmit: calculate)
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    if mode == .led {
                        supply = "5"
                        vf = "2.0"
                        current = "0.02"
                    } else {
                        resistance = "10000"
                        capacitance = "1e-6"
                    }
                    session.prepareForNewInputs()
                },
                exampleTitle: mode == .led ? "5 V, 2.0 V LED, 20 mA" : "10 kΩ · 1 µF"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let output = session.displayedResult {
                switch output {
                case .led(let r):
                    ResultCard(copyText: copyText) {
                        ResultRow(label: "R exact", value: "\(Format.number(r.resistance, digits: 3)) Ω", emphasis: true, tone: Theme.good)
                        ResultRow(label: "Nearest E24", value: "\(Format.number(r.nearestE24, digits: 3)) Ω")
                        ResultRow(label: "Drop", value: Format.volts(r.drop))
                        ResultRow(label: "Resistor P", value: Format.watts(r.power))
                    }
                    .opacity(session.isStale ? 0.72 : 1)
                    SaveJobBar(jobName: $jobName, canSave: !session.isStale) { saveLED(r) }
                case .rc(let r):
                    ResultCard(copyText: copyText) {
                        ResultRow(label: "τ", value: Format.time(r.tau), emphasis: true, tone: Theme.good)
                        ResultRow(label: "5τ", value: Format.time(r.fiveTau), emphasis: true)
                    }
                    .opacity(session.isStale ? 0.72 : 1)
                    if r.tau.isFinite, r.tau > 0 {
                        RCChargeDischargeChart(tau: r.tau)
                            .opacity(session.isStale ? 0.72 : 1)
                    }
                    SaveJobBar(jobName: $jobName, canSave: !session.isStale) { saveRC(r) }
                }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func calculate() {
        session.calculate {
            switch mode {
            case .led:
                return .led(try LEDResistor.size(
                    supply: supply.parsedDouble ?? .nan,
                    forward: vf.parsedDouble ?? .nan,
                    current: current.parsedDouble ?? .nan
                ))
            case .rc:
                return .rc(try RCTime.tau(
                    resistance: resistance.parsedDouble ?? .nan,
                    capacitance: capacitance.parsedDouble ?? .nan
                ))
            }
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        supply = ""
        vf = ""
        current = ""
        resistance = ""
        capacitance = ""
        session.reset()
    }

    private var substituted: String? {
        guard let output = session.displayedResult else { return nil }
        switch output {
        case .led(let r):
            return "\(r.formula)  →  \(Format.number(r.resistance, digits: 3)) Ω"
        case .rc(let r):
            return "\(r.formula)  →  \(Format.time(r.tau))"
        }
    }

    private var sticky: String? {
        guard let output = session.displayedResult else { return nil }
        switch output {
        case .led(let r):
            return "\(Format.number(r.resistance, digits: 3)) Ω  ·  E24 \(Format.number(r.nearestE24, digits: 3)) Ω"
        case .rc(let r):
            return Format.time(r.tau)
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
