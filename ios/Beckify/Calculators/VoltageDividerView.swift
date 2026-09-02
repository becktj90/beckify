import SwiftUI
import BeckifyMath

struct VoltageDividerView: View {
    enum Solve: String, CaseIterable, Identifiable {
        case vout = "Vout"
        case r1 = "R1"
        case r2 = "R2"
        var id: String { rawValue }
    }

    @EnvironmentObject private var jobs: JobStore
    @State private var solve: Solve = .vout
    @State private var vin = "12"
    @State private var vout = "6"
    @State private var r1 = "10000"
    @State private var r2 = "10000"
    @State private var jobName = "Voltage divider"

    var result: Result<VoltageDividerResult, CalcError> {
        do {
            switch solve {
            case .vout:
                return .success(try VoltageDivider.fromResistors(vin: vin.parsedDouble ?? .nan, r1: r1.parsedDouble ?? .nan, r2: r2.parsedDouble ?? .nan))
            case .r1:
                return .success(try VoltageDivider.solveR1(vin: vin.parsedDouble ?? .nan, vout: vout.parsedDouble ?? .nan, r2: r2.parsedDouble ?? .nan))
            case .r2:
                return .success(try VoltageDivider.solveR2(vin: vin.parsedDouble ?? .nan, vout: vout.parsedDouble ?? .nan, r1: r1.parsedDouble ?? .nan))
            }
        } catch let error as CalcError {
            return .failure(error)
        } catch {
            return .failure(.missing("values"))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FormulaCard(
                    text: "Vout = Vin × R2 / (R1 + R2)",
                    citation: "Unloaded divider. R1 is top (from Vin), R2 is to ground. Homework / breadboard aid — not a loaded Thevenin model."
                )
                Picker("Solve", selection: $solve) {
                    ForEach(Solve.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                NumberField(title: "Vin", unit: "V", text: $vin)
                if solve != .vout { NumberField(title: "Vout", unit: "V", text: $vout) }
                if solve != .r1 { NumberField(title: "R1 (top)", unit: "Ω", text: $r1) }
                if solve != .r2 { NumberField(title: "R2 (to GND)", unit: "Ω", text: $r2) }
                switch result {
                case .success(let r):
                    ResultCard {
                        ResultRow(label: "Vin", value: Format.volts(r.vin))
                        ResultRow(label: "Vout", value: Format.volts(r.vout), emphasis: true, tone: Theme.good)
                        ResultRow(label: "R1", value: "\(Format.number(r.r1, digits: 3)) Ω", emphasis: true)
                        ResultRow(label: "R2", value: "\(Format.number(r.r2, digits: 3)) Ω", emphasis: true)
                        ResultRow(label: "I", value: Format.amps(r.current))
                    }
                    SaveJobBar(jobName: $jobName, canSave: true) { save(r) }
                case .failure(let err):
                    ErrorText(message: err.message)
                }
                DisclaimerBanner()
            }
            .padding(20)
        }
        .navigationTitle("Voltage Divider")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save(_ r: VoltageDividerResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .voltageDivider,
            inputs: ["solve": solve.rawValue, "Vin": vin, "Vout": vout, "R1": r1, "R2": r2],
            outputs: [
                "Vout": Format.volts(r.vout),
                "R1": "\(Format.number(r.r1)) Ω",
                "R2": "\(Format.number(r.r2)) Ω",
                "I": Format.amps(r.current),
            ]
        ))
    }
}
