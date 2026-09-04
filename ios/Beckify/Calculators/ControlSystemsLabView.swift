import SwiftUI
import BeckifyMath

/// Pocket control-systems lab: plant → P/PI/PID step (ZN + overlays) → Bode → lead.
/// Lives under Field → Controls next to Signal Scaling / Modbus / PLC Timer.
struct ControlSystemsLabView: View {
    enum Section: String, CaseIterable, Identifiable {
        case plant = "Plant"
        case step = "Step"
        case bode = "Bode"
        case lead = "Lead"
        var id: String { rawValue }
    }

    private enum Output: Equatable {
        case plant(ControlPlantSummary)
        case step(ControlPlantSummary, ControlStepResult)
        case bode(ControlPlantSummary, ControlBodeResult)
        case lead(ControlPlantSummary, ControlLeadResult)
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.controlSystems, "section", default: Section.plant) private var section
    @StoredChoice(.controlSystems, "plantID", default: ControlPlantID.secondOrder) private var plantID
    @StoredChoice(.controlSystems, "mode", default: ControlControllerMode.p) private var mode
    @StoredInput(.controlSystems, "num", default: "4") private var numerator
    @StoredInput(.controlSystems, "den", default: "1, 1.2, 4") private var denominator
    @StoredInput(.controlSystems, "kp", default: "1") private var kp
    @StoredInput(.controlSystems, "ki", default: "0.5") private var ki
    @StoredInput(.controlSystems, "kd", default: "0.4") private var kd
    @StoredToggle(.controlSystems, "compare", default: false) private var compare
    @StoredChoice(.controlSystems, "znVariant", default: ControlZnVariant.classic) private var znVariant
    @StoredInput(.controlSystems, "ku", default: "4") private var ku
    @StoredInput(.controlSystems, "pu", default: "2") private var pu
    @StoredInput(.controlSystems, "fopdtK", default: "1") private var fopdtK
    @StoredInput(.controlSystems, "fopdtL", default: "0.4") private var fopdtL
    @StoredInput(.controlSystems, "fopdtT", default: "2") private var fopdtT
    @StoredInput(.controlSystems, "loopK", default: "1") private var loopK
    @StoredInput(.controlSystems, "leadPhase", default: "50") private var leadPhase
    @StoredInput(.controlSystems, "leadOmega", default: "4") private var leadOmega
    @StoredInput(.controlSystems, "jobName", default: "Control systems") private var jobName
    @State private var session = ExplicitCalculationState<Output>()
    @State private var successTick = 0
    @State private var tunerNote: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(section)|\(plantID)|\(mode)|\(numerator)|\(denominator)|\(kp)|\(ki)|\(kd)|\(compare)|\(loopK)|\(leadPhase)|\(leadOmega)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .controlSystems,
            stickyAnswer: sticky,
            copyText: sticky,
            disclaimer: .designAidExtra("Educational approximations (RK4 step, log Bode sweep, Durand–Kerner poles) — not for safety-critical commissioning."),
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .controlSystems,
                symbolic: symbolic,
                substituted: substituted,
                meaning: meaning
            )

            Picker("Section", selection: $section) {
                ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Lab section")

            plantPicker

            switch section {
            case .plant:
                plantFields
            case .step:
                stepFields
            case .bode:
                bodeFields
            case .lead:
                leadFields
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: loadExample,
                exampleTitle: exampleTitle
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let output = session.displayedResult {
                resultViews(output)
                    .opacity(session.isStale ? 0.72 : 1)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    save(output)
                }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .onChange(of: plantID) { _, newValue in
            applyLibraryPlant(newValue)
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    // MARK: - Fields

    @ViewBuilder
    private var plantPicker: some View {
        MenuField(
            title: "Plant",
            selection: $plantID,
            options: ControlPlantID.allCases
        ) { $0.displayName }

        if plantID != .custom, let plant = ControlSystems.plant(id: plantID) {
            Text(plant.summary)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
    }

    @ViewBuilder
    private var plantFields: some View {
        if plantID == .custom {
            TextInputField(
                title: "Numerator (highest power first)",
                text: $numerator,
                placeholder: "4",
                fieldID: "num"
            )
            TextInputField(
                title: "Denominator (highest power first)",
                text: $denominator,
                placeholder: "1, 1.2, 4",
                fieldID: "den"
            )
            Text("Comma or space separated, highest power first. Example: 4  /  1, 1.2, 4")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        } else {
            Text("G(s) = \(ControlSystems.plant(id: plantID)?.display ?? "—")")
                .font(.body.monospaced())
                .foregroundStyle(Theme.accent)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var stepFields: some View {
        Picker("Controller", selection: $mode) {
            ForEach(ControlControllerMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Controller type")

        Toggle("Compare Open / P / PI / PID", isOn: $compare)
            .tint(Theme.accent)
            .accessibilityHint("Overlay four unit-step responses on one chart using the Kp, Ki, and Kd below. Unused terms are zeroed per mode.")

        ThumbButtonRow {
            Button("1. P until it holds") {
                mode = .p
                if (kp.parsedDouble ?? 0) < 2 { kp = "2" }
                ki = "0"
                kd = "0"
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .frame(minHeight: Theme.touchTarget)
            Button("2. Add I") {
                mode = .pi
                if (ki.parsedDouble ?? 0) < 0.4 { ki = "0.4" }
                kd = "0"
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .frame(minHeight: Theme.touchTarget)
            Button("3. Add D") {
                mode = .pid
                if (kd.parsedDouble ?? 0) < 0.4 { kd = "0.4" }
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .frame(minHeight: Theme.touchTarget)
        }

        if mode != .open || compare {
            NumberField(title: "Kp", unit: "", text: $kp, fieldID: "kp", onSubmit: calculate)
        }
        if mode == .pi || mode == .pid || compare {
            NumberField(title: "Ki", unit: "1/s", text: $ki, fieldID: "ki", onSubmit: calculate)
        }
        if mode == .pid || compare {
            NumberField(title: "Kd", unit: "s", text: $kd, fieldID: "kd", onSubmit: calculate)
        }

        pidTuningCard
    }

    @ViewBuilder
    private var pidTuningCard: some View {
        Text("Ziegler–Nichols")
            .font(Theme.TypeRole.fieldLabel)
            .tracking(0.6)
            .foregroundStyle(Theme.muted)
        Text("Classic PID: Kp = 0.6 Ku, Ti = Pu/2, Td = Pu/8. Modified cuts overshoot. Apply writes Kp, Ki, Kd — then Calculate so you can compare responses.")
            .font(Theme.TypeRole.help)
            .foregroundStyle(Theme.muted)

        Picker("ZN table", selection: $znVariant) {
            ForEach(ControlZnVariant.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Ziegler–Nichols table")

        NumberField(title: "Ku", unit: "", text: $ku, helpText: "Ultimate gain — P-only oscillation.", fieldID: "ku")
        NumberField(title: "Pu", unit: "s", text: $pu, helpText: "Ultimate period of that oscillation.", fieldID: "pu")
        ThumbButtonRow {
            Button("Estimate Ku, Pu") { estimateUltimateGain() }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .frame(minHeight: Theme.touchTarget)
            Button("Apply ultimate") { applyZn(source: .ultimate) }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .frame(minHeight: Theme.touchTarget)
        }

        NumberField(title: "FOPDT K", unit: "", text: $fopdtK, fieldID: "fopdtK")
        NumberField(title: "L", unit: "s", text: $fopdtL, fieldID: "fopdtL")
        NumberField(title: "T", unit: "s", text: $fopdtT, helpText: "Reaction-curve PID: Kp = 1.2 T / (K L), Ti = 2L, Td = 0.5L.", fieldID: "fopdtT")
        ThumbButtonRow {
            Button("Fit open-loop step") { fitReactionCurve() }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .frame(minHeight: Theme.touchTarget)
            Button("Apply reaction") { applyZn(source: .reaction) }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .frame(minHeight: Theme.touchTarget)
        }

        if let tunerNote {
            Text(tunerNote)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .accessibilityIdentifier("controlSystems.tunerNote")
        }
    }

    @ViewBuilder
    private var bodeFields: some View {
        NumberField(
            title: "Loop gain K",
            unit: "",
            text: $loopK,
            helpText: "T = KG / (1 + KG). Margins are for this K.",
            fieldID: "loopK",
            onSubmit: calculate
        )
    }

    @ViewBuilder
    private var leadFields: some View {
        NumberField(
            title: "Phase bump φ",
            unit: "deg",
            text: $leadPhase,
            helpText: "α = (1 − sin φ) / (1 + sin φ). Keep φ under 80°.",
            fieldID: "leadPhase",
            onSubmit: calculate
        )
        NumberField(
            title: "ωm",
            unit: "rad/s",
            text: $leadOmega,
            helpText: "Frequency where the lead puts its maximum phase.",
            fieldID: "leadOmega",
            onSubmit: calculate
        )
    }

    // MARK: - Results

    @ViewBuilder
    private func resultViews(_ output: Output) -> some View {
        switch output {
        case .plant(let plant):
            plantCard(plant)
        case .step(let plant, let result):
            plantCard(plant)
            if result.comparison.isEmpty && !result.stable {
                ToolEmptyState(
                    title: "This loop is unstable",
                    detail: "The linear TF response diverges. Back the gains off, walk P → I → D, try Ziegler–Nichols, or pick a different plant.",
                    systemImage: "exclamationmark.triangle"
                )
            } else if result.stable || !result.comparison.isEmpty {
                stepChart(result)
            }
            if !result.comparison.isEmpty {
                compareMetricsCard(result)
            }
            ResultCard(copyText: sticky) {
                ResultRow(label: "Controller", value: result.mode.displayName, emphasis: true)
                ResultRow(
                    label: "Stability",
                    value: result.stable ? "Stable" : "Unstable",
                    emphasis: true,
                    tone: result.stable ? Theme.good : Theme.warn
                )
                ResultRow(label: "Rise time", value: ControlSystems.formatFinite(result.metrics?.riseTime, digits: 2, suffix: " s"))
                ResultRow(label: "Overshoot", value: ControlSystems.formatFinite(result.metrics?.overshoot, digits: 1, suffix: " %"))
                ResultRow(label: "Settling (2%)", value: ControlSystems.formatFinite(result.metrics?.settlingTime, digits: 2, suffix: " s"))
                ResultRow(label: "ess", value: ControlSystems.formatFinite(result.metrics?.steadyStateError, digits: 3))
                if result.mode != .open {
                    ResultRow(label: "Kp", value: Format.number(result.gains.kp, digits: 3))
                    if result.mode == .pi || result.mode == .pid {
                        ResultRow(label: "Ki", value: Format.number(result.gains.ki, digits: 3))
                    }
                    if result.mode == .pid {
                        ResultRow(label: "Kd", value: Format.number(result.gains.kd, digits: 3))
                    }
                }
            }
        case .bode(let plant, let result):
            plantCard(plant)
            ResultCard(title: "Margins", copyText: sticky) {
                ResultRow(
                    label: "Phase margin",
                    value: ControlSystems.formatFinite(result.margins.phaseMarginDeg, digits: 1, suffix: "°"),
                    emphasis: true,
                    tone: Theme.good
                )
                ResultRow(
                    label: "Gain margin",
                    value: ControlSystems.formatFinite(result.margins.gainMarginDb, digits: 1, suffix: " dB"),
                    emphasis: true
                )
                ResultRow(label: "ωc (gain xing)", value: ControlSystems.formatFinite(result.margins.gainCrossover, digits: 2, suffix: " rad/s"))
                ResultRow(label: "ωpc", value: ControlSystems.formatFinite(result.margins.phaseCrossover, digits: 2, suffix: " rad/s"))
                ResultRow(label: "ωb (CL −3 dB)", value: ControlSystems.formatFinite(result.bandwidth, digits: 2, suffix: " rad/s"))
                ResultRow(
                    label: "Closed loop",
                    value: result.closedLoopStable ? "Stable" : "Unstable",
                    tone: result.closedLoopStable ? Theme.good : Theme.warn
                )
            }
            Text(result.relativeStability)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            bodeCharts(result)
        case .lead(let plant, let result):
            plantCard(plant)
            ResultCard(copyText: sticky) {
                ResultRow(label: "Gc(s)", value: result.display, emphasis: true, tone: Theme.good)
                ResultRow(label: "α", value: Format.number(result.alpha, digits: 3))
                ResultRow(label: "T", value: Format.number(result.timeConstant, digits: 3) + " s")
                ResultRow(label: "R1 (C=0.1 µF)", value: formatOhms(result.parts.r1))
                ResultRow(label: "R2", value: formatOhms(result.parts.r2))
                ResultRow(label: "C1 = C2", value: "0.1 µF")
                ResultRow(label: "Plant Mp", value: ControlSystems.formatFinite(result.plantMetrics.overshoot, digits: 1, suffix: " %"))
                ResultRow(label: "Lead Mp", value: ControlSystems.formatFinite(result.leadMetrics.overshoot, digits: 1, suffix: " %"))
                ResultRow(label: "Plant ts", value: ControlSystems.formatFinite(result.plantMetrics.settlingTime, digits: 2, suffix: " s"))
                ResultRow(label: "Lead ts", value: ControlSystems.formatFinite(result.leadMetrics.settlingTime, digits: 2, suffix: " s"))
            }
            leadChart(result)
        }
    }

    @ViewBuilder
    private func plantCard(_ plant: ControlPlantSummary) -> some View {
        ResultCard(title: "Plant under study") {
            ResultRow(label: "Name", value: plant.name, emphasis: true)
            ResultRow(label: "G(s)", value: plant.display)
            ResultRow(label: "Order", value: "\(plant.order)")
            ResultRow(
                label: "DC gain",
                value: plant.dcGain.isFinite ? Format.number(plant.dcGain, digits: 3) : "∞ (integrator)"
            )
            ResultRow(
                label: "Open loop",
                value: plant.openLoopStable ? "Stable" : "Unstable",
                tone: plant.openLoopStable ? Theme.good : Theme.warn
            )
            ResultRow(
                label: "Poles",
                value: plant.poles.isEmpty ? "—" : plant.poles.map(ControlSystems.formatComplex).joined(separator: "  ·  ")
            )
        }
        Text(plant.teaches)
            .font(.subheadline)
            .foregroundStyle(Theme.muted)
    }

    @ViewBuilder
    private func stepChart(_ result: ControlStepResult) -> some View {
        if !result.comparison.isEmpty {
            compareChart(result)
        } else {
            let closed = result.closedLoop.filter { $0.y.isFinite && abs($0.y) < 1e6 }
            let open = result.openLoop.filter { $0.y.isFinite && abs($0.y) < 1e6 }
            if !closed.isEmpty {
                DiagramCard(
                    title: "Unit step",
                    accessibilitySummary: "Closed-loop step versus open-loop plant. Rise \(ControlSystems.formatFinite(result.metrics?.riseTime, digits: 2, suffix: " s")), overshoot \(ControlSystems.formatFinite(result.metrics?.overshoot, digits: 1, suffix: " %")).",
                    exportName: "control-step"
                ) {
                    EngineerLinePlot(
                        series: [
                            EngineerSeries(name: "Open loop", points: open, color: Theme.chartSecondary, fills: false),
                            EngineerSeries(name: result.mode == .open ? "Plant" : "Closed loop", points: closed, color: Theme.chartPrimary, fills: true),
                        ],
                        xLabel: "s",
                        yLabel: "y",
                        yGuides: [EngineerGuide(value: 1, label: "1", axis: .y)],
                        height: 220
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func compareChart(_ result: ControlStepResult) -> some View {
        let series = result.comparison.compactMap { trace -> EngineerSeries? in
            let points = trace.samples.filter { $0.y.isFinite && abs($0.y) < 1e6 }
            guard !points.isEmpty else { return nil }
            return EngineerSeries(
                name: trace.mode.displayName,
                points: points,
                color: compareColor(trace.mode),
                fills: trace.mode == .pid
            )
        }
        if !series.isEmpty {
            DiagramCard(
                title: "Open / P / PI / PID",
                accessibilitySummary: compareAccessibility(result),
                exportName: "control-step-compare"
            ) {
                EngineerLinePlot(
                    series: series,
                    xLabel: "s",
                    yLabel: "y",
                    yGuides: [EngineerGuide(value: 1, label: "1", axis: .y)],
                    height: 240
                )
            }
        }
    }

    @ViewBuilder
    private func compareMetricsCard(_ result: ControlStepResult) -> some View {
        ResultCard(title: "Overlay") {
            ForEach(result.comparison, id: \.mode) { trace in
                ResultRow(
                    label: trace.mode.displayName,
                    value: compareMetricLine(trace),
                    tone: trace.stable ? Theme.foreground : Theme.warn
                )
            }
        }
        Text("Same Kp / Ki / Kd on every trace; unused terms are zeroed. Change the gains or Apply Ziegler–Nichols, then Calculate again.")
            .font(.subheadline)
            .foregroundStyle(Theme.muted)
    }

    @ViewBuilder
    private func bodeCharts(_ result: ControlBodeResult) -> some View {
        DiagramCard(
            title: "Bode magnitude",
            accessibilitySummary: "Open-loop magnitude in dB versus rad/s. Phase margin \(ControlSystems.formatFinite(result.margins.phaseMarginDeg, digits: 1, suffix: "°")), gain margin \(ControlSystems.formatFinite(result.margins.gainMarginDb, digits: 1, suffix: " dB")).",
            exportName: "control-bode-mag"
        ) {
            EngineerLinePlot(
                series: [
                    EngineerSeries(name: "OL |G|", points: result.magnitude, color: Theme.chartPrimary, fills: true),
                    EngineerSeries(name: "CL |T|", points: result.closedMagnitude, color: Theme.chartSecondary, fills: false),
                ],
                xLabel: "rad/s",
                yLabel: "dB",
                xGuides: result.margins.gainCrossover.map { [EngineerGuide(value: $0, label: "ωc", axis: .x)] } ?? [],
                yGuides: [EngineerGuide(value: 0, label: "0 dB", axis: .y)],
                logX: true,
                height: 200
            )
        }
        DiagramCard(
            title: "Bode phase",
            accessibilitySummary: "Open-loop phase in degrees versus rad/s.",
            exportName: "control-bode-phase"
        ) {
            EngineerLinePlot(
                series: [
                    EngineerSeries(name: "∠G", points: result.phase, color: Theme.chartPrimary, fills: false),
                ],
                xLabel: "rad/s",
                yLabel: "deg",
                yGuides: [EngineerGuide(value: -180, label: "−180°", axis: .y)],
                logX: true,
                height: 200
            )
        }
    }

    @ViewBuilder
    private func leadChart(_ result: ControlLeadResult) -> some View {
        DiagramCard(
            title: "Unity-feedback step",
            accessibilitySummary: "Plant versus plant with lead. Lead overshoot \(ControlSystems.formatFinite(result.leadMetrics.overshoot, digits: 1, suffix: " %")).",
            exportName: "control-lead-step"
        ) {
            EngineerLinePlot(
                series: [
                    EngineerSeries(name: "Plant", points: result.plantStep, color: Theme.chartSecondary, fills: false),
                    EngineerSeries(name: "With lead", points: result.leadStep, color: Theme.chartPrimary, fills: true),
                ],
                xLabel: "s",
                yLabel: "y",
                yGuides: [EngineerGuide(value: 1, label: "1", axis: .y)],
                height: 220
            )
        }
    }

    // MARK: - Actions

    private func calculate() {
        session.calculate {
            let plant = try resolvedPlant()
            switch section {
            case .plant:
                return .plant(plant)
            case .step:
                let result = try ControlSystems.stepTune(
                    plant: plant.transferFunction,
                    mode: mode,
                    gains: parsedGains(),
                    duration: plant.duration,
                    compare: compare
                )
                return .step(plant, result)
            case .bode:
                let k = loopK.parsedDouble ?? .nan
                let result = try ControlSystems.bodeAnalysis(plant: plant.transferFunction, loopGain: k)
                return .bode(plant, result)
            case .lead:
                let phase = leadPhase.parsedDouble ?? .nan
                let omega = leadOmega.parsedDouble ?? .nan
                let result = try ControlSystems.leadDesign(
                    plant: plant.transferFunction,
                    phaseDeg: phase,
                    omega: omega,
                    duration: min(plant.duration, 12)
                )
                return .lead(plant, result)
            }
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        switch section {
        case .plant:
            plantID = .secondOrder
            applyLibraryPlant(.secondOrder)
        case .step:
            mode = .p
            compare = false
            znVariant = .classic
            ku = "4"
            pu = "2"
            fopdtK = "1"
            fopdtL = "0.4"
            fopdtT = "2"
            tunerNote = nil
            applySuggestedGains()
        case .bode:
            loopK = "1"
        case .lead:
            leadPhase = "50"
            leadOmega = "4"
        }
        session.reset()
    }

    private func loadExample() {
        switch section {
        case .plant:
            plantID = .secondOrder
            applyLibraryPlant(.secondOrder)
        case .step:
            plantID = .firstOrder
            applyLibraryPlant(.firstOrder)
            mode = .pi
            compare = true
            kp = "2"
            ki = "1"
            kd = "0.2"
            tunerNote = nil
        case .bode:
            plantID = .secondOrder
            applyLibraryPlant(.secondOrder)
            loopK = "1"
        case .lead:
            plantID = .secondOrder
            applyLibraryPlant(.secondOrder)
            leadPhase = "50"
            leadOmega = "4"
        }
        session.prepareForNewInputs()
        calculate()
    }

    private func applyLibraryPlant(_ id: ControlPlantID) {
        guard id != .custom, let plant = ControlSystems.plant(id: id) else { return }
        numerator = plant.transferFunction.numerator.map { Format.number($0, digits: 4) }.joined(separator: ", ")
        denominator = plant.transferFunction.denominator.map { Format.number($0, digits: 4) }.joined(separator: ", ")
        kp = Format.number(plant.suggested.kp, digits: 3)
        ki = Format.number(plant.suggested.ki, digits: 3)
        kd = Format.number(plant.suggested.kd, digits: 3)
    }

    private func applySuggestedGains() {
        if plantID != .custom, let plant = ControlSystems.plant(id: plantID) {
            kp = Format.number(plant.suggested.kp, digits: 3)
            ki = Format.number(plant.suggested.ki, digits: 3)
            kd = Format.number(plant.suggested.kd, digits: 3)
        } else {
            kp = "1"
            ki = "0.4"
            kd = "0.2"
        }
    }

    private func resolvedPlant() throws -> ControlPlantSummary {
        if plantID == .custom {
            return try ControlSystems.resolvePlant(id: .custom, numeratorText: numerator, denominatorText: denominator)
        }
        return try ControlSystems.resolvePlant(id: plantID)
    }

    private func parsedGains() -> ControlPidGains {
        ControlPidGains(
            kp: kp.parsedDouble ?? .nan,
            ki: ki.parsedDouble ?? .nan,
            kd: kd.parsedDouble ?? .nan
        )
    }

    private func save(_ output: Output) {
        let plant: ControlPlantSummary
        var outputs: [String: String] = [:]
        switch output {
        case .plant(let p):
            plant = p
            outputs = [
                "G(s)": p.display,
                "DC": p.dcGain.isFinite ? Format.number(p.dcGain, digits: 3) : "∞",
                "OL": p.openLoopStable ? "stable" : "unstable",
            ]
        case .step(let p, let r):
            plant = p
            var overlay = ""
            if let pi = r.comparison.first(where: { $0.mode == .pi }) {
                overlay = ControlSystems.formatFinite(pi.metrics?.steadyStateError, digits: 3)
            }
            outputs = [
                "mode": r.mode.displayName,
                "stable": r.stable ? "yes" : "no",
                "Mp": ControlSystems.formatFinite(r.metrics?.overshoot, digits: 1, suffix: " %"),
                "ts": ControlSystems.formatFinite(r.metrics?.settlingTime, digits: 2, suffix: " s"),
                "ess": ControlSystems.formatFinite(r.metrics?.steadyStateError, digits: 3),
            ]
            if !overlay.isEmpty {
                outputs["PI ess"] = overlay
            }
        case .bode(let p, let r):
            plant = p
            outputs = [
                "PM": ControlSystems.formatFinite(r.margins.phaseMarginDeg, digits: 1, suffix: "°"),
                "GM": ControlSystems.formatFinite(r.margins.gainMarginDb, digits: 1, suffix: " dB"),
                "ωc": ControlSystems.formatFinite(r.margins.gainCrossover, digits: 2, suffix: " rad/s"),
                "ωb": ControlSystems.formatFinite(r.bandwidth, digits: 2, suffix: " rad/s"),
            ]
        case .lead(let p, let r):
            plant = p
            outputs = [
                "Gc": r.display,
                "α": Format.number(r.alpha, digits: 3),
                "T": Format.number(r.timeConstant, digits: 3),
            ]
        }
        jobs.save(SavedJob(
            name: jobName,
            toolID: .controlSystems,
            inputs: [
                "section": section.rawValue,
                "plantID": plant.plantID.rawValue,
                "plant": plant.name,
                "G": plant.display,
                "num": numerator,
                "den": denominator,
                "mode": mode.rawValue,
                "kp": kp,
                "ki": ki,
                "kd": kd,
            ],
            outputs: outputs
        ))
    }

    private var exampleTitle: String {
        switch section {
        case .plant: return "lightly damped 2nd-order"
        case .step: return "compare Open / P / PI / PID on a lag"
        case .bode: return "2nd-order Bode margins"
        case .lead: return "50° lead at 4 rad/s"
        }
    }

    private var symbolic: String {
        switch section {
        case .plant:
            return "G(s) = N(s) / D(s)    poles = roots(D)    Kp = N(0)/D(0)"
        case .step:
            return compare
                ? "Overlay Open, P, PI, PID on the same unit step. Unused Ki / Kd are zeroed per mode."
                : "C(s) = Kp + Ki/s + Kd s    T = CG / (1 + CG)"
        case .bode:
            return "|G(jω)|dB = 20 log10 |G|    PM = 180° + ∠G(jωc)"
        case .lead:
            return "Gc(s) = (T s + 1) / (α T s + 1)    α = (1 − sin φ)/(1 + sin φ)"
        }
    }

    private var substituted: String? {
        guard let output = session.displayedResult else { return nil }
        switch output {
        case .plant(let plant):
            return "G(s) = \(plant.display)"
        case .step(_, let result):
            if !result.comparison.isEmpty {
                let pi = result.comparison.first { $0.mode == .pi }
                let pid = result.comparison.first { $0.mode == .pid }
                return "Open / P / PI / PID  ·  PI ess \(ControlSystems.formatFinite(pi?.metrics?.steadyStateError, digits: 3))  ·  PID Mp \(ControlSystems.formatFinite(pid?.metrics?.overshoot, digits: 1, suffix: " %"))"
            }
            if result.stable {
                return "\(result.mode.displayName)  ·  Mp \(ControlSystems.formatFinite(result.metrics?.overshoot, digits: 1, suffix: " %"))  ·  ts \(ControlSystems.formatFinite(result.metrics?.settlingTime, digits: 2, suffix: " s"))"
            }
            return "\(result.mode.displayName)  ·  unstable"
        case .bode(_, let result):
            return "PM \(ControlSystems.formatFinite(result.margins.phaseMarginDeg, digits: 1, suffix: "°"))  ·  GM \(ControlSystems.formatFinite(result.margins.gainMarginDb, digits: 1, suffix: " dB"))  ·  ωc \(ControlSystems.formatFinite(result.margins.gainCrossover, digits: 2, suffix: " rad/s"))"
        case .lead(_, let result):
            return "Gc = \(result.display)"
        }
    }

    private var meaning: String? {
        switch section {
        case .plant:
            return "Pick a library plant or type coefficients. Every other section uses this G(s). A right-half-plane pole means the open loop runs away."
        case .step:
            return "Walk P until the plant holds, I to kill offset, D to damp ringing. Toggle Compare to overlay Open / P / PI / PID on one chart. Ziegler–Nichols fills Kp, Ki, Kd from Ku/Pu or a FOPDT fit — a tuning aid, not autotune of a real plant."
        case .bode:
            return "Phase margin is how far you are from the −1 point at gain crossover. ωb is closed-loop speed, not a stability number."
        case .lead:
            return "A lead network adds phase around ωm. The R/C pair is a generic inverting analog suggestion at C = 0.1 µF — not a lab schematic."
        }
    }

    private var sticky: String? {
        guard let output = session.displayedResult else { return nil }
        switch output {
        case .plant(let plant):
            let gain = plant.dcGain.isFinite ? Format.number(plant.dcGain, digits: 2) : "∞"
            return "\(plant.name)  ·  DC \(gain)  ·  \(plant.openLoopStable ? "stable" : "unstable")"
        case .step(_, let result):
            if !result.comparison.isEmpty {
                let pi = result.comparison.first { $0.mode == .pi }
                return "Open/P/PI/PID  ·  PI ess \(ControlSystems.formatFinite(pi?.metrics?.steadyStateError, digits: 3))"
            }
            if result.stable {
                return "\(result.mode.displayName)  ·  Mp \(ControlSystems.formatFinite(result.metrics?.overshoot, digits: 1, suffix: "%"))  ·  ts \(ControlSystems.formatFinite(result.metrics?.settlingTime, digits: 2, suffix: "s"))"
            }
            return "\(result.mode.displayName)  ·  unstable"
        case .bode(_, let result):
            return "PM \(ControlSystems.formatFinite(result.margins.phaseMarginDeg, digits: 1, suffix: "°"))  ·  GM \(ControlSystems.formatFinite(result.margins.gainMarginDb, digits: 1, suffix: " dB"))  ·  ωc \(ControlSystems.formatFinite(result.margins.gainCrossover, digits: 2))"
        case .lead(_, let result):
            return "Gc  ·  α \(Format.number(result.alpha, digits: 2))  ·  T \(Format.number(result.timeConstant, digits: 2)) s"
        }
    }

    private func formatOhms(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        if abs(value) >= 1e6 { return "\(Format.number(value / 1e6, digits: 3)) MΩ" }
        if abs(value) >= 1e3 { return "\(Format.number(value / 1e3, digits: 3)) kΩ" }
        return "\(Format.number(value, digits: 3)) Ω"
    }

    private enum ZnSource {
        case ultimate
        case reaction
    }

    private func applyZn(source: ZnSource) {
        do {
            let form = ControlZnForm.from(mode: mode)
            let table: ControlZnGains
            switch source {
            case .ultimate:
                table = try ControlSystems.zieglerNicholsUltimate(
                    ku: ku.parsedDouble ?? .nan,
                    pu: pu.parsedDouble ?? .nan,
                    form: form,
                    variant: znVariant
                )
            case .reaction:
                table = try ControlSystems.zieglerNicholsReactionCurve(
                    k: fopdtK.parsedDouble ?? .nan,
                    l: fopdtL.parsedDouble ?? .nan,
                    t: fopdtT.parsedDouble ?? .nan,
                    form: form,
                    variant: znVariant
                )
            }
            kp = Format.number(table.kp, digits: 3)
            ki = Format.number(table.ki, digits: 3)
            kd = Format.number(table.kd, digits: 3)
            if mode == .open {
                mode = form.controllerMode
            }
            tunerNote = "\(znVariant.displayName) \(form.displayName): Kp \(Format.number(table.kp, digits: 3)), Ki \(Format.number(table.ki, digits: 3)), Kd \(Format.number(table.kd, digits: 3))"
            calculate()
        } catch let error as CalcError {
            tunerNote = error.message
        } catch {
            tunerNote = "Could not apply Ziegler–Nichols."
        }
    }

    private func estimateUltimateGain() {
        do {
            let plant = try resolvedPlant()
            let result = ControlSystems.ultimateGain(plant.transferFunction)
            guard let kuValue = result.ku, kuValue > 0, kuValue.isFinite else {
                tunerNote = "This plant stays stable for all K — no ultimate gain. Use the reaction-curve fit instead."
                return
            }
            ku = Format.number(kuValue, digits: 3)
            if let puValue = result.pu, puValue.isFinite, puValue > 0 {
                pu = Format.number(puValue, digits: 3)
            }
            tunerNote = "Estimated Ku \(ku)" + (result.pu != nil ? " · Pu \(pu) s. Apply ultimate to fill Kp, Ki, Kd." : ". Period was not resolved.")
        } catch let error as CalcError {
            tunerNote = error.message
        } catch {
            tunerNote = "Could not estimate Ku, Pu."
        }
    }

    private func fitReactionCurve() {
        do {
            let plant = try resolvedPlant()
            let dt = plant.duration / 320
            let samples = try ControlSystems.simulateStep(plant.transferFunction, duration: plant.duration, dt: dt)
            let fit = ControlSystems.fitReactionCurve(samples)
            if fit.k.isFinite {
                fopdtK = Format.number(fit.k, digits: 3)
            }
            guard fit.l.isFinite, fit.l > 0, fit.t.isFinite, fit.t > 0 else {
                tunerNote = "Open-loop step did not yield a usable FOPDT delay L. Try a slower plant or a longer duration."
                return
            }
            fopdtL = Format.number(max(fit.l, 0.01), digits: 3)
            fopdtT = Format.number(max(fit.t, 0.05), digits: 3)
            tunerNote = "Fit K \(fopdtK) · L \(fopdtL) s · T \(fopdtT) s. Apply reaction to fill Kp, Ki, Kd."
        } catch let error as CalcError {
            tunerNote = error.message
        } catch {
            tunerNote = "Could not fit the open-loop step."
        }
    }

    private func compareColor(_ mode: ControlControllerMode) -> Color {
        switch mode {
        case .open: return Theme.chartSecondary
        case .p: return Theme.chartTertiary
        case .pi: return Theme.chartPrimary
        case .pid: return Theme.good
        }
    }

    private func compareMetricLine(_ trace: ControlCompareTrace) -> String {
        if !trace.stable {
            return "unstable"
        }
        let mp = ControlSystems.formatFinite(trace.metrics?.overshoot, digits: 1, suffix: "%")
        let ess = ControlSystems.formatFinite(trace.metrics?.steadyStateError, digits: 3)
        return "Mp \(mp)  ·  ess \(ess)"
    }

    private func compareAccessibility(_ result: ControlStepResult) -> String {
        let bits = result.comparison.map { trace in
            "\(trace.mode.displayName) \(compareMetricLine(trace))"
        }
        return "Unit-step overlay. " + bits.joined(separator: ". ")
    }
}
