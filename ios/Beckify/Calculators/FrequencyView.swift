import SwiftUI
import BeckifyMath

struct FrequencyView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case freq = "f"
        case period = "T"
        case wavelength = "λ"
        case lc = "LC"
        var id: String { rawValue }
    }

    @EnvironmentObject private var jobs: JobStore
    @State private var mode: Mode = .freq
    @State private var frequency = "1000000"
    @State private var period = "1e-6"
    @State private var wavelength = "300"
    @State private var inductance = "0.0001"
    @State private var capacitance = "1e-10"
    @State private var jobName = "Frequency"

    var result: Result<FrequencyResult, CalcError> {
        do {
            switch mode {
            case .freq: return .success(try Wave.fromFrequency(frequency.parsedDouble ?? .nan))
            case .period: return .success(try Wave.fromPeriod(period.parsedDouble ?? .nan))
            case .wavelength: return .success(try Wave.fromWavelength(wavelength.parsedDouble ?? .nan))
            case .lc: return .success(try Wave.lcResonance(inductance: inductance.parsedDouble ?? .nan, capacitance: capacitance.parsedDouble ?? .nan))
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
                    text: mode == .lc ? "f = 1 / (2π √(LC))" : "T = 1/f    λ = c/f    c = 2.99792458×10⁸ m/s",
                    citation: "Free-space wavelength. Not a transmission-line velocity factor."
                )
                Picker("Known", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                switch mode {
                case .freq: NumberField(title: "Frequency", unit: "Hz", text: $frequency, allowsScientific: true)
                case .period: NumberField(title: "Period", unit: "s", text: $period, allowsScientific: true)
                case .wavelength: NumberField(title: "Wavelength", unit: "m", text: $wavelength, allowsScientific: true)
                case .lc:
                    NumberField(title: "L", unit: "H", text: $inductance, allowsScientific: true)
                    NumberField(title: "C", unit: "F", text: $capacitance, allowsScientific: true)
                }
                switch result {
                case .success(let r):
                    ResultCard {
                        ResultRow(label: "Frequency", value: Format.frequency(r.frequency), emphasis: true, tone: Theme.good)
                        ResultRow(label: "Period", value: Format.time(r.period), emphasis: true)
                        ResultRow(label: "Wavelength", value: Format.meters(r.wavelength))
                    }
                    SaveJobBar(jobName: $jobName, canSave: true) { save(r) }
                case .failure(let err):
                    ErrorText(message: err.message)
                }
                DisclaimerBanner()
            }
            .padding(20)
        }
        .navigationTitle("Frequency / LC")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save(_ r: FrequencyResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .frequencyWave,
            inputs: ["mode": mode.rawValue, "f": frequency, "T": period, "λ": wavelength, "L": inductance, "C": capacitance],
            outputs: [
                "f": Format.frequency(r.frequency),
                "T": Format.time(r.period),
                "λ": Format.meters(r.wavelength),
            ]
        ))
    }
}
