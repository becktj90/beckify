import Foundation

/// Lookup tables an engineer reads rather than calculates. Everything here is
/// a published classification, standard value, or code-table entry — nothing
/// is derived, so the tests check shape and known spot values, not arithmetic.
public struct ReferenceEntry: Identifiable, Equatable, Sendable {
    public var id: String { code }
    /// The short designation people actually say out loud: "4X", "IP67", "3/8-16".
    public var code: String
    public var title: String
    public var detail: String

    public init(code: String, title: String, detail: String) {
        self.code = code
        self.title = title
        self.detail = detail
    }
}

public struct ReferenceTopic: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    /// One line on when you would actually open this table.
    public var purpose: String
    public var entries: [ReferenceEntry]
    /// Where the classification comes from.
    public var source: String

    public init(id: String, title: String, purpose: String, source: String, entries: [ReferenceEntry]) {
        self.id = id
        self.title = title
        self.purpose = purpose
        self.source = source
        self.entries = entries
    }
}

public enum ReferenceLibrary {
    public static var topics: [ReferenceTopic] {
        [
            nemaEnclosures, ipRatings, conductorColors, hazardousAreas,
            conductorInsulation, boltTorque, conduitFittings, standardSizes,
        ]
    }

    public static func topic(id: String) -> ReferenceTopic? {
        topics.first { $0.id == id }
    }

    /// Search across code, title, and detail. Empty query returns everything.
    public static func matching(_ query: String) -> [ReferenceTopic] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return topics }
        return topics.compactMap { topic in
            if topic.title.lowercased().contains(q) || topic.purpose.lowercased().contains(q) {
                return topic
            }
            let hits = topic.entries.filter {
                $0.code.lowercased().contains(q)
                    || $0.title.lowercased().contains(q)
                    || $0.detail.lowercased().contains(q)
            }
            guard !hits.isEmpty else { return nil }
            var narrowed = topic
            narrowed.entries = hits
            return narrowed
        }
    }

    // MARK: - Enclosures

    public static let nemaEnclosures = ReferenceTopic(
        id: "nema-enclosures",
        title: "NEMA Enclosure Types",
        purpose: "Picking a box for where it is actually mounted — indoors, wash-down, or outside in the weather.",
        source: "NEMA 250",
        entries: [
            ReferenceEntry(code: "1", title: "Indoor, general purpose", detail: "Keeps fingers out and catches falling dirt. No liquid rating at all."),
            ReferenceEntry(code: "2", title: "Indoor, dripping", detail: "Type 1 plus limited dripping and light splashing."),
            ReferenceEntry(code: "3", title: "Outdoor", detail: "Rain, sleet, windblown dust. Undamaged by ice on the outside."),
            ReferenceEntry(code: "3R", title: "Outdoor, rainproof", detail: "The common outdoor disconnect. Rain, sleet, and ice — but not windblown dust."),
            ReferenceEntry(code: "4", title: "Indoor/outdoor, watertight", detail: "Hose-directed water. The usual choice for wash-down areas."),
            ReferenceEntry(code: "4X", title: "Watertight, corrosion resistant", detail: "Type 4 plus corrosion resistance — stainless or non-metallic. Food plants, coastal, chemical."),
            ReferenceEntry(code: "6", title: "Occasional submersion", detail: "Temporary submersion at limited depth."),
            ReferenceEntry(code: "6P", title: "Prolonged submersion", detail: "Extended submersion at limited depth."),
            ReferenceEntry(code: "7", title: "Class I, Div 1 explosionproof", detail: "Contains an internal explosion of a gas or vapour so it cannot ignite the room."),
            ReferenceEntry(code: "9", title: "Class II, Div 1 dust-ignitionproof", detail: "Combustible dust. Keeps dust out and the surface cool."),
            ReferenceEntry(code: "12", title: "Industrial, dust and drip", detail: "The standard indoor panel enclosure. Circulating dust, lint, and dripping non-corrosive liquid."),
            ReferenceEntry(code: "13", title: "Oil and coolant", detail: "Type 12 plus sprayed oil and non-corrosive coolant. Machine tools."),
        ]
    )

    public static let ipRatings = ReferenceTopic(
        id: "ip-ratings",
        title: "IP Rating Chart",
        purpose: "Reading the two digits on an imported device — first is solids, second is liquids.",
        source: "IEC 60529",
        entries: [
            ReferenceEntry(code: "IP0X", title: "Solids: none", detail: "No protection against solid objects."),
            ReferenceEntry(code: "IP1X", title: "Solids: >50 mm", detail: "Back of a hand. Not fingers."),
            ReferenceEntry(code: "IP2X", title: "Solids: >12.5 mm", detail: "A finger. This is the finger-safe line."),
            ReferenceEntry(code: "IP3X", title: "Solids: >2.5 mm", detail: "Tools and thick wires."),
            ReferenceEntry(code: "IP4X", title: "Solids: >1 mm", detail: "Most wires and screws."),
            ReferenceEntry(code: "IP5X", title: "Solids: dust protected", detail: "Dust gets in but not enough to interfere."),
            ReferenceEntry(code: "IP6X", title: "Solids: dust tight", detail: "No dust ingress at all."),
            ReferenceEntry(code: "IPX0", title: "Liquids: none", detail: "No protection against water."),
            ReferenceEntry(code: "IPX1", title: "Liquids: dripping", detail: "Vertically falling drops."),
            ReferenceEntry(code: "IPX3", title: "Liquids: spraying", detail: "Spray up to 60° from vertical."),
            ReferenceEntry(code: "IPX4", title: "Liquids: splashing", detail: "Splashing from any direction."),
            ReferenceEntry(code: "IPX5", title: "Liquids: jetting", detail: "6.3 mm nozzle from any direction."),
            ReferenceEntry(code: "IPX6", title: "Liquids: powerful jets", detail: "12.5 mm nozzle. Roughly the NEMA 4 hose test."),
            ReferenceEntry(code: "IPX7", title: "Liquids: immersion 1 m", detail: "30 minutes at up to one metre."),
            ReferenceEntry(code: "IPX8", title: "Liquids: continuous immersion", detail: "Deeper or longer than IPX7, to the maker's stated conditions."),
            ReferenceEntry(code: "IPX9K", title: "Liquids: high-pressure steam", detail: "Close-range high-temperature jets. Vehicle and food-plant wash-down."),
        ]
    )

    // MARK: - Colours

    public static let conductorColors = ReferenceTopic(
        id: "conductor-colors",
        title: "Conductor Colors",
        purpose: "Identifying a conductor in a panel you did not wire.",
        source: "NEC 200.6 / 250.119 / 210.5, and UL 508A for control wiring",
        entries: [
            ReferenceEntry(code: "120/208 V", title: "Black · Red · Blue", detail: "Phases A, B, C. Neutral white, ground green."),
            ReferenceEntry(code: "277/480 V", title: "Brown · Orange · Yellow", detail: "Phases A, B, C. Neutral grey, ground green."),
            ReferenceEntry(code: "High leg", title: "Orange", detail: "The 208 V-to-neutral leg on a 4-wire delta must be orange, or durably marked, per 110.15."),
            ReferenceEntry(code: "Grounded", title: "White or grey", detail: "White for a system under 6 AWG; grey when white would be ambiguous between systems."),
            ReferenceEntry(code: "Grounding", title: "Green, green/yellow, or bare", detail: "Equipment grounding conductor. Never used for a current-carrying leg."),
            ReferenceEntry(code: "AC control", title: "Red", detail: "UL 508A: AC control conductors powered by the panel."),
            ReferenceEntry(code: "DC control", title: "Blue", detail: "UL 508A: DC control conductors powered by the panel."),
            ReferenceEntry(code: "Foreign", title: "Yellow", detail: "UL 508A: live with the disconnect open — powered from outside the panel. Check before you touch it."),
            ReferenceEntry(code: "AC neutral", title: "White", detail: "UL 508A: grounded AC control conductor."),
            ReferenceEntry(code: "DC common", title: "White/blue stripe", detail: "UL 508A: grounded DC control conductor."),
        ]
    )

    // MARK: - Classified areas

    public static let hazardousAreas = ReferenceTopic(
        id: "hazardous-areas",
        title: "Hazardous Area Classes",
        purpose: "Knowing what the drawing means before you specify anything for a classified space.",
        source: "NEC Articles 500–506",
        entries: [
            ReferenceEntry(code: "Class I", title: "Flammable gases and vapours", detail: "Solvents, fuels, hydrogen. Groups A (acetylene) through D (propane)."),
            ReferenceEntry(code: "Class II", title: "Combustible dust", detail: "Groups E (metal), F (coal), G (grain, flour, plastic)."),
            ReferenceEntry(code: "Class III", title: "Ignitible fibres and flyings", detail: "Textile and woodworking. Not normally suspended in air."),
            ReferenceEntry(code: "Division 1", title: "Hazard present in normal operation", detail: "Present continuously, intermittently, or periodically under normal conditions."),
            ReferenceEntry(code: "Division 2", title: "Hazard present only abnormally", detail: "Confined in normal use; present only if a container or system fails."),
            ReferenceEntry(code: "Zone 0", title: "Continuous", detail: "IEC-style. Present continuously or for long periods."),
            ReferenceEntry(code: "Zone 1", title: "Likely in normal operation", detail: "Roughly comparable to Division 1."),
            ReferenceEntry(code: "Zone 2", title: "Unlikely, and brief if it happens", detail: "Roughly comparable to Division 2."),
        ]
    )

    // MARK: - Conductors

    public static let conductorInsulation = ReferenceTopic(
        id: "conductor-insulation",
        title: "Insulation Types",
        purpose: "Reading the letters printed on the jacket and knowing which ampacity column applies.",
        source: "NEC Table 310.4(A) / 310.16",
        entries: [
            ReferenceEntry(code: "THHN", title: "90 °C dry", detail: "Heat-resistant thermoplastic, nylon jacket. The common building wire — ampacity still limited to the 75 °C column by termination ratings."),
            ReferenceEntry(code: "THWN", title: "75 °C wet", detail: "Moisture- and heat-resistant. Almost always dual-rated THHN/THWN-2."),
            ReferenceEntry(code: "THWN-2", title: "90 °C wet and dry", detail: "The rating that lets one conductor be pulled into a wet raceway."),
            ReferenceEntry(code: "XHHW", title: "90 °C dry, 75 °C wet", detail: "Cross-linked polyethylene. Stiffer, strips cleanly, common on feeders."),
            ReferenceEntry(code: "XHHW-2", title: "90 °C wet and dry", detail: "The -2 suffix always means 90 °C in both wet and dry locations."),
            ReferenceEntry(code: "TW", title: "60 °C", detail: "Older thermoplastic. Puts you in the 60 °C ampacity column."),
            ReferenceEntry(code: "USE-2", title: "90 °C, direct burial", detail: "Underground service entrance. Sunlight resistant, no flame rating for interior use."),
            ReferenceEntry(code: "MTW", title: "Machine tool wire", detail: "Flexible, oil resistant. UL 508A control panels and machine wiring."),
        ]
    )

    // MARK: - Bolt torque

    public static let boltTorque = ReferenceTopic(
        id: "bolt-torque",
        title: "Torque Lookup",
        purpose: "A starting value for a bolt when the equipment nameplate doesn't give one. Always defer to the manufacturer's spec when it exists.",
        source: "Common SAE / metric coarse-thread practice, dry, non-lubricated",
        entries: [
            ReferenceEntry(code: "#8-32", title: "SAE Grade 2 — 20 lb·in", detail: "Small terminal and cover screws. Snug plus a quarter turn is a common field rule for this size."),
            ReferenceEntry(code: "#10-24", title: "SAE Grade 2 — 30 lb·in", detail: "Terminal blocks and light covers."),
            ReferenceEntry(code: "1/4-20", title: "SAE Grade 5 — 8-10 lb·ft", detail: "Panel covers, small brackets."),
            ReferenceEntry(code: "5/16-18", title: "SAE Grade 5 — 17-19 lb·ft", detail: "Disconnect covers, medium brackets."),
            ReferenceEntry(code: "3/8-16", title: "SAE Grade 5 — 30-35 lb·ft", detail: "Structural brackets, larger enclosure doors."),
            ReferenceEntry(code: "1/2-13", title: "SAE Grade 5 — 75-80 lb·ft", detail: "Structural steel, motor base bolts."),
            ReferenceEntry(code: "M6", title: "Metric 8.8 — 9-10 N·m", detail: "European gear terminal covers and light brackets."),
            ReferenceEntry(code: "M8", title: "Metric 8.8 — 23-25 N·m", detail: "Common European enclosure hardware."),
            ReferenceEntry(code: "M10", title: "Metric 8.8 — 46-48 N·m", detail: "Structural brackets, motor frames."),
            ReferenceEntry(code: "Lubricated", title: "≈ 75 % of dry value", detail: "A lubricated or plated fastener needs noticeably less torque for the same clamping force — using a dry spec on a lubricated bolt over-tightens it."),
        ]
    )

    // MARK: - Conduit and fittings

    public static let conduitFittings = ReferenceTopic(
        id: "conduit-fittings",
        title: "Conduit & Fittings Guide",
        purpose: "Picking the raceway type for the environment before you get to fill calculations.",
        source: "NEC Chapter 3 (Articles 342-362)",
        entries: [
            ReferenceEntry(code: "EMT", title: "Electrical metallic tubing", detail: "Thin-wall, indoor/dry or protected outdoor. Fittings are set-screw or compression, not threaded."),
            ReferenceEntry(code: "RMC", title: "Rigid metal conduit", detail: "Threaded, heaviest wall. Physical protection, hazardous locations, direct burial with corrosion protection."),
            ReferenceEntry(code: "IMC", title: "Intermediate metal conduit", detail: "Threaded, thinner wall than RMC but same fittings and same uses in most applications."),
            ReferenceEntry(code: "PVC", title: "Rigid PVC (Schedule 40/80)", detail: "Direct burial and corrosive areas. Schedule 80 for physical protection; needs expansion fittings on long runs."),
            ReferenceEntry(code: "LFMC", title: "Liquidtight flexible metal conduit", detail: "Motor and vibrating-equipment connections needing a liquidtight, flexible, groundable whip."),
            ReferenceEntry(code: "FMC", title: "Flexible metal conduit (Greenfield)", detail: "Dry locations only — not liquidtight. Short flexible runs, recessed lighting whips."),
            ReferenceEntry(code: "ENT", title: "Electrical nonmetallic tubing", detail: "Corrugated, bends by hand. Concealed in walls/slabs on covered construction only."),
            ReferenceEntry(code: "Set-screw", title: "EMT fitting, dry locations", detail: "Not rated wet or damp unless specifically listed raintight."),
            ReferenceEntry(code: "Compression", title: "EMT fitting, wet-rated", detail: "The go-to for EMT anywhere damp or outdoor."),
        ]
    )

    /// The standard-size lists live in NECTables so the calculators use exactly
    /// the same numbers as the reference screen shows.
    public static var standardSizes: ReferenceTopic {
        ReferenceTopic(
            id: "standard-sizes",
            title: "Standard Sizes",
            purpose: "The values you are allowed to round to — breakers, transformers, and conductor areas.",
            source: "NEC 240.6(A), 450.3, Chapter 9 Table 8",
            entries: [
                ReferenceEntry(
                    code: "OCPD",
                    title: "Standard overcurrent ratings",
                    detail: NECTables.standardOCPD.map(String.init).joined(separator: ", ") + " A"
                ),
                ReferenceEntry(
                    code: "kVA",
                    title: "Standard transformer sizes",
                    detail: NECTables.standardTransformerKVA
                        .map { $0 == $0.rounded() ? String(Int($0)) : String($0) }
                        .joined(separator: ", ") + " kVA"
                ),
                ReferenceEntry(
                    code: "AWG",
                    title: "Conductor sizes carried by this app",
                    detail: NECTables.wireSizeOrder.joined(separator: ", ")
                ),
                ReferenceEntry(
                    code: "EMT",
                    title: "EMT trade sizes",
                    detail: NECTables.emtArea.map(\.trade).joined(separator: ", ") + " in"
                ),
            ]
        )
    }
}
