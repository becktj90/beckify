import SwiftUI
import BeckifyMath

struct LEDRCView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case led = "LED R"
        case rc = "RC τ"
        var id: String { rawValue }
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.ledRC, "mode", default: .led) private var mode
    @StoredInput(.ledRC, "supply", default: "5") private var supply
    @StoredInput(.ledRC, "vf", default: "2.0") private var vf
    @StoredInput(.ledRC, "current", default: "0.02") private var current
    @StoredInput(.ledRC, "resistance", default: "10000") private var resistance
    @StoredInput(.ledRC, "capacitance", default: "1e-6") private var capacitance
    @StoredInput(.ledRC, "jobName", default: "LED / RC") private var jobName

    var ledResult: Result<LEDResistorResult, CalcError> {
        CalcCatch.run { try LEDResistor.size(supply: supply.parsedDouble ?? .nan, forward: vf.parsedDouble ?? .nan, current: current.parsedDouble ?? .nan) }
    }

    var rcResult: Result<RCTimeResult, CalcError> {
        CalcCatch.run { try RCTime.tau(resistance: resistance.parsedDouble ?? .nan, capacitance: capacitance.parsedDouble ?? .nan) }
    }

    var body: some View {
        ToolScaffold(toolID: .ledRC, stickyAnswer: sticky, copyText: copyText) {
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
                switch ledResult {
                case .success(let r):
                    ResultCard(copyText: copyText) {
                        ResultRow(label: "R exact", value: "\(Format.number(r.resistance, digits: 3)) Ω", emphasis: true, tone: Theme.good)
                        ResultRow(label: "Nearest E24", value: "\(Format.number(r.nearestE24, digits: 3)) Ω")
                        ResultRow(label: "Drop", value: Format.volts(r.drop))
                        ResultRow(label: "Resistor P", value: Format.watts(r.power))
                    }
                    SaveJobBar(jobName: $jobName, canSave: true) { saveLED(r) }
                case .failure(let err):
                    ErrorText(message: err.message)
                }
            } else {
                NumberField(title: "R", unit: "Ω", text: $resistance)
                NumberField(title: "C", unit: "F", text: $capacitance, allowsScientific: true)
                switch rcResult {
                case .success(let r):
                    ResultCard(copyText: copyText) {
                        ResultRow(label: "τ", value: Format.time(r.tau), emphasis: true, tone: Theme.good)
                        ResultRow(label: "5τ", value: Format.time(r.fiveTau), emphasis: true)
                    }
                    SaveJobBar(jobName: $jobName, canSave: true) { saveRC(r) }
                case .failure(let err):
                    ErrorText(message: err.message)
                }
            }
        }
    }

    private var substituted: String? {
        if mode == .led, case .success(let r) = ledResult {
            return "R = (\(supply) − \(vf)) / \(current) = \(Format.number(r.resistance, digits: 3)) Ω"
        }
        if mode == .rc, case .success(let r) = rcResult {
            return "τ = \(resistance) × \(capacitance) = \(Format.time(r.tau))"
        }
        return nil
    }

    private var sticky: String? {
        if mode == .led, case .success(let r) = ledResult {
            return "\(Format.number(r.resistance, digits: 3)) Ω  ·  E24 \(Format.number(r.nearestE24, digits: 3)) Ω"
        }
        if mode == .rc, case .success(let r) = rcResult {
            return Format.time(r.tau)
        }
        return nil
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
