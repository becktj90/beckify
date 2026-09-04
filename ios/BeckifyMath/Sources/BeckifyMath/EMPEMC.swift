import Foundation

public struct EMPEMCMaterial: Equatable, Sendable {
    public var id: String
    public var name: String
    public var sigma: Double
    public var muR: Double

    public static let copper = EMPEMCMaterial(id: "cu", name: "Copper", sigma: 5.80e7, muR: 1)
    public static let aluminum = EMPEMCMaterial(id: "al", name: "Aluminum", sigma: 3.77e7, muR: 1)
    public static let mildSteelLF = EMPEMCMaterial(id: "steel-lf", name: "Mild steel (LF μr)", sigma: 1.0e7, muR: 200)
    public static let mildSteelRF = EMPEMCMaterial(id: "steel-rf", name: "Mild steel (RF μr≈1)", sigma: 1.0e7, muR: 1)

    public static let all: [EMPEMCMaterial] = [.copper, .aluminum, .mildSteelLF, .mildSteelRF]
}

public struct SkinShieldResult: Equatable, Sendable {
    public var materialName: String
    public var frequencyHz: Double
    public var thicknessM: Double
    public var skinDepthM: Double
    public var tOverDelta: Double
    public var absorptionDB: Double
    public var reflectionDB: Double
    public var correctionDB: Double
    public var sheetSEDB: Double
    public var formula: String
}

public struct FaradayLoopResult: Equatable, Sendable {
    public var turns: Double
    public var areaM2: Double
    public var dBdt: Double
    public var inducedVolts: Double
    public var formula: String
}

public struct ApertureLeakResult: Equatable, Sendable {
    public var longestDimensionM: Double
    public var frequencyHz: Double
    public var wavelengthM: Double
    public var seDB: Double
    public var regime: String
    public var formula: String
}

/// Shielding / victim-circuit education math. Not a pulse-source designer.
public enum EMPEMC {
    public static let mu0 = 4 * Double.pi * 1e-7
    public static let c0 = 299_792_458.0

    public static func equivalentFrequencyHz(riseTimeS: Double) throws -> Double {
        let tr = try Positive.require(riseTimeS, name: "Rise time")
        return 0.35 / tr
    }

    public static func skinDepth(sigma: Double, muR: Double, frequencyHz: Double) throws -> Double {
        let s = try Positive.require(sigma, name: "Conductivity")
        let mur = try Positive.require(muR, name: "Relative permeability")
        let f = try Positive.require(frequencyHz, name: "Frequency")
        return 1 / sqrt(Double.pi * f * mu0 * mur * s)
    }

    public static func shieldEstimate(
        material: EMPEMCMaterial,
        thicknessM: Double,
        frequencyHz: Double
    ) throws -> SkinShieldResult {
        let t = try Positive.require(thicknessM, name: "Barrier thickness")
        let f = try Positive.require(frequencyHz, name: "Frequency")
        let delta = try skinDepth(sigma: material.sigma, muR: material.muR, frequencyHz: f)
        let tOver = t / delta
        let absorption = 8.686 * tOver
        // Far-field plane-wave reflection (Schelkunoff good-conductor form).
        let eta = 377.0
        let zs = sqrt(2 * Double.pi * f * mu0 * material.muR / material.sigma)
        let reflection = 20 * log10(eta / (4 * zs))
        let correction: Double
        if tOver >= 1 {
            correction = 0
        } else {
            // Thin-sheet correction B ≈ 20·log10|1 − exp(−2t/δ)| (order-of-magnitude).
            let term = abs(1 - exp(-2 * tOver))
            correction = term > 0 ? 20 * log10(term) : -120
        }
        let se = absorption + reflection + correction
        return SkinShieldResult(
            materialName: material.name,
            frequencyHz: f,
            thicknessM: t,
            skinDepthM: delta,
            tOverDelta: tOver,
            absorptionDB: absorption,
            reflectionDB: reflection,
            correctionDB: correction,
            sheetSEDB: se,
            formula: "δ = 1/√(π f μ σ); A ≈ 8.686 t/δ; SE ≈ A + R + B"
        )
    }

    public static func faradayLoop(turns: Double, areaM2: Double, dBdtTeslaPerS: Double) throws -> FaradayLoopResult {
        let n = try Positive.require(turns, name: "Turns")
        let a = try Positive.require(areaM2, name: "Loop area")
        guard dBdtTeslaPerS.isFinite else { throw CalcError.missing("dB/dt") }
        let v = n * a * abs(dBdtTeslaPerS)
        return FaradayLoopResult(
            turns: n,
            areaM2: a,
            dBdt: dBdtTeslaPerS,
            inducedVolts: v,
            formula: "V = N · A · |dB/dt|"
        )
    }

    public static func apertureSE(longestDimensionM: Double, frequencyHz: Double) throws -> ApertureLeakResult {
        let l = try Positive.require(longestDimensionM, name: "Aperture longest dimension")
        let f = try Positive.require(frequencyHz, name: "Frequency")
        let lambda = c0 / f
        // Worst-dimension rule of thumb: SE ≈ 20·log10(λ / (2ℓ)) when ℓ < λ/2.
        let cutoff = lambda / 2
        let se: Double
        let regime: String
        if l >= cutoff {
            se = 0
            regime = "Aperture ≥ λ/2 — treat as open (0 dB SE from this rule)"
        } else {
            se = 20 * log10(lambda / (2 * l))
            regime = "Electrically small aperture (worst-dimension rule of thumb)"
        }
        return ApertureLeakResult(
            longestDimensionM: l,
            frequencyHz: f,
            wavelengthM: lambda,
            seDB: se,
            regime: regime,
            formula: "SE ≈ 20·log₁₀(λ/(2ℓ)) for ℓ < λ/2"
        )
    }
}
