import SwiftUI
import BeckifyMath

struct MotorFLAView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredToggle(.motorFLA, "threePhase", default: true) private var threePhase
    @StoredInput(.motorFLA, "hp", default: "10") private var hp
    @StoredInput(.motorFLA, "systemVolts", default: "480") private var systemVolts
    @StoredInput(.motorFLA, "jobName", default: "Motor FLA") private var jobName

    private var table: [MotorFLARow] {
        threePhase ? MotorFLA.table430_250 : MotorFLA.table430_248
    }

    private var voltages: [String] {
        threePhase ? MotorFLA.threePhaseVoltages : MotorFLA.singlePhaseVoltages
    }

    private var hpOptions: [String] { table.map(\.horsepower) }

    var body: some View {
        ToolScaffold(toolID: .motorFLA, stickyAnswer: sticky, copyText: copyText) {
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

            if let col = MotorFLA.tableVoltage(forSystemVolts: systemVolts.parsedDouble ?? 0, threePhase: threePhase),
               let fla = MotorFLA.lookup(horsepower: hp, voltageColumn: col, threePhase: threePhase) {
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Table column", value: "\(col) V", tone: Theme.muted)
                    ResultRow(label: "Table FLA", value: Format.amps(fla), emphasis: true, tone: Theme.good)
                    ResultRow(label: "Conductor min (430.22)", value: Format.amps(MotorFLA.conductorAmps(fla: fla)))
                }
                SaveJobBar(jobName: $jobName, canSave: true) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .motorFLA,
                        inputs: ["HP": hp, "V": systemVolts, "table": threePhase ? "430.250" : "430.248"],
                        outputs: ["FLA": Format.amps(fla)]
                    ))
                }
            } else {
                ErrorText(message: "No table value for this HP / voltage combination. Pick a listed horsepower and a voltage this table actually has a column for.")
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

    private var substituted: String? {
        guard let col = MotorFLA.tableVoltage(forSystemVolts: systemVolts.parsedDouble ?? 0, threePhase: threePhase),
              let fla = MotorFLA.lookup(horsepower: hp, voltageColumn: col, threePhase: threePhase) else {
            return nil
        }
        let article = threePhase ? "430.250" : "430.248"
        return "Table \(article), \(hp) HP @ \(col) V column = \(Format.amps(fla)). Conductor min = 1.25 × FLA = \(Format.amps(MotorFLA.conductorAmps(fla: fla)))."
    }

    private var sticky: String? {
        guard let col = MotorFLA.tableVoltage(forSystemVolts: systemVolts.parsedDouble ?? 0, threePhase: threePhase),
              let fla = MotorFLA.lookup(horsepower: hp, voltageColumn: col, threePhase: threePhase) else {
            return nil
        }
        return "\(Format.amps(fla))  ·  \(hp) HP @ \(col) V"
    }

    private var copyText: String? { sticky }
}
