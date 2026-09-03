import SwiftUI
import BeckifyMath

struct ReceptacleSelectorView: View {
    private struct CommittedSelection: Equatable, Sendable {
        var matches: [ReceptacleMatch]
        var volts: Double
        var amps: Double
        var phase: ReceptaclePhaseKind
    }

    @EnvironmentObject private var jobs: JobStore

    @StoredChoice(.receptacleSelector, "voltagePreset", default: ReceptacleVoltagePreset.v120) private var voltagePreset
    @StoredInput(.receptacleSelector, "customVolts", default: "120") private var customVolts
    @StoredChoice(.receptacleSelector, "phase", default: ReceptaclePhaseKind.singlePhase2Wire) private var phase
    @StoredChoice(.receptacleSelector, "ampPreset", default: ReceptacleAmpPreset.a15) private var ampPreset
    @StoredInput(.receptacleSelector, "customAmps", default: "15") private var customAmps
    @StoredChoice(.receptacleSelector, "environment", default: ReceptacleEnvironment.indoorDry) private var environment
    @StoredChoice(.receptacleSelector, "family", default: ReceptacleFamilyFilter.any) private var family
    @StoredChoice(.receptacleSelector, "neutral", default: NeutralChoice.auto) private var neutral
    @StoredToggle(.receptacleSelector, "isolatedGround", default: false) private var isolatedGround
    @StoredToggle(.receptacleSelector, "preferGFCI", default: false) private var preferGFCI
    @StoredNumber(.receptacleSelector, "frequencyHz", default: 60) private var frequencyHz
    @State private var selectedID: String?
    @StoredInput(.receptacleSelector, "jobName", default: "Receptacle") private var jobName
    @State private var session = ExplicitCalculationState<CommittedSelection>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        "\(voltagePreset)|\(customVolts)|\(phase)|\(ampPreset)|\(customAmps)|\(environment)|\(family)|\(neutral)|\(isolatedGround)|\(preferGFCI)|\(frequencyHz)"
    }

    private var volts: Double? {
        voltagePreset == .custom ? customVolts.parsedDouble : voltagePreset.volts
    }

    private var amps: Double? {
        ampPreset == .custom ? customAmps.parsedDouble : ampPreset.amps
    }

    private var query: ReceptacleQuery? {
        guard let volts, let amps else { return nil }
        return ReceptacleQuery(
            volts: volts,
            phase: phase,
            amps: amps,
            environment: environment,
            family: family,
            isolatedGround: isolatedGround,
            preferGFCI: preferGFCI,
            frequencyHz: frequencyHz,
            neutral: neutral
        )
    }

    var body: some View {
        ToolScaffold(
            toolID: .receptacleSelector,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .designAidExtra("Not a UL listing, distributor cross, or classified-area stamp. Confirm current catalog before you buy or install."),
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .receptacleSelector,
                symbolic: "Match V · Ø · A · poles/wires to a NEMA or IEC 60309 face",
                substituted: substituted,
                meaning: "Best-fit is a configuration match, not a listing. Hazardous is a flag only — not a classified-area stamp. Isolated ground and GFCI are callouts, not a different face."
            )
            MenuField(title: "Voltage", selection: $voltagePreset, options: ReceptacleVoltagePreset.allCases) {
                $0 == .custom ? "Custom" : "\($0.rawValue) V"
            }
            if voltagePreset == .custom {
                NumberField(title: "Custom voltage", unit: "V", text: $customVolts)
            }

            Picker("Phase", selection: $phase) {
                ForEach(ReceptaclePhaseKind.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            MenuField(title: "Current / ampacity", selection: $ampPreset, options: ReceptacleAmpPreset.allCases) {
                $0 == .custom ? "Custom" : "\($0.rawValue) A"
            }
            if ampPreset == .custom {
                NumberField(title: "Custom current", unit: "A", text: $customAmps)
            }

            MenuField(title: "Location / environment", selection: $environment, options: ReceptacleEnvironment.allCases) { $0.displayName }
            if environment == .hazardous {
                Text("See listing / not a classified-area stamp. This tool will not pick a Class/Division or Zone fitting.")
                    .font(.caption)
                    .foregroundStyle(Theme.warn)
            }

            MenuField(title: "Device family", selection: $family, options: ReceptacleFamilyFilter.allCases) { $0.displayName }

            Picker("Neutral", selection: $neutral) {
                ForEach(NeutralChoice.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            Toggle("Isolated ground", isOn: $isolatedGround)
                .tint(Theme.accent)
                .frame(minHeight: Theme.touchTarget)
            Toggle("Call out GFCI where it applies", isOn: $preferGFCI)
                .tint(Theme.accent)
                .frame(minHeight: Theme.touchTarget)

            VStack(alignment: .leading, spacing: 6) {
                Text("FREQUENCY")
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.muted)
                Picker("Hz", selection: $frequencyHz) {
                    Text("60 Hz").tag(60.0)
                    Text("50 Hz").tag(50.0)
                }
                .pickerStyle(.segmented)
                Text("50 vs 60 Hz only changes IEC clock rows (e.g. 277 V 1P+N+E is 5h at 60 Hz). NEMA faces do not change.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: {
                    voltagePreset = .v120
                    phase = .singlePhase2Wire
                    ampPreset = .a15
                    environment = .indoorDry
                    family = .any
                    neutral = .auto
                    isolatedGround = false
                    preferGFCI = false
                    frequencyHz = 60
                    selectedID = nil
                    session.prepareForNewInputs()
                },
                exampleTitle: "120 V 1Ø 15 A indoor"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let committed = session.displayedResult {
                let list = committed.matches
                let shown = selected(from: list)
                Group {
                    ReceptacleFaceCard(match: shown)
                    ResultCard(title: "Best fit", copyText: copyText) {
                        ResultRow(label: "Configuration", value: shown.config.code, emphasis: true, tone: Theme.good)
                        ResultRow(label: "Family", value: shown.config.family.displayName)
                        ResultRow(label: "Voltage window", value: shown.config.voltageLabel)
                        ResultRow(label: "Poles / wires", value: shown.config.polesWiresLabel)
                        ResultRow(label: "Device rating", value: Format.amps(shown.config.amps))
                        if let hour = shown.config.iecEarthHour {
                            ResultRow(label: "IEC earth", value: "\(hour)h · \(shown.config.iecColor ?? "")")
                        }
                    }
                    ResultCard(title: "Why it fits") {
                        ForEach(shown.reasons, id: \.self) { reason in
                            Text("• \(reason)")
                                .font(.subheadline)
                                .foregroundStyle(Theme.foreground)
                                .padding(.vertical, 2)
                        }
                    }
                    if !shown.caveats.isEmpty {
                        ResultCard(title: "Notes") {
                            ForEach(shown.caveats, id: \.self) { note in
                                Text("• \(note)")
                                    .font(.caption)
                                    .foregroundStyle(Theme.warn)
                                    .padding(.vertical, 2)
                            }
                        }
                    }
                    catalogCard(shown)
                    rankedList(list)
                }
                .opacity(session.isStale ? 0.72 : 1)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    save(committed)
                }
            }
        }
        .onChange(of: voltagePreset) { _, _ in
            selectedID = nil
            session.markInputsChanged()
        }
        .onChange(of: phase) { _, _ in
            selectedID = nil
            session.markInputsChanged()
        }
        .onChange(of: ampPreset) { _, _ in
            selectedID = nil
            session.markInputsChanged()
        }
        .onChange(of: family) { _, _ in
            selectedID = nil
            session.markInputsChanged()
        }
        .onChange(of: environment) { _, _ in
            selectedID = nil
            session.markInputsChanged()
        }
        .onChange(of: isolatedGround) { _, _ in session.markInputsChanged() }
        .onChange(of: preferGFCI) { _, _ in session.markInputsChanged() }
        .onChange(of: neutral) { _, _ in session.markInputsChanged() }
        .onChange(of: frequencyHz) { _, _ in session.markInputsChanged() }
        .onChange(of: customVolts) { _, _ in session.markInputsChanged() }
        .onChange(of: customAmps) { _, _ in session.markInputsChanged() }
        .onChange(of: inputFingerprint) { _, _ in session.markInputsChanged() }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func calculate() {
        session.calculate {
            guard let query else { throw CalcError.missing("voltage and current") }
            selectedID = nil
            let matches = try ReceptacleSelector.select(query)
            return CommittedSelection(
                matches: matches,
                volts: query.volts,
                amps: query.amps,
                phase: query.phase
            )
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    private func reset() {
        voltagePreset = .v120
        customVolts = "120"
        phase = .singlePhase2Wire
        ampPreset = .a15
        customAmps = "15"
        environment = .indoorDry
        family = .any
        neutral = .auto
        isolatedGround = false
        preferGFCI = false
        frequencyHz = 60
        selectedID = nil
        session.reset()
    }

    private var substituted: String? {
        guard let committed = session.displayedResult else { return nil }
        let shown = selected(from: committed.matches)
        let v = Format.number(committed.volts, digits: 0)
        let a = Format.number(committed.amps, digits: 0)
        return "\(v) V · \(committed.phase.displayName) · \(a) A → \(shown.config.code) (\(shown.config.family.displayName))"
    }

    private var sticky: String? {
        guard let committed = session.displayedResult else { return nil }
        let shown = selected(from: committed.matches)
        return "\(shown.config.code)  ·  \(Format.amps(shown.config.amps))"
    }

    private var copyText: String? { sticky }

    private func selected(from list: [ReceptacleMatch]) -> ReceptacleMatch {
        if let selectedID, let hit = list.first(where: { $0.id == selectedID }) {
            return hit
        }
        return list[0]
    }

    private func rankedList(_ list: [ReceptacleMatch]) -> some View {
        ResultCard(title: "Ranked configurations") {
            ForEach(list) { match in
                Button {
                    selectedID = match.id
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(selected(from: list).id == match.id ? Theme.accent : Theme.border)
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(match.config.code)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.foreground)
                            Text("\(match.config.family.displayName) · \(match.config.voltageLabel) · \(Format.amps(match.config.amps))")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .frame(minHeight: Theme.touchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Select configuration \(match.config.code)")
                .accessibilityHint("\(match.config.family.displayName), \(match.config.voltageLabel), \(Format.amps(match.config.amps))")
                .accessibilityAddTraits(selected(from: list).id == match.id ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private func catalogCard(_ match: ReceptacleMatch) -> some View {
        ResultCard(title: "Public catalog PNs") {
            if let fallback = match.catalogFallback {
                Text(fallback)
                    .font(.subheadline)
                    .foregroundStyle(Theme.warn)
            }
            ForEach(match.catalog, id: \.self) { part in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(part.maker)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                        Spacer()
                        Text(part.partNumber)
                            .font(.body.monospaced().weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    if !part.note.isEmpty {
                        Text(part.note)
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                    }
                    if let url = URL(string: part.sourceURL), !part.sourceURL.isEmpty {
                        Link("\(part.partNumber) catalog", destination: url)
                            .font(.caption2)
                            .accessibilityLabel("Public catalog page for \(part.maker) \(part.partNumber)")
                    }
                }
                .padding(.vertical, 6)
            }
            Text("PNs are well-known public catalog numbers, not a live stock check. Confirm current catalog. This app is not a distributor.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
        }
    }

    private func save(_ committed: CommittedSelection) {
        let list = committed.matches
        let top = selected(from: list)
        let inputs: [String: String] = [
            "V": Format.number(committed.volts, digits: 1),
            "phase": committed.phase.displayName,
            "A": Format.number(committed.amps, digits: 1),
            "env": environment.displayName,
            "family": family.displayName,
            "N": neutral.displayName,
            "Hz": frequencyHz == 50 ? "50" : "60",
            "IG": isolatedGround ? "yes" : "no",
        ]
        var outputs: [String: String] = [
            "top": top.config.code,
            "why": top.reasons.joined(separator: "; "),
        ]
        if let pn = top.catalog.first {
            outputs["pn"] = "\(pn.maker) \(pn.partNumber)"
        } else if let fallback = top.catalogFallback {
            outputs["pn"] = fallback
        }
        let ranked = list.prefix(3).map(\.config.code).joined(separator: ", ")
        outputs["ranked"] = ranked
        jobs.save(SavedJob(
            name: jobName,
            toolID: .receptacleSelector,
            notes: top.caveats.joined(separator: " "),
            inputs: inputs,
            outputs: outputs
        ))
    }
}

struct ReceptacleFaceCard: View {
    let match: ReceptacleMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PINOUT")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
            ReceptacleFaceView(diagram: match.config.face)
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
            Text(match.config.face.caption)
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            HStack(spacing: 12) {
                ForEach(legend, id: \.kind) { item in
                    HStack(spacing: 4) {
                        Circle().fill(item.color).frame(width: 8, height: 8)
                        Text(item.label)
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
        }
    }

    private var legend: [(kind: ContactKind, label: String, color: Color)] {
        match.config.face.pins.map { pin in
            (kind: pin.kind, label: pin.label, color: ReceptacleFaceView.color(for: pin.kind))
        }
        .reduce(into: []) { acc, item in
            if !acc.contains(where: { $0.kind == item.kind }) { acc.append(item) }
        }
    }
}

struct ReceptacleFaceView: View {
    let diagram: FaceDiagram

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let cx = size.width / 2
            let cy = size.height / 2
            let r = s * 0.38

            let face = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            context.fill(face, with: .color(Color.white.opacity(0.06)))
            context.stroke(face, with: .color(Theme.border), lineWidth: 2)

            if diagram.keywayAtSix {
                var key = Path()
                let kw = r * 0.16
                key.addRect(CGRect(x: cx - kw / 2, y: cy + r - 4, width: kw, height: 14))
                context.fill(key, with: .color(Theme.background))
                context.stroke(key, with: .color(Theme.border), lineWidth: 1)
            }

            if diagram.kind == .iecClock {
                for h in 0..<12 {
                    let ang = Double(h) * .pi / 6 - .pi / 2
                    let inner = r * 0.88
                    let outer = r * 0.96
                    var tick = Path()
                    tick.move(to: CGPoint(x: cx + inner * cos(ang), y: cy + inner * sin(ang)))
                    tick.addLine(to: CGPoint(x: cx + outer * cos(ang), y: cy + outer * sin(ang)))
                    context.stroke(tick, with: .color(Theme.muted.opacity(h == (diagram.earthHour ?? -1) % 12 ? 1 : 0.35)), lineWidth: h % 3 == 0 ? 2 : 1)
                }
                if let hour = diagram.earthHour {
                    let label = Text("\(hour)h")
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .foregroundColor(Theme.accent)
                    context.draw(label, at: CGPoint(x: cx, y: cy - r - 14))
                }
            }

            for pin in diagram.pins {
                let px = cx + pin.x * r
                let py = cy - pin.y * r
                let color = Self.color(for: pin.kind)
                switch pin.shape {
                case .slotVertical:
                    let rect = CGRect(x: px - 6, y: py - 18, width: 12, height: 36)
                    context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(color))
                case .slotHorizontal:
                    let rect = CGRect(x: px - 18, y: py - 6, width: 36, height: 12)
                    context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(color))
                case .slotT:
                    let v = CGRect(x: px - 6, y: py - 18, width: 12, height: 36)
                    let h = CGRect(x: px - 18, y: py - 6, width: 36, height: 12)
                    context.fill(Path(roundedRect: v, cornerRadius: 3), with: .color(color))
                    context.fill(Path(roundedRect: h, cornerRadius: 3), with: .color(color))
                case .uGround:
                    var u = Path()
                    u.addArc(center: CGPoint(x: px, y: py), radius: 11, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
                    context.stroke(u, with: .color(color), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                case .round:
                    context.fill(Path(ellipseIn: CGRect(x: px - 9, y: py - 9, width: 18, height: 18)), with: .color(color.opacity(0.85)))
                    context.stroke(Path(ellipseIn: CGRect(x: px - 9, y: py - 9, width: 18, height: 18)), with: .color(color), lineWidth: 1.5)
                case .roundLarge:
                    context.fill(Path(ellipseIn: CGRect(x: px - 12, y: py - 12, width: 24, height: 24)), with: .color(color.opacity(0.9)))
                    context.stroke(Path(ellipseIn: CGRect(x: px - 12, y: py - 12, width: 24, height: 24)), with: .color(color), lineWidth: 2)
                }
                let label = Text(pin.label)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(Theme.foreground)
                context.draw(label, at: CGPoint(x: px, y: py + 22))
            }
        }
        .accessibilityLabel(diagram.caption)
    }

    static func color(for kind: ContactKind) -> Color {
        switch kind {
        case .line1: return Color(red: 0.96, green: 0.62, blue: 0.25)
        case .line2: return Color(red: 0.95, green: 0.42, blue: 0.42)
        case .line3: return Theme.accent
        case .neutral: return Color(red: 0.82, green: 0.84, blue: 0.90)
        case .ground: return Theme.good
        }
    }
}
