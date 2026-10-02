import SwiftUI
import BeckifyMath

struct ConductorLengthView: View {
    @EnvironmentObject private var jobs: JobStore
    @Environment(\.openRelatedTool) private var openRelated
    @StoredInput(.conductorLength, "resistance", default: "250") private var resistance
    @StoredChoice(.conductorLength, "rUnit", default: ConductorLengthResistanceUnit.milliohm) private var resistanceUnit
    @StoredInput(.conductorLength, "size", default: "1/0") private var size
    @StoredInput(.conductorLength, "customCmil", default: "250000") private var customCmil
    @StoredChoice(.conductorLength, "preset", default: ConductorLengthMaterial.copperAnnealed) private var material
    @StoredChoice(.conductorLength, "method", default: ConductorLengthMethod.loop2) private var method
    @StoredInput(.conductorLength, "temp", default: "20") private var temperature
    @StoredChoice(.conductorLength, "tempUnit", default: ConductorLengthTempUnit.celsius) private var temperatureUnit
    @StoredChoice(.conductorLength, "refTemp", default: ConductorLengthRefTemp.c20) private var refTemp
    @StoredInput(.conductorLength, "alpha", default: "0.00393") private var alpha
    @StoredInput(.conductorLength, "rho", default: "10.371") private var rho
    @StoredToggle(.conductorLength, "rhoAlphaCustom", default: false) private var rhoAlphaIsCustom
    @StoredChoice(.conductorLength, "technique", default: ConductorLengthMeasurementTechnique.twoWire) private var technique
    @StoredInput(.conductorLength, "leadR", default: "0") private var leadResistance
    @StoredInput(.conductorLength, "jumperR", default: "0") private var jumperResistance
    @StoredInput(.conductorLength, "qty", default: "1") private var conductorQuantityText
    @StoredInput(.conductorLength, "jobName", default: "Conductor length") private var jobName
    @State private var session = ExplicitCalculationState<ConductorLengthResult>()
    @State private var successTick = 0
    @State private var isApplyingPreset = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sizeOptions: [String] {
        NECTables.wireSizeOrder.filter { NECTables.circularMils[$0] != nil } + ["custom"]
    }

    private var resolvedCircularMils: Double {
        if size == "custom" {
            return customCmil.parsedDouble ?? .nan
        }
        return ConductorLength.circularMils(forSize: size) ?? .nan
    }

    private var conductorQuantity: Int {
        get { Int(conductorQuantityText) ?? 1 }
        nonmutating set { conductorQuantityText = "\(max(1, newValue))" }
    }

    private var conductorQuantityBinding: Binding<Int> {
        Binding(get: { conductorQuantity }, set: { conductorQuantity = $0 })
    }

    private var inputFingerprint: String {
        [
            resistance, resistanceUnit.rawValue, size, customCmil,
            material.rawValue, method.rawValue, temperature, temperatureUnit.rawValue,
            refTemp.rawValue, alpha, rho,
            technique.rawValue, leadResistance, jumperResistance, "\(conductorQuantity)",
        ].joined(separator: "|")
    }

    var body: some View {
        ToolScaffold(
            toolID: .conductorLength,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .designAidExtra("Uses R = ρL/CM with a linear α compensation. Contact resistance, stranding, and manufacturer ρ will shift the estimate — not a cable locator, TDR, or a bid length. Metal mass is book lb/kft × one-way length for one conductor, not a scale reading."),
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .conductorLength,
                symbolic: "L = (R_ref × CM) / ρ    R_ref = R / [1 + α × (T − T_ref)]",
                substituted: substituted,
                meaning: "Raw reading is first corrected for known lead/fixture or far-end jumper resistance, then corrected to the resistivity reference temperature, then solved for total conductor path. End-to-end reports that path. Two-conductor loop and 3-conductor far-end short divide it by two so the sticky number is distance to the far-end jumper. Metal mass is published lb/kft × that one-way length, for one conductor.",
                citation: "NEC Chapter 9 Table 8 circular mils · Cu ρ 10.371 / 12.9 Ω·cmil/ft · Al ρ 17.02 / 21.2 · α_Cu 0.00393 / α_Al 0.00403 · Cu 8.89 g/cm³ · Al 2.70 g/cm³.",
                referenceTool: .circularMils
            )

            HStack(alignment: .top, spacing: Theme.Space.sm) {
                NumberField(
                    title: "Measured resistance",
                    unit: resistanceUnit.displayName,
                    text: $resistance,
                    fieldID: "resistance",
                    onSubmit: calculate
                )
                MenuField(
                    title: "Units",
                    selection: $resistanceUnit,
                    options: ConductorLengthResistanceUnit.allCases
                ) { $0.displayName }
                .frame(maxWidth: 120)
            }

            MenuField(title: "Conductor size", selection: $size, options: sizeOptions, label: sizeLabel)
            if size == "custom" {
                NumberField(
                    title: "Custom circular mils",
                    unit: "cmil",
                    text: $customCmil,
                    fieldID: "customCmil",
                    onSubmit: calculate
                )
            }

            MenuField(
                title: "Material",
                selection: $material,
                options: ConductorLengthMaterial.allCases
            ) { $0.displayName }

            MenuField(
                title: "Measurement setup",
                selection: $method,
                options: [.loop2, .single, .loop3]
            ) { $0.displayName }
            Text(method.detail)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)

            MenuField(
                title: "Instrument technique",
                selection: $technique,
                options: ConductorLengthMeasurementTechnique.allCases
            ) { $0.displayName }
            Text(technique.detail)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)

            HStack(alignment: .top, spacing: Theme.Space.sm) {
                NumberField(
                    title: "Measurement temperature",
                    unit: temperatureUnit.displayName,
                    text: $temperature,
                    fieldID: "temp",
                    onSubmit: calculate
                )
                MenuField(
                    title: "Units",
                    selection: $temperatureUnit,
                    options: ConductorLengthTempUnit.allCases
                ) { $0.displayName }
                .frame(maxWidth: 120)
            }

            MenuField(
                title: "Resistivity reference",
                selection: $refTemp,
                options: ConductorLengthRefTemp.allCases
            ) { $0.displayName }

            NumberField(
                title: "Temperature coefficient α",
                unit: "1/°C",
                text: $alpha,
                helpText: rhoAlphaIsCustom
                    ? "Custom value — preserved when you switch material or reference temperature."
                    : "Filled from the material preset. Edit when you have manufacturer α.",
                fieldID: "alpha",
                onSubmit: calculate
            )
            .onChange(of: alpha) { _, _ in if !isApplyingPreset { rhoAlphaIsCustom = true } }
            NumberField(
                title: "Volume resistivity ρ",
                unit: "Ω·cmil/ft",
                text: $rho,
                helpText: rhoAlphaIsCustom
                    ? "Custom value — preserved when you switch material or reference temperature."
                    : "Cu 10.371 @20 °C / 12.9 @75 °C. Al 17.02 / 21.2. Hard-drawn copper currently reuses the annealed-copper book values — treat it as an approximation.",
                fieldID: "rho",
                onSubmit: calculate
            )
            .onChange(of: rho) { _, _ in if !isApplyingPreset { rhoAlphaIsCustom = true } }
            if rhoAlphaIsCustom {
                Button("Reset ρ / α to material preset") {
                    rhoAlphaIsCustom = false
                    applyMaterialPreset()
                }
                .font(Theme.TypeRole.help)
            }

            MenuField(
                title: "Conductors for total mass",
                selection: conductorQuantityBinding,
                options: [1, 2, 3, 4, 6, 9, 12]
            ) { "\($0)" }

            DisclosureGroup("Measurement quality corrections (optional)") {
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    if technique == .twoWire {
                        NumberField(
                            title: "Lead / fixture resistance",
                            unit: resistanceUnit.displayName,
                            text: $leadResistance,
                            optional: true,
                            helpText: "Known resistance of the test leads/fixture, subtracted from the raw reading before solving for length.",
                            fieldID: "leadR",
                            onSubmit: calculate
                        )
                    }
                    if method != .single {
                        NumberField(
                            title: "Far-end jumper / contact resistance",
                            unit: resistanceUnit.displayName,
                            text: $jumperResistance,
                            optional: true,
                            helpText: "Known resistance of the far-end bond or jumper. Four-wire sensing removes the meter's own lead error, not this remote jumper.",
                            fieldID: "jumperR",
                            onSubmit: calculate
                        )
                    }
                }
                .padding(.top, Theme.Space.sm)
            }
            .font(Theme.TypeRole.fieldLabel)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: applyExample,
                exampleTitle: "250 mΩ, 1/0 Cu, two-conductor loop"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ConductorLengthDiagram(method: method)
                    .opacity(session.isStale ? 0.72 : 1)

                ResultCard(copyText: copyText) {
                    ResultRow(
                        label: method.primaryLengthLabel,
                        value: "\(Format.number(r.oneWayLengthFt, digits: 2)) ft  ·  \(Format.meters(r.oneWayLengthM))",
                        emphasis: true,
                        tone: Theme.good
                    )
                    ResultRow(
                        label: r.metalMass.label,
                        value: "\(Format.number(r.metalMass.oneWayLb, digits: 2)) lb  ·  \(Format.number(r.metalMass.oneWayKg, digits: 2)) kg",
                        emphasis: true
                    )
                    if r.conductorQuantityForMass > 1 {
                        ResultRow(
                            label: "Total metal mass — \(r.conductorQuantityForMass) conductors",
                            value: "\(Format.number(r.metalMass.configuredTotalLb, digits: 2)) lb  ·  \(Format.number(r.metalMass.configuredTotalKg, digits: 2)) kg"
                        )
                    }
                    ResultRow(
                        label: "Total conductor path",
                        value: "\(Format.number(r.totalLengthFt, digits: 2)) ft  ·  \(Format.meters(r.totalLengthM))"
                    )
                    ResultRow(
                        label: "R at \(Format.number(r.referenceTempC, digits: 0)) °C",
                        value: "\(Format.number(r.resistanceAtRefTemp, digits: 6)) Ω"
                    )
                    ResultRow(label: "Net conductor-path resistance", value: "\(Format.number(r.resistanceOhms, digits: 6)) Ω")
                    if r.leadResistanceOhms > 0 || r.jumperResistanceOhms > 0 {
                        ResultRow(
                            label: "Raw reading / correction",
                            value: "\(Format.number(r.rawResistanceOhms, digits: 6)) Ω raw  −  \(Format.number(r.leadResistanceOhms + r.jumperResistanceOhms, digits: 6)) Ω correction",
                            tone: r.largeCorrectionWarning ? Theme.warn : Theme.muted
                        )
                        if r.largeCorrectionWarning {
                            ResultRow(
                                label: "Correction warning",
                                value: "Lead/jumper correction is a large share of the raw reading — verify the correction values.",
                                tone: Theme.warn
                            )
                        }
                    }
                    ResultRow(label: "Conductor area", value: "\(Format.number(r.circularMils, digits: 0)) cmil")
                    ResultRow(
                        label: "Material / ρ",
                        value: "\(material.displayName) — \(Format.number(r.rho, digits: 4)) Ω·cmil/ft"
                    )
                    ResultRow(label: "Measurement setup", value: method.detail, tone: Theme.muted)
                    ResultRow(label: "Instrument technique", value: technique.detail, tone: Theme.muted)
                    ResultRow(
                        label: "Mass basis",
                        value: "\(Format.number(r.metalMass.lbPerKft, digits: 2)) lb/kft × one-way length for one conductor (\(method.primaryLengthLabel.lowercased())). Bare \(r.metalMass.metalName.lowercased()) book — not a scale reading. Excludes insulation, jacket, armor, and fittings.",
                        tone: Theme.muted
                    )
                }
                .opacity(session.isStale ? 0.72 : 1)

                if !session.isStale {
                    Button {
                        openRelated(.voltageDrop)
                    } label: {
                        Label("Open Voltage Drop", systemImage: "arrow.right.circle")
                            .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        openRelated(.wireAmpacity)
                    } label: {
                        Label("Open Wire Ampacity", systemImage: "arrow.right.circle")
                            .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
                    }
                    .buttonStyle(.bordered)

                    SaveJobBar(jobName: $jobName, canSave: true) {
                        jobs.save(SavedJob(
                            name: jobName,
                            toolID: .conductorLength,
                            inputs: [
                                "R": resistance,
                                "unit": resistanceUnit.rawValue,
                                "size": size,
                                "CM": size == "custom" ? customCmil : "\(Format.number(r.circularMils, digits: 0))",
                                "mat": material.rawValue,
                                "method": method.rawValue,
                                "T": temperature,
                                "tempUnit": temperatureUnit.rawValue,
                                "refTemp": refTemp.rawValue,
                                "alpha": alpha,
                                "rho": rho,
                                "technique": technique.rawValue,
                                "leadR": leadResistance,
                                "jumperR": jumperResistance,
                                "qty": "\(conductorQuantity)",
                            ],
                            outputs: [
                                "oneWay": "\(Format.number(r.oneWayLengthFt, digits: 2)) ft",
                                "total": "\(Format.number(r.totalLengthFt, digits: 2)) ft",
                                "Rref": "\(Format.number(r.resistanceAtRefTemp, digits: 6)) Ω",
                                "Rnet": "\(Format.number(r.resistanceOhms, digits: 6)) Ω",
                                "weight": "\(Format.number(r.metalMass.oneWayLb, digits: 2)) lb",
                            ]
                        ))
                    }
                }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .onChange(of: material) { _, _ in
            if !rhoAlphaIsCustom { applyMaterialPreset() }
        }
        .onChange(of: refTemp) { _, _ in
            if !rhoAlphaIsCustom { applyMaterialPreset() }
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func sizeLabel(_ size: String) -> String {
        if size == "custom" { return "Custom circular mils" }
        let label = NECTables.wireLabel(size)
        guard let cm = NECTables.circularMils[size] else { return label }
        if label.hasSuffix("AWG") {
            return "\(label) (\(Format.number(cm, digits: 0)) cmil)"
        }
        return label
    }

    private func applyMaterialPreset() {
        let preset = ConductorLength.preset(material)
        isApplyingPreset = true
        alpha = Format.number(preset.alpha, digits: 5)
        rho = Format.number(preset.rho(at: refTemp), digits: 3)
        isApplyingPreset = false
    }

    private func calculate() {
        session.calculate {
            try ConductorLength.calculate(ConductorLengthInput(
                resistance: resistance.parsedDouble ?? .nan,
                resistanceUnit: resistanceUnit,
                circularMils: resolvedCircularMils,
                method: method,
                temperature: temperature.parsedDouble ?? .nan,
                temperatureUnit: temperatureUnit,
                referenceTempC: refTemp.celsius,
                alpha: alpha.parsedDouble ?? .nan,
                rho: rho.parsedDouble ?? .nan,
                material: material,
                measurementTechnique: technique,
                leadResistance: leadResistance.parsedDouble ?? 0,
                jumperResistance: jumperResistance.parsedDouble ?? 0,
                conductorQuantityForMass: conductorQuantity
            ))
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        resistance = ""
        customCmil = ""
        temperature = ""
        leadResistance = "0"
        jumperResistance = "0"
        conductorQuantity = 1
        rhoAlphaIsCustom = false
        applyMaterialPreset()
        session.reset()
    }

    private func applyExample() {
        resistance = "250"
        resistanceUnit = .milliohm
        size = "1/0"
        customCmil = "250000"
        material = .copperAnnealed
        method = .loop2
        temperature = "20"
        temperatureUnit = .celsius
        refTemp = .c20
        technique = .twoWire
        leadResistance = "0"
        jumperResistance = "0"
        conductorQuantity = 1
        rhoAlphaIsCustom = false
        isApplyingPreset = true
        alpha = "0.00393"
        rho = "10.371"
        isApplyingPreset = false
        session.prepareForNewInputs()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "R_ref = \(Format.number(r.resistanceOhms, digits: 6)) / [1 + \(Format.number(r.alpha, digits: 5)) × (\(Format.number(r.measuredTempC, digits: 1)) − \(Format.number(r.referenceTempC, digits: 0)))] = \(Format.number(r.resistanceAtRefTemp, digits: 6)) Ω  →  L = \(Format.number(r.totalLengthFt, digits: 2)) ft"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        let phrase = method == .single ? "end-to-end" : "to far-end jumper"
        return "\(Format.number(r.oneWayLengthFt, digits: 2)) ft \(phrase)  ·  \(Format.meters(r.oneWayLengthM))  ·  \(r.metalMass.label) \(Format.number(r.metalMass.oneWayLb, digits: 2)) lb (\(Format.number(r.metalMass.oneWayKg, digits: 2)) kg)"
    }

    private var copyText: String? { sticky }
}

// MARK: - Measurement path diagram

private struct ConductorLengthDiagram: View {
    let method: ConductorLengthMethod

    private var summary: String {
        switch method {
        case .single:
            return "Meter leads on the two ends of one isolated conductor. Measured distance equals the solved conductor path. Assumes an isolated, de-energized conductor."
        case .loop2:
            return "Two equal-length, equal-size, same-material conductors joined at the far end; meter across their near ends. One-way distance = total conductor path ÷ 2. Additional bonds or connected loads invalidate this simple loop reading."
        case .loop3:
            return "Three conductors with a far-end bond; the meter measures across the selected pair while the third near end is left open. That reading still traverses two conductor lengths, not three — one-way distance = total conductor path ÷ 2."
        }
    }

    private var farEndCaption: String {
        method == .single ? "Far end" : "Far-end jumper"
    }

    private var factorNote: String {
        method == .single
            ? "Path factor: ×1 (end-to-end)"
            : "Path factor: ÷2 — distance to far-end jumper is one-way"
    }

    var body: some View {
        DiagramCard(title: "Measurement setup", accessibilitySummary: summary) {
            VStack(alignment: .leading, spacing: 10) {
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .topLeading) {
                        meterBox
                            .frame(width: min(88, w * 0.28), height: 52)
                            .position(x: min(52, w * 0.16), y: 32)

                        wires(width: w)
                    }
                }
                .frame(height: 118)

                HStack {
                    Text("Meter")
                    Spacer()
                    Text(farEndCaption)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)

                Text(method.detail)
                    .font(.caption)
                    .foregroundStyle(Theme.foreground)
                Text(method == .single
                     ? "End-to-end length = solved conductor path. \(factorNote)"
                     : "Distance to far-end jumper = total conductor path ÷ 2. \(factorNote)")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                Text("Schematic only — not a geographically accurate route or a fault locator. Use isolated, de-energized conductors and appropriate measurement equipment.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 4)
        }
    }

    private var meterBox: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(Theme.accent, lineWidth: Theme.Stroke.emphasis)
            .overlay {
                VStack(spacing: 2) {
                    Text("DMM")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.foreground)
                    Text("mΩ / Ω")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
            }
    }

    @ViewBuilder
    private func wires(width: CGFloat) -> some View {
        let startX = min(100, width * 0.32)
        let endX = width - 18
        let midY: CGFloat = 32

        Path { path in
            switch method {
            case .single:
                path.move(to: CGPoint(x: startX, y: midY))
                path.addLine(to: CGPoint(x: endX, y: midY))
            case .loop2:
                path.move(to: CGPoint(x: startX, y: midY - 12))
                path.addLine(to: CGPoint(x: endX - 8, y: midY - 12))
                path.move(to: CGPoint(x: startX, y: midY + 12))
                path.addLine(to: CGPoint(x: endX - 8, y: midY + 12))
                path.move(to: CGPoint(x: endX - 8, y: midY - 12))
                path.addLine(to: CGPoint(x: endX - 8, y: midY + 12))
            case .loop3:
                path.move(to: CGPoint(x: startX, y: midY - 18))
                path.addLine(to: CGPoint(x: endX - 8, y: midY - 18))
                path.move(to: CGPoint(x: startX, y: midY))
                path.addLine(to: CGPoint(x: endX - 8, y: midY))
                path.move(to: CGPoint(x: startX, y: midY + 18))
                path.addLine(to: CGPoint(x: endX - 8, y: midY + 18))
                path.move(to: CGPoint(x: endX - 8, y: midY - 22))
                path.addLine(to: CGPoint(x: endX - 8, y: midY + 22))
            }
        }
        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

        if method == .single {
            Circle()
                .fill(Theme.accent)
                .frame(width: 10, height: 10)
                .position(x: endX, y: midY)
        }
    }
}
