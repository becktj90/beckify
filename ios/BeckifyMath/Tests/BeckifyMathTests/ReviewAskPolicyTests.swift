import XCTest
@testable import BeckifyMath

final class ReviewAskPolicyTests: XCTestCase {

    private let day0 = Date(timeIntervalSince1970: 1_778_000_000)
    private let version = "1.0"

    private func snapshot(
        saved: Int = 0,
        calcs: Int = 0,
        days: Int = 1,
        firstLaunch: Date? = nil,
        lastPrompted: String = "",
        nowOffsetHours: Double = 24,
        current: String? = nil
    ) -> ReviewAskSnapshot {
        let start = firstLaunch ?? day0
        return ReviewAskSnapshot(
            savedJobCount: saved,
            successfulCalcCount: calcs,
            distinctSessionDays: days,
            firstLaunchAt: start,
            lastPromptedVersion: lastPrompted,
            currentVersion: current ?? version,
            now: start.addingTimeInterval(nowOffsetHours * 3600)
        )
    }

    func testFirstLaunchNeverAsks() {
        XCTAssertFalse(ReviewAskPolicy.shouldRequest(snapshot(
            saved: 10,
            calcs: 20,
            days: 1,
            nowOffsetHours: 48
        )))
    }

    func testFirstHourNeverAsksEvenWithWinsAndTwoDays() {
        XCTAssertFalse(ReviewAskPolicy.shouldRequest(snapshot(
            saved: 3,
            days: 2,
            nowOffsetHours: 2
        )))
    }

    func testSameVersionAlreadyPromptedNeverAsksAgain() {
        XCTAssertFalse(ReviewAskPolicy.shouldRequest(snapshot(
            saved: 4,
            days: 5,
            lastPrompted: version,
            nowOffsetHours: 72
        )))
    }

    func testTwoSavedJobsOnReturningDayAsks() {
        XCTAssertTrue(ReviewAskPolicy.shouldRequest(snapshot(
            saved: 2,
            days: 2,
            nowOffsetHours: 13
        )))
    }

    func testOneSavePlusFiveCalcsAsks() {
        XCTAssertTrue(ReviewAskPolicy.shouldRequest(snapshot(
            saved: 1,
            calcs: 5,
            days: 2,
            nowOffsetHours: 13
        )))
    }

    func testEightCalcsWithoutSaveAsks() {
        XCTAssertTrue(ReviewAskPolicy.shouldRequest(snapshot(
            calcs: 8,
            days: 2,
            nowOffsetHours: 13
        )))
    }

    func testOneSaveAloneIsNotAWin() {
        let snap = snapshot(saved: 1, days: 2, nowOffsetHours: 24)
        XCTAssertFalse(ReviewAskPolicy.hasClearWin(snap))
        XCTAssertFalse(ReviewAskPolicy.shouldRequest(snap))
    }

    func testNewMarketingVersionCanAskAgain() {
        XCTAssertTrue(ReviewAskPolicy.shouldRequest(snapshot(
            saved: 2,
            days: 2,
            lastPrompted: "1.0",
            nowOffsetHours: 24,
            current: "1.1"
        )))
    }

    func testHasClearWinThresholds() {
        XCTAssertFalse(ReviewAskPolicy.hasClearWin(snapshot(calcs: 7)))
        XCTAssertTrue(ReviewAskPolicy.hasClearWin(snapshot(calcs: 8)))
        XCTAssertFalse(ReviewAskPolicy.hasClearWin(snapshot(saved: 1, calcs: 4)))
        XCTAssertTrue(ReviewAskPolicy.hasClearWin(snapshot(saved: 1, calcs: 5)))
        XCTAssertTrue(ReviewAskPolicy.hasClearWin(snapshot(saved: 2)))
    }
}
