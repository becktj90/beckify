import SwiftUI
import BeckifyMath

struct VoltageDropView: View {
    @EnvironmentObject private var jobs: JobStore
    @State private var system: ElectricalSystem = .threePhase
    @State private var voltage = "480"
    @State private var current = "45"
    @State private var length = "250"
    @State private var material: ConductorMaterial = .copper
    @State private var size = "4"
    @State private var jobName = "Voltage drop"

    private var sizes: [String] {
        NECTables.wireSizeOrder.filter { NECTables.circularMils[$0] != nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FormulaCard(
                    text: "VD = (M × K × I × L) / CM",
                    citation: "M = 2 (1Ø/DC) or √3 (3Ø). K = 12.9 Cu / 21.2 Al at 75 °C. 3% and 5% are informational notes, not hard NEC limits."
                )
                Picker("System", selection: $system) {
                    ForEach(ElectricalSystem.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Material", selection: $material) {
                    ForEach(ConductorMaterial.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)

                NumberField(title: "Supply voltage", unit: "V", text: $voltage)
                NumberField(title: "Load current", unit: "A", text: $current)
                NumberField(title: "One-way length", unit: "ft", text: $length)

                VStack(alignment: .leading, spacing: 6) {
                    Text("CONDUCTOR")
                        .font(.caption.weight(.semibold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.muted)
                    Picker("Size", selection: $size) {
                        ForEach(sizes, id: \.self) { Text(NECTables.wireLabel($0)).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                switch calc {
                case .success(let r):
                    ResultCard {
                        ResultRow(label: "Voltage drop", value: Format.volts(r.dropVolts), emphasis: true)
                        ResultRow(label: "Drop", value: Format.percent(r.dropPercent), emphasis: true)
                        ResultRow(label: "Receiving end", value: Format.volts(r.receivingVolts))
                        ResultRow(
                            label: "≤ 3% informational",
                            value: r.meets3Percent ? "PASS" : "OVER 3%",
                            tone: r.meets3Percent ? Theme.good : Theme.warn
                        )
                        ResultRow(
                            label: "≤ 5% informational",
                            value: r.meets5Percent ? "PASS" : "OVER 5%",
                            tone: r.meets5Percent ? Theme.good : Theme.bad
                        )
                        if let amp = r.ampacity75C {
                            ResultRow(
                                label: "310.16 75 °C",
                                value: "\(amp) A" + (r.ampacityOK == true ? "  meets load" : "  undersized"),
                                tone: r.ampacityOK == true ? Theme.good : Theme.bad
                            )
                        }
                    }
                    SaveJobBar(jobName: $jobName, canSave: true) {
                        jobs.save(SavedJob(
                            name: jobName,
                            toolID: .voltageDrop,
                            inputs: ["sys": system.displayName, "V": voltage, "I": current, "L": length, "size": size, "material": material.displayName],
                            outputs: ["VD": Format.volts(r.dropVolts), "%": Format.percent(r.dropPercent)]
                        ))
                    }
                case .failure(let err):
                    ErrorText(message: err.message)
                }
                DisclaimerBanner()
            }
            .padding(20)
        }
        .navigationTitle("Voltage Drop")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var calc: Result<VoltageDropResult, CalcError> {
        do {
            return .success(try VoltageDrop.calculate(
                system: system,
                current: current.parsedDouble ?? .nan,
                oneWayFeet: length.parsedDouble ?? .nan,
                supplyVolts: voltage.parsedDouble ?? .nan,
                size: size,
                material: material
            ))
        } catch let error as CalcError {
            return .failure(error)
        } catch {
            return .failure(.missing("values"))
        }
    }
}
