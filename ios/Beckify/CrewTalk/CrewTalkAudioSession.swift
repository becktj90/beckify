import AVFoundation
import Foundation

/// Audio session setup for Conversation Mode. Mirrors the main Crew Talk screen:
/// record on the speaker-friendly route, then play loud.
enum CrewTalkAudioSession {
    static func configureForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        // allowBluetoothHFP not in Xcode 16.4 SDK; rename when CI upgrades.
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        try session.overrideOutputAudioPort(.speaker)
    }

    /// Best effort. The route may already be the speaker.
    static func configureForPlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try session.overrideOutputAudioPort(.speaker)
        } catch {
            // Still attempt playback.
        }
    }
}

/// Error text the Conversation screen can show as-is.
struct CrewTalkConversationError: LocalizedError {
    var message: String
    /// True when retrying cannot help, such as a room that no longer exists.
    var fatal: Bool = false
    var errorDescription: String? { message }
}
