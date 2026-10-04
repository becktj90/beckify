import AVFoundation
import BeckifyMath
import Foundation

/// Plays one line to the end. Neural audio first. Apple's voice is the fallback.
@MainActor
final class CrewTalkSpeechOutput: NSObject {
    private var player: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Returns when playback finishes or `stop()` is called.
    func play(audio data: Data) async throws {
        stop()
        CrewTalkAudioSession.configureForPlayback()
        let player = try AVAudioPlayer(data: data)
        player.delegate = self
        player.volume = 1.0
        player.prepareToPlay()
        self.player = player
        guard player.play() else {
            self.player = nil
            throw CrewTalkConversationError(message: "Audio would not start.")
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.continuation = continuation
        }
    }

    /// Apple voice at the character's pace. Used only when cloud speech fails.
    func speak(apple text: String, crew: CrewTalkMember) async {
        stop()
        CrewTalkAudioSession.configureForPlayback()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: crew.speakLanguage == "es" ? "es-US" : "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * crew.appleRateFactor
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.continuation = continuation
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        player?.stop()
        player = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        finish()
    }

    /// A late callback from a player that was already replaced must not end the new line.
    fileprivate func playerEnded(_ id: ObjectIdentifier) {
        guard let current = player, ObjectIdentifier(current) == id else { return }
        player = nil
        finish()
    }

    private func finish() {
        let pending = continuation
        continuation = nil
        pending?.resume()
    }
}

extension CrewTalkSpeechOutput: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let id = ObjectIdentifier(player)
        Task { @MainActor in self.playerEnded(id) }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let id = ObjectIdentifier(player)
        Task { @MainActor in self.playerEnded(id) }
    }
}

extension CrewTalkSpeechOutput: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finish() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finish() }
    }
}
