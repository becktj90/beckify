import SwiftUI
import BeckifyMath

struct SeriesParallelView: View {
    enum Part: String, CaseIterable, Identifiable {
        case resistors = "R"
        case capacitors = "C"
        var id: String { rawValue }
    }

    @EnvironmentObject private var jobs: JobStore
    @State private var part: Part = .resistors
    @State private var kind: NetworkKind = .series
    @State private var v1 = "10"
    @State private var v2 = "20"
    @State private var v3 = ""
    @State private var v4 = ""
    @State private var jobName = "Series / parallel"

    private var unit: String { part == .resistors ? "Ω" : "F" }

    var result: Result<Double, CalcError> {
        do {
            var values: [Double] = []
            for (i, raw) in [v1, v2, v3, v4].enumerated() {
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                guard let n = trimmed.parsedDouble else {
                    throw CalcError.outOfRange("Value \(i + 1) is not a number.")
                }
                values.append(n)
            }
            if part == .resistors {
                return .success(try SeriesParallel.resistors(values, kind: kind))
            }
            return .success(try SeriesParallel.capacitors(values, kind: kind))
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
                    text: part == .resistors
                        ? (kind == .series ? "Rs = R1 + R2 + …" : "1/Rp = 1/R1 + 1/R2 + …")
                        : (kind == .series ? "1/Cs = 1/C1 + 1/C2 + …" : "Cp = C1 + C2 + …"),
                    citation: "Ideal lumped parts. Leave extra fields blank. Not temperature-derated."
                )
                Picker("Part", selection: $part) {
                    ForEach(Part.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Network", selection: $kind) {
                    Text("Series").tag(NetworkKind.series)
                    Text("Parallel").tag(NetworkKind.parallel)
                }
                .pickerStyle(.segmented)
                NumberField(title: "Value 1", unit: unit, text: $v1, allowsScientific: true)
                NumberField(title: "Value 2", unit: unit, text: $v2, allowsScientific: true)
                NumberField(title: "Value 3", unit: unit, text: $v3, optional: true, allowsScientific: true)
                NumberField(title: "Value 4", unit: unit, text: $v4, optional: true, allowsScientific: true)
                switch result {
                case .success(let eq):
                    ResultCard {
                        ResultRow(label: "Equivalent", value: "\(Format.number(eq, digits: 4)) \(unit)", emphasis: true, tone: Theme.good)
                    }
                    SaveJobBar(jobName: $jobName, canSave: true) { save(eq) }
                case .failure(let err):
                    ErrorText(message: err.message)
                }
                DisclaimerBanner()
            }
            .padding(20)
        }
        .navigationTitle("Series / Parallel")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: part) { _, new in
            switch new {
            case .resistors:
                v1 = "10"
                v2 = "20"
            case .capacitors:
                v1 = "1e-6"
                v2 = "2.2e-6"
            }
            v3 = ""
            v4 = ""
        }
    }

    private func save(_ eq: Double) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .seriesParallel,
            inputs: ["part": part.rawValue, "kind": kind.rawValue, "1": v1, "2": v2, "3": v3, "4": v4],
            outputs: ["eq": "\(Format.number(eq, digits: 4)) \(unit)"]
        ))
    }
}
