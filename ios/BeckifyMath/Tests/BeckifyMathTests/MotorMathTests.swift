import XCTest
@testable import BeckifyMath

final class MotorSpeedTests: XCTestCase {
    func testFourPoleSixtyHertzIsEighteenHundred() throws {
        XCTAssertEqual(try MotorSpeed.synchronousRPM(frequency: 60, poles: 4), 1800, accuracy: 1e-9)
        XCTAssertEqual(try MotorSpeed.synchronousRPM(frequency: 60, poles: 2), 3600, accuracy: 1e-9)
        XCTAssertEqual(try MotorSpeed.synchronousRPM(frequency: 50, poles: 4), 1500, accuracy: 1e-9)
    }

    /// The classic 1750 RPM nameplate on a 4-pole 60 Hz motor.
    func testTypicalNameplateSlip() throws {
        let result = try MotorSpeed.slip(frequency: 60, poles: 4, nameplateRPM: 1750)

        XCTAssertEqual(result.synchronousRPM, 1800, accuracy: 1e-9)
        XCTAssertEqual(result.slipPercent, 50.0 / 1800.0 * 100, accuracy: 1e-9)
        XCTAssertEqual(result.slipFrequency, 50.0 / 1800.0 * 60, accuracy: 1e-9)
    }

    func testSlipRoundTripsThroughRotorSpeed() throws {
        let forward = try MotorSpeed.slip(frequency: 60, poles: 6, nameplateRPM: 1160)
        let back = try MotorSpeed.rotorRPM(frequency: 60, poles: 6, slipPercent: forward.slipPercent)

        XCTAssertEqual(back.rotorRPM, 1160, accuracy: 1e-9)
    }

    func testSynchronousNameplateIsZeroSlip() throws {
        let result = try MotorSpeed.slip(frequency: 60, poles: 4, nameplateRPM: 1800)
        XCTAssertEqual(result.slipPercent, 0, accuracy: 1e-12)
    }

    /// A nameplate above synchronous speed means the pole count or the line
    /// frequency was entered wrong — the tool says so rather than reporting
    /// negative slip.
    func testAboveSynchronousThrows() {
        XCTAssertThrowsError(try MotorSpeed.slip(frequency: 60, poles: 4, nameplateRPM: 1900))
    }

    func testOddAndTooFewPolesThrow() {
        XCTAssertThrowsError(try MotorSpeed.synchronousRPM(frequency: 60, poles: 3))
        XCTAssertThrowsError(try MotorSpeed.synchronousRPM(frequency: 60, poles: 1))
        XCTAssertThrowsError(try MotorSpeed.synchronousRPM(frequency: 0, poles: 4))
    }

    func testSlipPercentOutOfRangeThrows() {
        XCTAssertThrowsError(try MotorSpeed.rotorRPM(frequency: 60, poles: 4, slipPercent: -1))
        XCTAssertThrowsError(try MotorSpeed.rotorRPM(frequency: 60, poles: 4, slipPercent: 101))
    }
}

final class MotorTorqueTests: XCTestCase {
    /// 10 HP at 1750 RPM is a shade over 30 lb·ft — the number on the wall chart.
    func testTorqueFromHorsepower() throws {
        let result = try MotorTorque.fromHorsepower(10, rpm: 1750)

        XCTAssertEqual(result.torqueLbFt, 52520.0 / 1750.0, accuracy: 1e-9)
        XCTAssertEqual(result.torqueLbFt, 30.011, accuracy: 0.001)
        XCTAssertEqual(result.torqueNewtonMetres, result.torqueLbFt * 1.3558179483314004, accuracy: 1e-9)
    }

    func testTorqueRoundTripsBackToHorsepower() throws {
        let forward = try MotorTorque.fromHorsepower(25, rpm: 1180)
        let back = try MotorTorque.fromTorque(lbFt: forward.torqueLbFt, rpm: 1180)

        XCTAssertEqual(back.horsepower, 25, accuracy: 1e-9)
    }

    func testZeroSpeedAndZeroPowerThrow() {
        XCTAssertThrowsError(try MotorTorque.fromHorsepower(10, rpm: 0))
        XCTAssertThrowsError(try MotorTorque.fromHorsepower(0, rpm: 1750))
        XCTAssertThrowsError(try MotorTorque.fromTorque(lbFt: -5, rpm: 1750))
    }

    func testCurveIsMonotonicallyDecreasingAndMatchesFormula() {
        let points = MotorTorque.curve(horsepower: 10, minRPM: 500, maxRPM: 3600, samples: 12)

        XCTAssertEqual(points.count, 12)
        for point in points {
            XCTAssertEqual(point.torqueLbFt, 5252 * 10 / point.rpm, accuracy: 1e-9)
        }
        for (a, b) in zip(points, points.dropFirst()) {
            XCTAssertLessThan(b.torqueLbFt, a.torqueLbFt)
        }
    }

    func testCurveIsEmptyForDegenerateRanges() {
        XCTAssertTrue(MotorTorque.curve(horsepower: 0, minRPM: 500, maxRPM: 3600).isEmpty)
        XCTAssertTrue(MotorTorque.curve(horsepower: 10, minRPM: 3600, maxRPM: 500).isEmpty)
        XCTAssertTrue(MotorTorque.curve(horsepower: 10, minRPM: 500, maxRPM: 3600, samples: 1).isEmpty)
    }
}
