import XCTest
@testable import BeckifyMath

final class CrewSpriteTimingTests: XCTestCase {
    private func shippedSpec(_ crew: CrewTalkMember) throws -> CrewSpriteSheetSpec {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Beckify/Assets.xcassets/\(crew.spriteSheetAssetName).dataset/\(crew.spriteSheetAssetName).json")
        return try CrewSpriteSheetSpec.decode(Data(contentsOf: url))
    }

    func testEveryCrewMemberShipsAConsistentSheet() throws {
        // Helpers added later fall back to their two portraits until a sheet is exported,
        // so only the shipped roster is required here.
        let shipped: Set<String> = ["bodieHale", "titoSolano", "lupitaReyes", "juniePell", "pearl", "sloaneMerritt", "dreLacey"]
        for crew in CrewTalkMember.allCases where shipped.contains(crew.rawValue) {
            let spec = try shippedSpec(crew)
            XCTAssertTrue(spec.isConsistent, "\(crew) sheet")
            XCTAssertEqual(spec.frameSize, 96)
            XCTAssertGreaterThanOrEqual(spec.animation(.talk)?.frames.count ?? 0, 2, "talk needs mouth shapes")
            XCTAssertTrue(spec.animation(.talk)?.loop ?? false)
            XCTAssertTrue(spec.animation(.idle)?.loop ?? false)
        }
    }

    func testLoopWrapsAndOneShotHolds() {
        let loop = CrewSpriteAnimation(frames: [4, 5, 6, 7], fps: 10, loop: true)
        XCTAssertEqual(loop.frame(at: 0), 4)
        XCTAssertEqual(loop.frame(at: 0.1), 5)
        XCTAssertEqual(loop.frame(at: 0.39), 7)
        XCTAssertEqual(loop.frame(at: 0.4), 4)
        XCTAssertEqual(loop.duration, 0.4, accuracy: 1e-9)
        let once = CrewSpriteAnimation(frames: [1, 2, 3], fps: 12, loop: false)
        XCTAssertEqual(once.frame(at: 10), 3)
        XCTAssertEqual(once.frame(at: -1), 1)
        XCTAssertEqual(once.frame(progress: 0), 1)
        XCTAssertEqual(once.frame(progress: 1), 3)
    }

    func testClipLengthMatchesAudioPlusTinyPad() {
        for audio in [0.8, 2.37, 4.0, 11.5] {
            let tl = CrewClipTimeline(audioDuration: audio)
            XCTAssertEqual(tl.totalDuration, audio + 0.5, accuracy: 1e-9)
            XCTAssertEqual(tl.audioEnd - tl.audioStart, audio, accuracy: 1e-9)
            let videoLength = Double(tl.frameCount) / Double(CrewClipTimeline.framesPerSecond)
            XCTAssertGreaterThanOrEqual(videoLength, tl.totalDuration - 1e-9)
            XCTAssertLessThan(videoLength - tl.totalDuration, 1.0 / Double(CrewClipTimeline.framesPerSecond))
        }
        XCTAssertEqual(CrewClipTimeline(audioDuration: .nan).audioDuration, 0)
        XCTAssertEqual(CrewClipTimeline(audioDuration: 900).audioDuration, CrewClipTimeline.maximumAudio)
    }

    func testClipTalksOnlyWhileAudioPlays() throws {
        let spec = try shippedSpec(.pearl)
        let tl = CrewClipTimeline(audioDuration: 2.0)
        XCTAssertEqual(tl.motion(at: 0, spec: spec), .intro)
        XCTAssertEqual(tl.motion(at: 0.25, spec: spec), .talk)
        XCTAssertEqual(tl.motion(at: 2.24, spec: spec), .talk)
        XCTAssertEqual(tl.motion(at: 2.25, spec: spec), .outro)
        XCTAssertNil(tl.gestureWindow(spec: spec))
        XCTAssertEqual(tl.frame(at: 0, spec: spec), spec.animation(.intro)!.frames.first)
        XCTAssertEqual(tl.frame(at: tl.totalDuration, spec: spec), spec.animation(.outro)!.frames.last)
        let long = CrewClipTimeline(audioDuration: 6)
        let g = try XCTUnwrap(long.gestureWindow(spec: spec))
        XCTAssertEqual((g.lowerBound + g.upperBound) / 2, 3, accuracy: 1e-9)
        XCTAssertEqual(long.motion(at: long.audioStart + 3, spec: spec), .gesture)
    }

    func testSheetOriginsAndClipKey() throws {
        let spec = try shippedSpec(.bodieHale)
        XCTAssertEqual(spec.origin(ofFrame: 0).x, 0)
        XCTAssertEqual(spec.origin(ofFrame: spec.columns).y, spec.frameSize)
        XCTAssertEqual(CrewTalkMember.pearl.spriteSheetAssetName, "crewPearlSheet")
        let a = CrewClipKey.make(crew: .pearl, line: "Hi", audioFileName: "x.mp3")
        XCTAssertEqual(a, CrewClipKey.make(crew: .pearl, line: "Hi", audioFileName: "x.mp3"))
        XCTAssertNotEqual(a, CrewClipKey.make(crew: .bodieHale, line: "Hi", audioFileName: "x.mp3"))
    }
}
