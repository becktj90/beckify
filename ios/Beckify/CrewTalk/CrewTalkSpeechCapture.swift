import AVFoundation
import BeckifyMath
import Foundation
import Speech

/// One-shot microphone capture for a single turn. On-device recognition when the
/// device supports it. The caller taps to start and taps to stop.
@MainActor
final class CrewTalkSpeechCapture {
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var generation: UInt64 = 0
    private(set) var transcript = ""

    /// Called on the main actor with every partial transcript.
    var onPartial: ((String) -> Void)?

    static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    func start(language: CrewTalkConversationLanguage) throws {
        cancel()
        let direction = language.speakingDirection
        let available = SFSpeechRecognizer.supportedLocales().map(\.identifier)
        guard let localeID = SpanishTranslatorAPI.bestSpeechLocale(direction: direction, available: available),
              let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID)),
              recognizer.isAvailable else {
            throw CrewTalkConversationError(message: SpanishTranslatorAPI.speechUnavailableMessage(direction: direction))
        }

        try CrewTalkAudioSession.configureForRecording()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request
        transcript = ""
        generation &+= 1
        let token = generation

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            input.removeTap(onBus: 0)
            self.request = nil
            throw CrewTalkConversationError(message: "Mic failed: \(error.localizedDescription)")
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let heard = result?.bestTranscription.formattedString else { return }
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                self.transcript = heard
                self.onPartial?(heard)
            }
        }
    }

    /// Stop the mic, give the recognizer a moment to settle, and return the final text.
    func stop() async -> String {
        let token = generation
        finishAudio()
        // Let the last partial land before we read it.
        try? await Task.sleep(nanoseconds: 350_000_000)
        guard generation == token else { return transcript }
        task?.finish()
        task = nil
        request = nil
        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func cancel() {
        generation &+= 1
        finishAudio()
        task?.cancel()
        task = nil
        request = nil
        transcript = ""
    }

    private func finishAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
    }
}
