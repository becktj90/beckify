import SwiftUI
import BeckifyMath

struct ConductorCostView: View {
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
    @Environment(\.openRelatedTool) private var openRelated
    @StoredChoice(.conductorCost, "system", default: ElectricalSystem.threePhase) private var system
    @StoredInput(.conductorCost, "voltage", default: "480") private var voltage
    @StoredInput(.conductorCost, "load", default: "150") private var load
    @StoredChoice(.conductorCost, "loadUnit", default: ConductorLoadUnit.amps) private var loadUnit
    @StoredInput(.conductorCost, "pf", default: "0.9") private var powerFactor
    @StoredChoice(.conductorCost, "material", default: ConductorMaterial.copper) private var material
    @StoredChoice(.conductorCost, "construction", default: LVConstruction.fourPlusE) private var construction
    @StoredChoice(.conductorCost, "insulation", default: TempChoice.c90) private var insulation
    @StoredChoice(.conductorCost, "termination", default: TempChoice.c75) private var termination
    @StoredInput(.conductorCost, "ambient", default: "30") private var ambient
    @StoredInput(.conductorCost, "ccc", default: "3") private var ccc
    @StoredToggle(.conductorCost, "continuous", default: true) private var continuous
    @StoredInput(.conductorCost, "length", default: "250") private var length
    @StoredInput(.conductorCost, "target", default: "3") private var target
    @StoredInput(.conductorCost, "maxRuns", default: "4") private var maxRuns
    @StoredInput(.conductorCost, "kft", default: "") private var dollarsPerKft
    @StoredInput(.conductorCost, "kwh", default: "") private var dollarsPerKwh
    @StoredInput(.conductorCost, "hours", default: "") private var hours
    @StoredInput(.conductorCost, "jobName", default: "Conductor cost") private var jobName
    @State private var session = ExplicitCalculationState<ConductorCostResult>()
    @State private var importedBanner: String?
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        [
            system.rawValue, voltage, load, loadUnit.rawValue, powerFactor,
            material.rawValue, construction.rawValue, insulation.rawValue, termination.rawValue,
            ambient, ccc, continuous ? "1" : "0", length, target, maxRuns,
            dollarsPerKft, dollarsPerKwh, hours,
        ].joined(separator: "|")
    }

    var body: some View {
        ToolScaffold(
            toolID: .conductorCost,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .conductorCost,
                symbolic: "Rank size × runs by first-cost after 310.16 + VD",
                substituted: substituted,
                meaning: "Every option must clear derated ampacity (310.16 / 310.15 / 110.14(C)) and the preferred voltage-drop target. Parallels are offered only for 1/0 AWG and larger. Dollars are a planning allowance you enter or the default book — not LME, not a bid.",
                citation: "NEC 2023 Table 310.16 · 310.15 · 110.14(C) · 310.10(G) · Ch.9 Tables 1 / 4 / 5 / 8 / 9."
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
            HStack(alignment: .top, spacing: Theme.Space.sm) {
                NumberField(title: "Load", unit: loadUnit.displayName, text: $load, fieldID: "load", onSubmit: calculate)
                MenuField(title: "Units", selection: $loadUnit, options: ConductorLoadUnit.allCases) { $0.displayName }
                    .frame(maxWidth: 120)
            }
            if loadUnit == .kw {
                NumberField(title: "Power factor", unit: "", text: $powerFactor, fieldID: "pf", onSubmit: calculate)
            }
            NumberField(title: "One-way length", unit: "ft", text: $length, fieldID: "length", onSubmit: calculate)
            NumberField(title: "Preferred drop target", unit: "%", text: $target, fieldID: "target", onSubmit: calculate)
            Toggle("Continuous load (125%)", isOn: $continuous)

            MenuField(title: "Construction", selection: $construction, options: LVConstruction.allCases) { $0.displayName }
            MenuField(title: "Insulation", selection: $insulation, options: TempChoice.allCases) { $0.label }
            MenuField(title: "Termination", selection: $termination, options: TempChoice.allCases) { $0.label }
            NumberField(title: "Ambient", unit: "°C", text: $ambient, fieldID: "ambient", onSubmit: calculate)
            NumberField(title: "Current-carrying conductors", unit: "CCC", text: $ccc, fieldID: "ccc", onSubmit: calculate)
            NumberField(title: "Max parallel runs", unit: "runs", text: $maxRuns, fieldID: "maxRuns", onSubmit: calculate)

            NumberField(
                title: "Planning $/kft",
                unit: "$/kft",
                text: $dollarsPerKft,
                optional: true,
                helpText: "Leave blank to use the default planning book for each size. Not a live quote.",
                fieldID: "kft",
                onSubmit: calculate
            )
            NumberField(title: "Energy", unit: "$/kWh", text: $dollarsPerKwh, optional: true, fieldID: "kwh", onSubmit: calculate)
            NumberField(title: "Hours / year", unit: "h", text: $hours, optional: true, fieldID: "hours", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: applyExample,
                exampleTitle: "480 V 3Ø, 150 A continuous, 250 ft Cu"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                results(r)
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .onAppear(perform: applyIncomingHandoff)
        .sensoryFeedback(.success, trigger: successTick)
    }

    @ViewBuilder
    private func results(_ r: ConductorCostResult) -> some View {
        ResultCard(copyText: copyText) {
            ResultRow(label: "Load current", value: Format.amps(r.loadAmps), emphasis: true)
            ResultRow(label: "Basis", value: r.currentBasis, tone: Theme.muted)
            if r.designCurrent > r.loadAmps + 1e-9 {
                ResultRow(label: "Continuous ×1.25", value: Format.amps(r.designCurrent))
            }
            ResultRow(label: "Lowest first-cost", value: r.recommended.typeString, emphasis: true, tone: Theme.good)
            ResultRow(label: "Modeled first-cost", value: Format.dollars(r.recommended.firstCost), emphasis: true, tone: Theme.good)
            ResultRow(label: "Usable ampacity", value: Format.amps(r.recommended.usableAmpacity), tone: Theme.good)
            ResultRow(label: "Voltage drop", value: "\(Format.volts(r.recommended.dropVolts))  ·  \(Format.percent(r.recommended.dropPercent))")
            if let emt = r.recommended.suggestedEMT {
                ResultRow(label: "Suggested EMT / run", value: "\(emt)\"  (\(r.recommended.conductorsPerRun) cond.)")
            }
            ResultRow(label: "Price source", value: r.priceSource, tone: Theme.muted)
            if let watts = r.recommended.i2rWatts {
                ResultRow(label: "I²R (operating I)", value: Format.watts(watts), tone: Theme.muted)
            }
            if let annual = r.recommended.annualEnergyCost {
                ResultRow(label: "Modeled annual I²R", value: Format.dollars(annual))
            }
            if let life = r.recommended.lifecycleCost {
                ResultRow(label: "First + 1 yr energy", value: Format.dollars(life))
            }
        }
        .opacity(session.isStale ? 0.72 : 1)

        ResultCard(title: "Compliant options") {
            ForEach(Array(r.options.prefix(10).enumerated()), id: \.offset) { index, option in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(option.typeString)
                            .font(.caption.weight(index == 0 ? .bold : .regular))
                            .foregroundStyle(index == 0 ? Theme.good : Theme.foreground)
                        Spacer(minLength: 8)
                        Text(Format.dollars(option.firstCost))
                            .font(.caption.monospacedDigit().weight(.semibold))
                    }
                    HStack {
                        Text("amp \(Format.amps(option.usableAmpacity))")
                            .font(.caption2)
                            .foregroundStyle(Theme.good)
                        Text("VD \(Format.percent(option.dropPercent))")
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                        if let emt = option.suggestedEMT {
                            Text("EMT \(emt)\"")
                                .font(.caption2)
                                .foregroundStyle(Theme.muted)
                        }
                        if let life = option.lifecycleCost {
                            Text("life \(Format.dollars(life))")
                                .font(.caption2)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(option.typeString), \(Format.dollars(option.firstCost)), drop \(Format.percent(option.dropPercent))")
            }
            if r.options.count > 10 {
                Text("+\(r.options.count - 10) more compliant options ranked by first-cost")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
            }
        }
        .opacity(session.isStale ? 0.72 : 1)

        if !r.warnings.isEmpty {
            ResultCard(title: "Provenance") {
                ForEach(Array(r.warnings.enumerated()), id: \.offset) { _, warning in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(warning.provenance.displayName.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                        Text(warning.message)
                            .font(.caption)
                            .foregroundStyle(warning.severity == .critical ? Theme.bad : Theme.muted)
                    }
                    .padding(.vertical, 3)
                    .accessibilityElement(children: .combine)
                }
            }
        }

        ResultCard(title: "Code references") {
            ForEach(Array(r.citations.enumerated()), id: \.offset) { _, cite in
                ResultRow(label: cite.articleOrTable, value: cite.edition.displayName, tone: Theme.muted)
            }
        }

        if !session.isStale {
            Button {
                ConductorHandoff.save(r.seed)
                openRelated(.voltageDrop)
            } label: {
                Label("Continue with Voltage Drop", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.copper)

            Button {
                ConductorHandoff.save(r.seed)
                openRelated(.wireAmpacity)
            } label: {
                Label("Continue with Wire Ampacity", systemImage: "arrow.right.circle")
                    .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
            }
            .buttonStyle(.bordered)

            Button {
                ConductorHandoff.save(r.seed)
                openRelated(.conduitFill)
            } label: {
                Label("Continue with Conduit Fill", systemImage: "arrow.right.circle")
                    .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
            }
            .buttonStyle(.bordered)

            SaveJobBar(jobName: $jobName, canSave: true) {
                jobs.save(SavedJob(
                    name: jobName,
                    toolID: .conductorCost,
                    inputs: [
                        "V": voltage,
                        "I": load,
                        "unit": loadUnit.rawValue,
                        "L": length,
                        "mat": material.displayName,
                        "runs": "\(r.recommended.parallelRuns)",
                    ],
                    outputs: [
                        "pick": r.recommended.typeString,
                        "cost": Format.dollars(r.recommended.firstCost),
                        "vd": Format.percent(r.recommended.dropPercent),
                    ]
                ))
            }
        }
    }

    private func calculate() {
        session.calculate {
            try ConductorCost.optimize(ConductorCostInput(
                system: system,
                supplyVolts: voltage.parsedDouble ?? .nan,
                loadValue: load.parsedDouble ?? .nan,
                loadUnit: loadUnit,
                powerFactor: powerFactor.parsedDouble ?? .nan,
                material: material,
                insulation: insulation.column,
                termination: termination.column,
                ambientC: ambient.parsedDouble ?? .nan,
                currentCarryingCount: Int(ccc.parsedDouble ?? 0),
                continuousLoad: continuous,
                oneWayFeet: length.parsedDouble ?? .nan,
                targetDropPercent: target.parsedDouble ?? .nan,
                maxParallelRuns: Int(maxRuns.parsedDouble ?? 0),
                construction: construction,
                dollarsPerKft: optionalPositive(dollarsPerKft),
                dollarsPerKwh: optionalPositive(dollarsPerKwh),
                hoursPerYear: optionalPositive(hours)
            ))
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func optionalPositive(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = trimmed.parsedDouble, value > 0 else { return nil }
        return value
    }

    private func reset() {
        voltage = ""
        load = ""
        length = ""
        target = "3"
        maxRuns = "4"
        ambient = "30"
        ccc = "3"
        dollarsPerKft = ""
        dollarsPerKwh = ""
        hours = ""
        importedBanner = nil
        session.reset()
    }

    private func applyExample() {
        system = .threePhase
        voltage = "480"
        load = "150"
        loadUnit = .amps
        powerFactor = "0.9"
        material = .copper
        construction = .fourPlusE
        insulation = .c90
        termination = .c75
        ambient = "30"
        ccc = "3"
        continuous = true
        length = "250"
        target = "3"
        maxRuns = "4"
        dollarsPerKft = ""
        dollarsPerKwh = ""
        hours = ""
        session.prepareForNewInputs()
    }

    private func applyIncomingHandoff() {
        guard let seed = ConductorHandoff.consume() else { return }
        load = Format.number(seed.loadAmps, digits: 2)
        loadUnit = .amps
        material = seed.material
        if let system = seed.system { self.system = system }
        if let volts = seed.supplyVolts { voltage = Format.number(volts, digits: 1) }
        if let feet = seed.oneWayFeet { length = Format.number(feet, digits: 1) }
        if let insul = seed.insulationCelsius, let choice = TempChoice(rawValue: "\(insul)") {
            insulation = choice
        }
        if let term = seed.terminationCelsius, let choice = TempChoice(rawValue: "\(term)") {
            termination = choice
        }
        importedBanner = "Imported from \(seed.sourceSummary). Edit freely, then Calculate."
        session.prepareForNewInputs()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.formula)  →  \(r.recommended.typeString)  \(Format.dollars(r.recommended.firstCost))"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.recommended.typeString)  ·  \(Format.dollars(r.recommended.firstCost))"
    }

    private var copyText: String? { sticky }
}
