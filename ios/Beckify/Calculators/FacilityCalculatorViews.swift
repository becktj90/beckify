import SwiftUI
import BeckifyMath

// MARK: - Transformer tap changer

struct TapChangerView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.tapChanger, "measured", default: "456") private var measured
    @StoredInput(.tapChanger, "currentTap", default: "0") private var currentTap
    @StoredInput(.tapChanger, "jobName", default: "Tap changer") private var jobName
    @State private var session = ExplicitCalculationState<TapChangerResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let tapChoices = TapChanger.defaultTapPercents
    private var inputFingerprint: String { "\(measured)|\(currentTap)" }

    /// Snap a persisted tap string onto a tagged menu Double and rewrite storage as `%g`
    /// so values like `"0.0"` never leave the Picker in an unmatched selection state.
    private func canonicalizeCurrentTap() {
        let value = currentTap.parsedDouble ?? 0
        let matched = tapChoices.first { abs($0 - value) < 1e-9 } ?? 0
        let canonical = String(format: "%g", matched)
        if currentTap != canonical {
            currentTap = canonical
        }
    }

    private var menuTapPercent: Double {
        let value = currentTap.parsedDouble ?? 0
        return tapChoices.first { abs($0 - value) < 1e-9 } ?? 0
    }

    var body: some View {
        ToolScaffold(
            toolID: .tapChanger,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .tapChanger,
                symbolic: "V_sec = V_pri / (N × (1 + tap/100))",
                substituted: substituted,
                meaning: "Default model is a 23 kV / 480 V DETC. Measured secondary and the present tap imply primary voltage; each tap is ranked by how close its expected secondary is to 480 V. Design aid — confirm nameplate taps.",
                citation: "Transformer nameplate DETC / off-load tap schedule."
            )

            NumberField(title: "Measured secondary", unit: "V", text: $measured, fieldID: "measured", onSubmit: calculate)
            MenuField(
                title: "Current tap",
                selection: Binding(
                    get: { menuTapPercent },
                    set: { currentTap = String(format: "%g", $0) }
                ),
                options: tapChoices
            ) { value in
                if value > 0 { return "+\(Format.number(value, digits: 1))%" }
                if value < 0 { return "\(Format.number(value, digits: 1))%" }
                return "0% (Nominal)"
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: {
                    measured = ""
                    currentTap = String(format: "%g", 0.0)
                    session.reset()
                },
                onExample: {
                    measured = "456"
                    currentTap = String(format: "%g", 0.0)
                    session.prepareForNewInputs()
                },
                exampleTitle: "456 V on 0% tap → recommend −5%"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Implied primary", value: Format.volts(r.impliedPrimaryVolts), emphasis: true)
                    ResultRow(label: "Nominal ratio", value: Format.number(r.nominalRatio, digits: 4))
                    ResultRow(
                        label: "Recommended tap",
                        value: r.positions.first(where: \.isRecommended)?.label ?? "—",
                        emphasis: true,
                        tone: Theme.good
                    )
                    ResultRow(label: "Expected at rec. tap", value: Format.volts(r.recommendedSecondaryVolts), tone: Theme.good)
                }
                .opacity(session.isStale ? 0.72 : 1)

                ResultCard(title: "Expected secondary by tap") {
                    ForEach(r.positions, id: \.tapPercent) { row in
                        ResultRow(
                            label: row.label + (row.isCurrent ? " · current" : "") + (row.isRecommended ? " · best" : ""),
                            value: "\(Format.volts(row.expectedSecondaryVolts))  (err \(Format.volts(row.errorVolts)))",
                            tone: row.isRecommended ? Theme.good : Theme.foreground
                        )
                    }
                }
                .opacity(session.isStale ? 0.72 : 1)

                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .tapChanger,
                        inputs: ["Vsec": measured, "tap": currentTap],
                        outputs: [
                            "recTap": r.positions.first(where: \.isRecommended)?.label ?? "",
                            "Vpri": Format.volts(r.impliedPrimaryVolts),
                        ]
                    ))
                }
            }
        }
        .onAppear { canonicalizeCurrentTap() }
        .onChange(of: inputFingerprint) { _, _ in session.markInputsChanged() }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func calculate() {
        canonicalizeCurrentTap()
        session.calculate {
            try TapChanger.solve(
                measuredSecondaryVolts: measured.parsedDouble ?? .nan,
                currentTapPercent: menuTapPercent
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion { successTick += 1 }
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.formula)  →  recommend \(r.positions.first(where: \.isRecommended)?.label ?? "—")"
    }

    private var sticky: String? {
        guard let r = session.displayedResult,
              let rec = r.positions.first(where: \.isRecommended) else { return nil }
        return "\(rec.label)  ·  \(Format.volts(r.recommendedSecondaryVolts))"
    }

    private var copyText: String? { sticky }
}

// MARK: - Harmonics THD

struct HarmonicsTHDView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.harmonicsTHD, "i1", default: "100") private var i1
    @StoredInput(.harmonicsTHD, "i2", default: "") private var i2
    @StoredInput(.harmonicsTHD, "i3", default: "33.3") private var i3
    @StoredInput(.harmonicsTHD, "i5", default: "20") private var i5
    @StoredInput(.harmonicsTHD, "i7", default: "") private var i7
    @StoredInput(.harmonicsTHD, "i9", default: "") private var i9
    @StoredInput(.harmonicsTHD, "i11", default: "") private var i11
    @StoredInput(.harmonicsTHD, "i13", default: "") private var i13
    @StoredInput(.harmonicsTHD, "jobName", default: "Harmonics THD") private var jobName
    @State private var session = ExplicitCalculationState<HarmonicsTHDResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String { "\(i1)|\(i2)|\(i3)|\(i5)|\(i7)|\(i9)|\(i11)|\(i13)" }

    var body: some View {
        ToolScaffold(
            toolID: .harmonicsTHD,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .harmonicsTHD,
                symbolic: "%THD = √(Σ Iₙ²) / I₁ × 100",
                substituted: substituted,
                meaning: "Leave unused harmonic orders blank. Status bands are engineering discussion guidance aligned with common IEEE 519 talk — not a PCC compliance study.",
                citation: "IEEE 519 discussion bands (informational). Design aid."
            )

            NumberField(title: "Fundamental I₁", unit: "A", text: $i1, fieldID: "i1", onSubmit: calculate)
            NumberField(title: "I₂", unit: "A", text: $i2, optional: true, fieldID: "i2", onSubmit: calculate)
            NumberField(title: "I₃", unit: "A", text: $i3, optional: true, fieldID: "i3", onSubmit: calculate)
            NumberField(title: "I₅", unit: "A", text: $i5, optional: true, fieldID: "i5", onSubmit: calculate)
            NumberField(title: "I₇", unit: "A", text: $i7, optional: true, fieldID: "i7", onSubmit: calculate)
            NumberField(title: "I₉", unit: "A", text: $i9, optional: true, fieldID: "i9", onSubmit: calculate)
            NumberField(title: "I₁₁", unit: "A", text: $i11, optional: true, fieldID: "i11", onSubmit: calculate)
            NumberField(title: "I₁₃", unit: "A", text: $i13, optional: true, fieldID: "i13", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    i1 = "100"; i2 = ""; i3 = "33.3"; i5 = "20"
                    i7 = ""; i9 = ""; i11 = ""; i13 = ""
                    session.prepareForNewInputs()
                },
                exampleTitle: "100 A fund., 33.3 A 3rd, 20 A 5th"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: copyText) {
                    ResultRow(label: "%THD", value: Format.percent(r.thdPercent), emphasis: true, tone: r.thdPercent < 5 ? Theme.good : (r.thdPercent < 15 ? Theme.warn : Theme.bad))
                    ResultRow(label: "Status", value: r.status, tone: Theme.muted)
                    ResultRow(label: "Harmonic RMS", value: Format.amps(r.harmonicRMS))
                    if let order = r.dominantOrder {
                        ResultRow(label: "Dominant", value: "\(order)th · \(Format.amps(r.dominantAmps))", tone: Theme.copper)
                    }
                    ResultRow(label: "Mitigation hint", value: r.mitigationHint, tone: Theme.muted)
                }
                .opacity(session.isStale ? 0.72 : 1)

                Text("Informational note — not a stamped IEEE 519 evaluation.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)

                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .harmonicsTHD,
                        inputs: ["I1": i1, "I3": i3, "I5": i5],
                        outputs: ["THD": Format.percent(r.thdPercent), "status": r.status]
                    ))
                }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in session.markInputsChanged() }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func calculate() {
        session.calculate {
            var parts: [HarmonicComponent] = []
            for (order, text) in [(2, i2), (3, i3), (5, i5), (7, i7), (9, i9), (11, i11), (13, i13)] {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                guard let amps = trimmed.parsedDouble else {
                    throw CalcError.outOfRange("I\(order.ordinalSuffix) is not a number.")
                }
                parts.append(HarmonicComponent(order: order, amps: amps))
            }
            return try HarmonicsTHD.calculate(
                fundamentalAmps: i1.parsedDouble ?? .nan,
                harmonics: parts
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion { successTick += 1 }
    }

    private func reset() {
        i1 = ""; i2 = ""; i3 = ""; i5 = ""; i7 = ""; i9 = ""; i11 = ""; i13 = ""
        session.reset()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.formula)  →  \(Format.percent(r.thdPercent))"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.percent(r.thdPercent)) THD"
    }

    private var copyText: String? { sticky }
}

private extension Int {
    var ordinalSuffix: String {
        switch self {
        case 2: return "₂"
        case 3: return "₃"
        case 5: return "₅"
        case 7: return "₇"
        case 9: return "₉"
        case 11: return "₁₁"
        case 13: return "₁₃"
        default: return "\(self)"
        }
    }
}

// MARK: - UPS sizing

struct UPSSizingView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.upsSizing, "kw", default: "10") private var kw
    @StoredInput(.upsSizing, "pf", default: "90") private var pf
    @StoredInput(.upsSizing, "runtime", default: "15") private var runtime
    @StoredInput(.upsSizing, "eff", default: "92") private var eff
    @StoredInput(.upsSizing, "dcv", default: "48") private var dcv
    @StoredInput(.upsSizing, "jobName", default: "UPS sizing") private var jobName
    @State private var session = ExplicitCalculationState<UPSSizingResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String { "\(kw)|\(pf)|\(runtime)|\(eff)|\(dcv)" }

    var body: some View {
        ToolScaffold(
            toolID: .upsSizing,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .upsSizing,
                symbolic: "kVA = kW/PF    design = 1.25·kVA    Ah = Wh/V_dc",
                substituted: substituted,
                meaning: "Quick on-site UPS / battery estimate. The 1.25 design multiplier is a Beckify design preference for headroom — not a manufacturer sizing letter. Generator / hybrid / BESS peak-shave stay on the website for now.",
                citation: "Engineering approximation / design preference. Confirm with UPS vendor curves."
            )

            NumberField(title: "Load", unit: "kW", text: $kw, fieldID: "kw", onSubmit: calculate)
            NumberField(title: "Power factor", unit: "%", text: $pf, fieldID: "pf", onSubmit: calculate)
            NumberField(title: "Runtime", unit: "min", text: $runtime, fieldID: "runtime", onSubmit: calculate)
            NumberField(title: "Efficiency", unit: "%", text: $eff, fieldID: "eff", onSubmit: calculate)
            NumberField(title: "DC bus", unit: "V", text: $dcv, fieldID: "dcv", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: {
                    kw = ""; pf = "90"; runtime = ""; eff = "92"; dcv = "48"
                    session.reset()
                },
                onExample: {
                    kw = "10"; pf = "90"; runtime = "15"; eff = "92"; dcv = "48"
                    session.prepareForNewInputs()
                },
                exampleTitle: "10 kW, PF 0.90, 15 min, 48 V"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Load kVA", value: "\(Format.number(r.loadKVA, digits: 2)) kVA")
                    ResultRow(label: "Design kVA (×1.25)", value: "\(Format.number(r.designKVA, digits: 2)) kVA", emphasis: true, tone: Theme.copper)
                    ResultRow(label: "Recommended UPS", value: "\(Format.number(r.recommendedKVA, digits: 1)) kVA", emphasis: true, tone: Theme.good)
                    ResultRow(label: "Battery energy", value: "\(Format.number(r.batteryWattHours / 1000, digits: 3)) kWh")
                    ResultRow(label: "Battery Ah", value: "\(Format.number(r.batteryAmpHours, digits: 1)) Ah @ \(Format.number(r.dcBusVolts, digits: 0)) V")
                }
                .opacity(session.isStale ? 0.72 : 1)

                Text("Design preference — ×1.25 headroom is not a code requirement.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)

                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .upsSizing,
                        inputs: ["kW": kw, "PF%": pf, "min": runtime, "eff%": eff, "Vdc": dcv],
                        outputs: [
                            "UPS": "\(Format.number(r.recommendedKVA, digits: 1)) kVA",
                            "Ah": Format.number(r.batteryAmpHours, digits: 1),
                        ]
                    ))
                }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in session.markInputsChanged() }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func calculate() {
        session.calculate {
            try UPSSizing.size(
                loadKW: kw.parsedDouble ?? .nan,
                powerFactor: (pf.parsedDouble ?? .nan) / 100,
                runtimeMinutes: runtime.parsedDouble ?? .nan,
                efficiency: (eff.parsedDouble ?? .nan) / 100,
                dcBusVolts: dcv.parsedDouble ?? .nan
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion { successTick += 1 }
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.formula)  →  \(Format.number(r.recommendedKVA, digits: 1)) kVA UPS"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.number(r.recommendedKVA, digits: 1)) kVA  ·  \(Format.number(r.batteryAmpHours, digits: 0)) Ah"
    }

    private var copyText: String? { sticky }
}

// MARK: - Motor nameplate analyzer

struct MotorNameplateView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.motorNameplate, "fla", default: "27") private var fla
    @StoredInput(.motorNameplate, "hp", default: "10") private var hp
    @StoredInput(.motorNameplate, "volts", default: "460") private var volts
    @StoredInput(.motorNameplate, "sf", default: "1.15") private var sf
    @StoredInput(.motorNameplate, "rise", default: "") private var rise
    @StoredInput(.motorNameplate, "code", default: "G") private var code
    @StoredInput(.motorNameplate, "phases", default: "3") private var phases
    @StoredInput(.motorNameplate, "motorType", default: "sc-bde") private var motorType
    @StoredInput(.motorNameplate, "device", default: "inv") private var device
    @StoredInput(.motorNameplate, "jobName", default: "Motor nameplate") private var jobName
    @State private var session = ExplicitCalculationState<MotorNameplateResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(fla)|\(hp)|\(volts)|\(sf)|\(rise)|\(code)|\(phases)|\(motorType)|\(device)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .motorNameplate,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .motorNameplate,
                symbolic: "OL ≤ %×FLA; SCPD ≤ T430.52 %×FLA; cond ≥ 125%×FLA",
                substituted: substituted,
                meaning: "Enter reviewed nameplate values (OCR can fill fields later). Uses NEC 430.32, Table 430.52, and 430.22. Design aid — confirm with the nameplate and AHJ.",
                citation: "NEC 430.32, Table 430.52, 430.22, 430.7(B) / NEMA MG-1."
            )

            NumberField(title: "Nameplate FLA", unit: "A", text: $fla, fieldID: "fla", onSubmit: calculate)
            NumberField(title: "Horsepower", unit: "HP", text: $hp, optional: true, fieldID: "hp", onSubmit: calculate)
            NumberField(title: "Voltage", unit: "V", text: $volts, optional: true, fieldID: "volts", onSubmit: calculate)
            NumberField(title: "Service factor", unit: "", text: $sf, optional: true, fieldID: "sf", onSubmit: calculate)
            NumberField(title: "Temp rise", unit: "°C", text: $rise, optional: true, fieldID: "rise", onSubmit: calculate)
            TextInputField(title: "Code letter", text: $code, placeholder: "G", optional: true, autocapitalization: .characters, fieldID: "code", onSubmit: calculate)
            MenuField(title: "Phases", selection: $phases, options: ["1", "3"]) { $0 == "1" ? "1-phase" : "3-phase" }
            MenuField(title: "Motor type", selection: $motorType, options: MotorNameplateType.allCases.map(\.rawValue)) { raw in
                MotorNameplateType(rawValue: raw)?.label ?? raw
            }
            MenuField(title: "SCPD device", selection: $device, options: MotorSCPDDevice.allCases.map(\.rawValue)) { raw in
                MotorSCPDDevice(rawValue: raw)?.label ?? raw
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: {
                    fla = ""; hp = ""; volts = ""; sf = ""; rise = ""; code = ""
                    phases = "3"; motorType = "sc-bde"; device = "inv"
                    session.reset()
                },
                onExample: {
                    fla = "27"; hp = "10"; volts = "460"; sf = "1.15"; rise = ""
                    code = "G"; phases = "3"; motorType = "sc-bde"; device = "inv"
                    session.prepareForNewInputs()
                },
                exampleTitle: "10 HP, 460 V, 27 A, SF 1.15, code G"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Overload max", value: "\(Format.number(r.overload.amps, digits: 1)) A (\(Format.number(r.overload.percent, digits: 0))%)", emphasis: true, tone: Theme.good)
                    ResultRow(label: "OL article", value: "\(r.overload.article) — \(r.overload.reason)", tone: Theme.muted)
                    ResultRow(label: "OL next higher", value: "\(Format.number(r.overloadNext.amps, digits: 1)) A (\(Format.number(r.overloadNext.percent, digits: 0))%)")
                    ResultRow(label: "SCPD max", value: "\(Format.number(r.scpd.rawAmps, digits: 1)) A → \(r.scpd.nextStandardAmps.map(String.init) ?? "—") A", emphasis: true, tone: Theme.copper)
                    ResultRow(label: "Conductor ≥", value: "\(Format.amps(r.conductorRequiredAmps))" + (r.suggestedConductorSize.map { " → \($0) AWG/kcmil" } ?? ""))
                }
                .opacity(session.isStale ? 0.72 : 1)

                if let lra = r.lockedRotor {
                    ResultCard(title: "Locked-rotor (code letter)") {
                        ResultRow(label: "Letter \(lra.letter)", value: "\(Format.number(lra.kvaPerHPMin, digits: 2))–\(lra.kvaPerHPMax.map { Format.number($0, digits: 2) } ?? "∞") kVA/HP")
                        if let amin = lra.ampsMin {
                            ResultRow(label: "Est. LRA", value: "\(Format.number(amin, digits: 0))–\(lra.ampsMax.map { Format.number($0, digits: 0) } ?? "∞") A")
                        }
                        Text(lra.note).font(Theme.TypeRole.help).foregroundStyle(Theme.muted)
                    }
                    .opacity(session.isStale ? 0.72 : 1)
                }

                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .motorNameplate,
                        inputs: ["FLA": fla, "HP": hp, "V": volts],
                        outputs: [
                            "OL": Format.number(r.overload.amps, digits: 1),
                            "SCPD": r.scpd.nextStandardAmps.map(String.init) ?? "",
                        ]
                    ))
                }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in session.markInputsChanged() }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func calculate() {
        session.calculate {
            try MotorNameplate.analyze(
                fla: fla.parsedDouble ?? .nan,
                phases: Int(phases) ?? 3,
                horsepower: hp.parsedDouble,
                volts: volts.parsedDouble,
                serviceFactor: sf.parsedDouble,
                temperatureRiseC: rise.parsedDouble,
                motorType: MotorNameplateType(rawValue: motorType) ?? .squirrelCageOther,
                device: MotorSCPDDevice(rawValue: device) ?? .inverseTimeBreaker,
                codeLetter: code
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion { successTick += 1 }
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.formula) → OL \(Format.number(r.overload.amps, digits: 1)) A"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "OL \(Format.number(r.overload.amps, digits: 1)) A · SCPD \(r.scpd.nextStandardAmps.map { "\($0) A" } ?? "—")"
    }

    private var copyText: String? { sticky }
}

// MARK: - Heater design wizard

struct HeaterDesignView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.heaterDesign, "watts", default: "9000") private var watts
    @StoredInput(.heaterDesign, "volts", default: "480") private var volts
    @StoredInput(.heaterDesign, "phase", default: "3ph") private var phase
    @StoredInput(.heaterDesign, "conn", default: "wye") private var conn
    @StoredInput(.heaterDesign, "awg", default: "18") private var awg
    @StoredInput(.heaterDesign, "rho", default: "1.09") private var rho
    @StoredInput(.heaterDesign, "jobName", default: "Heater design") private var jobName
    @State private var session = ExplicitCalculationState<HeaterElectricalResult>()
    @State private var elementSession = ExplicitCalculationState<HeaterElementResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String { "\(watts)|\(volts)|\(phase)|\(conn)|\(awg)|\(rho)" }

    var body: some View {
        ToolScaffold(
            toolID: .heaterDesign,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale || elementSession.isStale
        ) {
            ShowWorkCard(
                toolID: .heaterDesign,
                symbolic: "I = P/(√3·V); R_leg from PF=1; ℓ = R/(ρ/A)",
                substituted: substituted,
                meaning: "Electrical sizing for a balanced resistive heater, then a first-cut resistance-wire length from alloy resistivity. Confirm alloy data with the supplier before fabricating.",
                citation: "AC circuit theory + AWG geometry. Design aid."
            )

            NumberField(title: "Heater power", unit: "W", text: $watts, fieldID: "watts", onSubmit: calculate)
            NumberField(title: "Line voltage", unit: "V", text: $volts, fieldID: "volts", onSubmit: calculate)
            MenuField(title: "Phase", selection: $phase, options: HeaterPhase.allCases.map(\.rawValue)) { HeaterPhase(rawValue: $0)?.label ?? $0 }
            MenuField(title: "Connection", selection: $conn, options: HeaterConnection.allCases.map(\.rawValue)) { HeaterConnection(rawValue: $0)?.label ?? $0 }
            NumberField(title: "Element AWG", unit: "", text: $awg, fieldID: "awg", onSubmit: calculate)
            NumberField(title: "Resistivity", unit: "Ω·mm²/m", text: $rho, fieldID: "rho", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: {
                    watts = ""; volts = ""; phase = "3ph"; conn = "wye"; awg = "18"; rho = "1.09"
                    session.reset(); elementSession.reset()
                },
                onExample: {
                    watts = "9000"; volts = "480"; phase = "3ph"; conn = "wye"; awg = "18"; rho = "1.09"
                    session.prepareForNewInputs(); elementSession.prepareForNewInputs()
                },
                exampleTitle: "9 kW, 480 V 3Ø wye, Nichrome 18 AWG"
            )

            if let error = session.lastValidationError ?? session.error ?? elementSession.lastValidationError ?? elementSession.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Line current", value: Format.amps(r.lineAmps), emphasis: true)
                    ResultRow(label: "Phase voltage", value: Format.volts(r.phaseVolts))
                    ResultRow(label: "Leg resistance", value: "\(Format.number(r.legResistanceOhms, digits: 2)) Ω")
                    ResultRow(label: "Design current (×1.25)", value: Format.amps(r.designAmps), tone: Theme.copper)
                    if let size = r.suggestedConductorSize {
                        ResultRow(label: "Suggested conductor", value: "\(size) Cu 75°C", tone: Theme.good)
                    }
                    if let ocpd = r.suggestedOCPD {
                        ResultRow(label: "Suggested OCPD", value: "\(ocpd) A")
                    }
                }
                .opacity(session.isStale ? 0.72 : 1)
            }

            if let e = elementSession.displayedResult {
                ResultCard(title: "Element wire estimate") {
                    ResultRow(label: "Wire length", value: "\(Format.number(e.lengthFeet, digits: 1)) ft (\(Format.number(e.lengthMeters, digits: 2)) m)", emphasis: true)
                    ResultRow(label: "Diameter", value: "\(Format.number(e.diameterMm, digits: 3)) mm")
                    ResultRow(label: "Element current", value: Format.amps(e.currentAmps))
                    ResultRow(label: "Surface density", value: "\(Format.number(e.surfaceWPerCm2, digits: 2)) W/cm²")
                }
                .opacity(elementSession.isStale ? 0.72 : 1)
            }

            if let r = session.displayedResult {
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .heaterDesign,
                        inputs: ["W": watts, "V": volts, "ph": phase],
                        outputs: ["I": Format.amps(r.lineAmps), "Rleg": Format.number(r.legResistanceOhms, digits: 2)]
                    ))
                }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
            elementSession.markInputsChanged()
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func calculate() {
        session.calculate {
            try HeaterDesign.electrical(
                totalWatts: watts.parsedDouble ?? .nan,
                lineVolts: volts.parsedDouble ?? .nan,
                phase: HeaterPhase(rawValue: phase) ?? .three,
                connection: HeaterConnection(rawValue: conn) ?? .wye
            )
        }
        if let elec = session.displayedResult {
            elementSession.calculate {
                guard let awgVal = awg.parsedDouble, awgVal.isFinite else {
                    throw CalcError.missing("Element AWG")
                }
                return try HeaterDesign.element(
                    targetResistanceOhms: elec.legResistanceOhms,
                    targetWatts: elec.totalWatts / (elec.phase == .three ? 3 : 1),
                    resistivityOhmMm2PerM: rho.parsedDouble ?? .nan,
                    awg: Int(awgVal.rounded())
                )
            }
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion { successTick += 1 }
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.formula) → \(Format.amps(r.lineAmps))"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.amps(r.lineAmps)) · \(Format.number(r.legResistanceOhms, digits: 1)) Ω/leg"
    }

    private var copyText: String? { sticky }
}

// MARK: - EMP / EMC shielding

struct EMPEMCView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.empEmc, "mode", default: "skin") private var mode
    @StoredInput(.empEmc, "mat", default: "cu") private var mat
    @StoredInput(.empEmc, "thick", default: "1") private var thick
    @StoredInput(.empEmc, "freq", default: "1") private var freq
    @StoredInput(.empEmc, "freqUnit", default: "MHz") private var freqUnit
    @StoredInput(.empEmc, "area", default: "0.01") private var area
    @StoredInput(.empEmc, "dbdt", default: "100") private var dbdt
    @StoredInput(.empEmc, "aperture", default: "10") private var aperture
    @StoredInput(.empEmc, "jobName", default: "EMP/EMC") private var jobName
    @State private var skinSession = ExplicitCalculationState<SkinShieldResult>()
    @State private var loopSession = ExplicitCalculationState<FaradayLoopResult>()
    @State private var apertureSession = ExplicitCalculationState<ApertureLeakResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String { "\(mode)|\(mat)|\(thick)|\(freq)|\(freqUnit)|\(area)|\(dbdt)|\(aperture)" }

    var body: some View {
        ToolScaffold(
            toolID: .empEmc,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: skinSession.isStale || loopSession.isStale || apertureSession.isStale
        ) {
            ShowWorkCard(
                toolID: .empEmc,
                symbolic: "δ = 1/√(πfμσ); V = N·A·|dB/dt|; SE ≈ 20·log(λ/2ℓ)",
                substituted: substituted,
                meaning: "Protection-side educational estimates: sheet shielding, Faraday-loop voltage, and aperture leakage. Not a pulse-source or weapon design tool.",
                citation: "Schelkunoff / Ott-style rules of thumb. Design aid."
            )

            MenuField(title: "Mode", selection: $mode, options: ["skin", "loop", "aperture"]) {
                switch $0 {
                case "loop": return "Faraday loop"
                case "aperture": return "Aperture leakage"
                default: return "Skin depth / sheet SE"
                }
            }

            if mode == "skin" {
                MenuField(title: "Material", selection: $mat, options: EMPEMCMaterial.all.map(\.id)) { id in
                    EMPEMCMaterial.all.first { $0.id == id }?.name ?? id
                }
                NumberField(title: "Thickness", unit: "mm", text: $thick, fieldID: "thick", onSubmit: calculate)
                NumberField(title: "Frequency", unit: freqUnit, text: $freq, fieldID: "freq", onSubmit: calculate)
                MenuField(title: "Freq unit", selection: $freqUnit, options: ["Hz", "kHz", "MHz", "GHz"]) { $0 }
            } else if mode == "loop" {
                NumberField(title: "Loop area", unit: "m²", text: $area, fieldID: "area", onSubmit: calculate)
                NumberField(title: "dB/dt", unit: "T/s", text: $dbdt, fieldID: "dbdt", onSubmit: calculate)
            } else {
                NumberField(title: "Longest aperture", unit: "mm", text: $aperture, fieldID: "aperture", onSubmit: calculate)
                NumberField(title: "Frequency", unit: freqUnit, text: $freq, fieldID: "freq", onSubmit: calculate)
                MenuField(title: "Freq unit", selection: $freqUnit, options: ["Hz", "kHz", "MHz", "GHz"]) { $0 }
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: {
                    mode = "skin"; mat = "cu"; thick = ""; freq = ""; area = ""; dbdt = ""; aperture = ""
                    skinSession.reset(); loopSession.reset(); apertureSession.reset()
                },
                onExample: {
                    mode = "skin"; mat = "cu"; thick = "1"; freq = "1"; freqUnit = "MHz"
                    sessionPrepare()
                },
                exampleTitle: "1 mm copper @ 1 MHz"
            )

            if let error = skinSession.lastValidationError ?? skinSession.error
                ?? loopSession.lastValidationError ?? loopSession.error
                ?? apertureSession.lastValidationError ?? apertureSession.error {
                ErrorText(message: error.message)
            }

            if mode == "skin", let r = skinSession.displayedResult {
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Skin depth δ", value: formatLength(r.skinDepthM), emphasis: true)
                    ResultRow(label: "t / δ", value: Format.number(r.tOverDelta, digits: 3))
                    ResultRow(label: "Absorption A", value: "\(Format.number(r.absorptionDB, digits: 1)) dB")
                    ResultRow(label: "Reflection R", value: "\(Format.number(r.reflectionDB, digits: 1)) dB")
                    ResultRow(label: "Sheet SE", value: "\(Format.number(r.sheetSEDB, digits: 1)) dB", emphasis: true, tone: Theme.good)
                }
                .opacity(skinSession.isStale ? 0.72 : 1)
            }

            if mode == "loop", let r = loopSession.displayedResult {
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Induced voltage", value: Format.volts(r.inducedVolts), emphasis: true, tone: Theme.copper)
                }
                .opacity(loopSession.isStale ? 0.72 : 1)
            }

            if mode == "aperture", let r = apertureSession.displayedResult {
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Aperture SE", value: "\(Format.number(r.seDB, digits: 1)) dB", emphasis: true)
                    ResultRow(label: "Regime", value: r.regime, tone: Theme.muted)
                }
                .opacity(apertureSession.isStale ? 0.72 : 1)
            }

            Text("Educational shielding estimates — not an IEEE 299 / MIL-STD chamber result.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)

            SaveJobBar(jobName: $jobName, canSave: !(skinSession.isStale || loopSession.isStale || apertureSession.isStale)) {
                jobs.save(SavedJob(name: jobName, toolID: .empEmc, inputs: ["mode": mode], outputs: ["note": sticky ?? ""]))
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            skinSession.markInputsChanged()
            loopSession.markInputsChanged()
            apertureSession.markInputsChanged()
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func sessionPrepare() {
        skinSession.prepareForNewInputs()
        loopSession.prepareForNewInputs()
        apertureSession.prepareForNewInputs()
    }

    private func freqHz() -> Double {
        let f = freq.parsedDouble ?? .nan
        switch freqUnit {
        case "kHz": return f * 1e3
        case "MHz": return f * 1e6
        case "GHz": return f * 1e9
        default: return f
        }
    }

    private func calculate() {
        switch mode {
        case "loop":
            loopSession.calculate {
                try EMPEMC.faradayLoop(turns: 1, areaM2: area.parsedDouble ?? .nan, dBdtTeslaPerS: dbdt.parsedDouble ?? .nan)
            }
        case "aperture":
            apertureSession.calculate {
                try EMPEMC.apertureSE(
                    longestDimensionM: (aperture.parsedDouble ?? .nan) / 1000,
                    frequencyHz: freqHz()
                )
            }
        default:
            let material = EMPEMCMaterial.all.first { $0.id == mat } ?? .copper
            skinSession.calculate {
                try EMPEMC.shieldEstimate(
                    material: material,
                    thicknessM: (thick.parsedDouble ?? .nan) / 1000,
                    frequencyHz: freqHz()
                )
            }
        }
        if sticky != nil, !reduceMotion { successTick += 1 }
    }

    private func formatLength(_ m: Double) -> String {
        if m >= 1e-2 { return "\(Format.number(m * 100, digits: 2)) cm" }
        if m >= 1e-6 { return "\(Format.number(m * 1e6, digits: 2)) µm" }
        return "\(Format.number(m * 1e9, digits: 2)) nm"
    }

    private var substituted: String? {
        if let r = skinSession.displayedResult { return "\(r.formula) → SE \(Format.number(r.sheetSEDB, digits: 1)) dB" }
        if let r = loopSession.displayedResult { return "\(r.formula) → \(Format.volts(r.inducedVolts))" }
        if let r = apertureSession.displayedResult { return "\(r.formula) → \(Format.number(r.seDB, digits: 1)) dB" }
        return nil
    }

    private var sticky: String? {
        if mode == "skin", let r = skinSession.displayedResult { return "SE \(Format.number(r.sheetSEDB, digits: 1)) dB" }
        if mode == "loop", let r = loopSession.displayedResult { return Format.volts(r.inducedVolts) }
        if mode == "aperture", let r = apertureSession.displayedResult { return "\(Format.number(r.seDB, digits: 1)) dB SE" }
        return nil
    }

    private var copyText: String? { sticky }
}

// MARK: - NEC circuit calculator

struct NECCircuitView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.necCircuit, "fla", default: "") private var fla
    @StoredInput(.necCircuit, "kw", default: "15") private var kw
    @StoredInput(.necCircuit, "volts", default: "480") private var volts
    @StoredInput(.necCircuit, "phases", default: "3") private var phases
    @StoredInput(.necCircuit, "pf", default: "90") private var pf
    @StoredInput(.necCircuit, "dist", default: "150") private var dist
    @StoredInput(.necCircuit, "ambient", default: "30") private var ambient
    @StoredInput(.necCircuit, "loadType", default: "continuous") private var loadType
    @StoredInput(.necCircuit, "jobName", default: "NEC circuit") private var jobName
    @State private var session = ExplicitCalculationState<NECCircuitResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String { "\(fla)|\(kw)|\(volts)|\(phases)|\(pf)|\(dist)|\(ambient)|\(loadType)" }

    var body: some View {
        ToolScaffold(
            toolID: .necCircuit,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .necCircuit,
                symbolic: "I_des = FLA×mult; ampacity ≥ I_des; VD = φ·K·I·L/CM",
                substituted: substituted,
                meaning: "One-shot branch/feeder sketch: design current, derated ampacity pick, voltage drop, and OCPD. Leave FLA blank to compute from kW.",
                citation: "NEC 210.19 / 215.2 continuous, Table 310.16, Ch.9 Table 8 (CM) and Table 9 (K-factor VD). Design aid."
            )

            NumberField(title: "FLA (optional)", unit: "A", text: $fla, optional: true, fieldID: "fla", onSubmit: calculate)
            NumberField(title: "Load", unit: "kW", text: $kw, optional: true, fieldID: "kw", onSubmit: calculate)
            NumberField(title: "Voltage", unit: "V", text: $volts, fieldID: "volts", onSubmit: calculate)
            MenuField(title: "Phases", selection: $phases, options: ["1", "3"]) { $0 == "1" ? "1-phase" : "3-phase" }
            NumberField(title: "Power factor", unit: "%", text: $pf, fieldID: "pf", onSubmit: calculate)
            NumberField(title: "One-way distance", unit: "ft", text: $dist, fieldID: "dist", onSubmit: calculate)
            NumberField(title: "Ambient", unit: "°C", text: $ambient, fieldID: "ambient", onSubmit: calculate)
            MenuField(title: "Load type", selection: $loadType, options: NECCircuitLoadType.allCases.map(\.rawValue)) {
                NECCircuitLoadType(rawValue: $0)?.label ?? $0
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: {
                    fla = ""; kw = ""; volts = "480"; phases = "3"; pf = "90"; dist = ""; ambient = "30"; loadType = "continuous"
                    session.reset()
                },
                onExample: {
                    fla = ""; kw = "15"; volts = "480"; phases = "3"; pf = "90"; dist = "150"; ambient = "30"; loadType = "continuous"
                    session.prepareForNewInputs()
                },
                exampleTitle: "15 kW, 480 V 3Ø, 150 ft, continuous"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: copyText) {
                    ResultRow(label: "FLA", value: Format.amps(r.fla))
                    ResultRow(label: "Design current", value: Format.amps(r.designAmps), emphasis: true)
                    ResultRow(label: "Conductor", value: "\(r.conductorSize) Cu · \(Format.amps(r.deratedAmpacity)) usable", tone: Theme.good)
                    ResultRow(label: "Voltage drop", value: "\(Format.volts(r.vdVolts)) (\(Format.percent(r.vdPercent)))", tone: r.vdPercent > 3 ? Theme.warn : Theme.foreground)
                    ResultRow(label: "OCPD", value: r.ocpdAmps.map { "\($0) A" } ?? "—", emphasis: true, tone: Theme.copper)
                }
                .opacity(session.isStale ? 0.72 : 1)

                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .necCircuit,
                        inputs: ["kW": kw, "V": volts, "ft": dist],
                        outputs: ["size": r.conductorSize, "OCPD": r.ocpdAmps.map(String.init) ?? ""]
                    ))
                }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in session.markInputsChanged() }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func calculate() {
        session.calculate {
            try NECCircuitCalc.solve(
                fla: fla.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : fla.parsedDouble,
                loadKW: kw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : kw.parsedDouble,
                voltage: volts.parsedDouble ?? .nan,
                phases: Int(phases) ?? 3,
                powerFactor: (pf.parsedDouble ?? .nan) / 100,
                loadType: NECCircuitLoadType(rawValue: loadType) ?? .continuous,
                oneWayFeet: dist.parsedDouble ?? .nan,
                ambientC: ambient.parsedDouble ?? 30
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion { successTick += 1 }
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.formula) → \(r.conductorSize)"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.conductorSize) · \(r.ocpdAmps.map { "\($0) A" } ?? "—") · \(Format.percent(r.vdPercent)) VD"
    }

    private var copyText: String? { sticky }
}

// MARK: - Load calculation worksheet

struct LoadWorksheetView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.loadWorksheet, "occ", default: "other") private var occ
    @StoredInput(.loadWorksheet, "volts", default: "208") private var volts
    @StoredInput(.loadWorksheet, "phases", default: "3") private var phases
    @StoredInput(.loadWorksheet, "spare", default: "0") private var spare
    @StoredInput(.loadWorksheet, "lightVA", default: "12000") private var lightVA
    @StoredInput(.loadWorksheet, "receptVA", default: "5000") private var receptVA
    @StoredInput(.loadWorksheet, "contVA", default: "3000") private var contVA
    @StoredInput(.loadWorksheet, "motorVA", default: "8000") private var motorVA
    @StoredInput(.loadWorksheet, "jobName", default: "Load worksheet") private var jobName
    @State private var session = ExplicitCalculationState<LoadWorksheetResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String { "\(occ)|\(volts)|\(phases)|\(spare)|\(lightVA)|\(receptVA)|\(contVA)|\(motorVA)" }

    var body: some View {
        ToolScaffold(
            toolID: .loadWorksheet,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .loadWorksheet,
                symbolic: "Lighting → 220.42 DF; motors ×1.25; continuous +25%",
                substituted: substituted,
                meaning: "Simplified NEC 220 feeder/service worksheet. Row editors stay compact here — enter category VA totals. Not a stamped service calculation.",
                citation: "NEC Table 220.42 (as coded). Design aid."
            )

            MenuField(title: "Occupancy", selection: $occ, options: LoadWorksheetOccupancy.allCases.map(\.rawValue)) {
                LoadWorksheetOccupancy(rawValue: $0)?.label ?? $0
            }
            NumberField(title: "Voltage", unit: "V", text: $volts, fieldID: "volts", onSubmit: calculate)
            MenuField(title: "System", selection: $phases, options: ["1", "3"]) { $0 == "1" ? "1-phase" : "3-phase" }
            NumberField(title: "Spare", unit: "%", text: $spare, fieldID: "spare", onSubmit: calculate)
            NumberField(title: "Lighting VA", unit: "VA", text: $lightVA, fieldID: "lightVA", onSubmit: calculate)
            NumberField(title: "Receptacle VA", unit: "VA", text: $receptVA, fieldID: "receptVA", onSubmit: calculate)
            NumberField(title: "Continuous VA", unit: "VA", text: $contVA, fieldID: "contVA", onSubmit: calculate)
            NumberField(title: "Motor VA", unit: "VA", text: $motorVA, fieldID: "motorVA", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: {
                    lightVA = ""; receptVA = ""; contVA = ""; motorVA = ""; spare = "0"
                    session.reset()
                },
                onExample: {
                    occ = "other"; volts = "208"; phases = "3"; spare = "10"
                    lightVA = "12000"; receptVA = "5000"; contVA = "3000"; motorVA = "8000"
                    session.prepareForNewInputs()
                },
                exampleTitle: "12 kVA lighting + receptacles + continuous + motor"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: copyText) {
                    ResultRow(label: "Connected", value: "\(Format.number(r.connectedVA, digits: 0)) VA")
                    ResultRow(label: "Lighting demand", value: "\(Format.number(r.lightingDemandVA, digits: 0)) VA")
                    ResultRow(label: "Other demand", value: "\(Format.number(r.otherDemandVA, digits: 0)) VA")
                    ResultRow(label: "Total demand", value: "\(Format.number(r.totalDemandVA, digits: 0)) VA", emphasis: true)
                    ResultRow(label: "With spare", value: "\(Format.number(r.grandTotalVA, digits: 0)) VA", tone: Theme.copper)
                    ResultRow(label: "Calculated amps", value: Format.amps(r.amps), emphasis: true, tone: Theme.good)
                }
                .opacity(session.isStale ? 0.72 : 1)

                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .loadWorksheet,
                        inputs: ["light": lightVA, "motor": motorVA],
                        outputs: ["VA": Format.number(r.grandTotalVA, digits: 0), "A": Format.amps(r.amps)]
                    ))
                }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in session.markInputsChanged() }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func calculate() {
        session.calculate {
            let rows = [
                LoadWorksheetRow(description: "Lighting", type: .lighting, vaEach: try parseOptionalVA(lightVA, name: "Lighting VA")),
                LoadWorksheetRow(description: "Receptacles", type: .receptacle, vaEach: try parseOptionalVA(receptVA, name: "Receptacle VA")),
                LoadWorksheetRow(description: "Continuous", type: .continuous, vaEach: try parseOptionalVA(contVA, name: "Continuous VA")),
                LoadWorksheetRow(description: "Motor", type: .motor, vaEach: try parseOptionalVA(motorVA, name: "Motor VA")),
            ]
            return try LoadWorksheet.calculate(
                rows: rows,
                occupancy: LoadWorksheetOccupancy(rawValue: occ) ?? .other,
                voltage: volts.parsedDouble ?? .nan,
                phases: Int(phases) ?? 3,
                sparePercent: try parseOptionalVA(spare, name: "Spare percent")
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion { successTick += 1 }
    }

    /// Blank → 0; non-empty garbage → error (do not silently zero bad input).
    private func parseOptionalVA(_ text: String, name: String) throws -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        guard let value = trimmed.parsedDouble, value.isFinite, value >= 0 else {
            throw CalcError.outOfRange("\(name) is not a valid non-negative number.")
        }
        return value
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.formula) → \(Format.amps(r.amps))"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.number(r.grandTotalVA, digits: 0)) VA · \(Format.amps(r.amps))"
    }

    private var copyText: String? { sticky }
}

// MARK: - Cable schedule generator

struct CableScheduleView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.cableSchedule, "prefix", default: "C") private var prefix
    @StoredInput(.cableSchedule, "start", default: "1") private var start
    @StoredInput(.cableSchedule, "typeA", default: "PWR-3C-10") private var typeA
    @StoredInput(.cableSchedule, "qtyA", default: "3") private var qtyA
    @StoredInput(.cableSchedule, "fromA", default: "MCC-1") private var fromA
    @StoredInput(.cableSchedule, "toA", default: "P-101") private var toA
    @StoredInput(.cableSchedule, "typeB", default: "CTL-8C-14") private var typeB
    @StoredInput(.cableSchedule, "qtyB", default: "2") private var qtyB
    @StoredInput(.cableSchedule, "fromB", default: "PLC-1") private var fromB
    @StoredInput(.cableSchedule, "toB", default: "JB-12") private var toB
    @StoredInput(.cableSchedule, "jobName", default: "Cable schedule") private var jobName
    @State private var session = ExplicitCalculationState<CableScheduleResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String { "\(prefix)|\(start)|\(typeA)|\(qtyA)|\(fromA)|\(toA)|\(typeB)|\(qtyB)|\(fromB)|\(toB)" }
    private let typeOptions = CableSchedule.seedCatalog.map(\.id)

    var body: some View {
        ToolScaffold(
            toolID: .cableSchedule,
            stickyAnswer: sticky,
            copyText: session.displayedResult?.csv,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .cableSchedule,
                symbolic: "Cable ID = prefix + sequence; ampacity from 310.16",
                substituted: substituted,
                meaning: "Build a short cable schedule from the seeded type catalog. Length / tray / comments stay blank for field fill-in. Copy CSV from the result.",
                citation: "Project document generator. Ampacity notes use Table 310.16 75°C when listed."
            )

            TextInputField(title: "ID prefix", text: $prefix, placeholder: "C", autocapitalization: .characters, fieldID: "prefix", onSubmit: calculate)
            NumberField(title: "Start number", unit: "", text: $start, fieldID: "start", onSubmit: calculate)

            Text("LINE A").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            MenuField(title: "Type", selection: $typeA, options: typeOptions) { $0 }
            NumberField(title: "Quantity", unit: "", text: $qtyA, fieldID: "qtyA", onSubmit: calculate)
            TextInputField(title: "From", text: $fromA, placeholder: "MCC-1", autocapitalization: .characters, fieldID: "fromA", onSubmit: calculate)
            TextInputField(title: "To", text: $toA, placeholder: "P-101", autocapitalization: .characters, fieldID: "toA", onSubmit: calculate)

            Text("LINE B").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            MenuField(title: "Type", selection: $typeB, options: typeOptions) { $0 }
            NumberField(title: "Quantity", unit: "", text: $qtyB, fieldID: "qtyB", onSubmit: calculate)
            TextInputField(title: "From", text: $fromB, placeholder: "PLC-1", autocapitalization: .characters, fieldID: "fromB", onSubmit: calculate)
            TextInputField(title: "To", text: $toB, placeholder: "JB-12", autocapitalization: .characters, fieldID: "toB", onSubmit: calculate)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: {
                    prefix = "C"; start = "1"
                    qtyA = ""; fromA = ""; toA = ""; qtyB = ""; fromB = ""; toB = ""
                    session.reset()
                },
                onExample: {
                    prefix = "C"; start = "1"
                    typeA = "PWR-3C-10"; qtyA = "3"; fromA = "MCC-1"; toA = "P-101"
                    typeB = "CTL-8C-14"; qtyB = "2"; fromB = "PLC-1"; toB = "JB-12"
                    session.prepareForNewInputs()
                },
                exampleTitle: "3× power + 2× control cables"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                ResultCard(copyText: r.csv) {
                    ResultRow(label: "Rows", value: "\(r.rows.count)", emphasis: true, tone: Theme.good)
                    ForEach(r.rows.prefix(8)) { row in
                        ResultRow(
                            label: row.cableID,
                            value: "\(row.cableType) · \(row.from)→\(row.to)"
                        )
                    }
                    if r.rows.count > 8 {
                        Text("+\(r.rows.count - 8) more in CSV").font(Theme.TypeRole.help).foregroundStyle(Theme.muted)
                    }
                }
                .opacity(session.isStale ? 0.72 : 1)

                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .cableSchedule,
                        inputs: ["prefix": prefix, "n": "\(r.rows.count)"],
                        outputs: ["first": r.rows.first?.cableID ?? ""]
                    ))
                }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in session.markInputsChanged() }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func calculate() {
        session.calculate {
            var lines: [CableScheduleLineInput] = []
            let qA = Int(qtyA.parsedDouble ?? 0)
            if qA > 0 {
                lines.append(CableScheduleLineInput(typeId: typeA, quantity: qA, from: fromA, to: toA, system: "power"))
            }
            let qB = Int(qtyB.parsedDouble ?? 0)
            if qB > 0 {
                lines.append(CableScheduleLineInput(typeId: typeB, quantity: qB, from: fromB, to: toB, system: "control"))
            }
            return try CableSchedule.generate(
                lines: lines,
                prefix: prefix,
                startNumber: Int(start.parsedDouble ?? 1)
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion { successTick += 1 }
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.formula) → \(r.rows.count) cables"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.rows.count) cables · \(r.rows.first?.cableID ?? "")…"
    }
}

// MARK: - Solenoid design wizard

struct SolenoidDesignView: View {
    private enum Mode: String, CaseIterable {
        case analyze = "analyze"
        case targetB = "targetB"

        var label: String {
            switch self {
            case .analyze: return "Analyze geometry"
            case .targetB: return "Size current for B"
            }
        }
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.solenoidDesign, "mode", default: "analyze") private var mode
    @StoredInput(.solenoidDesign, "length", default: "80") private var lengthMm
    @StoredInput(.solenoidDesign, "diameter", default: "24") private var diameterMm
    @StoredInput(.solenoidDesign, "turns", default: "1200") private var turns
    @StoredInput(.solenoidDesign, "current", default: "0.8") private var current
    @StoredInput(.solenoidDesign, "targetB", default: "20") private var targetBmT
    @StoredInput(.solenoidDesign, "awg", default: "26") private var awg
    @StoredInput(.solenoidDesign, "muR", default: "1") private var muR
    @StoredInput(.solenoidDesign, "gap", default: "2") private var gapMm
    @StoredInput(.solenoidDesign, "jobName", default: "Solenoid design") private var jobName
    @State private var session = ExplicitCalculationState<SolenoidDesignResult>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(mode)|\(lengthMm)|\(diameterMm)|\(turns)|\(current)|\(targetBmT)|\(awg)|\(muR)|\(gapMm)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .solenoidDesign,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .solenoidDesign,
                symbolic: "B(z) finite solenoid · L ≈ μ₀μᵣN²A/ℓ · F ≈ (NI)²μ₀A/(2g²)",
                substituted: substituted,
                meaning: "Advanced winding pack, center-field, inductance, copper loss, axial B plot, and a single-gap plunger force estimate. Soft-iron µᵣ is linear — no saturation model. Design aid, not FEA.",
                citation: "Finite solenoid on-axis B; long-coil inductance; variable-reluctance force rule of thumb."
            )

            MenuField(title: "Wizard mode", selection: $mode, options: Mode.allCases.map(\.rawValue)) {
                Mode(rawValue: $0)?.label ?? $0
            }

            Text("GEOMETRY").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            NumberField(title: "Coil length", unit: "mm", text: $lengthMm, fieldID: "length", onSubmit: calculate)
            NumberField(title: "Mean diameter", unit: "mm", text: $diameterMm, fieldID: "diameter", onSubmit: calculate)
            NumberField(title: "Turns", unit: "", text: $turns, fieldID: "turns", onSubmit: calculate)
            NumberField(title: "Wire AWG", unit: "", text: $awg, fieldID: "awg", onSubmit: calculate)
            NumberField(title: "Relative µᵣ", unit: "", text: $muR, fieldID: "muR", onSubmit: calculate)
            NumberField(title: "Air gap (force)", unit: "mm", text: $gapMm, optional: true, fieldID: "gap", onSubmit: calculate)

            Text("ELECTRICAL").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            if mode == Mode.targetB.rawValue {
                NumberField(title: "Target center B", unit: "mT", text: $targetBmT, fieldID: "targetB", onSubmit: calculate)
            } else {
                NumberField(title: "Coil current", unit: "A", text: $current, fieldID: "current", onSubmit: calculate)
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: {
                    lengthMm = ""; diameterMm = ""; turns = ""; current = ""; targetBmT = ""
                    awg = "26"; muR = "1"; gapMm = ""; session.reset()
                },
                onExample: {
                    mode = Mode.analyze.rawValue
                    lengthMm = "80"; diameterMm = "24"; turns = "1200"; current = "0.8"
                    awg = "26"; muR = "1"; gapMm = "2"
                    session.prepareForNewInputs()
                },
                exampleTitle: "80×24 mm, 1200 turns, 26 AWG, 0.8 A"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                SolenoidCrossSectionDiagram(
                    lengthM: r.lengthM,
                    meanRadiusM: r.meanRadiusM,
                    outerRadiusM: r.packing.coilOuterRadiusM,
                    layers: r.packing.layers,
                    bCenterTesla: r.bCenterTesla
                )
                .opacity(session.isStale ? 0.72 : 1)

                ResultCard(copyText: copyText) {
                    ResultRow(label: "Center B", value: "\(Format.number(r.bCenterTesla * 1000, digits: 2)) mT", emphasis: true, tone: Theme.good)
                    ResultRow(label: "Ampere-turns", value: "\(Format.number(r.ampereTurns, digits: 0)) At")
                    ResultRow(label: "Inductance", value: "\(Format.number(r.inductanceHenry * 1000, digits: 2)) mH", emphasis: true)
                    ResultRow(label: "Stored energy", value: "\(Format.number(r.energyJoules * 1000, digits: 2)) mJ")
                    if let force = r.forceNewton {
                        ResultRow(label: "Plunger force", value: "\(Format.number(force, digits: 3)) N", tone: Theme.copper)
                    }
                }
                .opacity(session.isStale ? 0.72 : 1)

                ResultCard(title: "Winding & copper") {
                    ResultRow(label: "Packing", value: "\(r.packing.layers) layers × \(r.packing.turnsPerLayer) t/layer")
                    ResultRow(label: "Fill factor", value: Format.percent(r.packing.fillFactor * 100))
                    ResultRow(label: "Wire length", value: "\(Format.number(r.wireLengthM, digits: 2)) m")
                    ResultRow(label: "Resistance", value: "\(Format.number(r.resistanceOhms, digits: 2)) Ω")
                    ResultRow(label: "Voltage @ I", value: Format.volts(r.voltageVolts))
                    ResultRow(label: "Copper loss", value: "\(Format.number(r.copperLossWatts, digits: 2)) W")
                    ResultRow(label: "Current density", value: "\(Format.number(r.currentDensityAPerMm2, digits: 2)) A/mm²", tone: r.currentDensityAPerMm2 > 6 ? Theme.warn : Theme.foreground)
                }
                .opacity(session.isStale ? 0.72 : 1)

                SolenoidBCurrentChart(
                    points: r.bVsCurrent,
                    operatingCurrent: r.currentAmps,
                    operatingB: r.bCenterTesla
                )
                .opacity(session.isStale ? 0.72 : 1)

                SolenoidAxialFieldChart(
                    points: r.axialField,
                    lengthM: r.lengthM,
                    bCenter: r.bCenterTesla
                )
                .opacity(session.isStale ? 0.72 : 1)

                SolenoidForceGapChart(
                    points: r.forceVsGap,
                    operatingGapMm: r.airGapM.map { $0 * 1000 },
                    operatingForce: r.forceNewton
                )
                .opacity(session.isStale ? 0.72 : 1)

                if !r.warnings.isEmpty {
                    ResultCard(title: "Design notes") {
                        ForEach(r.warnings, id: \.self) { note in
                            Text(note)
                                .font(Theme.TypeRole.help)
                                .foregroundStyle(Theme.warn)
                        }
                    }
                    .opacity(session.isStale ? 0.72 : 1)
                }

                Text("Design aid — not a PE stamp, FEA substitute, or saturated-iron model.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)

                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .solenoidDesign,
                        inputs: [
                            "ℓ": lengthMm, "Ø": diameterMm, "N": turns, "I": Format.number(r.currentAmps, digits: 3),
                        ],
                        outputs: [
                            "B": "\(Format.number(r.bCenterTesla * 1000, digits: 2)) mT",
                            "L": "\(Format.number(r.inductanceHenry * 1000, digits: 2)) mH",
                        ]
                    ))
                }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in session.markInputsChanged() }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func calculate() {
        session.calculate {
            let lengthM = (lengthMm.parsedDouble ?? .nan) / 1000
            let radiusM = (diameterMm.parsedDouble ?? .nan) / 2000
            guard let turnsVal = turns.parsedDouble, turnsVal.isFinite else {
                throw CalcError.missing("Turns")
            }
            guard let awgValRaw = awg.parsedDouble, awgValRaw.isFinite else {
                throw CalcError.missing("Wire AWG")
            }
            let n = Int(turnsVal.rounded())
            let awgVal = Int(awgValRaw.rounded())
            let mur = muR.parsedDouble ?? .nan
            let gapText = gapMm.trimmingCharacters(in: .whitespacesAndNewlines)
            let gapM: Double?
            if gapText.isEmpty {
                gapM = nil
            } else if let gap = gapMm.parsedDouble, gap.isFinite {
                gapM = gap / 1000
            } else {
                throw CalcError.outOfRange("Air gap is not a valid number.")
            }

            let amps: Double
            if mode == Mode.targetB.rawValue {
                amps = try SolenoidDesign.currentForTargetB(
                    targetTesla: (targetBmT.parsedDouble ?? .nan) / 1000,
                    lengthM: lengthM,
                    meanRadiusM: radiusM,
                    turns: n,
                    relativePermeability: mur
                )
            } else {
                amps = current.parsedDouble ?? .nan
            }

            return try SolenoidDesign.design(
                lengthM: lengthM,
                meanRadiusM: radiusM,
                turns: n,
                currentAmps: amps,
                wireAWG: awgVal,
                relativePermeability: mur,
                airGapM: gapM
            )
        }
        if let r = session.displayedResult, mode == Mode.targetB.rawValue, !session.isStale {
            current = Format.number(r.currentAmps, digits: 3)
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion { successTick += 1 }
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.formula) → \(Format.number(r.bCenterTesla * 1000, digits: 2)) mT · \(Format.number(r.inductanceHenry * 1000, digits: 2)) mH"
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(Format.number(r.bCenterTesla * 1000, digits: 1)) mT · \(Format.number(r.inductanceHenry * 1000, digits: 1)) mH · \(Format.number(r.ampereTurns, digits: 0)) At"
    }

    private var copyText: String? { sticky }
}
