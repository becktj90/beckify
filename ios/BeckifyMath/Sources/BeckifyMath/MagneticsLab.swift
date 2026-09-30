import Foundation

/// First-pass magnetic path for a coil on steel, with an optional air gap.
///
/// Linear permeability. Ampere-turns, flux, and reluctance follow the same
/// layout as volts, amps, and ohms. Not a saturation curve, a leakage model,
/// or a finite-element mesh.
public enum MagneticsLab {
    /// Permeability of free space, H/m.
    public static let mu0 = 4 * Double.pi * 1e-7

    /// Steel flux density where a constant µr usually stops being useful.
    public static let saturationHintTesla = 1.5

    public struct CoreLeg: Equatable, Sendable {
        public var steelLength: Double
        public var steelArea: Double
        public var gapLength: Double
        public var relativePermeability: Double
        public var stackingFactor: Double
        public var fringing: Double

        public init(
            steelLength: Double,
            steelArea: Double,
            gapLength: Double = 0,
            relativePermeability: Double,
            stackingFactor: Double = 1,
            fringing: Double = 1
        ) {
            self.steelLength = steelLength
            self.steelArea = steelArea
            self.gapLength = gapLength
            self.relativePermeability = relativePermeability
            self.stackingFactor = stackingFactor
            self.fringing = fringing
        }
    }

    public struct Drop: Equatable, Sendable {
        public var name: String
        public var isGap: Bool
        public var reluctance: Double
        public var flux: Double
        public var fluxDensity: Double
        public var intensity: Double
        public var mmf: Double
        public var effectiveArea: Double

        public init(
            name: String,
            isGap: Bool,
            reluctance: Double,
            flux: Double,
            fluxDensity: Double,
            intensity: Double,
            mmf: Double,
            effectiveArea: Double
        ) {
            self.name = name
            self.isGap = isGap
            self.reluctance = reluctance
            self.flux = flux
            self.fluxDensity = fluxDensity
            self.intensity = intensity
            self.mmf = mmf
            self.effectiveArea = effectiveArea
        }
    }

    public struct Solution: Equatable, Sendable {
        public var turns: Double
        public var current: Double
        /// ℱ = N I, ampere-turns.
        public var mmf: Double
        public var equivalentReluctance: Double
        /// Flux linking the coil.
        public var coilFlux: Double
        /// L = N² / ℜ.
        public var inductance: Double
        /// W = ½ L I².
        public var energy: Double
        public var drops: [Drop]
        /// Share of the loop ampere-turns that land on air. Independent of current.
        public var gapMMFFraction: Double
        public var leftFlux: Double?
        public var rightFlux: Double?
        public var warnings: [String]

        public init(
            turns: Double,
            current: Double,
            mmf: Double,
            equivalentReluctance: Double,
            coilFlux: Double,
            inductance: Double,
            energy: Double,
            drops: [Drop],
            gapMMFFraction: Double,
            leftFlux: Double?,
            rightFlux: Double?,
            warnings: [String]
        ) {
            self.turns = turns
            self.current = current
            self.mmf = mmf
            self.equivalentReluctance = equivalentReluctance
            self.coilFlux = coilFlux
            self.inductance = inductance
            self.energy = energy
            self.drops = drops
            self.gapMMFFraction = gapMMFFraction
            self.leftFlux = leftFlux
            self.rightFlux = rightFlux
            self.warnings = warnings
        }

        public func drop(named name: String) -> Drop? {
            drops.first { $0.name == name }
        }
    }

    public static func series(
        turns: Double,
        current: Double,
        steelLength: Double,
        steelArea: Double,
        relativePermeability: Double,
        gapLength: Double = 0,
        stackingFactor: Double = 1,
        fringing: Double = 1
    ) throws -> Solution {
        let leg = CoreLeg(
            steelLength: steelLength,
            steelArea: steelArea,
            gapLength: gapLength,
            relativePermeability: relativePermeability,
            stackingFactor: stackingFactor,
            fringing: fringing
        )
        return try solveSeries(turns: turns, current: current, leg: leg)
    }

    public static func threeLeg(
        turns: Double,
        current: Double,
        center: CoreLeg,
        left: CoreLeg,
        right: CoreLeg
    ) throws -> Solution {
        let n = try Positive.require(turns, name: "Turns")
        let i = try finite(current, name: "Current")
        let centerParts = try parts(of: center, steel: "Center steel", gap: "Center gap")
        let leftParts = try parts(of: left, steel: "Left steel", gap: "Left gap")
        let rightParts = try parts(of: right, steel: "Right steel", gap: "Right gap")

        let rCenter = centerParts.reluctance
        let rLeft = leftParts.reluctance
        let rRight = rightParts.reluctance
        let rParallel = 1 / (1 / rLeft + 1 / rRight)
        let rEq = rCenter + rParallel
        let mmf = n * i
        let flux = mmf / rEq
        let mmfParallel = flux * rParallel
        let fluxLeft = mmfParallel / rLeft
        let fluxRight = mmfParallel / rRight

        var drops: [Drop] = []
        drops += energized(centerParts, flux: flux)
        drops += energized(leftParts, flux: fluxLeft)
        drops += energized(rightParts, flux: fluxRight)

        let leftGapShare = (centerParts.gapReluctance + leftParts.gapReluctance) / (rCenter + rLeft)
        let rightGapShare = (centerParts.gapReluctance + rightParts.gapReluctance) / (rCenter + rRight)
        let gapShare = max(leftGapShare, rightGapShare)

        return assemble(
            turns: n,
            current: i,
            reluctance: rEq,
            flux: flux,
            drops: drops,
            gapShare: gapShare,
            leftFlux: fluxLeft,
            rightFlux: fluxRight,
            fringing: max(center.fringing, max(left.fringing, right.fringing))
        )
    }

    // MARK: - Machine checks on a known B

    public struct TransformerLink: Equatable, Sendable {
        public var turnsRatio: Double
        public var sharedFlux: Double
        /// Peak flux that would match a sine primary voltage. Nil when volts or hertz are omitted.
        public var acPeakFlux: Double?
        public var note: String

        public init(turnsRatio: Double, sharedFlux: Double, acPeakFlux: Double?, note: String) {
            self.turnsRatio = turnsRatio
            self.sharedFlux = sharedFlux
            self.acPeakFlux = acPeakFlux
            self.note = note
        }
    }

    /// Ideal shared-flux link. DC flux from the coil current is not an AC voltage.
    public static func transformerLink(
        sharedFlux: Double,
        primaryTurns: Double,
        secondaryTurns: Double,
        primaryRMS: Double? = nil,
        frequencyHz: Double? = nil
    ) throws -> TransformerLink {
        let n1 = try Positive.require(primaryTurns, name: "Primary turns")
        let n2 = try Positive.require(secondaryTurns, name: "Secondary turns")
        let flux = try finite(sharedFlux, name: "Flux")
        let ratio = n2 / n1
        var acPeak: Double?
        var note = "Both windings link this same core flux. A steady flux does not produce voltage — the flux has to change."
        if let primaryRMS, let frequencyHz {
            let volts = try Positive.require(primaryRMS, name: "Primary voltage")
            let hertz = try Positive.require(frequencyHz, name: "Frequency")
            // Vrms ≈ 4.44 f N Φpeak for a sine and an ideal winding.
            let peak = volts / (4.44 * hertz * n1)
            acPeak = peak
            note = "Turns ratio is N₂/N₁. The AC peak is the sine flux that matches the primary voltage (4.44 f N Φ). It is not the DC flux from a holding current. Ideal winding: no resistance and no leakage."
            if abs(flux) > 0, abs(peak) > 0 {
                let compare = abs(flux) / abs(peak)
                if compare > 1.5 {
                    note += " The DC flux is larger than that AC peak — do not treat the holding current as the AC design point."
                }
            }
        }
        return TransformerLink(turnsRatio: ratio, sharedFlux: flux, acPeakFlux: acPeak, note: note)
    }

    public struct ConductorForce: Equatable, Sendable {
        public var newtons: Double
        public var note: String

        public init(newtons: Double, note: String) {
            self.newtons = newtons
            self.note = note
        }
    }

    /// Force on one straight conductor, |F| = |I| ℓ B |sin θ|. θ is the angle between the wire and B.
    public static func conductorForce(
        current: Double,
        length: Double,
        fluxDensity: Double,
        angleDegrees: Double = 90
    ) throws -> ConductorForce {
        let amps = try finite(current, name: "Conductor current")
        let active = try Positive.require(length, name: "Active length")
        let b = try finite(fluxDensity, name: "Flux density")
        let angle = try finite(angleDegrees, name: "Angle")
        let sine = sin(angle * .pi / 180)
        let force = abs(amps) * active * abs(b) * abs(sine)
        let note: String
        if abs(sine) < 1e-6 {
            note = "The wire is parallel to the field, so this pass shows no force."
        } else if abs(abs(angleDegrees) - 90) < 0.5 || abs(abs(angleDegrees) - 270) < 0.5 {
            note = "Perpendicular wire in the gap. Force is I × B on that length — one conductor, not a whole machine torque."
        } else {
            note = "Angle is between the wire and B. This is one conductor, not shaft torque."
        }
        return ConductorForce(newtons: force, note: note)
    }

    public struct MotionalEMF: Equatable, Sendable {
        public var volts: Double
        public var note: String

        public init(volts: Double, note: String) {
            self.volts = volts
            self.note = note
        }
    }

    /// Motional emf on one straight conductor, |e| = B ℓ v |sin θ|. θ is the angle between velocity and B.
    public static func motionalEMF(
        fluxDensity: Double,
        length: Double,
        speed: Double,
        angleDegrees: Double = 90
    ) throws -> MotionalEMF {
        let b = try finite(fluxDensity, name: "Flux density")
        let active = try Positive.require(length, name: "Active length")
        let motion = try finite(speed, name: "Speed")
        let angle = try finite(angleDegrees, name: "Angle")
        let sine = sin(angle * .pi / 180)
        let volts = abs(b) * active * abs(motion) * abs(sine)
        let note: String
        if abs(sine) < 1e-6 {
            note = "Motion is along the field, so this pass shows no induced emf."
        } else {
            note = "One conductor cutting the gap field. A machine winding is many of these, not this single length."
        }
        return MotionalEMF(volts: volts, note: note)
    }

    // MARK: - Internals

    private struct Parts {
        var steel: Piece
        var gap: Piece?
        var reluctance: Double { steel.reluctance + (gap?.reluctance ?? 0) }
        var gapReluctance: Double { gap?.reluctance ?? 0 }
    }

    private struct Piece {
        var name: String
        var isGap: Bool
        var length: Double
        var area: Double
        var mu: Double
        var reluctance: Double
    }

    private static func solveSeries(turns: Double, current: Double, leg: CoreLeg) throws -> Solution {
        let n = try Positive.require(turns, name: "Turns")
        let i = try finite(current, name: "Current")
        let built = try parts(of: leg, steel: "Steel", gap: "Air gap")
        let rEq = built.reluctance
        let mmf = n * i
        let flux = mmf / rEq
        let drops = energized(built, flux: flux)
        let gapShare = built.gapReluctance / rEq
        return assemble(
            turns: n,
            current: i,
            reluctance: rEq,
            flux: flux,
            drops: drops,
            gapShare: gapShare,
            leftFlux: nil,
            rightFlux: nil,
            fringing: leg.fringing
        )
    }

    private static func parts(of leg: CoreLeg, steel steelName: String, gap gapName: String) throws -> Parts {
        let length = try Positive.require(leg.steelLength, name: "Steel length")
        let area = try Positive.require(leg.steelArea, name: "Steel area")
        let muR = try Positive.require(leg.relativePermeability, name: "Relative permeability")
        let stack = try Positive.require(leg.stackingFactor, name: "Stacking factor")
        guard stack <= 1 else {
            throw CalcError.outOfRange("Stacking factor cannot exceed 1. It is the share of the stack that is actually steel.")
        }
        let fringe = try Positive.require(leg.fringing, name: "Fringing")
        guard leg.gapLength.isFinite, leg.gapLength >= 0 else {
            throw CalcError.outOfRange("Gap length cannot be negative.")
        }
        let steel = Piece(
            name: steelName,
            isGap: false,
            length: length,
            area: area * stack,
            mu: mu0 * muR,
            reluctance: length / (mu0 * muR * area * stack)
        )
        let gap: Piece?
        if leg.gapLength > 0 {
            let gapArea = area * fringe
            gap = Piece(
                name: gapName,
                isGap: true,
                length: leg.gapLength,
                area: gapArea,
                mu: mu0,
                reluctance: leg.gapLength / (mu0 * gapArea)
            )
        } else {
            gap = nil
        }
        return Parts(steel: steel, gap: gap)
    }

    private static func energized(_ parts: Parts, flux: Double) -> [Drop] {
        var drops = [drop(parts.steel, flux: flux)]
        if let gap = parts.gap {
            drops.append(drop(gap, flux: flux))
        }
        return drops
    }

    private static func drop(_ piece: Piece, flux: Double) -> Drop {
        let b = flux / piece.area
        let h = b / piece.mu
        return Drop(
            name: piece.name,
            isGap: piece.isGap,
            reluctance: piece.reluctance,
            flux: flux,
            fluxDensity: b,
            intensity: h,
            mmf: h * piece.length,
            effectiveArea: piece.area
        )
    }

    private static func assemble(
        turns: Double,
        current: Double,
        reluctance: Double,
        flux: Double,
        drops: [Drop],
        gapShare: Double,
        leftFlux: Double?,
        rightFlux: Double?,
        fringing: Double
    ) -> Solution {
        let inductance = turns * turns / reluctance
        let energy = 0.5 * inductance * current * current
        var warnings: [String] = []
        let steelB = drops.filter { !$0.isGap }.map { abs($0.fluxDensity) }.max() ?? 0
        if steelB >= 2 {
            warnings.append("Steel is past about 2 T. A constant µr is not a useful model here — use the maker’s curve.")
        } else if steelB >= saturationHintTesla {
            warnings.append("Steel is past about 1.5 T. Constant µr overstates flux once the steel saturates.")
        }
        if gapShare >= 0.7 {
            warnings.append("Most of the ampere-turns land on the air gap. The steel path is the easy part.")
        }
        if fringing < 1 {
            warnings.append("Fringing below 1 shrinks the gap face. Use 1 when you are ignoring bulge.")
        }
        return Solution(
            turns: turns,
            current: current,
            mmf: turns * current,
            equivalentReluctance: reluctance,
            coilFlux: flux,
            inductance: inductance,
            energy: energy,
            drops: drops,
            gapMMFFraction: gapShare,
            leftFlux: leftFlux,
            rightFlux: rightFlux,
            warnings: warnings
        )
    }

    private static func finite(_ value: Double, name: String) throws -> Double {
        guard value.isFinite else { throw CalcError.missing(name) }
        return value
    }
}
