import SwiftUI
import BeckifyMath

struct ResistorColorView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case decode4 = "4-band"
        case decode5 = "5-band"
        case encode = "Encode"
        var id: String { rawValue }
    }

    @EnvironmentObject private var jobs: JobStore
    @State private var mode: Mode = .decode4
    @State private var d1: ResistorBand = .yellow
    @State private var d2: ResistorBand = .violet
    @State private var d3: ResistorBand = .black
    @State private var multiplier: ResistorBand = .red
    @State private var tolerance: ResistorBand = .gold
    @State private var ohms = "4700"
    @State private var encodeBands = 4
    @State private var jobName = "Color code"

    private var digitBands: [ResistorBand] { ResistorBand.allCases.filter { $0.digit != nil } }
    private var multiplierBands: [ResistorBand] { ResistorBand.allCases.filter { $0.multiplier != nil } }
    private var toleranceBands: [ResistorBand] { ResistorBand.allCases.filter { $0.tolerancePercent != nil } }

    var result: Result<ColorCodeResult, CalcError> {
        do {
            switch mode {
            case .decode4:
                return .success(try ResistorColorCode.decode4(d1: d1, d2: d2, multiplier: multiplier, tolerance: tolerance))
            case .decode5:
                return .success(try ResistorColorCode.decode5(d1: d1, d2: d2, d3: d3, multiplier: multiplier, tolerance: tolerance))
            case .encode:
                return .success(try ResistorColorCode.encode(ohms: ohms.parsedDouble ?? .nan, bands: encodeBands, tolerance: tolerance))
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
                    text: "4-band: (10×d1 + d2) × 10^n    5-band: (100×d1 + 10×d2 + d3) × 10^n",
                    citation: "IEC 60062 colors. Encode rounds the significand to integer digits."
                )
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                if mode == .encode {
                    NumberField(title: "Resistance", unit: "Ω", text: $ohms)
                    Picker("Bands", selection: $encodeBands) {
                        Text("4").tag(4)
                        Text("5").tag(5)
                    }
                    .pickerStyle(.segmented)
                    bandPicker("Tolerance", selection: $tolerance, options: toleranceBands)
                } else {
                    bandPicker("Digit 1", selection: $d1, options: digitBands)
                    bandPicker("Digit 2", selection: $d2, options: digitBands)
                    if mode == .decode5 {
                        bandPicker("Digit 3", selection: $d3, options: digitBands)
                    }
                    bandPicker("Multiplier", selection: $multiplier, options: multiplierBands)
                    bandPicker("Tolerance", selection: $tolerance, options: toleranceBands)
                }
                switch result {
                case .success(let r):
                    ResultCard {
                        ResultRow(label: "Resistance", value: "\(Format.number(r.ohms, digits: 4)) Ω", emphasis: true, tone: Theme.good)
                        ResultRow(label: "Tolerance", value: "± \(Format.number(r.tolerancePercent, digits: 2)) %")
                        ResultRow(label: "Bands", value: r.bands.map(\.displayName).joined(separator: " · "))
                    }
                    SaveJobBar(jobName: $jobName, canSave: true) { save(r) }
                case .failure(let err):
                    ErrorText(message: err.message)
                }
                DisclaimerBanner()
            }
            .padding(20)
        }
        .navigationTitle("Resistor Color Code")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bandPicker(_ title: String, selection: Binding<ResistorBand>, options: [ResistorBand]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.muted)
            Picker(title, selection: selection) {
                ForEach(options) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.menu)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func save(_ r: ColorCodeResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .resistorColor,
            inputs: [
                "mode": mode.rawValue,
                "d1": d1.rawValue,
                "d2": d2.rawValue,
                "d3": d3.rawValue,
                "multiplier": multiplier.rawValue,
                "tolerance": tolerance.rawValue,
                "ohms": ohms,
                "encodeBands": "\(encodeBands)",
            ],
            outputs: [
                "R": "\(Format.number(r.ohms, digits: 4)) Ω",
                "tol": "± \(Format.number(r.tolerancePercent, digits: 2)) %",
                "bands": r.bands.map(\.displayName).joined(separator: " · "),
            ]
        ))
    }
}
