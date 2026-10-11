import Foundation

// MARK: - NFPA 780 lightning protection (2023 edition section numbers only)
//
// Design aid in plain words. Section numbers point at NFPA 780-2023; nothing here is
// copied code text. The adopted edition, the listing of the components, and the AHJ govern.

/// Roof shape as NFPA 780 Chapter 3 sorts it for strike-termination layout.
public enum LPSRoofStyle: String, CaseIterable, Sendable, Hashable {
    case flat
    case gentlySloping
    case steep

    public var displayName: String {
        switch self {
        case .flat: return "Flat"
        case .gentlySloping: return "Gently sloping"
        case .steep: return "Pitched (steep)"
        }
    }

    /// Classifies a roof from its rise per 12 of run and its span.
    ///
    /// NFPA pitch is rise over span. A plain gable's run is half its span, so a
    /// 1/8 pitch is 3-in-12 and 1/4 pitch is 6-in-12. Spans of 40 ft or less count as
    /// gently sloping up to 1/8 pitch; wider spans up to 1/4 pitch.
    public static func classify(risePer12: Double, spanFeet: Double) -> LPSRoofStyle {
        guard risePer12 > 0 else { return .flat }
        let pitch = (risePer12 / 12) / 2
        let limit = spanFeet <= 40 ? 1.0 / 8 : 1.0 / 4
        return pitch <= limit + 1e-9 ? .gentlySloping : .steep
    }
}

/// Class I vs Class II conductor and terminal materials (Ch. 4.2).
public enum LPSMaterialClass: String, Sendable, Hashable {
    case classI
    case classII

    public var displayName: String { self == .classI ? "Class I" : "Class II" }

    /// Structures over 75 ft call for Class II materials.
    public static func forHeight(feet: Double) -> LPSMaterialClass {
        feet > 75 ? .classII : .classI
    }
}

public enum RollingSphere {
    /// Ordinary structures (Ch. 4.7).
    public static let ordinaryRadiusFeet: Double = 150
    /// Flammable-vapor (Ch. 7) and explosives (Ch. 8) structures use a smaller sphere.
    public static let hazardousRadiusFeet: Double = 100

    /// Horizontal distance from the mast to where the sphere touches the ground.
    /// A mast taller than the sphere only counts up to one radius.
    public static func protectedRadiusAtGround(mastHeight h: Double, sphereRadius r: Double) -> Double {
        guard h > 0, r > 0 else { return 0 }
        let hh = min(h, r)
        return (2 * r * hh - hh * hh).squareRoot()
    }

    /// Height of the protected boundary at horizontal distance `x` from the mast.
    /// The boundary is the underside of a sphere resting on the mast tip and the ground.
    public static func protectedHeight(atDistance x: Double, mastHeight h: Double, sphereRadius r: Double) -> Double {
        guard h > 0, r > 0, x >= 0 else { return 0 }
        let hh = min(h, r)
        let d = protectedRadiusAtGround(mastHeight: hh, sphereRadius: r)
        guard x < d else { return 0 }
        let dx = d - x
        return max(0, r - (r * r - dx * dx).squareRoot())
    }

    public static func isProtected(objectHeight: Double, atDistance x: Double, mastHeight h: Double, sphereRadius r: Double) -> Bool {
        objectHeight >= 0 && objectHeight <= protectedHeight(atDistance: x, mastHeight: h, sphereRadius: r) + 1e-9
    }

    /// Sampled boundary for a cross-section drawing, from the mast out to the ground touch point.
    public static func profile(mastHeight h: Double, sphereRadius r: Double, samples: Int = 48) -> [(x: Double, y: Double)] {
        let d = protectedRadiusAtGround(mastHeight: h, sphereRadius: r)
        guard d > 0, samples > 1 else { return [] }
        return (0..<samples).map { i in
            let x = d * Double(i) / Double(samples - 1)
            return (x, protectedHeight(atDistance: x, mastHeight: h, sphereRadius: r))
        }
    }
}

/// Simple cone zones still allowed for low structures (Ch. 4.7).
public enum ProtectionCone {
    /// Horizontal reach per foot of height: 2 for structures 25 ft or less, 1 up to 50 ft, nil above (use the sphere).
    public static func horizontalRatio(forHeight h: Double) -> Double? {
        guard h > 0 else { return nil }
        if h <= 25 { return 2 }
        if h <= 50 { return 1 }
        return nil
    }

    public static func radiusAtGround(height h: Double) -> Double? {
        horizontalRatio(forHeight: h).map { $0 * h }
    }
}

public enum LPSLayout {
    /// Ridge / perimeter spacing for strike termination devices: 20 ft, or 25 ft when the devices stand 24 in or taller.
    public static func terminalSpacingFeet(terminalHeightInches: Double) -> Double {
        terminalHeightInches >= 24 ? 25 : 20
    }

    /// Devices along one open run (a ridge), with one within 2 ft of each end.
    public static func terminalsAlongRun(lengthFeet: Double, spacingFeet: Double) -> Int {
        guard lengthFeet > 0, spacingFeet > 0 else { return 0 }
        let inner = max(0, lengthFeet - 4)
        return max(2, Int((inner / spacingFeet).rounded(.up)) + 1)
    }

    /// Devices around a closed perimeter at the given spacing.
    public static func terminalsAroundPerimeter(perimeterFeet: Double, spacingFeet: Double) -> Int {
        guard perimeterFeet > 0, spacingFeet > 0 else { return 0 }
        return max(4, Int((perimeterFeet / spacingFeet - 1e-9).rounded(.up)))
    }

    /// Flat or gently sloping roofs wider than 50 ft get a grid of field devices no more than 50 ft apart.
    public static func interiorFieldTerminals(lengthFeet: Double, widthFeet: Double, gridFeet: Double = 50) -> Int {
        guard lengthFeet > gridFeet, widthFeet > gridFeet else { return 0 }
        let cols = Int((lengthFeet / gridFeet - 1e-9).rounded(.up)) - 1
        let rows = Int((widthFeet / gridFeet - 1e-9).rounded(.up)) - 1
        return max(0, cols) * max(0, rows)
    }

    /// At least two down conductors, and average spacing around the perimeter no more than 100 ft.
    public static func downConductorCount(perimeterFeet: Double, averageSpacingFeet: Double = 100) -> Int {
        guard perimeterFeet > 0 else { return 0 }
        return max(2, Int((perimeterFeet / averageSpacingFeet - 1e-9).rounded(.up)))
    }

    /// Bonding-distance concept (Ch. 4.15): D = h / (6 n) × Km.
    /// n = 1 with one down conductor, 1.5 with two or three, 2.25 with four or more.
    public static func separationDistanceFeet(heightFeet h: Double, downConductors: Int, solidMaterial: Bool) -> Double {
        guard h > 0, downConductors > 0 else { return 0 }
        let n: Double = downConductors >= 4 ? 2.25 : (downConductors >= 2 ? 1.5 : 1)
        let km: Double = solidMaterial ? 0.5 : 1
        return h / (6 * n) * km
    }
}

public struct LPSStructureInput: Equatable, Sendable {
    public var lengthFeet: Double
    public var widthFeet: Double
    public var heightFeet: Double
    public var risePer12: Double
    public var terminalHeightInches: Double
    public var hazardous: Bool

    public init(lengthFeet: Double, widthFeet: Double, heightFeet: Double, risePer12: Double, terminalHeightInches: Double, hazardous: Bool = false) {
        self.lengthFeet = lengthFeet
        self.widthFeet = widthFeet
        self.heightFeet = heightFeet
        self.risePer12 = risePer12
        self.terminalHeightInches = terminalHeightInches
        self.hazardous = hazardous
    }
}

public struct LPSStructureResult: Equatable, Sendable {
    public let input: LPSStructureInput
    public let roof: LPSRoofStyle
    public let materialClass: LPSMaterialClass
    public let perimeterFeet: Double
    public let spacingFeet: Double
    public let perimeterTerminals: Int
    public let ridgeTerminals: Int
    public let interiorTerminals: Int
    public let downConductors: Int
    public let sphereRadiusFeet: Double
    public let coneRadiusFeet: Double?
    public let separationAirFeet: Double

    /// Ridge devices for pitched roofs, perimeter + field grid for flat / gently sloping.
    public var totalTerminals: Int {
        roof == .steep ? ridgeTerminals : perimeterTerminals + interiorTerminals
    }
}

public enum LPSWizard {
    public static func solve(_ input: LPSStructureInput) throws -> LPSStructureResult {
        for (name, v) in [("Length", input.lengthFeet), ("Width", input.widthFeet), ("Height", input.heightFeet), ("Terminal height", input.terminalHeightInches)] {
            guard v.isFinite else { throw CalcError.missing(name) }
            guard v > 0 else { throw CalcError.nonPositive(name) }
        }
        guard input.risePer12.isFinite, input.risePer12 >= 0, input.risePer12 <= 24 else {
            throw CalcError.outOfRange("Roof rise should be 0 to 24 inches per 12.")
        }
        guard input.terminalHeightInches >= 10 else {
            throw CalcError.outOfRange("Strike termination devices stand at least 10 in above what they protect (4.6).")
        }
        let span = min(input.lengthFeet, input.widthFeet)
        let roof = LPSRoofStyle.classify(risePer12: input.risePer12, spanFeet: span)
        let perimeter = 2 * (input.lengthFeet + input.widthFeet)
        let spacing = LPSLayout.terminalSpacingFeet(terminalHeightInches: input.terminalHeightInches)
        let downs = LPSLayout.downConductorCount(perimeterFeet: perimeter)
        return LPSStructureResult(
            input: input,
            roof: roof,
            materialClass: .forHeight(feet: input.heightFeet),
            perimeterFeet: perimeter,
            spacingFeet: spacing,
            perimeterTerminals: LPSLayout.terminalsAroundPerimeter(perimeterFeet: perimeter, spacingFeet: spacing),
            ridgeTerminals: LPSLayout.terminalsAlongRun(lengthFeet: max(input.lengthFeet, input.widthFeet), spacingFeet: spacing),
            interiorTerminals: roof == .steep ? 0 : LPSLayout.interiorFieldTerminals(lengthFeet: input.lengthFeet, widthFeet: input.widthFeet),
            downConductors: downs,
            sphereRadiusFeet: input.hazardous ? RollingSphere.hazardousRadiusFeet : RollingSphere.ordinaryRadiusFeet,
            coneRadiusFeet: input.hazardous ? nil : ProtectionCone.radiusAtGround(height: input.heightFeet),
            separationAirFeet: LPSLayout.separationDistanceFeet(heightFeet: input.heightFeet, downConductors: downs, solidMaterial: false)
        )
    }
}

// MARK: - Reference cards

public struct CodeReferenceCard: Equatable, Sendable, Identifiable {
    public let title: String
    public let citation: String
    public let points: [String]
    public var id: String { title }

    public init(title: String, citation: String, points: [String]) {
        self.title = title
        self.citation = citation
        self.points = points
    }
}

public enum NFPA780Reference {
    public static let edition = "NFPA 780, 2023 edition"
    public static let governs = "Section numbers only, explained in our own words. The adopted edition, listed components, and the AHJ govern."

    /// Chapter titles verified against the 2023 table of contents.
    public static let chapterTitles: [Int: String] = [
        4: "General Requirements (ordinary structures)",
        5: "Miscellaneous Structures and Special Occupancies",
        6: "Heavy-Duty Stacks",
        7: "Structures Containing Flammable Vapors, Gases, or Liquids",
        8: "Structures Housing Explosive Materials",
    ]

    public static let chapter4: [CodeReferenceCard] = [
        CodeReferenceCard(title: "Materials", citation: "NFPA 780 4.2", points: [
            "Class I materials suit structures up to 75 ft tall; taller structures step up to heavier Class II conductors and terminals.",
            "Keep copper and aluminum apart where they would corrode each other; aluminum stays off masonry and out of the earth.",
        ]),
        CodeReferenceCard(title: "Strike termination devices", citation: "NFPA 780 4.5, 4.6", points: [
            "Devices stand at least 10 in above the object they protect.",
            "Along ridges and roof edges, space them about 20 ft apart, or 25 ft when the devices are 24 in or taller, and keep one within 2 ft of each ridge end and outside corner.",
            "Flat or gently sloping roofs wider than 50 ft add field devices on a grid no wider than 50 ft.",
        ]),
        CodeReferenceCard(title: "Zones of protection", citation: "NFPA 780 4.7", points: [
            "Rolling sphere: roll an imaginary 150 ft ball over the structure; anything the ball can touch needs a strike termination device.",
            "Structures 25 ft or lower may use a cone reaching 2 ft out per foot of height; up to 50 ft, 1 ft out per foot.",
            "Masts, overhead wires, and the structure's own metal can all form the zone.",
        ]),
        CodeReferenceCard(title: "Down conductors", citation: "NFPA 780 4.8", points: [
            "At least two, as far apart as practical, ideally at diagonally opposite corners.",
            "Average spacing around the perimeter no more than about 100 ft.",
            "Keep paths short and direct with gentle bends; avoid sharp turns and upward runs.",
        ]),
        CodeReferenceCard(title: "Grounding electrodes", citation: "NFPA 780 4.12", points: [
            "Each down conductor ends at a grounding electrode: rods, a ground ring, plates, or a concrete-encased electrode.",
            "Rods are commonly at least 1/2 in by 8 ft, set a little away from the foundation; shallow-soil and sandy sites use rings or radials instead.",
        ]),
        CodeReferenceCard(title: "Common bonding and equalization", citation: "NFPA 780 4.13, 4.14", points: [
            "Tie the lightning grounding system to the electrical, communications, and piping grounds so they rise together.",
            "Tall structures add loop conductors at intervals to equalize potential.",
        ]),
        CodeReferenceCard(title: "Bonding of metal bodies", citation: "NFPA 780 4.15", points: [
            "Metal close to a down conductor can flash over. Either keep it beyond the separation distance or bond it.",
            "The distance grows with height above the nearest bond and shrinks with more down conductors; solid material between halves it compared with air.",
        ]),
        CodeReferenceCard(title: "Surge protection", citation: "NFPA 780 4.19", points: [
            "Surge protective devices at the service entrance and where signal, data, and power lines enter are part of a complete system.",
        ]),
    ]

    public static let chapter7: [CodeReferenceCard] = [
        CodeReferenceCard(title: "Why these structures differ", citation: "NFPA 780 7.1, 7.2", points: [
            "A spark where vapor can collect is the hazard. Protection keeps arcs away from vents, seals, and openings.",
            "Zones are drawn with a smaller 100 ft rolling sphere instead of 150 ft.",
        ]),
        CodeReferenceCard(title: "Protective measures", citation: "NFPA 780 7.3", points: [
            "Keep vapor openings closed or flame-protected, bond all metal, and keep separation distances to anything that could spark.",
            "Masts or overhead shield wires can protect a structure without touching it.",
        ]),
        CodeReferenceCard(title: "Metallic vs nonmetallic tanks", citation: "NFPA 780 7.5, 7.6", points: [
            "A fully welded or bolted steel tank with a thick enough roof, tight joints, and good grounding largely protects itself.",
            "Nonmetallic tanks, or metal tanks with thin roofs, need masts, shield wires, or air terminals to place them in a zone of protection.",
        ]),
        CodeReferenceCard(title: "Floating-roof tanks", citation: "NFPA 780 7.6", points: [
            "Shunts bridge the floating roof to the shell at the seal, spaced closely around the rim so current crosses where vapor is thinnest.",
            "Bypass conductors tie the roof to the shell over its full travel; insulate or bond the seal assembly so it cannot arc.",
        ]),
        CodeReferenceCard(title: "Operating facilities, earthen containers, tank batteries", citation: "NFPA 780 7.4, 7.7, 7.8", points: [
            "Process structures follow Chapter 4 plus extra bonding at vents and piping.",
            "Earthen pits and tank batteries are bonded together and grounded as one group.",
        ]),
    ]

    public static let chapter8: [CodeReferenceCard] = [
        CodeReferenceCard(title: "Scope and system types", citation: "NFPA 780 8.1–8.3", points: [
            "Covers buildings and magazines holding explosives.",
            "Masts or overhead catenary wires kept clear of the structure are preferred; integral air terminals are allowed with tight bonding.",
            "Zones use the 100 ft rolling sphere.",
        ]),
        CodeReferenceCard(title: "Grounding and bonding", citation: "NFPA 780 8.4, 8.5", points: [
            "A ground ring around the structure ties all down conductors together.",
            "Every metal body, rail, pipe, and door frame is bonded so no gap can spark.",
        ]),
        CodeReferenceCard(title: "Surge protection and fences", citation: "NFPA 780 8.6, 8.8", points: [
            "Every incoming power, signal, and data line gets surge protection where it enters.",
            "Metal fences near the facility are grounded at intervals and at gates.",
        ]),
        CodeReferenceCard(title: "Specific facilities and inspection", citation: "NFPA 780 8.7, 8.9, 8.10", points: [
            "Earth-covered magazines, wharves, and rail or truck loading points have their own layouts.",
            "A written plan sets regular visual checks and electrical testing; record every result.",
        ]),
    ]
}
