import XCTest
@testable import BeckifyMath

final class DriveSkillMathTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    /// Feeds one window a second at `speed`, returning the next start time.
    @discardableResult
    private func run(
        _ tracker: inout DriveSkillTracker,
        seconds: Int,
        from first: Int,
        speed: Double = 60,
        window: (Int) -> GWindow? = { _ in GWindow(peakBrakeG: 0.05, peakAccelG: 0.05, peakLateralG: 0.05, samples: 15) },
        throttle: (Int) -> Double? = { _ in nil }
    ) -> Int {
        for offset in 0..<seconds {
            let t = first + offset
            tracker.add(window: window(offset), speedKph: speed, throttlePercent: throttle(offset), at: start.addingTimeInterval(Double(t)))
        }
        return first + seconds
    }

    func testTiersByScore() {
        XCTAssertEqual(DriveSkillTier.tier(for: 100), .chauffeur)
        XCTAssertEqual(DriveSkillTier.tier(for: 90), .chauffeur)
        XCTAssertEqual(DriveSkillTier.tier(for: 89.9), .smooth)
        XCTAssertEqual(DriveSkillTier.tier(for: 60), .steady)
        XCTAssertEqual(DriveSkillTier.tier(for: 59), .spirited)
        XCTAssertEqual(DriveSkillTier.tier(for: 20), .rough)
        XCTAssertEqual(DriveSkillTier.tier(for: 19), .reckless)
        XCTAssertEqual(DriveSkillTier.tier(for: -5), .reckless)
        XCTAssertEqual(DriveSkillTier.tier(for: .nan), .reckless)
    }

    func testNoScoreUntilTwentyMovingSeconds() {
        var tracker = DriveSkillTracker()
        run(&tracker, seconds: 15, from: 0)
        XCTAssertNil(tracker.score)
        XCTAssertNil(tracker.tier)
        XCTAssertLessThan(tracker.calibrationFraction, 1)
        run(&tracker, seconds: 30, from: 15)
        XCTAssertNotNil(tracker.score)
        XCTAssertEqual(tracker.calibrationFraction, 1)
    }

    func testSmoothDrivingIsAChauffeur() {
        var tracker = DriveSkillTracker()
        run(&tracker, seconds: 90, from: 0)
        XCTAssertEqual(tracker.score ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(tracker.tier, .chauffeur)
        XCTAssertEqual(tracker.harshBrakes + tracker.harshAccels + tracker.hardCorners + tracker.weaves, 0)
    }

    func testStoppedTimeIsNotScored() {
        var tracker = DriveSkillTracker()
        run(&tracker, seconds: 30, from: 0, speed: 0, window: { _ in GWindow(peakBrakeG: 0.9, peakAccelG: 0.9, peakLateralG: 0.9, samples: 15) })
        XCTAssertEqual(tracker.movingSeconds, 0)
        XCTAssertEqual(tracker.penalty, 0)
        XCTAssertEqual(tracker.harshBrakes, 0)
        XCTAssertNil(tracker.score)
    }

    func testHarshBrakingCostsPointsAndCountsOncePerRun() {
        var tracker = DriveSkillTracker()
        var t = run(&tracker, seconds: 40, from: 0)
        let hard = GWindow(peakBrakeG: 0.5, peakAccelG: 0, peakLateralG: 0, samples: 15)
        t = run(&tracker, seconds: 2, from: t, window: { _ in hard })
        XCTAssertEqual(tracker.harshBrakes, 1)
        XCTAssertLessThan(tracker.score ?? 100, 90)
        XCTAssertGreaterThan(tracker.score ?? 0, 60)
        // A calm second ends the run; the next hard stop is a second event.
        t = run(&tracker, seconds: 1, from: t)
        t = run(&tracker, seconds: 1, from: t, window: { _ in hard })
        XCTAssertEqual(tracker.harshBrakes, 2)
        _ = t
    }

    func testPenaltyFadesWithSmoothDriving() {
        var tracker = DriveSkillTracker()
        var t = run(&tracker, seconds: 40, from: 0)
        let hard = GWindow(peakBrakeG: 0.5, peakAccelG: 0, peakLateralG: 0, samples: 15)
        t = run(&tracker, seconds: 2, from: t, window: { _ in hard })
        let right = tracker.score ?? 0
        t = run(&tracker, seconds: 180, from: t)
        XCTAssertGreaterThan(tracker.score ?? 0, right)
        XCTAssertGreaterThan(tracker.score ?? 0, 90)
        _ = t
    }

    func testRepeatedHardBrakingAndCorneringIsReckless() {
        var tracker = DriveSkillTracker()
        let wild = GWindow(peakBrakeG: 0.5, peakAccelG: 0.4, peakLateralG: 0.5, samples: 15)
        run(&tracker, seconds: 40, from: 0, window: { _ in wild })
        XCTAssertEqual(tracker.tier, .reckless)
        XCTAssertLessThan(tracker.score ?? 100, 20)
        XCTAssertGreaterThan(tracker.hardCorners, 0)
    }

    func testWeavingIsCountedAndPenalized() {
        var tracker = DriveSkillTracker()
        let t = run(&tracker, seconds: 30, from: 0)
        let before = tracker.score ?? 0
        _ = run(&tracker, seconds: 6, from: t, window: { i in
            GWindow(peakBrakeG: 0.05, peakAccelG: 0.05, peakLateralG: i.isMultiple(of: 2) ? 0.22 : -0.22, samples: 15)
        })
        XCTAssertGreaterThanOrEqual(tracker.weaves, 4)
        XCTAssertLessThan(tracker.score ?? 100, before)
    }

    func testSpeedChangeStandsInWhenPhoneIsNotAligned() {
        var tracker = DriveSkillTracker()
        tracker.add(window: nil, speedKph: 90, throttlePercent: nil, at: start)
        // 90 → 60 km/h in one second is about 0.85 g.
        tracker.add(window: nil, speedKph: 60, throttlePercent: nil, at: start.addingTimeInterval(1))
        XCTAssertEqual(tracker.harshBrakes, 1)
        XCTAssertGreaterThan(tracker.penalty, 5)
    }

    func testStabbingTheThrottleLowersTheScore() {
        var smooth = DriveSkillTracker()
        run(&smooth, seconds: 60, from: 0, throttle: { _ in 20 })
        var stabby = DriveSkillTracker()
        run(&stabby, seconds: 60, from: 0, throttle: { $0.isMultiple(of: 2) ? 0 : 100 })
        XCTAssertLessThan(stabby.score ?? 100, (smooth.score ?? 0) - 10)
    }

    func testLongGapsAreNotScored() {
        var tracker = DriveSkillTracker()
        tracker.add(window: nil, speedKph: 60, throttlePercent: nil, at: start)
        tracker.add(window: GWindow(peakBrakeG: 0.9, peakAccelG: 0, peakLateralG: 0, samples: 5), speedKph: 60, throttlePercent: nil, at: start.addingTimeInterval(600))
        XCTAssertEqual(tracker.movingSeconds, 0)
        XCTAssertEqual(tracker.penalty, 0)
    }

    func testResetStartsOver() {
        var tracker = DriveSkillTracker()
        run(&tracker, seconds: 40, from: 0, window: { _ in GWindow(peakBrakeG: 0.5, peakAccelG: 0, peakLateralG: 0, samples: 1) })
        tracker.reset()
        XCTAssertNil(tracker.score)
        XCTAssertEqual(tracker.harshBrakes, 0)
        XCTAssertEqual(tracker.penalty, 0)
    }

    func testGForceWindowTracksExtremesAndResets() {
        var g = GForceTracker(smoothing: 1)
        XCTAssertNil(g.takeWindow())
        g.add(GVector(longitudinal: -0.3, lateral: 0.1))
        g.add(GVector(longitudinal: 0.2, lateral: -0.4))
        g.add(GVector(longitudinal: 0.0, lateral: 0.2))
        let window = g.takeWindow()
        XCTAssertEqual(window?.peakBrakeG ?? 0, 0.3, accuracy: 1e-9)
        XCTAssertEqual(window?.peakAccelG ?? 0, 0.2, accuracy: 1e-9)
        XCTAssertEqual(window?.peakLateralG ?? 0, -0.4, accuracy: 1e-9)
        XCTAssertEqual(window?.samples, 3)
        XCTAssertNil(g.takeWindow())
    }
}
