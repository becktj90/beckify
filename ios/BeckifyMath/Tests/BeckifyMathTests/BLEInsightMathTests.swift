import XCTest
@testable import BeckifyMath

final class BLEInsightMathTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testEmptyInsightsAreQuietAndHonest() {
        let insights = BLEInsightMath.insights(live: [], history: [], now: now, scanStarted: nil)
        XCTAssertEqual(insights.activity.index, 0)
        XCTAssertEqual(insights.activity.caption, .quiet)
        XCTAssertEqual(insights.activity.uniqueDevices, 0)
        XCTAssertEqual(insights.mix.summary.total, 0)
        XCTAssertEqual(insights.mix.shareCaption, "—")
        XCTAssertEqual(insights.churn.trend, .warmingUp)
        XCTAssertTrue(insights.stickyLine.contains("≠ people"))
        XCTAssertTrue(insights.copyLine.contains("Device count ≠ people"))
        XCTAssertTrue(insights.copyLine.contains("Quiet RF activity"))
        assertNotOccupancy(insights.copyLine)
        assertNotOccupancy(insights.stickyLine)
        assertNotOccupancy(insights.activity.caption.rawValue)
    }

    func testActivityCaptionsAreRFNotOccupancy() {
        XCTAssertEqual(BLERFActivityCaption.from(index: 0), .quiet)
        XCTAssertEqual(BLERFActivityCaption.from(index: 19), .quiet)
        XCTAssertEqual(BLERFActivityCaption.from(index: 20), .moderate)
        XCTAssertEqual(BLERFActivityCaption.from(index: 44), .moderate)
        XCTAssertEqual(BLERFActivityCaption.from(index: 45), .busy)
        XCTAssertEqual(BLERFActivityCaption.from(index: 69), .busy)
        XCTAssertEqual(BLERFActivityCaption.from(index: 70), .veryBusy)
        XCTAssertEqual(BLERFActivityCaption.from(index: 100), .veryBusy)
        for caption in [BLERFActivityCaption.quiet, .moderate, .busy, .veryBusy] {
            XCTAssertTrue(caption.rawValue.contains("RF activity"))
            assertNotOccupancy(caption.rawValue)
        }
    }

    func testNearConnectablePersonalOutweighsFarBeacon() {
        let airpods = sample(
            n: 1,
            name: "AirPods",
            rssi: -40,
            companyID: 0x004C,
            kind: .audio,
            connectable: true
        )
        let beacon = sample(
            n: 2,
            name: "Unnamed",
            rssi: -90,
            companyID: 0x0499,
            kind: .beacon,
            connectable: false,
            ibeacon: true
        )
        let personal = BLEInsightMath.sampleWeight(airpods)
        let infra = BLEInsightMath.sampleWeight(beacon)
        XCTAssertGreaterThan(personal, infra * 4)

        let onePersonal = BLEInsightMath.activity(from: [airpods])
        let manyBeacons = BLEInsightMath.activity(from: (0..<12).map {
            sample(
                n: $0 + 10,
                name: "Unnamed",
                rssi: -92,
                companyID: 0x0499,
                kind: .beacon,
                connectable: false,
                ibeacon: true
            )
        })
        XCTAssertGreaterThan(onePersonal.index, 0)
        XCTAssertLessThan(manyBeacons.index, 45)
        XCTAssertEqual(manyBeacons.caption, .quiet)
        XCTAssertEqual(manyBeacons.uniqueDevices, 12)
    }

    func testBusyRoomOfNearPersonalRadiosIsVeryBusyRF() {
        let live = (0..<8).map {
            sample(
                n: $0,
                name: "Watch",
                rssi: -38,
                companyID: 0x004C,
                kind: .phoneEcosystem,
                connectable: true
            )
        }
        let activity = BLEInsightMath.activity(from: live)
        XCTAssertGreaterThanOrEqual(activity.index, 70)
        XCTAssertEqual(activity.caption, .veryBusy)
        XCTAssertEqual(activity.uniqueDevices, 8)
        XCTAssertTrue(activity.caption.rawValue.contains("RF activity"))
    }

    func testActivityIndexSaturatesAndRejectsNonFinite() {
        XCTAssertEqual(BLEInsightMath.activityIndex(weighted: 0), 0)
        XCTAssertEqual(BLEInsightMath.activityIndex(weighted: -4), 0)
        XCTAssertEqual(BLEInsightMath.activityIndex(weighted: .nan), 0)
        XCTAssertEqual(BLEInsightMath.activityIndex(weighted: .infinity), 0)
        XCTAssertEqual(BLEInsightMath.activityIndex(weighted: 8), 50)
        XCTAssertEqual(BLEInsightMath.activityIndex(weighted: 200), 100)
    }

    func testRoomMixCountsBeaconLikeAndConnectableShare() {
        let live = [
            sample(n: 1, name: "AirPods", rssi: -40, companyID: 0x004C, kind: .audio, connectable: true),
            sample(n: 2, name: "Unnamed", rssi: -44, companyID: 0x004C, kind: .phoneEcosystem, connectable: true),
            sample(n: 3, name: "Unnamed", rssi: -70, companyID: 0x0075, kind: .unknown, connectable: nil),
            sample(n: 4, name: "Ruuvi", rssi: -90, companyID: 0x0499, kind: .beacon, connectable: false, ibeacon: true),
            sample(n: 5, name: "Unnamed", rssi: 127, companyID: nil, kind: .unnamedNoise, connectable: false),
        ]
        let mix = BLEInsightMath.roomMix(from: live)
        XCTAssertEqual(mix.summary.total, 5)
        XCTAssertEqual(mix.summary.named, 2)
        XCTAssertEqual(mix.summary.unnamed, 3)
        XCTAssertEqual(mix.summary.near, 2)
        XCTAssertEqual(mix.summary.mid, 1)
        XCTAssertEqual(mix.summary.far, 1)
        XCTAssertEqual(mix.summary.unknownBand, 1)
        XCTAssertEqual(mix.beaconLike, 1)
        XCTAssertEqual(mix.connectableYes, 2)
        XCTAssertEqual(mix.connectableNo, 2)
        XCTAssertEqual(mix.connectableUnknown, 1)
        XCTAssertEqual(mix.shareCaption, "1/5 beacon-like · 2/5 connectable")
        XCTAssertEqual(mix.summary.topManufacturers.map(\.name), ["Apple", "Samsung", "Ruuvi"])
    }

    func testChurnStaysWarmingUpUntilTwoTrendBuckets() {
        let started = now.addingTimeInterval(-90)
        let history = [
            sample(n: 1, name: "A", rssi: -50, first: now.addingTimeInterval(-20), last: now),
        ]
        let churn = BLEInsightMath.churn(history: history, now: now, scanStarted: started)
        XCTAssertEqual(churn.trend, .warmingUp)
        XCTAssertTrue(churn.caption.contains("RF"))
        assertNotOccupancy(churn.caption)
        assertNotOccupancy(churn.trend.rawValue)
    }

    func testChurnAppearedAgedOutAndBusierTrend() {
        let started = now.addingTimeInterval(-200)
        // Previous minute: ids 1 and 2. Current minute: 1, 3, 4, 5 → appeared net.
        let history = [
            sample(n: 1, name: "Stay", rssi: -50, first: now.addingTimeInterval(-250), last: now),
            sample(n: 2, name: "Gone", rssi: -60, first: now.addingTimeInterval(-240), last: now.addingTimeInterval(-70)),
            sample(n: 3, name: "NewA", rssi: -45, first: now.addingTimeInterval(-20), last: now),
            sample(n: 4, name: "NewB", rssi: -48, first: now.addingTimeInterval(-15), last: now),
            sample(n: 5, name: "NewC", rssi: -52, first: now.addingTimeInterval(-10), last: now),
        ]
        let churn = BLEInsightMath.churn(history: history, now: now, scanStarted: started)
        XCTAssertEqual(churn.appeared, 3)
        XCTAssertEqual(churn.disappeared, 1)
        XCTAssertEqual(churn.trend, .busier)
        XCTAssertTrue(churn.caption.contains("Getting busier (RF)"))
        XCTAssertTrue(churn.caption.contains("aged out"))
        assertNotOccupancy(churn.caption)
    }

    func testChurnQuieterAndSteadyFromDeviceIDs() {
        let started = now.addingTimeInterval(-200)
        let quieterHistory = [
            sample(n: 1, name: "Stay", rssi: -50, first: now.addingTimeInterval(-250), last: now),
            sample(n: 2, name: "GoneA", rssi: -60, first: now.addingTimeInterval(-240), last: now.addingTimeInterval(-70)),
            sample(n: 3, name: "GoneB", rssi: -62, first: now.addingTimeInterval(-230), last: now.addingTimeInterval(-80)),
            sample(n: 4, name: "GoneC", rssi: -64, first: now.addingTimeInterval(-220), last: now.addingTimeInterval(-75)),
        ]
        let quieter = BLEInsightMath.churn(history: quieterHistory, now: now, scanStarted: started)
        XCTAssertEqual(quieter.trend, .quieter)
        XCTAssertEqual(quieter.appeared, 0)
        XCTAssertEqual(quieter.disappeared, 3)
        XCTAssertTrue(quieter.caption.contains("Getting quieter (RF)"))

        let steadyHistory = [
            sample(n: 1, name: "A", rssi: -50, first: now.addingTimeInterval(-150), last: now),
            sample(n: 2, name: "B", rssi: -55, first: now.addingTimeInterval(-140), last: now),
            sample(n: 3, name: "SwapOut", rssi: -60, first: now.addingTimeInterval(-150), last: now.addingTimeInterval(-70)),
            sample(n: 4, name: "SwapIn", rssi: -48, first: now.addingTimeInterval(-20), last: now),
        ]
        let steady = BLEInsightMath.churn(history: steadyHistory, now: now, scanStarted: started)
        XCTAssertEqual(steady.trend, .steady)
        XCTAssertTrue(steady.caption.contains("Steady RF mix"))
    }

    func testInsightsStickyMentionsRFActivityAndPeopleDisclaimer() {
        let live = [
            sample(n: 1, name: "AirPods", rssi: -42, companyID: 0x004C, kind: .audio, connectable: true),
            sample(n: 2, name: "Unnamed", rssi: -70, companyID: nil, kind: .unnamedNoise, connectable: nil),
        ]
        let insights = BLEInsightMath.insights(
            live: live,
            history: live,
            now: now,
            scanStarted: now.addingTimeInterval(-30)
        )
        XCTAssertTrue(insights.stickyLine.contains("RF activity"))
        XCTAssertTrue(insights.stickyLine.contains("≠ people"))
        XCTAssertTrue(insights.copyLine.contains("Room mix"))
        XCTAssertTrue(insights.copyLine.contains("Churn"))
        XCTAssertTrue(insights.copyLine.contains(BLEAdvertisementMath.peopleCountDisclaimer))
        assertNotOccupancy(insights.stickyLine)
        assertNotOccupancy(insights.copyLine)
        XCTAssertFalse(insights.copyLine.localizedCaseInsensitiveContains("how many people"))
    }

    func testWasPresentUsesOverlapNotLastSeenAlone() {
        let row = sample(
            n: 1,
            name: "Stay",
            rssi: -50,
            first: now.addingTimeInterval(-90),
            last: now.addingTimeInterval(-10)
        )
        XCTAssertTrue(BLEInsightMath.wasPresent(row, from: now.addingTimeInterval(-60), to: now))
        XCTAssertFalse(BLEInsightMath.wasPresent(row, from: now.addingTimeInterval(-200), to: now.addingTimeInterval(-100)))
    }

    private func sample(
        n: Int,
        name: String,
        rssi: Int,
        companyID: UInt16? = nil,
        kind: BLEKindHint = .unknown,
        connectable: Bool? = nil,
        ibeacon: Bool = false,
        first: Date? = nil,
        last: Date? = nil
    ) -> BLEInsightSample {
        BLEInsightSample(
            id: uuid(n),
            name: name,
            rssi: rssi,
            companyID: companyID,
            kind: kind,
            isConnectable: connectable,
            looksLikeIBeacon: ibeacon,
            firstSeen: first ?? now.addingTimeInterval(-10),
            lastSeen: last ?? now
        )
    }

    private func uuid(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
    }

    private func assertNotOccupancy(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(text.localizedCaseInsensitiveContains("how many people"), file: file, line: line)
        let lowered = text.lowercased()
        if lowered.contains("occupancy") {
            XCTAssertTrue(
                lowered.contains("not occupancy"),
                "mentions occupancy without an honest negation",
                file: file,
                line: line
            )
        }
        if lowered.contains("headcount") {
            XCTAssertTrue(
                lowered.contains("not occupancy or a headcount") || lowered.contains("not a headcount"),
                "mentions headcount without an honest negation",
                file: file,
                line: line
            )
        }
    }
}
