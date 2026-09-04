import Foundation

// MARK: - Synchronous speed, slip, and shaft torque

public struct MotorSpeedResult: Equatable, Sendable {
    /// Synchronous (field) speed in RPM.
    public var synchronousRPM: Double
    /// Actual rotor speed in RPM.
    public var rotorRPM: Double
    /// Slip as a percentage of synchronous speed.
    public var slipPercent: Double
    /// Slip frequency seen by the rotor, in Hz.
    public var slipFrequency: Double

    public init(synchronousRPM: Double, rotorRPM: Double, slipPercent: Double, slipFrequency: Double) {
        self.synchronousRPM = synchronousRPM
        self.rotorRPM = rotorRPM
        self.slipPercent = slipPercent
        self.slipFrequency = slipFrequency
    }
}

public struct MotorTorqueResult: Equatable, Sendable {
    public var torqueLbFt: Double
    public var torqueNewtonMetres: Double
    public var horsepower: Double
    public var rpm: Double

    public init(torqueLbFt: Double, torqueNewtonMetres: Double, horsepower: Double, rpm: Double) {
        self.torqueLbFt = torqueLbFt
        self.torqueNewtonMetres = torqueNewtonMetres
        self.horsepower = horsepower
        self.rpm = rpm
    }
}

public enum MotorSpeed {
    /// Poles are always even on an induction machine — 2, 4, 6, 8…
    public static let commonPoleCounts = [2, 4, 6, 8, 10, 12]

    /// n_s = 120 f / p. The nameplate RPM is always below this; the gap is slip.
    public static func synchronousRPM(frequency: Double, poles: Int) throws -> Double {
        let f = try Positive.require(frequency, name: "Frequency")
        guard poles >= 2 else { throw CalcError.outOfRange("Pole count must be 2 or more.") }
        guard poles % 2 == 0 else { throw CalcError.outOfRange("Pole count must be even.") }
        return 120 * f / Double(poles)
    }

    /// Slip from a nameplate RPM. A nameplate above synchronous speed is a
    /// data-entry error on a motor, not a generator claim, so it is rejected.
    public static func slip(frequency: Double, poles: Int, nameplateRPM: Double) throws -> MotorSpeedResult {
        let sync = try synchronousRPM(frequency: frequency, poles: poles)
        let rpm = try Positive.require(nameplateRPM, name: "Nameplate RPM")
        guard rpm <= sync else {
            throw CalcError.outOfRange(
                "Nameplate RPM (\(Int(rpm.rounded()))) is above synchronous speed (\(Int(sync.rounded()))). Check the pole count and the line frequency."
            )
        }

        let slipFraction = (sync - rpm) / sync
        return MotorSpeedResult(
            synchronousRPM: sync,
            rotorRPM: rpm,
            slipPercent: slipFraction * 100,
            slipFrequency: slipFraction * frequency
        )
    }

    /// Rotor speed implied by a slip percentage — the reverse lookup.
    public static func rotorRPM(frequency: Double, poles: Int, slipPercent: Double) throws -> MotorSpeedResult {
        let sync = try synchronousRPM(frequency: frequency, poles: poles)
        guard slipPercent.isFinite, slipPercent >= 0, slipPercent <= 100 else {
            throw CalcError.outOfRange("Slip must be between 0 and 100 %.")
        }
        let fraction = slipPercent / 100
        return MotorSpeedResult(
            synchronousRPM: sync,
            rotorRPM: sync * (1 - fraction),
            slipPercent: slipPercent,
            slipFrequency: fraction * frequency
        )
    }
}

public enum MotorTorque {
    /// T(lb·ft) = 5252 · HP / RPM. 5252 is 33 000 ft·lb/min per HP divided by 2π.
    public static let constant: Double = 5252

    /// Newton-metres per pound-foot.
    public static let newtonMetresPerLbFt: Double = 1.3558179483314004

    public static func fromHorsepower(_ horsepower: Double, rpm: Double) throws -> MotorTorqueResult {
        let hp = try Positive.require(horsepower, name: "Horsepower")
        let speed = try Positive.require(rpm, name: "RPM")
        let lbFt = constant * hp / speed
        return MotorTorqueResult(
            torqueLbFt: lbFt,
            torqueNewtonMetres: lbFt * newtonMetresPerLbFt,
            horsepower: hp,
            rpm: speed
        )
    }

    public static func fromTorque(lbFt: Double, rpm: Double) throws -> MotorTorqueResult {
        let torque = try Positive.require(lbFt, name: "Torque")
        let speed = try Positive.require(rpm, name: "RPM")
        return MotorTorqueResult(
            torqueLbFt: torque,
            torqueNewtonMetres: torque * newtonMetresPerLbFt,
            horsepower: torque * speed / constant,
            rpm: speed
        )
    }

    /// Points for a constant-horsepower torque-vs-speed curve, for plotting.
    /// Torque falls off as 1/RPM — sampled log-ish across the usable range so
    /// the low-speed knee isn't lost.
    public static func curve(horsepower: Double, minRPM: Double, maxRPM: Double, samples: Int = 24) -> [(rpm: Double, torqueLbFt: Double)] {
        guard horsepower > 0, minRPM > 0, maxRPM > minRPM, samples > 1 else { return [] }
        return (0..<samples).map { i in
            let t = Double(i) / Double(samples - 1)
            let rpm = minRPM + (maxRPM - minRPM) * t
            return (rpm, constant * horsepower / rpm)
        }
    }
}
