import Foundation

// MARK: - dBm / watts

public struct RFPowerResult: Equatable, Sendable {
    public var dBm: Double
    public var watts: Double
    public var milliwatts: Double
    /// RMS volts into the reference impedance.
    public var voltsRMS: Double
    public var impedance: Double

    public init(dBm: Double, watts: Double, milliwatts: Double, voltsRMS: Double, impedance: Double) {
        self.dBm = dBm
        self.watts = watts
        self.milliwatts = milliwatts
        self.voltsRMS = voltsRMS
        self.impedance = impedance
    }
}

public enum RFPower {
    /// dBm is decibels relative to one milliwatt: P(mW) = 10^(dBm/10).
    public static func fromDBm(_ dBm: Double, impedance: Double = 50) throws -> RFPowerResult {
        guard dBm.isFinite else { throw CalcError.missing("a level in dBm") }
        let z = try Positive.require(impedance, name: "Impedance")
        let milliwatts = pow(10, dBm / 10)
        let watts = milliwatts / 1000
        return RFPowerResult(
            dBm: dBm,
            watts: watts,
            milliwatts: milliwatts,
            voltsRMS: (watts * z).squareRoot(),
            impedance: z
        )
    }

    public static func fromWatts(_ watts: Double, impedance: Double = 50) throws -> RFPowerResult {
        let p = try Positive.require(watts, name: "Power")
        let z = try Positive.require(impedance, name: "Impedance")
        let milliwatts = p * 1000
        return RFPowerResult(
            dBm: 10 * log10(milliwatts),
            watts: p,
            milliwatts: milliwatts,
            voltsRMS: (p * z).squareRoot(),
            impedance: z
        )
    }
}

// MARK: - VSWR, return loss, mismatch

public struct MatchResult: Equatable, Sendable {
    public var vswr: Double
    public var returnLossDB: Double
    /// |Γ|, the magnitude of the reflection coefficient (0…1).
    public var reflectionCoefficient: Double
    /// Fraction of forward power that comes back, as a percentage.
    public var reflectedPowerPercent: Double
    /// Extra loss through the mismatch, in dB.
    public var mismatchLossDB: Double

    public init(
        vswr: Double,
        returnLossDB: Double,
        reflectionCoefficient: Double,
        reflectedPowerPercent: Double,
        mismatchLossDB: Double
    ) {
        self.vswr = vswr
        self.returnLossDB = returnLossDB
        self.reflectionCoefficient = reflectionCoefficient
        self.reflectedPowerPercent = reflectedPowerPercent
        self.mismatchLossDB = mismatchLossDB
    }
}

public enum AntennaMatch {
    /// A perfect match is 1:1 with infinite return loss; the maths there divides
    /// by zero, so it is reported as a very large return loss rather than ∞.
    public static let perfectMatchReturnLossDB: Double = 99

    public static func fromVSWR(_ vswr: Double) throws -> MatchResult {
        guard vswr.isFinite, vswr >= 1 else {
            throw CalcError.outOfRange("VSWR is 1 or greater — 1:1 is a perfect match.")
        }
        let gamma = (vswr - 1) / (vswr + 1)
        return result(gamma: gamma, vswr: vswr)
    }

    public static func fromReturnLoss(_ returnLossDB: Double) throws -> MatchResult {
        guard returnLossDB.isFinite, returnLossDB >= 0 else {
            throw CalcError.outOfRange("Return loss is a positive number of dB below the forward power.")
        }
        let gamma = pow(10, -returnLossDB / 20)
        let vswr = gamma >= 1 ? Double.infinity : (1 + gamma) / (1 - gamma)
        return result(gamma: gamma, vswr: vswr)
    }

    public static func fromReflectionCoefficient(_ gamma: Double) throws -> MatchResult {
        guard gamma.isFinite, gamma >= 0, gamma <= 1 else {
            throw CalcError.outOfRange("|Γ| runs from 0 (matched) to 1 (fully reflected).")
        }
        let vswr = gamma >= 1 ? Double.infinity : (1 + gamma) / (1 - gamma)
        return result(gamma: gamma, vswr: vswr)
    }

    private static func result(gamma: Double, vswr: Double) -> MatchResult {
        let reflectedFraction = gamma * gamma
        let returnLoss = gamma <= 0 ? perfectMatchReturnLossDB : -20 * log10(gamma)
        let mismatchLoss = reflectedFraction >= 1 ? Double.infinity : -10 * log10(1 - reflectedFraction)
        return MatchResult(
            vswr: vswr,
            returnLossDB: returnLoss,
            reflectionCoefficient: gamma,
            reflectedPowerPercent: reflectedFraction * 100,
            mismatchLossDB: mismatchLoss
        )
    }
}

// MARK: - Free-space path loss

public struct PathLossResult: Equatable, Sendable {
    public var lossDB: Double
    public var frequencyMHz: Double
    public var distanceMetres: Double
    /// Level arriving at the far end when a transmit level and antenna gains are given.
    public var receivedDBm: Double?

    public init(lossDB: Double, frequencyMHz: Double, distanceMetres: Double, receivedDBm: Double?) {
        self.lossDB = lossDB
        self.frequencyMHz = frequencyMHz
        self.distanceMetres = distanceMetres
        self.receivedDBm = receivedDBm
    }
}

public enum FreeSpacePathLoss {
    /// FSPL(dB) = 20·log₁₀(d_km) + 20·log₁₀(f_MHz) + 32.44.
    public static let constantKmMHz: Double = 32.44

    public static func loss(
        frequencyMHz: Double,
        distanceMetres: Double,
        transmitDBm: Double? = nil,
        transmitGainDBi: Double = 0,
        receiveGainDBi: Double = 0
    ) throws -> PathLossResult {
        let f = try Positive.require(frequencyMHz, name: "Frequency")
        let d = try Positive.require(distanceMetres, name: "Distance")
        let loss = 20 * log10(d / 1000) + 20 * log10(f) + constantKmMHz

        var received: Double?
        if let transmitDBm, transmitDBm.isFinite {
            guard transmitGainDBi.isFinite, receiveGainDBi.isFinite else {
                throw CalcError.missing("finite antenna gains")
            }
            received = transmitDBm + transmitGainDBi + receiveGainDBi - loss
        }

        return PathLossResult(
            lossDB: loss,
            frequencyMHz: f,
            distanceMetres: d,
            receivedDBm: received
        )
    }

    /// Loss sampled across a distance range at a fixed frequency, for plotting.
    /// Distances are log-spaced since FSPL is logarithmic in distance.
    public static func distanceSweep(frequencyMHz: Double, minMetres: Double, maxMetres: Double, samples: Int = 24) -> [(distance: Double, lossDB: Double)] {
        guard frequencyMHz > 0, minMetres > 0, maxMetres > minMetres, samples > 1 else { return [] }
        let logMin = log10(minMetres)
        let logMax = log10(maxMetres)
        return (0..<samples).compactMap { i in
            let t = Double(i) / Double(samples - 1)
            let distance = pow(10, logMin + (logMax - logMin) * t)
            guard let result = try? loss(frequencyMHz: frequencyMHz, distanceMetres: distance) else { return nil }
            return (distance, result.lossDB)
        }
    }
}
