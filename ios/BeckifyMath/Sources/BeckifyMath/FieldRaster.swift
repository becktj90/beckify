import Foundation

/// A drawable cross-section of a field solve: B, field-line potential, induced E per unit current ramp, and what
/// is where. Row 0 is the bottom of the picture. Used by the field explorer on the solenoid and magnetic tools.
public struct FieldRaster: Equatable, Sendable {
    public enum Kind: String, Sendable { case solenoid, core }

    public struct Probe: Equatable, Sendable {
        public var xM: Double
        public var yM: Double
        public var bx: Double
        public var by: Double
        public var bMagnitude: Double
        /// Induced E, V/m, for the ramp given to `probe`. Per metre of depth for a core.
        public var inducedE: Double
        /// H in the material under the probe, A/m.
        public var h: Double
        public var material: String
    }

    public var kind: Kind
    public var columns: Int
    public var rows: Int
    public var widthM: Double
    public var heightM: Double
    public var bx: [Double]
    public var by: [Double]
    public var bMag: [Double]
    public var potential: [Double]
    /// Induced E per A/s of current ramp, V/m.
    public var ePerRamp: [Double]
    /// 0 air, 1 steel, 2 coil, 3 gap.
    public var tag: [UInt8]
    public var maxB: Double
    public var relativePermeability: Double
    public var currentAmps: Double

    public static let air: UInt8 = 0
    public static let steel: UInt8 = 1
    public static let coil: UInt8 = 2
    public static let gap: UInt8 = 3

    public func index(column: Int, row: Int) -> Int { row * columns + column }

    /// Largest |E| per A/s, for scaling the colour.
    public var maxEPerRamp: Double { ePerRamp.reduce(0) { max($0, abs($1)) } }

    /// Position of a cell centre in metres from the lower-left corner.
    public func position(column: Int, row: Int) -> (x: Double, y: Double) {
        (widthM * Double(column) / Double(columns - 1), heightM * Double(row) / Double(rows - 1))
    }

    /// Bilinear sample at a position in metres from the lower-left corner. Nil outside the picture.
    public func probe(xM: Double, yM: Double, didt: Double) -> Probe? {
        guard xM >= 0, yM >= 0, xM <= widthM, yM <= heightM, columns > 1, rows > 1 else { return nil }
        let fx = xM / widthM * Double(columns - 1)
        let fy = yM / heightM * Double(rows - 1)
        let c0 = min(Int(fx), columns - 2)
        let r0 = min(Int(fy), rows - 2)
        let tx = fx - Double(c0)
        let ty = fy - Double(r0)
        func mix(_ values: [Double]) -> Double {
            let a = values[index(column: c0, row: r0)]
            let b = values[index(column: c0 + 1, row: r0)]
            let c = values[index(column: c0, row: r0 + 1)]
            let d = values[index(column: c0 + 1, row: r0 + 1)]
            return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty
        }
        let nearC = min(max(Int(fx.rounded()), 0), columns - 1)
        let nearR = min(max(Int(fy.rounded()), 0), rows - 1)
        let tagHere = tag[index(column: nearC, row: nearR)]
        let bxHere = mix(bx)
        let byHere = mix(by)
        let magnitude = hypot(bxHere, byHere)
        let mu0 = 4 * Double.pi * 1e-7
        let permeability = tagHere == Self.steel ? mu0 * relativePermeability : mu0
        let material: String
        switch tagHere {
        case Self.steel: material = "Steel"
        case Self.coil: material = "Winding"
        case Self.gap: material = "Air gap"
        default: material = "Air"
        }
        return Probe(
            xM: xM, yM: yM, bx: bxHere, by: byHere, bMagnitude: magnitude,
            inducedE: mix(ePerRamp) * didt, h: magnitude / permeability, material: material
        )
    }

    // MARK: Builders

    /// Full cross-section of a solenoid through its axis: ρ mirrored about the axis, z up the page.
    public static func solenoid(
        lengthM: Double, innerRadiusM: Double, buildM: Double, turns: Int, currentAmps: Double,
        relativePermeability: Double = 1
    ) -> FieldRaster? {
        guard let map = SolenoidFieldMap.compute(
            lengthM: lengthM, innerRadiusM: innerRadiusM, buildM: buildM, turns: turns, currentAmps: currentAmps
        ) else { return nil }
        let half = map.columns - 1
        let columns = half * 2 + 1
        let rows = map.rows
        var bx = [Double](repeating: 0, count: columns * rows)
        var by = bx
        var mag = bx
        var potential = bx
        var ePerRamp = bx
        var tag = [UInt8](repeating: 0, count: columns * rows)
        let outer = innerRadiusM + max(buildM, innerRadiusM * 0.02)
        for row in 0..<rows {
            for column in 0..<columns {
                let side = column - half               // −half…half, 0 on the axis
                let src = abs(side)
                let s = row * map.columns + src
                let sign: Double = side < 0 ? -1 : 1
                let i = row * columns + column
                bx[i] = map.bRho[s] * sign
                by[i] = map.bZ[s]
                mag[i] = hypot(bx[i], by[i])
                potential[i] = map.psi[s]
                // E_φ points into the page on one side of the axis and out of it on the other.
                ePerRamp[i] = -map.aPhiPerAmp[s] * sign
                let position = map.position(column: src, row: row)
                if position.rho >= innerRadiusM, position.rho <= outer, abs(position.z) <= lengthM / 2 { tag[i] = coil }
            }
        }
        return FieldRaster(
            kind: .solenoid, columns: columns, rows: rows,
            widthM: 2 * map.rhoMax, heightM: 2 * map.zMax,
            bx: bx, by: by, bMag: mag, potential: potential, ePerRamp: ePerRamp, tag: tag,
            maxB: map.maxB, relativePermeability: relativePermeability, currentAmps: currentAmps
        )
    }

    /// Cross-section of a rectangular core with its winding and gap.
    public static func core(
        ampTurns: Double, legThicknessM: Double, pathLengthM: Double, gapM: Double,
        relativePermeability: Double, currentAmps: Double
    ) -> FieldRaster? {
        guard let map = CoreFieldMap.compute(
            ampTurns: ampTurns, legThicknessM: legThicknessM, pathLengthM: pathLengthM,
            gapM: gapM, relativePermeability: relativePermeability
        ) else { return nil }
        // Induced E per A/s of one-turn current needs A_z per ampere-turn. At zero excitation the field is zero but that
        // ratio is not, so take it from a unit solve.
        let unit = ampTurns == 0 ? CoreFieldMap.compute(
            ampTurns: 1, legThicknessM: legThicknessM, pathLengthM: pathLengthM,
            gapM: gapM, relativePermeability: relativePermeability
        ) : nil
        var tag = [UInt8](repeating: 0, count: map.columns * map.rows)
        var ePerRamp = [Double](repeating: 0, count: map.columns * map.rows)
        var mag = tag.map { _ in 0.0 }
        for i in 0..<tag.count {
            switch map.region[i] {
            case .steel: tag[i] = steel
            case .coilPlus, .coilMinus: tag[i] = coil
            case .gap: tag[i] = gap
            case .air: tag[i] = air
            }
            mag[i] = hypot(map.bx[i], map.by[i])
            ePerRamp[i] = ampTurns != 0 ? -map.az[i] / ampTurns : -(unit?.az[i] ?? 0)
        }
        return FieldRaster(
            kind: .core, columns: map.columns, rows: map.rows,
            widthM: map.cell * Double(map.columns - 1), heightM: map.cell * Double(map.rows - 1),
            bx: map.bx, by: map.by, bMag: mag, potential: map.az, ePerRamp: ePerRamp, tag: tag,
            maxB: map.maxB, relativePermeability: relativePermeability, currentAmps: currentAmps
        )
    }
}
