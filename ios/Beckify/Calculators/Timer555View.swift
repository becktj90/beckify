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
    @State private var mode: Mode = .astable
    @State private var r1 = "10"
    @State private var r2 = "47"
    @State private var c = "0.1"
    @State private var rUnit: RUnit = .k
    @State private var cUnit: CUnit = .uF
    @State private var diode = false
    @State private var jobName = "555 timer"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Mode", selection: $mode) {
                    Text("Astable").tag(Mode.astable)
                    Text("Monostable").tag(Mode.monostable)
                }
                .pickerStyle(.segmented)

                if mode == .astable {
                    FormulaCard(
                        text: diode ? "t1 = ln(2)·R1·C    t2 = ln(2)·R2·C" : "t1 = ln(2)·(R1+R2)·C    t2 = ln(2)·R2·C",
                        citation: "Standard bipolar 555 duty cycle stays above 50% unless R2 is diode-steered."
                    )
                    unitField("R1", text: $r1)
                    unitField("R2", text: $r2)
                    capField()
                    Toggle("Diode across R2 (sub-50% duty)", isOn: $diode)
                        .tint(Theme.accent)
                    astableResults
                } else {
                    FormulaCard(text: "t = ln(3) × R × C ≈ 1.1 RC", citation: "Capacitor charges 0 → 2/3 Vcc.")
                    unitField("R", text: $r1)
                    capField()
                    monostableResults
                }
                DisclaimerBanner()
            }
            .padding(20)
        }
        .navigationTitle("555 Timer")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func unitField(_ title: String, text: Binding<String>) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            NumberField(title: title, unit: rUnit.rawValue, text: text)
            Picker("R unit", selection: $rUnit) {
                ForEach(RUnit.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .padding(.bottom, 8)
        }
    }

    private func capField() -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            NumberField(title: "C", unit: cUnit.rawValue, text: $c)
            Picker("C unit", selection: $cUnit) {
                ForEach(CUnit.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var astableResults: some View {
        switch astable {
        case .success(let r):
            ResultCard {
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
                    inputs: ["R1": r1, "R2": r2, "C": c],
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
            ResultCard {
                ResultRow(label: "Pulse width", value: Format.time(r.pulseWidth), emphasis: true, tone: Theme.good)
                ResultRow(label: "Max retrigger", value: Format.frequency(r.maxRetriggerHz))
            }
            SaveJobBar(jobName: $jobName, canSave: true) {
                jobs.save(SavedJob(
                    name: jobName,
                    toolID: .timer555,
                    inputs: ["R": r1, "C": c],
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
        Result { try Timer555.astable(r1: ohms1, r2: ohms2, capacitance: farads, diodeSteering: diode) }
    }

    private var mono: Result<Monostable555Result, CalcError> {
        Result { try Timer555.monostable(resistance: ohms1, capacitance: farads) }
    }
}

private extension Result where Failure == CalcError {
    init(_ body: () throws -> Success) {
        do { self = .success(try body()) }
        catch let e as CalcError { self = .failure(e) }
        catch { self = .failure(.missing("values")) }
    }
}
