import XCTest
@testable import BeckifyMath

final class BLERadarMathTests: XCTestCase {

    func testUsableRSSIRejectsCoreBluetoothUnavailable() {
        XCTAssertFalse(BLERadarMath.isUsableRSSI(BLERadarMath.unavailableRSSI))
        XCTAssertFalse(BLERadarMath.isUsableRSSI(40))
        XCTAssertFalse(BLERadarMath.isUsableRSSI(-200))
        XCTAssertTrue(BLERadarMath.isUsableRSSI(-59))
        XCTAssertTrue(BLERadarMath.isUsableRSSI(0))
        XCTAssertTrue(BLERadarMath.isUsableRSSI(-127))
    }

    func testBandFromRSSI() {
        XCTAssertEqual(BLERadarMath.band(rssi: -40), .near)
        XCTAssertEqual(BLERadarMath.band(rssi: -60), .near)
        XCTAssertEqual(BLERadarMath.band(rssi: -61), .mid)
        XCTAssertEqual(BLERadarMath.band(rssi: -80), .mid)
        XCTAssertEqual(BLERadarMath.band(rssi: -81), .far)
        XCTAssertEqual(BLERadarMath.band(rssi: 127), .unknown)
    }

    func testLogDistanceEstimateAtReferenceIsOneMeter() {
        let meters = BLERadarMath.estimatedMeters(rssi: BLERadarMath.referenceRSSIAtOneMeter)
        XCTAssertEqual(meters ?? -1, 1, accuracy: 1e-9)
    }

    func testStrongerRSSIIsNearerThanWeaker() throws {
        let near = try XCTUnwrap(BLERadarMath.estimatedMeters(rssi: -50))
        let mid = try XCTUnwrap(BLERadarMath.estimatedMeters(rssi: -70))
        let far = try XCTUnwrap(BLERadarMath.estimatedMeters(rssi: -90))
        XCTAssertLessThan(near, mid)
        XCTAssertLessThan(mid, far)
        XCTAssertEqual(BLERadarMath.estimatedMeters(rssi: 127), nil)
    }

    func testEstimateIsClampedToHomeworkBand() throws {
        let veryNear = try XCTUnwrap(BLERadarMath.estimatedMeters(rssi: 0))
        let veryFar = try XCTUnwrap(BLERadarMath.estimatedMeters(rssi: -120))
        XCTAssertEqual(veryNear, BLERadarMath.minEstimateMeters, accuracy: 1e-9)
        XCTAssertEqual(veryFar, BLERadarMath.maxEstimateMeters, accuracy: 1e-9)
        XCTAssertTrue(BLERadarMath.estimatedMetersCaption(rssi: 0).contains("<"))
        XCTAssertTrue(BLERadarMath.estimatedMetersCaption(rssi: -120).contains(">"))
        XCTAssertTrue(BLERadarMath.estimatedMetersCaption(rssi: -59).contains("est."))
        XCTAssertEqual(BLERadarMath.estimatedMetersCaption(rssi: 127), "— est.")
    }

    func testNormalizedRadiusGrowsAsRSSIFalls() {
        let near = BLERadarMath.normalizedRadius(rssi: -45)
        let mid = BLERadarMath.normalizedRadius(rssi: -70)
        let far = BLERadarMath.normalizedRadius(rssi: -95)
        XCTAssertLessThan(near, mid)
        XCTAssertLessThan(mid, far)
        XCTAssertGreaterThanOrEqual(near, BLERadarMath.minPlotRadius)
        XCTAssertLessThanOrEqual(far, BLERadarMath.maxPlotRadius)
        XCTAssertEqual(BLERadarMath.normalizedRadius(rssi: 127), BLERadarMath.maxPlotRadius, accuracy: 1e-9)
    }

    func testBaseAngleIsStableAndInRange() {
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let a = BLERadarMath.baseAngleDegrees(identifier: id)
        let b = BLERadarMath.baseAngleDegrees(identifier: id)
        XCTAssertEqual(a, b, accuracy: 1e-12)
        XCTAssertGreaterThanOrEqual(a, 0)
        XCTAssertLessThan(a, 360)
        let other = BLERadarMath.baseAngleDegrees(identifier: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        XCTAssertNotEqual(a, other)
    }

    func testLayoutAnglesSpreadCollisionsButStayDeterministic() {
        let a = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let b = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let first = BLERadarMath.layoutAngles(identifiers: [a, b])
        let second = BLERadarMath.layoutAngles(identifiers: [b, a])
        XCTAssertEqual(first[a], second[a])
        XCTAssertEqual(first[b], second[b])
        XCTAssertEqual(first.count, 2)
        let delta = abs(BLERadarMath.shortestAngleDelta(from: first[a]!, to: first[b]!))
        XCTAssertGreaterThanOrEqual(delta, 10 - 1e-9)
    }

    func testNormalizeAndShortestDeltaWrap() {
        XCTAssertEqual(BLERadarMath.normalizeDegrees(-10), 350, accuracy: 1e-9)
        XCTAssertEqual(BLERadarMath.normalizeDegrees(370), 10, accuracy: 1e-9)
        XCTAssertEqual(BLERadarMath.shortestAngleDelta(from: 350, to: 10), 20, accuracy: 1e-9)
        XCTAssertEqual(BLERadarMath.shortestAngleDelta(from: 10, to: 350), -20, accuracy: 1e-9)
    }

    func testPlacementsCarryBandAndLayout() {
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let rows = BLERadarMath.placements(from: [(id: id, rssi: -55)])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].id, id)
        XCTAssertEqual(rows[0].band, .near)
        XCTAssertNotNil(rows[0].estimatedMeters)
        XCTAssertGreaterThanOrEqual(rows[0].angleDegrees, 0)
        XCTAssertLessThan(rows[0].angleDegrees, 360)
    }

    func testTxPowerImprovesDistanceOnlyInMeasuredPowerBand() throws {
        XCTAssertFalse(BLERadarMath.usesTxPowerForDistance(nil))
        XCTAssertFalse(BLERadarMath.usesTxPowerForDistance(4))
        XCTAssertFalse(BLERadarMath.usesTxPowerForDistance(-10))
        XCTAssertTrue(BLERadarMath.usesTxPowerForDistance(-59))
        XCTAssertEqual(BLERadarMath.distanceReferenceRSSI(txPowerDBm: 4), BLERadarMath.referenceRSSIAtOneMeter)

        let rssiOnly = try XCTUnwrap(BLERadarMath.estimatedMeters(rssi: -59))
        XCTAssertEqual(rssiOnly, 1, accuracy: 1e-9)
        let sameWithRadiatedTX = try XCTUnwrap(BLERadarMath.estimatedMeters(rssi: -59, txPowerDBm: 4))
        XCTAssertEqual(sameWithRadiatedTX, rssiOnly, accuracy: 1e-9)

        let louderAtOneMeter = try XCTUnwrap(BLERadarMath.estimatedMeters(rssi: -59, txPowerDBm: -40))
        XCTAssertGreaterThan(louderAtOneMeter, rssiOnly)
        XCTAssertTrue(BLERadarMath.estimatedMetersCaption(rssi: -59, txPowerDBm: -40).contains("TX"))
        XCTAssertFalse(BLERadarMath.estimatedMetersCaption(rssi: -59, txPowerDBm: 4).contains("TX"))
    }
}
