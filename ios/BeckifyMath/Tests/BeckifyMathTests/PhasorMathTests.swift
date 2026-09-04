import XCTest
@testable import BeckifyMath

final class PhasorSumTests: XCTestCase {
    /// Two equal phasors 180° apart cancel exactly.
    func testOppositePhasorsCancel() throws {
        let a = Phasor(id: 0, label: "A", magnitude: 10, angleDegrees: 0)
        let b = Phasor(id: 1, label: "B", magnitude: 10, angleDegrees: 180)

        let result = try PhasorSum.resultant(of: [a, b])
        XCTAssertEqual(result.resultantMagnitude, 0, accuracy: 1e-9)
    }

    /// Two equal phasors 90° apart sum to magnitude √2× at 45°.
    func testQuadraturePhasors() throws {
        let a = Phasor(id: 0, label: "A", magnitude: 10, angleDegrees: 0)
        let b = Phasor(id: 1, label: "B", magnitude: 10, angleDegrees: 90)

        let result = try PhasorSum.resultant(of: [a, b])
        XCTAssertEqual(result.resultantMagnitude, 10 * 2.0.squareRoot(), accuracy: 1e-9)
        XCTAssertEqual(result.resultantAngleDegrees, 45, accuracy: 1e-9)
    }

    /// A balanced three-phase set sums to zero — the whole point of three-phase.
    func testBalancedThreePhaseSetSumsToZero() throws {
        let phasors = PhasorSum.balancedThreePhaseAngles.enumerated().map { index, angle in
            Phasor(id: index, label: "L\(index + 1)", magnitude: 120, angleDegrees: angle)
        }
        let result = try PhasorSum.resultant(of: phasors)
        XCTAssertEqual(result.resultantMagnitude, 0, accuracy: 1e-9)
    }

    func testSingleColinearPhasorsAdd() throws {
        let a = Phasor(id: 0, label: "A", magnitude: 5, angleDegrees: 30)
        let b = Phasor(id: 1, label: "B", magnitude: 7, angleDegrees: 30)

        let result = try PhasorSum.resultant(of: [a, b])
        XCTAssertEqual(result.resultantMagnitude, 12, accuracy: 1e-9)
        XCTAssertEqual(result.resultantAngleDegrees, 30, accuracy: 1e-9)
    }

    func testFewerThanTwoPhasorsThrows() {
        XCTAssertThrowsError(try PhasorSum.resultant(of: []))
        XCTAssertThrowsError(try PhasorSum.resultant(of: [Phasor(id: 0, label: "A", magnitude: 1, angleDegrees: 0)]))
    }

    func testNegativeMagnitudeThrows() {
        let a = Phasor(id: 0, label: "A", magnitude: -1, angleDegrees: 0)
        let b = Phasor(id: 1, label: "B", magnitude: 1, angleDegrees: 0)
        XCTAssertThrowsError(try PhasorSum.resultant(of: [a, b]))
    }

    func testZeroMagnitudeResultantHasZeroAngle() throws {
        let a = Phasor(id: 0, label: "A", magnitude: 0, angleDegrees: 0)
        let b = Phasor(id: 1, label: "B", magnitude: 0, angleDegrees: 45)
        let result = try PhasorSum.resultant(of: [a, b])
        XCTAssertEqual(result.resultantAngleDegrees, 0)
    }
}
