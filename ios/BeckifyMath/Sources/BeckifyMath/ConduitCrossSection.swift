import Foundation

/// Optional phase tint. Names match Reference Library → Conductor Colors.
/// A legend only — not a pulling order and not a code rule.
public enum ConduitDistributionColors: String, Codable, CaseIterable, Sendable, Hashable {
    case off
    case low120
    case high277

    public var displayName: String {
        switch self {
        case .off: return "No phase tint"
        case .low120: return "120/208 V"
        case .high277: return "277/480 V"
        }
    }

    public var systemTitle: String? {
        switch self {
        case .off: return nil
        case .low120: return "120/208 V"
        case .high277: return "277/480 V"
        }
    }
}

public enum ConduitConductorRole: String, Codable, Sendable, Hashable {
    case phaseA
    case phaseB
    case phaseC
    case neutral
    case egc
    case unmarked

    public var displayName: String {
        switch self {
        case .phaseA: return "Phase A"
        case .phaseB: return "Phase B"
        case .phaseC: return "Phase C"
        case .neutral: return "Neutral"
        case .egc: return "EGC"
        case .unmarked: return "Unmarked"
        }
    }

    public var letter: String {
        switch self {
        case .phaseA: return "A"
        case .phaseB: return "B"
        case .phaseC: return "C"
        case .neutral: return "N"
        case .egc: return "G"
        case .unmarked: return ""
        }
    }

    /// Reference Library color name for this role, when a distribution system is on.
    public func colorName(in system: ConduitDistributionColors) -> String? {
        switch system {
        case .off:
            return nil
        case .low120:
            switch self {
            case .phaseA: return "Black"
            case .phaseB: return "Red"
            case .phaseC: return "Blue"
            case .neutral: return "White"
            case .egc: return "Green"
            case .unmarked: return nil
            }
        case .high277:
            switch self {
            case .phaseA: return "Brown"
            case .phaseB: return "Orange"
            case .phaseC: return "Yellow"
            case .neutral: return "Grey"
            case .egc: return "Green"
            case .unmarked: return nil
            }
        }
    }
}

/// Bore used by the cross-section. Fill area stays the published Table 4 number.
public struct ConduitRacewayBore: Equatable, Sendable {
    public var trade: String
    public var internalDiameterInches: Double
    public var internalAreaSquareInches: Double
    public var outsideDiameterInches: Double?
    public var dimensionNote: String

    public var wallThicknessInches: Double? {
        guard let outside = outsideDiameterInches else { return nil }
        let wall = (outside - internalDiameterInches) / 2
        return wall > 0 ? wall : nil
    }

    public init(
        trade: String,
        internalDiameterInches: Double,
        internalAreaSquareInches: Double,
        outsideDiameterInches: Double?,
        dimensionNote: String
    ) {
        self.trade = trade
        self.internalDiameterInches = internalDiameterInches
        self.internalAreaSquareInches = internalAreaSquareInches
        self.outsideDiameterInches = outsideDiameterInches
        self.dimensionNote = dimensionNote
    }
}

public struct ConduitPackedConductor: Equatable, Sendable, Identifiable {
    public var id: Int
    public var size: String
    public var sizeLabel: String
    public var insulation: ConductorInsulationKind
    public var role: ConduitConductorRole
    public var areaSquareInches: Double
    public var overallDiameterInches: Double
    public var metalDiameterInches: Double?
    /// Bore center is the origin. +x is right, +y is up. Inches.
    public var centerXInches: Double
    public var centerYInches: Double
    public var overlaps: Bool

    public var colorName: String?
}

public struct ConduitLegendLine: Equatable, Sendable, Identifiable {
    public var id: String
    public var count: Int
    public var sizeLabel: String
    public var insulationName: String
    public var role: ConduitConductorRole
    public var colorName: String?
    public var overallDiameterInches: Double
}

public struct ConduitFillNote: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var body: String
}

/// Generated cross-section. Packing is illustrative. Table 1 is not a jam check.
public struct ConduitCrossSectionLayout: Equatable, Sendable {
    public var tradeSize: String
    public var raceway: RacewayKind
    public var bore: ConduitRacewayBore
    public var conductors: [ConduitPackedConductor]
    public var fillPercent: Double
    public var allowedPercent: Double
    public var freeAreaPercent: Double
    public var passes: Bool
    public var fillBasis: String
    public var nipple: Bool
    public var packingOverlaps: Bool
    public var packingNote: String
    public var jamRatio: Double?
    public var jamNote: String?
    public var legend: [ConduitLegendLine]
    public var guidance: [ConduitFillNote]
    /// Annex C style maximum for this exact wire when every conductor matches.
    public var annexCMaximum: Int?
    /// AS/NZS 3000:2018 Appendix C C6.2. Guidance beside the NEC result, not a pass/fail.
    public var asnzsSpaceFactorPercent: Double
    public var exceedsASNZSGuidance: Bool
    public var colorSystemTitle: String?
    public var legendDisclaimer: String
    public var accessibilitySummary: String
}

/// Chapter 9 geometry, Annex C style counts, jam ratio, and a settled circle pack.
public enum ConduitCrossSection {
    /// AS/NZS 3000:2018 Appendix C Paragraph C6.2 space factors for a circular enclosure.
    /// Informative guidance. This tool does not transcribe AS/NZS 2053 bores.
    public static func asnzsSpaceFactorPercent(cableCount: Int) -> Double {
        switch cableCount {
        case 1: return 50
        case 2: return 33
        default: return 40
        }
    }

    /// Largest count of one identical conductor that stays inside Table 1 for this raceway.
    /// Same construction Annex C uses: the percent depends on the count.
    public static func maximumIdenticalCount(
        conductorArea: Double,
        racewayArea: Double,
        nipple: Bool
    ) -> Int {
        guard conductorArea > 0, racewayArea > 0 else { return 0 }
        if nipple {
            return Int(floor((racewayArea * 0.60 + 1e-12) / conductorArea))
        }
        var best = 0
        if conductorArea <= racewayArea * 0.53 + 1e-12 {
            best = 1
        }
        if 2 * conductorArea <= racewayArea * 0.31 + 1e-12 {
            best = max(best, 2)
        }
        let at40 = Int(floor((racewayArea * 0.40 + 1e-12) / conductorArea))
        if at40 >= 3 {
            best = max(best, at40)
        }
        return best
    }

    /// Overall diameter from a Table 5 area, inches.
    public static func overallDiameter(areaSquareInches: Double) -> Double {
        guard areaSquareInches > 0 else { return 0 }
        return 2 * sqrt(areaSquareInches / Double.pi)
    }

    /// Chapter 9 Table 8 metal diameter, inches. `sqrt(circular mils) / 1000`.
    public static func metalDiameter(size: String) -> Double? {
        guard let cm = NECTables.circularMils[size], cm > 0 else { return nil }
        return sqrt(cm) / 1000
    }

    public static func bore(kind: RacewayKind, trade: String) -> ConduitRacewayBore? {
        guard let area = NECTables.racewayInternalArea(kind: kind, trade: trade),
              let row = geometry[kind]?.first(where: { $0.trade == trade })
        else { return nil }
        return ConduitRacewayBore(
            trade: trade,
            internalDiameterInches: row.idInches,
            internalAreaSquareInches: area,
            outsideDiameterInches: row.odInches,
            dimensionNote: dimensionNote(kind)
        )
    }

    /// Roles for the conductors in group order. The EGC group, when counted, stays an EGC.
    /// Leftover conductors that do not complete a typical set stay unmarked.
    public static func roles(
        groups: [ConduitFillGroup],
        egcGroupIndex: Int?,
        context: EquipmentGroundingContext,
        colors: ConduitDistributionColors
    ) -> [ConduitConductorRole] {
        let nonEGC = groups.enumerated().reduce(0) { sum, item in
            item.offset == egcGroupIndex ? sum : sum + max(0, item.element.quantity)
        }
        let pattern = phasePattern(count: nonEGC, context: context, colors: colors)
        var roles: [ConduitConductorRole] = []
        var cursor = 0
        for (index, group) in groups.enumerated() {
            let count = max(0, group.quantity)
            if index == egcGroupIndex {
                roles.append(contentsOf: Array(repeating: .egc, count: count))
            } else {
                for _ in 0..<count {
                    roles.append(cursor < pattern.count ? pattern[cursor] : .unmarked)
                    cursor += 1
                }
            }
        }
        return roles
    }

    public static func make(
        result: ConduitFillResult,
        egcGroupIndex: Int?,
        context: EquipmentGroundingContext,
        colors: ConduitDistributionColors
    ) -> ConduitCrossSectionLayout? {
        guard let bore = bore(kind: result.raceway, trade: result.tradeSize) else { return nil }
        let assigned = roles(
            groups: result.groups,
            egcGroupIndex: egcGroupIndex,
            context: context,
            colors: colors
        )
        var specs: [Spec] = []
        var cursor = 0
        for group in result.groups {
            guard let area = NECTables.conductorArea(size: group.size, insulation: group.insulation) else {
                return nil
            }
            let count = max(0, group.quantity)
            for _ in 0..<count {
                let role = cursor < assigned.count ? assigned[cursor] : .unmarked
                specs.append(Spec(
                    index: cursor,
                    size: group.size,
                    insulation: group.insulation,
                    role: role,
                    area: area
                ))
                cursor += 1
            }
        }

        let radii = specs.map { overallDiameter(areaSquareInches: $0.area) / 2 }
        let packed = pack(radii: radii, boreRadius: bore.internalDiameterInches / 2)
        let conductors: [ConduitPackedConductor] = specs.enumerated().map { offset, spec in
            let disk = packed[offset]
            let overall = radii[offset] * 2
            let metal = metalDiameter(size: spec.size)
            let usableMetal = metal.flatMap { value in value < overall * 0.92 ? value : nil }
            return ConduitPackedConductor(
                id: spec.index,
                size: spec.size,
                sizeLabel: NECTables.wireLabel(spec.size),
                insulation: spec.insulation,
                role: spec.role,
                areaSquareInches: spec.area,
                overallDiameterInches: overall,
                metalDiameterInches: usableMetal,
                centerXInches: disk.x,
                centerYInches: disk.y,
                overlaps: disk.overlaps,
                colorName: spec.role.colorName(in: colors)
            )
        }

        let overlaps = conductors.contains { $0.overlaps }
        let jam = jamCheck(conductors: conductors, internalDiameter: bore.internalDiameterInches)
        let legend = legendLines(conductors)
        let annex = annexMaximum(result: result, boreArea: bore.internalAreaSquareInches)
        let space = asnzsSpaceFactorPercent(cableCount: result.conductorCount)
        let free = max(0, 100 - result.actualFillPercent)
        let disclaimer = legendDisclaimer(colors: colors, context: context)
        let summary = accessibilitySummary(
            result: result,
            bore: bore,
            overlaps: overlaps,
            jam: jam.note,
            disclaimer: disclaimer
        )

        return ConduitCrossSectionLayout(
            tradeSize: result.tradeSize,
            raceway: result.raceway,
            bore: bore,
            conductors: conductors,
            fillPercent: result.actualFillPercent,
            allowedPercent: result.maxFillPercent,
            freeAreaPercent: free,
            passes: result.passes,
            fillBasis: result.fillBasis,
            nipple: result.nipple,
            packingOverlaps: overlaps,
            packingNote: overlaps
                ? "Drawn to scale. Overlap means these circles do not sit in the bore without compressing. Table 1 area is not a field jam check."
                : "Settled packing, largest conductors toward the bottom. Illustrative — a pull does not land in this arrangement.",
            jamRatio: jam.ratio,
            jamNote: jam.note,
            legend: legend,
            guidance: guidance(raceway: result.raceway, groups: result.groups, nipple: result.nipple),
            annexCMaximum: annex,
            asnzsSpaceFactorPercent: space,
            exceedsASNZSGuidance: result.actualFillPercent > space + 1e-9,
            colorSystemTitle: colors.systemTitle,
            legendDisclaimer: disclaimer,
            accessibilitySummary: summary
        )
    }

    // MARK: - Geometry

    private struct GeomRow {
        var trade: String
        var idInches: Double
        var odInches: Double?
    }

    /// Internal diameters are the Chapter 9 Table 4 nominal IDs.
    /// Outside diameters are the nominal standard OD where one number is published:
    /// EMT ANSI C80.3, IMC ANSI C80.6, RMC ANSI C80.1, PVC ASTM D1785.
    /// ENT, FMC, and LFMC do not have a single listed OD in Table 4.
    private static let geometry: [RacewayKind: [GeomRow]] = [
        .emt: [
            GeomRow(trade: "1/2", idInches: 0.622, odInches: 0.706),
            GeomRow(trade: "3/4", idInches: 0.824, odInches: 0.922),
            GeomRow(trade: "1", idInches: 1.049, odInches: 1.163),
            GeomRow(trade: "1-1/4", idInches: 1.380, odInches: 1.510),
            GeomRow(trade: "1-1/2", idInches: 1.610, odInches: 1.740),
            GeomRow(trade: "2", idInches: 2.067, odInches: 2.197),
            GeomRow(trade: "2-1/2", idInches: 2.731, odInches: 2.875),
            GeomRow(trade: "3", idInches: 3.356, odInches: 3.500),
            GeomRow(trade: "3-1/2", idInches: 3.834, odInches: 4.000),
            GeomRow(trade: "4", idInches: 4.334, odInches: 4.500),
        ],
        .imc: nps(ids: [
            ("1/2", 0.660), ("3/4", 0.864), ("1", 1.105), ("1-1/4", 1.448),
            ("1-1/2", 1.683), ("2", 2.150), ("2-1/2", 2.557), ("3", 3.176),
            ("3-1/2", 3.671), ("4", 4.166),
        ]),
        .rmc: nps(ids: [
            ("1/2", 0.632), ("3/4", 0.836), ("1", 1.063), ("1-1/4", 1.394),
            ("1-1/2", 1.624), ("2", 2.083), ("2-1/2", 2.489), ("3", 3.090),
            ("3-1/2", 3.570), ("4", 4.050), ("5", 5.073), ("6", 6.093),
        ]),
        .pvc40: nps(ids: [
            ("1/2", 0.602), ("3/4", 0.804), ("1", 1.029), ("1-1/4", 1.360),
            ("1-1/2", 1.590), ("2", 2.047), ("2-1/2", 2.445), ("3", 3.042),
            ("3-1/2", 3.521), ("4", 3.998), ("5", 5.016), ("6", 6.031),
        ]),
        .pvc80: nps(ids: [
            ("1/2", 0.526), ("3/4", 0.722), ("1", 0.936), ("1-1/4", 1.255),
            ("1-1/2", 1.476), ("2", 1.913), ("2-1/2", 2.290), ("3", 2.864),
            ("3-1/2", 3.326), ("4", 3.786), ("5", 4.768), ("6", 5.709),
        ]),
        .ent: [
            GeomRow(trade: "1/2", idInches: 0.602, odInches: nil),
            GeomRow(trade: "3/4", idInches: 0.804, odInches: nil),
            GeomRow(trade: "1", idInches: 1.029, odInches: nil),
            GeomRow(trade: "1-1/4", idInches: 1.360, odInches: nil),
            GeomRow(trade: "1-1/2", idInches: 1.590, odInches: nil),
            GeomRow(trade: "2", idInches: 2.047, odInches: nil),
        ],
        .fmc: [
            GeomRow(trade: "1/2", idInches: 0.635, odInches: nil),
            GeomRow(trade: "3/4", idInches: 0.824, odInches: nil),
            GeomRow(trade: "1", idInches: 1.020, odInches: nil),
            GeomRow(trade: "1-1/4", idInches: 1.275, odInches: nil),
            GeomRow(trade: "1-1/2", idInches: 1.538, odInches: nil),
            GeomRow(trade: "2", idInches: 2.040, odInches: nil),
            GeomRow(trade: "2-1/2", idInches: 2.500, odInches: nil),
            GeomRow(trade: "3", idInches: 3.000, odInches: nil),
            GeomRow(trade: "3-1/2", idInches: 3.500, odInches: nil),
            GeomRow(trade: "4", idInches: 4.000, odInches: nil),
        ],
        .lfmc: [
            GeomRow(trade: "1/2", idInches: 0.632, odInches: nil),
            GeomRow(trade: "3/4", idInches: 0.830, odInches: nil),
            GeomRow(trade: "1", idInches: 1.054, odInches: nil),
            GeomRow(trade: "1-1/4", idInches: 1.395, odInches: nil),
            GeomRow(trade: "1-1/2", idInches: 1.588, odInches: nil),
            GeomRow(trade: "2", idInches: 2.033, odInches: nil),
            GeomRow(trade: "2-1/2", idInches: 2.493, odInches: nil),
            GeomRow(trade: "3", idInches: 3.085, odInches: nil),
            GeomRow(trade: "3-1/2", idInches: 3.520, odInches: nil),
            GeomRow(trade: "4", idInches: 4.020, odInches: nil),
        ],
    ]

    /// Nominal NPS outside diameter shared by RMC, IMC, and both PVC schedules.
    private static let npsOutside: [String: Double] = [
        "1/2": 0.840, "3/4": 1.050, "1": 1.315, "1-1/4": 1.660, "1-1/2": 1.900,
        "2": 2.375, "2-1/2": 2.875, "3": 3.500, "3-1/2": 4.000, "4": 4.500,
        "5": 5.563, "6": 6.625,
    ]

    private static func nps(ids: [(String, Double)]) -> [GeomRow] {
        ids.map { trade, id in
            GeomRow(trade: trade, idInches: id, odInches: npsOutside[trade])
        }
    }

    private static func dimensionNote(_ kind: RacewayKind) -> String {
        switch kind {
        case .emt:
            return "ID is NEC Chapter 9 Table 4. OD is the nominal ANSI C80.3 outside diameter. Wall is (OD − ID) / 2."
        case .imc:
            return "ID is NEC Chapter 9 Table 4. OD is the nominal ANSI C80.6 outside diameter."
        case .rmc:
            return "ID is NEC Chapter 9 Table 4. OD is the nominal ANSI C80.1 outside diameter."
        case .pvc40, .pvc80:
            return "ID is NEC Chapter 9 Table 4. OD is the nominal ASTM D1785 outside diameter. Schedule 80 shares that OD and has a smaller bore."
        case .ent, .fmc, .lfmc:
            return "NEC Chapter 9 Table 4 lists the internal diameter. A single outside diameter is not in that table — the jacket varies by maker, so the drawing shows the bore."
        }
    }

    // MARK: - Roles, legend, notes

    private static func phasePattern(
        count: Int,
        context: EquipmentGroundingContext,
        colors: ConduitDistributionColors
    ) -> [ConduitConductorRole] {
        guard count > 0 else { return [] }
        guard colors != .off, context != .none else {
            return Array(repeating: .unmarked, count: count)
        }
        switch context {
        case .none:
            return Array(repeating: .unmarked, count: count)
        case .threePhase:
            var roles: [ConduitConductorRole] = []
            for _ in 0..<(count / 3) {
                roles.append(contentsOf: [.phaseA, .phaseB, .phaseC])
            }
            switch count % 3 {
            case 1: roles.append(.neutral)
            case 2: roles.append(contentsOf: [.unmarked, .unmarked])
            default: break
            }
            return roles
        case .singlePhase:
            var roles: [ConduitConductorRole] = []
            for _ in 0..<(count / 2) {
                roles.append(contentsOf: [.phaseA, .neutral])
            }
            if count % 2 == 1 { roles.append(.unmarked) }
            return roles
        case .multiwire:
            var roles: [ConduitConductorRole] = []
            for _ in 0..<(count / 3) {
                roles.append(contentsOf: [.phaseA, .phaseB, .neutral])
            }
            let remainder = count % 3
            if remainder > 0 {
                roles.append(contentsOf: Array(repeating: .unmarked, count: remainder))
            }
            return roles
        }
    }

    private static func legendLines(_ conductors: [ConduitPackedConductor]) -> [ConduitLegendLine] {
        var order: [String] = []
        var buckets: [String: (count: Int, sample: ConduitPackedConductor)] = [:]
        for conductor in conductors {
            let key = "\(conductor.insulation.rawValue)|\(conductor.size)|\(conductor.role.rawValue)"
            if buckets[key] == nil {
                order.append(key)
                buckets[key] = (0, conductor)
            }
            buckets[key]?.count += 1
        }
        return order.compactMap { key in
            guard let bucket = buckets[key] else { return nil }
            let sample = bucket.sample
            return ConduitLegendLine(
                id: key,
                count: bucket.count,
                sizeLabel: sample.sizeLabel,
                insulationName: sample.insulation.displayName,
                role: sample.role,
                colorName: sample.colorName,
                overallDiameterInches: sample.overallDiameterInches
            )
        }
    }

    private static func legendDisclaimer(
        colors: ConduitDistributionColors,
        context: EquipmentGroundingContext
    ) -> String {
        if colors == .off {
            return "Tint off. Circles show the Table 5 outline and the Table 8 metal core, not phase colors."
        }
        if context == .none {
            return "Phase tint needs 1Ø, multiwire, or 3Ø. These circles stay unmarked."
        }
        return "Colors match Reference Library names for a typical arrangement. A legend only — not how the pull is taped."
    }

    private static func guidance(
        raceway: RacewayKind,
        groups: [ConduitFillGroup],
        nipple: Bool
    ) -> [ConduitFillNote] {
        var notes = [racewayNote(raceway), insulationNote(groups)]
        if nipple {
            notes.append(ConduitFillNote(
                id: "nipple",
                title: "Nipple ≤ 24 in",
                body: "Table 1 Note 4 allows 60% on a nipple 24 in or shorter. A longer run does not get that limit."
            ))
        }
        return notes
    }

    private static func racewayNote(_ kind: RacewayKind) -> ConduitFillNote {
        switch kind {
        case .emt:
            return ConduitFillNote(
                id: "raceway",
                title: "EMT",
                body: "Thin-wall steel. Set-screw fittings are a dry choice; compression where the run is wet. NEMA 250 and IP describe the enclosure, not this tube."
            )
        case .imc:
            return ConduitFillNote(
                id: "raceway",
                title: "IMC",
                body: "Threaded, thinner wall than RMC, and used for most of the same jobs. Confirm the listing before a hazardous location. NEMA/IP is the box."
            )
        case .rmc:
            return ConduitFillNote(
                id: "raceway",
                title: "RMC",
                body: "Threaded, heaviest wall. Physical protection and many hazardous locations. NEMA 250 and IP describe the enclosure, not the conduit."
            )
        case .pvc40:
            return ConduitFillNote(
                id: "raceway",
                title: "PVC Schedule 40",
                body: "Burial and corrosion. Not the physical-protection wall — that is Schedule 80. Long exposed runs need expansion fittings. The box rating is separate."
            )
        case .pvc80:
            return ConduitFillNote(
                id: "raceway",
                title: "PVC Schedule 80",
                body: "Schedule 80 where the raceway itself needs physical protection. Same outside diameter as Schedule 40, smaller bore. Enclosure NEMA/IP is still the box."
            )
        case .ent:
            return ConduitFillNote(
                id: "raceway",
                title: "ENT",
                body: "Corrugated, concealed in walls or slabs. Not an exposed raceway. Outside diameter varies by maker, so the drawing shows the NEC bore."
            )
        case .fmc:
            return ConduitFillNote(
                id: "raceway",
                title: "FMC",
                body: "Dry locations. Not liquidtight. A short whip, not a wet motor connection — that wants LFMC. The enclosure rating is the box."
            )
        case .lfmc:
            return ConduitFillNote(
                id: "raceway",
                title: "LFMC",
                body: "Liquidtight flexible metal for a motor or vibrating equipment. The whip does not set the enclosure rating. NEMA 250 and IP codes are in Reference Library."
            )
        }
    }

    private static func insulationNote(_ groups: [ConduitFillGroup]) -> ConduitFillNote {
        let kinds = Set(groups.map(\.insulation))
        guard kinds.count == 1, let kind = kinds.first else {
            return ConduitFillNote(
                id: "insulation",
                title: "Mixed insulation",
                body: "Each circle uses that Chapter 9 Table 5 area, including the insulation wall. THHN and RHW of the same AWG are not the same circle."
            )
        }
        switch kind {
        case .thhn:
            return ConduitFillNote(
                id: "insulation",
                title: "THHN / THWN-2",
                body: "The nylon jacket is inside the Table 5 area drawn here. Wet raceway wants the THWN-2 mark. Terminations often cap you at 75 °C."
            )
        case .xhhw:
            return ConduitFillNote(
                id: "insulation",
                title: "XHHW / XHHW-2",
                body: "The -2 mark is 90 °C wet and dry. The circle is the Table 5 overall area, not the bare metal."
            )
        case .rhw:
            return ConduitFillNote(
                id: "insulation",
                title: "RHH / RHW / RHW-2",
                body: "Thicker than THHN, so the same AWG fills more of the bore. The drawing uses that Table 5 area."
            )
        }
    }

    private static func annexMaximum(result: ConduitFillResult, boreArea: Double) -> Int? {
        let keys = Set(result.groups.map { "\($0.size)|\($0.insulation.rawValue)" })
        guard keys.count == 1, let group = result.groups.first,
              let area = NECTables.conductorArea(size: group.size, insulation: group.insulation)
        else { return nil }
        return maximumIdenticalCount(
            conductorArea: area,
            racewayArea: boreArea,
            nipple: result.nipple
        )
    }

    private static func jamCheck(
        conductors: [ConduitPackedConductor],
        internalDiameter: Double
    ) -> (ratio: Double?, note: String?) {
        guard conductors.count == 3,
              let first = conductors.first,
              conductors.allSatisfy({ abs($0.overallDiameterInches - first.overallDiameterInches) < 1e-9 }),
              first.overallDiameterInches > 0
        else { return (nil, nil) }
        let ratio = internalDiameter / first.overallDiameterInches
        guard ratio > 2.8, ratio < 3.2 else { return (ratio, nil) }
        let note = "Jam ratio \(FormatTrace.number(ratio, digits: 2)) is between 2.8 and 3.2. Three equal conductors can lock in a bend. Table 1 does not check that."
        return (ratio, note)
    }

    private static func accessibilitySummary(
        result: ConduitFillResult,
        bore: ConduitRacewayBore,
        overlaps: Bool,
        jam: String?,
        disclaimer: String
    ) -> String {
        let od: String
        if let outside = bore.outsideDiameterInches, let wall = bore.wallThicknessInches {
            od = "OD \(FormatTrace.number(outside, digits: 3)) in, wall \(FormatTrace.number(wall, digits: 3)) in."
        } else {
            od = "Outside diameter is not a single listed dimension."
        }
        let pack = overlaps ? "Circles overlap." : "Circles sit in the bore."
        let jamText = jam.map { " \($0)" } ?? ""
        let free = max(0, 100 - result.actualFillPercent)
        return "\(result.tradeSize) inch \(result.raceway.displayName). ID \(FormatTrace.number(bore.internalDiameterInches, digits: 3)) in. \(od) Fill \(FormatTrace.percent(result.actualFillPercent)) of \(FormatTrace.percent(result.maxFillPercent)). Free area \(FormatTrace.percent(free)). \(pack) Illustrative packing.\(jamText) \(disclaimer)"
    }

    // MARK: - Packing

    private struct Spec {
        var index: Int
        var size: String
        var insulation: ConductorInsulationKind
        var role: ConduitConductorRole
        var area: Double
    }

    private struct Disk {
        var index: Int
        var radius: Double
        var x: Double
        var y: Double
        var overlaps: Bool
    }

    /// Largest circles settle toward the bottom of the bore, each new circle
    /// touching two neighbors or the wall. Not a random scatter.
    private static func pack(radii: [Double], boreRadius: Double) -> [Disk] {
        let order = radii.enumerated().sorted { lhs, rhs in
            if lhs.element != rhs.element { return lhs.element > rhs.element }
            return lhs.offset < rhs.offset
        }
        var placed: [Disk] = []
        for (original, radius) in order {
            let r = max(radius, 1e-8)
            if boreRadius <= r + fitSlop {
                placed.append(Disk(index: original, radius: r, x: 0, y: 0, overlaps: true))
                continue
            }
            if placed.isEmpty {
                let y = order.count == 1 ? 0 : -(boreRadius - r)
                placed.append(Disk(index: original, radius: r, x: 0, y: y, overlaps: false))
                continue
            }
            if let spot = bestContact(radius: r, placed: placed, boreRadius: boreRadius) {
                placed.append(Disk(index: original, radius: r, x: spot.x, y: spot.y, overlaps: false))
            } else if let spot = gridSpot(radius: r, placed: placed, boreRadius: boreRadius, allowOverlap: false) {
                placed.append(Disk(index: original, radius: r, x: spot.x, y: spot.y, overlaps: false))
            } else if let spot = gridSpot(radius: r, placed: placed, boreRadius: boreRadius, allowOverlap: true) {
                placed.append(Disk(index: original, radius: r, x: spot.x, y: spot.y, overlaps: true))
            } else {
                placed.append(Disk(index: original, radius: r, x: 0, y: 0, overlaps: true))
            }
        }
        return radii.indices.map { index in
            guard let disk = placed.first(where: { $0.index == index }) else {
                return Disk(index: index, radius: radii[index], x: 0, y: 0, overlaps: true)
            }
            var copy = disk
            copy.overlaps = !fits(x: disk.x, y: disk.y, radius: disk.radius, placed: placed.filter { $0.index != index }, boreRadius: boreRadius)
            return copy
        }
    }

    private static let fitSlop = 1e-4

    private static func fits(x: Double, y: Double, radius: Double, placed: [Disk], boreRadius: Double) -> Bool {
        if hypot(x, y) + radius > boreRadius + fitSlop { return false }
        for disk in placed {
            if hypot(x - disk.x, y - disk.y) + fitSlop < radius + disk.radius {
                return false
            }
        }
        return true
    }

    private static func bestContact(radius: Double, placed: [Disk], boreRadius: Double) -> (x: Double, y: Double)? {
        var candidates: [(x: Double, y: Double)] = [(0, -(boreRadius - radius))]
        let inner = boreRadius - radius
        // Lowest disks first. Pockets that matter for a settled pile are among them,
        // so a full raceway does not do an all-pairs search.
        let pool = placed.sorted { lhs, rhs in
            if abs(lhs.y - rhs.y) > 1e-9 { return lhs.y < rhs.y }
            return abs(lhs.x) < abs(rhs.x)
        }.prefix(16)
        for disk in pool {
            candidates.append(contentsOf: intersections(
                x1: disk.x, y1: disk.y, r1: disk.radius + radius,
                x2: 0, y2: 0, r2: inner
            ))
        }
        let poolList = Array(pool)
        if poolList.count >= 2 {
            for i in 0..<poolList.count {
                for j in (i + 1)..<poolList.count {
                    candidates.append(contentsOf: intersections(
                        x1: poolList[i].x, y1: poolList[i].y, r1: poolList[i].radius + radius,
                        x2: poolList[j].x, y2: poolList[j].y, r2: poolList[j].radius + radius
                    ))
                }
            }
        }
        let clear = candidates.filter { fits(x: $0.x, y: $0.y, radius: radius, placed: placed, boreRadius: boreRadius) }
        return clear.min { lhs, rhs in
            if abs(lhs.y - rhs.y) > 1e-6 { return lhs.y < rhs.y }
            let lx = abs(lhs.x)
            let rx = abs(rhs.x)
            if abs(lx - rx) > 1e-6 { return lx < rx }
            return lhs.x < rhs.x
        }
    }

    private static func intersections(
        x1: Double, y1: Double, r1: Double,
        x2: Double, y2: Double, r2: Double
    ) -> [(x: Double, y: Double)] {
        let dx = x2 - x1
        let dy = y2 - y1
        let d = hypot(dx, dy)
        if d < 1e-9 || d > r1 + r2 + 1e-7 || d < abs(r1 - r2) - 1e-7 { return [] }
        let a = (r1 * r1 - r2 * r2 + d * d) / (2 * d)
        let h2 = r1 * r1 - a * a
        if h2 < -1e-8 { return [] }
        let h = sqrt(max(0, h2))
        let xm = x1 + a * dx / d
        let ym = y1 + a * dy / d
        if h < 1e-9 { return [(xm, ym)] }
        let rx = -dy * h / d
        let ry = dx * h / d
        return [(xm + rx, ym + ry), (xm - rx, ym - ry)]
    }

    /// Coarse scan used when the contact candidates miss a pocket, and as the
    /// least-overlap fallback when the bundle does not fit.
    private static func gridSpot(
        radius: Double,
        placed: [Disk],
        boreRadius: Double,
        allowOverlap: Bool
    ) -> (x: Double, y: Double)? {
        let limit = boreRadius - radius
        guard limit > 0 else { return nil }
        let step = max(0.012, radius * 0.45)
        var y = -limit
        var best: (x: Double, y: Double, penalty: Double)?
        while y <= limit + 1e-9 {
            let span = sqrt(max(0, limit * limit - y * y))
            var x = -span
            while x <= span + 1e-9 {
                if fits(x: x, y: y, radius: radius, placed: placed, boreRadius: boreRadius) {
                    if !allowOverlap { return (x, y) }
                } else if allowOverlap {
                    let penalty = overlapPenalty(x: x, y: y, radius: radius, placed: placed, boreRadius: boreRadius)
                    if best == nil || penalty < best!.penalty - 1e-9 || (abs(penalty - best!.penalty) < 1e-9 && y < best!.y) {
                        best = (x, y, penalty)
                    }
                }
                x += step
            }
            y += step
        }
        return allowOverlap ? best.map { ($0.x, $0.y) } : nil
    }

    private static func overlapPenalty(
        x: Double,
        y: Double,
        radius: Double,
        placed: [Disk],
        boreRadius: Double
    ) -> Double {
        var penalty = max(0, hypot(x, y) + radius - boreRadius)
        for disk in placed {
            penalty += max(0, radius + disk.radius - hypot(x - disk.x, y - disk.y))
        }
        return penalty
    }
}
