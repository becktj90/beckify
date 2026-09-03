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

    private enum Output: Equatable, Sendable {
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
    @State private var session = ExplicitCalculationSession<Output>()
    @State private var successTick = 0

    private var ohms1: Double { (r1.parsedDouble ?? .nan) * rUnit.factor }
    private var ohms2: Double { (r2.parsedDouble ?? .nan) * rUnit.factor }
    private var farads: Double { (c.parsedDouble ?? .nan) * cUnit.factor }

    private var fingerprint: String {
        "\(mode.rawValue)|\(r1)|\(r2)|\(c)|\(rUnit.rawValue)|\(cUnit.rawValue)|\(diode)"
    }
    private var display: ExplicitCalculationSession<Output>.Display {
        session.display(for: fingerprint)
    }

    var body: some View {
        ToolScaffold(
            toolID: .timer555,
            stickyAnswer: sticky,
            copyText: copyText,
            dock: {
                CalculateActionBar(
                    isStale: isStale,
                    errorMessage: session.visibleError(for: fingerprint),
                    successTick: successTick,
                    onCalculate: calculate,
                    onReset: reset
                )
            }
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
            }

            switch display {
            case .current(let output), .stale(let output):
                resultCard(for: output)
                if case .current = display {
                    SaveJobBar(jobName: $jobName, canSave: true) { save(output) }
                }
            case .idle:
                ToolEmptyState(
                    title: "Enter R and C",
                    detail: "Set resistance, capacitance, and mode, then Calculate.",
                    systemImage: "timer"
                )
            case .failed:
                EmptyView()
            }
        }
    }

    private var isStale: Bool {
        if case .stale = display { return true }
        return false
    }

    private func calculate() {
        session.calculate(fingerprint: fingerprint) {
            if mode == .astable {
                return .astable(try Timer555.astable(r1: ohms1, r2: ohms2, capacitance: farads, diodeSteering: diode))
            }
            return .monostable(try Timer555.monostable(resistance: ohms1, capacitance: farads))
        }
        if case .current = session.display(for: fingerprint) {
            successTick += 1
        }
    }

    private func reset() {
        session.reset()
        mode = .astable
        r1 = "10"
        r2 = "47"
        c = "0.1"
        rUnit = .k
        cUnit = .uF
        diode = false
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
    private func resultCard(for output: Output) -> some View {
        switch output {
        case .astable(let r):
            ResultCard(copyText: copyText) {
                ResultRow(label: "t high", value: Format.time(r.timeHigh), emphasis: true, tone: Theme.good)
                ResultRow(label: "t low", value: Format.time(r.timeLow), emphasis: true, tone: Theme.warn)
                ResultRow(label: "Period", value: Format.time(r.period))
                ResultRow(label: "Frequency", value: Format.frequency(r.frequency), emphasis: true)
                ResultRow(label: "Duty cycle", value: Format.percent(r.dutyPercent))
            }
        case .monostable(let r):
            ResultCard(copyText: copyText) {
                ResultRow(label: "Pulse width", value: Format.time(r.pulseWidth), emphasis: true, tone: Theme.good)
                ResultRow(label: "Max retrigger", value: Format.frequency(r.maxRetriggerHz))
            }
        }
    }

    private func save(_ output: Output) {
        switch output {
        case .astable(let r):
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
        case .monostable(let r):
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

    private var substituted: String? {
        guard case .current(let output) = display else { return nil }
        switch output {
        case .astable(let r):
            return "\(r.formula)  →  f = \(Format.frequency(r.frequency)), duty \(Format.percent(r.dutyPercent))"
        case .monostable(let r):
            return "\(r.formula)  →  t = \(Format.time(r.pulseWidth))"
        }
    }

    private var sticky: String? {
        switch display {
        case .current(let output), .stale(let output):
            switch output {
            case .astable(let r):
                return "\(Format.frequency(r.frequency))  ·  \(Format.percent(r.dutyPercent)) duty"
            case .monostable(let r):
                return Format.time(r.pulseWidth)
            }
        default:
            return nil
        }
    }

    private var copyText: String? { sticky }
}
