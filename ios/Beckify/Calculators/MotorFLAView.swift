import SwiftUI
import BeckifyMath

struct MotorFLAView: View {
    @EnvironmentObject private var jobs: JobStore
    @State private var threePhase = true
    @State private var hp = "10"
    @State private var systemVolts = "480"
    @State private var jobName = "Motor FLA"

    private var table: [MotorFLARow] {
        threePhase ? MotorFLA.table430_250 : MotorFLA.table430_248
    }

    private var voltages: [String] {
        threePhase ? MotorFLA.threePhaseVoltages : MotorFLA.singlePhaseVoltages
    }

    private var hpOptions: [String] { table.map(\.horsepower) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FormulaCard(
                    text: "Use table FLA, not nameplate, for conductors and OCPD (430.6(A)(1)).",
                    citation: "430.248 single-phase · 430.250 three-phase squirrel-cage. 480 V systems use the 460 V column. Conductors at 125% (430.22)."
                )
                Picker("Table", selection: $threePhase) {
                    Text("430.248 1Ø").tag(false)
                    Text("430.250 3Ø").tag(true)
                }
                .pickerStyle(.segmented)

                menu("Horsepower", selection: $hp, options: hpOptions)
                NumberField(title: "System voltage", unit: "V", text: $systemVolts)

                if let col = MotorFLA.tableVoltage(forSystemVolts: systemVolts.parsedDouble ?? 0, threePhase: threePhase),
                   let fla = MotorFLA.lookup(horsepower: hp, voltageColumn: col, threePhase: threePhase) {
                    ResultCard {
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
                    ErrorText(message: "No table value for this HP / voltage combination.")
                }

                ResultCard(title: threePhase ? "NEC Table 430.250" : "NEC Table 430.248") {
                    ForEach(table, id: \.horsepower) { row in
                        HStack {
                            Text("\(row.horsepower) HP")
                                .font(.caption.weight(.semibold))
                                .frame(width: 64, alignment: .leading)
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
                DisclaimerBanner()
            }
            .padding(20)
        }
        .navigationTitle("Motor FLA")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: threePhase) { _, _ in
            let opts = hpOptions
            if !opts.contains(hp) { hp = opts.first ?? hp }
        }
    }

    private func menu(_ title: String, selection: Binding<String>, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.muted)
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { Text("\($0) HP").tag($0) }
            }
            .pickerStyle(.menu)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
