import SwiftUI
import BeckifyMath

struct UL508AWireView: View {
    @StoredChoice(.ul508aPanelLab, "environment", default: PanelInstallEnvironment.indoorDry) private var environment
    @StoredChoice(.ul508aPanelLab, "wireColumn", default: PanelTerminalColumn.c75) private var column
    @StoredChoice(.ul508aPanelLab, "wireClass", default: PanelCircuitClass.internalPower) private var circuit
    @StoredInput(.ul508aPanelLab, "wireAmps", default: "66.5") private var amps
    @State private var session = ExplicitCalculationState<PanelWireChoice>()

    private var fingerprint: String { "\(amps)|\(column)|\(circuit)" }

    var body: some View {
        PanelLabScreen(
            title: "Power & Control Wire",
            bullets: [
                "60°C when the terminal is unmarked or 60°C only. 75°C when it is marked 75°C or 60/75°C.",
                "18 and 16 AWG are control sizes on the 60°C column. Power circuits start at 14 AWG.",
                "Class 2 stays separated from power. The note is a checklist, not a raceway design.",
                "Field wiring leaving the panel still follows the adopted NEC. Open Wire Size & Ampacity for 310.16.",
            ],
            stickyAnswer: session.displayedResult.map { "\(NECTables.wireLabel($0.size)) · \($0.ampacity) A" },
            copyText: session.displayedResult.map { "\(NECTables.wireLabel($0.size)) planning ampacity \($0.ampacity) A (\(column.title))" }
        ) {
            EnvironmentMenu(environment: $environment)
            MenuField(title: "Circuit", selection: $circuit, options: PanelCircuitClass.allCases) { $0.title }
            MenuField(title: "Terminal column", selection: $column, options: PanelTerminalColumn.allCases) { $0.title }
            Text(column.detail + " " + PanelWireAmpacity.caption)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            if circuit != .class2 {
                NumberField(title: "Required current", unit: "A", text: $amps, fieldID: "wireAmps", onSubmit: calculate)
                CalculatorActionBar(onCalculate: calculate, onReset: { amps = ""; session = ExplicitCalculationState() }, onExample: {
                    amps = "66.5"
                    column = .c75
                    circuit = .powerFeeder
                    session = ExplicitCalculationState()
                }, exampleTitle: "66.5 A feeder, 75°C")
            }
            if let error = session.lastValidationError ?? session.error, circuit != .class2 {
                ErrorText(message: error.message)
            }
            if circuit != .class2, let choice = session.displayedResult {
                AmpacityMeter(required: panelParse(amps) ?? 0, capacity: Double(choice.ampacity))
                    .opacity(session.isStale ? 0.72 : 1)
                ResultCard(title: "Planning size") {
                    ResultRow(label: "Size", value: NECTables.wireLabel(choice.size), emphasis: true, tone: Theme.good)
                    ResultRow(label: column.title, value: "\(choice.ampacity) A")
                    if choice.controlOnly {
                        Text("This size is a control-circuit planning row, not a power feeder.")
                            .font(Theme.TypeRole.help)
                            .foregroundStyle(Theme.warn)
                    }
                }
            }
            WiringAdviceCard(advice: PanelWiringAdvice.recommend(environment: environment, circuit: circuit))
            if circuit == .class2 || circuit == .control {
                Text("Power and Class 2 do not share a raceway by default. Keep the limited-energy bundle on its own path or behind a barrier, and do not use this ampacity table to 'size' a Class 2 loop.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ConductorColorGuide(families: circuit == .control || circuit == .class2 ? [.controlPanel] : [.powerDistribution, .controlPanel])
        }
        .onChange(of: fingerprint) { _, _ in session.markInputsChanged() }
    }

    private func calculate() {
        session.calculate {
            guard let required = panelParse(amps) else { throw CalcError.missing("required current") }
            return try PanelWireAmpacity.smallest(
                requiredAmps: required,
                column: column,
                includeControlSizes: circuit == .control
            )
        }
    }
}

struct UL508AEnclosureView: View {
    @StoredChoice(.ul508aPanelLab, "environment", default: PanelInstallEnvironment.indoorDry) private var environment
    @StoredInput(.ul508aPanelLab, "enclosureID", default: "4X") private var enclosureID
    @StoredInput(.ul508aPanelLab, "disconnectAmps", default: "66.5") private var disconnectAmps
    @StoredToggle(.ul508aPanelLab, "switchesMotor", default: true) private var switchesMotor
    @State private var session = ExplicitCalculationState<DisconnectPlan>()

    private var guide: EnclosureGuide? { PanelEnclosureGuide.guide(id: enclosureID) }

    var body: some View {
        PanelLabScreen(
            title: "Disconnect & Enclosure",
            bullets: [
                "Pick the enclosure for the room: dry, dust, rain, hose-down, or corrosion. IP codes are analogies, not a conversion.",
                "The disconnect is at least the calculated load, lockable open, and horsepower-rated when it switches a motor.",
                "Wire-bending space and working clearance are prompts. Measure the room. This is not an Article 110 reprint.",
                "Hazardous locations are a pointer only. No Class or Division design on this screen.",
            ],
            stickyAnswer: session.displayedResult.map { "Disconnect ≥ \(Format.amps($0.minimumAmps))" },
            copyText: session.displayedResult.map { plan in
                "Disconnect ≥ \(Format.amps(plan.minimumAmps)). Enclosure \(guide?.nemaType ?? "")."
            }
        ) {
            ForEach(PanelEnclosureGuide.rows) { row in
                Button {
                    enclosureID = row.id
                    environment = row.environment
                } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.nemaType)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.foreground)
                            Text(row.title)
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        if enclosureID == row.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.accent)
                                .accessibilityLabel("Selected")
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: Theme.touchTarget, alignment: .leading)
                    .background(enclosureID == row.id ? Theme.accent.opacity(0.12) : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(row.nemaType), \(row.title)")
            }
            if let guide {
                ResultCard(title: guide.nemaType) {
                    Text(guide.whenToPick)
                        .font(.subheadline)
                        .foregroundStyle(Theme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(guide.ipAnalogy)
                        .font(.subheadline)
                        .foregroundStyle(Theme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(guide.notFor)
                        .font(.subheadline)
                        .foregroundStyle(Theme.warn)
                        .fixedSize(horizontal: false, vertical: true)
                    if guide.analogyOnly {
                        Text("NEMA type and IP code are not the same test. Do not mark an IP rating because a NEMA type was selected here.")
                            .font(Theme.TypeRole.help)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                WiringAdviceCard(advice: PanelWiringAdvice.recommend(environment: guide.environment, circuit: .powerFeeder))
            }
            NumberField(title: "Calculated panel load", unit: "A", text: $disconnectAmps, fieldID: "disconnectAmps", onSubmit: calculate)
            Toggle("Disconnect switches a motor", isOn: $switchesMotor)
                .font(.subheadline)
            CalculatorActionBar(onCalculate: calculate, onExample: {
                disconnectAmps = "66.5"
                switchesMotor = true
                enclosureID = "4X"
                environment = .corrosive
                session = ExplicitCalculationState()
            }, exampleTitle: "66.5 A, Type 4X")
            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }
            if let plan = session.displayedResult {
                ResultCard(title: "Disconnect") {
                    ResultRow(label: "Minimum rating", value: Format.amps(plan.minimumAmps), emphasis: true, tone: Theme.good)
                    ForEach(plan.reminders, id: \.self) { line in
                        Text("• \(line)")
                            .font(.subheadline)
                            .foregroundStyle(Theme.foreground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            ResultCard(title: "Clearance prompts") {
                ForEach(PanelEnclosureGuide.clearancePrompts, id: \.self) { line in
                    Text("• \(line)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onChange(of: disconnectAmps) { _, _ in session.markInputsChanged() }
        .onChange(of: switchesMotor) { _, _ in session.markInputsChanged() }
    }

    private func calculate() {
        session.calculate {
            guard let amps = panelParse(disconnectAmps) else { throw CalcError.missing("calculated load") }
            return try PanelDisconnect.plan(calculatedLoadAmps: amps, switchesMotor: switchesMotor)
        }
    }
}

struct UL508ACPTView: View {
    @EnvironmentObject private var jobs: JobStore
    @Environment(\.openRelatedTool) private var openRelated
    @StoredInput(.ul508aPanelLab, "cptVA", default: "500") private var va
    @StoredInput(.ul508aPanelLab, "cptVp", default: "480") private var primaryVolts
    @StoredInput(.ul508aPanelLab, "cptVs", default: "120") private var secondaryVolts
    @StoredInput(.ul508aPanelLab, "cptJob", default: "Control transformer") private var jobName
    @State private var session = ExplicitCalculationState<ControlTransformerPlan>()

    private var fingerprint: String { "\(va)|\(primaryVolts)|\(secondaryVolts)" }

    var body: some View {
        PanelLabScreen(
            title: "Control Transformer",
            bullets: [
                "Primary planning bands: 500% at 2 A or under, 167% through 9 A, 125% above that.",
                "Secondary is planned at 125% of secondary current. A power transformer with both sides protected belongs in Transformer Sizing.",
                "Class 2 and other limited-energy secondaries are not sized like a power branch.",
                "If control power taps the feeder, the primary device is in the panel SCCR. The coils on its load side are not.",
            ],
            stickyAnswer: session.displayedResult.flatMap { plan in
                plan.primaryDeviceAmps.map { "Primary \($0) A" }
            },
            copyText: session.displayedResult.map { plan in
                "CPT primary \(plan.primaryDeviceAmps.map { "\($0) A" } ?? Format.amps(plan.primaryCeilingAmps)), secondary \(plan.secondaryDeviceAmps.map { "\($0) A" } ?? Format.amps(plan.secondaryCeilingAmps))"
            }
        ) {
            NumberField(title: "Transformer", unit: "VA", text: $va, fieldID: "cptVA", onSubmit: calculate)
            NumberField(title: "Primary", unit: "V", text: $primaryVolts, fieldID: "cptVp", onSubmit: calculate)
            NumberField(title: "Secondary", unit: "V", text: $secondaryVolts, fieldID: "cptVs", onSubmit: calculate)
            CalculatorActionBar(onCalculate: calculate, onReset: {
                va = ""
                primaryVolts = ""
                secondaryVolts = ""
                session = ExplicitCalculationState()
            }, onExample: {
                va = "500"
                primaryVolts = "480"
                secondaryVolts = "120"
                session = ExplicitCalculationState()
            }, exampleTitle: "500 VA, 480 to 120")
            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }
            if let plan = session.displayedResult {
                ResultCard(title: "Control power") {
                    ResultRow(label: "Primary current", value: Format.amps(plan.primaryFLA))
                    ResultRow(label: "Primary band", value: Format.percent(plan.primaryPercent))
                    ResultRow(label: "Primary ceiling", value: Format.amps(plan.primaryCeilingAmps))
                    ResultRow(label: "Primary device", value: plan.primaryDeviceAmps.map { "\($0) A" } ?? "—", emphasis: true, tone: Theme.good)
                    ResultRow(label: "Secondary current", value: Format.amps(plan.secondaryFLA))
                    ResultRow(label: "Secondary ceiling", value: Format.amps(plan.secondaryCeilingAmps))
                    ResultRow(label: "Secondary device", value: plan.secondaryDeviceAmps.map { "\($0) A" } ?? "—")
                    Text(plan.bandNote)
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(plan.sccrNote)
                        .font(.subheadline)
                        .foregroundStyle(Theme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(plan.limitedEnergyNote)
                        .font(.subheadline)
                        .foregroundStyle(Theme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 8) {
                    Button("Transformer Sizing") { openRelated(.transformer) }
                        .buttonStyle(.bordered)
                    Button("Short-circuit") { openRelated(.shortCircuit) }
                        .buttonStyle(.bordered)
                }
                .frame(minHeight: Theme.touchTarget)
                ConductorColorGuide(families: [.controlPanel])
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    guard let plan = session.displayedResult else { return }
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .ul508aPanelLab,
                        inputs: ["step": "cpt", "VA": va],
                        outputs: ["primary": plan.primaryDeviceAmps.map(String.init) ?? ""]
                    ))
                }
            }
        }
        .onChange(of: fingerprint) { _, _ in session.markInputsChanged() }
    }

    private func calculate() {
        session.calculate {
            guard let voltAmps = panelParse(va) else { throw CalcError.missing("transformer VA") }
            guard let vp = panelParse(primaryVolts) else { throw CalcError.missing("primary voltage") }
            guard let vs = panelParse(secondaryVolts) else { throw CalcError.missing("secondary voltage") }
            return try PanelControlTransformer.plan(va: voltAmps, primaryVolts: vp, secondaryVolts: vs)
        }
    }
}

struct UL508ANameplateView: View {
    @Environment(\.openRelatedTool) private var openRelated
    @StoredInput(.ul508aPanelLab, "npChecked", default: "") private var checkedRaw
    @StoredInput(.ul508aPanelLab, "npVolts", default: "480") private var volts
    @StoredInput(.ul508aPanelLab, "npSCCRkA", default: "5") private var sccr
    @StoredInput(.ul508aPanelLab, "npFLC", default: "66.5") private var flc
    @StoredInput(.ul508aPanelLab, "npEnclosure", default: "Type 12") private var enclosure
    @StoredInput(.ul508aPanelLab, "npDiagram", default: "E-101") private var diagram
    @StoredInput(.ul508aPanelLab, "npMotor", default: "25") private var motor

    private var checked: Set<String> {
        Set(checkedRaw.split(separator: ",").map(String.init))
    }

    private var marking: String? {
        guard let ka = panelParse(sccr), let voltage = panelParse(volts) else { return nil }
        return PanelSCCR.planningMarking(sccrKA: ka, volts: voltage)
    }

    private var exportText: String {
        var lines: [String] = []
        if let marking { lines.append(marking) }
        if let flcAmps = panelParse(flc) { lines.append("Full-load current \(Format.amps(flcAmps))") }
        if !enclosure.isEmpty { lines.append("Enclosure \(enclosure)") }
        if !diagram.isEmpty { lines.append("Schematic \(diagram)") }
        if !motor.isEmpty { lines.append("Largest motor \(motor) HP") }
        let open = PanelNameplate.prompts.filter { !checked.contains($0.id) }.map(\.title)
        if !open.isEmpty { lines.append("Still open: " + open.joined(separator: ", ")) }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        PanelLabScreen(
            title: "Nameplate & Documentation",
            bullets: [
                "The door should say voltage, full-load current, SCCR, enclosure type, and which drawing matches the panel.",
                "If the SCCR depends on a specific upstream device, the nameplate has to say so.",
                "The sentence below is a planning line. Use the wording your procedure and the listing require.",
                "Panel Directory and Cable Schedule keep the schedule and the cable list. This screen does not replace them.",
            ],
            stickyAnswer: marking.map { _ in "SCCR line ready" },
            copyText: exportText
        ) {
            ForEach(PanelNameplate.prompts) { prompt in
                Button {
                    toggle(prompt.id)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: checked.contains(prompt.id) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(checked.contains(prompt.id) ? Theme.good : Theme.muted)
                            .frame(minWidth: 24, minHeight: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prompt.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.foreground)
                            Text(prompt.detail)
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: Theme.touchTarget, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(prompt.title)
                .accessibilityValue(checked.contains(prompt.id) ? "Checked" : "Not checked")
            }
            NumberField(title: "SCCR", unit: "kA", text: $sccr, fieldID: "npSCCR")
            NumberField(title: "Voltage", unit: "V", text: $volts, fieldID: "npV")
            NumberField(title: "Full-load current", unit: "A", text: $flc, fieldID: "npFLC")
            TextInputField(title: "Enclosure type", text: $enclosure, placeholder: "Type 12", autocapitalization: .words, fieldID: "npEnc")
            TextInputField(title: "Schematic number", text: $diagram, placeholder: "E-101", fieldID: "npDwg")
            TextInputField(title: "Largest motor", text: $motor, placeholder: "25", unit: "HP", fieldID: "npHP")
            if let marking {
                ResultCard(title: "Planning line", copyText: exportText) {
                    Text(marking)
                        .font(.subheadline)
                        .foregroundStyle(Theme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(checked.count) of \(PanelNameplate.prompts.count) markings checked on this phone.")
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                }
            }
            HStack(spacing: 8) {
                Button("Panel Directory") { openRelated(.panelDirectory) }
                    .buttonStyle(.bordered)
                Button("Cable Schedule") { openRelated(.cableSchedule) }
                    .buttonStyle(.bordered)
            }
            .frame(minHeight: Theme.touchTarget)
        }
    }

    private func toggle(_ id: String) {
        var next = checked
        if next.contains(id) { next.remove(id) } else { next.insert(id) }
        checkedRaw = next.sorted().joined(separator: ",")
    }
}
