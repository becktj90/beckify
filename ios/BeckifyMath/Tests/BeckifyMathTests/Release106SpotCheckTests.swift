import XCTest
@testable import BeckifyMath

/// 1.0.6 release guard: bug-fix release, no math changes.
final class Release106SpotCheckTests: XCTestCase {

    /// 3Ø, 480 V, 100 A, 200 ft one-way, 3/0 Cu → 2.66 V, 0.55 % (NEC K-method).
    func testVoltageDropSpotCheckUnchanged() throws {
        let r = try VoltageDrop.calculate(
            system: .threePhase,
            current: 100,
            oneWayFeet: 200,
            supplyVolts: 480,
            size: "3/0",
            material: .copper
        )
        XCTAssertEqual((r.dropVolts * 100).rounded() / 100, 2.66, accuracy: 0.0001)
        XCTAssertEqual((r.dropPercent * 100).rounded() / 100, 0.55, accuracy: 0.0001)
    }

    /// The same-size example (four 12 AWG THHN in 3/4" EMT) is a PASS on both platforms.
    func testConduitSameSizeExamplePasses() throws {
        let r = try ConduitFill.calculate(quantity: 4, size: "12", tradeSize: "3/4")
        XCTAssertTrue(r.passes)
    }

    /// 3× 3/0 THHN does not fit 1/2" EMT, so PASS/FAIL still computes a FAIL.
    func testOversizedConduitExampleFails() throws {
        let r = try ConduitFill.calculate(quantity: 3, size: "3/0", tradeSize: "1/2")
        XCTAssertFalse(r.passes)
    }

    func testCalculationEventsReportSuccessOnly() {
        final class Counter: @unchecked Sendable { var n = 0 }
        let counter = Counter()
        CalculationEvents.setSuccessHandler { counter.n += 1 }
        defer { CalculationEvents.setSuccessHandler(nil) }
        var state = ExplicitCalculationState<Double>()
        state.calculate { 1.0 }
        state.calculate { throw CalcError.missing("x") }
        XCTAssertEqual(counter.n, 1)
    }
}
