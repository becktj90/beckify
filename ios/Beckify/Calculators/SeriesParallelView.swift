import SwiftUI
import BeckifyMath

struct SeriesParallelView: View {
    enum Part: String, CaseIterable, Identifiable {
        case resistors = "R"
        case capacitors = "C"
        var id: String { rawValue }
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.seriesParallel, "part", default: .resistors) private var part
    @StoredChoice(.seriesParallel, "kind", default: NetworkKind.series) private var kind
    @StoredInput(.seriesParallel, "v1", default: "10") private var v1
    @StoredInput(.seriesParallel, "v2", default: "20") private var v2
    @StoredInput(.seriesParallel, "v3", default: "") private var v3
    @StoredInput(.seriesParallel, "v4", default: "") private var v4
    @StoredInput(.seriesParallel, "jobName", default: "Series / parallel") private var jobName

    private var unit: String { part == .resistors ? "Ω" : "F" }

    var result: Result<Double, CalcError> {
        CalcCatch.run {
            var values: [Double] = []
            for (i, raw) in [v1, v2, v3, v4].enumerated() {
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                guard let n = trimmed.parsedDouble else {
                    throw CalcError.outOfRange("Value \(i + 1) is not a number. Use digits, a decimal, or scientific notation like 1e-6.")
                }
                values.append(n)
            }
            if part == .resistors {
                return try SeriesParallel.resistors(values, kind: kind)
            }
            return try SeriesParallel.capacitors(values, kind: kind)
        }
    }

    var body: some View {
        ToolScaffold(toolID: .seriesParallel, stickyAnswer: sticky, copyText: copyText) {
            ShowWorkCard(
                toolID: .seriesParallel,
                symbolic: symbolic,
                substituted: substituted,
                meaning: "Ideal lumped parts. Leave extra fields blank. Not temperature-derated."
            )
            TryExampleButton(title: part == .resistors ? "10 Ω + 20 Ω series" : "1 µF ∥ 2.2 µF") {
                applyExample()
            }
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
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Equivalent", value: "\(Format.number(eq, digits: 4)) \(unit)", emphasis: true, tone: Theme.good)
                }
                SaveJobBar(jobName: $jobName, canSave: true) { save(eq) }
            case .failure(let err):
                ErrorText(message: err.message)
            }
        }
        .onChange(of: part) { _, new in
            applyDefaults(for: new)
        }
    }

    private var symbolic: String {
        if part == .resistors {
            return kind == .series ? "Rs = R1 + R2 + …" : "1/Rp = 1/R1 + 1/R2 + …"
        }
        return kind == .series ? "1/Cs = 1/C1 + 1/C2 + …" : "Cp = C1 + C2 + …"
    }

    private var substituted: String? {
        guard case .success(let eq) = result else { return nil }
        let filled = [v1, v2, v3, v4].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return "\(filled.joined(separator: kind == .series ? " + " : " ∥ "))  →  \(Format.number(eq, digits: 4)) \(unit)"
    }

    private var sticky: String? {
        guard case .success(let eq) = result else { return nil }
        return "\(Format.number(eq, digits: 4)) \(unit)"
    }

    private var copyText: String? { sticky }

    private func applyExample() {
        applyDefaults(for: part)
        if part == .resistors {
            kind = .series
        } else {
            kind = .parallel
        }
    }

    private func applyDefaults(for part: Part) {
        switch part {
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

    private func save(_ eq: Double) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .seriesParallel,
            inputs: ["part": part.rawValue, "kind": kind.rawValue, "1": v1, "2": v2, "3": v3, "4": v4],
            outputs: ["eq": "\(Format.number(eq, digits: 4)) \(unit)"]
        ))
    }
}
