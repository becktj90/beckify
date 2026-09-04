import Foundation

/// Input validation failures shared by every calculator.
public enum CalcError: Error, Equatable, Sendable {
    case missing(String)
    case nonPositive(String)
    case outOfRange(String)
    case needTwoOfThree
    case notListed(String)

    public var message: String {
        switch self {
        case .missing(let name):
            return "Need \(name). Type a number — this tool will not guess a blank."
        case .nonPositive(let name):
            return "\(name) must be greater than zero. Zero, negatives, and empty are not usable here."
        case .outOfRange(let detail):
            return detail
        case .needTwoOfThree:
            return "Enter any two of voltage, current, or resistance. Leave the one you want solved blank."
        case .notListed(let detail):
            return detail
        }
    }
}

public enum ElectricalSystem: String, Codable, CaseIterable, Sendable, Hashable {
    case dc
    case singlePhase
    case threePhase

    public var displayName: String {
        switch self {
        case .dc: return "DC"
        case .singlePhase: return "1Ø AC"
        case .threePhase: return "3Ø AC"
        }
    }

    /// Phase multiplier used in apparent-power formulas. DC and 1Ø are 1; 3Ø is √3.
    public var phaseMultiplier: Double {
        self == .threePhase ? Foundation.sqrt(3.0) : 1.0
    }

    /// Voltage-drop path multiplier. 1Ø / DC loop is 2; 3Ø is √3.
    public var voltageDropMultiplier: Double {
        self == .threePhase ? Foundation.sqrt(3.0) : 2.0
    }
}

public enum ConductorMaterial: String, Codable, CaseIterable, Sendable, Hashable {
    case copper
    case aluminum

    public var displayName: String {
        switch self {
        case .copper: return "Copper"
        case .aluminum: return "Aluminum"
        }
    }

    /// NEC Chapter 9 Table 9 DC resistance constant K at 75 °C (Ω·CM/ft).
    public var resistivityK: Double {
        switch self {
        case .copper: return 12.9
        case .aluminum: return 21.2
        }
    }
}

/// Chapter 9 Table 4 raceway families transcribed for fill checks.
public enum RacewayKind: String, Codable, CaseIterable, Sendable, Hashable {
    case emt
    case imc
    case rmc
    case pvc40
    case pvc80
    case ent
    case fmc
    case lfmc

    public var displayName: String {
        switch self {
        case .emt: return "EMT"
        case .imc: return "IMC"
        case .rmc: return "RMC"
        case .pvc40: return "PVC Sch 40"
        case .pvc80: return "PVC Sch 80"
        case .ent: return "ENT"
        case .fmc: return "FMC"
        case .lfmc: return "LFMC"
        }
    }
}

/// Chapter 9 Table 5 insulation families used for conductor area.
public enum ConductorInsulationKind: String, Codable, CaseIterable, Sendable, Hashable {
    case thhn
    case xhhw
    case rhw

    public var displayName: String {
        switch self {
        case .thhn: return "THHN / THWN-2"
        case .xhhw: return "XHHW / XHHW-2"
        case .rhw: return "RHH / RHW / RHW-2"
        }
    }
}

public enum Positive {
    public static func require(_ value: Double, name: String) throws -> Double {
        guard value.isFinite, value > 0 else { throw CalcError.nonPositive(name) }
        return value
    }
}

public enum WholeCount {
    /// Positive integer with no fractional part (e.g. conductor count).
    public static func parse(_ value: Double, name: String) throws -> Int {
        guard value.isFinite, value >= 1 else { throw CalcError.nonPositive(name) }
        let whole = value.rounded(.towardZero)
        guard value == whole else {
            throw CalcError.outOfRange("\(name) must be a whole number.")
        }
        guard let count = Int(exactly: whole) else {
            throw CalcError.outOfRange("\(name) is out of range.")
        }
        return count
    }
}
