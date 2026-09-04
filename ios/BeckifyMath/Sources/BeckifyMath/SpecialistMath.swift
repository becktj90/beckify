import Foundation

// MARK: - Magnetic circuit

public struct MagneticCircuitResult: Equatable, Sendable {
    public var reluctance: Double
    public var flux: Double
    public var fluxDensity: Double

    public init(reluctance: Double, flux: Double, fluxDensity: Double) {
        self.reluctance = reluctance
        self.flux = flux
        self.fluxDensity = fluxDensity
    }
}

/// The magnetic analogue of Ohm's law: mmf plays V, flux plays I, reluctance
/// plays R. Useful for a first-pass core sizing before reaching for FEA.
public enum MagneticCircuit {
    /// Permeability of free space, henries per metre.
    public static let mu0 = 4 * Double.pi * 1e-7

    public static func solve(
        magnetomotiveForce: Double,
        pathLength: Double,
        crossSectionalArea: Double,
        relativePermeability: Double
    ) throws -> MagneticCircuitResult {
        let mmf = try Positive.require(magnetomotiveForce, name: "Magnetomotive force")
        let length = try Positive.require(pathLength, name: "Path length")
        let area = try Positive.require(crossSectionalArea, name: "Cross-sectional area")
        let mu_r = try Positive.require(relativePermeability, name: "Relative permeability")

        let reluctance = length / (mu0 * mu_r * area)
        let flux = mmf / reluctance
        return MagneticCircuitResult(
            reluctance: reluctance,
            flux: flux,
            fluxDensity: flux / area
        )
    }
}

// MARK: - Fiber optic numerical aperture

public struct FiberLinkResult: Equatable, Sendable {
    public var numericalAperture: Double
    public var acceptanceAngleDegrees: Double
    /// V-number at the given operating wavelength — V < 2.405 is single-mode.
    public var vNumber: Double?
    public var isSingleMode: Bool?

    public init(numericalAperture: Double, acceptanceAngleDegrees: Double, vNumber: Double?, isSingleMode: Bool?) {
        self.numericalAperture = numericalAperture
        self.acceptanceAngleDegrees = acceptanceAngleDegrees
        self.vNumber = vNumber
        self.isSingleMode = isSingleMode
    }
}

/// Step-index fiber acceptance cone and, optionally, the mode condition.
public enum FiberLink {
    public static func solve(
        coreIndex: Double,
        claddingIndex: Double,
        coreRadiusMicrons: Double? = nil,
        wavelengthNanometers: Double? = nil
    ) throws -> FiberLinkResult {
        let n1 = try Positive.require(coreIndex, name: "Core index")
        let n2 = try Positive.require(claddingIndex, name: "Cladding index")
        guard n1 > n2 else {
            throw CalcError.outOfRange("Core index must be greater than cladding index, or light won't guide.")
        }

        let naSquared = n1 * n1 - n2 * n2
        let na = naSquared.squareRoot()
        let acceptance = asin(min(na, 1)) * 180 / .pi

        var vNumber: Double?
        var singleMode: Bool?
        if let coreRadiusMicrons, let wavelengthNanometers {
            let a = try Positive.require(coreRadiusMicrons, name: "Core radius")
            let lambda = try Positive.require(wavelengthNanometers, name: "Wavelength")
            // V = 2π a NA / λ, with a and λ both converted to the same unit (µm).
            let v = 2 * .pi * a * na / (lambda / 1000)
            vNumber = v
            singleMode = v < 2.405
        }

        return FiberLinkResult(
            numericalAperture: na,
            acceptanceAngleDegrees: acceptance,
            vNumber: vNumber,
            isSingleMode: singleMode
        )
    }
}

// MARK: - Gaussian beam propagation

public struct GaussianBeamResult: Equatable, Sendable {
    public var rayleighRange: Double
    public var divergenceHalfAngleRadians: Double
    public var divergenceHalfAngleMilliradians: Double
    /// Beam radius at the given propagation distance.
    public var radiusAtDistance: Double?

    public init(
        rayleighRange: Double,
        divergenceHalfAngleRadians: Double,
        divergenceHalfAngleMilliradians: Double,
        radiusAtDistance: Double?
    ) {
        self.rayleighRange = rayleighRange
        self.divergenceHalfAngleRadians = divergenceHalfAngleRadians
        self.divergenceHalfAngleMilliradians = divergenceHalfAngleMilliradians
        self.radiusAtDistance = radiusAtDistance
    }
}

/// TEM00 Gaussian beam propagation from a waist — the laser-optics analogue
/// of a lens equation. Distances and the waist share one unit (millimetres
/// throughout is the natural choice for a bench setup).
public enum GaussianBeam {
    public static func solve(
        waistRadius: Double,
        wavelengthNanometers: Double,
        propagationDistance: Double? = nil
    ) throws -> GaussianBeamResult {
        let w0 = try Positive.require(waistRadius, name: "Waist radius")
        let lambdaNm = try Positive.require(wavelengthNanometers, name: "Wavelength")
        // Convert nm to mm so it shares units with a waist entered in mm.
        let lambda = lambdaNm * 1e-6

        let zR = .pi * w0 * w0 / lambda
        let theta = lambda / (.pi * w0)

        var radiusAtZ: Double?
        if let z = propagationDistance, z.isFinite, z >= 0 {
            radiusAtZ = w0 * (1 + (z / zR) * (z / zR)).squareRoot()
        }

        return GaussianBeamResult(
            rayleighRange: zR,
            divergenceHalfAngleRadians: theta,
            divergenceHalfAngleMilliradians: theta * 1000,
            radiusAtDistance: radiusAtZ
        )
    }
}
