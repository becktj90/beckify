import Foundation

/// Pure decisions behind Crew Talk "Make clip". The renderer (AVAssetWriter) lives in the app;
/// everything here is testable on Linux.
///
/// Root cause of the 1.0.6 (302–308) "Make clip does nothing" bug: the renderer appended every
/// video frame before any audio. AVAssetWriter interleaves its inputs, so once video got ~1 s
/// ahead it stopped reporting `isReadyForMoreMediaData` and waited for audio that never came —
/// the render loop spun forever and no clip was produced. `CrewClipMux.next` always feeds the
/// stream that is behind and never waits on one input while the other is ready.
public enum CrewClipMux {
    public enum Step: Equatable, Sendable { case video, audio, wait, finish }

    public static func next(
        videoRemaining: Bool, videoReady: Bool, videoTime: Double,
        audioRemaining: Bool, audioReady: Bool, audioTime: Double
    ) -> Step {
        if !videoRemaining && !audioRemaining { return .finish }
        let canVideo = videoRemaining && videoReady
        let canAudio = audioRemaining && audioReady
        switch (canVideo, canAudio) {
        case (true, true): return videoTime <= audioTime ? .video : .audio
        case (true, false): return .video
        case (false, true): return .audio
        case (false, false): return .wait
        }
    }
}

/// Where the clip's voice comes from.
public enum CrewClipAudioSource: Equatable, Sendable {
    case cached
    case fetch

    /// Reuse the Speak recording only when it exists on disk and was made by the same helper for
    /// the same line. Otherwise fetch the ElevenLabs voice again (no playback).
    public static func resolve(
        hasCachedFile: Bool,
        cachedCrew: CrewTalkMember?, crew: CrewTalkMember,
        cachedLine: String?, line: String
    ) -> CrewClipAudioSource {
        guard hasCachedFile, cachedCrew == crew,
              let cachedLine, cachedLine.trimmingCharacters(in: .whitespacesAndNewlines)
                == line.trimmingCharacters(in: .whitespacesAndNewlines)
        else { return .fetch }
        return .cached
    }
}

/// Determinate progress for the clip render: frames written / total.
public struct CrewClipProgress: Equatable, Sendable {
    /// Show the bar (with Cancel) only when a render runs longer than this.
    public static let showAfter: TimeInterval = 1.0

    public var framesDone: Int
    public var totalFrames: Int

    public init(framesDone: Int, totalFrames: Int) {
        self.framesDone = framesDone
        self.totalFrames = totalFrames
    }

    public var fraction: Double {
        guard totalFrames > 0 else { return 0 }
        return min(max(Double(framesDone) / Double(totalFrames), 0), 1)
    }

    public var percentLabel: String { "\(Int((fraction * 100).rounded(.down)))%" }

    public static func shouldShowBar(elapsed: TimeInterval, finished: Bool) -> Bool {
        !finished && elapsed >= showAfter
    }
}

/// Picking a different helper after a translation exists re-runs the line in the new voice.
/// Quick swipes through the roster are debounced; only the last pick fires.
public struct CrewHelperSwitchState: Equatable, Sendable {
    public static let debounce: TimeInterval = 0.3

    public enum Action: Equatable, Sendable {
        case none
        /// Cancel in-flight translate/speak now, then fire `token` after `debounce`.
        case cancelAndSchedule(token: UInt64)
    }

    public private(set) var crew: CrewTalkMember
    public private(set) var pendingToken: UInt64 = 0
    public private(set) var pendingSource: String?

    public init(crew: CrewTalkMember) { self.crew = crew }

    /// - Parameters:
    ///   - source: what the person said/typed for the current result.
    ///   - hasResult: a translation/rewrite is already on screen (or in flight).
    public mutating func helperChanged(to next: CrewTalkMember, source: String, hasResult: Bool) -> Action {
        let changed = next != crew
        crew = next
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard changed, hasResult, !trimmed.isEmpty else { return .none }
        pendingToken &+= 1
        pendingSource = trimmed
        return .cancelAndSchedule(token: pendingToken)
    }

    /// Debounce timer fired. Returns the line to translate if this is still the latest pick.
    public mutating func fire(token: UInt64) -> String? {
        guard token == pendingToken, let source = pendingSource else { return nil }
        pendingSource = nil
        return source
    }

    /// A new typed/spoken turn or a direction flip supersedes any pending re-run.
    public mutating func reset(crew: CrewTalkMember) {
        self.crew = crew
        pendingToken &+= 1
        pendingSource = nil
    }
}
