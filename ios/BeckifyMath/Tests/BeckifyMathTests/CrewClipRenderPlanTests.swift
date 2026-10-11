import XCTest
@testable import BeckifyMath

final class CrewClipRenderPlanTests: XCTestCase {
    func testMuxNeverWaitsWhileOtherInputReady() {
        // Video ahead and the writer stops taking video: must feed audio, not spin.
        XCTAssertEqual(CrewClipMux.next(videoRemaining: true, videoReady: false, videoTime: 2,
                                        audioRemaining: true, audioReady: true, audioTime: 0), .audio)
        XCTAssertEqual(CrewClipMux.next(videoRemaining: true, videoReady: true, videoTime: 0,
                                        audioRemaining: true, audioReady: false, audioTime: 1), .video)
        XCTAssertEqual(CrewClipMux.next(videoRemaining: true, videoReady: false, videoTime: 0,
                                        audioRemaining: true, audioReady: false, audioTime: 0), .wait)
        XCTAssertEqual(CrewClipMux.next(videoRemaining: false, videoReady: true, videoTime: 3,
                                        audioRemaining: false, audioReady: true, audioTime: 3), .finish)
    }

    func testMuxFeedsTheStreamThatIsBehind() {
        XCTAssertEqual(CrewClipMux.next(videoRemaining: true, videoReady: true, videoTime: 1.0,
                                        audioRemaining: true, audioReady: true, audioTime: 0.5), .audio)
        XCTAssertEqual(CrewClipMux.next(videoRemaining: true, videoReady: true, videoTime: 0.4,
                                        audioRemaining: true, audioReady: true, audioTime: 0.5), .video)
    }

    /// Simulates a writer that refuses an input once it runs >1 s ahead of the other.
    /// The old "all video, then audio" order deadlocks here; the mux plan finishes.
    func testSimulatedInterleavingWriterCompletes() {
        let fps = 24.0, total = 120, audioChunks = 50, chunk = 0.1
        var v = 0, a = 0, steps = 0
        while steps < 10_000 {
            steps += 1
            let vt = Double(v) / fps, at = Double(a) * chunk
            let step = CrewClipMux.next(
                videoRemaining: v < total, videoReady: a >= audioChunks || vt - at < 1.0, videoTime: vt,
                audioRemaining: a < audioChunks, audioReady: v >= total || at - vt < 1.0, audioTime: at)
            switch step {
            case .video: v += 1
            case .audio: a += 1
            case .wait: XCTFail("deadlock at v=\(v) a=\(a)"); return
            case .finish: XCTAssertEqual(v, total); XCTAssertEqual(a, audioChunks); return
            }
        }
        XCTFail("did not finish")
    }

    func testAudioSourceFetchesWhenNotCachedOrStale() {
        XCTAssertEqual(CrewClipAudioSource.resolve(hasCachedFile: false, cachedCrew: .titoSolano, crew: .titoSolano,
                                                   cachedLine: "Hola", line: "Hola"), .fetch)
        XCTAssertEqual(CrewClipAudioSource.resolve(hasCachedFile: true, cachedCrew: .titoSolano, crew: .humbertoArismendi,
                                                   cachedLine: "Hola", line: "Hola"), .fetch)
        XCTAssertEqual(CrewClipAudioSource.resolve(hasCachedFile: true, cachedCrew: .titoSolano, crew: .titoSolano,
                                                   cachedLine: "Hola", line: "Adiós"), .fetch)
        XCTAssertEqual(CrewClipAudioSource.resolve(hasCachedFile: true, cachedCrew: .titoSolano, crew: .titoSolano,
                                                   cachedLine: "Hola ", line: "Hola"), .cached)
    }

    func testProgress() {
        XCTAssertEqual(CrewClipProgress(framesDone: 0, totalFrames: 0).fraction, 0)
        XCTAssertEqual(CrewClipProgress(framesDone: 30, totalFrames: 120).fraction, 0.25)
        XCTAssertEqual(CrewClipProgress(framesDone: 300, totalFrames: 120).fraction, 1)
        XCTAssertEqual(CrewClipProgress(framesDone: 60, totalFrames: 120).percentLabel, "50%")
        XCTAssertFalse(CrewClipProgress.shouldShowBar(elapsed: 0.5, finished: false))
        XCTAssertTrue(CrewClipProgress.shouldShowBar(elapsed: 1.2, finished: false))
        XCTAssertFalse(CrewClipProgress.shouldShowBar(elapsed: 5, finished: true))
    }

    func testHelperSwitchStateMachine() {
        var s = CrewHelperSwitchState(crew: .titoSolano)
        // No result yet: picking a helper does nothing.
        XCTAssertEqual(s.helperChanged(to: .humbertoArismendi, source: "Bring more wire.", hasResult: false), .none)
        // Same helper again: nothing.
        XCTAssertEqual(s.helperChanged(to: .humbertoArismendi, source: "Bring more wire.", hasResult: true), .none)
        // Real switch with a result: cancel + schedule.
        guard case .cancelAndSchedule(let t1) = s.helperChanged(to: .titoSolano, source: "Bring more wire.", hasResult: true) else {
            return XCTFail("expected schedule")
        }
        // Quick swipe: second pick supersedes the first.
        guard case .cancelAndSchedule(let t2) = s.helperChanged(to: .humbertoArismendi, source: "Bring more wire.", hasResult: true) else {
            return XCTFail("expected schedule")
        }
        XCTAssertNil(s.fire(token: t1))
        XCTAssertEqual(s.fire(token: t2), "Bring more wire.")
        XCTAssertNil(s.fire(token: t2), "fires once")
        // A new turn cancels a pending re-run.
        guard case .cancelAndSchedule(let t3) = s.helperChanged(to: .titoSolano, source: "x", hasResult: true) else {
            return XCTFail("expected schedule")
        }
        s.reset(crew: .titoSolano)
        XCTAssertNil(s.fire(token: t3))
        // Blank source never schedules.
        XCTAssertEqual(s.helperChanged(to: .humbertoArismendi, source: "  ", hasResult: true), .none)
        XCTAssertEqual(CrewHelperSwitchState.debounce, 0.3)
    }
}
