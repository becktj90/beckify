import Foundation

public enum LoadWorksheetOccupancy: String, Codable, CaseIterable, Sendable {
    case dwelling
    case hospital
    case hotel
    case warehouse
    case other

    public var label: String {
        switch self {
        case .dwelling: return "Dwelling (220.42)"
        case .hospital: return "Hospital (220.42)"
        case .hotel: return "Hotel / motel (220.42)"
        case .warehouse: return "Warehouse storage (220.42)"
        case .other: return "All others — 100%"
        }
    }

    /// Stepped demand factors (upTo VA ceiling, factor).
    public var lightingSteps: [(upTo: Double, factor: Double)] {
        switch self {
        case .dwelling: return [(3000, 1.0), (120_000, 0.35), (.infinity, 0.25)]
        case .hospital: return [(50_000, 0.40), (.infinity, 0.20)]
        case .hotel: return [(20_000, 0.50), (100_000, 0.40), (.infinity, 0.30)]
        case .warehouse: return [(12_500, 1.0), (.infinity, 0.50)]
        case .other: return [(.infinity, 1.0)]
        }
    }
}

public enum LoadRowType: String, Codable, CaseIterable, Sendable, Hashable {
    case lighting
    case receptacle
    case continuous
    case motor
    case other

    public var label: String {
        switch self {
        case .lighting: return "Lighting"
        case .receptacle: return "Receptacle"
        case .continuous: return "Continuous"
        case .motor: return "Motor"
        case .other: return "Other"
        }
    }
}

public struct LoadWorksheetRow: Equatable, Sendable, Identifiable {
    public var id: String
    public var description: String
    public var type: LoadRowType
    public var quantity: Double
    public var vaEach: Double

    public init(
        id: String = UUID().uuidString,
        description: String,
        type: LoadRowType,
        quantity: Double = 1,
        vaEach: Double
    ) {
        self.id = id
        self.description = description
        self.type = type
        self.quantity = quantity
        self.vaEach = vaEach
    }

    public var connectedVA: Double { quantity * vaEach }
}

public struct LoadWorksheetResult: Equatable, Sendable {
    public var connectedVA: Double
    public var lightingConnectedVA: Double
    public var lightingDemandVA: Double
    public var otherDemandVA: Double
    public var continuousAddVA: Double
    public var totalDemandVA: Double
    public var spareVA: Double
    public var grandTotalVA: Double
    public var amps: Double
    public var voltage: Double
    public var phases: Int
    public var formula: String
}

/// NEC 220 feeder/service worksheet (simplified commercial path). Design aid.
public enum LoadWorksheet {
    public static func lightingDemand(connectedVA: Double, occupancy: LoadWorksheetOccupancy) -> Double {
        var remaining = max(0, connectedVA)
        var previous = 0.0
        var demand = 0.0
        for step in occupancy.lightingSteps {
            let band = min(remaining, step.upTo - previous)
            if band <= 0 { break }
            demand += band * step.factor
            remaining -= band
            previous = step.upTo
            if remaining <= 1e-9 { break }
        }
        return demand
    }

    public static func calculate(
        rows: [LoadWorksheetRow],
        occupancy: LoadWorksheetOccupancy,
        voltage: Double,
        phases: Int,
        sparePercent: Double = 0
    ) throws -> LoadWorksheetResult {
        let v = try Positive.require(voltage, name: "Voltage")
        guard phases == 1 || phases == 3 else {
            throw CalcError.outOfRange("Phases must be 1 or 3.")
        }
        let spare = max(0, sparePercent)
        guard spare.isFinite else { throw CalcError.outOfRange("Spare percent must be finite.") }

        var lighting = 0.0
        var other = 0.0
        var continuousExtra = 0.0
        var connected = 0.0

        for row in rows {
            let va = row.connectedVA
            guard va.isFinite, va >= 0, row.quantity.isFinite, row.quantity >= 0 else {
                throw CalcError.outOfRange("Load row values must be finite and not negative.")
            }
            connected += va
            switch row.type {
            case .lighting:
                lighting += va
            case .continuous:
                other += va
                continuousExtra += va * 0.25 // already at 100%; add 25% for continuous
            case .motor:
                other += va * 1.25
            case .receptacle, .other:
                other += va
            }
        }

        let lightingDemand = lightingDemand(connectedVA: lighting, occupancy: occupancy)
        let demand = lightingDemand + other
        let spareVA = demand * spare / 100
        let grand = demand + spareVA
        let amps = phases == 3 ? grand / (sqrt(3) * v) : grand / v

        return LoadWorksheetResult(
            connectedVA: connected,
            lightingConnectedVA: lighting,
            lightingDemandVA: lightingDemand,
            otherDemandVA: other,
            continuousAddVA: continuousExtra,
            totalDemandVA: demand,
            spareVA: spareVA,
            grandTotalVA: grand,
            amps: amps,
            voltage: v,
            phases: phases,
            formula: "Σ lighting → Table 220.42 DF; other/motor/continuous as coded; I = VA / (√3·V) or VA/V"
        )
    }
}
