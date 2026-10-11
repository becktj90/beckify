import Foundation

// Crew Talk pixel animations. Sheets are made once by ios/Art/CrewTalk/build_sprites.py and shipped
// in the asset catalog; nothing is generated at runtime. This file is the pure timing half, shared by
// the on-card player and the video clip builder, so it runs in `swift test` on Linux.

/// One named loop or beat on a sprite sheet.
public struct CrewSpriteAnimation: Codable, Equatable, Sendable {
    public let frames: [Int]
    public let fps: Double
    public let loop: Bool

    public init(frames: [Int], fps: Double, loop: Bool) {
        self.frames = frames
        self.fps = fps
        self.loop = loop
    }

    /// Length of one pass through the frames.
    public var duration: TimeInterval {
        guard fps > 0 else { return 0 }
        return Double(frames.count) / fps
    }

    /// Sheet frame index shown `elapsed` seconds into this animation. One-shot animations hold the last frame.
    public func frame(at elapsed: TimeInterval) -> Int {
        guard !frames.isEmpty else { return 0 }
        guard fps > 0, elapsed.isFinite else { return frames[0] }
        // A hair of slack so 0.1 * 10 lands on frame 1, not frame 0.
        let step = Int((max(elapsed, 0) * fps + 1e-9).rounded(.down))
        return loop ? frames[step % frames.count] : frames[min(step, frames.count - 1)]
    }

    /// Sheet frame for a one-shot squeezed into `window` seconds (`progress` 0...1).
    public func frame(progress: Double) -> Int {
        guard !frames.isEmpty else { return 0 }
        let p = min(max(progress.isFinite ? progress : 0, 0), 1)
        return frames[min(Int(p * Double(frames.count)), frames.count - 1)]
    }
}

public enum CrewSpriteMotion: String, CaseIterable, Sendable {
    case idle, talk, gesture, intro, outro
}

/// The JSON written next to each `<asset>Sheet.png`.
public struct CrewSpriteSheetSpec: Codable, Equatable, Sendable {
    public let frameSize: Int
    public let columns: Int
    public let frameCount: Int
    public let animations: [String: CrewSpriteAnimation]

    public init(frameSize: Int, columns: Int, frameCount: Int, animations: [String: CrewSpriteAnimation]) {
        self.frameSize = frameSize
        self.columns = columns
        self.frameCount = frameCount
        self.animations = animations
    }

    public static func decode(_ data: Data) throws -> CrewSpriteSheetSpec {
        try JSONDecoder().decode(CrewSpriteSheetSpec.self, from: data)
    }

    public func animation(_ motion: CrewSpriteMotion) -> CrewSpriteAnimation? {
        animations[motion.rawValue]
    }

    /// Top-left pixel of a frame on the sheet.
    public func origin(ofFrame index: Int) -> (x: Int, y: Int) {
        let cols = max(columns, 1)
        let i = min(max(index, 0), max(frameCount - 1, 0))
        return ((i % cols) * frameSize, (i / cols) * frameSize)
    }

    /// True when every frame an animation names exists on the sheet.
    public var isConsistent: Bool {
        frameSize > 0 && columns > 0 && frameCount > 0
            && CrewSpriteMotion.allCases.allSatisfy { animations[$0.rawValue] != nil }
            && animations.values.allSatisfy { anim in
                anim.fps > 0 && !anim.frames.isEmpty && anim.frames.allSatisfy { (0..<frameCount).contains($0) }
            }
    }
}

public extension CrewTalkMember {
    /// Sprite sheet image and its `.dataset` timing JSON share this name.
    var spriteSheetAssetName: String { portraitAssetName + "Sheet" }
    /// Data asset name for frame timing (must differ from the imageset name).
    var spriteTimingAssetName: String { portraitAssetName + "SheetTiming" }
}

/// Frame plan for a shareable clip: a short scan-in, the talk loop for exactly the audio, a scan-out.
/// The video runs `lead + audio + tail`; the voice starts at `lead`.
public struct CrewClipTimeline: Equatable, Sendable {
    public static let lead: TimeInterval = 0.25
    public static let tail: TimeInterval = 0.25
    public static let framesPerSecond: Int = 24
    /// Audio at least this long gets one emphasis gesture in the middle.
    public static let gestureMinimumAudio: TimeInterval = 3.0
    /// Longest clip we will build (iMessage-friendly).
    public static let maximumAudio: TimeInterval = 120

    public let audioDuration: TimeInterval

    public init(audioDuration: TimeInterval) {
        let d = audioDuration.isFinite ? audioDuration : 0
        self.audioDuration = min(max(d, 0), Self.maximumAudio)
    }

    public var audioStart: TimeInterval { Self.lead }
    public var audioEnd: TimeInterval { Self.lead + audioDuration }
    public var totalDuration: TimeInterval { Self.lead + audioDuration + Self.tail }
    public var frameCount: Int { Int((totalDuration * Double(Self.framesPerSecond)).rounded(.up)) }

    public func time(ofFrame index: Int) -> TimeInterval {
        Double(index) / Double(Self.framesPerSecond)
    }

    /// Which motion is on screen at `t`.
    public func motion(at t: TimeInterval, spec: CrewSpriteSheetSpec) -> CrewSpriteMotion {
        if t < audioStart { return .intro }
        if t >= audioEnd { return .outro }
        if let window = gestureWindow(spec: spec), window.contains(t - audioStart) { return .gesture }
        return .talk
    }

    /// Gesture window in audio-relative seconds, centered on the line.
    public func gestureWindow(spec: CrewSpriteSheetSpec) -> Range<TimeInterval>? {
        guard audioDuration >= Self.gestureMinimumAudio, let g = spec.animation(.gesture), g.duration > 0 else { return nil }
        let start = (audioDuration - g.duration) / 2
        return start..<(start + g.duration)
    }

    /// Sheet frame at `t` seconds into the clip.
    public func frame(at t: TimeInterval, spec: CrewSpriteSheetSpec) -> Int {
        let motion = motion(at: t, spec: spec)
        guard let anim = spec.animation(motion) else { return 0 }
        switch motion {
        case .intro: return anim.frame(progress: t / Self.lead)
        case .outro: return anim.frame(progress: (t - audioEnd) / Self.tail)
        case .gesture:
            let start = gestureWindow(spec: spec)?.lowerBound ?? 0
            return anim.frame(at: t - audioStart - start)
        case .talk, .idle: return anim.frame(at: t - audioStart)
        }
    }
}

/// Cache key for one clip: same voice, same line, same audio file → same video.
public enum CrewClipKey {
    public static func make(crew: CrewTalkMember, line: String, audioFileName: String) -> String {
        let text = "\(crew.rawValue)|\(line)|\(audioFileName)"
        // FNV-1a 64; stable across launches (Swift's Hasher is not).
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in text.utf8 { h = (h ^ UInt64(b)) &* 0x100_0000_01b3 }
        return String(h, radix: 16)
    }
}
