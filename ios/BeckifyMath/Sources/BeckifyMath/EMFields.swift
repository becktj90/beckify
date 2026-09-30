import Foundation

/// Induced emf, point-charge fields, Lorentz force, and a small vector check.
/// Closed-form only — not a particle tracker and not a symbolic solver.
public enum EMFields {
    public static let mu0 = MagneticsLab.mu0
    /// Coulomb constant, N·m²/C².
    public static let coulombConstant = 8.9875517923e9

    // MARK: - Faraday

    public struct InducedEMF: Equatable, Sendable {
        /// dΦ/dt for one turn, Wb/s.
        public var fluxRate: Double
        /// ε = −N dΦ/dt.
        public var emf: Double
        /// Viewed with positive B toward you.
        public var circulation: String
        public var note: String

        public init(fluxRate: Double, emf: Double, circulation: String, note: String) {
            self.fluxRate = fluxRate
            self.emf = emf
            self.circulation = circulation
            self.note = note
        }
    }

    public static func faradayFluxRate(turns: Double, fluxRate: Double) throws -> InducedEMF {
        let n = try Positive.require(turns, name: "Turns")
        let rate = try finite(fluxRate, name: "Flux rate")
        return induced(turns: n, fluxRate: rate)
    }

    /// Uniform B perpendicular to a flat area. ε = −N A dB/dt.
    public static func faradayDensityRate(
        turns: Double,
        area: Double,
        densityRate: Double
    ) throws -> InducedEMF {
        let n = try Positive.require(turns, name: "Turns")
        let a = try Positive.require(area, name: "Area")
        let rate = try finite(densityRate, name: "dB/dt")
        return induced(turns: n, fluxRate: a * rate)
    }

    /// Two flux-density readings over a time span. The rate is the average (B₂ − B₁) / Δt.
    public static func faradayLinearDensity(
        turns: Double,
        area: Double,
        startDensity: Double,
        endDensity: Double,
        seconds: Double
    ) throws -> InducedEMF {
        let n = try Positive.require(turns, name: "Turns")
        let a = try Positive.require(area, name: "Area")
        let b0 = try finite(startDensity, name: "Starting B")
        let b1 = try finite(endDensity, name: "Ending B")
        let dt = try Positive.require(seconds, name: "Time span")
        return induced(turns: n, fluxRate: a * (b1 - b0) / dt)
    }

    private static func induced(turns: Double, fluxRate: Double) -> InducedEMF {
        let emf = -turns * fluxRate
        let circulation: String
        let note: String
        if abs(emf) < 1e-15 {
            circulation = "none"
            note = "Flux through the loop is steady. Induced emf is zero."
        } else if fluxRate > 0 {
            circulation = "clockwise"
            note = "Flux toward you is rising. Induced current on this view is clockwise so its own field points away from you."
        } else {
            circulation = "counterclockwise"
            note = "Flux toward you is falling. Induced current on this view is counterclockwise so its own field points toward you."
        }
        return InducedEMF(fluxRate: fluxRate, emf: emf, circulation: circulation, note: note)
    }

    // MARK: - Point charges

    public struct PointCharge: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var z: Double
        public var coulombs: Double

        public init(x: Double, y: Double, z: Double, coulombs: Double) {
            self.x = x
            self.y = y
            self.z = z
            self.coulombs = coulombs
        }
    }

    public struct ChargeField: Equatable, Sendable {
        public var electricField: FieldVector
        public var magnitude: Double
        public var force: FieldVector?
        public var nearEquilibrium: Bool
        public var contributions: [FieldVector]

        public init(
            electricField: FieldVector,
            magnitude: Double,
            force: FieldVector?,
            nearEquilibrium: Bool,
            contributions: [FieldVector]
        ) {
            self.electricField = electricField
            self.magnitude = magnitude
            self.force = force
            self.nearEquilibrium = nearEquilibrium
            self.contributions = contributions
        }
    }

    /// Superposition of point charges. The test point cannot sit on a charge.
    public static func pointChargeField(
        charges: [PointCharge],
        at point: FieldVector,
        testCharge: Double? = nil
    ) throws -> ChargeField {
        guard !charges.isEmpty else {
            throw CalcError.outOfRange("Add at least one charge.")
        }
        var sum = FieldVector(x: 0, y: 0, z: 0)
        var parts: [FieldVector] = []
        var largest = 0.0
        for charge in charges {
            let dx = try finite(point.x - charge.x, name: "Position")
            let dy = try finite(point.y - charge.y, name: "Position")
            let dz = try finite(point.z - charge.z, name: "Position")
            let q = try finite(charge.coulombs, name: "Charge")
            let r2 = dx * dx + dy * dy + dz * dz
            if r2 < 1e-12 {
                throw CalcError.outOfRange("The test point sits on a charge. Move it off the charge.")
            }
            let r = r2.squareRoot()
            let scale = coulombConstant * q / (r2 * r)
            let part = FieldVector(x: scale * dx, y: scale * dy, z: scale * dz)
            parts.append(part)
            largest = max(largest, part.magnitude)
            sum = FieldVector(x: sum.x + part.x, y: sum.y + part.y, z: sum.z + part.z)
        }
        let magnitude = sum.magnitude
        let equilibrium = charges.count >= 2 && magnitude <= max(1e-6, 0.02 * largest)
        let force: FieldVector?
        if let testCharge {
            let q = try finite(testCharge, name: "Test charge")
            force = FieldVector(x: q * sum.x, y: q * sum.y, z: q * sum.z)
        } else {
            force = nil
        }
        return ChargeField(
            electricField: sum,
            magnitude: magnitude,
            force: force,
            nearEquilibrium: equilibrium,
            contributions: parts
        )
    }

    // MARK: - Lorentz

    public struct LorentzResult: Equatable, Sendable {
        public var force: FieldVector
        public var electricTerm: FieldVector
        public var magneticTerm: FieldVector
        public var magneticDominant: Bool
        public var electricDominant: Bool
        /// Cyclotron radius when the magnetic term owns the force and a mass is given.
        public var radius: Double?
        public var path: String
        public var note: String

        public init(
            force: FieldVector,
            electricTerm: FieldVector,
            magneticTerm: FieldVector,
            magneticDominant: Bool,
            electricDominant: Bool,
            radius: Double?,
            path: String,
            note: String
        ) {
            self.force = force
            self.electricTerm = electricTerm
            self.magneticTerm = magneticTerm
            self.magneticDominant = magneticDominant
            self.electricDominant = electricDominant
            self.radius = radius
            self.path = path
            self.note = note
        }
    }

    /// F = q (E + v × B). Radius is m v⊥ / (|q| B) only when E is negligible.
    public static func lorentz(
        charge: Double,
        electric: FieldVector,
        velocity: FieldVector,
        magnetic: FieldVector,
        mass: Double? = nil
    ) throws -> LorentzResult {
        let q = try finite(charge, name: "Charge")
        let e = try vector(electric, name: "Electric field")
        let v = try vector(velocity, name: "Velocity")
        let b = try vector(magnetic, name: "Magnetic field")
        let cross = FieldVector.cross(v, b)
        let electricTerm = FieldVector(x: q * e.x, y: q * e.y, z: q * e.z)
        let magneticTerm = FieldVector(x: q * cross.x, y: q * cross.y, z: q * cross.z)
        let force = FieldVector(
            x: electricTerm.x + magneticTerm.x,
            y: electricTerm.y + magneticTerm.y,
            z: electricTerm.z + magneticTerm.z
        )
        let eMag = e.magnitude
        let vbMag = cross.magnitude
        let magneticDominant = vbMag > 0 && vbMag >= 3 * eMag
        let electricDominant = eMag >= 3 * vbMag
        var radius: Double?
        if let mass {
            let m = try Positive.require(mass, name: "Mass")
            if magneticDominant, eMag <= 0.05 * vbMag, abs(q) > 0, b.magnitude > 0 {
                let vPerp = vbMag / b.magnitude
                if vPerp > 0 {
                    radius = m * vPerp / (abs(q) * b.magnitude)
                }
            }
        }
        let path: String
        let note: String
        if force.magnitude < 1e-18 {
            path = "straight"
            note = "Net force is about zero. The charge keeps its velocity."
        } else if magneticDominant && radius != nil {
            path = "curves"
            note = "The magnetic term sets the force. The arc radius is m v⊥ / (|q| B) while E stays negligible. This is not a tracked path."
        } else if magneticDominant {
            path = "curves"
            note = "The magnetic term sets the force, so the charge curves. Enter a mass to read the arc radius. This is not a tracked path."
        } else if electricDominant {
            path = "straight"
            note = "The electric term sets the force, so the charge accelerates along E. The sketch is the initial push, not a full flight."
        } else {
            path = "mixed"
            note = "Electric and magnetic terms are the same order. The first step is the net force; a real path needs a tracker this pass does not run."
        }
        return LorentzResult(
            force: force,
            electricTerm: electricTerm,
            magneticTerm: magneticTerm,
            magneticDominant: magneticDominant,
            electricDominant: electricDominant,
            radius: radius,
            path: path,
            note: note
        )
    }

    // MARK: - Vectors

    public struct Cylindrical: Equatable, Sendable {
        public var rho: Double
        public var phiDegrees: Double
        public var z: Double

        public init(rho: Double, phiDegrees: Double, z: Double) {
            self.rho = rho
            self.phiDegrees = phiDegrees
            self.z = z
        }
    }

    public struct Spherical: Equatable, Sendable {
        public var r: Double
        public var thetaDegrees: Double
        public var phiDegrees: Double

        public init(r: Double, thetaDegrees: Double, phiDegrees: Double) {
            self.r = r
            self.thetaDegrees = thetaDegrees
            self.phiDegrees = phiDegrees
        }
    }

    public static func cylindrical(from cartesian: FieldVector) throws -> Cylindrical {
        let v = try vector(cartesian, name: "Vector")
        let rho = (v.x * v.x + v.y * v.y).squareRoot()
        let phi = atan2(v.y, v.x) * 180 / .pi
        return Cylindrical(rho: rho, phiDegrees: phi, z: v.z)
    }

    public static func cartesian(fromCylindrical rho: Double, phiDegrees: Double, z: Double) throws -> FieldVector {
        let radius = try finite(rho, name: "Rho")
        guard radius >= 0 else { throw CalcError.outOfRange("Rho cannot be negative.") }
        let phi = try finite(phiDegrees, name: "Phi") * .pi / 180
        let height = try finite(z, name: "Z")
        return FieldVector(x: radius * cos(phi), y: radius * sin(phi), z: height)
    }

    public static func spherical(from cartesian: FieldVector) throws -> Spherical {
        let v = try vector(cartesian, name: "Vector")
        let r = v.magnitude
        let theta = r == 0 ? 0 : acos(max(-1, min(1, v.z / r))) * 180 / .pi
        let phi = atan2(v.y, v.x) * 180 / .pi
        return Spherical(r: r, thetaDegrees: theta, phiDegrees: phi)
    }

    public static func cartesian(fromSpherical r: Double, thetaDegrees: Double, phiDegrees: Double) throws -> FieldVector {
        let radius = try finite(r, name: "R")
        guard radius >= 0 else { throw CalcError.outOfRange("R cannot be negative.") }
        let theta = try finite(thetaDegrees, name: "Theta") * .pi / 180
        let phi = try finite(phiDegrees, name: "Phi") * .pi / 180
        return FieldVector(
            x: radius * sin(theta) * cos(phi),
            y: radius * sin(theta) * sin(phi),
            z: radius * cos(theta)
        )
    }

    public struct VectorProducts: Equatable, Sendable {
        public var dot: Double
        public var cross: FieldVector
        public var projection: FieldVector
        public var unitA: FieldVector?
        public var unitB: FieldVector?

        public init(
            dot: Double,
            cross: FieldVector,
            projection: FieldVector,
            unitA: FieldVector?,
            unitB: FieldVector?
        ) {
            self.dot = dot
            self.cross = cross
            self.projection = projection
            self.unitA = unitA
            self.unitB = unitB
        }
    }

    /// Dot, cross, projection of A onto B, and unit vectors. A zero vector has no unit vector.
    public static func products(a: FieldVector, b: FieldVector) throws -> VectorProducts {
        let left = try vector(a, name: "Vector A")
        let right = try vector(b, name: "Vector B")
        return VectorProducts(
            dot: FieldVector.dot(left, right),
            cross: FieldVector.cross(left, right),
            projection: FieldVector.project(left, onto: right),
            unitA: FieldVector.unit(left),
            unitB: FieldVector.unit(right)
        )
    }

    public enum SampleField: String, CaseIterable, Sendable {
        case uniform
        case spreading
        case swirl
        case saddle

        public var title: String {
            switch self {
            case .uniform: return "Uniform"
            case .spreading: return "Spreading"
            case .swirl: return "Swirl"
            case .saddle: return "Saddle"
            }
        }

        /// Constant divergence of these canned fields.
        public var divergence: Double {
            switch self {
            case .uniform: return 0
            case .spreading: return 3
            case .swirl: return 0
            case .saddle: return 0
            }
        }

        public var curl: FieldVector {
            switch self {
            case .uniform, .spreading, .saddle:
                return FieldVector(x: 0, y: 0, z: 0)
            case .swirl:
                return FieldVector(x: 0, y: 0, z: 2)
            }
        }

        public var circulationNote: String {
            switch self {
            case .uniform, .spreading, .saddle:
                return "Curl is zero here, so a small loop picks up no circulation."
            case .swirl:
                return "Curl is along z. A loop around that axis picks up circulation."
            }
        }

        public var fluxNote: String {
            switch self {
            case .uniform, .swirl, .saddle:
                return "Divergence is zero, so a small box has no net flux out."
            case .spreading:
                return "Divergence is 3. Flux leaves a small box."
            }
        }

        public func value(at point: FieldVector) -> FieldVector {
            switch self {
            case .uniform:
                return FieldVector(x: 3, y: 0, z: 0)
            case .spreading:
                return FieldVector(x: point.x, y: point.y, z: point.z)
            case .swirl:
                return FieldVector(x: -point.y, y: point.x, z: 0)
            case .saddle:
                return FieldVector(x: point.x, y: -point.y, z: 0)
            }
        }
    }

    public struct SampleProbe: Equatable, Sendable {
        public var value: FieldVector
        public var divergence: Double
        public var curl: FieldVector
        public var circulationNote: String
        public var fluxNote: String

        public init(
            value: FieldVector,
            divergence: Double,
            curl: FieldVector,
            circulationNote: String,
            fluxNote: String
        ) {
            self.value = value
            self.divergence = divergence
            self.curl = curl
            self.circulationNote = circulationNote
            self.fluxNote = fluxNote
        }
    }

    public static func probe(field: SampleField, at point: FieldVector) throws -> SampleProbe {
        let p = try vector(point, name: "Point")
        return SampleProbe(
            value: field.value(at: p),
            divergence: field.divergence,
            curl: field.curl,
            circulationNote: field.circulationNote,
            fluxNote: field.fluxNote
        )
    }

    private static func vector(_ value: FieldVector, name: String) throws -> FieldVector {
        guard value.x.isFinite, value.y.isFinite, value.z.isFinite else {
            throw CalcError.missing(name)
        }
        return value
    }

    private static func finite(_ value: Double, name: String) throws -> Double {
        guard value.isFinite else { throw CalcError.missing(name) }
        return value
    }
}

public struct FieldVector: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public var magnitude: Double {
        (x * x + y * y + z * z).squareRoot()
    }

    public static func dot(_ a: FieldVector, _ b: FieldVector) -> Double {
        a.x * b.x + a.y * b.y + a.z * b.z
    }

    public static func cross(_ a: FieldVector, _ b: FieldVector) -> FieldVector {
        FieldVector(
            x: a.y * b.z - a.z * b.y,
            y: a.z * b.x - a.x * b.z,
            z: a.x * b.y - a.y * b.x
        )
    }

    public static func unit(_ value: FieldVector) -> FieldVector? {
        let mag = value.magnitude
        guard mag > 0, mag.isFinite else { return nil }
        return FieldVector(x: value.x / mag, y: value.y / mag, z: value.z / mag)
    }

    /// Projection of `a` onto `b`. Zero when `b` is zero.
    public static func project(_ a: FieldVector, onto b: FieldVector) -> FieldVector {
        let denom = dot(b, b)
        guard denom > 0 else { return FieldVector(x: 0, y: 0, z: 0) }
        let scale = dot(a, b) / denom
        return FieldVector(x: scale * b.x, y: scale * b.y, z: scale * b.z)
    }
}
