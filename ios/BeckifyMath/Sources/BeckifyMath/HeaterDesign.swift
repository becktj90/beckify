import Foundation

public enum HeaterPhase: String, Codable, CaseIterable, Sendable {
    case single = "1ph"
    case three = "3ph"

    public var label: String {
        switch self {
        case .single: return "1-phase"
        case .three: return "3-phase"
        }
    }
}

public enum HeaterConnection: String, Codable, CaseIterable, Sendable {
    case wye
    case delta

    public var label: String { rawValue.capitalized }
}

public struct HeaterElectricalResult: Equatable, Sendable {
    public var totalWatts: Double
    public var lineVolts: Double
    public var phase: HeaterPhase
    public var connection: HeaterConnection
    public var phaseVolts: Double
    public var lineAmps: Double
    public var legResistanceOhms: Double
    public var designAmps: Double
    public var suggestedConductorSize: String?
    public var suggestedOCPD: Int?
    public var formula: String
}

public struct HeaterElementResult: Equatable, Sendable {
    public var targetResistanceOhms: Double
    public var targetWatts: Double
    public var awg: Int
    public var diameterMm: Double
    public var areaMm2: Double
    public var resistivityOhmMm2PerM: Double
    public var lengthMeters: Double
    public var lengthFeet: Double
    public var currentAmps: Double
    public var surfaceWPerCm2: Double
    public var formula: String
}

/// Resistive heater electrical sizing + basic resistance-wire length estimate.
public enum HeaterDesign {
    public static let alloys: [(id: String, label: String, resistivity: Double)] = [
        ("nichrome80", "Nichrome 80", 1.09),
        ("nichrome60", "Nichrome 60", 1.12),
        ("kanthalA1", "Kanthal A-1", 1.45),
        ("kanthalD", "Kanthal D", 1.35),
        ("custom", "Custom", 1.10),
    ]

    public static func awgDiameterInches(_ awg: Int) -> Double {
        0.005 * pow(92, (36.0 - Double(awg)) / 39.0)
    }

    public static func awgDiameterMm(_ awg: Int) -> Double {
        awgDiameterInches(awg) * 25.4
    }

    public static func awgAreaMm2(_ awg: Int) -> Double {
        let d = awgDiameterMm(awg)
        return (.pi / 4) * d * d
    }

    public static func phaseVoltage(lineVolts: Double, phase: HeaterPhase, connection: HeaterConnection) -> Double {
        switch phase {
        case .single: return lineVolts
        case .three: return connection == .wye ? lineVolts / sqrt(3) : lineVolts
        }
    }

    public static func legResistance(totalWatts: Double, lineVolts: Double, phase: HeaterPhase, connection: HeaterConnection) -> Double {
        switch phase {
        case .single:
            return (lineVolts * lineVolts) / totalWatts
        case .three:
            return connection == .wye
                ? (lineVolts * lineVolts) / totalWatts
                : (3 * lineVolts * lineVolts) / totalWatts
        }
    }

    public static func lineCurrent(totalWatts: Double, lineVolts: Double, phase: HeaterPhase) -> Double {
        switch phase {
        case .single: return totalWatts / lineVolts
        case .three: return totalWatts / (sqrt(3) * lineVolts)
        }
    }

    public static func electrical(
        totalWatts: Double,
        lineVolts: Double,
        phase: HeaterPhase,
        connection: HeaterConnection = .wye,
        material: ConductorMaterial = .copper
    ) throws -> HeaterElectricalResult {
        let p = try Positive.require(totalWatts, name: "Heater power")
        let v = try Positive.require(lineVolts, name: "Line voltage")
        let iLine = lineCurrent(totalWatts: p, lineVolts: v, phase: phase)
        let design = iLine * 1.25
        let rLeg = legResistance(totalWatts: p, lineVolts: v, phase: phase, connection: connection)
        let vPhase = phaseVoltage(lineVolts: v, phase: phase, connection: connection)

        var size: String?
        var ocpd: Int?
        if let pick = try? WireAmpacity.smallestConductor(loadAmps: design, material: material) {
            size = pick.size
            ocpd = NECTables.nextStandardOCPD(design)
        }

        return HeaterElectricalResult(
            totalWatts: p,
            lineVolts: v,
            phase: phase,
            connection: connection,
            phaseVolts: vPhase,
            lineAmps: iLine,
            legResistanceOhms: rLeg,
            designAmps: design,
            suggestedConductorSize: size,
            suggestedOCPD: ocpd,
            formula: "I_line = P/(√3·V) (3Ø) or P/V (1Ø); R_leg from balanced resistive PF=1; design = 1.25×I"
        )
    }

    public static func element(
        targetResistanceOhms: Double,
        targetWatts: Double,
        resistivityOhmMm2PerM: Double,
        awg: Int
    ) throws -> HeaterElementResult {
        let r = try Positive.require(targetResistanceOhms, name: "Target resistance")
        let p = try Positive.require(targetWatts, name: "Target power")
        let rho = try Positive.require(resistivityOhmMm2PerM, name: "Resistivity")
        guard awg >= -3 && awg <= 40 else {
            throw CalcError.outOfRange("AWG must be between 4/0 (−3) and 40.")
        }

        let dMm = awgDiameterMm(awg)
        let area = awgAreaMm2(awg)
        let ohmPerM = rho / area
        let lengthM = r / ohmPerM
        let current = sqrt(p / r)
        let circumferenceCm = .pi * dMm / 10
        let surface = p / (lengthM * 100 * circumferenceCm)

        return HeaterElementResult(
            targetResistanceOhms: r,
            targetWatts: p,
            awg: awg,
            diameterMm: dMm,
            areaMm2: area,
            resistivityOhmMm2PerM: rho,
            lengthMeters: lengthM,
            lengthFeet: lengthM / 0.3048,
            currentAmps: current,
            surfaceWPerCm2: surface,
            formula: "ℓ = R / (ρ/A); I = √(P/R); surface = P / (ℓ·π·d)"
        )
    }
}
