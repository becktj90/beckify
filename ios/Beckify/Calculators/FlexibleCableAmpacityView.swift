import Charts
import SwiftUI
import BeckifyMath

/// Jobsite ampacity for Type W and SO/SJO portable cord.
/// Building-wire ampacity stays on Wire Size & Ampacity (Table 310.16).
struct FlexibleCableAmpacityView: View {
    private enum TempChoice: String, CaseIterable, Identifiable {
        case c60 = "60"
        case c75 = "75"
        case c90 = "90"
        var id: String { rawValue }
        var column: ConductorTempColumn {
            switch self {
            case .c60: return .c60
            case .c75: return .c75
            case .c90: return .c90
            }
        }
        var label: String { "\(rawValue) °C" }
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.flexibleCable, "family", default: FlexibleCableFamily.so) private var family
    @StoredInput(.flexibleCable, "size", default: "12") private var size
    @StoredInput(.flexibleCable, "cmil", default: "") private var cmil
    @StoredInput(.flexibleCable, "conductors", default: "3") private var conductors
    @StoredChoice(.flexibleCable, "material", default: ConductorMaterial.copper) private var material
    @StoredChoice(.flexibleCable, "insulation", default: TempChoice.c90) private var insulation
    @StoredInput(.flexibleCable, "ambient", default: "30") private var ambient
    @StoredInput(.flexibleCable, "ccc", default: "2") private var ccc
    @StoredToggle(.flexibleCable, "continuous", default: false) private var continuous
    @StoredInput(.flexibleCable, "load", default: "") private var load
    @StoredInput(.flexibleCable, "jobName", default: "Flexible cable") private var jobName
    @State private var session = ExplicitCalculationState<FlexibleCableAmpacityResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var cccCount: Int {
        Int(ccc.parsedDouble ?? 0)
    }

    private var availableSizes: [String] {
        FlexibleCableAmpacity.sizes(for: family, currentCarryingCount: cccCount)
    }

    private var inputFingerprint: String {
        "\(family.rawValue)|\(size)|\(cmil)|\(conductors)|\(material.rawValue)|\(insulation.rawValue)|\(ambient)|\(ccc)|\(continuous)|\(load)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .flexibleCable,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .flexibleCable,
                symbolic: "Allowable = table × ambient × 400.5(A)(3)",
                substituted: substituted,
                meaning: "Portable cord uses Table 400.5(A)(1). Type W uses the transcribed 90°C column of Table 400.5(A)(2). A target load at or under 400 A picks the smallest listed size.",
                citation: "NEC Table 400.5(A)(1), Table 400.5(A)(2), and Table 400.5(A)(3). Ambient correction is Table 310.15(B)(1). Not Table 310.16."
            )

            MenuField(title: "Cable family", selection: $family, options: FlexibleCableFamily.allCases) { $0.displayName }
            Text(family.voltageNote + " Types: " + family.listedTypes + ".")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            if availableSizes.isEmpty {
                Text("Table 400.5(A)(1) has no single-conductor column. Set current-carrying conductors to at least 2, or switch to Type W.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                MenuField(title: "Size", selection: $size, options: availableSizes) { sizeLabel($0) }
            }
            NumberField(title: "Or circular mils", unit: "cmil", text: $cmil, optional: true, fieldID: "cmil", onSubmit: calculate)
            Text("Exact Chapter 9 Table 8 match only. A near miss is not rounded to a neighbor.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            NumberField(title: "Conductor count", unit: "", text: $conductors, fieldID: "conductors", onSubmit: calculate)
            NumberField(title: "Current-carrying conductors", unit: "", text: $ccc, fieldID: "ccc", onSubmit: calculate)
            Text("Do not count the equipment grounding conductor. More than three uses Table 400.5(A)(3).")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            MenuField(title: "Conductor metal", selection: $material, options: ConductorMaterial.allCases) { $0.displayName }
            MenuField(title: "Insulation temperature", selection: $insulation, options: TempChoice.allCases) { $0.label }
            Text(family == .typeW
                 ? "Type W lookup here is the 90°C column only. 60°C and 75°C are not transcribed."
                 : "On portable cord this picks the ambient-correction column. It does not change the Table 400.5(A)(1) base value.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            NumberField(title: "Ambient", unit: "°C", text: $ambient, fieldID: "ambient", onSubmit: calculate)
            NumberField(title: "Target load", unit: "A", text: $load, optional: true, fieldID: "load", onSubmit: calculate)
            Toggle("Continuous load (125%)", isOn: $continuous)
                .font(.subheadline)
            Text("Selection stops at 400 A after the 125% check. Cord protection under 240.5 is not calculated.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: applyExample,
                exampleTitle: "Type W, 400 A, 3 CCC"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let result = session.displayedResult {
                ResultCard(title: "Allowable ampacity", copyText: copyText) {
                    ResultRow(label: "Cable", value: "\(result.family.displayName)", emphasis: false)
                    ResultRow(label: "Size", value: result.label, emphasis: true)
                    ResultRow(label: "Column", value: result.columnLabel)
                    ResultRow(label: "Table ampacity", value: Format.amps(result.baseAmpacity))
                    ResultRow(label: "Ambient factor", value: Format.number(result.ambientFactor, digits: 2))
                    ResultRow(label: "400.5(A)(3) factor", value: Format.number(result.bundleFactor, digits: 2))
                    ResultRow(label: "Allowable", value: Format.amps(result.allowableAmpacity), emphasis: true, tone: Theme.good)
                    if let required = result.requiredAmpacity {
                        ResultRow(label: "Required", value: Format.amps(required))
                        ResultRow(
                            label: "This size",
                            value: result.passesLoad == true ? "Meets the load" : "Below the load",
                            tone: result.passesLoad == true ? Theme.good : Theme.warn
                        )
                    }
                    if let pick = result.recommendation {
                        ResultRow(label: "Smallest size", value: "\(pick.label) · \(Format.amps(pick.allowableAmpacity))", emphasis: true)
                    }
                }
                .opacity(session.isStale ? 0.72 : 1)

                Text(result.tableName + ". " + result.source)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                FlexibleCableAmpacityChart(points: result.chart, column: result.columnLabel)
                    .opacity(session.isStale ? 0.72 : 1)

                FlexibleCableSizeTable(points: result.chart, column: result.columnLabel) { picked in
                    size = picked
                    cmil = ""
                }

                if !result.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(result.warnings, id: \.self) { warning in
                            Text(warning)
                                .font(Theme.TypeRole.help)
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .flexibleCable,
                        inputs: [
                            "family": family.rawValue,
                            "size": result.size,
                            "conductors": conductors,
                            "ccc": ccc,
                            "mat": material.rawValue,
                            "insulation": insulation.rawValue,
                            "ambient": ambient,
                            "load": load,
                        ],
                        outputs: [
                            "allowable": Format.amps(result.allowableAmpacity),
                            "table": result.tableName,
                            "recommend": result.recommendation?.label ?? "",
                        ]
                    ))
                }
            }

            installNotes
        }
        .onAppear { snapSize() }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
            snapSize()
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private var installNotes: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INSTALL NOTES")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
            ForEach(FlexibleCableAmpacity.installNotes(for: family)) { note in
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                    Text(note.body)
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("flexibleCableInstallNotes")
    }

    private func calculate() {
        let cmilText = cmil.trimmingCharacters(in: .whitespacesAndNewlines)
        let loadText = load.trimmingCharacters(in: .whitespacesAndNewlines)
        session.calculate {
            let conductorsCount = try WholeCount.parse(conductors.parsedDouble ?? .nan, name: "Conductor count")
            let carrying = try WholeCount.parse(ccc.parsedDouble ?? .nan, name: "Current-carrying conductor count")
            let ambientC = try Positive.require(ambient.parsedDouble ?? .nan, name: "Ambient temperature")
            let circular = cmilText.isEmpty ? nil : cmil.parsedDouble
            if !cmilText.isEmpty, circular == nil {
                throw CalcError.missing("circular mils as a number")
            }
            let target: Double?
            if loadText.isEmpty {
                target = nil
            } else {
                target = try Positive.require(load.parsedDouble ?? .nan, name: "Target load")
            }
            return try FlexibleCableAmpacity.evaluate(FlexibleCableAmpacityInput(
                family: family,
                size: size,
                circularMils: circular,
                conductorCount: conductorsCount,
                material: material,
                insulation: insulation.column,
                ambientC: ambientC,
                currentCarryingCount: carrying,
                continuousLoad: continuous,
                loadAmps: target
            ))
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        family = .so
        size = "12"
        cmil = ""
        conductors = "3"
        material = .copper
        insulation = .c90
        ambient = "30"
        ccc = "2"
        continuous = false
        load = ""
        session.reset()
    }

    private func applyExample() {
        family = .typeW
        size = "4/0"
        cmil = ""
        conductors = "4"
        material = .copper
        insulation = .c90
        ambient = "30"
        ccc = "3"
        continuous = false
        load = "400"
        session.prepareForNewInputs()
        snapSize()
    }

    private func snapSize() {
        let sizes = availableSizes
        guard !sizes.contains(size), let first = sizes.first else { return }
        size = first
    }

    private func sizeLabel(_ size: String) -> String {
        let kcmil: Set<String> = ["250", "300", "350", "400", "500"]
        return kcmil.contains(size) ? "\(size) kcmil" : "\(size) AWG"
    }

    private var substituted: String? {
        guard let result = session.displayedResult else { return nil }
        var line = "\(result.label) \(result.columnLabel) → \(Format.amps(result.allowableAmpacity))"
        if let pick = result.recommendation {
            line += " · smallest \(pick.label)"
        }
        return line
    }

    private var sticky: String? {
        guard let result = session.displayedResult else { return nil }
        if let pick = result.recommendation {
            return "\(pick.label) · \(Format.amps(pick.allowableAmpacity))"
        }
        return "\(result.label) · \(Format.amps(result.allowableAmpacity))"
    }

    private var copyText: String? {
        guard let result = session.displayedResult else { return nil }
        var line = "\(result.family.displayName) \(result.label): \(Format.amps(result.allowableAmpacity)) allowable (\(result.tableName), \(result.columnLabel))"
        if let pick = result.recommendation {
            line += ". Smallest for the load: \(pick.label)."
        }
        return line
    }
}

private struct FlexibleCableAmpacityChart: View {
    let points: [FlexibleCableChartPoint]
    let column: String

    private var summary: String {
        let highlighted = points.first { $0.isSelected }?.label ?? "none"
        return "Table ampacity versus size for \(column). Highlighted size \(highlighted). Bars are the cited column before ambient correction."
    }

    var body: some View {
        DiagramCard(title: "Ampacity vs size", accessibilitySummary: summary, exportName: "flexible-cable-ampacity") {
            Chart(points) { point in
                BarMark(
                    x: .value("Size", point.label),
                    y: .value("Amps", point.tableAmps)
                )
                .foregroundStyle(barColor(point))
            }
            .chartYAxisLabel("A")
            .frame(height: 180)
            .accessibilityHidden(true)
            Text("Bars are \(column) from the cited table, before ambient correction and Table 400.5(A)(3). The strong bar is the size you picked. A second color, when it appears, is the smallest size for the load.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func barColor(_ point: FlexibleCableChartPoint) -> Color {
        if point.isSelected { return Theme.accent }
        if point.isRecommended { return Theme.good }
        return Theme.chartGrid
    }
}

private struct FlexibleCableSizeTable: View {
    let points: [FlexibleCableChartPoint]
    let column: String
    var onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TABLE")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
            VStack(spacing: 0) {
                ForEach(points) { point in
                    Button {
                        onSelect(point.size)
                    } label: {
                        HStack {
                            Text(point.label)
                                .font(.subheadline.monospacedDigit().weight(point.isSelected ? .semibold : .regular))
                                .foregroundStyle(Theme.foreground)
                            Spacer(minLength: 8)
                            Text("\(Format.number(point.tableAmps, digits: 0)) A")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(point.isSelected ? Theme.accent : Theme.foreground)
                            if point.isRecommended {
                                Text("pick")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.good)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(point.isSelected ? Theme.accent.opacity(0.12) : Color.clear)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(point.label), \(Format.number(point.tableAmps, digits: 0)) amps, \(column)")
                    if point.id != points.last?.id {
                        Divider()
                    }
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
            if let source = points.first?.source {
                Text(source)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
