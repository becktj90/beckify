import SwiftUI
import BeckifyMath

struct OhmsLawView: View {
    @EnvironmentObject private var jobs: JobStore
    @State private var voltage = "12"
    @State private var current = "2"
    @State private var resistance = ""
    @State private var jobName = "Ohm's Law"

    var result: Result<OhmsLawResult, CalcError> {
        do {
            return .success(try OhmsLaw.solve(
                voltage: voltage.parsedDouble,
                current: current.parsedDouble,
                resistance: resistance.parsedDouble
            ))
        } catch let error as CalcError {
            return .failure(error)
        } catch {
            return .failure(.missing("values"))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FormulaCard(text: "V = I × R     P = V × I", citation: "Leave one field blank to solve for it.")
                NumberField(title: "Voltage", unit: "V", text: $voltage, optional: true)
                NumberField(title: "Current", unit: "A", text: $current, optional: true)
                NumberField(title: "Resistance", unit: "Ω", text: $resistance, optional: true)
                switch result {
                case .success(let r):
                    ResultCard {
                        ResultRow(label: "Voltage", value: Format.volts(r.voltage), emphasis: true)
                        ResultRow(label: "Current", value: Format.amps(r.current), emphasis: true)
                        ResultRow(label: "Resistance", value: "\(Format.number(r.resistance, digits: 3)) Ω", emphasis: true)
                        ResultRow(label: "Power", value: "\(Format.watts(r.power))  (\(Format.number(r.power / 1000, digits: 3)) kW)", tone: Theme.good)
                    }
                    SaveJobBar(jobName: $jobName, canSave: true) { save(r) }
                case .failure(let err):
                    ErrorText(message: err.message)
                }
                DisclaimerBanner()
            }
            .padding(20)
        }
        .navigationTitle("Ohm's Law")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save(_ r: OhmsLawResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .ohmsLaw,
            inputs: ["V": voltage, "I": current, "R": resistance],
            outputs: [
                "V": Format.volts(r.voltage),
                "I": Format.amps(r.current),
                "R": "\(Format.number(r.resistance)) Ω",
                "P": Format.watts(r.power),
            ]
        ))
    }
}
