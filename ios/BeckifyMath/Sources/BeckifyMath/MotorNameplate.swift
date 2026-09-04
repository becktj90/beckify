import Foundation

public enum MotorNameplateType: String, Codable, CaseIterable, Sendable {
    case singlePhase = "1ph"
    case squirrelCageOther = "sc-bde"
    case squirrelCageEnergyEfficient = "sc-ee"
    case synchronous = "sync"
    case woundRotor = "wound"
    case dc = "dc"

    public var label: String {
        switch self {
        case .singlePhase: return "Single-phase AC"
        case .squirrelCageOther: return "Squirrel-cage (other than Design B EE/PE)"
        case .squirrelCageEnergyEfficient: return "Squirrel-cage Design B EE/PE"
        case .synchronous: return "Synchronous AC"
        case .woundRotor: return "Wound-rotor AC"
        case .dc: return "DC (constant voltage)"
        }
    }
}

public enum MotorSCPDDevice: String, Codable, CaseIterable, Sendable {
    case nontimeDelayFuse = "ntd"
    case dualElementFuse = "td"
    case instantaneousBreaker = "inst"
    case inverseTimeBreaker = "inv"

    public var label: String {
        switch self {
        case .nontimeDelayFuse: return "Nontime-delay fuse"
        case .dualElementFuse: return "Dual-element time-delay fuse"
        case .instantaneousBreaker: return "Instantaneous-trip breaker"
        case .inverseTimeBreaker: return "Inverse-time breaker"
        }
    }
}

public struct MotorOverloadResult: Equatable, Sendable {
    public var percent: Double
    public var amps: Double
    public var article: String
    public var reason: String
}

public struct MotorSCPDResult: Equatable, Sendable {
    public var percent: Double
    public var rawAmps: Double
    public var nextStandardAmps: Int?
    public var article: String
    public var motorTypeLabel: String
    public var deviceLabel: String
}

public struct LockedRotorResult: Equatable, Sendable {
    public var letter: String
    public var kvaPerHPMin: Double
    public var kvaPerHPMax: Double?
    public var ampsMin: Double?
    public var ampsMax: Double?
    public var article: String
    public var note: String
}

public struct MotorNameplateResult: Equatable, Sendable {
    public var fla: Double
    public var horsepower: Double?
    public var overload: MotorOverloadResult
    public var overloadNext: MotorOverloadResult
    public var scpd: MotorSCPDResult
    public var conductorRequiredAmps: Double
    public var suggestedConductorSize: String?
    public var suggestedConductorAmpacity: Double?
    public var lockedRotor: LockedRotorResult?
    public var formula: String
}

/// Nameplate → overload / SCPD / 430.22 conductor math. Structured OCR lives in
/// `NameplateFieldParser` / Motor Nameplate OCR; this module only consumes
/// reviewed numeric fields.
public enum MotorNameplate {
    /// NEC Table 430.52 percentages: ntd, td, inst, inv.
    private static let table430_52: [MotorNameplateType: (ntd: Double, td: Double, inst: Double, inv: Double)] = [
        .singlePhase: (300, 175, 800, 250),
        .squirrelCageOther: (300, 175, 800, 250),
        .squirrelCageEnergyEfficient: (300, 175, 1100, 250),
        .synchronous: (300, 175, 800, 250),
        .woundRotor: (150, 150, 800, 150),
        .dc: (150, 150, 250, 150),
    ]

    /// NEMA MG-1 Table 10-1 / NEC 430.7(B) code-letter locked-rotor kVA/HP ranges.
    private static let codeLetterRanges: [String: (Double, Double?)] = [
        "A": (0, 3.14), "B": (3.15, 3.54), "C": (3.55, 3.99), "D": (4.0, 4.49),
        "E": (4.5, 4.99), "F": (5.0, 5.59), "G": (5.6, 6.29), "H": (6.3, 7.09),
        "J": (7.1, 7.99), "K": (8.0, 8.99), "L": (9.0, 9.99), "M": (10.0, 11.19),
        "N": (11.2, 12.49), "P": (12.5, 13.99), "R": (14.0, 15.99), "S": (16.0, 17.99),
        "T": (18.0, 19.99), "U": (20.0, 22.39), "V": (22.4, nil),
    ]

    public static func overloadPercent(serviceFactor: Double?, temperatureRiseC: Double?) -> (pct: Double, reason: String) {
        let sfOK = (serviceFactor ?? 0) >= 1.15
        let riseOK = (temperatureRiseC ?? .infinity) > 0 && (temperatureRiseC ?? .infinity) <= 40
        if sfOK || riseOK {
            return (125, "SF ≥ 1.15 or temperature rise ≤ 40°C")
        }
        return (115, "all other motors")
    }

    public static func overloadNextHigherPercent(serviceFactor: Double?, temperatureRiseC: Double?) -> Double {
        let base = overloadPercent(serviceFactor: serviceFactor, temperatureRiseC: temperatureRiseC)
        return base.pct == 125 ? 140 : 130
    }

    public static func scpdPercent(motorType: MotorNameplateType, device: MotorSCPDDevice) -> Double {
        let row = table430_52[motorType] ?? table430_52[.squirrelCageOther]!
        switch device {
        case .nontimeDelayFuse: return row.ntd
        case .dualElementFuse: return row.td
        case .instantaneousBreaker: return row.inst
        case .inverseTimeBreaker: return row.inv
        }
    }

    public static func lockedRotor(
        codeLetter: String?,
        horsepower: Double?,
        volts: Double?,
        phases: Int
    ) -> LockedRotorResult? {
        guard let raw = codeLetter?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let key = raw.uppercased()
        guard let range = codeLetterRanges[key] else { return nil }
        var ampsMin: Double?
        var ampsMax: Double?
        if let hp = horsepower, hp > 0, let v = volts, v > 0 {
            func amps(_ kvaPerHp: Double) -> Double {
                let va = kvaPerHp * hp * 1000
                return phases == 1 ? va / v : va / (sqrt(3) * v)
            }
            ampsMin = amps(range.0)
            if let hi = range.1 { ampsMax = amps(hi) }
        }
        return LockedRotorResult(
            letter: key,
            kvaPerHPMin: range.0,
            kvaPerHPMax: range.1,
            ampsMin: ampsMin,
            ampsMax: ampsMax,
            article: "NEC 430.7(B); NEMA MG-1 Table 10-1",
            note: "Table range, not a substitute for manufacturer LRA."
        )
    }

    public static func analyze(
        fla: Double,
        phases: Int,
        horsepower: Double? = nil,
        kilowatts: Double? = nil,
        volts: Double? = nil,
        serviceFactor: Double? = nil,
        temperatureRiseC: Double? = nil,
        motorType: MotorNameplateType = .squirrelCageOther,
        device: MotorSCPDDevice = .inverseTimeBreaker,
        material: ConductorMaterial = .copper,
        codeLetter: String? = nil
    ) throws -> MotorNameplateResult {
        let i = try Positive.require(fla, name: "Nameplate FLA")
        guard phases == 1 || phases == 3 else {
            throw CalcError.outOfRange("Phase must be 1 or 3.")
        }

        var hp = horsepower
        if (hp == nil || (hp ?? 0) <= 0), let kw = kilowatts, kw > 0 {
            hp = kw / 0.746
        }

        let ol = overloadPercent(serviceFactor: serviceFactor, temperatureRiseC: temperatureRiseC)
        let olNextPct = overloadNextHigherPercent(serviceFactor: serviceFactor, temperatureRiseC: temperatureRiseC)
        let scpdPct = scpdPercent(motorType: motorType, device: device)
        let scpdRaw = i * scpdPct / 100
        let conductorNeed = MotorFLA.conductorAmps(fla: i)

        var size: String?
        var sizeAmp: Double?
        if let pick = try? WireAmpacity.smallestConductor(loadAmps: conductorNeed, material: material) {
            size = pick.size
            sizeAmp = Double(pick.ampacity)
        }

        return MotorNameplateResult(
            fla: i,
            horsepower: hp,
            overload: MotorOverloadResult(
                percent: ol.pct,
                amps: i * ol.pct / 100,
                article: "NEC 430.32(A)(1)",
                reason: ol.reason
            ),
            overloadNext: MotorOverloadResult(
                percent: olNextPct,
                amps: i * olNextPct / 100,
                article: "NEC 430.32(C)",
                reason: "next higher size if motor will not start"
            ),
            scpd: MotorSCPDResult(
                percent: scpdPct,
                rawAmps: scpdRaw,
                nextStandardAmps: NECTables.nextStandardOCPD(scpdRaw),
                article: "NEC Table 430.52",
                motorTypeLabel: motorType.label,
                deviceLabel: device.label
            ),
            conductorRequiredAmps: conductorNeed,
            suggestedConductorSize: size,
            suggestedConductorAmpacity: sizeAmp,
            lockedRotor: lockedRotor(codeLetter: codeLetter, horsepower: hp, volts: volts, phases: phases),
            formula: "OL ≤ % × FLA; SCPD ≤ Table 430.52 % × FLA; conductor ≥ 125% × FLA (430.22)"
        )
    }
}
