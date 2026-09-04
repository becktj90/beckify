import SwiftUI
import BeckifyMath

struct VoltageDropView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.voltageDrop, "system", default: ElectricalSystem.threePhase) private var system
    @StoredInput(.voltageDrop, "voltage", default: "480") private var voltage
    @StoredInput(.voltageDrop, "current", default: "45") private var current
    @StoredInput(.voltageDrop, "length", default: "250") private var length
    @StoredChoice(.voltageDrop, "material", default: ConductorMaterial.copper) private var material
    @StoredInput(.voltageDrop, "size", default: "4") private var size
    @StoredInput(.voltageDrop, "runs", default: "1") private var runs
    @StoredInput(.voltageDrop, "target", default: "3") private var target
    @StoredInput(.voltageDrop, "jobName", default: "Voltage drop") private var jobName
    @State private var session = ExplicitCalculationState<VoltageDropSizingResult>()
    @State private var importedBanner: String?
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sizes: [String] {
        NECTables.wireSizeOrder.filter { NECTables.circularMils[$0] != nil }
    }

    private var inputFingerprint: String {
        "\(system)|\(voltage)|\(current)|\(length)|\(material)|\(size)|\(runs)|\(target)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .voltageDrop,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .voltageDrop,
                symbolic: "VD ≈ (M × K × I × L) / (CM × runs)",
                substituted: substituted,
                meaning: "M is 2 for 1Ø/DC or √3 for 3Ø. K is 12.9 Cu / 21.2 Al at 75 °C. This is a K-factor approximation, not an exact AC impedance calculation. 3% and 5% are informational notes.",
                citation: "NEC Chapter 9 Table 9 K-factor · ampacity cross-check Table 310.16 75 °C · Informational Notes on 3%/5%.",
                referenceTool: .wireAmpacity
            )

            if let importedBanner {
                Text(importedBanner)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.accent)
            }

            Picker("System", selection: $system) {
                ForEach(ElectricalSystem.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Material", selection: $material) {
                ForEach(ConductorMaterial.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            NumberField(title: "Supply voltage", unit: "V", text: $voltage, fieldID: "voltage", onSubmit: calculate)
            NumberField(title: "Load current", unit: "A", text: $current, fieldID: "current", onSubmit: calculate)
            NumberField(title: "One-way length", unit: "ft", text: $length, fieldID: "length", onSubmit: calculate)
            MenuField(title: "Conductor", selection: $size, options: sizes, label: NECTables.wireLabel)
            NumberField(title: "Parallel runs per phase", unit: "runs", text: $runs, fieldID: "runs", onSubmit: calculate)
            NumberField(title: "Preferred drop target", unit: "%", text: $target, fieldID: "target", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    system = .threePhase
                    voltage = "480"
                    current = "45"
                    length = "250"
                    material = .copper
                    size = "4"
                    runs = "1"
                    target = "3"
                    session.prepareForNewInputs()
                },
                exampleTitle: "480 V 3Ø, 45 A, 250 ft, 4 Cu"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                if let diagram = VoltageDropDiagram.model(from: r.legacy) {
                    diagram.opacity(session.isStale ? 0.72 : 1)
                }

                ResultCard(copyText: copyText) {
                    ResultRow(label: "Method", value: r.method.displayName, tone: Theme.muted)
                    ResultRow(label: "Voltage drop", value: Format.volts(r.dropVolts), emphasis: true)
                    ResultRow(label: "Drop", value: Format.percent(r.dropPercent), emphasis: true)
                    ResultRow(label: "Receiving end", value: Format.volts(r.receivingVolts))
                    ResultRow(
                        label: "Preferred target \(Format.percent(r.targetDropPercent))",
                        value: r.meetsTarget ? "MEETS" : "OVER",
                        tone: r.meetsTarget ? Theme.good : Theme.warn
                    )
                    ResultRow(
                        label: "≤ 3% informational",
                        value: r.meets3Percent ? "PASS" : "OVER 3%",
                        tone: r.meets3Percent ? Theme.good : Theme.warn
                    )
                    ResultRow(
                        label: "≤ 5% informational",
                        value: r.meets5Percent ? "PASS" : "OVER 5%",
                        tone: r.meets5Percent ? Theme.good : Theme.bad
                    )
                    if let amp = r.ampacity75C {
                        ResultRow(
                            label: "310.16 75 °C × runs",
                            value: "\(amp) A" + (r.ampacityOK ? "  meets load" : "  undersized"),
                            tone: r.ampacityOK ? Theme.good : Theme.bad
                        )
                    }
                    if let ampMin = r.ampacityMinimumSize {
                        ResultRow(label: "Ampacity minimum", value: NECTables.wireLabel(ampMin))
                    }
                    if let vdMin = r.voltageDropMinimumSize {
                        ResultRow(label: "VD target minimum", value: NECTables.wireLabel(vdMin), tone: Theme.copper)
                    }
                    if let rec = r.recommendedLabel {
                        ResultRow(label: "Recommended final", value: rec, emphasis: true, tone: Theme.good)
                    }
                    if let loss = r.conductorLossWatts {
                        ResultRow(label: "Approx. conductor loss", value: Format.watts(loss), tone: Theme.muted)
                    }
                }
                .opacity(session.isStale ? 0.72 : 1)

                ResultCard(title: "Size comparison") {
                    ForEach(comparisonRows(from: r), id: \.size) { row in
                        HStack(alignment: .firstTextBaseline) {
                            Text(row.label)
                                .font(.caption.monospacedDigit().weight(row.highlight ? .bold : .regular))
                                .foregroundStyle(row.highlight ? Theme.good : Theme.foreground)
                                .frame(minWidth: 72, alignment: .leading)
                            Text(row.ampacityOK ? "amp OK" : "amp low")
                                .font(.caption2)
                                .foregroundStyle(row.ampacityOK ? Theme.good : Theme.bad)
                            Spacer(minLength: 6)
                            Text(Format.percent(row.dropPercent))
                                .font(.caption.monospacedDigit())
                            Text(Format.volts(row.receivingVolts))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(Theme.muted)
                                .frame(minWidth: 54, alignment: .trailing)
                        }
                        .padding(.vertical, 2)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(row.label), \(row.ampacityOK ? "ampacity OK" : "ampacity low"), drop \(Format.percent(row.dropPercent)), receiving \(Format.volts(row.receivingVolts))")
                    }
                }
                .opacity(session.isStale ? 0.72 : 1)

                if !r.warnings.isEmpty {
                    ResultCard(title: "Assumptions & limits") {
                        ForEach(Array(r.warnings.enumerated()), id: \.offset) { _, warning in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(warning.provenance.displayName.uppercased())
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.muted)
                                Text(warning.message)
                                    .font(.caption)
                                    .foregroundStyle(warning.severity == .critical ? Theme.bad : Theme.warn)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }

                ResultCard(title: "Code references") {
                    ForEach(Array(r.citations.enumerated()), id: \.offset) { _, cite in
                        ResultRow(label: cite.articleOrTable, value: cite.edition.displayName, tone: Theme.muted)
                    }
                }

                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .voltageDrop,
                        inputs: [
                            "sys": system.displayName,
                            "V": voltage,
                            "I": current,
                            "L": length,
                            "size": size,
                            "material": material.displayName,
                            "runs": runs,
                            "target": target,
                        ],
                        outputs: [
                            "VD": Format.volts(r.dropVolts),
                            "%": Format.percent(r.dropPercent),
                            "rec": r.recommendedLabel ?? r.label,
                        ]
                    ))
                }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .onAppear(perform: applyIncomingHandoff)
        .sensoryFeedback(.success, trigger: successTick)
    }

    private struct ComparisonRow {
        var size: String
        var label: String
        var dropPercent: Double
        var receivingVolts: Double
        var ampacityOK: Bool
        var highlight: Bool
    }

    private func comparisonRows(from r: VoltageDropSizingResult) -> [ComparisonRow] {
        let focus = Set([r.size, r.ampacityMinimumSize, r.voltageDropMinimumSize, r.recommendedSize].compactMap { $0 })
        return r.candidates
            .filter { focus.contains($0.size) || $0.meetsAllConstraints || $0.size == r.size }
            .prefix(8)
            .map {
                ComparisonRow(
                    size: $0.size,
                    label: $0.label,
                    dropPercent: $0.dropPercent,
                    receivingVolts: $0.receivingVolts,
                    ampacityOK: $0.ampacityOK,
                    highlight: $0.size == (r.recommendedSize ?? r.size)
                )
            }
    }

    private func calculate() {
        session.calculate {
            try VoltageDropSizing.calculate(
                VoltageDropSizingInput(
                    system: system,
                    supplyVolts: voltage.parsedDouble ?? .nan,
                    current: current.parsedDouble ?? .nan,
                    oneWayFeet: length.parsedDouble ?? .nan,
                    size: size,
                    material: material,
                    parallelRuns: Int(runs.parsedDouble ?? 0),
                    targetDropPercent: target.parsedDouble ?? .nan
                )
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        voltage = ""
        current = ""
        length = ""
        size = "4"
        runs = "1"
        target = "3"
        importedBanner = nil
        session.reset()
    }

    private func applyIncomingHandoff() {
        guard let seed = ConductorHandoff.consume() else { return }
        current = Format.number(seed.loadAmps, digits: 2)
        material = seed.material
        size = seed.size
        runs = "\(max(1, seed.parallelRuns))"
        if let system = seed.system { self.system = system }
        if let volts = seed.supplyVolts { voltage = Format.number(volts, digits: 1) }
        if let feet = seed.oneWayFeet { length = Format.number(feet, digits: 1) }
        importedBanner = "Imported from \(seed.sourceSummary). Edit freely, then Calculate."
        session.prepareForNewInputs()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.formula)  →  \(Format.volts(r.dropVolts))  (\(Format.percent(r.dropPercent)))"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        let rec = r.recommendedLabel.map { "  ·  rec \($0)" } ?? ""
        return "\(Format.volts(r.dropVolts))  ·  \(Format.percent(r.dropPercent))\(rec)"
    }

    private var copyText: String? { sticky }
}
