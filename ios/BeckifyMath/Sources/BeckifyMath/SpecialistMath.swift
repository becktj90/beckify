import Foundation

// MARK: - RC / RL transient response

public struct TransientResult: Equatable, Sendable {
    public var timeConstant: Double
    /// Voltage (RC) or current (RL) at the requested time.
    public var valueAtTime: Double
    /// Percent of the way from the starting value to the final value.
    public var percentComplete: Double
    /// Sampled points for a response curve, time then value.
    public var curve: [(time: Double, value: Double)]

    public init(timeConstant: Double, valueAtTime: Double, percentComplete: Double, curve: [(time: Double, value: Double)]) {
        self.timeConstant = timeConstant
        self.valueAtTime = valueAtTime
        self.percentComplete = percentComplete
        self.curve = curve
    }
}

extension TransientResult {
    public static func == (lhs: TransientResult, rhs: TransientResult) -> Bool {
        lhs.timeConstant == rhs.timeConstant
            && lhs.valueAtTime == rhs.valueAtTime
            && lhs.percentComplete == rhs.percentComplete
            && lhs.curve.count == rhs.curve.count
            && zip(lhs.curve, rhs.curve).allSatisfy { $0.time == $1.time && $0.value == $1.value }
    }
}

public enum TransientCircuit {
    /// First-order step response. `amplitude` is the target when charging
    /// (the value being risen toward) or the starting value when discharging
    /// (the value being decayed away from) — same exponential, opposite sense.
    public static func step(
        amplitude: Double,
        timeConstant: Double,
        time: Double,
        charging: Bool,
        samples: Int = 24
    ) throws -> TransientResult {
        let final = try Positive.require(amplitude, name: "Amplitude")
        let tau = try Positive.require(timeConstant, name: "Time constant")
        guard time.isFinite, time >= 0 else { throw CalcError.nonPositive("Time") }

        func value(at t: Double) -> Double {
            charging ? final * (1 - exp(-t / tau)) : final * exp(-t / tau)
        }

        let v = value(at: time)
        let percent = charging ? (v / final) * 100 : (1 - v / final) * 100

        let span = max(time, tau * 5)
        let curve: [(time: Double, value: Double)] = (0..<samples).map { i in
            let t = span * Double(i) / Double(samples - 1)
            return (t, value(at: t))
        }

        return TransientResult(timeConstant: tau, valueAtTime: v, percentComplete: percent, curve: curve)
    }

    /// RC time constant in seconds, farads entered directly (convert µF before calling).
    public static func rcTimeConstant(resistance: Double, capacitance: Double) throws -> Double {
        try Positive.require(resistance, name: "Resistance") * (try Positive.require(capacitance, name: "Capacitance"))
    }

    /// RL time constant in seconds.
    public static func rlTimeConstant(inductance: Double, resistance: Double) throws -> Double {
        try Positive.require(inductance, name: "Inductance") / (try Positive.require(resistance, name: "Resistance"))
    }
}

// MARK: - Rack / bus current budget

public struct RackCurrentResult: Equatable, Sendable {
    public var totalCurrent: Double
    public var headroom: Double
    public var utilizationPercent: Double

    public init(totalCurrent: Double, headroom: Double, utilizationPercent: Double) {
        self.totalCurrent = totalCurrent
        self.headroom = headroom
        self.utilizationPercent = utilizationPercent
    }
}

/// Adding up device draws against a bus or backplane's rated current — the
/// same arithmetic whether it's a PLC 5 V logic bus or a 24 VDC panel rail.
public enum RackCurrentBudget {
    public static func solve(deviceCurrents: [Double], busCapacity: Double) throws -> RackCurrentResult {
        let capacity = try Positive.require(busCapacity, name: "Bus capacity")
        guard !deviceCurrents.isEmpty else { throw CalcError.missing("at least one device current") }
        for current in deviceCurrents {
            guard current.isFinite, current >= 0 else {
                throw CalcError.nonPositive("Every device current")
            }
        }

        let total = deviceCurrents.reduce(0, +)
        return RackCurrentResult(
            totalCurrent: total,
            headroom: capacity - total,
            utilizationPercent: (total / capacity) * 100
        )
    }
}

// MARK: - Diode I-V (Shockley)

public struct DiodeIVResult: Equatable, Sendable {
    public var current: Double
    public var thermalVoltage: Double
    /// Sampled points for the forward I-V curve, 0 V to the sweep ceiling.
    public var curve: [(voltage: Double, current: Double)]

    public init(current: Double, thermalVoltage: Double, curve: [(voltage: Double, current: Double)]) {
        self.current = current
        self.thermalVoltage = thermalVoltage
        self.curve = curve
    }
}

extension DiodeIVResult {
    public static func == (lhs: DiodeIVResult, rhs: DiodeIVResult) -> Bool {
        lhs.current == rhs.current
            && lhs.thermalVoltage == rhs.thermalVoltage
            && lhs.curve.count == rhs.curve.count
            && zip(lhs.curve, rhs.curve).allSatisfy { $0.voltage == $1.voltage && $0.current == $1.current }
    }
}

/// The Shockley diode equation — the one curve every semiconductor course
/// starts with, and the reason a diode's forward drop barely moves even
/// though its current changes by orders of magnitude.
public enum DiodeIV {
    static let boltzmann = 1.380649e-23
    static let elementaryCharge = 1.602176634e-19

    public static func thermalVoltage(temperatureKelvin: Double) throws -> Double {
        let t = try Positive.require(temperatureKelvin, name: "Temperature")
        return boltzmann * t / elementaryCharge
    }

    public static func solve(
        saturationCurrent: Double,
        idealityFactor: Double,
        temperatureKelvin: Double,
        forwardVoltage: Double,
        samples: Int = 24
    ) throws -> DiodeIVResult {
        let saturation = try Positive.require(saturationCurrent, name: "Saturation current")
        let n = try Positive.require(idealityFactor, name: "Ideality factor")
        let vt = try thermalVoltage(temperatureKelvin: temperatureKelvin)
        guard forwardVoltage.isFinite else { throw CalcError.missing("a forward voltage") }

        func current(at v: Double) -> Double {
            saturation * (exp(v / (n * vt)) - 1)
        }

        let sweepCeiling = max(forwardVoltage * 1.2, 0.1)
        let curve: [(voltage: Double, current: Double)] = (0..<samples).map { index in
            let v = sweepCeiling * Double(index) / Double(samples - 1)
            return (v, current(at: v))
        }

        return DiodeIVResult(current: current(at: forwardVoltage), thermalVoltage: vt, curve: curve)
    }
}

// MARK: - Intrinsic safety loop (Entity Concept)

public struct ISLoopResult: Equatable, Sendable {
    public var voltageOK: Bool
    public var currentOK: Bool
    public var capacitanceOK: Bool
    public var inductanceOK: Bool
    public var isSafe: Bool
    public var totalCapacitance: Double
    public var totalInductance: Double

    public init(
        voltageOK: Bool,
        currentOK: Bool,
        capacitanceOK: Bool,
        inductanceOK: Bool,
        isSafe: Bool,
        totalCapacitance: Double,
        totalInductance: Double
    ) {
        self.voltageOK = voltageOK
        self.currentOK = currentOK
        self.capacitanceOK = capacitanceOK
        self.inductanceOK = inductanceOK
        self.isSafe = isSafe
        self.totalCapacitance = totalCapacitance
        self.totalInductance = totalInductance
    }
}

/// The four Entity Concept inequalities from IEC 60079-11 / ISA RP12.06.01:
/// the barrier's output must never be able to supply more than the field
/// device can safely receive, and the field wiring's reactive parameters must
/// fit inside what the barrier was certified against.
///
/// This checks the parametric inequalities only. It is not a substitute for
/// the system's control drawing, a full loop calculation by a qualified
/// person, or the equipment's own certification documentation.
public enum ISLoopVerifier {
    public static func verify(
        barrierVoc: Double,
        barrierIsc: Double,
        barrierCa: Double,
        barrierLa: Double,
        deviceVmax: Double,
        deviceImax: Double,
        deviceCi: Double,
        deviceLi: Double,
        cableCapacitance: Double,
        cableInductance: Double
    ) throws -> ISLoopResult {
        for (value, name) in [
            (barrierVoc, "Barrier Voc"), (barrierIsc, "Barrier Isc"),
            (barrierCa, "Barrier Ca"), (barrierLa, "Barrier La"),
            (deviceVmax, "Device Vmax"), (deviceImax, "Device Imax"),
            (deviceCi, "Device Ci"), (deviceLi, "Device Li"),
            (cableCapacitance, "Cable capacitance"), (cableInductance, "Cable inductance"),
        ] {
            guard value.isFinite, value >= 0 else { throw CalcError.nonPositive(name) }
        }

        let totalC = deviceCi + cableCapacitance
        let totalL = deviceLi + cableInductance
        let voltageOK = barrierVoc <= deviceVmax
        let currentOK = barrierIsc <= deviceImax
        let capacitanceOK = barrierCa >= totalC
        let inductanceOK = barrierLa >= totalL

        return ISLoopResult(
            voltageOK: voltageOK,
            currentOK: currentOK,
            capacitanceOK: capacitanceOK,
            inductanceOK: inductanceOK,
            isSafe: voltageOK && currentOK && capacitanceOK && inductanceOK,
            totalCapacitance: totalC,
            totalInductance: totalL
        )
    }
}

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
