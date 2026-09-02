import SwiftUI
import BeckifyMath

struct PowerWizardView: View {
    enum Known: String, CaseIterable, Identifiable {
        case kw = "kW"
        case amps = "A"
        case kva = "kVA"
        case hp = "HP"
        var id: String { rawValue }
    }

    @EnvironmentObject private var jobs: JobStore
    @State private var system: ElectricalSystem = .threePhase
    @State private var known: Known = .kw
    @State private var value = "50"
    @State private var voltage = "480"
    @State private var pf = "90"
    @State private var eff = "100"
    @State private var jobName = "Power Wizard"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FormulaCard(
                    text: system == .threePhase
                        ? "I = kW × 1000 ÷ (√3 × V × PF)"
                        : (system == .dc ? "I = P ÷ V     (PF = 1)" : "I = kW × 1000 ÷ (V × PF)"),
                    citation: "Spot check: 480 V 3Ø 50 kW PF 0.90 → 66.8 A"
                )
                Picker("System", selection: $system) {
                    ForEach(ElectricalSystem.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Known", selection: $known) {
                    ForEach(Known.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                NumberField(title: "Known value", unit: known.rawValue, text: $value)
                NumberField(title: system == .threePhase ? "Line-to-line voltage" : "Voltage", unit: "V", text: $voltage)
                if system != .dc {
                    NumberField(title: "Power factor", unit: "%", text: $pf)
                }
                if known == .hp {
                    NumberField(title: "Efficiency", unit: "%", text: $eff)
                }

                switch wizard {
                case .success(let r):
                    ResultCard {
                        ResultRow(label: "Current", value: Format.amps(r.amps), emphasis: true, tone: Theme.good)
                        ResultRow(label: "Apparent", value: "\(Format.number(r.kVA, digits: 3)) kVA")
                        ResultRow(label: "Real", value: "\(Format.number(r.kW, digits: 3)) kW")
                        if system != .dc {
                            ResultRow(label: "Reactive", value: "\(Format.number(r.kVAR, digits: 3)) kVAR")
                            ResultRow(label: "θ", value: "\(Format.number(r.phaseAngleDegrees, digits: 1)) °")
                        }
                        ResultRow(label: "Shaft HP", value: "\(Format.number(r.horsepower, digits: 2)) HP")
                    }
                    Text(r.formula)
                        .font(.caption.monospaced())
                        .foregroundStyle(Theme.muted)
                    SaveJobBar(jobName: $jobName, canSave: true) { save(r) }
                case .failure(let err):
                    ErrorText(message: err.message)
                }
                DisclaimerBanner()
            }
            .padding(20)
        }
        .navigationTitle("Power Wizard")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var wizard: Result<PowerWizardResult, CalcError> {
        do {
            let knownValue = value.parsedDouble ?? .nan
            let knownEnum: PowerWizardKnown
            switch known {
            case .amps: knownEnum = .amps(knownValue)
            case .kw: knownEnum = .kilowatts(knownValue)
            case .kva: knownEnum = .kilovoltAmps(knownValue)
            case .hp: knownEnum = .horsepower(knownValue)
            }
            return .success(try PowerWizard.solve(
                system: system,
                known: knownEnum,
                voltage: voltage.parsedDouble ?? .nan,
                powerFactor: (pf.parsedDouble ?? .nan) / 100,
                efficiency: (eff.parsedDouble ?? .nan) / 100
            ))
        } catch let error as CalcError {
            return .failure(error)
        } catch {
            return .failure(.missing("values"))
        }
    }

    private func save(_ r: PowerWizardResult) {
        var inputs: [String: String] = [
            "system": system.displayName,
            "known": known.rawValue,
            "value": value,
            "V": voltage,
        ]
        if system != .dc { inputs["PF"] = pf }
        if known == .hp { inputs["eff"] = eff }
        jobs.save(SavedJob(
            name: jobName,
            toolID: .powerWizard,
            inputs: inputs,
            outputs: ["I": Format.amps(r.amps), "kW": Format.number(r.kW), "kVA": Format.number(r.kVA)]
        ))
    }
}
