import Foundation

public struct DCPowerResult: Equatable, Sendable {
    public var power: Double
    public var voltage: Double
    public var current: Double
    public var resistance: Double
    public var formula: String

    public init(power: Double, voltage: Double, current: Double, resistance: Double, formula: String) {
        self.power = power
        self.voltage = voltage
        self.current = current
        self.resistance = resistance
        self.formula = formula
    }
}

public enum DCPower {
    public static func fromVI(voltage: Double, current: Double) throws -> DCPowerResult {
        guard voltage.isFinite, current.isFinite else { throw CalcError.missing("Voltage and current") }
        guard current != 0 else {
            throw CalcError.outOfRange("Current must not be zero when deriving resistance.")
        }
        let p = voltage * current
        let r = voltage / current
        return DCPowerResult(power: p, voltage: voltage, current: current, resistance: r, formula: "P = V × I")
    }

    public static func fromIR(current: Double, resistance: Double) throws -> DCPowerResult {
        let i = try Positive.require(current, name: "Current")
        let r = try Positive.require(resistance, name: "Resistance")
        let p = i * i * r
        return DCPowerResult(power: p, voltage: i * r, current: i, resistance: r, formula: "P = I² × R")
    }

    public static func fromVR(voltage: Double, resistance: Double) throws -> DCPowerResult {
        let v = try Positive.require(voltage, name: "Voltage")
        let r = try Positive.require(resistance, name: "Resistance")
        let p = v * v / r
        return DCPowerResult(power: p, voltage: v, current: v / r, resistance: r, formula: "P = V² / R")
    }
}

public struct ACPowerResult: Equatable, Sendable {
    public var kVA: Double
    public var kW: Double
    public var kVAR: Double
    public var powerFactor: Double
    public var phaseAngleDegrees: Double
    public var formula: String

    public init(kVA: Double, kW: Double, kVAR: Double, powerFactor: Double, phaseAngleDegrees: Double, formula: String) {
        self.kVA = kVA
        self.kW = kW
        self.kVAR = kVAR
        self.powerFactor = powerFactor
        self.phaseAngleDegrees = phaseAngleDegrees
        self.formula = formula
    }
}

public enum ACPower {
    public static func solve(system: ElectricalSystem, voltage: Double, current: Double, powerFactor: Double) throws -> ACPowerResult {
        guard system != .dc else {
            throw CalcError.outOfRange("AC power is for 1Ø or 3Ø. Use DC power or Power Wizard for DC.")
        }
        let v = try Positive.require(voltage, name: "Voltage")
        let i = try Positive.require(current, name: "Current")
        guard powerFactor.isFinite, powerFactor > 0, powerFactor <= 1 else {
            throw CalcError.outOfRange("Power factor must be between 0 and 1 (exclusive of 0).")
        }
        let kVA = system.phaseMultiplier * v * i / 1000
        let kW = kVA * powerFactor
        let kVAR = kVA * (1 - powerFactor * powerFactor).squareRoot()
        let theta = acos(min(1, powerFactor)) * 180 / .pi
        let formula = system == .threePhase
            ? "kVA = √3 × V_L-L × I_L / 1000    kW = kVA × PF"
            : "kVA = V × I / 1000    kW = kVA × PF"
        return ACPowerResult(kVA: kVA, kW: kW, kVAR: kVAR, powerFactor: powerFactor, phaseAngleDegrees: theta, formula: formula)
    }
}

public enum PowerWizardKnown: Equatable, Sendable {
    case amps(Double)
    case kilowatts(Double)
    case kilovoltAmps(Double)
    case horsepower(Double)
}

public struct PowerWizardResult: Equatable, Sendable {
    public var system: ElectricalSystem
    public var voltage: Double
    public var amps: Double
    public var kVA: Double
    public var kW: Double
    public var kVAR: Double
    public var horsepower: Double
    public var powerFactor: Double
    public var efficiency: Double
    public var phaseAngleDegrees: Double
    public var formula: String

    public init(
        system: ElectricalSystem,
        voltage: Double,
        amps: Double,
        kVA: Double,
        kW: Double,
        kVAR: Double,
        horsepower: Double,
        powerFactor: Double,
        efficiency: Double,
        phaseAngleDegrees: Double,
        formula: String
    ) {
        self.system = system
        self.voltage = voltage
        self.amps = amps
        self.kVA = kVA
        self.kW = kW
        self.kVAR = kVAR
        self.horsepower = horsepower
        self.powerFactor = powerFactor
        self.efficiency = efficiency
        self.phaseAngleDegrees = phaseAngleDegrees
        self.formula = formula
    }
}

/// One path for DC, 1Ø, and 3Ø: solve any of A / kW / kVA / HP from the others.
public enum PowerWizard {
    public static func solve(
        system: ElectricalSystem,
        known: PowerWizardKnown,
        voltage: Double,
        powerFactor: Double,
        efficiency: Double
    ) throws -> PowerWizardResult {
        let v = try Positive.require(voltage, name: "Voltage")
        let pf = system == .dc ? 1.0 : powerFactor
        if system != .dc {
            guard pf.isFinite, pf > 0, pf <= 1 else {
                throw CalcError.outOfRange("Power factor must be between 0 and 1 (exclusive of 0).")
            }
        }
        guard efficiency.isFinite, efficiency > 0, efficiency <= 1 else {
            throw CalcError.outOfRange("Efficiency must be between 0 and 1 (exclusive of 0).")
        }
        let safeEff = efficiency
        let mult = system.phaseMultiplier
        let multText = system == .threePhase ? "√3 × " : ""

        let amps: Double
        let kva: Double
        let kw: Double
        let hp: Double
        let formula: String

        switch known {
        case .amps(let value):
            amps = try Positive.require(value, name: "Current")
            kva = (mult * v * amps) / 1000
            kw = kva * pf
            hp = (kw * 1000 * safeEff) / 746
            formula = "kVA = \(multText)V × I ÷ 1000"
        case .kilovoltAmps(let value):
            kva = try Positive.require(value, name: "kVA")
            amps = (kva * 1000) / (mult * v)
            kw = kva * pf
            hp = (kw * 1000 * safeEff) / 746
            formula = "I = kVA × 1000 ÷ (\(multText)V)"
        case .kilowatts(let value):
            kw = try Positive.require(value, name: "kW")
            kva = kw / pf
            amps = (kw * 1000) / (mult * v * pf)
            hp = (kw * 1000 * safeEff) / 746
            formula = "I = kW × 1000 ÷ (\(multText)V × PF)"
        case .horsepower(let value):
            hp = try Positive.require(value, name: "Horsepower")
            kw = (hp * 746) / (safeEff * 1000)
            kva = kw / pf
            amps = (kw * 1000) / (mult * v * pf)
            formula = "I = HP × 746 ÷ (\(multText)V × PF × Eff)"
        }

        let kvar = system == .dc ? 0 : max(0, kva * kva - kw * kw).squareRoot()
        let theta = system == .dc ? 0 : acos(min(1, pf)) * 180 / .pi

        return PowerWizardResult(
            system: system,
            voltage: v,
            amps: amps,
            kVA: kva,
            kW: kw,
            kVAR: kvar,
            horsepower: hp,
            powerFactor: pf,
            efficiency: safeEff,
            phaseAngleDegrees: theta,
            formula: formula
        )
    }
}
