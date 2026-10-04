import Foundation

// MARK: - Elliptic integrals

/// Complete elliptic integrals of the first and second kind by the arithmetic–geometric mean.
/// `m` is the parameter k², valid for 0 ≤ m < 1.
public enum EllipticIntegrals {
    public static func kAndE(m: Double) -> (k: Double, e: Double) {
        let clamped = min(max(m, 0), 1 - 1e-15)
        var a = 1.0
        var b = (1 - clamped).squareRoot()
        var c = clamped.squareRoot()
        var sum = 0.5 * c * c
        var power = 0.5
        for _ in 0..<40 {
            let next = (a + b) / 2
            c = (a - b) / 2
            b = (a * b).squareRoot()
            a = next
            power *= 2
            sum += power * c * c
            if abs(c) < 1e-16 { break }
        }
        let k = Double.pi / (2 * a)
        return (k, k * (1 - sum))
    }
}

// MARK: - Contours

/// Marching squares on a regular grid. Coordinates are in grid units: x = column, y = row.
public enum FieldContours {
    public struct Segment: Equatable, Sendable {
        public var x0: Double
        public var y0: Double
        public var x1: Double
        public var y1: Double
    }

    /// Evenly spaced levels strictly between `low` and `high`.
    public static func levels(low: Double, high: Double, count: Int) -> [Double] {
        guard count > 0, high > low else { return [] }
        return (1...count).map { low + (high - low) * Double($0) / Double(count + 1) }
    }

    public static func segments(values: [Double], columns: Int, rows: Int, level: Double) -> [Segment] {
        guard columns > 1, rows > 1, values.count == columns * rows else { return [] }
        var out: [Segment] = []
        func v(_ x: Int, _ y: Int) -> Double { values[y * columns + x] }
        func cross(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int) -> (Double, Double) {
            let a = v(x0, y0)
            let b = v(x1, y1)
            let t = (b - a) == 0 ? 0.5 : (level - a) / (b - a)
            return (Double(x0) + (Double(x1) - Double(x0)) * t, Double(y0) + (Double(y1) - Double(y0)) * t)
        }
        for y in 0..<(rows - 1) {
            for x in 0..<(columns - 1) {
                let a = v(x, y), b = v(x + 1, y), c = v(x + 1, y + 1), d = v(x, y + 1)
                guard a.isFinite, b.isFinite, c.isFinite, d.isFinite else { continue }
                var index = 0
                if a > level { index |= 1 }
                if b > level { index |= 2 }
                if c > level { index |= 4 }
                if d > level { index |= 8 }
                if index == 0 || index == 15 { continue }
                // Edge midpoints: bottom (a-b), right (b-c), top (d-c), left (a-d).
                let bottom = cross(x, y, x + 1, y)
                let right = cross(x + 1, y, x + 1, y + 1)
                let top = cross(x, y + 1, x + 1, y + 1)
                let left = cross(x, y, x, y + 1)
                func add(_ p: (Double, Double), _ q: (Double, Double)) {
                    out.append(Segment(x0: p.0, y0: p.1, x1: q.0, y1: q.1))
                }
                switch index {
                case 1, 14: add(left, bottom)
                case 2, 13: add(bottom, right)
                case 3, 12: add(left, right)
                case 4, 11: add(right, top)
                case 6, 9: add(bottom, top)
                case 7, 8: add(left, top)
                case 5:
                    let centre = (a + b + c + d) / 4
                    if centre > level { add(left, top); add(bottom, right) } else { add(left, bottom); add(right, top) }
                case 10:
                    let centre = (a + b + c + d) / 4
                    if centre > level { add(left, bottom); add(right, top) } else { add(left, top); add(bottom, right) }
                default: break
                }
            }
        }
        return out
    }
}

// MARK: - Solenoid: exact field of a loop sum

/// Field of a solenoid winding modeled as a stack of circular current filaments.
/// Exact for each filament (elliptic integrals), so the winding's own field is right near the wire and at the ends.
/// An iron core is not modeled here: this is the air-core field. A core changes the shape and raises B inside it.
public struct SolenoidFieldMap: Equatable, Sendable {
    public struct Winding: Equatable, Sendable {
        /// Axial position of each filament from the coil centre, metres.
        public var z: [Double]
        /// Radius of each filament, metres.
        public var radius: [Double]
        /// Turns each filament stands for.
        public var turnsEach: Double
    }

    public var winding: Winding
    public var currentAmps: Double
    public var rhoMax: Double
    public var zMax: Double
    public var columns: Int
    public var rows: Int
    /// Row-major over rows = z (−zMax…zMax, bottom to top) and columns = ρ (0…ρMax).
    public var bRho: [Double]
    public var bZ: [Double]
    /// Flux function ψ = 2πρA_φ in webers: field lines are its level sets.
    public var psi: [Double]
    /// A_φ per ampere, V·s/m per A. Multiply by dI/dt for the induced E.
    public var aPhiPerAmp: [Double]
    public var maxB: Double

    public static func winding(
        lengthM: Double,
        innerRadiusM: Double,
        buildM: Double,
        turns: Int,
        maxFilaments: Int = 240
    ) -> Winding {
        let n = max(turns, 1)
        // Filaments closer than about half the radius keep the ripple between them small.
        let wanted = Int((lengthM / max(innerRadiusM * 0.4, 1e-9)).rounded(.up))
        let axial = max(1, min(n, min(max(wanted, 12), 120)))
        let radial = max(1, min(3, min(maxFilaments / axial, Int((Double(n) / Double(axial)).rounded(.up)))))
        var zs: [Double] = []
        var rs: [Double] = []
        for layer in 0..<radial {
            let r = innerRadiusM + buildM * (Double(layer) + 0.5) / Double(radial)
            for slot in 0..<axial {
                zs.append(lengthM * ((Double(slot) + 0.5) / Double(axial) - 0.5))
                rs.append(r)
            }
        }
        return Winding(z: zs, radius: rs, turnsEach: Double(n) / Double(axial * radial))
    }

    /// B and the flux function of one filament, per ampere, at (ρ, z) from its centre.
    static func loop(radius a: Double, rho: Double, z: Double) -> (bRho: Double, bZ: Double, aPhi: Double) {
        let mu0 = 4 * Double.pi * 1e-7
        // On the axis the general form is 0/0.
        if rho < a * 1e-7 {
            let bz = mu0 * a * a / (2 * pow(a * a + z * z, 1.5))
            return (0, bz, 0)
        }
        let r2 = a * a + rho * rho + z * z
        let alpha2 = max(r2 - 2 * a * rho, a * a * 1e-9)
        let beta2 = r2 + 2 * a * rho
        let beta = beta2.squareRoot()
        let m = 1 - alpha2 / beta2
        let (kk, ee) = EllipticIntegrals.kAndE(m: m)
        let c = mu0 / Double.pi
        let bz = c / (2 * alpha2 * beta) * ((a * a - rho * rho - z * z) * ee + alpha2 * kk)
        let brho = c * z / (2 * alpha2 * beta * rho) * (r2 * ee - alpha2 * kk)
        let k = m.squareRoot()
        let aphi = mu0 / (Double.pi * k) * (a / rho).squareRoot() * ((1 - m / 2) * kk - ee)
        return (brho, bz, aphi)
    }

    /// B and A_φ at one point, summed over every filament. Per the stored current.
    public func sample(rho: Double, z: Double) -> (bRho: Double, bZ: Double, aPhiPerAmp: Double) {
        var br = 0.0
        var bz = 0.0
        var ap = 0.0
        for index in 0..<winding.z.count {
            let part = Self.loop(radius: winding.radius[index], rho: rho, z: z - winding.z[index])
            br += part.bRho
            bz += part.bZ
            ap += part.aPhi
        }
        let turns = winding.turnsEach
        return (br * turns * currentAmps, bz * turns * currentAmps, ap * turns)
    }

    public static func compute(
        lengthM: Double,
        innerRadiusM: Double,
        buildM: Double,
        turns: Int,
        currentAmps: Double,
        columns: Int = 72,
        rows: Int = 96,
        windowScale: Double = 2.4
    ) -> SolenoidFieldMap? {
        guard lengthM > 0, innerRadiusM > 0, turns > 0, currentAmps.isFinite, columns > 3, rows > 3 else { return nil }
        let wind = winding(lengthM: lengthM, innerRadiusM: innerRadiusM, buildM: max(buildM, innerRadiusM * 0.02), turns: turns)
        let outer = innerRadiusM + max(buildM, 0)
        let extent = max(lengthM / 2, outer) * windowScale
        let rhoMax = extent
        let zMax = extent
        var map = SolenoidFieldMap(
            winding: wind, currentAmps: currentAmps, rhoMax: rhoMax, zMax: zMax,
            columns: columns, rows: rows,
            bRho: Array(repeating: 0, count: columns * rows),
            bZ: Array(repeating: 0, count: columns * rows),
            psi: Array(repeating: 0, count: columns * rows),
            aPhiPerAmp: Array(repeating: 0, count: columns * rows),
            maxB: 0
        )
        var maxB = 0.0
        for row in 0..<rows {
            let z = -zMax + 2 * zMax * Double(row) / Double(rows - 1)
            for column in 0..<columns {
                let rho = rhoMax * Double(column) / Double(columns - 1)
                let s = map.sample(rho: rho, z: z)
                let index = row * columns + column
                map.bRho[index] = s.bRho
                map.bZ[index] = s.bZ
                map.aPhiPerAmp[index] = s.aPhiPerAmp
                map.psi[index] = 2 * Double.pi * rho * s.aPhiPerAmp * currentAmps
                let magnitude = hypot(s.bRho, s.bZ)
                if magnitude.isFinite { maxB = max(maxB, magnitude) }
            }
        }
        map.maxB = maxB
        return map
    }

    public func bMagnitude(column: Int, row: Int) -> Double {
        let i = row * columns + column
        return hypot(bRho[i], bZ[i])
    }

    /// Induced E in the winding direction, V/m, for a current ramp `didt` (A/s): E_φ = −dA_φ/dt.
    public func inducedE(column: Int, row: Int, didt: Double) -> Double {
        -aPhiPerAmp[row * columns + column] * didt
    }

    /// Grid column and row to metres.
    public func position(column: Int, row: Int) -> (rho: Double, z: Double) {
        (rhoMax * Double(column) / Double(columns - 1), -zMax + 2 * zMax * Double(row) / Double(rows - 1))
    }
}

// MARK: - Gapped core: 2D magnetostatic solve

/// Planar cross-section of a rectangular core with a winding on one leg and an optional air gap, solved for the
/// out-of-plane vector potential A_z on a grid: ∇·(ν∇A_z) = −J. Field lines are level sets of A_z. B is its curl.
/// Per unit depth, linear permeability, no saturation, no leakage beyond what the geometry itself produces.
public struct CoreFieldMap: Equatable, Sendable {
    public enum Region: UInt8, Sendable { case air = 0, steel = 1, coilPlus = 2, coilMinus = 3, gap = 4 }

    public struct Geometry: Equatable, Sendable {
        /// Everything in units of the leg thickness.
        public var windowWidth: Double
        public var windowHeight: Double
        public var gap: Double
        public var gapDrawn: Double
        public var relativePermeability: Double
    }

    public var geometry: Geometry
    public var columns: Int
    public var rows: Int
    /// Metres per grid cell, from the real leg thickness.
    public var cell: Double
    public var region: [Region]
    public var az: [Double]
    public var bx: [Double]
    public var by: [Double]
    public var maxB: Double
    public var iterations: Int
    public var residual: Double
    /// Mean |B| in the steel away from the gap, T.
    public var steelB: Double
    /// Mean |B| across the gap centre line, T. Zero when there is no gap.
    public var gapB: Double

    /// `legThicknessM` is √area for a square section. `pathLengthM` is the steel mean path.
    public static func compute(
        ampTurns: Double,
        legThicknessM: Double,
        pathLengthM: Double,
        gapM: Double,
        relativePermeability: Double,
        resolution: Int = 96
    ) -> CoreFieldMap? {
        guard ampTurns.isFinite, legThicknessM > 0, pathLengthM > 0, gapM >= 0, relativePermeability >= 1 else { return nil }
        let mu0 = 4 * Double.pi * 1e-7
        let t = legThicknessM
        // Mean path of a rectangle with legs t wide: 2(w + h) where w, h are mean sides. Use a 4:3 window.
        let meanSide = max(pathLengthM / 2, 3 * t) / t // w + h, in leg thicknesses
        let w = meanSide * 4 / 7
        let h = meanSide * 3 / 7
        let windowW = max(w - 1, 1)
        let windowH = max(h - 1, 1)
        let gap = gapM / t
        // The solver always uses the real gap. A gap thinner than a cell is carried as the series reluctance of the
        // cells it crosses (below), and only the picture shows a minimum width.
        let gapDrawn = gap
        let totalW = windowW + 2
        let totalH = windowH + 2
        let margin = 0.9
        let domainW = totalW + 2 * margin
        let domainH = totalH + 2 * margin
        let cellUnits = max(domainW, domainH) / Double(resolution)
        let columns = Int((domainW / cellUnits).rounded()) + 1
        let rows = Int((domainH / cellUnits).rounded()) + 1
        let cellM = cellUnits * t

        var region = [Region](repeating: .air, count: columns * rows)
        func unitsX(_ c: Int) -> Double { Double(c) * cellUnits - margin }
        func unitsY(_ r: Int) -> Double { Double(r) * cellUnits - margin }
        let gapHalf = gap / 2
        let gapCentre = totalW / 2
        // Fraction of each cell column the gap covers, so a gap of any width keeps its true reluctance.
        var gapShare = [Double](repeating: 0, count: columns)
        var nearestColumn = 0
        var nearestDistance = Double.infinity
        for c in 0..<columns {
            let x = unitsX(c)
            let lo = max(x - cellUnits / 2, gapCentre - gapHalf)
            let hi = min(x + cellUnits / 2, gapCentre + gapHalf)
            gapShare[c] = gap > 0 ? max(0, hi - lo) / cellUnits : 0
            let d = abs(x - gapCentre)
            if d < nearestDistance { nearestDistance = d; nearestColumn = c }
        }
        var partialGap = [Int: Double]()
        for r in 0..<rows {
            for c in 0..<columns {
                let x = unitsX(c), y = unitsY(r)
                let inside = x >= 0 && x <= totalW && y >= 0 && y <= totalH
                let inWindow = x > 1 && x < 1 + windowW && y > 1 && y < 1 + windowH
                var kind = Region.air
                if inside && !inWindow {
                    kind = .steel
                    // Gap through the bottom leg, centred.
                    if gap > 0, y < 1 {
                        let share = gapShare[c]
                        if share >= 0.5 { kind = .gap }
                        else if share > 0 || c == nearestColumn { kind = (c == nearestColumn) ? .gap : .steel }
                        if share > 0 { partialGap[r * columns + c] = min(share, 1) }
                        else if c == nearestColumn { partialGap[r * columns + c] = 0 }
                    }
                }
                // Winding fills the window beside the left leg. Current out of the page on the inner side, back on the outer.
                if inWindow, x < 1 + min(0.45, windowW * 0.25) { kind = .coilPlus }
                region[r * columns + c] = kind
            }
        }
        // Return conductors of the same winding sit outside the left leg.
        for r in 0..<rows {
            for c in 0..<columns {
                let x = unitsX(c), y = unitsY(r)
                if x < 0, x > -min(0.45, windowW * 0.25), y > 1, y < 1 + windowH { region[r * columns + c] = .coilMinus }
            }
        }

        var coilCells = 0
        for kind in region where kind == .coilPlus { coilCells += 1 }
        guard coilCells > 0 else { return nil }
        // Current density chosen so the coil cross-section carries NI. Cells are cellM square.
        let jPlus = ampTurns / (Double(coilCells) * cellM * cellM)
        // ν per cell.
        let nuAir = 1 / mu0
        let nuSteel = 1 / (mu0 * relativePermeability)
        var nu = [Double](repeating: nuAir, count: columns * rows)
        var source = [Double](repeating: 0, count: columns * rows)
        for i in 0..<region.count {
            if let share = partialGap[i] {
                // Series reluctance of the steel and air along the flux path through this cell.
                nu[i] = (1 - share) * nuSteel + share * nuAir
                continue
            }
            switch region[i] {
            case .steel: nu[i] = nuSteel
            case .coilPlus: source[i] = jPlus
            case .coilMinus: source[i] = -jPlus * Double(coilCells) / Double(max(region.filter { $0 == .coilMinus }.count, 1))
            default: break
            }
        }

        // Solve the interior with Jacobi-preconditioned conjugate gradient. A_z = 0 on the outer boundary.
        // The operator is symmetric positive definite, and Jacobi scaling absorbs the steel/air contrast.
        func harmonic(_ p: Double, _ q: Double) -> Double { 2 * p * q / (p + q) }
        let count = columns * rows
        var diag = [Double](repeating: 1, count: count)
        var nE = [Double](repeating: 0, count: count)
        var nN = [Double](repeating: 0, count: count)
        var nW = [Double](repeating: 0, count: count)
        var nS = [Double](repeating: 0, count: count)
        var rhs = [Double](repeating: 0, count: count)
        for r in 1..<(rows - 1) {
            for c in 1..<(columns - 1) {
                let i = r * columns + c
                nE[i] = harmonic(nu[i], nu[i + 1])
                nW[i] = harmonic(nu[i], nu[i - 1])
                nN[i] = harmonic(nu[i], nu[i + columns])
                nS[i] = harmonic(nu[i], nu[i - columns])
                diag[i] = nE[i] + nW[i] + nN[i] + nS[i]
                rhs[i] = source[i] * cellM * cellM
            }
        }
        func apply(_ x: [Double], _ y: inout [Double]) {
            for r in 1..<(rows - 1) {
                for c in 1..<(columns - 1) {
                    let i = r * columns + c
                    y[i] = diag[i] * x[i] - nE[i] * x[i + 1] - nW[i] * x[i - 1] - nN[i] * x[i + columns] - nS[i] * x[i - columns]
                }
            }
        }
        var a = [Double](repeating: 0, count: count)
        var res = rhs
        var z = [Double](repeating: 0, count: count)
        var direction = [Double](repeating: 0, count: count)
        var product = [Double](repeating: 0, count: count)
        var rz = 0.0
        var bNorm = 0.0
        for r in 1..<(rows - 1) {
            for c in 1..<(columns - 1) {
                let i = r * columns + c
                z[i] = res[i] / diag[i]
                direction[i] = z[i]
                rz += res[i] * z[i]
                bNorm += rhs[i] * rhs[i]
            }
        }
        bNorm = bNorm.squareRoot()
        var iterations = 0
        var residual = bNorm == 0 ? 0 : 1.0
        let maxIterations = 4000
        while iterations < maxIterations, bNorm > 0 {
            apply(direction, &product)
            var dp = 0.0
            for r in 1..<(rows - 1) {
                for c in 1..<(columns - 1) {
                    let i = r * columns + c
                    dp += direction[i] * product[i]
                }
            }
            guard dp > 0 else { break }
            let alpha = rz / dp
            var rNorm = 0.0
            var rzNew = 0.0
            for r in 1..<(rows - 1) {
                for c in 1..<(columns - 1) {
                    let i = r * columns + c
                    a[i] += alpha * direction[i]
                    res[i] -= alpha * product[i]
                    rNorm += res[i] * res[i]
                    z[i] = res[i] / diag[i]
                    rzNew += res[i] * z[i]
                }
            }
            iterations += 1
            residual = rNorm.squareRoot() / bNorm
            if residual < 1e-9 { break }
            let beta = rzNew / rz
            rz = rzNew
            for r in 1..<(rows - 1) {
                for c in 1..<(columns - 1) {
                    let i = r * columns + c
                    direction[i] = z[i] + beta * direction[i]
                }
            }
        }

        // B = curl A: Bx = dA/dy, By = −dA/dx.
        var bx = [Double](repeating: 0, count: columns * rows)
        var by = [Double](repeating: 0, count: columns * rows)
        var maxB = 0.0
        for r in 1..<(rows - 1) {
            for c in 1..<(columns - 1) {
                let i = r * columns + c
                bx[i] = (a[i + columns] - a[i - columns]) / (2 * cellM)
                by[i] = -(a[i + 1] - a[i - 1]) / (2 * cellM)
                maxB = max(maxB, hypot(bx[i], by[i]))
            }
        }
        // Sample the steel well away from the corners and the gap, and the middle of the gap.
        var steelSum = 0.0
        var steelCount = 0
        var gapSum = 0.0
        var gapCount = 0
        for r in 1..<(rows - 1) {
            for c in 1..<(columns - 1) {
                let i = r * columns + c
                let x = unitsX(c), y = unitsY(r)
                if region[i] == .steel, x > 0.15, x < 0.85, y > 1.2, y < windowH - 0.2 + 1 {
                    steelSum += hypot(bx[i], by[i])
                    steelCount += 1
                }
                if region[i] == .gap, y > 0.3, y < 0.7 {
                    gapSum += hypot(bx[i], by[i])
                    gapCount += 1
                }
            }
        }
        return CoreFieldMap(
            geometry: Geometry(windowWidth: windowW, windowHeight: windowH, gap: gap, gapDrawn: gapDrawn, relativePermeability: relativePermeability),
            columns: columns, rows: rows, cell: cellM, region: region, az: a, bx: bx, by: by,
            maxB: maxB, iterations: iterations, residual: residual,
            steelB: steelCount > 0 ? steelSum / Double(steelCount) : 0,
            gapB: gapCount > 0 ? gapSum / Double(gapCount) : 0
        )
    }

    public func bMagnitude(column: Int, row: Int) -> Double {
        let i = row * columns + column
        return hypot(bx[i], by[i])
    }

    /// Induced E along the winding for a current ramp, V/m per unit depth: E = −dA_z/dt.
    /// A_z scales with the current, so dA/dt = A_z · (dI/dt)/I.
    public func inducedE(column: Int, row: Int, didt: Double, current: Double) -> Double {
        guard current != 0 else { return 0 }
        return -az[row * columns + column] * didt / current
    }
}
