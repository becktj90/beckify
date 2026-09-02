import SwiftUI
import BeckifyMath

struct WireAmpacityView: View {
    @EnvironmentObject private var jobs: JobStore
    @State private var amps = "95"
    @State private var material: ConductorMaterial = .copper
    @State private var jobName = "Wire size"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FormulaCard(
                    text: "NEC Table 310.16 · 75 °C column",
                    citation: "Not more than three current-carrying conductors in a raceway, 30 °C ambient. Termination temperature still applies (110.14(C))."
                )
                Picker("Material", selection: $material) {
                    ForEach(ConductorMaterial.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                NumberField(title: "Load current", unit: "A", text: $amps)

                switch sized {
                case .success(let r):
                    ResultCard {
                        ResultRow(label: "Smallest size", value: r.label, emphasis: true, tone: Theme.good)
                        ResultRow(label: "Ampacity 75 °C", value: Format.amps(Double(r.ampacity)))
                    }
                    SaveJobBar(jobName: $jobName, canSave: true) {
                        jobs.save(SavedJob(
                            name: jobName,
                            toolID: .wireAmpacity,
                            inputs: ["I": amps, "mat": material.displayName],
                            outputs: ["size": r.label, "amp": "\(r.ampacity) A"]
                        ))
                    }
                case .failure(let err):
                    ErrorText(message: err.message)
                }

                ResultCard(title: "310.16 75 °C") {
                    ForEach(WireAmpacity.table310_16_75C, id: \.size) { row in
                        HStack {
                            Text(row.label)
                                .font(.subheadline.monospacedDigit())
                            Spacer()
                            Text(row.copper75C.map { "Cu \($0) A" } ?? "—")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(material == .copper ? Theme.foreground : Theme.muted)
                            Text(row.aluminum75C.map { "Al \($0) A" } ?? "Al —")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(material == .aluminum ? Theme.foreground : Theme.muted)
                                .frame(width: 72, alignment: .trailing)
                        }
                        .padding(.vertical, 3)
                    }
                }
                DisclaimerBanner()
            }
            .padding(20)
        }
        .navigationTitle("Wire Size & Ampacity")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sized: Result<WireSizeResult, CalcError> {
        do {
            return .success(try WireAmpacity.smallestConductor(loadAmps: amps.parsedDouble ?? .nan, material: material))
        } catch let error as CalcError {
            return .failure(error)
        } catch {
            return .failure(.missing("Load current"))
        }
    }
}
