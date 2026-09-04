import Foundation

/// One phasor: a magnitude at an angle, degrees measured counter-clockwise
/// from the positive real axis — the electrical-engineering convention.
public struct Phasor: Equatable, Sendable, Identifiable {
    public var id: Int
    public var label: String
    public var magnitude: Double
    public var angleDegrees: Double

    public init(id: Int, label: String, magnitude: Double, angleDegrees: Double) {
        self.id = id
        self.label = label
        self.magnitude = magnitude
        self.angleDegrees = angleDegrees
    }

    var real: Double { magnitude * cos(angleDegrees * .pi / 180) }
    var imaginary: Double { magnitude * sin(angleDegrees * .pi / 180) }
}

public struct PhasorSumResult: Equatable, Sendable {
    public var phasors: [Phasor]
    public var resultantMagnitude: Double
    public var resultantAngleDegrees: Double

    public init(phasors: [Phasor], resultantMagnitude: Double, resultantAngleDegrees: Double) {
        self.phasors = phasors
        self.resultantMagnitude = resultantMagnitude
        self.resultantAngleDegrees = resultantAngleDegrees
    }
}

public enum PhasorSum {
    /// Standard three-phase angles, 120° apart, for the "load a balanced set"
    /// shortcut. A-B-C rotation: A at 0°, B lagging by 120°, C lagging by 240°.
    public static let balancedThreePhaseAngles: [Double] = [0, -120, -240]

    /// Vector sum of two or more phasors — the thing a phasor diagram is
    /// actually for: adding sine waves that are out of step with each other.
    public static func resultant(of phasors: [Phasor]) throws -> PhasorSumResult {
        guard phasors.count >= 2 else {
            throw CalcError.outOfRange("Add at least two phasors to sum.")
        }
        for phasor in phasors {
            guard phasor.magnitude.isFinite, phasor.magnitude >= 0 else {
                throw CalcError.nonPositive("\(phasor.label) magnitude")
            }
            guard phasor.angleDegrees.isFinite else {
                throw CalcError.missing("a finite angle for \(phasor.label)")
            }
        }

        let sumReal = phasors.reduce(0) { $0 + $1.real }
        let sumImaginary = phasors.reduce(0) { $0 + $1.imaginary }
        let magnitude = (sumReal * sumReal + sumImaginary * sumImaginary).squareRoot()
        let angle = magnitude > 0 ? atan2(sumImaginary, sumReal) * 180 / .pi : 0

        return PhasorSumResult(phasors: phasors, resultantMagnitude: magnitude, resultantAngleDegrees: angle)
    }
}
