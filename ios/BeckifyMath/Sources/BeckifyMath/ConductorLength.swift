import Foundation

/// Resistance unit for the conductor-length-by-resistance tool.
/// Raw values match the website toolbox (`ohm` / `mohm`).
public enum ConductorLengthResistanceUnit: String, Codable, CaseIterable, Sendable, Hashable {
    case ohm
    case milliohm = "mohm"

    public var displayName: String {
        switch self {
        case .ohm: return "Ω"
        case .milliohm: return "mΩ"
        }
    }
}

/// Measurement-temperature unit. Raw values match the website (`c` / `f`).
public enum ConductorLengthTempUnit: String, Codable, CaseIterable, Sendable, Hashable {
    case celsius = "c"
    case fahrenheit = "f"

    public var displayName: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }
}

/// Path geometry. Loop methods always divide solved length by 2 for one-way
/// distance, including the 3-phase far-end short (website `loop3` rule).
public enum ConductorLengthMethod: String, Codable, CaseIterable, Sendable, Hashable {
    case single
    case loop2
    case loop3

    public var displayName: String {
        switch self {
        case .single: return "Single conductor"
        case .loop2: return "2-conductor loop"
        case .loop3: return "3-phase loop"
        }
    }

    public var detail: String {
        switch self {
        case .single: return "One-way equals solved path length"
        case .loop2: return "Far-end jumper; one-way = total path ÷ 2"
        case .loop3: return "Symmetrical far-end short; one-way = total path ÷ 2"
        }
    }

    /// Website `clrPathFactor`: single is ×1, every loop method is ÷2.
    public var pathFactor: Double { self == .single ? 1 : 2 }
}

/// Material presets. Raw values match `CLR_MATERIAL_PRESETS` in app.js.
public enum ConductorLengthMaterial: String, Codable, CaseIterable, Sendable, Hashable {
    case copperAnnealed = "cu-annealed"
    case copperHardDrawn = "cu-hard"
    case aluminum = "al"

    public var displayName: String {
        switch self {
        case .copperAnnealed: return "Copper (annealed)"
        case .copperHardDrawn: return "Copper (hard-drawn)"
        case .aluminum: return "Aluminum"
        }
    }

    /// Maps onto the shared copper / aluminum catalog used by ampacity and VD.
    public var conductorMaterial: ConductorMaterial {
        self == .aluminum ? .aluminum : .copper
    }
}

/// Resistivity reference temperature. Raw values match the website select.
public enum ConductorLengthRefTemp: String, Codable, CaseIterable, Sendable, Hashable {
    case c20 = "20"
    case c75 = "75"

    public var celsius: Double {
        switch self {
        case .c20: return 20
        case .c75: return 75
        }
    }

    public var displayName: String {
        switch self {
        case .c20: return "20 °C (68 °F)"
        case .c75: return "75 °C (167 °F)"
        }
    }
}

public struct ConductorLengthPreset: Equatable, Sendable {
    public var label: String
    public var rho20: Double
    public var rho75: Double
    public var alpha: Double

    public func rho(at refTemp: ConductorLengthRefTemp) -> Double {
        refTemp == .c75 ? rho75 : rho20
    }
}

public struct ConductorLengthInput: Equatable, Sendable {
    public var resistance: Double
    public var resistanceUnit: ConductorLengthResistanceUnit
    public var circularMils: Double
    public var method: ConductorLengthMethod
    public var temperature: Double
    public var temperatureUnit: ConductorLengthTempUnit
    public var referenceTempC: Double
    public var alpha: Double
    public var rho: Double

    public init(
        resistance: Double,
        resistanceUnit: ConductorLengthResistanceUnit = .ohm,
        circularMils: Double,
        method: ConductorLengthMethod = .single,
        temperature: Double,
        temperatureUnit: ConductorLengthTempUnit = .celsius,
        referenceTempC: Double,
        alpha: Double,
        rho: Double
    ) {
        self.resistance = resistance
        self.resistanceUnit = resistanceUnit
        self.circularMils = circularMils
        self.method = method
        self.temperature = temperature
        self.temperatureUnit = temperatureUnit
        self.referenceTempC = referenceTempC
        self.alpha = alpha
        self.rho = rho
    }
}

public struct ConductorLengthResult: Equatable, Sendable {
    public var resistanceOhms: Double
    public var measuredTempC: Double
    public var referenceTempC: Double
    public var resistanceAtRefTemp: Double
    public var totalLengthFt: Double
    public var oneWayLengthFt: Double
    public var totalLengthM: Double
    public var oneWayLengthM: Double
    public var pathFactor: Double
    public var circularMils: Double
    public var rho: Double
    public var alpha: Double
    public var formula: String
}

/// Estimate one-way conductor distance from measured resistance.
/// Same identity as the website toolbox: L = R_ref × CM / ρ, with linear α
/// compensation to the resistivity reference temperature.
public enum ConductorLength {
    /// Website `CLR_MATERIAL_PRESETS`. Hard-drawn copper starts from the
    /// annealed copper book; edit ρ when you have manufacturer data.
    public static let presets: [ConductorLengthMaterial: ConductorLengthPreset] = [
        .copperAnnealed: ConductorLengthPreset(
            label: "Copper (Annealed)",
            rho20: 10.371,
            rho75: 12.9,
            alpha: 0.00393
        ),
        .copperHardDrawn: ConductorLengthPreset(
            label: "Copper (Hard-Drawn)",
            rho20: 10.371,
            rho75: 12.9,
            alpha: 0.00393
        ),
        .aluminum: ConductorLengthPreset(
            label: "Aluminum",
            rho20: 17.02,
            rho75: 21.2,
            alpha: 0.00403
        ),
    ]

    public static func preset(_ material: ConductorLengthMaterial) -> ConductorLengthPreset {
        presets[material] ?? presets[.copperAnnealed]!
    }

    /// Chapter 9 Table 8 circular mils — same numbers as website `CLR_SIZE_CMIL`.
    public static func circularMils(forSize size: String) -> Double? {
        NECTables.circularMils[size]
    }

    public static func resistanceToOhms(_ resistance: Double, unit: ConductorLengthResistanceUnit) -> Double {
        unit == .milliohm ? resistance / 1000 : resistance
    }

    public static func temperatureToC(_ temperature: Double, unit: ConductorLengthTempUnit) -> Double {
        unit == .fahrenheit ? (temperature - 32) * 5 / 9 : temperature
    }

    /// Port of `conductorLengthByResistanceModel` in toolbox `app.js`.
    public static func calculate(_ input: ConductorLengthInput) throws -> ConductorLengthResult {
        let resistanceOhms = resistanceToOhms(input.resistance, unit: input.resistanceUnit)
        let measuredTempC = temperatureToC(input.temperature, unit: input.temperatureUnit)
        let refTempC = input.referenceTempC
        let alpha = input.alpha
        let rho = input.rho
        let cmil = input.circularMils
        let pathFactor = input.method.pathFactor
        let denom = 1 + alpha * (measuredTempC - refTempC)

        // Match website `isPos` / `isNum` checks and error copy so iOS and web agree.
        guard resistanceOhms.isFinite, resistanceOhms > 0,
              cmil.isFinite, cmil > 0,
              rho.isFinite, rho > 0 else {
            throw CalcError.outOfRange("Resistance, conductor area, and ρ must be greater than zero.")
        }
        guard measuredTempC.isFinite, refTempC.isFinite, alpha.isFinite, alpha >= 0 else {
            throw CalcError.outOfRange("Enter valid temperatures and α.")
        }
        if abs(denom) < 1e-9 || denom <= 0 {
            throw CalcError.outOfRange("Temperature compensation produced an invalid resistance factor.")
        }

        let resistanceAtRefTemp = resistanceOhms / denom
        let totalLengthFt = resistanceAtRefTemp * cmil / rho
        let oneWayLengthFt = totalLengthFt / pathFactor

        return ConductorLengthResult(
            resistanceOhms: resistanceOhms,
            measuredTempC: measuredTempC,
            referenceTempC: refTempC,
            resistanceAtRefTemp: resistanceAtRefTemp,
            totalLengthFt: totalLengthFt,
            oneWayLengthFt: oneWayLengthFt,
            totalLengthM: totalLengthFt * 0.3048,
            oneWayLengthM: oneWayLengthFt * 0.3048,
            pathFactor: pathFactor,
            circularMils: cmil,
            rho: rho,
            alpha: alpha,
            formula: "L = R_ref × CM / ρ    R_ref = R / [1 + α × (T − T_ref)]"
        )
    }
}
