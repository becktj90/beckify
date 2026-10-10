import SwiftUI
import BeckifyMath

// MARK: - NEC 500–506 hazardous locations guide + Article 490 card

struct HazardousLocationsView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case classify = "Classify"
        case tcode = "T-code"
        case methods = "Methods"
        case wiring = "Wiring"
        case art490 = "Art. 490"
        var id: String { rawValue }
    }

    @StoredInput(.hazardousLocations, "tab", default: "Classify") private var tabRaw
    @StoredInput(.hazardousLocations, "material", default: HazMaterial.gasVapor.rawValue) private var materialRaw
    @StoredInput(.hazardousLocations, "presence", default: HazPresence.normal.rawValue) private var presenceRaw
    @StoredInput(.hazardousLocations, "group", default: HazGroup.d.rawValue) private var groupRaw
    @StoredToggle(.hazardousLocations, "zoneSystem", default: false) private var zoneSystem
    @StoredInput(.hazardousLocations, "ait", default: "280") private var ait
    @StoredInput(.hazardousLocations, "methodArea", default: HazArea.c1d1.rawValue) private var methodAreaRaw

    private var tab: Tab { Tab(rawValue: tabRaw) ?? .classify }
    private var material: HazMaterial { HazMaterial(rawValue: materialRaw) ?? .gasVapor }
    private var presence: HazPresence { HazPresence(rawValue: presenceRaw) ?? .normal }

    /// Group only applies when it belongs to the chosen material; Class III has none.
    private var group: HazGroup? {
        guard let g = HazGroup(rawValue: groupRaw), g.material == material else { return nil }
        return g
    }

    private var classification: HazClassification? {
        try? HazClassifier.classify(material: material, presence: presence, group: group)
    }

    var body: some View {
        ToolScaffold(toolID: .hazardousLocations, stickyAnswer: sticky, copyText: sticky) {
            Picker("Section", selection: $tabRaw) {
                ForEach(Tab.allCases) { t in Text(t.rawValue).tag(t.rawValue) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("hazardousLocations.tab")

            switch tab {
            case .classify: classify
            case .tcode: tcodeSection
            case .methods: methods
            case .wiring:
                CodeReferenceCardsView(heading: "Wiring methods and seals", cards: HazLocReference.wiringAndSeals)
            case .art490:
                CodeReferenceCardsView(heading: "Article 490 — equipment over 1000 V (not hazardous locations)", cards: HazLocReference.article490)
            }

            Text(HazLocReference.governs)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
        }
    }

    // MARK: Classify

    @ViewBuilder private var classify: some View {
        MenuField(title: "What can burn", selection: $materialRaw, options: HazMaterial.allCases.map(\.rawValue)) {
            HazMaterial(rawValue: $0)?.displayName ?? $0
        }
        MenuField(title: "How often it is present", selection: $presenceRaw, options: HazPresence.allCases.map(\.rawValue)) {
            HazPresence(rawValue: $0)?.displayName ?? $0
        }
        if material != .fibers {
            MenuField(title: "Group", selection: $groupRaw, options: HazGroup.groups(for: material).map(\.rawValue)) { raw in
                guard let g = HazGroup(rawValue: raw) else { return raw }
                return "Group \(g.letter) — \(g.examples)"
            }
            if group == nil {
                Text("Pick a group for this material.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.warn)
            }
        }
        Toggle("Show methods for the Zone system", isOn: $zoneSystem)
            .tint(Theme.accent)
            .frame(minHeight: Theme.touchTarget)

        if let c = classification {
            ResultCard(title: "Classification", copyText: "\(c.divisionLabel) · \(c.zoneLabel)") {
                ResultRow(label: "Division system (Art. \(material.divisionArticle))", value: c.divisionLabel, emphasis: true, tone: Theme.copper)
                ResultRow(label: "Zone system (Art. \(material.zoneArticle))", value: c.zoneLabel, emphasis: true)
                ResultRow(label: "Rules", value: "500.5, 500.6, \(material.zoneArticle).5")
                ForEach(c.notes, id: \.self) { note in
                    Text(note)
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                        .padding(.vertical, 2)
                }
            }
            let area = HazArea.from(c, zoneSystem: zoneSystem)
            techniqueCard(area)
        }
    }

    // MARK: T-code

    @ViewBuilder private var tcodeSection: some View {
        NumberField(title: "Autoignition temperature", unit: "°C", text: $ait,
                    helpText: "From the SDS or NFPA 497 / 499 tables. Gasoline is about 280 °C.", fieldID: "ait")
        let value = ait.parsedDouble ?? .nan
        if value.isFinite {
            if let code = TemperatureCodes.minimumCode(forAutoignitionC: value) {
                let zoneCode = TemperatureCodes.minimumCode(forAutoignitionC: value, zoneOnly: true)
                ResultCard(title: "Equipment T-code") {
                    ResultRow(label: "Hottest acceptable (Division)", value: "\(code.code) · ≤ \(Format.number(code.maxSurfaceC)) °C", emphasis: true, tone: Theme.copper)
                    ResultRow(label: "Hottest acceptable (Zone, T1–T6)", value: zoneCode.map { "\($0.code) · ≤ \(Format.number($0.maxSurfaceC)) °C" } ?? "—")
                    ResultRow(label: "Rule", value: "500.8(D), 505.9(D)")
                    Text("Any cooler code (higher number) is also fine. Dust layers have their own surface-temperature limits (500.8(D)(2)).")
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                }
            } else {
                ErrorText(message: "No T-code reaches below \(Format.number(value)) °C; T6 is 85 °C. Ask the manufacturer or keep equipment out of the area.")
            }
        } else {
            ErrorText(message: CalcError.missing("autoignition temperature").message)
        }
        ResultCard(title: "T-code table") {
            ForEach(TemperatureCodes.table) { t in
                let ok = value.isFinite && TemperatureCodes.permits(t, autoignitionC: value)
                ResultRow(
                    label: t.zoneMarking ? t.code : "\(t.code) (Division only)",
                    value: "\(Format.number(t.maxSurfaceC)) °C",
                    tone: value.isFinite ? (ok ? Theme.good : Theme.bad) : Theme.foreground
                )
            }
        }
    }

    // MARK: Methods

    @ViewBuilder private var methods: some View {
        MenuField(title: "Area", selection: $methodAreaRaw, options: HazArea.allCases.map(\.rawValue)) {
            HazArea(rawValue: $0)?.displayName ?? $0
        }
        techniqueCard(HazArea(rawValue: methodAreaRaw) ?? .c1d1)
        ResultCard(title: "All techniques") {
            ForEach(ProtectionTechniques.all) { t in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(t.name) (\(t.marking)) · \(t.citation)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                    Text(HazArea.allCases.filter { t.allowed.contains($0) }.map(\.displayName).joined(separator: ", "))
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.accent)
                    Text(t.idea)
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func techniqueCard(_ area: HazArea) -> some View {
        ResultCard(title: "Allowed in \(area.displayName)") {
            ForEach(ProtectionTechniques.allowed(in: area)) { t in
                ResultRow(label: "\(t.name) (\(t.marking))", value: t.citation)
            }
        }
    }

    private var sticky: String? {
        guard tab == .classify, let c = classification else { return nil }
        return "\(c.divisionLabel) · \(c.zoneLabel)"
    }
}
