import SwiftUI
import BeckifyMath

struct Timer555View: View {
    enum Mode: String, CaseIterable, Identifiable {
        case astable, monostable
        var id: String { rawValue }
    }
    enum RUnit: String, CaseIterable, Identifiable {
        case ohm = "Ω"
        case k = "kΩ"
        case M = "MΩ"
        var id: String { rawValue }
        var factor: Double {
            switch self {
            case .ohm: return 1
            case .k: return 1e3
            case .M: return 1e6
            }
        }
    }
    enum CUnit: String, CaseIterable, Identifiable {
        case uF = "µF"
        case nF = "nF"
        case pF = "pF"
        var id: String { rawValue }
        var factor: Double {
            switch self {
            case .uF: return 1e-6
            case .nF: return 1e-9
            case .pF: return 1e-12
            }
        }
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.timer555, "mode", default: .astable) private var mode
    @StoredInput(.timer555, "r1", default: "10") private var r1
    @StoredInput(.timer555, "r2", default: "47") private var r2
    @StoredInput(.timer555, "c", default: "0.1") private var c
    @StoredChoice(.timer555, "rUnit", default: .k) private var rUnit
    @StoredChoice(.timer555, "cUnit", default: .uF) private var cUnit
    @StoredToggle(.timer555, "diode", default: false) private var diode
    @StoredInput(.timer555, "jobName", default: "555 timer") private var jobName

    var body: some View {
        ToolScaffold(toolID: .timer555, stickyAnswer: sticky, copyText: copyText) {
            Picker("Mode", selection: $mode) {
                Text("Astable").tag(Mode.astable)
                Text("Monostable").tag(Mode.monostable)
            }
            .pickerStyle(.segmented)

            if mode == .astable {
                ShowWorkCard(
                    toolID: .timer555,
                    symbolic: diode ? "t1 = ln(2)·R1·C    t2 = ln(2)·R2·C" : "t1 = ln(2)·(R1+R2)·C    t2 = ln(2)·R2·C",
                    substituted: substituted,
                    meaning: "Standard bipolar 555 duty cycle stays above 50% unless R2 is diode-steered. Frequency is 1 / (t1 + t2)."
                )
                TryExampleButton(title: "10 kΩ / 47 kΩ / 0.1 µF astable") {
                    mode = .astable
                    r1 = "10"
                    r2 = "47"
                    c = "0.1"
                    rUnit = .k
                    cUnit = .uF
                    diode = false
                }
                unitField("R1", text: $r1)
                unitField("R2", text: $r2)
                capField()
                Toggle("Diode across R2 (sub-50% duty)", isOn: $diode)
                    .tint(Theme.accent)
                    .frame(minHeight: Theme.touchTarget)
                astableResults
            } else {
                ShowWorkCard(
                    toolID: .timer555,
                    symbolic: "t = ln(3) × R × C ≈ 1.1 RC",
                    substituted: substituted,
                    meaning: "Monostable pulse width while the capacitor charges from 0 to 2/3 Vcc."
                )
                TryExampleButton(title: "10 kΩ / 0.1 µF one-shot") {
                    mode = .monostable
                    r1 = "10"
                    c = "0.1"
                    rUnit = .k
                    cUnit = .uF
                }
                unitField("R", text: $r1)
                capField()
                monostableResults
            }
        }
    }

    private func unitField(_ title: String, text: Binding<String>) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            NumberField(title: title, unit: rUnit.rawValue, text: text)
            Picker("R unit", selection: $rUnit) {
                ForEach(RUnit.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(minHeight: Theme.touchTarget)
            .padding(.bottom, 4)
            .accessibilityLabel("Resistance unit")
        }
    }

    private func capField() -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            NumberField(title: "C", unit: cUnit.rawValue, text: $c)
            Picker("C unit", selection: $cUnit) {
                ForEach(CUnit.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(minHeight: Theme.touchTarget)
            .padding(.bottom, 4)
            .accessibilityLabel("Capacitance unit")
        }
    }

    @ViewBuilder
    private var astableResults: some View {
        switch astable {
        case .success(let r):
            ResultCard(copyText: copyText) {
                ResultRow(label: "t high", value: Format.time(r.timeHigh), emphasis: true, tone: Theme.good)
                ResultRow(label: "t low", value: Format.time(r.timeLow), emphasis: true, tone: Theme.warn)
                ResultRow(label: "Period", value: Format.time(r.period))
                ResultRow(label: "Frequency", value: Format.frequency(r.frequency), emphasis: true)
                ResultRow(label: "Duty cycle", value: Format.percent(r.dutyPercent))
            }
            SaveJobBar(jobName: $jobName, canSave: true) {
                jobs.save(SavedJob(
                    name: jobName,
                    toolID: .timer555,
                    inputs: [
                        "mode": "astable",
                        "R1": r1,
                        "R2": r2,
                        "C": c,
                        "R unit": rUnit.rawValue,
                        "C unit": cUnit.rawValue,
                        "diode": diode ? "yes" : "no",
                    ],
                    outputs: ["f": Format.frequency(r.frequency), "D": Format.percent(r.dutyPercent)]
                ))
            }
        case .failure(let err):
            ErrorText(message: err.message)
        }
    }

    @ViewBuilder
    private var monostableResults: some View {
        switch mono {
        case .success(let r):
            ResultCard(copyText: copyText) {
                ResultRow(label: "Pulse width", value: Format.time(r.pulseWidth), emphasis: true, tone: Theme.good)
                ResultRow(label: "Max retrigger", value: Format.frequency(r.maxRetriggerHz))
            }
            SaveJobBar(jobName: $jobName, canSave: true) {
                jobs.save(SavedJob(
                    name: jobName,
                    toolID: .timer555,
                    inputs: [
                        "mode": "monostable",
                        "R": r1,
                        "C": c,
                        "R unit": rUnit.rawValue,
                        "C unit": cUnit.rawValue,
                    ],
                    outputs: ["t": Format.time(r.pulseWidth)]
                ))
            }
        case .failure(let err):
            ErrorText(message: err.message)
        }
    }

    private var ohms1: Double { (r1.parsedDouble ?? .nan) * rUnit.factor }
    private var ohms2: Double { (r2.parsedDouble ?? .nan) * rUnit.factor }
    private var farads: Double { (c.parsedDouble ?? .nan) * cUnit.factor }

    private var astable: Result<Astable555Result, CalcError> {
        CalcCatch.run { try Timer555.astable(r1: ohms1, r2: ohms2, capacitance: farads, diodeSteering: diode) }
    }

    private var mono: Result<Monostable555Result, CalcError> {
        CalcCatch.run { try Timer555.monostable(resistance: ohms1, capacitance: farads) }
    }

    private var substituted: String? {
        if mode == .astable, case .success(let r) = astable {
            return "\(r.formula)  →  f = \(Format.frequency(r.frequency)), duty \(Format.percent(r.dutyPercent))"
        }
        if mode == .monostable, case .success(let r) = mono {
            return "\(r.formula)  →  t = \(Format.time(r.pulseWidth))"
        }
        return nil
    }

    private var sticky: String? {
        if mode == .astable, case .success(let r) = astable {
            return "\(Format.frequency(r.frequency))  ·  \(Format.percent(r.dutyPercent)) duty"
        }
        if mode == .monostable, case .success(let r) = mono {
            return Format.time(r.pulseWidth)
        }
        return nil
    }

    private var copyText: String? { sticky }
}
