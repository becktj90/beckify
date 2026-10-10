import Foundation

/// Procedural Penrose P3 (rhombus) tiling built by Robinson-triangle deflation.
/// Pure Swift (no CoreGraphics) so it is unit-tested on Linux CI.
public enum PenroseTiling {
    public static let phi = (1 + 5.0.squareRoot()) / 2

    public struct Point: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
        static func + (a: Point, b: Point) -> Point { Point(a.x + b.x, a.y + b.y) }
        static func - (a: Point, b: Point) -> Point { Point(a.x - b.x, a.y - b.y) }
        static func * (a: Point, s: Double) -> Point { Point(a.x * s, a.y * s) }
        public func distance(to o: Point) -> Double { ((x - o.x) * (x - o.x) + (y - o.y) * (y - o.y)).squareRoot() }
    }

    /// Half-rhombus. `thin == false` is the 36° (fat rhombus half), `true` the 108° (thin half).
    public struct Triangle: Sendable {
        public var thin: Bool
        public var a: Point, b: Point, c: Point
    }

    /// A segment to stroke. Robinson triangles share their base with their twin
    /// half, so only the two rhombus edges (a–b, a–c) are emitted.
    public struct Segment: Sendable {
        public var p: Point, q: Point
    }

    /// Ten-triangle "sun" of radius `radius` around `center`.
    public static func sun(center: Point = Point(0, 0), radius: Double) -> [Triangle] {
        (0..<10).map { i in
            let t1 = Double(2 * i - 1) * .pi / 10
            let t2 = Double(2 * i + 1) * .pi / 10
            var b = center + Point(cos(t1), sin(t1)) * radius
            var c = center + Point(cos(t2), sin(t2)) * radius
            if i % 2 == 0 { swap(&b, &c) }
            return Triangle(thin: false, a: center, b: b, c: c)
        }
    }

    public static func deflate(_ tris: [Triangle]) -> [Triangle] {
        var out: [Triangle] = []
        out.reserveCapacity(tris.count * 3)
        for t in tris {
            if !t.thin {
                let p = t.a + (t.b - t.a) * (1 / phi)
                out.append(Triangle(thin: false, a: t.c, b: p, c: t.b))
                out.append(Triangle(thin: true, a: p, b: t.c, c: t.a))
            } else {
                let q = t.b + (t.a - t.b) * (1 / phi)
                let r = t.b + (t.c - t.b) * (1 / phi)
                out.append(Triangle(thin: true, a: r, b: t.c, c: t.a))
                out.append(Triangle(thin: true, a: q, b: r, c: t.b))
                out.append(Triangle(thin: false, a: r, b: q, c: t.a))
            }
        }
        return out
    }

    public static func triangles(radius: Double, center: Point = Point(0, 0), depth: Int) -> [Triangle] {
        var tris = sun(center: center, radius: radius)
        for _ in 0..<max(0, depth) { tris = deflate(tris) }
        return tris
    }

    /// Deduplicated rhombus edges, ready to stroke once and cache.
    public static func segments(radius: Double, center: Point = Point(0, 0), depth: Int) -> [Segment] {
        var seen = Set<String>()
        var out: [Segment] = []
        func key(_ p: Point) -> String { String(format: "%.3f,%.3f", p.x, p.y) }
        for t in triangles(radius: radius, center: center, depth: depth) {
            for (p, q) in [(t.a, t.b), (t.a, t.c)] {
                let k1 = key(p), k2 = key(q)
                let k = k1 < k2 ? k1 + "|" + k2 : k2 + "|" + k1
                if seen.insert(k).inserted { out.append(Segment(p: p, q: q)) }
            }
        }
        return out
    }

    /// Expected (fat, thin) counts after `depth` deflations of the sun.
    public static func expectedCounts(depth: Int) -> (fat: Int, thin: Int) {
        var fat = 10, thin = 0
        for _ in 0..<max(0, depth) { (fat, thin) = (fat + thin, fat + 2 * thin) }
        return (fat, thin)
    }
}

/// Damped radial ripple ("rock in a pond") used by the launch splash.
public enum PondRipple {
    /// Wave amplitude 0…1 at distance `r` (points) and time `t` (seconds).
    /// Each ripple is a ring travelling at `speed` with a damped sine envelope.
    public static func amplitude(r: Double, t: Double, speed: Double = 520, wavelength: Double = 90,
                                 ripples: [Double] = [0, 0.32], damping: Double = 2.2) -> Double {
        var total = 0.0
        for start in ripples where t > start {
            let age = t - start
            let front = age * speed
            let d = front - r
            guard d > 0, d < wavelength * 2 else { continue }
            let envelope = exp(-damping * age) * exp(-d / wavelength)
            total += envelope * max(0, sin(2 * .pi * d / wavelength))
        }
        return min(1, total)
    }
}
