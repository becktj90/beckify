import Foundation

public struct VoltageDropResult: Equatable, Sendable {
    public var dropVolts: Double
    public var dropPercent: Double
    public var receivingVolts: Double
    public var meets3Percent: Bool
    public var meets5Percent: Bool
    public var conductorSize: String
    public var conductorLabel: String
    public var ampacity75C: Int?
    public var ampacityOK: Bool?
    public var formula: String

    public init(
        dropVolts: Double,
        dropPercent: Double,
        receivingVolts: Double,
        meets3Percent: Bool,
        meets5Percent: Bool,
        conductorSize: String,
        conductorLabel: String,
        ampacity75C: Int?,
        ampacityOK: Bool?,
        formula: String
    ) {
        self.dropVolts = dropVolts
        self.dropPercent = dropPercent
        self.receivingVolts = receivingVolts
        self.meets3Percent = meets3Percent
        self.meets5Percent = meets5Percent
        self.conductorSize = conductorSize
        self.conductorLabel = conductorLabel
        self.ampacity75C = ampacity75C
        self.ampacityOK = ampacityOK
        self.formula = formula
    }
}

/// Approximate voltage drop using NEC Chapter 9 Table 9 K-factor at 75 °C.
/// 3 % / 5 % flags are informational (NEC Informational Note), not a hard code limit.
public enum VoltageDrop {
    public static func calculate(
        system: ElectricalSystem,
        current: Double,
        oneWayFeet: Double,
        supplyVolts: Double,
        size: String,
        material: ConductorMaterial
    ) throws -> VoltageDropResult {
        let i = try Positive.require(current, name: "Current")
        let length = try Positive.require(oneWayFeet, name: "One-way length")
        let vs = try Positive.require(supplyVolts, name: "Supply voltage")
        guard let cm = NECTables.circularMils[size] else {
            throw CalcError.notListed("Unknown conductor size \(size).")
        }
        let m = system.voltageDropMultiplier
        let k = material.resistivityK
        let vd = m * k * i * length / cm
        let pct = vd / vs * 100
        let amp = NECTables.ampacity75C(size: size, material: material)
        let ampOK = amp.map { Double($0) >= i }
        let formula = system == .threePhase
            ? "VD = (√3 × K × I × L) / CM"
            : "VD = (2 × K × I × L) / CM"
        return VoltageDropResult(
            dropVolts: vd,
            dropPercent: pct,
            receivingVolts: vs - vd,
            meets3Percent: pct <= 3,
            meets5Percent: pct <= 5,
            conductorSize: size,
            conductorLabel: NECTables.wireLabel(size),
            ampacity75C: amp,
            ampacityOK: ampOK,
            formula: formula
        )
    }
}

public struct ConduitFillGroup: Equatable, Codable, Sendable, Hashable {
    public var quantity: Int
    public var size: String
    public var insulation: ConductorInsulationKind

    public init(quantity: Int, size: String, insulation: ConductorInsulationKind = .thhn) {
        self.quantity = quantity
        self.size = size
        self.insulation = insulation
    }

    public var label: String {
        "\(quantity) × \(NECTables.wireLabel(size)) \(insulation.displayName)"
    }
}

public struct ConduitFillResult: Equatable, Sendable {
    public var conductorCount: Int
    public var conductorSize: String
    public var tradeSize: String
    public var totalWireArea: Double
    public var conduitArea: Double
    public var maxFillPercent: Double
    public var maxFillArea: Double
    public var actualFillPercent: Double
    public var passes: Bool
    public var suggestedTradeSize: String?
    public var formula: String
    public var raceway: RacewayKind
    public var groups: [ConduitFillGroup]
    public var groupAreas: [Double]
    public var fillBasis: String
    public var nipple: Bool
    public var isMixed: Bool

    public init(
        conductorCount: Int,
        conductorSize: String,
        tradeSize: String,
        totalWireArea: Double,
        conduitArea: Double,
        maxFillPercent: Double,
        maxFillArea: Double,
        actualFillPercent: Double,
        passes: Bool,
        suggestedTradeSize: String?,
        formula: String,
        raceway: RacewayKind = .emt,
        groups: [ConduitFillGroup] = [],
        groupAreas: [Double] = [],
        fillBasis: String = "NEC Ch.9 Table 1",
        nipple: Bool = false,
        isMixed: Bool = false
    ) {
        self.conductorCount = conductorCount
        self.conductorSize = conductorSize
        self.tradeSize = tradeSize
        self.totalWireArea = totalWireArea
        self.conduitArea = conduitArea
        self.maxFillPercent = maxFillPercent
        self.maxFillArea = maxFillArea
        self.actualFillPercent = actualFillPercent
        self.passes = passes
        self.suggestedTradeSize = suggestedTradeSize
        self.formula = formula
        self.raceway = raceway
        self.groups = groups
        self.groupAreas = groupAreas
        self.fillBasis = fillBasis
        self.nipple = nipple
        self.isMixed = isMixed
    }
}

/// Chapter 9 Table 1 fill with Table 4 raceway areas and Table 5 conductor areas.
public enum ConduitFill {
    /// Same-size THHN in EMT — original single-size path.
    public static func calculate(quantity: Int, size: String, tradeSize: String) throws -> ConduitFillResult {
        try calculate(
            groups: [ConduitFillGroup(quantity: quantity, size: size, insulation: .thhn)],
            raceway: .emt,
            tradeSize: tradeSize,
            nipple: false
        )
    }

    /// Mixed or same-size fill for any transcribed Table 4 raceway.
    public static func calculate(
        groups: [ConduitFillGroup],
        raceway: RacewayKind,
        tradeSize: String,
        nipple: Bool = false
    ) throws -> ConduitFillResult {
        guard !groups.isEmpty else {
            throw CalcError.missing("at least one conductor group")
        }

        var totalCount = 0
        var totalArea = 0.0
        var areas: [Double] = []
        var normalized: [ConduitFillGroup] = []

        for group in groups {
            let qty = try WholeCount.parse(Double(group.quantity), name: "Conductor quantity")
            guard let wireArea = NECTables.conductorArea(size: group.size, insulation: group.insulation) else {
                throw CalcError.notListed("No \(group.insulation.displayName) area listed for \(NECTables.wireLabel(group.size)).")
            }
            let groupArea = Double(qty) * wireArea
            totalCount += qty
            totalArea += groupArea
            areas.append(groupArea)
            normalized.append(ConduitFillGroup(quantity: qty, size: group.size, insulation: group.insulation))
        }

        guard let conduitArea = NECTables.racewayInternalArea(kind: raceway, trade: tradeSize) else {
            throw CalcError.notListed("Unknown \(raceway.displayName) trade size \(tradeSize).")
        }

        let maxPct = NECTables.table1FillPercent(conductorCount: totalCount, nipple: nipple)
        let maxArea = conduitArea * maxPct / 100
        let fillPct = totalArea / conduitArea * 100
        let pass = totalArea <= maxArea + 1e-12
        let suggested = pass
            ? nil
            : NECTables.smallestTradeSize(kind: raceway, totalWireArea: totalArea, maxFillPercent: maxPct)

        let uniqueSizes = Set(normalized.map(\.size))
        let sizeLabel = uniqueSizes.count == 1
            ? (normalized.first.map { $0.size } ?? "mixed")
            : normalized.map { "\($0.quantity)×\(NECTables.wireLabel($0.size))" }.joined(separator: " + ")

        return ConduitFillResult(
            conductorCount: totalCount,
            conductorSize: sizeLabel,
            tradeSize: tradeSize,
            totalWireArea: totalArea,
            conduitArea: conduitArea,
            maxFillPercent: maxPct,
            maxFillArea: maxArea,
            actualFillPercent: fillPct,
            passes: pass,
            suggestedTradeSize: suggested,
            formula: "Fill % = (Σ conductor areas) / raceway area × 100    NEC Ch.9 Table 1",
            raceway: raceway,
            groups: normalized,
            groupAreas: areas,
            fillBasis: NECTables.table1FillBasis(conductorCount: totalCount, nipple: nipple),
            nipple: nipple,
            isMixed: uniqueSizes.count > 1 || Set(normalized.map(\.insulation)).count > 1
        )
    }

    /// Smallest trade size of `raceway` that holds the groups under Table 1.
    public static func suggestedTradeSize(
        groups: [ConduitFillGroup],
        raceway: RacewayKind = .emt,
        nipple: Bool = false
    ) throws -> String? {
        let count = try groups.reduce(0) { acc, group in
            acc + (try WholeCount.parse(Double(group.quantity), name: "Conductor quantity"))
        }
        let total = try totalArea(groups: groups)
        let maxPct = NECTables.table1FillPercent(conductorCount: count, nipple: nipple)
        return NECTables.smallestTradeSize(kind: raceway, totalWireArea: total, maxFillPercent: maxPct)
    }

    public static func totalArea(groups: [ConduitFillGroup]) throws -> Double {
        var total = 0.0
        for group in groups {
            let qty = try WholeCount.parse(Double(group.quantity), name: "Conductor quantity")
            guard let wireArea = NECTables.conductorArea(size: group.size, insulation: group.insulation) else {
                throw CalcError.notListed("No \(group.insulation.displayName) area listed for \(NECTables.wireLabel(group.size)).")
            }
            total += Double(qty) * wireArea
        }
        return total
    }
}
