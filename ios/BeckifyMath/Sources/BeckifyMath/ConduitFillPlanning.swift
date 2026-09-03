import Foundation

public struct ConductorGroup: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var quantity: Int
    public var size: String
    public var insulation: ConductorInsulation
    public var material: ConductorMaterial
    public var purpose: ConductorPurpose
    public var description: String
    public var manufacturerNote: String
    public var countsAsCurrentCarrying: Bool?
    public var customAreaSquareInches: Double?
    public var customOutsideDiameterInches: Double?

    public init(
        id: UUID = UUID(),
        quantity: Int,
        size: String,
        insulation: ConductorInsulation,
        material: ConductorMaterial = .copper,
        purpose: ConductorPurpose = .phase,
        description: String = "",
        manufacturerNote: String = "",
        countsAsCurrentCarrying: Bool? = nil,
        customAreaSquareInches: Double? = nil,
        customOutsideDiameterInches: Double? = nil
    ) {
        self.id = id
        self.quantity = quantity
        self.size = size
        self.insulation = insulation
        self.material = material
        self.purpose = purpose
        self.description = description
        self.manufacturerNote = manufacturerNote
        self.countsAsCurrentCarrying = countsAsCurrentCarrying
        self.customAreaSquareInches = customAreaSquareInches
        self.customOutsideDiameterInches = customOutsideDiameterInches
    }

    public var resolvedCurrentCarrying: Bool? {
        countsAsCurrentCarrying ?? purpose.defaultCountsAsCurrentCarrying
    }

    public var summaryLabel: String {
        let qty = "\(quantity) ×"
        let sizeLabel = NECTables.wireLabel(size)
        let mat = material == .aluminum ? "Al" : "Cu"
        return "\(qty) \(sizeLabel) \(mat) \(insulation.displayName) \(purpose.displayName)"
    }
}

public struct RacewaySelection: Codable, Equatable, Sendable {
    public var type: RacewayType
    public var tradeSize: String
    public var nippleLengthInches: Double?

    public init(type: RacewayType, tradeSize: String, nippleLengthInches: Double? = nil) {
        self.type = type
        self.tradeSize = tradeSize
        self.nippleLengthInches = nippleLengthInches
    }

    public var displayName: String {
        let metric = type.metricDesignator(for: tradeSize).map { " (metric \($0))" } ?? ""
        return "\(tradeSize)\" \(type.displayName)\(metric)"
    }
}

public struct PullRoute: Codable, Equatable, Sendable {
    public var lengthFeet: Double?
    public var totalBendDegrees: Double?
    public var bendCount: Int?
    public var bendRadiusInches: Double?
    public var verticalRiseFeet: Double?
    public var pullPointCount: Int?

    public init(
        lengthFeet: Double? = nil,
        totalBendDegrees: Double? = nil,
        bendCount: Int? = nil,
        bendRadiusInches: Double? = nil,
        verticalRiseFeet: Double? = nil,
        pullPointCount: Int? = nil
    ) {
        self.lengthFeet = lengthFeet
        self.totalBendDegrees = totalBendDegrees
        self.bendCount = bendCount
        self.bendRadiusInches = bendRadiusInches
        self.verticalRiseFeet = verticalRiseFeet
        self.pullPointCount = pullPointCount
    }
}

public struct ConduitFillPreferences: Codable, Equatable, Sendable {
    public var preferredMaximumPercent: Double
    public var pullingLubricantPlanned: Bool
    public var pullingMethod: PullingMethod
    public var manufacturerMaxTensionPounds: Double?
    public var manufacturerSidewallPoundsPerFoot: Double?
    public var currentCarryingOverride: Int?
    public var advancedFrictionCoefficient: Double?

    public init(
        preferredMaximumPercent: Double = 30,
        pullingLubricantPlanned: Bool = false,
        pullingMethod: PullingMethod = .unspecified,
        manufacturerMaxTensionPounds: Double? = nil,
        manufacturerSidewallPoundsPerFoot: Double? = nil,
        currentCarryingOverride: Int? = nil,
        advancedFrictionCoefficient: Double? = nil
    ) {
        self.preferredMaximumPercent = preferredMaximumPercent
        self.pullingLubricantPlanned = pullingLubricantPlanned
        self.pullingMethod = pullingMethod
        self.manufacturerMaxTensionPounds = manufacturerMaxTensionPounds
        self.manufacturerSidewallPoundsPerFoot = manufacturerSidewallPoundsPerFoot
        self.currentCarryingOverride = currentCarryingOverride
        self.advancedFrictionCoefficient = advancedFrictionCoefficient
    }

    public static let defaults = ConduitFillPreferences()
}

public struct InstallationConditions: Codable, Equatable, Sendable {
    public var location: InstallationLocation
    public var runKind: RacewayRunKind

    public init(location: InstallationLocation = .dry, runKind: RacewayRunKind = .normal) {
        self.location = location
        self.runKind = runKind
    }

    public static let defaults = InstallationConditions()
}

public struct ConduitFillInput: Codable, Equatable, Sendable {
    public var groups: [ConductorGroup]
    public var raceway: RacewaySelection
    public var route: PullRoute
    public var preferences: ConduitFillPreferences
    public var installation: InstallationConditions

    public init(
        groups: [ConductorGroup],
        raceway: RacewaySelection,
        route: PullRoute = PullRoute(),
        preferences: ConduitFillPreferences = .defaults,
        installation: InstallationConditions = .defaults
    ) {
        self.groups = groups
        self.raceway = raceway
        self.route = route
        self.preferences = preferences
        self.installation = installation
    }
}

public struct ConductorAreaResult: Equatable, Sendable, Codable {
    public var groupID: UUID
    public var quantity: Int
    public var size: String
    public var insulation: ConductorInsulation
    public var material: ConductorMaterial
    public var purpose: ConductorPurpose
    public var unitArea: Double
    public var totalArea: Double
    public var source: DimensionalSource
    public var usedCustomDimension: Bool
    public var countsAsCurrentCarrying: Bool?
    public var label: String
}

public struct CodeReference: Equatable, Sendable, Codable, Hashable {
    public var citation: String
    public var note: String

    public init(citation: String, note: String) {
        self.citation = citation
        self.note = note
    }
}

public enum ConduitRecommendationKind: String, Codable, Sendable, CaseIterable {
    case noRacewayLargeEnough
    case increaseForCode
    case increaseForPreferred
    case addPullPoint
    case confirmBendLimit
    case useLubricant
    case verifyTension
    case verifySidewall
    case largerBendRadius
    case pullCompleteSet
    case confirmNeutralCCC
    case egcCountsTowardFill
    case reserveFuture
    case checkPullBox
    case jammingReview
    case customDimensionUsed
    case wetLocationNote

    public var sortOrder: Int {
        switch self {
        case .noRacewayLargeEnough: return 0
        case .increaseForCode: return 1
        case .increaseForPreferred: return 2
        case .jammingReview: return 3
        case .addPullPoint: return 4
        case .confirmBendLimit: return 5
        case .useLubricant: return 6
        case .verifyTension: return 7
        case .verifySidewall: return 8
        case .largerBendRadius: return 9
        case .pullCompleteSet: return 10
        case .confirmNeutralCCC: return 11
        case .egcCountsTowardFill: return 12
        case .reserveFuture: return 13
        case .checkPullBox: return 14
        case .customDimensionUsed: return 15
        case .wetLocationNote: return 16
        }
    }
}

public struct ConduitRecommendation: Equatable, Sendable, Codable {
    public var kind: ConduitRecommendationKind
    public var text: String
}

public enum PullPlanningStatus: String, Codable, Sendable, Comparable {
    case favorable
    case moderate
    case difficult
    case engineeringReview

    public var displayName: String {
        switch self {
        case .favorable: return "Favorable"
        case .moderate: return "Moderate"
        case .difficult: return "Difficult"
        case .engineeringReview: return "Engineering review recommended"
        }
    }

    private var rank: Int {
        switch self {
        case .favorable: return 0
        case .moderate: return 1
        case .difficult: return 2
        case .engineeringReview: return 3
        }
    }

    public static func < (lhs: PullPlanningStatus, rhs: PullPlanningStatus) -> Bool {
        lhs.rank < rhs.rank
    }
}

public struct PullPlanningFactor: Equatable, Sendable, Codable {
    public var detail: String
    public var status: PullPlanningStatus
}

public enum JammingScreening: Equatable, Sendable, Codable {
    case unavailable(reason: String)
    case screened(ratio: Double, inCautionBand: Bool, racewayID: Double, conductorOD: Double)

    public var isCaution: Bool {
        if case .screened(_, let caution, _, _) = self { return caution }
        return false
    }
}

public struct RacewaySizeOption: Equatable, Sendable, Codable {
    public var selection: RacewaySelection
    public var racewayArea: Double
    public var actualFillPercent: Double
    public var remainingArea: Double
    public var passesCode: Bool
    public var meetsPreferred: Bool
    public var kind: Kind

    public enum Kind: String, Codable, Sendable {
        case selected
        case minimumCode
        case preferred
        case nextLarger
    }
}

public struct CurrentCarryingReview: Equatable, Sendable, Codable {
    public var physicalConductorCount: Int
    public var automaticCurrentCarryingCount: Int
    public var overrideCount: Int?
    public var reportedCount: Int
    public var unconfirmedNeutralCount: Int
    public var adjustmentReviewMayBeRequired: Bool
    public var notes: [String]
}

public struct PullPlanningResult: Equatable, Sendable, Codable {
    public var status: PullPlanningStatus
    public var factors: [PullPlanningFactor]
    public var jamming: JammingScreening
    public var tensionCalculated: Bool
    public var tensionNote: String
}

public struct ConduitFillDesignResult: Equatable, Sendable {
    public var conductorBreakdown: [ConductorAreaResult]
    public var physicalConductorCount: Int
    public var totalConductorArea: Double
    public var racewayArea: Double
    public var codeMaximumPercent: Double
    public var codeMaximumArea: Double
    public var preferredMaximumPercent: Double
    public var actualFillPercent: Double
    public var remainingArea: Double
    public var remainingPercentPoints: Double
    public var passesCodeFill: Bool
    public var qualifyingNipple: Bool
    public var nippleNote: String
    public var selectedRaceway: RacewaySelection
    public var minimumCompliantRaceway: RacewaySelection?
    public var preferredRaceway: RacewaySelection?
    public var nextLargerRaceway: RacewaySelection?
    public var sizeOptions: [RacewaySizeOption]
    public var currentCarrying: CurrentCarryingReview
    public var pullPlanning: PullPlanningResult
    public var recommendations: [ConduitRecommendation]
    public var references: [CodeReference]
    public var assumptions: [String]
    public var formula: String
    public var edition: NECCodeEdition
}

/// Mixed-conductor raceway fill, code vs preferred size, and qualitative pull planning.
public enum ConduitFillPlanning {
    public static let nippleMaxLengthInches = 24.0
    public static let preferredDefaultPercent = 30.0
    /// Industry three-conductor jam-ratio band (ID / OD), used only as a screen.
    public static let jammingRatioLow = 2.8
    public static let jammingRatioHigh = 3.2

    public static func design(_ input: ConduitFillInput) throws -> ConduitFillDesignResult {
        let groups = input.groups
        guard !groups.isEmpty else { throw CalcError.missing("at least one conductor group") }

        var breakdown: [ConductorAreaResult] = []
        var totalArea = 0.0
        var physicalCount = 0

        for (index, group) in groups.enumerated() {
            let row = try resolveGroup(group, index: index)
            breakdown.append(row)
            totalArea += row.totalArea
            physicalCount += row.quantity
        }

        guard physicalCount >= 1 else { throw CalcError.nonPositive("Conductor quantity") }
        guard totalArea.isFinite, totalArea > 0 else {
            throw CalcError.outOfRange("Total conductor area is not a usable finite value.")
        }

        let nipple = qualifyingNipple(input)
        let codePct = NECTables.table1FillPercent(
            conductorCount: physicalCount,
            qualifyingNipple: nipple.qualifies
        )
        let preferredPct = sanitizedPreferred(input.preferences.preferredMaximumPercent)

        guard let selectedArea = input.raceway.type.area(for: input.raceway.tradeSize) else {
            throw CalcError.notListed(
                "\(input.raceway.tradeSize)\" is not a listed \(input.raceway.type.displayName) trade size in Chapter 9 Table 4."
            )
        }
        guard selectedArea.isFinite, selectedArea > 0 else {
            throw CalcError.outOfRange("Raceway internal area is not a usable finite value.")
        }

        let maxArea = selectedArea * codePct / 100
        let fillPct = totalArea / selectedArea * 100
        guard fillPct.isFinite else {
            throw CalcError.outOfRange("Fill percentage overflowed. Check quantity and custom area.")
        }
        let remainingArea = selectedArea - totalArea
        let remainingPoints = codePct - fillPct
        let passes = totalArea <= maxArea || almostEqual(totalArea, maxArea)

        let minSel = smallestTrade(
            type: input.raceway.type,
            totalArea: totalArea,
            maxPercent: codePct
        )
        let prefSel = smallestTrade(
            type: input.raceway.type,
            totalArea: totalArea,
            maxPercent: preferredPct
        )
        let nextSel = nextLarger(
            type: input.raceway.type,
            after: preferredOrSelected(preferred: prefSel, selected: input.raceway, minimum: minSel)
        )

        let options = sizeOptions(
            type: input.raceway.type,
            selected: input.raceway,
            minimum: minSel,
            preferred: prefSel,
            next: nextSel,
            totalArea: totalArea,
            codePct: codePct,
            preferredPct: preferredPct
        )

        let ccc = currentCarryingReview(groups: groups, breakdown: breakdown, physical: physicalCount, override: input.preferences.currentCarryingOverride)
        let jam = jammingScreening(breakdown: breakdown, raceway: input.raceway, physical: physicalCount)
        let pull = pullPlanning(
            input: input,
            fillPct: fillPct,
            codePct: codePct,
            preferredPct: preferredPct,
            passes: passes,
            physical: physicalCount,
            breakdown: breakdown,
            jam: jam
        )
        let recs = recommendations(
            input: input,
            fillPct: fillPct,
            preferredPct: preferredPct,
            passes: passes,
            minSel: minSel,
            prefSel: prefSel,
            nipple: nipple,
            ccc: ccc,
            pull: pull,
            breakdown: breakdown,
            totalArea: totalArea,
            selectedArea: selectedArea
        )

        return ConduitFillDesignResult(
            conductorBreakdown: breakdown,
            physicalConductorCount: physicalCount,
            totalConductorArea: totalArea,
            racewayArea: selectedArea,
            codeMaximumPercent: codePct,
            codeMaximumArea: maxArea,
            preferredMaximumPercent: preferredPct,
            actualFillPercent: fillPct,
            remainingArea: remainingArea,
            remainingPercentPoints: remainingPoints,
            passesCodeFill: passes,
            qualifyingNipple: nipple.qualifies,
            nippleNote: nipple.note,
            selectedRaceway: input.raceway,
            minimumCompliantRaceway: minSel,
            preferredRaceway: prefSel,
            nextLargerRaceway: nextSel,
            sizeOptions: options,
            currentCarrying: ccc,
            pullPlanning: pull,
            recommendations: recs,
            references: references(input: input, nipple: nipple.qualifies, ccc: ccc),
            assumptions: assumptions(input: input, nipple: nipple, jam: jam),
            formula: formulaText(
                physical: physicalCount,
                totalArea: totalArea,
                racewayArea: selectedArea,
                fillPct: fillPct,
                codePct: codePct
            ),
            edition: NECDimensionalCatalog.edition
        )
    }

    public static func groups(for preset: ConduitFillPreset) -> [ConductorGroup] {
        switch preset {
        case .singlePhaseBranch:
            return [
                ConductorGroup(quantity: 1, size: "12", insulation: .thhnTHWN2, purpose: .phase, description: "Ungrounded", countsAsCurrentCarrying: true),
                ConductorGroup(quantity: 1, size: "12", insulation: .thhnTHWN2, purpose: .neutral, description: "Neutral — CCC not assumed", countsAsCurrentCarrying: nil),
                ConductorGroup(quantity: 1, size: "12", insulation: .thhnTHWN2, purpose: .equipmentGround, description: "EGC", countsAsCurrentCarrying: false),
            ]
        case .threePhaseFeeder:
            return [
                ConductorGroup(quantity: 3, size: "3/0", insulation: .thhnTHWN2, purpose: .phase, description: "Phase A/B/C", countsAsCurrentCarrying: true),
            ]
        case .threePhaseFeederWithNeutralAndEGC:
            return [
                ConductorGroup(quantity: 3, size: "3/0", insulation: .thhnTHWN2, purpose: .phase, description: "Phase A/B/C", countsAsCurrentCarrying: true),
                ConductorGroup(quantity: 1, size: "3/0", insulation: .thhnTHWN2, purpose: .neutral, description: "Neutral — CCC not assumed", countsAsCurrentCarrying: nil),
                ConductorGroup(quantity: 1, size: "4", insulation: .thhnTHWN2, purpose: .equipmentGround, description: "EGC", countsAsCurrentCarrying: false),
                ConductorGroup(quantity: 4, size: "12", insulation: .thhnTHWN2, purpose: .control, description: "Control", countsAsCurrentCarrying: true),
            ]
        case .controlCircuit:
            return [
                ConductorGroup(quantity: 4, size: "12", insulation: .thhnTHWN2, purpose: .control, description: "Control", countsAsCurrentCarrying: true),
            ]
        case .custom:
            return [
                ConductorGroup(quantity: 1, size: "12", insulation: .thhnTHWN2, purpose: .phase, countsAsCurrentCarrying: true),
            ]
        }
    }

    // MARK: - Group resolution

    private static func resolveGroup(_ group: ConductorGroup, index: Int) throws -> ConductorAreaResult {
        let qty = try WholeCount.parse(Double(group.quantity), name: "Conductor quantity in row \(index + 1)")
        let customArea = finitePositive(group.customAreaSquareInches)
        let customOD = finitePositive(group.customOutsideDiameterInches)

        let unitArea: Double
        let usedCustom: Bool
        let source: DimensionalSource

        if let customArea {
            unitArea = customArea
            usedCustom = true
            source = DimensionalSource(
                table: "User / manufacturer area",
                units: "in²",
                sizeRange: NECTables.wireLabel(group.size),
                notes: group.manufacturerNote
            )
        } else if let customOD {
            unitArea = Double.pi * (customOD / 2) * (customOD / 2)
            usedCustom = true
            source = DimensionalSource(
                table: "User / manufacturer OD → area π(d/2)²",
                units: "in",
                sizeRange: NECTables.wireLabel(group.size),
                notes: group.manufacturerNote
            )
        } else if let listed = group.insulation.listedArea(for: group.size) {
            unitArea = listed
            usedCustom = false
            source = group.insulation.source
        } else if !group.insulation.hasListedTable5Area {
            throw CalcError.notListed(
                "\(group.insulation.displayName) has no listed area in this dataset for \(NECTables.wireLabel(group.size)). Enter a manufacturer area or OD — THHN area is not substituted."
            )
        } else {
            throw CalcError.notListed("No \(group.insulation.displayName) area listed for \(NECTables.wireLabel(group.size)).")
        }

        guard unitArea.isFinite, unitArea > 0 else {
            throw CalcError.outOfRange("Conductor area in row \(index + 1) is not a usable finite value.")
        }
        let total = Double(qty) * unitArea
        guard total.isFinite else {
            throw CalcError.outOfRange("Conductor area in row \(index + 1) overflowed.")
        }

        return ConductorAreaResult(
            groupID: group.id,
            quantity: qty,
            size: group.size,
            insulation: group.insulation,
            material: group.material,
            purpose: group.purpose,
            unitArea: unitArea,
            totalArea: total,
            source: source,
            usedCustomDimension: usedCustom,
            countsAsCurrentCarrying: group.resolvedCurrentCarrying,
            label: group.summaryLabel
        )
    }

    private static func finitePositive(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value > 0 else { return nil }
        return value
    }

    // MARK: - Nipple

    private struct NippleDecision {
        var qualifies: Bool
        var note: String
    }

    private static func qualifyingNipple(_ input: ConduitFillInput) -> NippleDecision {
        guard input.installation.runKind == .nipple else {
            return NippleDecision(qualifies: false, note: "Normal run — Chapter 9 Table 1 percentages apply.")
        }
        guard let length = input.raceway.nippleLengthInches ?? input.route.lengthFeet.map({ $0 * 12 }) else {
            return NippleDecision(
                qualifies: false,
                note: "Nipple selected but length is missing, so the 60% Note 4 allowance is not applied."
            )
        }
        guard length.isFinite, length > 0 else {
            return NippleDecision(qualifies: false, note: "Nipple length is not a usable finite value, so Note 4 is not applied.")
        }
        if length <= nippleMaxLengthInches {
            return NippleDecision(
                qualifies: true,
                note: "Qualifying nipple \(format(length, 2)) in (≤ 24 in) — Chapter 9 Table 1 Note 4 permits 60% fill between boxes or cabinets."
            )
        }
        return NippleDecision(
            qualifies: false,
            note: "Entered nipple length \(format(length, 2)) in exceeds 24 in, so Table 1 Note 4 does not apply."
        )
    }

    // MARK: - Sizing

    private static func sanitizedPreferred(_ value: Double) -> Double {
        guard value.isFinite, value > 0, value < 100 else { return preferredDefaultPercent }
        return value
    }

    private static func smallestTrade(type: RacewayType, totalArea: Double, maxPercent: Double) -> RacewaySelection? {
        for trade in type.orderedTradeSizes {
            guard let area = type.area(for: trade) else { continue }
            let allowed = area * maxPercent / 100
            if totalArea <= allowed || almostEqual(totalArea, allowed) {
                return RacewaySelection(type: type, tradeSize: trade)
            }
        }
        return nil
    }

    private static func nextLarger(type: RacewayType, after: RacewaySelection?) -> RacewaySelection? {
        guard let after else { return nil }
        let sizes = type.orderedTradeSizes
        guard let idx = sizes.firstIndex(of: after.tradeSize), idx + 1 < sizes.count else { return nil }
        return RacewaySelection(type: type, tradeSize: sizes[idx + 1])
    }

    private static func preferredOrSelected(
        preferred: RacewaySelection?,
        selected: RacewaySelection,
        minimum: RacewaySelection?
    ) -> RacewaySelection? {
        preferred ?? minimum ?? selected
    }

    private static func sizeOptions(
        type: RacewayType,
        selected: RacewaySelection,
        minimum: RacewaySelection?,
        preferred: RacewaySelection?,
        next: RacewaySelection?,
        totalArea: Double,
        codePct: Double,
        preferredPct: Double
    ) -> [RacewaySizeOption] {
        var seen = Set<String>()
        var rows: [RacewaySizeOption] = []
        func add(_ sel: RacewaySelection?, kind: RacewaySizeOption.Kind) {
            guard let sel, let area = type.area(for: sel.tradeSize), !seen.contains(sel.tradeSize) else { return }
            seen.insert(sel.tradeSize)
            let fill = totalArea / area * 100
            let allowed = area * codePct / 100
            rows.append(
                RacewaySizeOption(
                    selection: RacewaySelection(type: type, tradeSize: sel.tradeSize),
                    racewayArea: area,
                    actualFillPercent: fill,
                    remainingArea: area - totalArea,
                    passesCode: totalArea <= allowed || almostEqual(totalArea, allowed),
                    meetsPreferred: fill <= preferredPct || almostEqual(fill, preferredPct),
                    kind: kind
                )
            )
        }
        add(selected, kind: .selected)
        add(minimum, kind: .minimumCode)
        add(preferred, kind: .preferred)
        add(next, kind: .nextLarger)
        return rows
    }

    // MARK: - CCC

    private static func currentCarryingReview(
        groups: [ConductorGroup],
        breakdown: [ConductorAreaResult],
        physical: Int,
        override: Int?
    ) -> CurrentCarryingReview {
        let automatic = breakdown.reduce(0) { $0 + (($1.countsAsCurrentCarrying == true) ? $1.quantity : 0) }
        let unconfirmed = groups.reduce(0) { partial, group in
            group.purpose == .neutral && group.resolvedCurrentCarrying == nil ? partial + group.quantity : partial
        }
        var notes = [
            "Every installed conductor counts toward physical fill, including equipment grounding conductors, neutrals, controls, and spares.",
            "Not every conductor is current-carrying for 310.15(C)(1) adjustment. This review does not size ampacity.",
        ]
        if unconfirmed > 0 {
            notes.append("Neutral current-carrying treatment is not assumed. Confirm whether the \(unconfirmed) unmarked neutral(s) are current-carrying before applying adjustment factors.")
        }
        let reported: Int
        if let override {
            reported = override
            notes.append("Current-carrying count uses the user override (\(override)).")
        } else {
            reported = automatic
        }
        let mayNeed = reported > 3
        if mayNeed {
            notes.append("More than three current-carrying conductors — review NEC 2023 Table 310.15(C)(1) in the Wire Size & Ampacity tool. This fill result does not apply derating.")
        }
        return CurrentCarryingReview(
            physicalConductorCount: physical,
            automaticCurrentCarryingCount: automatic,
            overrideCount: override,
            reportedCount: reported,
            unconfirmedNeutralCount: unconfirmed,
            adjustmentReviewMayBeRequired: mayNeed,
            notes: notes
        )
    }

    // MARK: - Jamming

    private static func jammingScreening(
        breakdown: [ConductorAreaResult],
        raceway: RacewaySelection,
        physical: Int
    ) -> JammingScreening {
        guard physical == 3 else {
            return .unavailable(reason: "Three-conductor jamming screening applies only when exactly three conductors are installed.")
        }
        let ods = breakdown.compactMap { row -> Double? in
            derivedOD(row)
        }
        guard ods.count == breakdown.count, let first = ods.first else {
            return .unavailable(reason: "Conductor outside diameter is missing, so jamming cannot be screened.")
        }
        let unique = Set(ods.map { ($0 * 1e6).rounded() / 1e6 })
        guard unique.count == 1 else {
            return .unavailable(reason: "Mixed conductor diameters — the 2.8–3.2 jam-ratio screen is for three same-size conductors.")
        }
        guard let id = raceway.type.derivedInternalDiameterInches(for: raceway.tradeSize) else {
            return .unavailable(reason: "Raceway internal diameter could not be derived from the listed Table 4 area.")
        }
        let ratio = id / first
        guard ratio.isFinite, ratio > 0 else {
            return .unavailable(reason: "Jam ratio is not a usable finite value.")
        }
        let caution = ratio >= jammingRatioLow && ratio <= jammingRatioHigh
        return .screened(ratio: ratio, inCautionBand: caution, racewayID: id, conductorOD: first)
    }

    private static func derivedOD(_ row: ConductorAreaResult) -> Double? {
        guard row.unitArea > 0, row.unitArea.isFinite else { return nil }
        return 2 * (row.unitArea / Double.pi).squareRoot()
    }

    // MARK: - Pull planning

    private static func pullPlanning(
        input: ConduitFillInput,
        fillPct: Double,
        codePct: Double,
        preferredPct: Double,
        passes: Bool,
        physical: Int,
        breakdown: [ConductorAreaResult],
        jam: JammingScreening
    ) -> PullPlanningResult {
        var factors: [PullPlanningFactor] = []
        var status: PullPlanningStatus = .favorable

        func bump(_ next: PullPlanningStatus, _ detail: String) {
            factors.append(PullPlanningFactor(detail: detail, status: next))
            if next > status { status = next }
        }

        if !passes {
            bump(.engineeringReview, "Selected raceway exceeds the applicable Chapter 9 Table 1 fill limit (\(format(fillPct, 2))% vs \(format(codePct, 0))%).")
        } else if fillPct > preferredPct {
            bump(.difficult, "Fill \(format(fillPct, 2))% is over the \(format(preferredPct, 0))% Beckify preferred-fill target (not a code limit).")
        } else if fillPct > 25 {
            bump(.moderate, "Fill \(format(fillPct, 2))% is code-compliant but not spacious.")
        } else {
            bump(.favorable, "Fill \(format(fillPct, 2))% is at or under the preferred target.")
        }

        if let length = input.route.lengthFeet, length.isFinite, length > 0 {
            if length > 200 {
                bump(.difficult, "Entered run length \(format(length, 1)) ft is a long pull.")
            } else if length > 80 {
                bump(.moderate, "Entered run length \(format(length, 1)) ft is a moderate pull.")
            } else {
                bump(.favorable, "Entered run length \(format(length, 1)) ft.")
            }
        }

        if let deg = input.route.totalBendDegrees, deg.isFinite, deg > 0 {
            if deg > 360 {
                bump(.engineeringReview, "Entered \(format(deg, 0))° of bends exceeds the typical 360° between pull points. Confirm \(input.raceway.type.displayName) \(input.raceway.type.bendArticle).")
            } else if deg > 180 {
                bump(.difficult, "Entered \(format(deg, 0))° of bends is a substantial cumulative bend.")
            } else {
                bump(.moderate, "Entered \(format(deg, 0))° of bends.")
            }
        } else if let count = input.route.bendCount, count >= 3 {
            bump(.moderate, "Entered \(count) bends without total degrees.")
        }

        if let rise = input.route.verticalRiseFeet, rise.isFinite, rise > 15 {
            bump(.difficult, "Vertical rise \(format(rise, 1)) ft is entered.")
        }

        let largest = breakdown.max(by: { $0.unitArea < $1.unitArea })
        if let largest, indexOfSize(largest.size) >= indexOfSize("1/0") {
            bump(.moderate, "Largest conductor is \(NECTables.wireLabel(largest.size)).")
        }

        let distinctSizes = Set(breakdown.map(\.size))
        if distinctSizes.count > 1 {
            bump(.moderate, "Mixed conductor sizes (\(distinctSizes.count) sizes) are in the same raceway.")
        }

        if jam.isCaution {
            bump(.engineeringReview, "Three-conductor jam-ratio screen is in the 2.8–3.2 caution band.")
        }

        let pulls = input.route.pullPointCount ?? 0
        if let length = input.route.lengthFeet, length > 80, pulls < 1,
           let deg = input.route.totalBendDegrees, deg >= 180 {
            bump(.difficult, "Long pull with substantial bends and no intermediate pull point entered.")
        }

        if input.preferences.manufacturerMaxTensionPounds == nil,
           status >= .difficult {
            bump(.engineeringReview, "Manufacturer maximum pulling tension was not entered. No generic safe tension is assumed.")
        }

        let tensionNote: String
        if input.preferences.manufacturerMaxTensionPounds != nil || input.preferences.manufacturerSidewallPoundsPerFoot != nil {
            tensionNote = "Manufacturer limits were entered for reference only. Pulling tension and sidewall pressure are not calculated — attachment method, construction, and a verified equation are not available in this tool."
        } else if input.preferences.advancedFrictionCoefficient != nil {
            tensionNote = "A friction coefficient was entered, but tension is still not calculated. A validated pulling-equation set and attachment method are required before any pound-force result."
        } else {
            tensionNote = "No pulling-tension or sidewall-pressure calculation is performed. Maximum tension depends on conductor material, attachment method, cable construction, and the manufacturer limit."
        }

        return PullPlanningResult(
            status: status,
            factors: factors,
            jamming: jam,
            tensionCalculated: false,
            tensionNote: tensionNote
        )
    }

    private static func indexOfSize(_ size: String) -> Int {
        NECTables.wireSizeOrder.firstIndex(of: size) ?? 0
    }

    // MARK: - Recommendations

    private static func recommendations(
        input: ConduitFillInput,
        fillPct: Double,
        preferredPct: Double,
        passes: Bool,
        minSel: RacewaySelection?,
        prefSel: RacewaySelection?,
        nipple: NippleDecision,
        ccc: CurrentCarryingReview,
        pull: PullPlanningResult,
        breakdown: [ConductorAreaResult],
        totalArea: Double,
        selectedArea: Double
    ) -> [ConduitRecommendation] {
        var list: [ConduitRecommendation] = []
        let selected = input.raceway.displayName
        let type = input.raceway.type

        if !passes {
            if let minSel, let minArea = type.area(for: minSel.tradeSize) {
                let newFill = totalArea / minArea * 100
                list.append(ConduitRecommendation(
                    kind: .increaseForCode,
                    text: "Increase from \(selected) to \(minSel.displayName) to satisfy the \(format(NECTables.table1FillPercent(conductorCount: ccc.physicalConductorCount, qualifyingNipple: nipple.qualifies), 0))% Chapter 9 Table 1 limit. Fill would drop from \(format(fillPct, 1))% to \(format(newFill, 1))%."
                ))
            } else {
                list.append(ConduitRecommendation(
                    kind: .noRacewayLargeEnough,
                    text: "No listed \(type.displayName) trade size has enough internal area at the applicable Table 1 percentage for \(format(totalArea, 4)) in² of conductor."
                ))
            }
        } else if fillPct > preferredPct, let prefSel, prefSel.tradeSize != input.raceway.tradeSize,
                  let prefArea = type.area(for: prefSel.tradeSize) {
            let newFill = totalArea / prefArea * 100
            list.append(ConduitRecommendation(
                kind: .increaseForPreferred,
                text: "Increase from \(selected) to \(prefSel.displayName) to reduce fill from \(format(fillPct, 1))% to \(format(newFill, 1))%. That larger size is a Beckify preferred-fill choice, not an NEC requirement."
            ))
        }

        if case .screened(let ratio, true, _, _) = pull.jamming {
            list.append(ConduitRecommendation(
                kind: .jammingReview,
                text: "Jam ratio \(format(ratio, 2)) is inside the 2.8–3.2 three-conductor caution band (derived ID/OD). This is a screening indicator, not proof that jamming will occur."
            ))
        }

        let long = (input.route.lengthFeet ?? 0) > 80
        let bent = (input.route.totalBendDegrees ?? 0) >= 180
        if long && bent && (input.route.pullPointCount ?? 0) < 1 {
            list.append(ConduitRecommendation(
                kind: .addPullPoint,
                text: "Add an intermediate pull point. The entered route is \(format(input.route.lengthFeet ?? 0, 0)) ft with \(format(input.route.totalBendDegrees ?? 0, 0))° of bends and no pull point."
            ))
            list.append(ConduitRecommendation(
                kind: .checkPullBox,
                text: "If a pull point is added, size the pull box or junction box separately. This tool does not apply 314.28."
            ))
        }

        if let deg = input.route.totalBendDegrees, deg > 360 {
            list.append(ConduitRecommendation(
                kind: .confirmBendLimit,
                text: "Confirm \(type.displayName) article \(type.bendArticle) permitted bend total between pull points. Entered total is \(format(deg, 0))°."
            ))
        }

        if pull.status >= .difficult, !input.preferences.pullingLubricantPlanned {
            list.append(ConduitRecommendation(
                kind: .useLubricant,
                text: "Use a listed pulling lubricant compatible with \(breakdown.map(\.insulation.displayName).uniqued.joined(separator: ", ")) and \(type.displayName)."
            ))
        }

        if pull.status >= .moderate, input.preferences.manufacturerMaxTensionPounds == nil {
            list.append(ConduitRecommendation(
                kind: .verifyTension,
                text: "Verify the manufacturer’s maximum pulling tension for the attachment method (basket, pulling eye, or harness). This tool does not invent a safe tension."
            ))
        }

        if let deg = input.route.totalBendDegrees, deg > 0, input.preferences.manufacturerSidewallPoundsPerFoot == nil, pull.status >= .moderate {
            list.append(ConduitRecommendation(
                kind: .verifySidewall,
                text: "Verify sidewall-pressure limits at bends. No sidewall-pressure calculation is performed without a manufacturer limit and a validated equation."
            ))
        }

        if let largest = breakdown.max(by: { $0.unitArea < $1.unitArea }),
           indexOfSize(largest.size) >= indexOfSize("4/0"),
           let radius = input.route.bendRadiusInches, radius.isFinite, radius > 0,
           let od = derivedOD(largest), radius < 8 * od {
            list.append(ConduitRecommendation(
                kind: .largerBendRadius,
                text: "Consider a larger bend radius for \(NECTables.wireLabel(largest.size)). Entered radius \(format(radius, 1)) in is less than 8× the derived conductor OD."
            ))
        }

        if ccc.physicalConductorCount >= 3 {
            list.append(ConduitRecommendation(
                kind: .pullCompleteSet,
                text: "Pull the complete conductor set together when the installation method requires it. Staggered pulls are not evaluated here."
            ))
        }

        if ccc.unconfirmedNeutralCount > 0 {
            list.append(ConduitRecommendation(
                kind: .confirmNeutralCCC,
                text: "Confirm neutral current-carrying treatment for \(ccc.unconfirmedNeutralCount) unmarked neutral(s) before applying 310.15(C)(1)."
            ))
        }

        if breakdown.contains(where: { $0.purpose == .equipmentGround }) {
            list.append(ConduitRecommendation(
                kind: .egcCountsTowardFill,
                text: "Equipment grounding conductors count toward physical fill even when they are not current-carrying for adjustment."
            ))
        }

        if !breakdown.contains(where: { $0.purpose == .spare }), passes, fillPct > 20 {
            list.append(ConduitRecommendation(
                kind: .reserveFuture,
                text: "Selected fill is \(format(fillPct, 1))% of \(format(selectedArea, 3)) in². Reserve additional capacity if future conductors are expected."
            ))
        }

        if breakdown.contains(where: { $0.usedCustomDimension }) {
            list.append(ConduitRecommendation(
                kind: .customDimensionUsed,
                text: "One or more rows use a manufacturer or custom area/OD instead of Table 5. Confirm the product sheet before construction."
            ))
        }

        if input.installation.location == .wet {
            list.append(ConduitRecommendation(
                kind: .wetLocationNote,
                text: "Wet location is recorded for field notes only. Fill percentages do not change. Confirm the insulation listing for wet use (THHN/THWN-2 is dual-rated; THHN-only is not assumed)."
            ))
        }

        return list.sorted { $0.kind.sortOrder < $1.kind.sortOrder }
    }

    // MARK: - References / assumptions

    private static func references(input: ConduitFillInput, nipple: Bool, ccc: CurrentCarryingReview) -> [CodeReference] {
        var refs = [
            CodeReference(citation: "NEC 2023 Art. 300.17", note: "Conductors in raceway shall not fill so as to prevent installation or withdrawal."),
            CodeReference(citation: "NEC 2023 Chapter 9 Table 1", note: "Maximum percent of raceway cross-section: 53% / 31% / 40% by conductor count."),
            CodeReference(citation: "NEC 2023 Chapter 9 Table 4", note: "\(input.raceway.type.displayName) total internal area."),
            CodeReference(citation: "NEC 2023 Chapter 9 Table 5", note: "Insulated conductor dimensions for types listed in this dataset."),
        ]
        if nipple {
            refs.append(CodeReference(citation: "NEC 2023 Chapter 9 Table 1 Note 4", note: "Nipples ≤ 24 in between boxes or cabinets may be filled to 60%."))
        }
        refs.append(CodeReference(citation: "NEC 2023 \(input.raceway.type.bendArticle)", note: "Confirm permitted bends between pull points for \(input.raceway.type.displayName)."))
        if ccc.adjustmentReviewMayBeRequired {
            refs.append(CodeReference(citation: "NEC 2023 Table 310.15(C)(1)", note: "Adjustment for more than three current-carrying conductors — not applied in this fill result."))
        }
        return refs
    }

    private static func assumptions(input: ConduitFillInput, nipple: NippleDecision, jam: JammingScreening) -> [String] {
        var list = [
            "Physical fill sums quantity × listed or custom area for every row. Mixed sizes are not replaced by a single size.",
            "Multiconductor cable assemblies are not calculated. Do not treat cable fill as the sum of the internal conductors.",
            "Preferred maximum fill is a Beckify design preference, not an NEC requirement.",
            nipple.note,
            "Installation-planning status is qualitative. It is not a guarantee that a pull will succeed.",
            "No generic safe pulling tension is provided.",
        ]
        switch jam {
        case .unavailable(let reason):
            list.append("Jamming analysis unavailable: \(reason)")
        case .screened:
            list.append("Jam ratio uses equivalent circular diameters derived from listed Table 4 / Table 5 areas (or custom OD). It is a screen, not a packing proof.")
        }
        if input.installation.location == .wet {
            list.append("Wet/dry context does not change Table 1 percentages.")
        }
        return list
    }

    private static func formulaText(physical: Int, totalArea: Double, racewayArea: Double, fillPct: Double, codePct: Double) -> String {
        "Fill % = (Σ qty × conductor area) / raceway area × 100 = \(format(totalArea, 4)) / \(format(racewayArea, 3)) × 100 = \(format(fillPct, 2))%   limit \(format(codePct, 0))% for \(physical) conductor(s)  NEC 2023 Ch.9 Table 1"
    }

    private static func almostEqual(_ a: Double, _ b: Double) -> Bool {
        abs(a - b) <= max(1e-12, abs(b) * 1e-12)
    }

    private static func format(_ value: Double, _ digits: Int) -> String {
        String(format: "%.\(digits)f", value)
    }
}

private extension Array where Element == String {
    var uniqued: [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}

/// Last-used / saved-job snapshot. Version 1 is the legacy single-size THHN/EMT job.
public struct ConduitFillJobSnapshot: Codable, Equatable, Sendable {
    public var version: Int
    public var input: ConduitFillInput

    public init(version: Int = 2, input: ConduitFillInput) {
        self.version = version
        self.input = input
    }

    /// Restore a v2 JSON blob or a v1 `n` / `size` / `emt` dictionary.
    public static func decode(from inputs: [String: String]) throws -> ConduitFillJobSnapshot {
        if let blob = inputs["v2"], let data = blob.data(using: .utf8) {
            return try JSONDecoder().decode(ConduitFillJobSnapshot.self, from: data)
        }
        guard let qtyText = inputs["n"], let size = inputs["size"], let trade = inputs["emt"] else {
            throw CalcError.missing("saved conduit-fill inputs")
        }
        guard let qtyValue = Double(qtyText) else {
            throw CalcError.outOfRange("Saved conductor quantity is not a number.")
        }
        let qty = try WholeCount.parse(qtyValue, name: "Saved conductor quantity")
        let group = ConductorGroup(
            quantity: qty,
            size: size,
            insulation: .thhnTHWN2,
            material: .copper,
            purpose: .phase,
            description: "Restored single-size THHN job",
            countsAsCurrentCarrying: true
        )
        return ConduitFillJobSnapshot(
            version: 1,
            input: ConduitFillInput(
                groups: [group],
                raceway: RacewaySelection(type: .emt, tradeSize: trade)
            )
        )
    }

    public func encodeInputs() -> [String: String] {
        let data = (try? JSONEncoder().encode(self)) ?? Data()
        let blob = String(data: data, encoding: .utf8) ?? ""
        let first = input.groups.first
        return [
            "v2": blob,
            "n": first.map { String($0.quantity) } ?? "",
            "size": first?.size ?? "",
            "emt": input.raceway.tradeSize,
        ]
    }
}
