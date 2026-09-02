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
            return "Enter \(name)."
        case .nonPositive(let name):
            return "\(name) must be greater than zero."
        case .outOfRange(let detail):
            return detail
        case .needTwoOfThree:
            return "Enter any two of voltage, current, or resistance."
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

public enum Positive {
    public static func require(_ value: Double, name: String) throws -> Double {
        guard value.isFinite, value > 0 else { throw CalcError.nonPositive(name) }
        return value
    }
}
