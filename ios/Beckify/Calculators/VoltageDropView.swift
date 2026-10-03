import SwiftUI
import BeckifyMath

struct VoltageDropView: View {
    @EnvironmentObject private var jobs: JobStore
    @AppStorage(ToolboxPreferenceKey.electricalCode) private var codeRaw = ElectricalCode.nec.rawValue
    @AppStorage(ToolboxPreferenceKey.preferredUnits) private var unitsRaw = PreferredUnitSystem.followCode.rawValue
    @StoredChoice(.voltageDrop, "system", default: ElectricalSystem.threePhase) private var system
    @StoredInput(.voltageDrop, "voltage", default: "480") private var voltage
    @StoredInput(.voltageDrop, "current", default: "45") private var current
    @StoredInput(.voltageDrop, "length", default: "250") private var length
    @StoredChoice(.voltageDrop, "material", default: ConductorMaterial.copper) private var material
    @StoredInput(.voltageDrop, "size", default: "4") private var size
    @StoredInput(.voltageDrop, "runs", default: "1") private var runs
    @StoredInput(.voltageDrop, "target", default: "3") private var target
    @StoredInput(.voltageDrop, "asnzsVoltage", default: "400") private var asVoltage
    @StoredInput(.voltageDrop, "asnzsCurrent", default: "32") private var asCurrent
    @StoredInput(.voltageDrop, "asnzsLength", default: "40") private var asLength
    @StoredInput(.voltageDrop, "asnzsSize", default: "6") private var asSize
    @StoredInput(.voltageDrop, "asnzsRuns", default: "1") private var asRuns
    @StoredInput(.voltageDrop, "asnzsTarget", default: "5") private var asTarget
    @StoredInput(.voltageDrop, "asnzsTemp", default: "75") private var asTemp
    @StoredInput(.voltageDrop, "jobName", default: "Voltage drop") private var jobName
    @State private var session = ExplicitCalculationState<VoltageDropSizingResult>()
    @State private var asnzsSession = ExplicitCalculationState<ASNZSVoltageDropResult>()
    @State private var importedBanner: String?
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var code: ElectricalCode { ElectricalCode(rawValue: codeRaw) ?? .nec }

    private var lengthUnit: FieldLengthUnit {
        (PreferredUnitSystem(rawValue: unitsRaw) ?? .followCode).lengthUnit(for: code)
    }

    private var necSizes: [String] {
        NECTables.wireSizeOrder.filter { NECTables.circularMils[$0] != nil }
    }

    private var asSizes: [String] { ASNZSTables.tokens(for: material) }

    private var inputFingerprint: String {
        let common = "\(code.rawValue)|\(lengthUnit.rawValue)|\(system)|\(material)"
        if code == .asnzs {
            return "\(common)|as|\(asVoltage)|\(asCurrent)|\(asLength)|\(asSize)|\(asRuns)|\(asTarget)|\(asTemp)"
        }
        return "\(common)|nec|\(voltage)|\(current)|\(length)|\(size)|\(runs)|\(target)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .voltageDrop,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: code == .asnzs ? asnzsSession.isStale : session.isStale
        ) {
            if code == .asnzs {
                asnzsContent
            } else {
                necContent
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
            asnzsSession.markInputsChanged()
        }
        .onChange(of: material) { _, _ in
            guard code == .asnzs, !asSizes.contains(asSize) else { return }
            asSize = asSizes.first ?? "16"
        }
        .onAppear(perform: applyIncomingHandoff)
        .sensoryFeedback(.success, trigger: successTick)
    }

    @ViewBuilder
    private var necContent: some View {
        ShowWorkCard(
            toolID: .voltageDrop,
            symbolic: "VD ≈ (M × K × I × L) / (CM × runs)",
            substituted: necSubstituted,
            meaning: "M is 2 for 1Ø/DC or √3 for 3Ø. K ≈ 12.9 Cu / 21.2 Al is a field resistivity near 75 °C, not Chapter 9 Table 9. Table 9 is AC impedance. Enter the amps the load is drawing. 3% and 5% Informational Notes compare this single run — the form has no separate feeder+branch segments. The ampacity row is Table 310.16 75 °C × runs vs those amps; continuous × 1.25 and 110.14(C) still apply when you size the circuit. Long 480 V feeders at 2 AWG and larger want Table 8 R plus Table 9 X.",
            citation: "Field K near 75 °C · Ch.9 Table 8 R + Table 9 X when reactance matters · Table 310.16 · 210.19(A) and 215.2(A) Informational Notes.",
            referenceTool: .wireAmpacity
        )

        if let importedBanner {
            Text(importedBanner)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.accent)
        }
        if lengthUnit == .metres {
            Text("Length is metres. The NEC K-factor formula converts that number to feet. Switching units does not rewrite the number already in the field.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
        }

        Picker("System", selection: $system) {
            ForEach(ElectricalSystem.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }
        .segmentedControlStyle()
        Picker("Material", selection: $material) {
            ForEach(ConductorMaterial.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }
        .segmentedControlStyle()

        NumberField(
            title: "Supply voltage",
            unit: "V",
            text: $voltage,
            helpText: "Voltage across the load: line-to-line for 3Ø; line-to-line or line-to-neutral as wired for 1Ø; DC supply voltage for DC.",
            fieldID: "voltage",
            onSubmit: calculateNEC
        )
        NumberField(title: "Load current", unit: "A", text: $current, fieldID: "current", onSubmit: calculateNEC)
        NumberField(title: "One-way length", unit: lengthUnit.symbol, text: $length, fieldID: "length", onSubmit: calculateNEC)
        MenuField(title: "Conductor", selection: $size, options: necSizes, label: NECTables.wireLabel)
        NumberField(title: "Parallel runs per phase", unit: "runs", text: $runs, fieldID: "runs", onSubmit: calculateNEC)
        NumberField(title: "Preferred drop target", unit: "%", text: $target, fieldID: "target", onSubmit: calculateNEC)

        CalculatorActionBar(
            onCalculate: calculateNEC,
            onReset: resetNEC,
            onExample: {
                system = .threePhase
                voltage = "480"
                current = "45"
                length = lengthUnit == .metres ? "76.2" : "250"
                material = .copper
                size = "4"
                runs = "1"
                target = "3"
                session.prepareForNewInputs()
            },
            exampleTitle: lengthUnit == .metres ? "480 V 3Ø, 45 A, 76.2 m, 4 Cu" : "480 V 3Ø, 45 A, 250 ft, 4 Cu"
        )

        if let error = session.lastValidationError ?? session.error {
            ErrorText(message: error.message)
        }

        if let r = session.displayedResult {
            let run = VoltageDropRunReadout(result: r)
            if let run, let diagram = VoltageDropDiagram.model(
                supply: run.supplyVolts,
                drop: run.chartDropVolts,
                receiving: run.receivingVolts,
                dropPercent: run.chartDropPercent,
                oneWayLength: lengthLabel(fromFeet: run.oneWayFeet),
                parallelRuns: run.parallelRuns,
                targetPercent: run.targetDropPercent,
                meetsTarget: run.meetsTarget
            ) {
                diagram.opacity(session.isStale ? 0.72 : 1)
            }

            ResultCard(copyText: necCopy) {
                ResultRow(label: "Method", value: r.method.displayName, tone: Theme.muted)
                ResultRow(label: "Voltage drop", value: Format.volts(r.dropVolts), emphasis: true)
                ResultRow(label: "Drop", value: Format.percent(r.dropPercent), emphasis: true)
                ResultRow(label: "Receiving end", value: Format.volts(r.receivingVolts))
                ResultRow(
                    label: "Preferred target \(Format.percent(r.targetDropPercent))",
                    value: r.meetsTarget ? "MEETS" : "OVER",
                    tone: r.meetsTarget ? Theme.good : Theme.warn
                )
                if let run {
                    ResultRow(
                        label: run.note3Label,
                        value: run.note3Value,
                        tone: run.meets3Percent ? Theme.good : Theme.warn
                    )
                    ResultRow(
                        label: run.note5Label,
                        value: run.note5Value,
                        tone: run.meets5Percent ? Theme.good : Theme.bad
                    )
                }
                if let amp = r.ampacity75C {
                    ResultRow(
                        label: run?.ampacityRowLabel ?? "310.16 75 °C × runs (≤3 CCC, 30 °C)",
                        value: "\(amp) A" + (r.ampacityOK ? "  meets load" : "  undersized"),
                        tone: r.ampacityOK ? Theme.good : Theme.bad
                    )
                    Text(run?.ampacityAssumptionCaption ?? VoltageDropRunReadout.ampacityAssumptionFallback)
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
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

            EquipmentGroundingCard(
                recommendation: EquipmentGrounding.recommend(
                    amps: current.parsedDouble ?? .nan,
                    material: material,
                    context: EquipmentGroundingContext.from(system: system),
                    ampsAreOCPDRating: false,
                    ungroundedSize: r.recommendedSize ?? size
                )
            )
            .opacity(session.isStale ? 0.72 : 1)

            ResultCard(title: "Size comparison") {
                ForEach(necComparisonRows(from: r), id: \.size) { row in
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
                warningCard(r.warnings)
            }

            ResultCard(title: "Code references") {
                ForEach(Array(r.citations.enumerated()), id: \.offset) { _, cite in
                    ResultRow(label: cite.articleOrTable, value: cite.edition.displayName, tone: Theme.muted)
                }
            }

            ContractorShareBar(tool: .voltageDrop, fields: necShareFields(r), enabled: !session.isStale)

            SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                jobs.save(SavedJob(
                    name: jobName,
                    toolID: .voltageDrop,
                    inputs: [
                        "code": ElectricalCode.nec.displayName,
                        "sys": system.displayName,
                        "V": voltage,
                        "I": current,
                        "L": length,
                        "Lunit": lengthUnit.symbol,
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

    @ViewBuilder
    private var asnzsContent: some View {
        ShowWorkCard(
            toolID: .voltageDrop,
            symbolic: "Vd = M × I × L × R",
            substituted: asSubstituted,
            meaning: "M is 2 for 1Ø/DC or √3 for 3Ø. R is the IEC 60228 Class 2 maximum, corrected from 20 °C. Reactance is zero and power factor is 1. This is not an AS/NZS 3008 mV/A·m table, and it does not check current-carrying capacity.",
            citation: "AS/NZS 3000:2018 Clause 3.6.2 (5% from the point of supply) · Table 5.1 copper earth · IEC 60228 Class 2 R. Not AS/NZS 3008.",
            referenceTool: .wireAmpacity
        )

        if let importedBanner {
            Text(importedBanner)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.accent)
        }
        Text(ElectricalCode.asnzs.nominalSupply.note)
            .font(Theme.TypeRole.help)
            .foregroundStyle(Theme.muted)
        if lengthUnit == .feet {
            Text("Length is feet. This AS/NZS path converts that number to metres before using R in Ω/m. Switching units does not rewrite the number already in the field.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
        }

        Picker("System", selection: $system) {
            ForEach(ElectricalSystem.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }
        .segmentedControlStyle()
        Picker("Material", selection: $material) {
            ForEach(ConductorMaterial.allCases, id: \.self) { Text(ASNZSTables.materialName($0)).tag($0) }
        }
        .segmentedControlStyle()

        NumberField(title: "Supply voltage", unit: "V", text: $asVoltage, fieldID: "voltage", onSubmit: calculateASNZS)
        NumberField(title: "Load current", unit: "A", text: $asCurrent, fieldID: "current", onSubmit: calculateASNZS)
        NumberField(title: "One-way length", unit: lengthUnit.symbol, text: $asLength, fieldID: "length", onSubmit: calculateASNZS)
        MenuField(title: "Conductor", selection: $asSize, options: asSizes) { "\($0) mm²" }
        NumberField(title: "Parallel runs per phase", unit: "runs", text: $asRuns, fieldID: "runs", onSubmit: calculateASNZS)
        NumberField(title: "Preferred drop target", unit: "%", text: $asTarget, fieldID: "target", onSubmit: calculateASNZS)
        Picker("Conductor temperature", selection: $asTemp) {
            Text("75 °C").tag("75")
            Text("90 °C").tag("90")
        }
        .segmentedControlStyle()

        CalculatorActionBar(
            onCalculate: calculateASNZS,
            onReset: resetASNZS,
            onExample: {
                system = .threePhase
                asVoltage = "400"
                asCurrent = "32"
                asLength = lengthUnit == .feet ? "131.2" : "40"
                material = .copper
                asSize = "6"
                asRuns = "1"
                asTarget = "5"
                asTemp = "75"
                asnzsSession.prepareForNewInputs()
            },
            exampleTitle: lengthUnit == .feet ? "400 V 3Ø, 32 A, 131.2 ft, 6 mm² Cu" : "400 V 3Ø, 32 A, 40 m, 6 mm² Cu"
        )

        if let error = asnzsSession.lastValidationError ?? asnzsSession.error {
            ErrorText(message: error.message)
        }

        if let r = asnzsSession.displayedResult {
            if let diagram = VoltageDropDiagram.model(
                supply: r.supplyVolts,
                drop: r.dropVolts,
                receiving: r.receivingVolts,
                dropPercent: r.dropPercent,
                oneWayLength: "\(Format.number(r.oneWayMetres, digits: 2)) m",
                parallelRuns: r.parallelRuns,
                targetPercent: r.targetDropPercent,
                meetsTarget: r.meetsTarget
            ) {
                diagram.opacity(asnzsSession.isStale ? 0.72 : 1)
            }

            ResultCard(copyText: asCopy) {
                ResultRow(label: "Method", value: "Resistance only (IEC 60228)", tone: Theme.muted)
                ResultRow(label: "Code", value: "AS/NZS", emphasis: true, tone: Theme.accent)
                ResultRow(label: "Voltage drop", value: Format.volts(r.dropVolts), emphasis: true)
                ResultRow(label: "Drop", value: Format.percent(r.dropPercent), emphasis: true)
                ResultRow(label: "Receiving end", value: Format.volts(r.receivingVolts))
                ResultRow(label: "One-way used", value: "\(Format.number(r.oneWayMetres, digits: 2)) m")
                ResultRow(
                    label: "Clause 3.6.2 ≤ 5%",
                    value: r.meetsInstallationLimit ? "WITHIN" : "OVER 5%",
                    tone: r.meetsInstallationLimit ? Theme.good : Theme.bad
                )
                ResultRow(
                    label: "Preferred target \(Format.percent(r.targetDropPercent))",
                    value: r.meetsTarget ? "MEETS" : "OVER",
                    tone: r.meetsTarget ? Theme.good : Theme.warn
                )
                ResultRow(label: "R at \(Format.number(r.conductorTemperatureC, digits: 0)) °C", value: "\(Format.number(r.resistanceOhmPerKm, digits: 4)) Ω/km", tone: Theme.muted)
                ResultRow(label: "Ampacity", value: "Not checked — no AS/NZS 3008 table", tone: Theme.warn)
                if let rec = r.recommendedLabel {
                    ResultRow(label: "Smallest size at target", value: rec, emphasis: true, tone: Theme.good)
                }
                if let loss = r.conductorLossWatts {
                    ResultRow(label: "Approx. I²R loss", value: Format.watts(loss), tone: Theme.muted)
                }
            }
            .opacity(asnzsSession.isStale ? 0.72 : 1)

            if let earth = r.earth {
                asnzsEarthCard(earth, title: "Earthing conductor")
                    .opacity(asnzsSession.isStale ? 0.72 : 1)
            }
            if let recommended = r.recommendedEarth, recommended.activeMM2 != r.earth?.activeMM2 {
                asnzsEarthCard(recommended, title: "Earth at the smaller target size")
                    .opacity(asnzsSession.isStale ? 0.72 : 1)
            }

            ResultCard(title: "Size comparison") {
                ForEach(asComparisonRows(from: r), id: \.token) { row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.label)
                            .font(.caption.monospacedDigit().weight(row.token == r.token ? .bold : .regular))
                            .foregroundStyle(row.token == (r.recommendedMM2.map(ASNZSTables.token(for:)) ?? r.token) ? Theme.good : Theme.foreground)
                            .frame(minWidth: 72, alignment: .leading)
                        Spacer(minLength: 6)
                        Text(Format.percent(row.dropPercent))
                            .font(.caption.monospacedDigit())
                        Text(row.meetsInstallationLimit ? "≤5%" : "over 5%")
                            .font(.caption2)
                            .foregroundStyle(row.meetsInstallationLimit ? Theme.good : Theme.bad)
                    }
                    .padding(.vertical, 2)
                }
            }
            .opacity(asnzsSession.isStale ? 0.72 : 1)

            if !r.warnings.isEmpty {
                warningCard(r.warnings)
            }

            ResultCard(title: "Code references") {
                ForEach(Array(r.citations.enumerated()), id: \.offset) { _, cite in
                    ResultRow(label: cite.articleOrTable, value: cite.edition.displayName, tone: Theme.muted)
                }
            }

            ContractorShareBar(tool: .voltageDrop, fields: asnzsShareFields(r), enabled: !asnzsSession.isStale)

            SaveJobBar(jobName: $jobName, canSave: !asnzsSession.isStale) {
                jobs.save(SavedJob(
                    name: jobName,
                    toolID: .voltageDrop,
                    inputs: [
                        "code": ElectricalCode.asnzs.rawValue,
                        "system": system.displayName,
                        "asnzsVoltage": asVoltage,
                        "asnzsCurrent": asCurrent,
                        "asnzsLength": asLength,
                        "asnzsSize": asSize,
                        "material": ASNZSTables.materialName(material),
                        "asnzsRuns": asRuns,
                        "asnzsTarget": asTarget,
                        "asnzsTemp": asTemp,
                    ],
                    outputs: [
                        "VD": Format.volts(r.dropVolts),
                        "%": Format.percent(r.dropPercent),
                        "rec": r.recommendedLabel ?? r.label,
                        "earth": r.earth?.copyLine ?? "",
                    ]
                ))
            }
        }
    }

    private func asnzsEarthCard(_ earth: ASNZSEarthingRecommendation, title: String) -> some View {
        ResultCard(title: title, copyText: earth.copyLine) {
            ResultRow(label: "Separate copper earth", value: ASNZSTables.label(for: earth.separateCopperMM2), emphasis: true, tone: Theme.copper)
            ResultRow(label: "Table 5.1 minimum", value: ASNZSTables.label(for: earth.tableCopperMM2))
            ResultRow(label: "Active", value: "\(earth.activeLabel) \(ASNZSTables.materialName(earth.activeMaterial))")
            ResultRow(label: earth.citation.articleOrTable, value: earth.citation.edition.displayName, tone: Theme.muted)
            ForEach(Array(earth.notes.prefix(4).enumerated()), id: \.offset) { _, note in
                Text(note)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .padding(.vertical, 2)
            }
        }
    }

    private func warningCard(_ warnings: [DesignWarning]) -> some View {
        ResultCard(title: "Assumptions & limits") {
            ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
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

    private struct NECComparisonRow {
        var size: String
        var label: String
        var dropPercent: Double
        var receivingVolts: Double
        var ampacityOK: Bool
        var highlight: Bool
    }

    private func necComparisonRows(from r: VoltageDropSizingResult) -> [NECComparisonRow] {
        let focus = Set([r.size, r.ampacityMinimumSize, r.voltageDropMinimumSize, r.recommendedSize].compactMap { $0 })
        return r.candidates
            .filter { focus.contains($0.size) || $0.meetsAllConstraints || $0.size == r.size }
            .prefix(8)
            .map {
                NECComparisonRow(
                    size: $0.size,
                    label: $0.label,
                    dropPercent: $0.dropPercent,
                    receivingVolts: $0.receivingVolts,
                    ampacityOK: $0.ampacityOK,
                    highlight: $0.size == (r.recommendedSize ?? r.size)
                )
            }
    }

    private func asComparisonRows(from r: ASNZSVoltageDropResult) -> [ASNZSVoltageDropCandidate] {
        let recommendedToken = r.recommendedMM2.map(ASNZSTables.token(for:))
        let focus: Set<String> = [r.token, recommendedToken].compactMap { $0 }.reduce(into: Set<String>()) { $0.insert($1) }
        let picked = r.candidates.filter { focus.contains($0.token) || $0.meetsTarget }
        if picked.count >= 2 { return Array(picked.prefix(8)) }
        return Array(r.candidates.prefix(6))
    }

    private func calculateNEC() {
        let typedLength = length.parsedDouble ?? .nan
        let feet = lengthUnit.feet(from: typedLength)
        session.calculate {
            try VoltageDropSizing.calculate(
                VoltageDropSizingInput(
                    system: system,
                    supplyVolts: voltage.parsedDouble ?? .nan,
                    current: current.parsedDouble ?? .nan,
                    oneWayFeet: feet,
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

    private func calculateASNZS() {
        let typedLength = asLength.parsedDouble ?? .nan
        let metres = lengthUnit.metres(from: typedLength)
        asnzsSession.calculate {
            guard let sizeMM2 = ASNZSTables.mm2(from: asSize) else {
                throw CalcError.notListed("Pick a listed mm² size.")
            }
            return try ASNZSVoltageDrop.calculate(
                ASNZSVoltageDropInput(
                    system: system,
                    supplyVolts: asVoltage.parsedDouble ?? .nan,
                    current: asCurrent.parsedDouble ?? .nan,
                    oneWayMetres: metres,
                    sizeMM2: sizeMM2,
                    material: material,
                    parallelRuns: Int(asRuns.parsedDouble ?? 0),
                    targetDropPercent: asTarget.parsedDouble ?? .nan,
                    conductorTemperatureC: asTemp.parsedDouble ?? .nan
                )
            )
        }
        if asnzsSession.displayedResult != nil, !asnzsSession.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func resetNEC() {
        voltage = ""
        current = ""
        length = ""
        size = "4"
        runs = "1"
        target = "3"
        importedBanner = nil
        session.reset()
    }

    private func resetASNZS() {
        asVoltage = ""
        asCurrent = ""
        asLength = ""
        asSize = "6"
        asRuns = "1"
        asTarget = "5"
        asTemp = "75"
        importedBanner = nil
        asnzsSession.reset()
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
        if code == .asnzs {
            importedBanner = "Imported design is AWG and feet. It was stored on the NEC inputs. Switch Settings to NEC (US) to use it — this AS/NZS screen was not filled with a converted size."
        } else {
            importedBanner = "Imported from \(seed.sourceSummary). Edit freely, then Calculate."
        }
        session.prepareForNewInputs()
    }

    /// One-way length in the unit on screen, from the feet the NEC result used.
    private func lengthLabel(fromFeet feet: Double) -> String {
        let shown: Double
        switch lengthUnit {
        case .feet:
            shown = feet
        case .metres:
            shown = FieldLengthUnit.feet.metres(from: feet)
        }
        return "\(Format.number(shown, digits: 1)) \(lengthUnit.symbol)"
    }

    private var necSubstituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.formula)  →  \(Format.volts(r.dropVolts))  (\(Format.percent(r.dropPercent)))"
    }

    private var asSubstituted: String? {
        guard let r = asnzsSession.displayedResult else { return nil }
        return "\(r.formula)  →  \(Format.volts(r.dropVolts))  (\(Format.percent(r.dropPercent)))"
    }

    private var sticky: String? {
        if code == .asnzs {
            guard let r = asnzsSession.displayedResult else { return nil }
            let rec = r.recommendedLabel.map { "  ·  rec \($0)" } ?? ""
            return "AS/NZS  \(Format.volts(r.dropVolts))  ·  \(Format.percent(r.dropPercent))\(rec)"
        }
        guard let r = session.displayedResult else { return nil }
        let rec = r.recommendedLabel.map { "  ·  rec \($0)" } ?? ""
        return "\(Format.volts(r.dropVolts))  ·  \(Format.percent(r.dropPercent))\(rec)"
    }

    private func necShareFields(_ r: VoltageDropSizingResult) -> [ContractorShareField] {
        var rows = [
            ContractorShareField(label: "Code", value: ElectricalCode.nec.displayName),
            ContractorShareField(label: "System", value: system.displayName),
            ContractorShareField(label: "Voltage", value: "\(voltage) V"),
            ContractorShareField(label: "Current", value: "\(current) A"),
            ContractorShareField(label: "One-way length", value: "\(length) \(lengthUnit.symbol)"),
            ContractorShareField(label: "Conductor", value: "\(NECTables.wireLabel(size)) \(material.displayName)"),
            ContractorShareField(label: "Runs", value: runs),
            ContractorShareField(label: "Voltage drop", value: Format.volts(r.dropVolts)),
            ContractorShareField(label: "Drop", value: Format.percent(r.dropPercent)),
            ContractorShareField(label: "Receiving end", value: Format.volts(r.receivingVolts)),
            ContractorShareField(label: "Target", value: r.meetsTarget ? "Meets \(Format.percent(r.targetDropPercent))" : "Over \(Format.percent(r.targetDropPercent))"),
        ]
        if let rec = r.recommendedLabel {
            rows.append(ContractorShareField(label: "Recommended", value: rec))
        }
        return rows
    }

    private func asnzsShareFields(_ r: ASNZSVoltageDropResult) -> [ContractorShareField] {
        var rows = [
            ContractorShareField(label: "Code", value: ElectricalCode.asnzs.displayName),
            ContractorShareField(label: "System", value: system.displayName),
            ContractorShareField(label: "Voltage", value: "\(asVoltage) V"),
            ContractorShareField(label: "Current", value: "\(asCurrent) A"),
            ContractorShareField(label: "One-way length", value: "\(asLength) \(lengthUnit.symbol)"),
            ContractorShareField(label: "Conductor", value: "\(asSize) mm² \(ASNZSTables.materialName(material))"),
            ContractorShareField(label: "Voltage drop", value: Format.volts(r.dropVolts)),
            ContractorShareField(label: "Drop", value: Format.percent(r.dropPercent)),
            ContractorShareField(label: "Receiving end", value: Format.volts(r.receivingVolts)),
        ]
        if let rec = r.recommendedLabel {
            rows.append(ContractorShareField(label: "Recommended", value: rec))
        }
        if let earth = r.earth {
            rows.append(ContractorShareField(label: "Earth", value: earth.copyLine))
        }
        return rows
    }

    private var necCopy: String? { sticky }
    private var asCopy: String? { sticky }
    private var copyText: String? { sticky }
}
