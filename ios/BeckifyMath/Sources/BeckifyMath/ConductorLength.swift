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
        case .single: return "End-to-end"
        case .loop2: return "Short to parallel"
        case .loop3: return "3-phase far-end short"
        }
    }

    public var detail: String {
        switch self {
        case .single: return "One conductor measured end-to-end; distance = solved path"
        case .loop2: return "Measure between two parallels shorted/bonded along the run; distance to short = path ÷ 2"
        case .loop3: return "Symmetrical far-end short; distance to short = path ÷ 2"
        }
    }

    /// Sticky / result headline: end-to-end length vs one-way distance to the short.
    public var primaryLengthLabel: String {
        self == .single ? "End-to-end length" : "Distance to short"
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

    /// Result-row / copy label. Copper (annealed or hard-drawn) stays "Copper weight".
    public var weightLabel: String {
        self == .aluminum ? "Aluminum weight" : "Copper weight"
    }

    public var metalDisplayName: String {
        self == .aluminum ? "Aluminum" : "Copper"
    }

    /// Soft copper ~8.89 g/cm³; commercial aluminum ~2.70 g/cm³.
    /// These are book densities for a volume estimate, not a scale reading.
    public var densityGPerCm3: Double {
        self == .aluminum
            ? ConductorLength.aluminumDensityGPerCm3
            : ConductorLength.copperDensityGPerCm3
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
    /// Selects copper vs aluminum density for the metal-mass estimate.
    public var material: ConductorLengthMaterial

    public init(
        resistance: Double,
        resistanceUnit: ConductorLengthResistanceUnit = .ohm,
        circularMils: Double,
        method: ConductorLengthMethod = .single,
        temperature: Double,
        temperatureUnit: ConductorLengthTempUnit = .celsius,
        referenceTempC: Double,
        alpha: Double,
        rho: Double,
        material: ConductorLengthMaterial = .copperAnnealed
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
        self.material = material
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
    public var metalMass: ConductorMetalMass
}

/// Estimated metal mass from published bare-metal lb/kft × length.
/// Displayed weight is always **one-way** (distance to short / end-to-end).
/// Not a scale reading — insulation, compounds, and temperature are ignored.
public struct ConductorMetalMass: Equatable, Sendable {
    public var label: String
    public var metalName: String
    public var densityGPerCm3: Double
    /// Published / book pounds per 1000 ft for this CM and metal.
    public var lbPerKft: Double
    public var oneWayLb: Double
    public var oneWayKg: Double
    public var totalPathLb: Double
    public var totalPathKg: Double
}

/// Estimate one-way conductor distance from measured resistance.
/// Same identity as the website toolbox: L = R_ref × CM / ρ, with linear α
/// compensation to the resistivity reference temperature.
public enum ConductorLength {
    /// Soft (annealed) copper book density used for custom-CM fallback.
    /// 8.89 g/cm³ is the common electrical-copper figure — not a weigh-scale.
    public static let copperDensityGPerCm3 = 8.89
    /// Commercial aluminum ~2.70 g/cm³.
    public static let aluminumDensityGPerCm3 = 2.70
    /// avoirdupois pound.
    public static let gramsPerPound = 453.59237
    /// 1 in³ = (2.54 cm)³.
    public static let cubicInchesToCubicCm = 16.387064
    /// Industry identity that generates the solid-bare-copper books:
    /// W = 0.003027 lb per circular mil per 1000 ft at 8.89 g/cm³.
    /// Used for kcmil and custom circular mils that are not in the AWG table.
    public static let copperLbPerCmilPerKft = 0.003027
    /// Solid bare copper lb/1000 ft — Standard Wire & Cable Co.
    /// “Wire Data – Solid Bare Copper” (ASTM B3 family).
    /// 14 AWG is published as **12.43 lb/kft** (4,107 CM in that book;
    /// NEC Chapter 9 Table 8 lists 14 AWG as 4,110 CM).
    public static let copperBookLbPerKft: [String: Double] = [
        "14": 12.43, "12": 19.77, "10": 31.43, "8": 49.99,
        "6": 79.47, "4": 126.3, "3": 159.3, "2": 200.9,
        "1": 253.3, "1/0": 319.5, "2/0": 402.7, "3/0": 508.0, "4/0": 640.5,
    ]

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

    /// Published bare-metal lb/1000 ft for a circular-mil area.
    /// Catalog AWG 14–4/0 uses Standard Wire solid-bare-copper book values.
    /// Other CM (kcmil / custom) uses 0.003027 × CM. Aluminum scales by 2.70/8.89.
    public static func bookLbPerKft(
        circularMils: Double,
        material: ConductorLengthMaterial
    ) -> Double {
        let copper: Double
        if let size = NECTables.circularMils.first(where: { abs($0.value - circularMils) < 0.5 })?.key,
           let published = copperBookLbPerKft[size] {
            copper = published
        } else {
            copper = circularMils * copperLbPerCmilPerKft
        }
        return material == .aluminum
            ? copper * aluminumDensityGPerCm3 / copperDensityGPerCm3
            : copper
    }

    /// Density × volume identity (CM → in² → cm³ × g/cm³). Kept as the
    /// custom-density primitive and as a cross-check against the book table.
    public static func metalMass(
        lengthFt: Double,
        circularMils: Double,
        densityGPerCm3: Double
    ) throws -> (kg: Double, lb: Double) {
        guard lengthFt.isFinite, lengthFt > 0,
              circularMils.isFinite, circularMils > 0,
              densityGPerCm3.isFinite, densityGPerCm3 > 0 else {
            throw CalcError.outOfRange("Length, conductor area, and density must be greater than zero.")
        }
        let areaIn2 = try CircularMils.squareInches(fromCircularMils: circularMils)
        let volumeCm3 = areaIn2 * lengthFt * 12 * cubicInchesToCubicCm
        let massG = volumeCm3 * densityGPerCm3
        return (kg: massG / 1000, lb: massG / gramsPerPound)
    }

    /// Book lb/kft × length / 1000. This is the displayed weight path.
    public static func metalMass(
        lengthFt: Double,
        circularMils: Double,
        material: ConductorLengthMaterial
    ) throws -> (kg: Double, lb: Double) {
        guard lengthFt.isFinite, lengthFt > 0,
              circularMils.isFinite, circularMils > 0 else {
            throw CalcError.outOfRange("Length and conductor area must be greater than zero.")
        }
        let lb = bookLbPerKft(circularMils: circularMils, material: material) * lengthFt / 1000
        return (kg: lb * gramsPerPound / 1000, lb: lb)
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
        let lbPerKft = bookLbPerKft(circularMils: cmil, material: input.material)
        let oneWay = try Self.metalMass(
            lengthFt: oneWayLengthFt,
            circularMils: cmil,
            material: input.material
        )
        let totalPath = try Self.metalMass(
            lengthFt: totalLengthFt,
            circularMils: cmil,
            material: input.material
        )
        let estimatedMass = ConductorMetalMass(
            label: input.material.weightLabel,
            metalName: input.material.metalDisplayName,
            densityGPerCm3: input.material.densityGPerCm3,
            lbPerKft: lbPerKft,
            oneWayLb: oneWay.lb,
            oneWayKg: oneWay.kg,
            totalPathLb: totalPath.lb,
            totalPathKg: totalPath.kg
        )

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
            formula: "L = R_ref × CM / ρ    R_ref = R / [1 + α × (T − T_ref)]",
            metalMass: estimatedMass
        )
    }
}
