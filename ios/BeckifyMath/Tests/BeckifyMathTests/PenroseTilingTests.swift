import XCTest
@testable import BeckifyMath

final class PenroseTilingTests: XCTestCase {
    func testTriangleCountsFollowDeflationRecurrence() {
        for depth in 0...6 {
            let tris = PenroseTiling.triangles(radius: 100, depth: depth)
            let exp = PenroseTiling.expectedCounts(depth: depth)
            XCTAssertEqual(tris.filter { !$0.thin }.count, exp.fat, "depth \(depth)")
            XCTAssertEqual(tris.filter { $0.thin }.count, exp.thin, "depth \(depth)")
        }
        // Thin/fat ratio tends to the golden ratio.
        let e = PenroseTiling.expectedCounts(depth: 10)
        XCTAssertEqual(Double(e.thin) / Double(e.fat), PenroseTiling.phi, accuracy: 0.01) // fat:thin → 1:φ
    }

    func testGeometryIsRobinsonTriangles() {
        let tris = PenroseTiling.triangles(radius: 100, depth: 4)
        let phi = PenroseTiling.phi
        for t in tris {
            let ab = t.a.distance(to: t.b), ac = t.a.distance(to: t.c), bc = t.b.distance(to: t.c)
            XCTAssertEqual(ab, ac, accuracy: 1e-6) // isosceles at a
            XCTAssertEqual(t.thin ? ab / bc : bc / ab, t.thin ? 1 / phi : 1 / phi, accuracy: 1e-6)
            for p in [t.a, t.b, t.c] {
                XCTAssertTrue(p.x.isFinite && p.y.isFinite)
                XCTAssertLessThanOrEqual(p.distance(to: .init(0, 0)), 100 + 1e-6)
            }
        }
    }

    func testSegmentsAreDeduplicatedAndNonDegenerate() {
        let segs = PenroseTiling.segments(radius: 100, depth: 4)
        let tris = PenroseTiling.triangles(radius: 100, depth: 4)
        XCTAssertLessThan(segs.count, tris.count * 2)
        XCTAssertGreaterThan(segs.count, tris.count / 2)
        XCTAssertTrue(segs.allSatisfy { $0.p.distance(to: $0.q) > 1e-6 })
    }

    func testRippleIsDampedAndBounded() {
        XCTAssertEqual(PondRipple.amplitude(r: 300, t: 0.01), 0) // not reached yet
        var maxEarly = 0.0, maxLate = 0.0
        for r in stride(from: 0.0, through: 900, by: 5) {
            maxEarly = max(maxEarly, PondRipple.amplitude(r: r, t: 0.25))
            maxLate = max(maxLate, PondRipple.amplitude(r: r, t: 1.4))
            XCTAssertLessThanOrEqual(PondRipple.amplitude(r: r, t: 0.6), 1)
        }
        XCTAssertGreaterThan(maxEarly, maxLate)
    }
}
