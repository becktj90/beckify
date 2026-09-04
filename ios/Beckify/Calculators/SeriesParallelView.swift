import SwiftUI
import BeckifyMath

struct SeriesParallelView: View {
    enum Part: String, CaseIterable, Identifiable {
        case resistors = "R"
        case capacitors = "C"
        var id: String { rawValue }

        var unit: String { self == .resistors ? "Ω" : "F" }
    }

    private struct NetworkResult: Equatable {
        var equivalent: Double
        var part: Part
        var kind: NetworkKind
        var filledValues: [String]

        var unit: String { part.unit }
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.seriesParallel, "part", default: Part.resistors) private var part
    @StoredChoice(.seriesParallel, "kind", default: NetworkKind.series) private var kind
    @StoredInput(.seriesParallel, "v1", default: "10") private var v1
    @StoredInput(.seriesParallel, "v2", default: "20") private var v2
    @StoredInput(.seriesParallel, "v3", default: "") private var v3
    @StoredInput(.seriesParallel, "v4", default: "") private var v4
    @StoredInput(.seriesParallel, "jobName", default: "Series / parallel") private var jobName
    @State private var session = ExplicitCalculationState<NetworkResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var unit: String { part.unit }

    private var inputFingerprint: String { "\(part)|\(kind)|\(v1)|\(v2)|\(v3)|\(v4)" }

    var body: some View {
        ToolScaffold(
            toolID: .seriesParallel,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .seriesParallel,
                symbolic: symbolic,
                substituted: substituted,
                meaning: "Ideal lumped parts. Leave extra fields blank. Not temperature-derated."
            )
            Picker("Part", selection: $part) {
                ForEach(Part.allCases) { Text($0.rawValue).tag($0) }
            }
            .segmentedControlStyle()
            Picker("Network", selection: $kind) {
                Text("Series").tag(NetworkKind.series)
                Text("Parallel").tag(NetworkKind.parallel)
            }
            .segmentedControlStyle()
            NumberField(title: "Value 1", unit: unit, text: $v1, allowsScientific: true, fieldID: "v1", onSubmit: calculate)
            NumberField(title: "Value 2", unit: unit, text: $v2, allowsScientific: true, fieldID: "v2", onSubmit: calculate)
            NumberField(title: "Value 3", unit: unit, text: $v3, optional: true, allowsScientific: true, onSubmit: calculate)
            NumberField(title: "Value 4", unit: unit, text: $v4, optional: true, allowsScientific: true, onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    applyExample()
                    session.prepareForNewInputs()
                },
                exampleTitle: part == .resistors ? "10 Ω + 20 Ω series" : "1 µF ∥ 2.2 µF"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let eq = session.displayedResult {
                ResultCard(copyText: copyText) {
                    ResultRow(
                        label: "Equivalent",
                        value: "\(Format.number(eq.equivalent, digits: 4)) \(eq.unit)",
                        emphasis: true,
                        tone: Theme.good
                    )
                }
                .opacity(session.isStale ? 0.72 : 1)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) { save(eq) }
            }
        }
        .onChange(of: part) { _, new in
            applyDefaults(for: new)
            session.markInputsChanged()
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private var symbolic: String {
        if part == .resistors {
            return kind == .series ? "Rs = R1 + R2 + …" : "1/Rp = 1/R1 + 1/R2 + …"
        }
        return kind == .series ? "1/Cs = 1/C1 + 1/C2 + …" : "Cp = C1 + C2 + …"
    }

    private func calculate() {
        session.calculate {
            var values: [Double] = []
            var filled: [String] = []
            for (i, raw) in [v1, v2, v3, v4].enumerated() {
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                guard let n = trimmed.parsedDouble else {
                    throw CalcError.outOfRange("Value \(i + 1) is not a number. Use digits, a decimal, or scientific notation like 1e-6.")
                }
                values.append(n)
                filled.append(trimmed)
            }
            let equivalent: Double
            if part == .resistors {
                equivalent = try SeriesParallel.resistors(values, kind: kind)
            } else {
                equivalent = try SeriesParallel.capacitors(values, kind: kind)
            }
            return NetworkResult(equivalent: equivalent, part: part, kind: kind, filledValues: filled)
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        v1 = ""
        v2 = ""
        v3 = ""
        v4 = ""
        session.reset()
    }

    private var substituted: String? {
        guard let eq = session.displayedResult else { return nil }
        let joiner = eq.kind == .series ? " + " : " ∥ "
        return "\(eq.filledValues.joined(separator: joiner))  →  \(Format.number(eq.equivalent, digits: 4)) \(eq.unit)"
    }

    private var sticky: String? {
        guard let eq = session.displayedResult else { return nil }
        return "\(Format.number(eq.equivalent, digits: 4)) \(eq.unit)"
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

    private func save(_ eq: NetworkResult) {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .seriesParallel,
            inputs: [
                "part": eq.part.rawValue,
                "kind": eq.kind.rawValue,
                "1": v1,
                "2": v2,
                "3": v3,
                "4": v4,
            ],
            outputs: ["eq": "\(Format.number(eq.equivalent, digits: 4)) \(eq.unit)"]
        ))
    }
}
