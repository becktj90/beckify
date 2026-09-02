import SwiftUI
import BeckifyMath

struct PowerView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case dcVI = "DC P=VI"
        case dcIR = "DC P=I²R"
        case dcVR = "DC P=V²/R"
        case ac1 = "1Ø AC"
        case ac3 = "3Ø AC"
        var id: String { rawValue }
    }

    @EnvironmentObject private var jobs: JobStore
    @State private var mode: Mode = .ac3
    @State private var v = "480"
    @State private var i = "66.8"
    @State private var r = "10"
    @State private var pf = "90"
    @State private var jobName = "AC Power"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch mode {
                case .dcVI:
                    FormulaCard(text: "P = V × I")
                    NumberField(title: "Voltage", unit: "V", text: $v)
                    NumberField(title: "Current", unit: "A", text: $i)
                    dcResult { try DCPower.fromVI(voltage: $0, current: $1) }
                case .dcIR:
                    FormulaCard(text: "P = I² × R")
                    NumberField(title: "Current", unit: "A", text: $i)
                    NumberField(title: "Resistance", unit: "Ω", text: $r)
                    dcFrom { try DCPower.fromIR(current: i.parsedDouble ?? .nan, resistance: r.parsedDouble ?? .nan) }
                case .dcVR:
                    FormulaCard(text: "P = V² / R")
                    NumberField(title: "Voltage", unit: "V", text: $v)
                    NumberField(title: "Resistance", unit: "Ω", text: $r)
                    dcFrom { try DCPower.fromVR(voltage: v.parsedDouble ?? .nan, resistance: r.parsedDouble ?? .nan) }
                case .ac1, .ac3:
                    FormulaCard(
                        text: mode == .ac3 ? "kVA = √3 × V_L-L × I_L / 1000\nkW = kVA × PF" : "kVA = V × I / 1000\nkW = kVA × PF",
                        citation: mode == .ac3 ? "Three-phase voltage is line-to-line." : "Single-phase."
                    )
                    NumberField(title: "Voltage", unit: "V", text: $v)
                    NumberField(title: "Current", unit: "A", text: $i)
                    NumberField(title: "Power factor", unit: "%", text: $pf)
                    acResult
                }
                DisclaimerBanner()
            }
            .padding(20)
        }
        .navigationTitle("DC / AC Power")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func dcResult(_ compute: (Double, Double) throws -> DCPowerResult) -> some View {
        dcFrom {
            try compute(v.parsedDouble ?? .nan, i.parsedDouble ?? .nan)
        }
    }

    @ViewBuilder
    private func dcFrom(_ compute: () throws -> DCPowerResult) -> some View {
        let boxed: Result<DCPowerResult, CalcError> = {
            do { return .success(try compute()) }
            catch let e as CalcError { return .failure(e) }
            catch { return .failure(.missing("values")) }
        }()
        switch boxed {
        case .success(let r):
            ResultCard {
                ResultRow(label: "Power", value: Format.watts(r.power), emphasis: true, tone: Theme.good)
                ResultRow(label: "Voltage", value: Format.volts(r.voltage))
                ResultRow(label: "Current", value: Format.amps(r.current))
                ResultRow(label: "Resistance", value: r.resistance.isFinite ? "\(Format.number(r.resistance)) Ω" : "—")
            }
            SaveJobBar(jobName: $jobName, canSave: true) {
                jobs.save(SavedJob(name: jobName, toolID: .power, inputs: ["mode": mode.rawValue, "V": v, "I": i, "R": r], outputs: ["P": Format.watts(r.power)]))
            }
        case .failure(let err):
            ErrorText(message: err.message)
        }
    }

    @ViewBuilder
    private var acResult: some View {
        let boxed: Result<ACPowerResult, CalcError> = {
            do {
                return .success(try ACPower.solve(
                    system: mode == .ac3 ? .threePhase : .singlePhase,
                    voltage: v.parsedDouble ?? .nan,
                    current: i.parsedDouble ?? .nan,
                    powerFactor: (pf.parsedDouble ?? .nan) / 100
                ))
            } catch let e as CalcError {
                return .failure(e)
            } catch {
                return .failure(.missing("values"))
            }
        }()
        switch boxed {
        case .success(let r):
            ResultCard {
                ResultRow(label: "Apparent", value: "\(Format.number(r.kVA, digits: 3)) kVA", emphasis: true)
                ResultRow(label: "Real", value: "\(Format.number(r.kW, digits: 3)) kW", emphasis: true, tone: Theme.good)
                ResultRow(label: "Reactive", value: "\(Format.number(r.kVAR, digits: 3)) kVAR")
                ResultRow(label: "PF", value: Format.percent(r.powerFactor * 100))
                ResultRow(label: "θ", value: "\(Format.number(r.phaseAngleDegrees, digits: 1)) °")
            }
            SaveJobBar(jobName: $jobName, canSave: true) {
                jobs.save(SavedJob(
                    name: jobName,
                    toolID: .power,
                    inputs: ["mode": mode.rawValue, "V": v, "I": i, "PF": pf],
                    outputs: ["kVA": Format.number(r.kVA), "kW": Format.number(r.kW)]
                ))
            }
        case .failure(let err):
            ErrorText(message: err.message)
        }
    }
}
