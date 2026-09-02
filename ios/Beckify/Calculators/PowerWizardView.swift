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
    @StoredChoice(.powerWizard, "system", default: .threePhase) private var system
    @StoredChoice(.powerWizard, "known", default: .kw) private var known
    @StoredInput(.powerWizard, "value", default: "50") private var value
    @StoredInput(.powerWizard, "voltage", default: "480") private var voltage
    @StoredInput(.powerWizard, "pf", default: "90") private var pf
    @StoredInput(.powerWizard, "eff", default: "100") private var eff
    @StoredInput(.powerWizard, "jobName", default: "Power Wizard") private var jobName

    var body: some View {
        ToolScaffold(toolID: .powerWizard, stickyAnswer: sticky, copyText: copyText) {
            ShowWorkCard(
                toolID: .powerWizard,
                symbolic: symbolic,
                substituted: substituted,
                meaning: "Current from known kW, kVA, amps, or HP. PF is a decimal after the % field (90 → 0.90). Efficiency only matters on the HP path."
            )
            TryExampleButton(title: "480 V 3Ø 50 kW PF 0.90 → 66.8 A") {
                system = .threePhase
                known = .kw
                value = "50"
                voltage = "480"
                pf = "90"
                eff = "100"
            }
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
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Current", value: Format.amps(r.amps), emphasis: true, tone: Theme.good)
                    ResultRow(label: "Apparent", value: "\(Format.number(r.kVA, digits: 3)) kVA")
                    ResultRow(label: "Real", value: "\(Format.number(r.kW, digits: 3)) kW")
                    if system != .dc {
                        ResultRow(label: "Reactive", value: "\(Format.number(r.kVAR, digits: 3)) kVAR")
                        ResultRow(label: "θ", value: "\(Format.number(r.phaseAngleDegrees, digits: 1)) °")
                    }
                    ResultRow(label: "Shaft HP", value: "\(Format.number(r.horsepower, digits: 2)) HP")
                }
                SaveJobBar(jobName: $jobName, canSave: true) { save(r) }
            case .failure(let err):
                ErrorText(message: err.message)
            }
        }
    }

    private var symbolic: String {
        if system == .threePhase { return "I = kW × 1000 ÷ (√3 × V × PF)" }
        if system == .dc { return "I = P ÷ V     (PF = 1)" }
        return "I = kW × 1000 ÷ (V × PF)"
    }

    private var substituted: String? {
        guard case .success(let r) = wizard else { return nil }
        return "\(r.formula)  →  \(Format.amps(r.amps))"
    }

    private var sticky: String? {
        guard case .success(let r) = wizard else { return nil }
        return "\(Format.amps(r.amps))  ·  \(Format.number(r.kW, digits: 3)) kW  ·  \(Format.number(r.kVA, digits: 3)) kVA"
    }

    private var copyText: String? { sticky }

    private var wizard: Result<PowerWizardResult, CalcError> {
        CalcCatch.run {
            let knownValue = value.parsedDouble ?? .nan
            let knownEnum: PowerWizardKnown
            switch known {
            case .amps: knownEnum = .amps(knownValue)
            case .kw: knownEnum = .kilowatts(knownValue)
            case .kva: knownEnum = .kilovoltAmps(knownValue)
            case .hp: knownEnum = .horsepower(knownValue)
            }
            return try PowerWizard.solve(
                system: system,
                known: knownEnum,
                voltage: voltage.parsedDouble ?? .nan,
                powerFactor: (pf.parsedDouble ?? .nan) / 100,
                efficiency: (eff.parsedDouble ?? .nan) / 100
            )
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
