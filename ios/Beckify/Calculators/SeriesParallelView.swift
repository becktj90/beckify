import SwiftUI
import BeckifyMath

struct SeriesParallelView: View {
    enum Part: String, CaseIterable, Identifiable {
        case resistors = "R"
        case capacitors = "C"
        var id: String { rawValue }

        var unit: String { self == .resistors ? "Ω" : "F" }
    }

    private struct NetworkResult: Equatable, Sendable {
        var value: Double
        var unit: String
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.seriesParallel, "part", default: Part.resistors) private var part
    @StoredChoice(.seriesParallel, "kind", default: NetworkKind.series) private var kind
    @StoredInput(.seriesParallel, "v1", default: "10") private var v1
    @StoredInput(.seriesParallel, "v2", default: "20") private var v2
    @StoredInput(.seriesParallel, "v3", default: "") private var v3
    @StoredInput(.seriesParallel, "v4", default: "") private var v4
    @StoredInput(.seriesParallel, "jobName", default: "Series / parallel") private var jobName
    @State private var session = ExplicitCalculationSession<NetworkResult>()
    @State private var successTick = 0

    private var unit: String { part.unit }

    private var fingerprint: String { "\(part.rawValue)|\(kind.rawValue)|\(v1)|\(v2)|\(v3)|\(v4)" }
    private var display: ExplicitCalculationSession<NetworkResult>.Display {
        session.display(for: fingerprint)
    }

    var body: some View {
        ToolScaffold(
            toolID: .seriesParallel,
            stickyAnswer: sticky,
            copyText: copyText,
            dock: {
                CalculateActionBar(
                    isStale: isStale,
                    errorMessage: session.visibleError(for: fingerprint),
                    successTick: successTick,
                    onCalculate: calculate,
                    onReset: reset
                )
            }
        ) {
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
            switch display {
            case .current(let eq), .stale(let eq):
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Equivalent", value: "\(Format.number(eq.value, digits: 4)) \(eq.unit)", emphasis: true, tone: Theme.good)
                }
                if case .current = display {
                    SaveJobBar(jobName: $jobName, canSave: true) { save(eq) }
                }
            case .idle:
                ToolEmptyState(
                    title: "Enter component values",
                    detail: "Fill at least two values, then Calculate.",
                    systemImage: "point.3.connected.trianglepath.dotted"
                )
            case .failed:
                EmptyView()
            }
        }
        .onChange(of: part) { _, new in
            applyDefaults(for: new)
        }
    }

    private var isStale: Bool {
        if case .stale = display { return true }
        return false
    }

    private func calculate() {
        session.calculate(fingerprint: fingerprint) {
            var values: [Double] = []
            for (i, raw) in [v1, v2, v3, v4].enumerated() {
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                guard let n = trimmed.parsedDouble else {
                    throw CalcError.outOfRange("Value \(i + 1) is not a number. Use digits, a decimal, or scientific notation like 1e-6.")
                }
                values.append(n)
            }
            let equivalent: Double
            if part == .resistors {
                equivalent = try SeriesParallel.resistors(values, kind: kind)
            } else {
                equivalent = try SeriesParallel.capacitors(values, kind: kind)
            }
            return NetworkResult(value: equivalent, unit: part.unit)
        }
        if case .current = session.display(for: fingerprint) {
            successTick += 1
        }
    }

    private func reset() {
        session.reset()
        part = .resistors
        kind = .series
        applyDefaults(for: .resistors)
    }

    private var symbolic: String {
        if part == .resistors {
            return kind == .series ? "Rs = R1 + R2 + …" : "1/Rp = 1/R1 + 1/R2 + …"
        }
        return kind == .series ? "1/Cs = 1/C1 + 1/C2 + …" : "Cp = C1 + C2 + …"
    }

    private var substituted: String? {
        guard case .current(let eq) = display else { return nil }
        let filled = [v1, v2, v3, v4].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return "\(filled.joined(separator: kind == .series ? " + " : " ∥ "))  →  \(Format.number(eq.value, digits: 4)) \(eq.unit)"
    }

    private var sticky: String? {
        switch display {
        case .current(let eq), .stale(let eq):
            return "\(Format.number(eq.value, digits: 4)) \(eq.unit)"
        default:
            return nil
        }
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
            inputs: ["part": part.rawValue, "kind": kind.rawValue, "1": v1, "2": v2, "3": v3, "4": v4],
            outputs: ["eq": "\(Format.number(eq.value, digits: 4)) \(eq.unit)"]
        ))
    }
}
