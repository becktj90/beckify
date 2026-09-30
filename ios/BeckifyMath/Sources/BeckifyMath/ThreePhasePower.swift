import Foundation

/// Rectangular ohms. Positive reactance is inductive.
public struct ComplexOhms: Equatable, Sendable {
    public var resistance: Double
    public var reactance: Double

    public init(resistance: Double, reactance: Double) {
        self.resistance = resistance
        self.reactance = reactance
    }

    public var magnitude: Double { hypot(resistance, reactance) }

    public var angleDegrees: Double { atan2(reactance, resistance) * 180 / .pi }

    public func scaled(by factor: Double) -> ComplexOhms {
        ComplexOhms(resistance: resistance * factor, reactance: reactance * factor)
    }
}

/// Balanced source and load. Mixed pairs are the four ordinary connections.
public enum ThreePhaseTopology: String, CaseIterable, Sendable, Equatable, Hashable, Identifiable {
    case wyeWye = "yy"
    case wyeDelta = "yd"
    case deltaWye = "dy"
    case deltaDelta = "dd"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .wyeWye: return "Y–Y"
        case .wyeDelta: return "Y–Δ"
        case .deltaWye: return "Δ–Y"
        case .deltaDelta: return "Δ–Δ"
        }
    }

    public var sourceIsWye: Bool { self == .wyeWye || self == .wyeDelta }
    public var loadIsWye: Bool { self == .wyeWye || self == .deltaWye }
    public var neutralPresent: Bool { sourceIsWye || loadIsWye }

    /// Line voltage ÷ phase voltage on that side. Wye is √3. Delta is 1.
    public var sourceVoltageRatio: Double { sourceIsWye ? Self.sqrt3 : 1 }
    public var loadVoltageRatio: Double { loadIsWye ? Self.sqrt3 : 1 }

    /// Line current ÷ phase current on that side. Wye is 1. Delta is √3.
    public var sourceCurrentRatio: Double { sourceIsWye ? 1 : Self.sqrt3 }
    public var loadCurrentRatio: Double { loadIsWye ? 1 : Self.sqrt3 }

    /// ABC sequence: line voltage leads a wye phase voltage by 30°. A delta phase voltage is the line voltage.
    public var sourceVoltageLeadDegrees: Double { sourceIsWye ? 30 : 0 }
    public var loadVoltageLeadDegrees: Double { loadIsWye ? 30 : 0 }

    /// ABC sequence: line current lags a delta phase current by 30°. A wye phase current is the line current.
    public var sourceCurrentLagDegrees: Double { sourceIsWye ? 0 : 30 }
    public var loadCurrentLagDegrees: Double { loadIsWye ? 0 : 30 }

    public var reading: String {
        switch self {
        case .wyeWye:
            return "One phase is the whole circuit. Neutral current is zero while the three currents stay equal."
        case .wyeDelta:
            return "The delta load is solved as Z ÷ 3. Phase current is line current ÷ √3."
        case .deltaWye:
            return "The delta source is solved as a wye at line ÷ √3, 30° from the line voltage."
        case .deltaDelta:
            return "Both sides use a wye equivalent. On the delta, phase voltage equals line voltage."
        }
    }

    fileprivate static let sqrt3 = 3.0.squareRoot()
}

public struct ThreePhasePowerResult: Equatable, Sendable {
    public var topology: ThreePhaseTopology
    public var sourceLineVolts: Double
    public var sourcePhaseVolts: Double
    public var loadLineVolts: Double
    public var loadPhaseVolts: Double
    public var lineCurrent: Double
    public var sourcePhaseCurrent: Double
    public var loadPhaseCurrent: Double
    public var phaseAngleDegrees: Double
    public var powerFactor: Double
    public var lagging: Bool
    public var watts: Double
    public var vars: Double
    public var voltAmps: Double
    public var neutralAmps: Double
    public var equivalentWye: ComplexOhms
    public var line: ComplexOhms
    public var lineLossWatts: Double
    public var sourceWatts: Double
    public var sourceVars: Double
    public var reading: String
    public var formula: String

    public init(
        topology: ThreePhaseTopology,
        sourceLineVolts: Double,
        sourcePhaseVolts: Double,
        loadLineVolts: Double,
        loadPhaseVolts: Double,
        lineCurrent: Double,
        sourcePhaseCurrent: Double,
        loadPhaseCurrent: Double,
        phaseAngleDegrees: Double,
        powerFactor: Double,
        lagging: Bool,
        watts: Double,
        vars: Double,
        voltAmps: Double,
        neutralAmps: Double,
        equivalentWye: ComplexOhms,
        line: ComplexOhms,
        lineLossWatts: Double,
        sourceWatts: Double,
        sourceVars: Double,
        reading: String,
        formula: String
    ) {
        self.topology = topology
        self.sourceLineVolts = sourceLineVolts
        self.sourcePhaseVolts = sourcePhaseVolts
        self.loadLineVolts = loadLineVolts
        self.loadPhaseVolts = loadPhaseVolts
        self.lineCurrent = lineCurrent
        self.sourcePhaseCurrent = sourcePhaseCurrent
        self.loadPhaseCurrent = loadPhaseCurrent
        self.phaseAngleDegrees = phaseAngleDegrees
        self.powerFactor = powerFactor
        self.lagging = lagging
        self.watts = watts
        self.vars = vars
        self.voltAmps = voltAmps
        self.neutralAmps = neutralAmps
        self.equivalentWye = equivalentWye
        self.line = line
        self.lineLossWatts = lineLossWatts
        self.sourceWatts = sourceWatts
        self.sourceVars = sourceVars
        self.reading = reading
        self.formula = formula
    }
}

/// Balanced three-phase line, phase, and complex power.
///
/// One phase is solved as a wye. A delta load uses Z/3. A delta source uses line ÷ √3.
public enum ThreePhasePower {
    public static let formula = "P = √3 × V_LL × I_L × cos θ    |S| = √3 × V_LL × I_L    S = P + jQ"

    public static func solve(
        topology: ThreePhaseTopology,
        lineToLineVolts: Double,
        load: ComplexOhms,
        line: ComplexOhms = ComplexOhms(resistance: 0, reactance: 0)
    ) throws -> ThreePhasePowerResult {
        let sourceLine = try Positive.require(lineToLineVolts, name: "Line voltage")
        guard load.resistance.isFinite, load.reactance.isFinite else {
            throw CalcError.missing("Phase resistance and reactance")
        }
        guard line.resistance.isFinite, line.reactance.isFinite else {
            throw CalcError.missing("Line resistance and reactance")
        }
        guard load.resistance >= 0 else {
            throw CalcError.outOfRange("Phase resistance cannot be negative.")
        }
        guard line.resistance >= 0 else {
            throw CalcError.outOfRange("Line resistance cannot be negative. Put capacitance in the reactance.")
        }
        guard load.magnitude > 0 else {
            throw CalcError.outOfRange("Phase impedance cannot be a short. Enter resistance, reactance, or both.")
        }

        let sqrt3 = ThreePhaseTopology.sqrt3
        let zPhase = topology.loadIsWye ? load : load.scaled(by: 1.0 / 3.0)
        let zTotal = C(re: line.resistance + zPhase.resistance, im: line.reactance + zPhase.reactance)
        guard zTotal.mag > 0 else {
            throw CalcError.outOfRange("Line plus phase impedance is zero.")
        }

        let van = C(re: sourceLine / sqrt3, im: 0)
        let ia = van / zTotal
        let vLoadPhase = ia * C(re: zPhase.resistance, im: zPhase.reactance)
        let lineCurrent = ia.mag
        let loadLine = vLoadPhase.mag * sqrt3
        let theta = atan2(load.reactance, load.resistance)
        let watts = sqrt3 * loadLine * lineCurrent * cos(theta)
        let vars = sqrt3 * loadLine * lineCurrent * sin(theta)
        let voltAmps = sqrt3 * loadLine * lineCurrent
        let sourceComplex = van * ia.conj
        let lineLoss = 3 * lineCurrent * lineCurrent * line.resistance

        return ThreePhasePowerResult(
            topology: topology,
            sourceLineVolts: sourceLine,
            sourcePhaseVolts: topology.sourceIsWye ? sourceLine / sqrt3 : sourceLine,
            loadLineVolts: loadLine,
            loadPhaseVolts: topology.loadIsWye ? vLoadPhase.mag : loadLine,
            lineCurrent: lineCurrent,
            sourcePhaseCurrent: topology.sourceIsWye ? lineCurrent : lineCurrent / sqrt3,
            loadPhaseCurrent: topology.loadIsWye ? lineCurrent : lineCurrent / sqrt3,
            phaseAngleDegrees: theta * 180 / .pi,
            powerFactor: cos(theta),
            lagging: load.reactance >= 0,
            watts: watts,
            vars: vars,
            voltAmps: voltAmps,
            neutralAmps: 0,
            equivalentWye: zPhase,
            line: line,
            lineLossWatts: lineLoss,
            sourceWatts: 3 * sourceComplex.re,
            sourceVars: 3 * sourceComplex.im,
            reading: topology.reading,
            formula: formula
        )
    }
}

private struct C {
    var re: Double
    var im: Double

    var mag: Double { hypot(re, im) }
    var conj: C { C(re: re, im: -im) }

    static func + (a: C, b: C) -> C { C(re: a.re + b.re, im: a.im + b.im) }

    static func * (a: C, b: C) -> C {
        C(re: a.re * b.re - a.im * b.im, im: a.re * b.im + a.im * b.re)
    }

    static func / (a: C, b: C) -> C {
        let d = b.re * b.re + b.im * b.im
        return C(re: (a.re * b.re + a.im * b.im) / d, im: (a.im * b.re - a.re * b.im) / d)
    }
}
