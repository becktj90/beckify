import SwiftUI
import AVFoundation
import Speech
import BeckifyMath

/// Toolkit → Reference: record English → Beckify AI Cuban / Florida LatAm Spanish → loud TTS.
struct SpanishTranslatorView: View {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var engine = SpanishTranslatorEngine()
    @State private var typedEnglish = ""
    @State private var customEndpoint = ""
    @State private var apiToken = ""
    @State private var showAdvanced = false

    var body: some View {
        ToolScaffold(
            toolID: .spanishTranslator,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .designAidExtra(SpanishTranslatorAPI.disclaimer)
        ) {
            statusCard
            recordCard
            textCards
            speakCard
            if showAdvanced {
                advancedCard
            } else {
                Button("API endpoint / token (optional)") {
                    showAdvanced = true
                }
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
            }
            if let err = engine.errorMessage, !err.isEmpty {
                Text(err)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.warn)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                engine.stopListening(translateAfter: false)
                engine.stopSpeaking()
            }
        }
        .onDisappear {
            engine.stopListening(translateAfter: false)
            engine.stopSpeaking()
        }
    }

    private var sticky: String {
        let status = engine.statusLabel
        if !engine.spanishText.isEmpty {
            return "\(status) · \(engine.spanishText)"
        }
        if !engine.englishText.isEmpty {
            return "\(status) · \(engine.englishText)"
        }
        return status
    }

    private var copyText: String {
        var lines = ["Spanish Translator"]
        if !engine.englishText.isEmpty { lines.append("EN: \(engine.englishText)") }
        if !engine.spanishText.isEmpty { lines.append("ES: \(engine.spanishText)") }
        if !engine.dialectLabel.isEmpty { lines.append(engine.dialectLabel) }
        if !engine.voiceNote.isEmpty { lines.append(engine.voiceNote) }
        lines.append(SpanishTranslatorAPI.disclaimer)
        return lines.joined(separator: "\n")
    }

    private var statusCard: some View {
        ResultCard(title: "Status", copyText: engine.statusLabel) {
            ResultRow(label: "Phase", value: engine.statusLabel, emphasis: true, tone: statusTone)
            if !engine.engineLabel.isEmpty {
                ResultRow(label: "Engine", value: engine.engineLabel)
            }
            if !engine.dialectLabel.isEmpty {
                ResultRow(label: "Dialect", value: engine.dialectLabel)
            }
            if !engine.voiceNote.isEmpty {
                ResultRow(label: "Voice", value: engine.voiceNote)
            }
            Text("Listening → Translating → Speaking. Hold the phone so the bottom mic hears you clearly.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .padding(.top, 4)
        }
    }

    private var statusTone: Color {
        switch engine.phase {
        case .listening: return Theme.good
        case .translating: return Theme.copper
        case .speaking: return Theme.warn
        case .error: return Theme.warn
        case .idle: return Theme.muted
        }
    }

    private var recordCard: some View {
        VStack(spacing: 14) {
            Button {
                if engine.phase == .listening {
                    engine.stopListening(translateAfter: true)
                } else {
                    engine.startListening(customEndpoint: customEndpoint, token: apiToken)
                }
            } label: {
                Label(
                    engine.phase == .listening ? "Stop" : "Record",
                    systemImage: engine.phase == .listening ? "stop.circle.fill" : "mic.circle.fill"
                )
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 72)
            }
            .buttonStyle(.borderedProminent)
            .tint(engine.phase == .listening ? Theme.warn : Theme.copper)
            .accessibilityIdentifier("spanishTranslator.record")

            HStack(spacing: 12) {
                Button {
                    let typed = typedEnglish.trimmingCharacters(in: .whitespacesAndNewlines)
                    let source = typed.isEmpty ? engine.englishText : typed
                    engine.translateText(
                        source,
                        customEndpoint: customEndpoint,
                        token: apiToken
                    )
                } label: {
                    Label("Translate", systemImage: "globe")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(engine.englishText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && typedEnglish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || engine.phase == .listening
                    || engine.phase == .translating)

                Button {
                    engine.speakSpanishAgain()
                } label: {
                    Label("Speak again", systemImage: "speaker.wave.3.fill")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.good)
                .disabled(engine.spanishText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || engine.phase == .listening)
                .accessibilityIdentifier("spanishTranslator.speakAgain")
            }

            TextField("Or type English here", text: $typedEnglish, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
                .onSubmit {
                    engine.translateText(typedEnglish, customEndpoint: customEndpoint, token: apiToken)
                }
        }
        .padding(.vertical, 4)
    }

    private var textCards: some View {
        VStack(spacing: 12) {
            ResultCard(title: "English (heard / typed)", copyText: engine.englishText) {
                Text(engine.englishText.isEmpty ? "—" : engine.englishText)
                    .font(Theme.TypeRole.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            ResultCard(title: "Spanish (Cuban / Florida LatAm)", copyText: engine.spanishText) {
                Text(engine.spanishText.isEmpty ? "—" : engine.spanishText)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }

    private var speakCard: some View {
        ResultCard(title: "Loud playback", copyText: engine.voiceNote) {
            Text("Playback uses maximum utterance volume and routes to the speaker. Media volume still matters — turn the Ring/Silent switch up if the phone is muted for media.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
        }
    }

    private var advancedCard: some View {
        ResultCard(title: "Beckify API", copyText: endpointHint) {
            Text(endpointHint)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
            TextField("Custom HTTPS translate URL (optional)", text: $customEndpoint)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            SecureField("Bearer token for custom endpoint only", text: $apiToken)
                .textFieldStyle(.roundedBorder)
            Text("Leave blank to use https://api.beckify.com/api/translate. A personal token is not sent to Beckify unless you set a custom URL.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
        }
    }

    private var endpointHint: String {
        if SpanishTranslatorAPI.translateURL(customEndpoint: customEndpoint) != nil,
           PhotoLookCheck.httpsBase(customEndpoint) != nil {
            return "Custom translate URL is set."
        }
        return "Uses https://api.beckify.com/api/translate when the custom URL is blank."
    }
}

// MARK: - Engine

@MainActor
final class SpanishTranslatorEngine: NSObject, ObservableObject {
    enum Phase: Equatable {
        case idle, listening, translating, speaking, error
    }

    @Published var phase: Phase = .idle
    @Published var englishText = ""
    @Published var spanishText = ""
    @Published var dialectLabel = ""
    @Published var engineLabel = ""
    @Published var voiceNote = ""
    @Published var errorMessage: String?
    @Published var statusLabel = "Ready"

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private var selectedVoice: AVSpeechSynthesisVoice?
    private var pendingCustomEndpoint = ""
    private var pendingToken = ""

    override init() {
        super.init()
        synthesizer.delegate = self
        refreshVoice()
    }

    func startListening(customEndpoint: String = "", token: String = "") {
        pendingCustomEndpoint = customEndpoint
        pendingToken = token
        errorMessage = nil
        stopSpeaking()
        spanishText = ""
        dialectLabel = ""
        engineLabel = ""

        SFSpeechRecognizer.requestAuthorization { [weak self] auth in
            Task { @MainActor in
                guard let self else { return }
                switch auth {
                case .authorized:
                    self.beginRecognition()
                case .denied, .restricted:
                    self.phase = .error
                    self.statusLabel = "Speech recognition blocked"
                    self.errorMessage = "Enable Speech Recognition for Beckify in Settings."
                case .notDetermined:
                    self.phase = .error
                    self.statusLabel = "Speech recognition needed"
                    self.errorMessage = "Allow Speech Recognition when prompted."
                @unknown default:
                    self.phase = .error
                    self.statusLabel = "Speech recognition unavailable"
                }
            }
        }
    }

    func stopListening(translateAfter: Bool) {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        let source = englishText.trimmingCharacters(in: .whitespacesAndNewlines)
        if translateAfter, !source.isEmpty {
            translateText(source, customEndpoint: pendingCustomEndpoint, token: pendingToken)
        } else if phase == .listening {
            phase = .idle
            statusLabel = source.isEmpty ? "Ready" : "Ready to translate"
        }
    }

    func translateText(_ raw: String, customEndpoint: String, token: String) {
        pendingCustomEndpoint = customEndpoint
        pendingToken = token
        let source = SpanishTranslatorAPI.clampSourceText(raw)
        guard !source.isEmpty else {
            errorMessage = "Say or type something in English first."
            return
        }
        englishText = source
        phase = .translating
        statusLabel = "Translating"
        errorMessage = nil
        engineLabel = "Beckify API…"

        Task {
            do {
                let draft = try await Self.postTranslate(
                    text: source,
                    customEndpoint: customEndpoint,
                    token: token
                )
                applyDraft(draft)
                speakSpanish(draft.translation)
            } catch {
                phase = .error
                statusLabel = "Translate failed"
                engineLabel = ""
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
                // English text stays on screen for retry when the Beckify API returns.
            }
        }
    }

    func speakSpanishAgain() {
        let text = spanishText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        speakSpanish(text)
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func applyDraft(_ draft: SpanishTranslationDraft) {
        spanishText = draft.translation
        dialectLabel = draft.displayDialect
        if draft.engine == "apple" {
            engineLabel = "Apple Translation (on-device fallback)"
        } else if !draft.provider.isEmpty {
            engineLabel = "Beckify API · \(draft.provider)"
                + (draft.model.isEmpty ? "" : " · \(draft.model)")
        } else {
            engineLabel = "Beckify API"
        }
    }

    private func beginRecognition() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            phase = .error
            statusLabel = "Recognizer unavailable"
            errorMessage = "English speech recognition is not available on this device right now."
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try session.overrideOutputAudioPort(.speaker)
        } catch {
            phase = .error
            statusLabel = "Audio session failed"
            errorMessage = error.localizedDescription
            return
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            phase = .error
            statusLabel = "Mic failed"
            errorMessage = error.localizedDescription
            return
        }

        phase = .listening
        statusLabel = "Listening"
        englishText = ""

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.englishText = result.bestTranscription.formattedString
                }
                if let error, self.phase == .listening {
                    // Ignore benign end-of-audio cancellations after Stop.
                    let ns = error as NSError
                    if ns.domain == "kAFAssistantErrorDomain", ns.code == 1110 { return }
                    if !self.englishText.isEmpty { return }
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func refreshVoice() {
        let languages = AVSpeechSynthesisVoice.speechVoices().map(\.language)
        let bestLang = SpanishTranslatorAPI.bestSpanishVoiceLanguage(from: languages)
        if let bestLang {
            selectedVoice = AVSpeechSynthesisVoice.speechVoices()
                .filter { $0.language.caseInsensitiveCompare(bestLang) == .orderedSame }
                .sorted { $0.quality.rawValue > $1.quality.rawValue }
                .first
                ?? AVSpeechSynthesisVoice(language: bestLang)
        } else {
            selectedVoice = AVSpeechSynthesisVoice(language: "es-US")
                ?? AVSpeechSynthesisVoice(language: "es-MX")
                ?? AVSpeechSynthesisVoice(language: "es-ES")
        }
        voiceNote = SpanishTranslatorAPI.voiceFallbackNote(selectedLanguage: selectedVoice?.language)
    }

    private func speakSpanish(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        refreshVoice()
        stopSpeaking()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try session.overrideOutputAudioPort(.speaker)
        } catch {
            // Still attempt utterance; route may already be speaker.
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = selectedVoice
        utterance.volume = 1.0
        // Slightly under default rate for field intelligibility while staying loud/clear.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.05

        phase = .speaking
        statusLabel = "Speaking"
        synthesizer.speak(utterance)
    }

    private static func postTranslate(
        text: String,
        customEndpoint: String,
        token: String
    ) async throws -> SpanishTranslationDraft {
        guard let url = SpanishTranslatorAPI.translateURL(customEndpoint: customEndpoint) else {
            throw VisionHTTPError(
                status: 0,
                message: "Translate needs an HTTPS endpoint. Leave the custom URL blank to use api.beckify.com, or enter a https:// URL."
            )
        }
        let body = try SpanishTranslatorAPI.requestJSON(text: text)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        let auth = SpanishTranslatorAPI.authorizationToken(customEndpoint: customEndpoint, token: token)
        if !auth.isEmpty {
            request.setValue("Bearer \(auth)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw VisionHTTPError(status: 0, message: error.localizedDescription)
        }
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if status < 200 || status >= 300 {
            let message = SpanishTranslatorAPI.formatTranslateError(
                status: status,
                message: payload["error"] as? String,
                endpoint: url.absoluteString
            )
            throw VisionHTTPError(status: status, message: message)
        }
        guard let draft = SpanishTranslatorAPI.normalizeDraft(payload, fallbackSource: text) else {
            throw VisionHTTPError(status: status, message: "Translate returned no Spanish text.")
        }
        return draft
    }

}

extension SpanishTranslatorEngine: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if phase == .speaking {
                phase = .idle
                statusLabel = "Ready"
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if phase == .speaking {
                phase = .idle
                statusLabel = "Ready"
            }
        }
    }
}
