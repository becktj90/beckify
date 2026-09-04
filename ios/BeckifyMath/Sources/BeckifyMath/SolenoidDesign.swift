import Foundation

public struct SolenoidPlotPoint: Equatable, Sendable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct SolenoidPackingResult: Equatable, Sendable {
    public var turnsPerLayer: Int
    public var layers: Int
    public var fillFactor: Double
    public var coilOuterRadiusM: Double
    public var wireDiameterM: Double
}

public struct SolenoidDesignResult: Equatable, Sendable {
    public var lengthM: Double
    public var meanRadiusM: Double
    public var turns: Int
    public var currentAmps: Double
    public var relativePermeability: Double
    public var wireAWG: Int
    public var airGapM: Double?

    public var packing: SolenoidPackingResult
    public var wireLengthM: Double
    public var resistanceOhms: Double
    public var voltageVolts: Double
    public var copperLossWatts: Double
    public var currentDensityAPerMm2: Double

    public var ampereTurns: Double
    public var turnsPerMetre: Double
    public var hFieldAmpsPerM: Double
    public var bCenterTesla: Double
    public var inductanceHenry: Double
    public var energyJoules: Double
    public var forceNewton: Double?

    public var bVsCurrent: [SolenoidPlotPoint]
    public var forceVsGap: [SolenoidPlotPoint]
    public var axialField: [SolenoidPlotPoint]
    public var warnings: [String]
    public var formula: String
}

/// Advanced air-core / soft-iron solenoid design aid.
/// Finite-solenoid on-axis B, packing from AWG, inductance, copper loss,
/// and a single-gap plunger force estimate. Design aid — not FEA.
public enum SolenoidDesign {
    public static let mu0 = 4 * Double.pi * 1e-7

    /// Copper resistivity at ~20 °C, Ω·m.
    public static let copperResistivity = 1.724e-8

    public static func awgDiameterMetres(_ awg: Int) -> Double {
        // AWG definition: d(in) = 0.005 × 92^((36−n)/39)
        0.005 * pow(92, (36.0 - Double(awg)) / 39.0) * 0.0254
    }

    public static func awgAreaMm2(_ awg: Int) -> Double {
        let dMm = awgDiameterMetres(awg) * 1000
        return (.pi / 4) * dMm * dMm
    }

    /// Pack rectangular winding into a coil length and build radius outward.
    public static func packing(
        turns: Int,
        lengthM: Double,
        meanRadiusM: Double,
        awg: Int,
        insulationFactor: Double = 1.15
    ) throws -> SolenoidPackingResult {
        let n = try WholeCount.parse(Double(turns), name: "Turns")
        let length = try Positive.require(lengthM, name: "Coil length")
        let radius = try Positive.require(meanRadiusM, name: "Mean radius")
        guard awg >= -3 && awg <= 40 else {
            throw CalcError.outOfRange("AWG must be between 4/0 (−3) and 40.")
        }
        let d = awgDiameterMetres(awg) * max(insulationFactor, 1)
        guard d > 0, d < length else {
            throw CalcError.outOfRange("Wire diameter is incompatible with coil length.")
        }
        let turnsPerLayer = max(1, Int(floor(length / d)))
        let layers = Int(ceil(Double(n) / Double(turnsPerLayer)))
        let copperArea = Double(n) * (.pi / 4) * pow(awgDiameterMetres(awg), 2)
        let build = Double(layers) * d
        let outer = radius + build / 2
        let window = length * max(build, d)
        let fill = window > 0 ? min(1, copperArea / window) : 0
        return SolenoidPackingResult(
            turnsPerLayer: turnsPerLayer,
            layers: layers,
            fillFactor: fill,
            coilOuterRadiusM: outer,
            wireDiameterM: awgDiameterMetres(awg)
        )
    }

    /// On-axis B for a finite thick-ish solenoid modeled as a thin cylindrical current sheet at `meanRadius`.
    public static func axialFieldTesla(
        zFromCenterM: Double,
        lengthM: Double,
        meanRadiusM: Double,
        turns: Int,
        currentAmps: Double,
        relativePermeability: Double = 1
    ) -> Double {
        let L = lengthM
        let R = meanRadiusM
        let nI = (Double(turns) / L) * currentAmps
        let mur = max(relativePermeability, 1e-12)
        func term(_ z: Double) -> Double {
            z / sqrt(R * R + z * z)
        }
        let z1 = zFromCenterM + L / 2
        let z2 = zFromCenterM - L / 2
        return 0.5 * mu0 * mur * nI * (term(z1) - term(z2))
    }

    public static func inductanceHenry(
        turns: Int,
        lengthM: Double,
        meanRadiusM: Double,
        relativePermeability: Double
    ) throws -> Double {
        let n = try WholeCount.parse(Double(turns), name: "Turns")
        let length = try Positive.require(lengthM, name: "Coil length")
        let radius = try Positive.require(meanRadiusM, name: "Mean radius")
        let mur = try Positive.require(relativePermeability, name: "Relative permeability")
        let area = .pi * radius * radius
        // Long-solenoid inductance; slightly optimistic for short coils.
        return mu0 * mur * Double(n * n) * area / length
    }

    /// Single air-gap plunger force estimate F ≈ (N·I)² μ₀ A / (2 g²).
    public static func plungerForceNewton(
        turns: Int,
        currentAmps: Double,
        meanRadiusM: Double,
        airGapM: Double,
        relativePermeability: Double = 1
    ) throws -> Double {
        let n = try WholeCount.parse(Double(turns), name: "Turns")
        let i = try Positive.require(currentAmps, name: "Current")
        let radius = try Positive.require(meanRadiusM, name: "Mean radius")
        let gap = try Positive.require(airGapM, name: "Air gap")
        let mur = try Positive.require(relativePermeability, name: "Relative permeability")
        let area = .pi * radius * radius
        let ni = Double(n) * i
        return (ni * ni) * mu0 * mur * area / (2 * gap * gap)
    }

    public static func design(
        lengthM: Double,
        meanRadiusM: Double,
        turns: Int,
        currentAmps: Double,
        wireAWG: Int,
        relativePermeability: Double = 1,
        airGapM: Double? = nil,
        supplyVolts: Double? = nil
    ) throws -> SolenoidDesignResult {
        let length = try Positive.require(lengthM, name: "Coil length")
        let radius = try Positive.require(meanRadiusM, name: "Mean radius")
        let n = try WholeCount.parse(Double(turns), name: "Turns")
        let i = try Positive.require(currentAmps, name: "Current")
        let mur = try Positive.require(relativePermeability, name: "Relative permeability")
        guard wireAWG >= -3 && wireAWG <= 40 else {
            throw CalcError.outOfRange("AWG must be between 4/0 (−3) and 40.")
        }

        let pack = try packing(turns: n, lengthM: length, meanRadiusM: radius, awg: wireAWG)
        let meanTurnLength = 2 * .pi * radius
        let wireLength = meanTurnLength * Double(n)
        let areaM2 = (.pi / 4) * pow(pack.wireDiameterM, 2)
        let resistance = copperResistivity * wireLength / areaM2
        let voltage = supplyVolts ?? (i * resistance)
        let loss = i * i * resistance
        let jAPerMm2 = i / awgAreaMm2(wireAWG)

        let turnsPerM = Double(n) / length
        let h = turnsPerM * i
        let bCenter = axialFieldTesla(
            zFromCenterM: 0,
            lengthM: length,
            meanRadiusM: radius,
            turns: n,
            currentAmps: i,
            relativePermeability: mur
        )
        let inductance = try inductanceHenry(
            turns: n,
            lengthM: length,
            meanRadiusM: radius,
            relativePermeability: mur
        )
        let energy = 0.5 * inductance * i * i

        var force: Double?
        if let gap = airGapM {
            force = try plungerForceNewton(
                turns: n,
                currentAmps: i,
                meanRadiusM: radius,
                airGapM: gap,
                relativePermeability: mur
            )
        }

        let bVsI: [SolenoidPlotPoint] = (0...24).map { step in
            let frac = Double(step) / 24
            let amps = i * (0.05 + 0.95 * frac)
            let b = axialFieldTesla(
                zFromCenterM: 0,
                lengthM: length,
                meanRadiusM: radius,
                turns: n,
                currentAmps: amps,
                relativePermeability: mur
            )
            return SolenoidPlotPoint(x: amps, y: b)
        }

        let forceCurve: [SolenoidPlotPoint] = (1...24).compactMap { step in
            let frac = Double(step) / 24
            let gap = max(length * 0.002, length * 0.25 * frac)
            guard let f = try? plungerForceNewton(
                turns: n,
                currentAmps: i,
                meanRadiusM: radius,
                airGapM: gap,
                relativePermeability: mur
            ), f.isFinite else { return nil }
            return SolenoidPlotPoint(x: gap * 1000, y: f)
        }

        let axial: [SolenoidPlotPoint] = (-40...40).map { step in
            let z = length * Double(step) / 40
            let b = axialFieldTesla(
                zFromCenterM: z,
                lengthM: length,
                meanRadiusM: radius,
                turns: n,
                currentAmps: i,
                relativePermeability: mur
            )
            return SolenoidPlotPoint(x: z * 1000, y: b)
        }

        var warnings: [String] = []
        if length / (2 * radius) < 2 {
            warnings.append("Short coil (ℓ/D < 2): long-solenoid inductance is optimistic — confirm with measurement or FEA.")
        }
        if jAPerMm2 > 6 {
            warnings.append("Current density \(FormatTrace.number(jAPerMm2, digits: 1)) A/mm² is aggressive for continuous duty without forced cooling.")
        }
        if mur > 1.5 {
            warnings.append("µᵣ > 1 assumes a soft-iron path without saturation. Real B saturates near 1.5–2 T.")
        }
        if bCenter > 1.8 {
            warnings.append("Center B exceeds ~1.8 T — iron would be saturated; treat air-core math only.")
        }

        return SolenoidDesignResult(
            lengthM: length,
            meanRadiusM: radius,
            turns: n,
            currentAmps: i,
            relativePermeability: mur,
            wireAWG: wireAWG,
            airGapM: airGapM,
            packing: pack,
            wireLengthM: wireLength,
            resistanceOhms: resistance,
            voltageVolts: voltage,
            copperLossWatts: loss,
            currentDensityAPerMm2: jAPerMm2,
            ampereTurns: Double(n) * i,
            turnsPerMetre: turnsPerM,
            hFieldAmpsPerM: h,
            bCenterTesla: bCenter,
            inductanceHenry: inductance,
            energyJoules: energy,
            forceNewton: force,
            bVsCurrent: bVsI,
            forceVsGap: forceCurve,
            axialField: axial,
            warnings: warnings,
            formula: "B(z) finite solenoid · L ≈ μ₀μᵣN²A/ℓ · F ≈ (NI)²μ₀A/(2g²)"
        )
    }

    /// Solve current for a target center B (air-core / linear µᵣ).
    public static func currentForTargetB(
        targetTesla: Double,
        lengthM: Double,
        meanRadiusM: Double,
        turns: Int,
        relativePermeability: Double = 1
    ) throws -> Double {
        let b = try Positive.require(targetTesla, name: "Target B")
        let length = try Positive.require(lengthM, name: "Coil length")
        let radius = try Positive.require(meanRadiusM, name: "Mean radius")
        let n = try WholeCount.parse(Double(turns), name: "Turns")
        let mur = try Positive.require(relativePermeability, name: "Relative permeability")
        let half = length / 2
        // B(0) = ½ μ₀ μᵣ (N/ℓ) I · [term(+ℓ/2) − term(−ℓ/2)] = ½ μ₀ μᵣ N I / √(R²+(ℓ/2)²)
        let denom = 0.5 * mu0 * mur * Double(n) / sqrt(radius * radius + half * half)
        guard denom > 0, denom.isFinite else {
            throw CalcError.outOfRange("Geometry cannot produce a finite target B.")
        }
        return b / denom
    }
}
