import SwiftUI
import BeckifyMath

struct ConduitFillView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.conduitFill, "qty", default: "4") private var qty
    @StoredInput(.conduitFill, "size", default: "12") private var size
    @StoredInput(.conduitFill, "trade", default: "3/4") private var trade
    @StoredInput(.conduitFill, "jobName", default: "Conduit fill") private var jobName

    private var sizes: [String] { NECTables.wireSizeOrder.filter { NECTables.thhnArea[$0] != nil } }
    private var trades: [String] { NECTables.emtArea.map(\.trade) }

    var body: some View {
        ToolScaffold(toolID: .conduitFill, stickyAnswer: sticky, copyText: copyText) {
            ShowWorkCard(
                toolID: .conduitFill,
                symbolic: "1 wire → 53%    2 wires → 31%    3+ → 40%",
                substituted: substituted,
                meaning: "Fill percent is conductor area over raceway area. Over 40% with three or more THHN in EMT fails Chapter 9 Table 1 in this calculator.",
                citation: "NEC Chapter 9 Table 1. Areas from Table 4 (EMT) and Table 5 (THHN/THWN-2)."
            )
            TryExampleButton(title: "Four 12 AWG THHN in ¾\" EMT") {
                qty = "4"
                size = "12"
                trade = "3/4"
            }
            NumberField(title: "Conductor count", unit: "ea", text: $qty)
            MenuField(title: "THHN size", selection: $size, options: sizes, label: NECTables.wireLabel)
            MenuField(title: "EMT trade size", selection: $trade, options: trades, label: { "\($0)\"" })

            switch calc {
            case .success(let r):
                ResultCard(copyText: copyText) {
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
        }
    }

    private var substituted: String? {
        guard case .success(let r) = calc else { return nil }
        return "Fill % = (\(qty) × conductor area) / raceway area × 100 = \(Format.percent(r.actualFillPercent))  (limit \(Format.percent(r.maxFillPercent)))"
    }

    private var sticky: String? {
        guard case .success(let r) = calc else { return nil }
        return "\(Format.percent(r.actualFillPercent))  ·  \(r.passes ? "PASS" : "FAIL")"
    }

    private var copyText: String? { sticky }

    private var calc: Result<ConduitFillResult, CalcError> {
        CalcCatch.run {
            let n = try WholeCount.parse(qty.parsedDouble ?? .nan, name: "Conductor quantity")
            return try ConduitFill.calculate(quantity: n, size: size, tradeSize: trade)
        }
    }
}
