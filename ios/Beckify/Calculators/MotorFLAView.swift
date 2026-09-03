import SwiftUI
import BeckifyMath

struct MotorFLAView: View {
    private struct LookupResult: Equatable, Sendable {
        var columnVolts: String
        var fla: Double
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredToggle(.motorFLA, "threePhase", default: true) private var threePhase
    @StoredInput(.motorFLA, "hp", default: "10") private var hp
    @StoredInput(.motorFLA, "systemVolts", default: "480") private var systemVolts
    @StoredInput(.motorFLA, "jobName", default: "Motor FLA") private var jobName
    @State private var session = ExplicitCalculationSession<LookupResult>()
    @State private var successTick = 0

    private var table: [MotorFLARow] {
        threePhase ? MotorFLA.table430_250 : MotorFLA.table430_248
    }

    private var voltages: [String] {
        threePhase ? MotorFLA.threePhaseVoltages : MotorFLA.singlePhaseVoltages
    }

    private var hpOptions: [String] { table.map(\.horsepower) }

    private var fingerprint: String { "\(threePhase)|\(hp)|\(systemVolts)" }
    private var display: ExplicitCalculationSession<LookupResult>.Display {
        session.display(for: fingerprint)
    }

    var body: some View {
        ToolScaffold(
            toolID: .motorFLA,
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
            ShowWorkCard(
                toolID: .motorFLA,
                symbolic: "Use table FLA, not nameplate, for conductors and OCPD (430.6(A)(1)).",
                substituted: substituted,
                meaning: "480 V systems use the 460 V column. Conductors at 125% of table FLA (430.22). This is table current, not a nameplate reading.",
                citation: "NEC 430.248 single-phase · 430.250 three-phase squirrel-cage."
            )
            TryExampleButton(title: "10 HP, 480 V 3Ø") {
                threePhase = true
                hp = "10"
                systemVolts = "480"
            }
            Picker("Table", selection: $threePhase) {
                Text("430.248 1Ø").tag(false)
                Text("430.250 3Ø").tag(true)
            }
            .pickerStyle(.segmented)

            MenuField(title: "Horsepower", selection: $hp, options: hpOptions) { "\($0) HP" }
            NumberField(title: "System voltage", unit: "V", text: $systemVolts)

            switch display {
            case .current(let r), .stale(let r):
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Table column", value: "\(r.columnVolts) V", tone: Theme.muted)
                    ResultRow(label: "Table FLA", value: Format.amps(r.fla), emphasis: true, tone: Theme.good)
                    ResultRow(label: "Conductor min (430.22)", value: Format.amps(MotorFLA.conductorAmps(fla: r.fla)))
                }
                SaveJobBar(jobName: $jobName, canSave: { if case .current = display { true } else { false } }()) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .motorFLA,
                        inputs: ["HP": hp, "V": systemVolts, "table": threePhase ? "430.250" : "430.248"],
                        outputs: ["FLA": Format.amps(r.fla)]
                    ))
                }
            case .idle:
                ToolEmptyState(
                    title: "Pick HP and voltage",
                    detail: "Choose table HP and system volts, then Calculate.",
                    systemImage: "fanblades"
                )
            case .failed:
                EmptyView()
            }

            ResultCard(title: threePhase ? "NEC Table 430.250" : "NEC Table 430.248") {
                ForEach(table, id: \.horsepower) { row in
                    HStack {
                        Text("\(row.horsepower) HP")
                            .font(.caption.weight(.semibold))
                            .frame(minWidth: 64, alignment: .leading)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(voltages, id: \.self) { v in
                                    VStack(spacing: 2) {
                                        Text("\(v) V").font(.caption2).foregroundStyle(Theme.muted)
                                        Text(row.amps(at: v).map { Format.number($0, digits: 1) } ?? "—")
                                            .font(.caption.monospacedDigit())
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .onChange(of: threePhase) { _, _ in
            let opts = hpOptions
            if !opts.contains(hp) { hp = opts.first ?? hp }
        }
    }

    private var isStale: Bool {
        if case .stale = display { return true }
        return false
    }

    private func calculate() {
        session.calculate(fingerprint: fingerprint) {
            guard let col = MotorFLA.tableVoltage(forSystemVolts: systemVolts.parsedDouble ?? .nan, threePhase: threePhase),
                  let fla = MotorFLA.lookup(horsepower: hp, voltageColumn: col, threePhase: threePhase) else {
                throw CalcError.outOfRange(
                    "No table value for this HP / voltage combination. Pick a listed horsepower and a voltage this table actually has a column for."
                )
            }
            return LookupResult(columnVolts: col, fla: fla)
        }
        if case .current = session.display(for: fingerprint) {
            successTick += 1
        }
    }

    private func reset() {
        session.reset()
        threePhase = true
        hp = "10"
        systemVolts = "480"
    }

    private var substituted: String? {
        guard case .current(let r) = display else { return nil }
        let article = threePhase ? "430.250" : "430.248"
        return "Table \(article), \(hp) HP @ \(r.columnVolts) V column = \(Format.amps(r.fla)). Conductor min = 1.25 × FLA = \(Format.amps(MotorFLA.conductorAmps(fla: r.fla)))."
    }

    private var sticky: String? {
        switch display {
        case .current(let r), .stale(let r):
            return "\(Format.amps(r.fla))  ·  \(hp) HP @ \(r.columnVolts) V"
        default:
            return nil
        }
    }

    private var copyText: String? { sticky }
}
