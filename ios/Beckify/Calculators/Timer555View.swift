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

    private enum SessionResult: Equatable {
        case astable(Astable555Result)
        case monostable(Monostable555Result)
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.timer555, "mode", default: Mode.astable) private var mode
    @StoredInput(.timer555, "r1", default: "10") private var r1
    @StoredInput(.timer555, "r2", default: "47") private var r2
    @StoredInput(.timer555, "c", default: "0.1") private var c
    @StoredChoice(.timer555, "rUnit", default: RUnit.k) private var rUnit
    @StoredChoice(.timer555, "cUnit", default: CUnit.uF) private var cUnit
    @StoredToggle(.timer555, "diode", default: false) private var diode
    @StoredInput(.timer555, "jobName", default: "555 timer") private var jobName
    @State private var session = ExplicitCalculationState<SessionResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(mode)|\(r1)|\(r2)|\(c)|\(rUnit)|\(cUnit)|\(diode)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .timer555,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
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
                unitField("R1", text: $r1)
                unitField("R2", text: $r2)
                capField()
                Toggle("Diode across R2 (sub-50% duty)", isOn: $diode)
                    .tint(Theme.accent)
                    .frame(minHeight: Theme.touchTarget)
            } else {
                ShowWorkCard(
                    toolID: .timer555,
                    symbolic: "t = ln(3) × R × C ≈ 1.1 RC",
                    substituted: substituted,
                    meaning: "Monostable pulse width while the capacitor charges from 0 to 2/3 Vcc."
                )
                unitField("R", text: $r1)
                capField()
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    if mode == .astable {
                        r1 = "10"
                        r2 = "47"
                        c = "0.1"
                        rUnit = .k
                        cUnit = .uF
                        diode = false
                    } else {
                        r1 = "10"
                        c = "0.1"
                        rUnit = .k
                        cUnit = .uF
                    }
                    session.prepareForNewInputs()
                },
                exampleTitle: mode == .astable ? "10 kΩ / 47 kΩ / 0.1 µF astable" : "10 kΩ / 0.1 µF one-shot"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let output = session.displayedResult {
                switch output {
                case .astable(let r):
                    if r.frequency.isFinite, r.dutyPercent.isFinite {
                        Timer555WaveformDiagram(frequency: r.frequency, dutyPercent: r.dutyPercent)
                            .opacity(session.isStale ? 0.72 : 1)
                    }
                    ResultCard(copyText: copyText) {
                        ResultRow(label: "t high", value: Format.time(r.timeHigh), emphasis: true, tone: Theme.good)
                        ResultRow(label: "t low", value: Format.time(r.timeLow), emphasis: true, tone: Theme.warn)
                        ResultRow(label: "Period", value: Format.time(r.period))
                        ResultRow(label: "Frequency", value: Format.frequency(r.frequency), emphasis: true)
                        ResultRow(label: "Duty cycle", value: Format.percent(r.dutyPercent))
                    }
                    .opacity(session.isStale ? 0.72 : 1)
                    SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
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
                case .monostable(let r):
                    if r.pulseWidth.isFinite, r.pulseWidth > 0 {
                        MonostableCapChargeChart(pulseWidth: r.pulseWidth)
                            .opacity(session.isStale ? 0.72 : 1)
                    }
                    ResultCard(copyText: copyText) {
                        ResultRow(label: "Pulse width", value: Format.time(r.pulseWidth), emphasis: true, tone: Theme.good)
                        ResultRow(label: "Max retrigger", value: Format.frequency(r.maxRetriggerHz))
                    }
                    .opacity(session.isStale ? 0.72 : 1)
                    SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
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
                }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func unitField(_ title: String, text: Binding<String>) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            NumberField(title: title, unit: rUnit.rawValue, text: text, onSubmit: calculate)
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
            NumberField(title: "C", unit: cUnit.rawValue, text: $c, onSubmit: calculate)
            Picker("C unit", selection: $cUnit) {
                ForEach(CUnit.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(minHeight: Theme.touchTarget)
            .padding(.bottom, 4)
            .accessibilityLabel("Capacitance unit")
        }
    }

    private var ohms1: Double { (r1.parsedDouble ?? .nan) * rUnit.factor }
    private var ohms2: Double { (r2.parsedDouble ?? .nan) * rUnit.factor }
    private var farads: Double { (c.parsedDouble ?? .nan) * cUnit.factor }

    private func calculate() {
        session.calculate {
            if mode == .astable {
                return .astable(try Timer555.astable(r1: ohms1, r2: ohms2, capacitance: farads, diodeSteering: diode))
            }
            return .monostable(try Timer555.monostable(resistance: ohms1, capacitance: farads))
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        r1 = ""
        r2 = ""
        c = ""
        session.reset()
    }

    private var substituted: String? {
        guard let output = session.displayedResult else { return nil }
        switch output {
        case .astable(let r):
            return "\(r.formula)  →  f = \(Format.frequency(r.frequency)), duty \(Format.percent(r.dutyPercent))"
        case .monostable(let r):
            return "\(r.formula)  →  t = \(Format.time(r.pulseWidth))"
        }
    }

    private var sticky: String? {
        guard let output = session.displayedResult else { return nil }
        switch output {
        case .astable(let r):
            return "\(Format.frequency(r.frequency))  ·  \(Format.percent(r.dutyPercent)) duty"
        case .monostable(let r):
            return Format.time(r.pulseWidth)
        }
    }

    private var copyText: String? { sticky }
}
