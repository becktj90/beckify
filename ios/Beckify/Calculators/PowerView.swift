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

    private enum SessionResult: Equatable {
        case dc(DCPowerResult)
        case ac(ACPowerResult)
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.power, "mode", default: Mode.ac3) private var mode
    @StoredInput(.power, "v", default: "480") private var v
    @StoredInput(.power, "i", default: "66.8") private var i
    @StoredInput(.power, "r", default: "10") private var r
    @StoredInput(.power, "pf", default: "90") private var pf
    @StoredInput(.power, "jobName", default: "AC Power") private var jobName
    @State private var session = ExplicitCalculationState<SessionResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String { "\(mode)|\(v)|\(i)|\(r)|\(pf)" }

    var body: some View {
        ToolScaffold(
            toolID: .power,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .power,
                symbolic: symbolic,
                substituted: substituted,
                meaning: meaning
            )
            MenuField(title: "Mode", selection: $mode, options: Mode.allCases) { $0.rawValue }
            switch mode {
            case .dcVI:
                NumberField(title: "Voltage", unit: "V", text: $v, fieldID: "v", onSubmit: calculate)
                NumberField(title: "Current", unit: "A", text: $i, fieldID: "i", onSubmit: calculate)
            case .dcIR:
                NumberField(title: "Current", unit: "A", text: $i, fieldID: "i", onSubmit: calculate)
                NumberField(title: "Resistance", unit: "Ω", text: $r, fieldID: "r", onSubmit: calculate)
            case .dcVR:
                NumberField(title: "Voltage", unit: "V", text: $v, fieldID: "v", onSubmit: calculate)
                NumberField(title: "Resistance", unit: "Ω", text: $r, fieldID: "r", onSubmit: calculate)
            case .ac1, .ac3:
                NumberField(title: "Voltage", unit: "V", text: $v, fieldID: "v", onSubmit: calculate)
                NumberField(title: "Current", unit: "A", text: $i, fieldID: "i", onSubmit: calculate)
                NumberField(title: "Power factor", unit: "%", text: $pf, fieldID: "pf", onSubmit: calculate)
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    mode = .ac3
                    v = "480"
                    i = "66.8"
                    pf = "90"
                    session.prepareForNewInputs()
                },
                exampleTitle: "480 V 3Ø, 66.8 A, PF 90%"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let output = session.displayedResult {
                switch output {
                case .dc(let dc):
                    dcResultCard(dc)
                case .ac(let ac):
                    acResultCard(ac)
                }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    @ViewBuilder
    private func dcResultCard(_ dc: DCPowerResult) -> some View {
        ResultCard(copyText: Format.watts(dc.power)) {
            ResultRow(label: "Power", value: Format.watts(dc.power), emphasis: true, tone: Theme.good)
            ResultRow(label: "Voltage", value: Format.volts(dc.voltage))
            ResultRow(label: "Current", value: Format.amps(dc.current))
            ResultRow(label: "Resistance", value: dc.resistance.isFinite ? "\(Format.number(dc.resistance)) Ω" : "—")
        }
        .opacity(session.isStale ? 0.72 : 1)
        SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
            jobs.save(SavedJob(
                name: jobName,
                toolID: .power,
                inputs: ["mode": mode.rawValue, "V": v, "I": i, "R": Format.number(dc.resistance)],
                outputs: ["P": Format.watts(dc.power)]
            ))
        }
    }

    @ViewBuilder
    private func acResultCard(_ ac: ACPowerResult) -> some View {
        ResultCard(copyText: "\(Format.number(ac.kW, digits: 3)) kW, \(Format.number(ac.kVA, digits: 3)) kVA") {
            ResultRow(label: "Apparent", value: "\(Format.number(ac.kVA, digits: 3)) kVA", emphasis: true)
            ResultRow(label: "Real", value: "\(Format.number(ac.kW, digits: 3)) kW", emphasis: true, tone: Theme.good)
            ResultRow(label: "Reactive", value: "\(Format.number(ac.kVAR, digits: 3)) kVAR")
            ResultRow(label: "PF", value: Format.percent(ac.powerFactor * 100))
            ResultRow(label: "θ", value: "\(Format.number(ac.phaseAngleDegrees, digits: 1)) °")
        }
        .opacity(session.isStale ? 0.72 : 1)
        SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
            jobs.save(SavedJob(
                name: jobName,
                toolID: .power,
                inputs: ["mode": mode.rawValue, "V": v, "I": i, "PF": pf],
                outputs: ["kVA": Format.number(ac.kVA), "kW": Format.number(ac.kW)]
            ))
        }
    }

    private func calculate() {
        session.calculate {
            switch mode {
            case .dcVI:
                return .dc(try DCPower.fromVI(voltage: v.parsedDouble ?? .nan, current: i.parsedDouble ?? .nan))
            case .dcIR:
                return .dc(try DCPower.fromIR(current: i.parsedDouble ?? .nan, resistance: r.parsedDouble ?? .nan))
            case .dcVR:
                return .dc(try DCPower.fromVR(voltage: v.parsedDouble ?? .nan, resistance: r.parsedDouble ?? .nan))
            case .ac1, .ac3:
                return .ac(try ACPower.solve(
                    system: mode == .ac3 ? .threePhase : .singlePhase,
                    voltage: v.parsedDouble ?? .nan,
                    current: i.parsedDouble ?? .nan,
                    powerFactor: (pf.parsedDouble ?? .nan) / 100
                ))
            }
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        v = ""
        i = ""
        r = ""
        pf = "90"
        session.reset()
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
        guard let output = session.displayedResult else { return nil }
        switch (mode, output) {
        case (.dcVI, .dc(let r)), (.dcIR, .dc(let r)), (.dcVR, .dc(let r)):
            return "\(r.formula) = \(Format.watts(r.power))"
        case (.ac1, .ac(let r)), (.ac3, .ac(let r)):
            let pfText = Format.number((pf.parsedDouble ?? .nan) / 100, digits: 2)
            if mode == .ac3 {
                return "kVA = √3 × \(Format.number(v.parsedDouble ?? .nan, digits: 2)) × \(Format.number(i.parsedDouble ?? .nan, digits: 2)) / 1000 = \(Format.number(r.kVA, digits: 3)) kVA    kW = kVA × \(pfText) = \(Format.number(r.kW, digits: 3)) kW"
            }
            return "kVA = \(Format.number(v.parsedDouble ?? .nan, digits: 2)) × \(Format.number(i.parsedDouble ?? .nan, digits: 2)) / 1000 = \(Format.number(r.kVA, digits: 3)) kVA    kW = kVA × \(pfText) = \(Format.number(r.kW, digits: 3)) kW"
        default:
            return nil
        }
    }

    private var sticky: String? {
        guard let output = session.displayedResult else { return nil }
        switch output {
        case .dc(let r):
            return Format.watts(r.power)
        case .ac(let r):
            return "\(Format.number(r.kW, digits: 3)) kW  ·  \(Format.number(r.kVA, digits: 3)) kVA"
        }
    }

    private var copyText: String? { sticky }
}
