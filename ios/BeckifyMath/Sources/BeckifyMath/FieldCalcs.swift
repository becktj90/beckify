import Foundation

// MARK: - Reactance and resonance

public struct ReactanceResult: Equatable, Sendable {
    public var inductiveReactance: Double
    public var capacitiveReactance: Double
    public var netReactance: Double
    public var impedance: Double
    public var phaseAngleDegrees: Double
    public var formula: String

    public init(
        inductiveReactance: Double,
        capacitiveReactance: Double,
        netReactance: Double,
        impedance: Double,
        phaseAngleDegrees: Double,
        formula: String
    ) {
        self.inductiveReactance = inductiveReactance
        self.capacitiveReactance = capacitiveReactance
        self.netReactance = netReactance
        self.impedance = impedance
        self.phaseAngleDegrees = phaseAngleDegrees
        self.formula = formula
    }
}

public struct ResonanceResult: Equatable, Sendable {
    public var frequency: Double
    public var qualityFactor: Double
    public var bandwidth: Double
    public var formula: String

    public init(frequency: Double, qualityFactor: Double, bandwidth: Double, formula: String) {
        self.frequency = frequency
        self.qualityFactor = qualityFactor
        self.bandwidth = bandwidth
        self.formula = formula
    }
}

public enum Reactance {
    /// Series R-L-C at one frequency. X_L = 2πfL, X_C = 1/(2πfC).
    public static func series(
        frequency: Double,
        resistance: Double,
        inductance: Double,
        capacitance: Double
    ) throws -> ReactanceResult {
        let f = try Positive.require(frequency, name: "Frequency")
        guard resistance.isFinite, inductance.isFinite, capacitance.isFinite else {
            throw CalcError.missing("finite R, L, and C values")
        }
        guard resistance >= 0, inductance >= 0, capacitance >= 0 else {
            throw CalcError.outOfRange("Resistance, inductance, and capacitance cannot be negative.")
        }
        if inductance == 0 && capacitance == 0 {
            throw CalcError.missing("an inductance or a capacitance")
        }

        let omega = 2 * Double.pi * f
        let xl = omega * inductance
        // An open (C = 0) passes no current: treat its reactance as unbounded
        // rather than dividing by zero.
        let xc = capacitance > 0 ? 1 / (omega * capacitance) : Double.infinity
        let net = xc.isInfinite ? -Double.infinity : xl - xc
        let magnitude = net.isInfinite ? Double.infinity : (resistance * resistance + net * net).squareRoot()
        let theta = net.isInfinite ? -90 : atan2(net, resistance) * 180 / Double.pi

        return ReactanceResult(
            inductiveReactance: xl,
            capacitiveReactance: xc,
            netReactance: net,
            impedance: magnitude,
            phaseAngleDegrees: theta,
            formula: "X_L = 2πfL    X_C = 1/(2πfC)    Z = √(R² + (X_L − X_C)²)"
        )
    }

    /// LC resonance: f₀ = 1/(2π√(LC)), Q = (1/R)·√(L/C) for a series circuit.
    public static func resonance(
        inductance: Double,
        capacitance: Double,
        resistance: Double
    ) throws -> ResonanceResult {
        let l = try Positive.require(inductance, name: "Inductance")
        let c = try Positive.require(capacitance, name: "Capacitance")
        let f0 = 1 / (2 * Double.pi * (l * c).squareRoot())

        var q = Double.nan
        var bandwidth = Double.nan
        if resistance.isFinite, resistance > 0 {
            q = (1 / resistance) * (l / c).squareRoot()
            bandwidth = q > 0 ? f0 / q : Double.nan
        }

        return ResonanceResult(
            frequency: f0,
            qualityFactor: q,
            bandwidth: bandwidth,
            formula: "f₀ = 1/(2π√(LC))    Q = (1/R)√(L/C)    BW = f₀/Q"
        )
    }
}

// MARK: - Power factor correction

public struct PowerFactorResult: Equatable, Sendable {
    public var existingKVAR: Double
    public var targetKVAR: Double
    public var correctionKVAR: Double
    public var capacitance: Double
    public var newKVA: Double
    public var formula: String

    public init(
        existingKVAR: Double,
        targetKVAR: Double,
        correctionKVAR: Double,
        capacitance: Double,
        newKVA: Double,
        formula: String
    ) {
        self.existingKVAR = existingKVAR
        self.targetKVAR = targetKVAR
        self.correctionKVAR = correctionKVAR
        self.capacitance = capacitance
        self.newKVA = newKVA
        self.formula = formula
    }
}

public enum PowerFactorCorrection {
    /// Capacitive kVAR to move a real load from one power factor to a target.
    public static func solve(
        realPowerKW: Double,
        existingPowerFactor: Double,
        targetPowerFactor: Double,
        voltage: Double,
        frequency: Double = 60,
        system: ElectricalSystem = .threePhase
    ) throws -> PowerFactorResult {
        let kw = try Positive.require(realPowerKW, name: "Real power")
        guard system != .dc else { throw CalcError.outOfRange("Power-factor correction requires an AC system.") }
        let volts = try Positive.require(voltage, name: "Voltage")
        let hertz = try Positive.require(frequency, name: "Frequency")
        guard existingPowerFactor > 0, existingPowerFactor <= 1 else {
            throw CalcError.outOfRange("Existing power factor must be between 0 and 1.")
        }
        guard targetPowerFactor > 0, targetPowerFactor <= 1 else {
            throw CalcError.outOfRange("Target power factor must be between 0 and 1.")
        }
        guard targetPowerFactor > existingPowerFactor else {
            throw CalcError.outOfRange("Target power factor has to be higher than the existing one.")
        }

        let existingAngle = acos(existingPowerFactor)
        let targetAngle = acos(targetPowerFactor)
        let existingKVAR = kw * tan(existingAngle)
        let targetKVAR = kw * tan(targetAngle)
        let correction = existingKVAR - targetKVAR
        let newKVA = kw / targetPowerFactor

        // Q = V²·2πfC, with the per-phase voltage for a wye bank.
        let perPhaseVolts = system == .threePhase ? volts / 3.0.squareRoot() : volts
        let perPhaseVAR = correction * 1000 / (system == .threePhase ? 3 : 1)
        let capacitance = perPhaseVAR / (2 * Double.pi * hertz * perPhaseVolts * perPhaseVolts)

        return PowerFactorResult(
            existingKVAR: existingKVAR,
            targetKVAR: targetKVAR,
            correctionKVAR: correction,
            capacitance: capacitance,
            newKVA: newKVA,
            formula: "kVAR = kW·(tan θ₁ − tan θ₂)    C = Q / (2πf·V²)"
        )
    }
}

// MARK: - Short-circuit current

public struct ShortCircuitResult: Equatable, Sendable {
    public var fullLoadAmps: Double
    public var availableFaultAmps: Double
    public var multiplier: Double
    public var formula: String

    public init(fullLoadAmps: Double, availableFaultAmps: Double, multiplier: Double, formula: String) {
        self.fullLoadAmps = fullLoadAmps
        self.availableFaultAmps = availableFaultAmps
        self.multiplier = multiplier
        self.formula = formula
    }
}

public enum ShortCircuit {
    /// Infinite-bus fault current at the transformer secondary.
    /// Design aid only — a real study models source and conductor impedance.
    public static func transformerSecondary(
        kVA: Double,
        secondaryVolts: Double,
        impedancePercent: Double,
        system: ElectricalSystem = .threePhase
    ) throws -> ShortCircuitResult {
        let kva = try Positive.require(kVA, name: "Transformer kVA")
        let volts = try Positive.require(secondaryVolts, name: "Secondary voltage")
        let z = try Positive.require(impedancePercent, name: "Impedance %")
        guard system != .dc else { throw CalcError.outOfRange("Transformer secondary fault current requires an AC system.") }

        let fla = (kva * 1000) / (volts * system.phaseMultiplier)
        let multiplier = 100 / z

        return ShortCircuitResult(
            fullLoadAmps: fla,
            availableFaultAmps: fla * multiplier,
            multiplier: multiplier,
            formula: "I_FLA = kVA·1000 / (\(system == .threePhase ? "√3·" : "")V)    I_SC = I_FLA × 100/%Z"
        )
    }
}

// MARK: - Circular mils

public enum CircularMils {
    /// Circular mils of a round conductor: CM = d(mils)².
    public static func fromDiameterMils(_ mils: Double) throws -> Double {
        let d = try Positive.require(mils, name: "Diameter")
        return d * d
    }

    public static func fromDiameterInches(_ inches: Double) throws -> Double {
        try fromDiameterMils(Positive.require(inches, name: "Diameter") * 1000)
    }

    public static func diameterMils(fromCircularMils cm: Double) throws -> Double {
        try Positive.require(cm, name: "Circular mils").squareRoot()
    }

    /// Square inches for a round conductor of the given circular mils.
    public static func squareInches(fromCircularMils cm: Double) throws -> Double {
        let value = try Positive.require(cm, name: "Circular mils")
        let diameterInches = value.squareRoot() / 1000
        return Double.pi * diameterInches * diameterInches / 4
    }
}

// MARK: - Load and demand factors

public struct LoadFactorResult: Equatable, Sendable {
    public var demandFactor: Double
    public var loadFactor: Double
    public var diversityFactor: Double
    public var capacityUtilization: Double
    public var formula: String

    public init(
        demandFactor: Double,
        loadFactor: Double,
        diversityFactor: Double,
        capacityUtilization: Double,
        formula: String
    ) {
        self.demandFactor = demandFactor
        self.loadFactor = loadFactor
        self.diversityFactor = diversityFactor
        self.capacityUtilization = capacityUtilization
        self.formula = formula
    }
}

public enum LoadFactors {
    /// Ratios an estimator reads off metered data. Any input left at zero drops
    /// the ratios that need it rather than returning a divide-by-zero.
    public static func solve(
        connectedLoad: Double,
        maximumDemand: Double,
        averageLoad: Double,
        sumOfIndividualDemands: Double,
        systemCapacity: Double
    ) throws -> LoadFactorResult {
        let connected = try Positive.require(connectedLoad, name: "Connected load")
        let demand = try Positive.require(maximumDemand, name: "Maximum demand")

        let demandFactor = demand / connected
        let loadFactor = averageLoad > 0 ? averageLoad / demand : Double.nan
        let diversity = sumOfIndividualDemands > 0 ? sumOfIndividualDemands / demand : Double.nan
        let utilization = systemCapacity > 0 ? demand / systemCapacity : Double.nan

        return LoadFactorResult(
            demandFactor: demandFactor,
            loadFactor: loadFactor,
            diversityFactor: diversity,
            capacityUtilization: utilization,
            formula: "DF = max demand / connected    LF = average / max demand    Diversity = Σ individual / max demand"
        )
    }
}
