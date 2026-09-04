import SwiftUI
import BeckifyMath

struct WireAmpacityView: View {
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

    private enum Mode: String, CaseIterable, Identifiable {
        case select = "Select size"
        case evaluate = "Evaluate size"
        var id: String { rawValue }
    }

    @EnvironmentObject private var jobs: JobStore
    @Environment(\.openRelatedTool) private var openRelated
    @StoredChoice(.wireAmpacity, "mode", default: Mode.select) private var mode
    @StoredInput(.wireAmpacity, "amps", default: "95") private var amps
    @StoredChoice(.wireAmpacity, "material", default: ConductorMaterial.copper) private var material
    @StoredChoice(.wireAmpacity, "insulation", default: TempChoice.c90) private var insulation
    @StoredChoice(.wireAmpacity, "termination", default: TempChoice.c75) private var termination
    @StoredInput(.wireAmpacity, "ambient", default: "30") private var ambient
    @StoredInput(.wireAmpacity, "ccc", default: "3") private var ccc
    @StoredInput(.wireAmpacity, "runs", default: "1") private var runs
    @StoredToggle(.wireAmpacity, "continuous", default: false) private var continuous
    @StoredInput(.wireAmpacity, "size", default: "3") private var size
    @StoredInput(.wireAmpacity, "ocpd", default: "") private var ocpd
    @StoredInput(.wireAmpacity, "jobName", default: "Wire ampacity") private var jobName
    @State private var session = ExplicitCalculationState<ConductorSelectionResult>()
    @State private var evaluateSession = ExplicitCalculationState<AmpacityDeratingResult>()
    @State private var importedBanner: String?
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sizes: [String] {
        NECTables.wireSizeOrder.filter {
            NECAmpacityFactors.ampacity(size: $0, material: material, column: .c75) != nil
        }
    }

    private var inputFingerprint: String {
        "\(mode)|\(amps)|\(material)|\(insulation)|\(termination)|\(ambient)|\(ccc)|\(runs)|\(continuous)|\(size)|\(ocpd)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .wireAmpacity,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: activeSessionIsStale
        ) {
            ShowWorkCard(
                toolID: .wireAmpacity,
                symbolic: "I_allow = min(I_base × F_amb × F_CCC, I_term) × runs",
                substituted: substituted,
                meaning: "Correction and adjustment use the insulation column (310.15). Usable ampacity is then capped by the termination column (110.14(C)). Continuous loads use 125% of the load current as the required ampacity.",
                citation: "NEC 2023 Table 310.16 · 310.15(B)(1) · 310.15(C)(1) · 110.14(C)."
            )

            if let importedBanner {
                Text(importedBanner)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.accent)
                    .accessibilityLabel(importedBanner)
            }

            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .segmentedControlStyle()

            Picker("Material", selection: $material) {
                ForEach(ConductorMaterial.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .segmentedControlStyle()

            NumberField(title: "Load current", unit: "A", text: $amps, fieldID: "amps", onSubmit: calculate)
            MenuField(title: "Insulation", selection: $insulation, options: TempChoice.allCases) { $0.label }
            MenuField(title: "Termination", selection: $termination, options: TempChoice.allCases) { $0.label }
            NumberField(title: "Ambient", unit: "°C", text: $ambient, fieldID: "ambient", onSubmit: calculate)
            NumberField(title: "Current-carrying conductors", unit: "CCC", text: $ccc, fieldID: "ccc", onSubmit: calculate)
            NumberField(title: "Parallel runs per phase", unit: "runs", text: $runs, fieldID: "runs", onSubmit: calculate)
            Toggle("Continuous load (125%)", isOn: $continuous)
            if mode == .evaluate {
                MenuField(title: "Conductor size", selection: $size, options: sizes, label: NECTables.wireLabel)
                NumberField(title: "OCPD rating", unit: "A", text: $ocpd, optional: true, fieldID: "ocpd", onSubmit: calculate)
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: applyExample,
                exampleTitle: "95 A Cu, 90/75 °C, 30 °C, 3 CCC"
            )

            if let error = activeError {
                ErrorText(message: error.message)
            }

            if mode == .select, let r = session.displayedResult {
                selectionResults(r)
            }
            if mode == .evaluate, let r = evaluateSession.displayedResult {
                evaluateResults(r)
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
            evaluateSession.markInputsChanged()
        }
        .onAppear(perform: applyIncomingHandoff)
        .sensoryFeedback(.success, trigger: successTick)
    }

    private var activeSessionIsStale: Bool {
        mode == .select ? session.isStale : evaluateSession.isStale
    }

    private var activeError: CalcError? {
        if mode == .select {
            return session.lastValidationError ?? session.error
        }
        return evaluateSession.lastValidationError ?? evaluateSession.error
    }

    @ViewBuilder
    private func selectionResults(_ r: ConductorSelectionResult) -> some View {
        AmpacityWaterfallDiagram(steps: r.selected.trace)
            .opacity(session.isStale ? 0.72 : 1)

        ResultCard(copyText: copyText) {
            ResultRow(label: "Required ampacity", value: Format.amps(r.requiredAmpacity), emphasis: true)
            ResultRow(label: "Selected size", value: r.selected.label, emphasis: true, tone: Theme.good)
            ResultRow(label: "Usable ampacity", value: Format.amps(r.selected.usableTotal), tone: Theme.good)
            ResultRow(label: "Base table", value: Format.amps(r.selected.baseAmpacity))
            ResultRow(label: "After ambient × CCC", value: Format.amps(r.selected.correctedAmpacity))
            ResultRow(label: "Termination cap", value: Format.amps(r.selected.terminationCap))
            if let next = r.nextLarger {
                ResultRow(label: "Next larger", value: "\(next.label) · \(Format.amps(next.usableTotal))")
            }
            if let ocpd = r.selected.recommendedOCPD {
                ResultRow(label: "Next standard OCPD", value: "\(ocpd) A", tone: Theme.muted)
            }
        }
        .opacity(session.isStale ? 0.72 : 1)

        warningList(r.selected.warnings)
        citationList(r.selected.citations)

        if !session.isStale {
            Button {
                ConductorHandoff.save(r.selected.seedForVoltageDrop)
                openRelated(.voltageDrop)
            } label: {
                Label("Continue with Voltage Drop", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.copper)
            .accessibilityHint("Opens Voltage Drop with this conductor size, material, and load current.")

            SaveJobBar(jobName: $jobName, canSave: true) {
                jobs.save(SavedJob(
                    name: jobName,
                    toolID: .wireAmpacity,
                    inputs: [
                        "I": amps,
                        "mat": material.displayName,
                        "insul": insulation.label,
                        "term": termination.label,
                        "amb": ambient,
                        "ccc": ccc,
                        "runs": runs,
                        "cont": continuous ? "yes" : "no",
                    ],
                    outputs: [
                        "size": r.selected.label,
                        "usable": Format.amps(r.selected.usableTotal),
                        "required": Format.amps(r.requiredAmpacity),
                    ]
                ))
            }
        }
    }

    @ViewBuilder
    private func evaluateResults(_ r: AmpacityDeratingResult) -> some View {
        AmpacityWaterfallDiagram(steps: r.trace)
            .opacity(evaluateSession.isStale ? 0.72 : 1)

        ResultCard(copyText: copyText) {
            ResultRow(label: "Usable ampacity", value: Format.amps(r.usableTotal), emphasis: true, tone: r.passesLoad == false ? Theme.bad : Theme.good)
            if let required = r.requiredAmpacity {
                ResultRow(label: "Required", value: Format.amps(required))
            }
            if let margin = r.marginAmps {
                ResultRow(label: "Margin", value: Format.amps(margin), tone: margin >= 0 ? Theme.good : Theme.bad)
            }
            ResultRow(label: "Governed by", value: r.limitedByTermination ? "Termination rating" : "Derating factors")
            if let next = r.nextLargerSize {
                ResultRow(label: "Next larger", value: NECTables.wireLabel(next))
            }
        }
        .opacity(evaluateSession.isStale ? 0.72 : 1)

        warningList(r.warnings)
        citationList(r.citations)

        if !evaluateSession.isStale {
            Button {
                ConductorHandoff.save(r.seedForVoltageDrop)
                openRelated(.voltageDrop)
            } label: {
                Label("Continue with Voltage Drop", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.copper)

            SaveJobBar(jobName: $jobName, canSave: true) {
                jobs.save(SavedJob(
                    name: jobName,
                    toolID: .wireAmpacity,
                    inputs: ["size": r.label, "mat": material.displayName, "I": amps],
                    outputs: ["usable": Format.amps(r.usableTotal)]
                ))
            }
        }
    }

    @ViewBuilder
    private func warningList(_ warnings: [DesignWarning]) -> some View {
        if !warnings.isEmpty {
            ResultCard(title: "Warnings & limits") {
                ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(warning.provenance.displayName.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                        Text(warning.message)
                            .font(.caption)
                            .foregroundStyle(warning.severity == .critical ? Theme.bad : Theme.warn)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    @ViewBuilder
    private func citationList(_ citations: [CodeCitation]) -> some View {
        ResultCard(title: "Code references") {
            ForEach(Array(citations.enumerated()), id: \.offset) { _, cite in
                ResultRow(label: cite.articleOrTable, value: cite.edition.displayName, tone: Theme.muted)
            }
        }
    }

    private func calculate() {
        if mode == .select {
            session.calculate {
                try WireAmpacity.selectConductor(
                    loadAmps: amps.parsedDouble ?? .nan,
                    material: material,
                    insulation: insulation.column,
                    termination: termination.column,
                    ambientC: ambient.parsedDouble ?? .nan,
                    currentCarryingCount: Int(ccc.parsedDouble ?? 0),
                    parallelRuns: Int(runs.parsedDouble ?? 0),
                    continuousLoad: continuous
                )
            }
            if session.displayedResult != nil, !session.isStale, !reduceMotion { successTick += 1 }
        } else {
            evaluateSession.calculate {
                try WireAmpacity.evaluate(AmpacityDeratingInput(
                    size: size,
                    material: material,
                    insulation: insulation.column,
                    termination: termination.column,
                    ambientC: ambient.parsedDouble ?? .nan,
                    currentCarryingCount: Int(ccc.parsedDouble ?? 0),
                    parallelRuns: Int(runs.parsedDouble ?? 1),
                    continuousLoad: continuous,
                    loadAmps: amps.parsedDouble,
                    ocpdAmps: ocpd.trimmingCharacters(in: .whitespaces).isEmpty ? nil : ocpd.parsedDouble
                ))
            }
            if evaluateSession.displayedResult != nil, !evaluateSession.isStale, !reduceMotion { successTick += 1 }
        }
    }

    private func reset() {
        amps = ""
        ambient = "30"
        ccc = "3"
        runs = "1"
        continuous = false
        ocpd = ""
        session.reset()
        evaluateSession.reset()
        importedBanner = nil
    }

    private func applyExample() {
        mode = .select
        amps = "95"
        material = .copper
        insulation = .c90
        termination = .c75
        ambient = "30"
        ccc = "3"
        runs = "1"
        continuous = false
        session.prepareForNewInputs()
        evaluateSession.prepareForNewInputs()
    }

    private func applyIncomingHandoff() {
        guard let seed = ConductorHandoff.consume() else { return }
        amps = Format.number(seed.loadAmps, digits: 2)
        material = seed.material
        size = seed.size
        if let insul = seed.insulationCelsius, let choice = TempChoice(rawValue: "\(insul)") {
            insulation = choice
        }
        if let term = seed.terminationCelsius, let choice = TempChoice(rawValue: "\(term)") {
            termination = choice
        }
        runs = "\(seed.parallelRuns)"
        importedBanner = "Imported from \(seed.sourceSummary). Edit freely, then Calculate."
        session.prepareForNewInputs()
        evaluateSession.prepareForNewInputs()
    }

    private var substituted: String? {
        if mode == .select, let r = session.displayedResult {
            return "Required \(Format.amps(r.requiredAmpacity)) → \(r.selected.label) usable \(Format.amps(r.selected.usableTotal))"
        }
        if mode == .evaluate, let r = evaluateSession.displayedResult {
            return "\(r.label) usable \(Format.amps(r.usableTotal)) after ambient × CCC and termination cap"
        }
        return nil
    }

    private var sticky: String? {
        if mode == .select, let r = session.displayedResult {
            return "\(r.selected.label)  ·  \(Format.amps(r.selected.usableTotal))"
        }
        if mode == .evaluate, let r = evaluateSession.displayedResult {
            return "\(r.label)  ·  \(Format.amps(r.usableTotal))"
        }
        return nil
    }

    private var copyText: String? { sticky }
}
