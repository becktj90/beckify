import SwiftUI
import BeckifyMath

enum PanelLabDisclaimer {
    static let text = Theme.disclaimer + " UL 508A official text and listed components govern. This lab is a planning aid, not a certification."
}

func panelParse(_ text: String) -> Double? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let value = Double(trimmed), value.isFinite else { return nil }
    return value
}

struct PanelLabScreen<Content: View>: View {
    let title: String
    var bullets: [String]
    var stickyAnswer: String? = nil
    var copyText: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .accessibilityAddTraits(.isHeader)
                if !bullets.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("HOW THIS STEP WORKS")
                            .font(.caption.weight(.semibold))
                            .tracking(0.6)
                            .foregroundStyle(Theme.muted)
                        ForEach(bullets, id: \.self) { bullet in
                            Text("• \(bullet)")
                                .font(.subheadline)
                                .foregroundStyle(Theme.foreground)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                content
                PanelCrossLinks()
                DisclaimerBanner(text: PanelLabDisclaimer.text)
            }
            .padding(Theme.Space.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let stickyAnswer, !stickyAnswer.isEmpty {
                StickyAnswerBar(answer: stickyAnswer, copyText: copyText)
            }
        }
    }
}

struct PanelCrossLinks: View {
    @Environment(\.openRelatedTool) private var openRelated

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ALREADY IN THE TOOLBOX")
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.muted)
            Text("Motor FLA, equipment grounding, conduit fill, and NEC ampacity stay in their own tools. This lab does not keep a second copy.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(PanelWiringAdvice.crossLinkToolIDs, id: \.self) { raw in
                if let id = ToolID(rawValue: raw) {
                    let tool = ToolboxCatalog.tool(id)
                    Button {
                        openRelated(id)
                    } label: {
                        Label(tool.title, systemImage: tool.symbol)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: Theme.touchTarget, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                    .accessibilityLabel("Open \(tool.title)")
                }
            }
        }
    }
}

struct WiringAdviceCard: View {
    let advice: WiringMethodAdvice

    var body: some View {
        ResultCard(title: "Wire and conduit for this place") {
            Text(advice.circuit.title + " · " + advice.environment.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.foreground)
            Text("Wire")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
            ForEach(advice.wireTypes, id: \.self) { line in
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Conduit")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .padding(.top, 4)
            ForEach(advice.conduitTypes, id: \.self) { line in
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(advice.why)
                .font(.subheadline)
                .foregroundStyle(Theme.foreground)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            Text(advice.avoid)
                .font(.subheadline)
                .foregroundStyle(Theme.warn)
                .fixedSize(horizontal: false, vertical: true)
            Text(advice.verify)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct AmpacityMeter: View {
    let required: Double
    let capacity: Double

    private var fraction: Double {
        guard capacity > 0 else { return 0 }
        return min(max(required / capacity, 0), 1)
    }

    private var fits: Bool { required <= capacity + 1e-6 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("FILL")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text("\(Format.amps(required)) of \(Format.amps(capacity))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(fits ? Theme.good : Theme.bad)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.border.opacity(0.45))
                    Capsule()
                        .fill(fits ? Theme.good : Theme.bad)
                        .frame(width: max(4, geo.size.width * fraction))
                }
            }
            .frame(height: 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(fits
                ? "Required \(Format.amps(required)) fits in \(Format.amps(capacity))"
                : "Required \(Format.amps(required)) is over \(Format.amps(capacity))")
        }
    }
}

struct PanelOneLineDiagram: View {
    let paths: [SCCRPathLine]
    let panelKA: Double
    let volts: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                oneLineNode(title: "Feeder", detail: "Supply", limiting: false)
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 18, height: 2)
                    .accessibilityHidden(true)
                oneLineNode(
                    title: "Panel",
                    detail: "\(Format.number(panelKA, digits: 1)) kA",
                    limiting: true
                )
            }
            Text("\(Format.number(volts, digits: 0)) V · weakest applicable path")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            ForEach(paths) { path in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(path.limiting ? Theme.bad : Theme.accent.opacity(0.7))
                        .frame(width: 3, height: 28)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(path.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.foreground)
                        Text(path.role.title)
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 8)
                    Text("\(Format.number(path.effectiveKA, digits: 1)) kA")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(path.limiting ? Theme.bad : Theme.good)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (path.limiting ? Theme.bad : Theme.good).opacity(0.12),
                            in: Capsule()
                        )
                        .accessibilityLabel("\(path.name), \(Format.number(path.effectiveKA, digits: 1)) kiloamperes\(path.limiting ? ", limiting" : "")")
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("One-line diagram. Panel \(Format.number(panelKA, digits: 1)) kiloamperes at \(Format.number(volts, digits: 0)) volts.")
    }

    private func oneLineNode(title: String, detail: String, limiting: Bool) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)
            Text(detail)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(limiting ? Theme.bad : Theme.foreground)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(limiting ? Theme.bad.opacity(0.7) : Theme.border, lineWidth: 1)
        )
    }
}

struct ConductorSwatchView: View {
    let swatch: ConductorSwatch

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(panelHex: swatch.hex))
                .overlay {
                    if let ring = swatch.ringHex {
                        Circle().stroke(Color(panelHex: ring), lineWidth: 3)
                    }
                }
                .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
            Text(swatch.name)
                .font(.caption)
                .foregroundStyle(Theme.foreground)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(swatch.name)
    }
}

struct ConductorColorGuide: View {
    var families: [ConductorColorFamily] = ConductorColorFamily.allCases
    @AppStorage(ToolboxPreferenceKey.electricalCode) private var codeRaw = ElectricalCode.nec.rawValue
    @Environment(\.openRelatedTool) private var openRelated

    private var code: ElectricalCode { ElectricalCode(rawValue: codeRaw) ?? .nec }

    private var ordered: [ConductorColorFamily] {
        guard families.contains(.iec) else { return families }
        if PanelConductorColors.emphasizeIEC(code: code) {
            return [.iec] + families.filter { $0 != .iec }
        }
        return families.filter { $0 != .iec } + [.iec]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            if PanelConductorColors.emphasizeIEC(code: code), families.contains(.iec) {
                Text("Settings is AS/NZS. The IEC card is an identification convention for that kind of job. It is not an AS/NZS cable design, and the panel math in this lab is still UL 508A / NEC planning.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(ordered) { family in
                ResultCard(title: family.title) {
                    if family == .iec && !PanelConductorColors.emphasizeIEC(code: code) {
                        Text("Optional. Use this when the job is IEC / EU. Leave it alone on a North American panel.")
                            .font(Theme.TypeRole.help)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(PanelConductorColors.roles(in: family)) { role in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(role.role)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.foreground)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(role.swatches) { swatch in
                                        ConductorSwatchView(swatch: swatch)
                                    }
                                }
                            }
                            Text(role.guidance)
                                .font(.subheadline)
                                .foregroundStyle(Theme.foreground)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(role.authority)
                                .font(Theme.TypeRole.help)
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            Button {
                openRelated(.referenceLibrary)
            } label: {
                Label("Open Reference Library color notes", systemImage: "book")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: Theme.touchTarget, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
        }
    }
}

struct EnvironmentMenu: View {
    @Binding var environment: PanelInstallEnvironment

    var body: some View {
        MenuField(title: "Location", selection: $environment, options: PanelInstallEnvironment.allCases) { $0.title }
    }
}

struct UL508APanelLabView: View {
    @StoredChoice(.ul508aPanelLab, "environment", default: PanelInstallEnvironment.indoorDry)
    private var environment

    var body: some View {
        ToolScaffold(
            toolID: .ul508aPanelLab,
            disclaimer: .designAidExtra("UL 508A official text and listed components govern. This lab is not a certification.")
        ) {
            Text("Shop planning for an industrial control panel. Each step is a calculator or a checklist. Motor FLA, grounding, conduit fill, and NEC ampacity stay where they already live.")
                .font(.subheadline)
                .foregroundStyle(Theme.foreground)
                .fixedSize(horizontal: false, vertical: true)

            EnvironmentMenu(environment: $environment)
            WiringAdviceCard(
                advice: PanelWiringAdvice.recommend(environment: environment, circuit: .powerFeeder)
            )

            VStack(alignment: .leading, spacing: 8) {
                labLink("SCCR Wizard", "Marked ratings or SB4.1-style defaults. Weakest path, with an optional let-through or transformer.") {
                    UL508ASCCRWizardView()
                }
                labLink("Feeder Circuit Sizer", "125% of the largest motor, 125% of heaters, the rest at 100%. Multi-load example.") {
                    UL508AFeederView()
                }
                labLink("Branch / Motor Circuit", "One motor, or a group with the one-tenth tap note. Opens Motor FLA for the table.") {
                    UL508ABranchView()
                }
                labLink("Power & Control Wire", "60°C and 75°C terminal columns, plus the wire and conduit pick for this location.") {
                    UL508AWireView()
                }
                labLink("Wire Colors", "Power phases, grounds, and control-panel colors with swatches. Convention, not a statute.") {
                    UL508AColorView()
                }
                labLink("Disconnect & Enclosure", "NEMA and IP as analogies, disconnect at least the load, clearance prompts.") {
                    UL508AEnclosureView()
                }
                labLink("Control Transformer", "Primary and secondary devices, limited energy, and the SCCR note when control taps the feeder.") {
                    UL508ACPTView()
                }
                labLink("Nameplate & Documentation", "SCCR, voltage, FLC, enclosure, and the schematic — a shop-floor checklist.") {
                    UL508ANameplateView()
                }
            }
        }
    }

    private func labLink<Destination: View>(_ title: String, _ subtitle: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: Theme.touchTarget, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}

struct UL508AColorView: View {
    var body: some View {
        PanelLabScreen(
            title: "Wire Colors",
            bullets: [
                "Power colors are North American convention. High-leg orange is an identification practice — confirm the adopted Code.",
                "Control colors are shop practice: red AC, blue DC, yellow foreign, white or gray grounded, green ground.",
                "Customer spec, UL 508A, and NFPA 79 win when they differ. Nothing here is mandatory law.",
                "AS/NZS in Settings brings the IEC card forward. It does not recolor a 480 V panel by itself.",
            ]
        ) {
            ConductorColorGuide()
        }
    }
}

private extension Color {
    init(panelHex: String) {
        var hex = panelHex
        if hex.hasPrefix("#") { hex.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
