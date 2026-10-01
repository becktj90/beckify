import SwiftUI
import AVFoundation
import Speech
import Translation
import BeckifyMath

/// Toolkit → Reference: record English → Beckify AI Spanish (Clean / Jobsite) → OpenAI neural TTS (Apple fallback).
/// Falls back to on-device Apple Translation (iOS 18+) when `/api/translate` fails.
struct SpanishTranslatorView: View {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var engine = SpanishTranslatorEngine()
    @AppStorage(SpanishVoiceMode.storageKey) private var voiceModeRaw = SpanishVoiceMode.jobsite.rawValue
    @State private var typedEnglish = ""
    @State private var customEndpoint = ""
    @State private var apiToken = ""
    @State private var showAdvanced = false
    @State private var lastTestPhrase = ""
    @State private var lastAttentionPhrase = ""

    private var voiceMode: SpanishVoiceMode {
        get { SpanishVoiceMode.parse(voiceModeRaw) }
        nonmutating set { voiceModeRaw = newValue.rawValue }
    }

    var body: some View {
        ToolScaffold(
            toolID: .spanishTranslator,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .designAidExtra(SpanishTranslatorAPI.disclaimer)
        ) {
            statusCard
            modeCard
            attentionCard
            recordCard
            quickPhrasesCard
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
        .spanishOnDeviceTranslation(
            requestID: engine.onDeviceRequestID,
            english: engine.pendingOnDeviceEnglish
        ) { result in
            engine.handleOnDeviceResult(result)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                engine.stopListening(translateAfter: false)
                engine.stopSpeaking()
            }
        }
        .onAppear { engine.voiceMode = voiceMode }
        .onChange(of: voiceModeRaw) { _, raw in
            engine.voiceMode = SpanishVoiceMode.parse(raw)
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
        if !engine.engineLabel.isEmpty { lines.append(engine.engineLabel) }
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
            Text("Listening → Translating → Speaking. Pick Clean or Jobsite, then tap Hey! for a short attention call, or record, type, tap a chip, or Test. Beckify AI rewrites on the selected mode. On-device Apple Translation (iOS 18+) is the fallback when the API is down. Playback prefers OpenAI neural TTS from api.beckify.com; Apple AVSpeech if that fails. Hold the phone so the bottom mic hears you clearly.")
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
        case .idle:
            if engine.statusLabel == SpanishTranslatorAPI.statusViaBeckifyAI
                || engine.statusLabel == SpanishTranslatorAPI.statusOnDevice {
                return Theme.good
            }
            return Theme.muted
        }
    }

    private var modeCard: some View {
        ResultCard(title: "Mode", copyText: voiceMode.uiLabel) {
            Picker("Mode", selection: $voiceModeRaw) {
                ForEach(SpanishVoiceMode.allCases, id: \.rawValue) { mode in
                    Text(mode.uiLabel).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("spanishTranslator.voiceMode")
            Text(voiceMode == .clean
                 ? "Clean: polished, warm Spanish. Jobsite: rough banter on the same Beckify AI path."
                 : "Jobsite: rough banter Spanish. Clean: polished and warm on the same Beckify AI path.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .padding(.top, 4)
        }
    }

    private var attentionCard: some View {
        VStack(spacing: 8) {
            Button {
                let phrase = SpanishTranslatorAPI.nextAttentionCallPhrase(excluding: lastAttentionPhrase)
                lastAttentionPhrase = phrase
                typedEnglish = phrase
                engine.voiceMode = voiceMode
                engine.translateText(
                    phrase,
                    customEndpoint: customEndpoint,
                    token: apiToken
                )
            } label: {
                Label(SpanishTranslatorAPI.attentionButtonTitle, systemImage: "hand.wave.fill")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: 76)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.warn)
            .disabled(engine.phase == .listening || engine.phase == .translating)
            .accessibilityIdentifier("spanishTranslator.attention")
            .accessibilityLabel(SpanishTranslatorAPI.attentionButtonAccessibilityLabel)

            Text(SpanishTranslatorAPI.attentionButtonHelp)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private var recordCard: some View {
        VStack(spacing: 14) {
            Button {
                if engine.phase == .listening {
                    engine.stopListening(translateAfter: true)
                } else {
                    engine.voiceMode = voiceMode
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
                    engine.voiceMode = voiceMode
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

            Button {
                let phrase = SpanishTranslatorAPI.nextRandomTestPhrase(excluding: lastTestPhrase)
                lastTestPhrase = phrase
                typedEnglish = phrase
                engine.voiceMode = voiceMode
                engine.translateText(
                    phrase,
                    customEndpoint: customEndpoint,
                    token: apiToken
                )
            } label: {
                Label("Test", systemImage: "shuffle")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.copper)
            .disabled(engine.phase == .listening || engine.phase == .translating)
            .accessibilityIdentifier("spanishTranslator.testRandom")
            .accessibilityLabel("Test with a random phrase")

            TextField("Or type English here", text: $typedEnglish, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
                .onSubmit {
                    engine.voiceMode = voiceMode
                    engine.translateText(typedEnglish, customEndpoint: customEndpoint, token: apiToken)
                }
        }
        .padding(.vertical, 4)
    }

    private var quickPhrasesCard: some View {
        ResultCard(title: "Quick lines", copyText: SpanishTranslatorAPI.quickTranslatePhrases.joined(separator: " · ")) {
            Text("Tap a chip to fill English and run Beckify AI translate + speak on the selected mode.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(SpanishTranslatorAPI.quickTranslatePhrases.enumerated()), id: \.offset) { index, phrase in
                        Button {
                            typedEnglish = phrase
                            engine.voiceMode = voiceMode
                            engine.translateText(
                                phrase,
                                customEndpoint: customEndpoint,
                                token: apiToken
                            )
                        } label: {
                            Text(phrase)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.foreground)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Theme.surfaceRaised.opacity(0.9), in: Capsule(style: .continuous))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Theme.border, lineWidth: 1)
                                )
                                .frame(minHeight: Theme.touchTarget)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(engine.phase == .listening || engine.phase == .translating)
                        .accessibilityIdentifier("spanishTranslator.quickPhrase.\(index)")
                        .accessibilityLabel("Quick translate: \(phrase)")
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var textCards: some View {

        VStack(spacing: 12) {
            ResultCard(title: "English (heard / typed)", copyText: engine.englishText) {
                Text(engine.englishText.isEmpty ? "—" : engine.englishText)
                    .font(Theme.TypeRole.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            ResultCard(title: "Spanish", copyText: engine.spanishText) {
                Text(engine.spanishText.isEmpty ? "—" : engine.spanishText)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }

    private var speakCard: some View {
        ResultCard(title: "Loud playback", copyText: engine.voiceNote) {
            Text("Loud playback: OpenAI neural TTS from api.beckify.com (voice follows Clean / Jobsite). Falls back to an Apple Spanish voice if cloud TTS fails. Media volume still matters if the phone is muted.")
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
            Text("Leave blank to use https://api.beckify.com/api/translate. A personal token is not sent to Beckify unless you set a custom URL. If the API fails, the app tries on-device Apple Translation on iOS 18+.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
        }
    }

    private var endpointHint: String {
        if SpanishTranslatorAPI.translateURL(customEndpoint: customEndpoint) != nil,
           PhotoLookCheck.httpsBase(customEndpoint) != nil {
            return "Custom translate URL is set."
        }
        return "Uses https://api.beckify.com/api/translate and /api/speak when the custom URL is blank. On-device Apple Translation + Apple TTS are fallbacks."
    }
}

// MARK: - On-device Translation (iOS 18+)

extension View {
    /// Triggers Apple TranslationSession when `requestID` increments (API fallback path).
    @ViewBuilder
    func spanishOnDeviceTranslation(
        requestID: UInt64,
        english: String,
        onResult: @escaping (Result<(text: String, targetLanguageID: String), Error>) -> Void
    ) -> some View {
        if #available(iOS 18.0, *) {
            modifier(
                SpanishOnDeviceTranslationModifier(
                    requestID: requestID,
                    english: english,
                    onResult: onResult
                )
            )
        } else {
            self
        }
    }
}

@available(iOS 18.0, *)
private struct SpanishOnDeviceTranslationModifier: ViewModifier {
    let requestID: UInt64
    let english: String
    let onResult: (Result<(text: String, targetLanguageID: String), Error>) -> Void

    @State private var configuration: TranslationSession.Configuration?
    @State private var activeTargetID = "es"

    func body(content: Content) -> some View {
        content
            .translationTask(configuration) { session in
                let source = english.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !source.isEmpty else { return }
                do {
                    try await session.prepareTranslation()
                    let response = try await session.translate(source)
                    let translated = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !translated.isEmpty else {
                        await MainActor.run {
                            onResult(.failure(
                                NSError(
                                    domain: "BeckifySpanishTranslator",
                                    code: 1,
                                    userInfo: [NSLocalizedDescriptionKey: "On-device translation returned empty Spanish."]
                                )
                            ))
                        }
                        return
                    }
                    let targetID = activeTargetID
                    await MainActor.run {
                        onResult(.success((text: translated, targetLanguageID: targetID)))
                    }
                } catch {
                    await MainActor.run {
                        onResult(.failure(error))
                    }
                }
            }
            .onChange(of: requestID) { _, newID in
                guard newID > 0 else { return }
                Task { @MainActor in
                    await armConfiguration()
                }
            }
    }

    @MainActor
    private func armConfiguration() async {
        let source = Locale.Language(identifier: "en")
        let targetID = await Self.preferredSpanishTargetID()
        activeTargetID = targetID
        let target = Locale.Language(identifier: targetID)
        if var config = configuration {
            config.source = source
            config.target = target
            config.invalidate()
            configuration = config
        } else {
            configuration = TranslationSession.Configuration(source: source, target: target)
        }
    }

    /// Prefer common Spanish locale pairs when Apple has them installed or downloadable.
    private static func preferredSpanishTargetID() async -> String {
        let availability = LanguageAvailability()
        let source = Locale.Language(identifier: "en")
        for id in SpanishTranslatorAPI.preferredAppleSpanishLanguageIDs {
            let target = Locale.Language(identifier: id)
            let status = await availability.status(from: source, to: target)
            switch status {
            case .installed, .supported:
                return id
            default:
                continue
            }
        }
        return "es"
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
    /// Incremented to ask the view for an on-device TranslationSession pass.
    @Published var onDeviceRequestID: UInt64 = 0
    /// English snapshot for the in-flight on-device request.
    @Published var pendingOnDeviceEnglish = ""
    /// Active Clean / Jobsite register for translate + speak (set from the view).
    var voiceMode: SpanishVoiceMode = .jobsite

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var selectedVoice: AVSpeechSynthesisVoice?
    private var pendingCustomEndpoint = ""
    private var pendingToken = ""
    private var lastSuccessStatus = ""
    private var speakGeneration: UInt64 = 0
    private var lastTTSModel = "gpt-4o-mini-tts"
    private var lastTTSVoice = "onyx"
    private var lastAPIError: String?
    private var translateGeneration: UInt64 = 0

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
        lastSuccessStatus = ""
        lastAPIError = nil

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
        engineLabel = "Beckify AI…"
        lastAPIError = nil
        translateGeneration &+= 1
        let generation = translateGeneration

        Task {
            do {
                let draft = try await Self.postTranslate(
                    text: source,
                    customEndpoint: customEndpoint,
                    token: token,
                    voiceMode: voiceMode
                )
                guard generation == translateGeneration else { return }
                finishWithDraft(draft, successStatus: SpanishTranslatorAPI.statusViaBeckifyAI)
            } catch {
                guard generation == translateGeneration else { return }
                let message = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
                let status = (error as? VisionHTTPError)?.status ?? 0
                lastAPIError = message

                if SpanishTranslatorAPI.shouldAttemptOnDeviceFallback(httpStatus: status) {
                    beginOnDeviceFallback(source: source, apiError: message)
                } else {
                    phase = .error
                    statusLabel = "Translate failed"
                    engineLabel = ""
                    errorMessage = message
                }
            }
        }
    }

    func handleOnDeviceResult(_ result: Result<(text: String, targetLanguageID: String), Error>) {
        switch result {
        case .success(let payload):
            let draft = SpanishTranslatorAPI.appleOnDeviceDraft(
                translation: payload.text,
                sourceText: pendingOnDeviceEnglish.isEmpty ? englishText : pendingOnDeviceEnglish,
                targetLanguageID: payload.targetLanguageID
            )
            // Soft note: Beckify AI was down; on-device succeeded.
            if let api = lastAPIError, !api.isEmpty {
                errorMessage = "Beckify AI unavailable — used on-device Apple Translation. (\(api))"
            } else {
                errorMessage = nil
            }
            finishWithDraft(draft, successStatus: SpanishTranslatorAPI.statusOnDevice)
        case .failure(let error):
            phase = .error
            statusLabel = "Translate failed"
            engineLabel = ""
            errorMessage = SpanishTranslatorAPI.bothPathsFailedMessage(
                apiError: lastAPIError,
                onDeviceError: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
            pendingOnDeviceEnglish = ""
        }
    }

    func speakSpanishAgain() {
        let text = spanishText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        speakSpanish(text)
    }

    func stopSpeaking() {
        speakGeneration &+= 1
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        if let player = audioPlayer, player.isPlaying {
            player.stop()
        }
        audioPlayer = nil
    }

    private func beginOnDeviceFallback(source: String, apiError: String) {
        if #available(iOS 18.0, *) {
            phase = .translating
            statusLabel = "Translating on device…"
            engineLabel = "Apple Translation…"
            pendingOnDeviceEnglish = source
            onDeviceRequestID &+= 1
        } else {
            phase = .error
            statusLabel = "Translate failed"
            engineLabel = ""
            errorMessage = SpanishTranslatorAPI.onDeviceUnavailableMessage(apiError: apiError)
        }
    }

    private func finishWithDraft(_ draft: SpanishTranslationDraft, successStatus: String) {
        applyDraft(draft)
        lastSuccessStatus = successStatus
        statusLabel = successStatus
        speakSpanish(draft.translation)
        pendingOnDeviceEnglish = ""
    }

    private func applyDraft(_ draft: SpanishTranslationDraft) {
        spanishText = draft.translation
        dialectLabel = draft.displayDialect
        if draft.engine == "apple" {
            engineLabel = "Translated on device · Apple Translation"
        } else if !draft.provider.isEmpty {
            engineLabel = "Translated via Beckify AI · \(draft.provider)"
                + (draft.model.isEmpty ? "" : " · \(draft.model)")
        } else {
            engineLabel = "Translated via Beckify AI"
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
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
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
        let voices = AVSpeechSynthesisVoice.speechVoices().filter {
            SpanishTranslatorAPI.spanishVoiceScore(language: $0.language) >= 0
        }
        let ranked = voices.sorted { lhs, rhs in
            let l = SpanishTranslatorAPI.jobsiteVoiceScore(
                language: lhs.language,
                genderRaw: lhs.gender.rawValue,
                qualityRaw: lhs.quality.rawValue
            )
            let r = SpanishTranslatorAPI.jobsiteVoiceScore(
                language: rhs.language,
                genderRaw: rhs.gender.rawValue,
                qualityRaw: rhs.quality.rawValue
            )
            if l != r { return l > r }
            return lhs.identifier < rhs.identifier
        }
        selectedVoice = ranked.first
            ?? AVSpeechSynthesisVoice(language: "es-US")
            ?? AVSpeechSynthesisVoice(language: "es-MX")
            ?? AVSpeechSynthesisVoice(language: "es-ES")

        let genderLabel: String
        if let gender = selectedVoice?.gender {
            switch gender {
            case .male: genderLabel = "male"
            case .female: genderLabel = "female"
            case .unspecified: genderLabel = "unspecified"
            @unknown default: genderLabel = "unspecified"
            }
        } else {
            genderLabel = "unspecified"
        }
        voiceNote = SpanishTranslatorAPI.voiceFallbackNote(
            selectedLanguage: selectedVoice?.language,
            genderLabel: genderLabel,
            voiceName: selectedVoice?.name
        )
    }

    private func speakSpanish(_ text: String) {
        let trimmed = SpanishTranslatorAPI.clampSpeakText(text)
        guard !trimmed.isEmpty else { return }
        // stopSpeaking bumps speakGeneration so in-flight fetches are ignored.
        stopSpeaking()
        let generation = speakGeneration
        phase = .speaking
        statusLabel = "Speaking…"
        voiceNote = "Fetching neural TTS…"

        Task {
            do {
                let mode = voiceMode
                let result = try await Self.postSpeak(
                    text: trimmed,
                    customEndpoint: pendingCustomEndpoint,
                    token: pendingToken,
                    voiceMode: mode
                )
                guard generation == speakGeneration else { return }
                lastTTSModel = result.model ?? lastTTSModel
                lastTTSVoice = result.voice ?? lastTTSVoice
                try playNeuralAudio(result.data)
                voiceNote = SpanishTranslatorAPI.neuralVoiceNote(
                    model: lastTTSModel,
                    voice: lastTTSVoice,
                    voiceMode: mode
                )
            } catch {
                guard generation == speakGeneration else { return }
                // Soft note only — translation already succeeded.
                let detail = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                if !detail.isEmpty {
                    errorMessage = "Neural TTS unavailable — Apple voice. (\(detail))"
                }
                speakWithAppleFallback(trimmed)
            }
        }
    }

    private func playNeuralAudio(_ data: Data) throws {
        prepareLoudPlaybackSession()
        let player = try AVAudioPlayer(data: data)
        player.delegate = self
        player.volume = 1.0
        player.prepareToPlay()
        audioPlayer = player
        phase = .speaking
        statusLabel = "Speaking"
        guard player.play() else {
            throw VisionHTTPError(status: 0, message: "AVAudioPlayer failed to start.")
        }
    }

    private func speakWithAppleFallback(_ text: String) {
        refreshVoice()
        prepareLoudPlaybackSession()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectedVoice
        utterance.volume = 1.0
        // Slightly slower than default so playback stays intelligible over site noise.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * SpanishTranslatorAPI.jobsiteSpeechRateFactor
        // Slightly lower pitch reads a bit deeper / thicker on many Apple voices.
        utterance.pitchMultiplier = SpanishTranslatorAPI.jobsitePitchMultiplier
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.08

        phase = .speaking
        statusLabel = "Speaking"
        synthesizer.speak(utterance)
    }

    private func prepareLoudPlaybackSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try session.overrideOutputAudioPort(.speaker)
        } catch {
            // Still attempt utterance; route may already be speaker.
        }
    }

    private static func postSpeak(
        text: String,
        customEndpoint: String,
        token: String,
        voiceMode: SpanishVoiceMode
    ) async throws -> (data: Data, model: String?, voice: String?) {
        guard let url = SpanishTranslatorAPI.speakURL(customEndpoint: customEndpoint) else {
            throw VisionHTTPError(
                status: 0,
                message: "Speak needs an HTTPS endpoint. Leave the custom URL blank to use api.beckify.com."
            )
        }
        let body = try SpanishTranslatorAPI.speakRequestJSON(text: text, voiceMode: voiceMode)
        let auth = SpanishTranslatorAPI.authorizationToken(customEndpoint: customEndpoint, token: token)
        do {
            let result = try await BeckifyAIClient.postAudio(
                url: url,
                body: body,
                bearerToken: auth,
                timeout: 30
            )
            return (result.data, result.model, result.voice)
        } catch let error as VisionHTTPError {
            let message = SpanishTranslatorAPI.formatSpeakError(
                status: error.status,
                message: error.message,
                endpoint: url.absoluteString
            )
            throw VisionHTTPError(status: error.status, message: message)
        }
    }

    private static func postTranslate(
        text: String,
        customEndpoint: String,
        token: String,
        voiceMode: SpanishVoiceMode
    ) async throws -> SpanishTranslationDraft {
        guard let url = SpanishTranslatorAPI.translateURL(customEndpoint: customEndpoint) else {
            throw VisionHTTPError(
                status: 0,
                message: "Translate needs an HTTPS endpoint. Leave the custom URL blank to use api.beckify.com, or enter a https:// URL."
            )
        }
        let body = try SpanishTranslatorAPI.requestJSON(text: text, voiceMode: voiceMode)
        let auth = SpanishTranslatorAPI.authorizationToken(customEndpoint: customEndpoint, token: token)
        do {
            let payload = try await BeckifyAIClient.postJSON(
                url: url,
                body: body,
                bearerToken: auth,
                timeout: 30
            )
            guard let draft = SpanishTranslatorAPI.normalizeDraft(payload, fallbackSource: text) else {
                throw VisionHTTPError(status: 200, message: "Translate returned no Spanish text.")
            }
            return draft
        } catch let error as VisionHTTPError {
            let message = SpanishTranslatorAPI.formatTranslateError(
                status: error.status,
                message: error.message,
                endpoint: url.absoluteString
            )
            throw VisionHTTPError(status: error.status, message: message)
        }
    }

}

extension SpanishTranslatorEngine: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if phase == .speaking {
                phase = .idle
                statusLabel = lastSuccessStatus.isEmpty ? "Ready" : lastSuccessStatus
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if phase == .speaking {
                phase = .idle
                statusLabel = lastSuccessStatus.isEmpty ? "Ready" : lastSuccessStatus
            }
        }
    }
}

extension SpanishTranslatorEngine: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if phase == .speaking {
                phase = .idle
                statusLabel = lastSuccessStatus.isEmpty ? "Ready" : lastSuccessStatus
            }
            audioPlayer = nil
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            audioPlayer = nil
            if phase == .speaking {
                let fallback = spanishText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !fallback.isEmpty {
                    errorMessage = "Neural audio decode failed — Apple voice."
                    speakWithAppleFallback(SpanishTranslatorAPI.clampSpeakText(fallback))
                } else {
                    phase = .idle
                    statusLabel = lastSuccessStatus.isEmpty ? "Ready" : lastSuccessStatus
                }
            }
        }
    }
}
