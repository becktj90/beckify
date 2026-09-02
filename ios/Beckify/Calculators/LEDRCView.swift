import SwiftUI
import BeckifyMath

struct LEDRCView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case led = "LED R"
        case rc = "RC τ"
        var id: String { rawValue }
    }

    @EnvironmentObject private var jobs: JobStore
    @State private var mode: Mode = .led
    @State private var supply = "5"
    @State private var vf = "2.0"
    @State private var current = "0.02"
    @State private var resistance = "10000"
    @State private var capacitance = "1e-6"
    @State private var jobName = "LED / RC"

    var ledResult: Result<LEDResistorResult, CalcError> {
        wrap { try LEDResistor.size(supply: supply.parsedDouble ?? .nan, forward: vf.parsedDouble ?? .nan, current: current.parsedDouble ?? .nan) }
    }

    var rcResult: Result<RCTimeResult, CalcError> {
        wrap { try RCTime.tau(resistance: resistance.parsedDouble ?? .nan, capacitance: capacitance.parsedDouble ?? .nan) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FormulaCard(
                    text: mode == .led ? "R = (Vin − Vf) / If" : "τ = R × C    (~5τ to settle)",
                    citation: mode == .led
                        ? "Nearest E24 is a hint, not a guaranteed stocked part. Check LED datasheet current."
                        : "First-order RC only. 555 astable/monostable lives in the 555 Timer tool (ln 2 / ln 3)."
                )
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
                        ResultCard {
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
                        ResultCard {
                            ResultRow(label: "τ", value: Format.time(r.tau), emphasis: true, tone: Theme.good)
                            ResultRow(label: "5τ", value: Format.time(r.fiveTau), emphasis: true)
                        }
                        SaveJobBar(jobName: $jobName, canSave: true) { saveRC(r) }
                    case .failure(let err):
                        ErrorText(message: err.message)
                    }
                }
                DisclaimerBanner()
            }
            .padding(20)
        }
        .navigationTitle("LED / RC")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func wrap<T>(_ body: () throws -> T) -> Result<T, CalcError> {
        do {
            return .success(try body())
        } catch let error as CalcError {
            return .failure(error)
        } catch {
            return .failure(.missing("values"))
        }
    }

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
