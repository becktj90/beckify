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
        formula: String
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
    }
}

/// THHN in EMT using Chapter 9 Table 1 fill percentages and Tables 4 / 5 areas.
public enum ConduitFill {
    public static func calculate(quantity: Int, size: String, tradeSize: String) throws -> ConduitFillResult {
        guard quantity >= 1 else { throw CalcError.nonPositive("Conductor quantity") }
        guard let wireArea = NECTables.thhnArea[size] else {
            throw CalcError.notListed("No THHN area listed for \(size).")
        }
        guard let conduit = NECTables.emtArea.first(where: { $0.trade == tradeSize }) else {
            throw CalcError.notListed("Unknown EMT trade size \(tradeSize).")
        }
        let total = Double(quantity) * wireArea
        let maxPct = NECTables.table1FillPercent(conductorCount: quantity)
        let maxArea = conduit.area * maxPct / 100
        let fillPct = total / conduit.area * 100
        let pass = total <= maxArea
        var suggested: String?
        if !pass {
            suggested = NECTables.emtArea.first(where: { $0.area * maxPct / 100 >= total })?.trade
        }
        return ConduitFillResult(
            conductorCount: quantity,
            conductorSize: size,
            tradeSize: tradeSize,
            totalWireArea: total,
            conduitArea: conduit.area,
            maxFillPercent: maxPct,
            maxFillArea: maxArea,
            actualFillPercent: fillPct,
            passes: pass,
            suggestedTradeSize: suggested,
            formula: "Fill % = (n × conductor area) / raceway area × 100    NEC Ch.9 Table 1"
        )
    }
}
