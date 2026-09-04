import XCTest
@testable import BeckifyMath

final class RFPowerTests: XCTestCase {
    func testZeroDBmIsOneMilliwatt() throws {
        let result = try RFPower.fromDBm(0)

        XCTAssertEqual(result.milliwatts, 1, accuracy: 1e-12)
        XCTAssertEqual(result.watts, 0.001, accuracy: 1e-12)
        // √(0.001 W × 50 Ω) = 223.6 mV RMS.
        XCTAssertEqual(result.voltsRMS, 0.2236, accuracy: 0.0001)
    }

    func testThirtyDBmIsOneWatt() throws {
        XCTAssertEqual(try RFPower.fromDBm(30).watts, 1, accuracy: 1e-9)
    }

    func testNegativeLevelsAreValid() throws {
        // -30 dBm is a microwatt; a level in dBm is signed, unlike a power.
        XCTAssertEqual(try RFPower.fromDBm(-30).watts, 1e-6, accuracy: 1e-15)
    }

    func testWattsRoundTripToDBm() throws {
        let forward = try RFPower.fromWatts(5)
        let back = try RFPower.fromDBm(forward.dBm)

        XCTAssertEqual(forward.dBm, 36.9897, accuracy: 0.0001)
        XCTAssertEqual(back.watts, 5, accuracy: 1e-9)
    }

    func testZeroWattsAndBadImpedanceThrow() {
        XCTAssertThrowsError(try RFPower.fromWatts(0))
        XCTAssertThrowsError(try RFPower.fromDBm(0, impedance: 0))
    }
}

final class AntennaMatchTests: XCTestCase {
    /// 2:1 is the everyday "acceptable" line: 11.1 % of power comes back.
    func testTwoToOneVSWR() throws {
        let result = try AntennaMatch.fromVSWR(2)

        XCTAssertEqual(result.reflectionCoefficient, 1.0 / 3.0, accuracy: 1e-9)
        XCTAssertEqual(result.returnLossDB, 9.542, accuracy: 0.001)
        XCTAssertEqual(result.reflectedPowerPercent, 11.111, accuracy: 0.001)
        XCTAssertEqual(result.mismatchLossDB, 0.5115, accuracy: 0.001)
    }

    func testPerfectMatchReportsFiniteReturnLoss() throws {
        let result = try AntennaMatch.fromVSWR(1)

        XCTAssertEqual(result.reflectionCoefficient, 0, accuracy: 1e-12)
        XCTAssertEqual(result.returnLossDB, AntennaMatch.perfectMatchReturnLossDB, accuracy: 1e-12)
        XCTAssertEqual(result.reflectedPowerPercent, 0, accuracy: 1e-12)
        XCTAssertEqual(result.mismatchLossDB, 0, accuracy: 1e-12)
    }

    func testReturnLossRoundTripsToVSWR() throws {
        let forward = try AntennaMatch.fromVSWR(1.5)
        let back = try AntennaMatch.fromReturnLoss(forward.returnLossDB)

        XCTAssertEqual(back.vswr, 1.5, accuracy: 1e-9)
    }

    func testReflectionCoefficientRoundTrips() throws {
        let result = try AntennaMatch.fromReflectionCoefficient(0.2)
        XCTAssertEqual(result.vswr, 1.5, accuracy: 1e-9)
    }

    /// A dead short reflects everything: |Γ| = 1, infinite VSWR, 0 dB return loss.
    func testTotalReflection() throws {
        let result = try AntennaMatch.fromReflectionCoefficient(1)

        XCTAssertEqual(result.returnLossDB, 0, accuracy: 1e-12)
        XCTAssertTrue(result.vswr.isInfinite)
        XCTAssertEqual(result.reflectedPowerPercent, 100, accuracy: 1e-9)
    }

    func testBelowUnityVSWRAndNegativeReturnLossThrow() {
        XCTAssertThrowsError(try AntennaMatch.fromVSWR(0.9))
        XCTAssertThrowsError(try AntennaMatch.fromReturnLoss(-3))
        XCTAssertThrowsError(try AntennaMatch.fromReflectionCoefficient(1.2))
    }
}

final class FreeSpacePathLossTests: XCTestCase {
    /// 2.4 GHz at 100 m is the Wi-Fi sanity check: about 80 dB.
    func testWiFiAtOneHundredMetres() throws {
        let result = try FreeSpacePathLoss.loss(frequencyMHz: 2400, distanceMetres: 100)
        XCTAssertEqual(result.lossDB, 80.044, accuracy: 0.001)
    }

    /// Doubling the distance adds 6 dB; so does doubling the frequency.
    func testInverseSquareBehaviour() throws {
        let near = try FreeSpacePathLoss.loss(frequencyMHz: 900, distanceMetres: 50)
        let far = try FreeSpacePathLoss.loss(frequencyMHz: 900, distanceMetres: 100)
        let high = try FreeSpacePathLoss.loss(frequencyMHz: 1800, distanceMetres: 50)

        XCTAssertEqual(far.lossDB - near.lossDB, 6.0206, accuracy: 0.001)
        XCTAssertEqual(high.lossDB - near.lossDB, 6.0206, accuracy: 0.001)
    }

    func testLinkBudgetSubtractsLossFromTransmitAndGains() throws {
        let result = try FreeSpacePathLoss.loss(
            frequencyMHz: 2400,
            distanceMetres: 100,
            transmitDBm: 20,
            transmitGainDBi: 3,
            receiveGainDBi: 3
        )

        XCTAssertEqual(try XCTUnwrap(result.receivedDBm), 26 - result.lossDB, accuracy: 1e-9)
    }

    func testReceivedIsNilWithoutATransmitLevel() throws {
        XCTAssertNil(try FreeSpacePathLoss.loss(frequencyMHz: 900, distanceMetres: 10).receivedDBm)
    }

    func testZeroDistanceOrFrequencyThrows() {
        XCTAssertThrowsError(try FreeSpacePathLoss.loss(frequencyMHz: 0, distanceMetres: 10))
        XCTAssertThrowsError(try FreeSpacePathLoss.loss(frequencyMHz: 900, distanceMetres: 0))
    }

    func testDistanceSweepIsIncreasingAndMatchesLoss() {
        let points = FreeSpacePathLoss.distanceSweep(frequencyMHz: 2400, minMetres: 1, maxMetres: 1000, samples: 10)

        XCTAssertEqual(points.count, 10)
        for point in points {
            let expected = try? FreeSpacePathLoss.loss(frequencyMHz: 2400, distanceMetres: point.distance)
            XCTAssertEqual(point.lossDB, expected?.lossDB ?? .nan, accuracy: 1e-6)
        }
        for (a, b) in zip(points, points.dropFirst()) {
            XCTAssertLessThan(a.lossDB, b.lossDB)
        }
    }

    func testDistanceSweepIsEmptyForDegenerateRanges() {
        XCTAssertTrue(FreeSpacePathLoss.distanceSweep(frequencyMHz: 0, minMetres: 1, maxMetres: 100).isEmpty)
        XCTAssertTrue(FreeSpacePathLoss.distanceSweep(frequencyMHz: 900, minMetres: 100, maxMetres: 1).isEmpty)
    }
}
