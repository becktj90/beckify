import SwiftUI
import BeckifyMath

private struct SCCRDraft: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var role: SCCRRole
    var useAssumed: Bool
    var kind: SCCRComponentKind
    var markedKA: String
    var volts: String

    static let example: [SCCRDraft] = [
        SCCRDraft(id: "feeder", name: "Feeder breaker", role: .feederProtectiveDevice, useAssumed: false, kind: .circuitBreaker, markedKA: "65", volts: "480"),
        SCCRDraft(id: "contactor", name: "Contactor", role: .loadSideComponent, useAssumed: true, kind: .motorController0to50, markedKA: "", volts: "480"),
        SCCRDraft(id: "block", name: "Terminal block", role: .feederComponent, useAssumed: true, kind: .terminalOrPDB, markedKA: "", volts: "480"),
        SCCRDraft(id: "branch", name: "Branch breaker", role: .branchProtectiveDevice, useAssumed: false, kind: .circuitBreaker, markedKA: "65", volts: "480"),
    ]
}

private enum SCCRLimitMode: String, CaseIterable, Hashable, Identifiable {
    case none
    case fuse
    case breaker
    case transformer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .fuse: return "Current-limiting fuse"
        case .breaker: return "Current-limiting breaker"
        case .transformer: return "Transformer secondary"
        }
    }
}

struct UL508ASCCRWizardView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.ul508aPanelLab, "sccrJSON", default: "") private var sccrJSON
    @StoredChoice(.ul508aPanelLab, "sccrMode", default: SCCRLimitMode.none) private var mode
    @StoredChoice(.ul508aPanelLab, "fuseClass", default: PanelFuseClass.j) private var fuseClass
    @StoredInput(.ul508aPanelLab, "fuseAmps", default: "100") private var fuseAmps
    @StoredInput(.ul508aPanelLab, "prospective", default: "100") private var prospective
    @StoredInput(.ul508aPanelLab, "fuseIR", default: "200") private var fuseIR
    @StoredInput(.ul508aPanelLab, "breakerPeak", default: "14") private var breakerPeak
    @StoredInput(.ul508aPanelLab, "breakerProspective", default: "100") private var breakerProspective
    @StoredInput(.ul508aPanelLab, "breakerIR", default: "65") private var breakerIR
    @StoredInput(.ul508aPanelLab, "xfmrVA", default: "45000") private var xfmrVA
    @StoredInput(.ul508aPanelLab, "xfmrV", default: "480") private var xfmrV
    @StoredInput(.ul508aPanelLab, "xfmrZ", default: "") private var xfmrZ
    @StoredCount(.ul508aPanelLab, "xfmrPhases", default: 3) private var xfmrPhases
    @StoredInput(.ul508aPanelLab, "xfmrPrimaryIR", default: "65") private var xfmrPrimaryIR
    @StoredInput(.ul508aPanelLab, "sccrJob", default: "Panel SCCR") private var jobName
    @State private var drafts: [SCCRDraft] = SCCRDraft.example
    @State private var didLoad = false
    @State private var session = ExplicitCalculationState<PanelSCCRResult>()

    private var fingerprint: String {
        let body = drafts.map { "\($0.id)|\($0.name)|\($0.role)|\($0.useAssumed)|\($0.kind)|\($0.markedKA)|\($0.volts)" }.joined(separator: ";")
        return "\(mode)|\(fuseClass)|\(fuseAmps)|\(prospective)|\(fuseIR)|\(breakerPeak)|\(breakerProspective)|\(breakerIR)|\(xfmrVA)|\(xfmrV)|\(xfmrZ)|\(xfmrPhases)|\(xfmrPrimaryIR)|\(body)"
    }

    var body: some View {
        PanelLabScreen(
            title: "SCCR Wizard",
            bullets: [
                "Enter each power-circuit part with its marked SCCR, or an assumed default labeled per UL 508A Table SB4.1.",
                "A current-limiting fuse uses planning peaks in the Table SB4.2 style. A breaker needs the peak from its curve. A transformer uses VA / (√3·V·%Z), and unmarked %Z is planned at 2.1%.",
                "The panel number is the lowest applicable path. Load-side credit does not raise a feeder block or a branch breaker.",
                "Planning aid. Verify listed combinations and the AHJ. This is not a UL certification.",
            ],
            stickyAnswer: session.displayedResult.map { "\(Format.number($0.panelKA, digits: 1)) kA @ \(Format.number($0.panelVolts, digits: 0)) V" },
            copyText: session.displayedResult.map(copyText)
        ) {
            DisclosureGroup("Assumed defaults") {
                ForEach(SCCRComponentKind.allCases) { kind in
                    HStack(alignment: .firstTextBaseline) {
                        Text(kind.label)
                            .font(.caption)
                            .foregroundStyle(Theme.foreground)
                        Spacer(minLength: 8)
                        Text("\(Format.number(kind.assumedKiloamps, digits: 1)) kA")
                            .font(.caption.monospacedDigit().weight(.semibold))
                    }
                }
                Text(UL508APanelMath.assumedSCCRLabel + ". A meter on a CT or shunt is not given a default here. Mercury-tube rows are omitted — enter a marked rating if you still have one.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.subheadline.weight(.semibold))

            ForEach($drafts) { $draft in
                componentCard($draft)
            }
            Button("Add component") { drafts.append(blankDraft()) }
                .buttonStyle(.bordered)
                .frame(minHeight: Theme.touchTarget)

            MenuField(title: "Feeder current-limiting", selection: $mode, options: SCCRLimitMode.allCases) { $0.title }
            limiterFields

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: applyExample,
                exampleTitle: "5 kA contactor, 65 kA breakers"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }
            if let result = session.displayedResult {
                PanelOneLineDiagram(paths: result.paths, panelKA: result.panelKA, volts: result.panelVolts)
                    .opacity(session.isStale ? 0.72 : 1)
                ResultCard(title: "Nameplate summary", copyText: copyText(result)) {
                    Text(result.marking)
                        .font(.subheadline)
                        .foregroundStyle(Theme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                    if let peak = result.letThroughKA {
                        ResultRow(label: "Planning peak", value: "\(Format.number(peak, digits: 1)) kA")
                    }
                    if let transformer = result.transformer {
                        ResultRow(
                            label: "Secondary Isc",
                            value: "\(Format.amps(transformer.iscAmps)) @ \(Format.number(transformer.percentZUsed, digits: 1))% Z"
                        )
                        if transformer.assumedUnmarkedZ {
                            Text("Unmarked %Z, or a value under 2.1%, is planned at 2.1%.")
                                .font(Theme.TypeRole.help)
                                .foregroundStyle(Theme.warn)
                        }
                    }
                    ForEach(result.notes, id: \.self) { note in
                        Text(note)
                            .font(Theme.TypeRole.help)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    guard let result = session.displayedResult else { return }
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .ul508aPanelLab,
                        inputs: ["step": "sccr", "mode": mode.rawValue],
                        outputs: ["sccrKA": Format.number(result.panelKA, digits: 1), "marking": result.marking]
                    ))
                }
            }
        }
        .onAppear(perform: load)
        .onChange(of: drafts) { _, newValue in
            guard didLoad, let data = try? JSONEncoder().encode(newValue), let text = String(data: data, encoding: .utf8) else { return }
            sccrJSON = text
        }
        .onChange(of: fingerprint) { _, _ in session.markInputsChanged() }
    }

    @ViewBuilder
    private var limiterFields: some View {
        switch mode {
        case .none:
            Text("With no limiter, the panel is the lowest component rating you entered.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
        case .fuse:
            MenuField(title: "Fuse class", selection: $fuseClass, options: PanelFuseClass.allCases) { $0.title }
            NumberField(title: "Fuse rating", unit: "A", text: $fuseAmps, fieldID: "fuseAmps", onSubmit: calculate)
            NumberField(title: "Prospective fault", unit: "kA", text: $prospective, fieldID: "prospective", onSubmit: calculate)
            NumberField(title: "Fuse interrupting rating", unit: "kA", text: $fuseIR, fieldID: "fuseIR", onSubmit: calculate)
            Text(UL508APanelMath.letThroughLabel + ". An in-between ampere rating uses the next listed case size. Confirm the published table and the fuse curve before a nameplate.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        case .breaker:
            NumberField(title: "Peak let-through Ip", unit: "kA", text: $breakerPeak, fieldID: "breakerPeak", onSubmit: calculate)
            NumberField(title: "Prospective fault", unit: "kA", text: $breakerProspective, fieldID: "breakerProspective", onSubmit: calculate)
            NumberField(title: "Breaker interrupting rating", unit: "kA", text: $breakerIR, fieldID: "breakerIR", onSubmit: calculate)
            Text("Only a breaker that is listed and marked current-limiting. This screen does not read the mark. Enter Ip from the manufacturer curve.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        case .transformer:
            NumberField(title: "Transformer", unit: "VA", text: $xfmrVA, fieldID: "xfmrVA", onSubmit: calculate)
            NumberField(title: "Secondary voltage", unit: "V", text: $xfmrV, fieldID: "xfmrV", onSubmit: calculate)
            NumberField(title: "Impedance", unit: "%Z", text: $xfmrZ, optional: true, fieldID: "xfmrZ", onSubmit: calculate)
            Picker("Phases", selection: $xfmrPhases) {
                Text("1Ø").tag(1)
                Text("3Ø").tag(3)
            }
            .segmentedControlStyle()
            NumberField(title: "Primary device IR", unit: "kA", text: $xfmrPrimaryIR, fieldID: "xfmrPrimaryIR", onSubmit: calculate)
            Text("Leave %Z blank when it is unmarked. Blank or under 2.1% is planned at 2.1%. Isc ≈ VA / (√3·V·%Z) on a three-phase secondary. Mark secondary components with the transformer-secondary role.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func componentCard(_ draft: Binding<SCCRDraft>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextInputField(title: "Name", text: draft.name, placeholder: "Contactor", fieldID: "name-\(draft.wrappedValue.id)")
                Button(role: .destructive) {
                    drafts.removeAll { $0.id == draft.wrappedValue.id }
                } label: {
                    Image(systemName: "trash")
                        .frame(minWidth: Theme.touchTarget, minHeight: Theme.touchTarget)
                }
                .accessibilityLabel("Remove \(draft.wrappedValue.name)")
                .disabled(drafts.count <= 1)
            }
            MenuField(title: "Role", selection: draft.role, options: SCCRRole.allCases) { $0.title }
            Toggle("Use assumed default", isOn: draft.useAssumed)
                .font(.subheadline)
            if draft.wrappedValue.useAssumed {
                MenuField(title: "Component", selection: draft.kind, options: SCCRComponentKind.allCases) { $0.label }
                Text("\(UL508APanelMath.assumedSCCRLabel): \(Format.number(draft.wrappedValue.kind.assumedKiloamps, digits: 1)) kA. \(draft.wrappedValue.kind.assumptionNote)")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                NumberField(title: "Marked SCCR", unit: "kA", text: draft.markedKA, fieldID: "ka-\(draft.wrappedValue.id)", onSubmit: calculate)
            }
            NumberField(title: "Voltage", unit: "V", text: draft.volts, fieldID: "v-\(draft.wrappedValue.id)", onSubmit: calculate)
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }

    private func calculate() {
        session.calculate {
            let components = try drafts.enumerated().map { index, draft in
                try component(from: draft, index: index)
            }
            return try PanelSCCR.aggregate(components: components, limit: try limiter())
        }
    }

    private func component(from draft: SCCRDraft, index: Int) throws -> SCCRComponent {
        let kiloamps: Double
        let source: SCCRRatingSource
        if draft.useAssumed {
            kiloamps = draft.kind.assumedKiloamps
            source = .assumedSB41
        } else if let marked = panelParse(draft.markedKA) {
            kiloamps = marked
            source = .marked
        } else {
            throw CalcError.missing("marked SCCR for \(draft.name.isEmpty ? "component \(index + 1)" : draft.name)")
        }
        guard let volts = panelParse(draft.volts) else {
            throw CalcError.missing("voltage for \(draft.name.isEmpty ? "component \(index + 1)" : draft.name)")
        }
        return SCCRComponent(
            id: draft.id,
            name: draft.name.isEmpty ? "Component \(index + 1)" : draft.name,
            role: draft.role,
            kiloamps: kiloamps,
            volts: volts,
            source: source
        )
    }

    private func limiter() throws -> PanelCurrentLimit {
        switch mode {
        case .none:
            return .none
        case .fuse:
            guard let amps = panelParse(fuseAmps) else { throw CalcError.missing("fuse rating") }
            guard let prospectiveKA = panelParse(prospective) else { throw CalcError.missing("prospective fault") }
            guard let interrupt = panelParse(fuseIR) else { throw CalcError.missing("fuse interrupting rating") }
            return .fuse(fuseClass: fuseClass, amps: amps, prospectiveKA: prospectiveKA, interruptKA: interrupt)
        case .breaker:
            guard let peak = panelParse(breakerPeak) else { throw CalcError.missing("breaker peak let-through") }
            guard let prospectiveKA = panelParse(breakerProspective) else { throw CalcError.missing("prospective fault") }
            guard let interrupt = panelParse(breakerIR) else { throw CalcError.missing("breaker interrupting rating") }
            return .breaker(peakLetThroughKA: peak, prospectiveKA: prospectiveKA, interruptKA: interrupt)
        case .transformer:
            guard let va = panelParse(xfmrVA) else { throw CalcError.missing("transformer VA") }
            guard let volts = panelParse(xfmrV) else { throw CalcError.missing("secondary voltage") }
            guard let primary = panelParse(xfmrPrimaryIR) else { throw CalcError.missing("primary device interrupting rating") }
            return .transformer(
                va: va,
                secondaryVolts: volts,
                percentZ: panelParse(xfmrZ),
                phases: xfmrPhases,
                primaryInterruptKA: primary
            )
        }
    }

    private func copyText(_ result: PanelSCCRResult) -> String {
        var lines = [result.marking]
        for path in result.paths {
            lines.append("\(path.name): \(Format.number(path.effectiveKA, digits: 1)) kA\(path.limiting ? " (limiting)" : "")")
        }
        return lines.joined(separator: "\n")
    }

    private func blankDraft() -> SCCRDraft {
        SCCRDraft(id: UUID().uuidString, name: "", role: .loadSideComponent, useAssumed: true, kind: .overloadRelay, markedKA: "", volts: "480")
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let data = sccrJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([SCCRDraft].self, from: data),
              !decoded.isEmpty else { return }
        drafts = decoded
    }

    private func reset() {
        drafts = [blankDraft()]
        mode = .none
        session = ExplicitCalculationState()
    }

    private func applyExample() {
        drafts = SCCRDraft.example
        mode = .none
        session = ExplicitCalculationState()
    }
}
