import SwiftUI
import BeckifyMath

struct ConduitFillView: View {
    @EnvironmentObject private var jobs: JobStore
    @State private var qty = "4"
    @State private var size = "12"
    @State private var trade = "3/4"
    @State private var jobName = "Conduit fill"

    private var sizes: [String] { NECTables.wireSizeOrder.filter { NECTables.thhnArea[$0] != nil } }
    private var trades: [String] { NECTables.emtArea.map(\.trade) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FormulaCard(
                    text: "1 wire → 53%    2 wires → 31%    3+ → 40%",
                    citation: "NEC Chapter 9 Table 1. Areas from Table 4 (EMT) and Table 5 (THHN/THWN-2)."
                )
                NumberField(title: "Conductor count", unit: "ea", text: $qty)
                menuPicker("THHN size", selection: $size, options: sizes, label: NECTables.wireLabel)
                menuPicker("EMT trade size", selection: $trade, options: trades, label: { "\($0)\"" })

                switch calc {
                case .success(let r):
                    ResultCard {
                        ResultRow(label: "Wire area", value: "\(Format.number(r.totalWireArea, digits: 4)) in²")
                        ResultRow(label: "EMT area", value: "\(Format.number(r.conduitArea, digits: 3)) in²")
                        ResultRow(label: "Table 1 limit", value: Format.percent(r.maxFillPercent))
                        ResultRow(label: "Actual fill", value: Format.percent(r.actualFillPercent), emphasis: true, tone: r.passes ? Theme.good : Theme.bad)
                        ResultRow(label: "Status", value: r.passes ? "PASS" : "FAIL — exceeds Table 1", tone: r.passes ? Theme.good : Theme.bad)
                        if let sug = r.suggestedTradeSize {
                            ResultRow(label: "Minimum EMT", value: "\(sug)\"", tone: Theme.warn)
                        }
                    }
                    SaveJobBar(jobName: $jobName, canSave: true) {
                        jobs.save(SavedJob(
                            name: jobName,
                            toolID: .conduitFill,
                            inputs: ["n": qty, "size": size, "emt": trade],
                            outputs: ["fill": Format.percent(r.actualFillPercent), "ok": r.passes ? "PASS" : "FAIL"]
                        ))
                    }
                case .failure(let err):
                    ErrorText(message: err.message)
                }
                DisclaimerBanner()
            }
            .padding(20)
        }
        .navigationTitle("Conduit Fill")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func menuPicker(_ title: String, selection: Binding<String>, options: [String], label: @escaping (String) -> String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.muted)
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { Text(label($0)).tag($0) }
            }
            .pickerStyle(.menu)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var calc: Result<ConduitFillResult, CalcError> {
        do {
            let n = try WholeCount.parse(qty.parsedDouble ?? .nan, name: "Conductor quantity")
            return .success(try ConduitFill.calculate(quantity: n, size: size, tradeSize: trade))
        } catch let error as CalcError {
            return .failure(error)
        } catch {
            return .failure(.missing("values"))
        }
    }
}
