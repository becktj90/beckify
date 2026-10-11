import Foundation

// MARK: - NEC Articles 500–506 hazardous (classified) locations, plus an Article 490 card
//
// 2023 NEC section numbers only, summarized in our own words. Classification is an
// engineering judgment documented for the AHJ; this tool explains the mapping.

public enum HazMaterial: String, CaseIterable, Sendable, Hashable {
    case gasVapor
    case dust
    case fibers

    public var displayName: String {
        switch self {
        case .gasVapor: return "Flammable gas or vapor"
        case .dust: return "Combustible dust"
        case .fibers: return "Ignitible fibers / flyings"
        }
    }

    public var classLabel: String {
        switch self {
        case .gasVapor: return "Class I"
        case .dust: return "Class II"
        case .fibers: return "Class III"
        }
    }

    public var divisionArticle: String {
        switch self {
        case .gasVapor: return "501"
        case .dust: return "502"
        case .fibers: return "503"
        }
    }

    public var zoneArticle: String { self == .gasVapor ? "505" : "506" }
}

public enum HazPresence: String, CaseIterable, Sendable, Hashable {
    /// Present continuously or for long periods.
    case continuous
    /// Likely in normal operation, repair, or maintenance.
    case normal
    /// Only if something fails or is handled abnormally.
    case abnormal

    public var displayName: String {
        switch self {
        case .continuous: return "Continuously / long periods"
        case .normal: return "Normal operation (likely)"
        case .abnormal: return "Only abnormal (leak, failure)"
        }
    }
}

public enum HazGroup: String, CaseIterable, Sendable, Hashable {
    case a, b, c, d, e, f, g

    public var letter: String { rawValue.uppercased() }

    public var material: HazMaterial {
        switch self {
        case .a, .b, .c, .d: return .gasVapor
        case .e, .f, .g: return .dust
        }
    }

    public var examples: String {
        switch self {
        case .a: return "Acetylene"
        case .b: return "Hydrogen, some manufactured gases"
        case .c: return "Ethylene, ethyl ether"
        case .d: return "Propane, gasoline, natural gas, methane"
        case .e: return "Metal dusts (aluminum, magnesium)"
        case .f: return "Carbonaceous dusts (coal, carbon black, coke)"
        case .g: return "Other dusts (grain, flour, wood, plastic, sugar)"
        }
    }

    /// Nearest Zone-system group (505.6 / 506.6).
    public var zoneGroup: String {
        switch self {
        case .a, .b: return "IIC"
        case .c: return "IIB"
        case .d: return "IIA"
        case .e: return "IIIC"
        case .f: return "IIIC if conductive, else IIIB"
        case .g: return "IIIB"
        }
    }

    public static func groups(for material: HazMaterial) -> [HazGroup] {
        allCases.filter { $0.material == material }
    }
}

public struct HazClassification: Equatable, Sendable {
    public let material: HazMaterial
    public let presence: HazPresence
    public let group: HazGroup?
    public let division: Int
    public let zone: Int

    public var classLabel: String { material.classLabel }
    public var divisionLabel: String { "\(material.classLabel), Division \(division)" + (group.map { ", Group \($0.letter)" } ?? "") }
    public var zoneLabel: String {
        switch material {
        case .gasVapor: return "Zone \(zone)" + (group.map { ", Group \($0.zoneGroup)" } ?? "")
        case .dust: return "Zone \(zone)" + (group.map { ", Group \($0.zoneGroup)" } ?? "")
        case .fibers: return "Zone \(zone), Group IIIA"
        }
    }

    public var notes: [String] {
        var out: [String] = []
        if presence == .continuous && material != .fibers {
            out.append("Continuous presence is Division 1 in the Division system; the Zone system splits it out as the most severe zone.")
        }
        if material == .dust && group == .e {
            out.append("Group E metal dust in hazardous quantities is Division 1 wherever present (500.5(C)(1)).")
        }
        if material == .fibers {
            out.append("Class III: Division 1 where fibers are made, handled, or used; Division 2 where only stored or handled outside manufacturing (500.5(D)). No groups.")
        }
        if material == .gasVapor && presence == .abnormal {
            out.append("Division 2 also covers areas next to Division 1 unless positive-pressure ventilation with failure safeguards keeps vapor out (500.5(B)(2)).")
        }
        return out
    }
}

public enum HazClassifier {
    public static func classify(material: HazMaterial, presence: HazPresence, group: HazGroup? = nil) throws -> HazClassification {
        if let group, group.material != material {
            throw CalcError.outOfRange("Group \(group.letter) is a \(group.material.classLabel) group, not \(material.classLabel).")
        }
        if material == .fibers, group != nil {
            throw CalcError.outOfRange("Class III has no material groups.")
        }
        var division = presence == .abnormal ? 2 : 1
        if material == .dust, group == .e { division = 1 }
        let base = material == .gasVapor ? 0 : 20
        let step: Int
        switch presence {
        case .continuous: step = 0
        case .normal: step = 1
        case .abnormal: step = 2
        }
        return HazClassification(material: material, presence: presence, group: group, division: division, zone: base + step)
    }
}

// MARK: - Temperature codes (500.8(D), 505.9(D))

public struct TemperatureCode: Equatable, Sendable, Identifiable {
    public let code: String
    public let maxSurfaceC: Double
    /// Zone marking uses only T1–T6.
    public let zoneMarking: Bool
    public var id: String { code }
}

public enum TemperatureCodes {
    public static let table: [TemperatureCode] = [
        .init(code: "T1", maxSurfaceC: 450, zoneMarking: true),
        .init(code: "T2", maxSurfaceC: 300, zoneMarking: true),
        .init(code: "T2A", maxSurfaceC: 280, zoneMarking: false),
        .init(code: "T2B", maxSurfaceC: 260, zoneMarking: false),
        .init(code: "T2C", maxSurfaceC: 230, zoneMarking: false),
        .init(code: "T2D", maxSurfaceC: 215, zoneMarking: false),
        .init(code: "T3", maxSurfaceC: 200, zoneMarking: true),
        .init(code: "T3A", maxSurfaceC: 180, zoneMarking: false),
        .init(code: "T3B", maxSurfaceC: 165, zoneMarking: false),
        .init(code: "T3C", maxSurfaceC: 160, zoneMarking: false),
        .init(code: "T4", maxSurfaceC: 135, zoneMarking: true),
        .init(code: "T4A", maxSurfaceC: 120, zoneMarking: false),
        .init(code: "T5", maxSurfaceC: 100, zoneMarking: true),
        .init(code: "T6", maxSurfaceC: 85, zoneMarking: true),
    ]

    public static func code(named name: String) -> TemperatureCode? {
        table.first { $0.code.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Equipment is acceptable when its marked maximum surface temperature does not exceed the AIT.
    public static func permits(_ code: TemperatureCode, autoignitionC: Double) -> Bool {
        code.maxSurfaceC <= autoignitionC
    }

    /// Hottest (least restrictive) code that still stays at or below the AIT.
    public static func minimumCode(forAutoignitionC ait: Double, zoneOnly: Bool = false) -> TemperatureCode? {
        guard ait.isFinite else { return nil }
        return table
            .filter { !zoneOnly || $0.zoneMarking }
            .filter { permits($0, autoignitionC: ait) }
            .max { $0.maxSurfaceC < $1.maxSurfaceC }
    }

    /// Every code acceptable at this AIT, hottest first.
    public static func acceptableCodes(forAutoignitionC ait: Double) -> [TemperatureCode] {
        table.filter { permits($0, autoignitionC: ait) }
    }
}

// MARK: - Protection techniques

public enum HazArea: String, CaseIterable, Sendable, Hashable {
    case c1d1, c1d2, c2d1, c2d2, c3d1, c3d2
    case z0, z1, z2, z20, z21, z22

    public var displayName: String {
        switch self {
        case .c1d1: return "Class I Div 1"
        case .c1d2: return "Class I Div 2"
        case .c2d1: return "Class II Div 1"
        case .c2d2: return "Class II Div 2"
        case .c3d1: return "Class III Div 1"
        case .c3d2: return "Class III Div 2"
        case .z0: return "Zone 0"
        case .z1: return "Zone 1"
        case .z2: return "Zone 2"
        case .z20: return "Zone 20"
        case .z21: return "Zone 21"
        case .z22: return "Zone 22"
        }
    }

    public static func from(_ c: HazClassification, zoneSystem: Bool) -> HazArea {
        if zoneSystem {
            switch c.zone {
            case 0: return .z0
            case 1: return .z1
            case 2: return .z2
            case 20: return .z20
            case 21: return .z21
            default: return .z22
            }
        }
        switch (c.material, c.division) {
        case (.gasVapor, 1): return .c1d1
        case (.gasVapor, _): return .c1d2
        case (.dust, 1): return .c2d1
        case (.dust, _): return .c2d2
        case (.fibers, 1): return .c3d1
        case (.fibers, _): return .c3d2
        }
    }
}

public struct ProtectionTechnique: Equatable, Sendable, Identifiable {
    public let name: String
    public let marking: String
    public let citation: String
    public let allowed: Set<HazArea>
    public let idea: String
    public var id: String { marking + name }
}

public enum ProtectionTechniques {
    public static let all: [ProtectionTechnique] = [
        .init(name: "Explosionproof", marking: "XP", citation: "500.7(A)", allowed: [.c1d1, .c1d2],
              idea: "Enclosure contains an internal explosion and cools escaping gases through flame paths."),
        .init(name: "Dust-ignitionproof", marking: "DIP", citation: "500.7(B)", allowed: [.c2d1, .c2d2],
              idea: "Keeps dust out and stays cool enough not to ignite a layer or cloud."),
        .init(name: "Dusttight", marking: "DT", citation: "500.7(C)", allowed: [.c2d2, .c3d1, .c3d2],
              idea: "Sealed against dust entry; for areas where dust is abnormal or fibers are present."),
        .init(name: "Purged and pressurized", marking: "Type X / Y / Z", citation: "500.7(D), NFPA 496", allowed: [.c1d1, .c1d2, .c2d1, .c2d2],
              idea: "Clean air or inert gas keeps the hazard out; X and Y suit Division 1, Z suits Division 2."),
        .init(name: "Intrinsic safety", marking: "IS / ia", citation: "500.7(E), 505.8, 506.8, Art. 504", allowed: [.c1d1, .c1d2, .c2d1, .c2d2, .c3d1, .c3d2, .z0, .z1, .z2, .z20, .z21, .z22],
              idea: "Limits circuit energy so even a fault cannot ignite. Level ia works in Zone 0 / 20."),
        .init(name: "Intrinsic safety, level ib", marking: "ib", citation: "505.8, 506.8", allowed: [.z1, .z2, .z21, .z22],
              idea: "Energy-limited with one fault tolerated; not for Zone 0 / 20."),
        .init(name: "Intrinsic safety, level ic", marking: "ic", citation: "505.8, 506.8", allowed: [.z2, .z22],
              idea: "Energy-limited in normal operation only."),
        .init(name: "Nonincendive", marking: "NI", citation: "500.7(F)–(H)", allowed: [.c1d2, .c2d2, .c3d1, .c3d2],
              idea: "Cannot ignite the atmosphere in normal operation; Division 2 style protection."),
        .init(name: "Oil immersion", marking: "o", citation: "500.7(I), 505.8", allowed: [.c1d2, .z1, .z2],
              idea: "Arcing parts sit under oil so sparks never meet the atmosphere."),
        .init(name: "Hermetically sealed", marking: "HS", citation: "500.7(J)", allowed: [.c1d2, .c2d2, .c3d1, .c3d2],
              idea: "Fusion-sealed so the outside atmosphere cannot get in."),
        .init(name: "Combustible gas detection", marking: "—", citation: "500.7(K)", allowed: [.c1d1, .c1d2],
              idea: "Industrial sites with qualified people only; detection and alarms stand in for some listed equipment."),
        .init(name: "Flameproof", marking: "d", citation: "505.8", allowed: [.z1, .z2],
              idea: "Zone cousin of explosionproof; IEC-style enclosure."),
        .init(name: "Increased safety", marking: "e", citation: "505.8", allowed: [.z1, .z2],
              idea: "Extra measures prevent arcs, sparks, and hot spots in equipment that does not normally spark."),
        .init(name: "Pressurization (zone)", marking: "px / py / pz", citation: "505.8, 506.8", allowed: [.z1, .z2, .z21, .z22],
              idea: "px and py for Zone 1, pz for Zone 2; dust versions for Zones 21 and 22."),
        .init(name: "Encapsulation", marking: "ma / mb / mc", citation: "505.8, 506.8", allowed: [.z0, .z1, .z2, .z20, .z21, .z22],
              idea: "Potted in compound. ma down to Zone 0 / 20, mb to Zone 1 / 21, mc Zone 2 / 22."),
        .init(name: "Powder filling", marking: "q", citation: "505.8", allowed: [.z1, .z2],
              idea: "Parts buried in quartz sand so an arc cannot reach the atmosphere."),
        .init(name: "Type of protection n", marking: "nA / nC / nR", citation: "505.8", allowed: [.z2],
              idea: "Non-sparking, enclosed-break, or restricted-breathing equipment for Zone 2."),
        .init(name: "Protection by enclosure (dust)", marking: "ta / tb / tc", citation: "506.8", allowed: [.z20, .z21, .z22],
              idea: "Dust-excluding enclosure with surface temperature limits; ta to Zone 20, tb to 21, tc to 22."),
    ]

    public static func allowed(in area: HazArea) -> [ProtectionTechnique] {
        all.filter { $0.allowed.contains(area) }
    }
}

// MARK: - Reference cards

public enum HazLocReference {
    public static let governs = "2023 NEC section numbers only, in our own words. Classification is documented per 500.4; the AHJ governs."

    public static let wiringAndSeals: [CodeReferenceCard] = [
        CodeReferenceCard(title: "Class I Div 1 wiring", citation: "501.10(A)", points: [
            "Threaded rigid metal conduit or IMC is the default; MI cable and MC-HL / ITC-HL cable in industrial sites with qualified maintenance also qualify.",
            "Boxes and fittings must be explosionproof; threaded joints made up wrench-tight with enough engaged threads.",
        ]),
        CodeReferenceCard(title: "Class I Div 2 wiring", citation: "501.10(B)", points: [
            "Everything allowed in Division 1, plus enclosed gasketed busway and several cable types such as PLTC, ITC, MC, and TC-ER where conditions are met.",
        ]),
        CodeReferenceCard(title: "Conduit and cable seals", citation: "501.15", points: [
            "In Division 1, seal conduit within 18 in of an explosionproof enclosure that houses arcing or hot parts, and of entries 2 in and larger holding splices or terminals.",
            "Seal where conduit leaves a Division 1 or 2 area, within 10 ft of the boundary, with no union, coupling, or box between the seal and the boundary except listed reducers.",
            "Sealing compound fill is limited (generally 25 % of the conduit area) and the seal is at least as thick as the trade size, never under 5/8 in.",
        ]),
        CodeReferenceCard(title: "Drains and bonding", citation: "501.15(F), 501.30", points: [
            "Drain or breather fittings where condensation could collect behind a seal.",
            "Do not rely on locknut-bushing contact; use bonding jumpers or bonding-type locknuts across every raceway joint back to the service.",
        ]),
        CodeReferenceCard(title: "Dust and fiber wiring", citation: "502.10, 502.15, 503.10", points: [
            "Class II Div 1 uses threaded conduit or listed cable with dusttight boxes; seal or separate raceways between dust-ignitionproof and other enclosures.",
            "Class III allows a wider range of raceways and cables with dusttight, tight-cover boxes.",
        ]),
        CodeReferenceCard(title: "Zone wiring and seals", citation: "505.15, 505.16, 506.15, 506.16", points: [
            "Zone 0 / 1 / 2 wiring parallels Division 1 / 2 choices; seals follow the same idea with Zone-specific triggers.",
            "Division-listed equipment may serve in matching zones (505.9(C)); zone equipment needs the right marking for the zone, group, and T-code.",
        ]),
    ]

    public static let article490: [CodeReferenceCard] = [
        CodeReferenceCard(title: "What Article 490 is", citation: "NEC Art. 490", points: [
            "Equipment over 1000 V nominal: medium-voltage switchgear, circuit breakers, fuses, load interrupters, and similar gear.",
            "It is NOT a hazardous-locations article. Classified areas are Articles 500–506.",
        ]),
        CodeReferenceCard(title: "Part I and II — general and specific equipment", citation: "490.2, 490.21–490.25", points: [
            "Interrupting devices must be rated for the available fault current and the voltage.",
            "Isolating means and backfeed warnings protect people working downstream.",
        ]),
        CodeReferenceCard(title: "Part III — metal-enclosed and metal-clad gear", citation: "490.30–490.48", points: [
            "Guarding, interlocks, grounding provisions, and accessibility of energized parts for enclosed switchgear and substations.",
        ]),
        CodeReferenceCard(title: "Parts IV and V — portable gear and electrode boilers", citation: "490.51–490.74", points: [
            "Mobile and portable MV equipment, and electrode-type boilers.",
            "Working space and entrance rules for over 1000 V come from 110.30–110.34.",
        ]),
    ]
}
