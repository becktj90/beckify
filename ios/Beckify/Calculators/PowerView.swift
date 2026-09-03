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
    @StoredChoice(.power, "mode", default: Mode.ac3) private var mode
    @StoredInput(.power, "v", default: "480") private var v
    @StoredInput(.power, "i", default: "66.8") private var i
    @StoredInput(.power, "r", default: "10") private var r
    @StoredInput(.power, "pf", default: "90") private var pf
    @StoredInput(.power, "jobName", default: "AC Power") private var jobName

    var body: some View {
        ToolScaffold(toolID: .power, stickyAnswer: sticky, copyText: copyText) {
            ShowWorkCard(
                toolID: .power,
                symbolic: symbolic,
                substituted: substituted,
                meaning: meaning
            )
            TryExampleButton(title: "480 V 3Ø, 66.8 A, PF 90%") {
                mode = .ac3
                v = "480"
                i = "66.8"
                pf = "90"
            }
            MenuField(title: "Mode", selection: $mode, options: Mode.allCases) { $0.rawValue }
            switch mode {
            case .dcVI:
                NumberField(title: "Voltage", unit: "V", text: $v)
                NumberField(title: "Current", unit: "A", text: $i)
                dcFrom { try DCPower.fromVI(voltage: v.parsedDouble ?? .nan, current: i.parsedDouble ?? .nan) }
            case .dcIR:
                NumberField(title: "Current", unit: "A", text: $i)
                NumberField(title: "Resistance", unit: "Ω", text: $r)
                dcFrom { try DCPower.fromIR(current: i.parsedDouble ?? .nan, resistance: r.parsedDouble ?? .nan) }
            case .dcVR:
                NumberField(title: "Voltage", unit: "V", text: $v)
                NumberField(title: "Resistance", unit: "Ω", text: $r)
                dcFrom { try DCPower.fromVR(voltage: v.parsedDouble ?? .nan, resistance: r.parsedDouble ?? .nan) }
            case .ac1, .ac3:
                NumberField(title: "Voltage", unit: "V", text: $v)
                NumberField(title: "Current", unit: "A", text: $i)
                NumberField(title: "Power factor", unit: "%", text: $pf)
                acResult
            }
        }
    }

    private var symbolic: String {
        switch mode {
        case .dcVI: return "P = V × I"
        case .dcIR: return "P = I² × R"
        case .dcVR: return "P = V² / R"
        case .ac1: return "kVA = V × I / 1000\nkW = kVA × PF"
        case .ac3: return "kVA = √3 × V_L-L × I_L / 1000\nkW = kVA × PF"
        }
    }

    private var meaning: String {
        switch mode {
        case .dcVI, .dcIR, .dcVR:
            return "DC watts from the two quantities you know. Resistance is V/I when both are known."
        case .ac1:
            return "Single-phase apparent power is volts times amps. Real power is that times power factor."
        case .ac3:
            return "Three-phase voltage is line-to-line. The √3 is the three-phase multiplier, not a fudge factor."
        }
    }

    private var substituted: String? {
        switch mode {
        case .dcVI, .dcIR, .dcVR:
            if case .success(let r) = dcBoxed { return "\(r.formula) = \(Format.watts(r.power))" }
            return nil
        case .ac1, .ac3:
            if case .success(let r) = acBoxed {
                let pfText = Format.number((pf.parsedDouble ?? .nan) / 100, digits: 2)
                if mode == .ac3 {
                    return "kVA = √3 × \(Format.number(v.parsedDouble ?? .nan, digits: 2)) × \(Format.number(i.parsedDouble ?? .nan, digits: 2)) / 1000 = \(Format.number(r.kVA, digits: 3)) kVA    kW = kVA × \(pfText) = \(Format.number(r.kW, digits: 3)) kW"
                }
                return "kVA = \(Format.number(v.parsedDouble ?? .nan, digits: 2)) × \(Format.number(i.parsedDouble ?? .nan, digits: 2)) / 1000 = \(Format.number(r.kVA, digits: 3)) kVA    kW = kVA × \(pfText) = \(Format.number(r.kW, digits: 3)) kW"
            }
            return nil
        }
    }

    private var sticky: String? {
        switch mode {
        case .dcVI, .dcIR, .dcVR:
            if case .success(let r) = dcBoxed { return Format.watts(r.power) }
            return nil
        case .ac1, .ac3:
            if case .success(let r) = acBoxed {
                return "\(Format.number(r.kW, digits: 3)) kW  ·  \(Format.number(r.kVA, digits: 3)) kVA"
            }
            return nil
        }
    }

    private var copyText: String? { sticky }

    private var dcBoxed: Result<DCPowerResult, CalcError> {
        CalcCatch.run {
            switch mode {
            case .dcVI: return try DCPower.fromVI(voltage: v.parsedDouble ?? .nan, current: i.parsedDouble ?? .nan)
            case .dcIR: return try DCPower.fromIR(current: i.parsedDouble ?? .nan, resistance: r.parsedDouble ?? .nan)
            case .dcVR: return try DCPower.fromVR(voltage: v.parsedDouble ?? .nan, resistance: r.parsedDouble ?? .nan)
            default: throw CalcError.missing("values")
            }
        }
    }

    private var acBoxed: Result<ACPowerResult, CalcError> {
        CalcCatch.run {
            try ACPower.solve(
                system: mode == .ac3 ? .threePhase : .singlePhase,
                voltage: v.parsedDouble ?? .nan,
                current: i.parsedDouble ?? .nan,
                powerFactor: (pf.parsedDouble ?? .nan) / 100
            )
        }
    }

    @ViewBuilder
    private func dcFrom(_ compute: () throws -> DCPowerResult) -> some View {
        switch CalcCatch.run(compute) {
        case .success(let r):
            ResultCard(copyText: Format.watts(r.power)) {
                ResultRow(label: "Power", value: Format.watts(r.power), emphasis: true, tone: Theme.good)
                ResultRow(label: "Voltage", value: Format.volts(r.voltage))
                ResultRow(label: "Current", value: Format.amps(r.current))
                ResultRow(label: "Resistance", value: r.resistance.isFinite ? "\(Format.number(r.resistance)) Ω" : "—")
            }
            SaveJobBar(jobName: $jobName, canSave: true) {
                jobs.save(SavedJob(name: jobName, toolID: .power, inputs: ["mode": mode.rawValue, "V": v, "I": i, "R": Format.number(r.resistance)], outputs: ["P": Format.watts(r.power)]))
            }
        case .failure(let err):
            ErrorText(message: err.message)
        }
    }

    @ViewBuilder
    private var acResult: some View {
        switch acBoxed {
        case .success(let r):
            ResultCard(copyText: "\(Format.number(r.kW, digits: 3)) kW, \(Format.number(r.kVA, digits: 3)) kVA") {
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
