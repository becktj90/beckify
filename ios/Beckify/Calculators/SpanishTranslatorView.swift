import SwiftUI
import AVFoundation
import Speech
import Translation
import BeckifyMath

/// Toolkit → Reference: English ↔ Spanish in one tool.
/// Default is record/type English → Beckify AI Spanish (Clean / Jobsite) → neural TTS.
/// Spanish → English listens in Spanish and speaks English. On-device Apple Translation is the fallback.
struct SpanishTranslatorView: View {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var engine = SpanishTranslatorEngine()
    @AppStorage(SpanishVoiceMode.storageKey) private var voiceModeRaw = SpanishVoiceMode.jobsite.rawValue
    @AppStorage(SpanishTranslateDirection.storageKey) private var directionRaw = SpanishTranslateDirection.englishToSpanish.rawValue
    @State private var typedLine = ""
    @State private var customEndpoint = ""
    @State private var apiToken = ""
    @State private var showAdvanced = false
    @State private var lastTestPhrase = ""
    @State private var lastAttentionPhrase = ""

    private var voiceMode: SpanishVoiceMode {
        get { SpanishVoiceMode.parse(voiceModeRaw) }
        nonmutating set { voiceModeRaw = newValue.rawValue }
    }

    private var direction: SpanishTranslateDirection {
        get { SpanishTranslateDirection.parse(directionRaw) }
        nonmutating set { directionRaw = newValue.rawValue }
    }

    var body: some View {
        ToolScaffold(
            toolID: .spanishTranslator,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .designAidExtra(SpanishTranslatorAPI.disclaimer)
        ) {
            statusCard
            directionCard
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
            sourceText: engine.pendingOnDeviceSource,
            direction: engine.onDeviceDirection
        ) { result in
            engine.handleOnDeviceResult(result)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                engine.stopListening(translateAfter: false)
                engine.stopSpeaking()
            }
        }
        .onAppear {
            engine.voiceMode = voiceMode
            engine.setDirection(direction)
        }
        .onChange(of: voiceModeRaw) { _, raw in
            engine.voiceMode = SpanishVoiceMode.parse(raw)
        }
        .onChange(of: directionRaw) { _, raw in
            typedLine = ""
            lastTestPhrase = ""
            lastAttentionPhrase = ""
            engine.setDirection(SpanishTranslateDirection.parse(raw))
        }
        .onDisappear {
            engine.stopListening(translateAfter: false)
            engine.stopSpeaking()
        }
    }

    private var sticky: String {
        let status = engine.statusLabel
        let answer = direction.listensInSpanish ? engine.englishText : engine.spanishText
        let source = direction.listensInSpanish ? engine.spanishText : engine.englishText
        if !answer.isEmpty {
            return "\(status) · \(answer)"
        }
        if !source.isEmpty {
            return "\(status) · \(source)"
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
            Text(SpanishTranslatorAPI.statusHelp(direction: direction))
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
            Text(SpanishTranslatorAPI.modeHelp(direction: direction, voiceMode: voiceMode))
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .padding(.top, 4)
        }
    }

    private var directionCard: some View {
        ResultCard(title: "Direction", copyText: direction.uiLabel) {
            Picker("Direction", selection: $directionRaw) {
                ForEach(SpanishTranslateDirection.allCases, id: \.rawValue) { way in
                    Text(way.uiLabel).tag(way.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("spanishTranslator.direction")
            Text(direction.listensInSpanish
                 ? "Listen or type Spanish. You get English back, then English speech."
                 : "Listen or type English. You get Spanish back, then Spanish speech.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .padding(.top, 4)
        }
    }

    private var attentionCard: some View {
        VStack(spacing: 8) {
            if direction.listensInSpanish {
                Text(SpanishTranslatorAPI.reverseAttentionHelp)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
            Button {
                let phrase = SpanishTranslatorAPI.nextAttentionCallPhrase(excluding: lastAttentionPhrase)
                lastAttentionPhrase = phrase
                typedLine = phrase
                engine.voiceMode = voiceMode
                engine.setDirection(direction)
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
                    engine.setDirection(direction)
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
                    let typed = typedLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    let heard = direction.listensInSpanish ? engine.spanishText : engine.englishText
                    let source = typed.isEmpty ? heard : typed
                    engine.voiceMode = voiceMode
                    engine.setDirection(direction)
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
                .disabled(translateDisabled)

                Button {
                    engine.speakResultAgain()
                } label: {
                    Label("Speak again", systemImage: "speaker.wave.3.fill")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.good)
                .disabled(speakAgainDisabled)
                .accessibilityIdentifier("spanishTranslator.speakAgain")
            }

            Button {
                let phrase = SpanishTranslatorAPI.nextRandomTestPhrase(
                    direction: direction,
                    excluding: lastTestPhrase
                )
                lastTestPhrase = phrase
                typedLine = phrase
                engine.voiceMode = voiceMode
                engine.setDirection(direction)
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

            TextField(SpanishTranslatorAPI.typedPlaceholder(direction: direction), text: $typedLine, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
                .onSubmit {
                    engine.voiceMode = voiceMode
                    engine.setDirection(direction)
                    engine.translateText(typedLine, customEndpoint: customEndpoint, token: apiToken)
                }
        }
        .padding(.vertical, 4)
    }

    private var translateDisabled: Bool {
        let typed = typedLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let heard = direction.listensInSpanish ? engine.spanishText : engine.englishText
        return (heard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && typed.isEmpty)
            || engine.phase == .listening
            || engine.phase == .translating
    }

    private var speakAgainDisabled: Bool {
        let result = direction.listensInSpanish ? engine.englishText : engine.spanishText
        return result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || engine.phase == .listening
    }

    private var quickPhrases: [String] {
        SpanishTranslatorAPI.quickPhrases(direction: direction)
    }

    private var quickPhrasesCard: some View {
        ResultCard(title: "Quick lines", copyText: quickPhrases.joined(separator: " · ")) {
            Text(SpanishTranslatorAPI.quickLinesHelp(direction: direction))
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(quickPhrases.enumerated()), id: \.offset) { index, phrase in
                        Button {
                            typedLine = phrase
                            engine.voiceMode = voiceMode
                            engine.setDirection(direction)
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
            if direction.listensInSpanish {
                languageCard(title: "Spanish (heard / typed)", text: engine.spanishText, prominent: false)
                languageCard(title: "English", text: engine.englishText, prominent: true)
            } else {
                languageCard(title: "English (heard / typed)", text: engine.englishText, prominent: false)
                languageCard(title: "Spanish", text: engine.spanishText, prominent: true)
            }
        }
    }

    private func languageCard(title: String, text: String, prominent: Bool) -> some View {
        ResultCard(title: title, copyText: text) {
            Text(text.isEmpty ? "—" : text)
                .font(prominent
                      ? .system(size: 22, weight: .semibold, design: .rounded)
                      : Theme.TypeRole.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private var speakCard: some View {
        ResultCard(title: "Loud playback", copyText: engine.voiceNote) {
            Text(SpanishTranslatorAPI.playbackHelp(direction: direction))
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
        sourceText: String,
        direction: SpanishTranslateDirection,
        onResult: @escaping (Result<(text: String, sourceLanguageID: String, targetLanguageID: String), Error>) -> Void
    ) -> some View {
        if #available(iOS 18.0, *) {
            modifier(
                SpanishOnDeviceTranslationModifier(
                    requestID: requestID,
                    sourceText: sourceText,
                    direction: direction,
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
    let sourceText: String
    let direction: SpanishTranslateDirection
    let onResult: (Result<(text: String, sourceLanguageID: String, targetLanguageID: String), Error>) -> Void

    @State private var configuration: TranslationSession.Configuration?
    @State private var activeSourceID = "en"
    @State private var activeTargetID = "es"

    func body(content: Content) -> some View {
        content
            .translationTask(configuration) { session in
                let source = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !source.isEmpty else { return }
                let sourceID = activeSourceID
                let targetID = activeTargetID
                let emptyNoun = targetID.lowercased().hasPrefix("en") ? "English" : "Spanish"
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
                                    userInfo: [NSLocalizedDescriptionKey: "On-device translation returned empty \(emptyNoun)."]
                                )
                            ))
                        }
                        return
                    }
                    await MainActor.run {
                        onResult(.success((text: translated, sourceLanguageID: sourceID, targetLanguageID: targetID)))
                    }
                } catch {
                    await MainActor.run {
                        onResult(.failure(error))
                    }
                }
            }
            .onChange(of: requestID) { _, newID in
                guard newID > 0 else { return }
                let armedDirection = direction
                Task { @MainActor in
                    await armConfiguration(direction: armedDirection)
                }
            }
    }

    @MainActor
    private func armConfiguration(direction: SpanishTranslateDirection) async {
        let pair = await Self.preferredPair(direction: direction)
        activeSourceID = pair.sourceID
        activeTargetID = pair.targetID
        let source = Locale.Language(identifier: pair.sourceID)
        let target = Locale.Language(identifier: pair.targetID)
        if var config = configuration {
            config.source = source
            config.target = target
            config.invalidate()
            configuration = config
        } else {
            configuration = TranslationSession.Configuration(source: source, target: target)
        }
    }

    /// Prefer an installed pair for this direction. English → Spanish stays en → es-*.
    /// Spanish → English tries es-US / es-MX / es → en-US / en.
    private static func preferredPair(direction: SpanishTranslateDirection) async -> (sourceID: String, targetID: String) {
        let availability = LanguageAvailability()
        let candidates = SpanishTranslatorAPI.appleTranslationCandidates(direction: direction)
        for sourceID in candidates.sources {
            for targetID in candidates.targets {
                let status = await availability.status(
                    from: Locale.Language(identifier: sourceID),
                    to: Locale.Language(identifier: targetID)
                )
                switch status {
                case .installed, .supported:
                    return (sourceID, targetID)
                default:
                    continue
                }
            }
        }
        return (candidates.sources.first ?? "en", candidates.targets.first ?? "es")
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
    /// Source snapshot for the in-flight on-device request (English or Spanish).
    @Published var pendingOnDeviceSource = ""
    /// Direction captured when the on-device request was armed.
    @Published var onDeviceDirection: SpanishTranslateDirection = .englishToSpanish
    /// Active Clean / Jobsite register for translate + speak (set from the view).
    var voiceMode: SpanishVoiceMode = .jobsite
    /// English → Spanish by default. Recreated speech recognizer follows this.
    private(set) var direction: SpanishTranslateDirection = .englishToSpanish

    private var speechRecognizer: SFSpeechRecognizer?
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
    private var onDeviceGeneration: UInt64 = 0
    /// Bumped when direction changes or a new listen starts so a late recognition
    /// callback cannot write text for the wrong locale.
    private var listenToken: UInt64 = 0

    override init() {
        super.init()
        synthesizer.delegate = self
        rebuildSpeechRecognizer()
        refreshVoice()
    }

    /// Switch direction. Stops the mic and any in-flight translate/speak so a flip
    /// cannot finish against the previous locale.
    func setDirection(_ newDirection: SpanishTranslateDirection) {
        guard direction != newDirection else { return }
        listenToken &+= 1
        translateGeneration &+= 1
        onDeviceGeneration = 0
        stopListening(translateAfter: false)
        stopSpeaking()
        pendingOnDeviceSource = ""
        direction = newDirection
        englishText = ""
        spanishText = ""
        dialectLabel = ""
        engineLabel = ""
        errorMessage = nil
        lastSuccessStatus = ""
        lastAPIError = nil
        phase = .idle
        statusLabel = "Ready"
        rebuildSpeechRecognizer()
        refreshVoice()
    }

    func startListening(customEndpoint: String = "", token: String = "") {
        pendingCustomEndpoint = customEndpoint
        pendingToken = token
        errorMessage = nil
        stopSpeaking()
        if direction.listensInSpanish {
            englishText = ""
        } else {
            spanishText = ""
        }
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

        let source = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
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
            errorMessage = SpanishTranslatorAPI.emptySourceMessage(direction: direction)
            return
        }
        if direction.listensInSpanish {
            spanishText = source
            englishText = ""
        } else {
            englishText = source
            spanishText = ""
        }
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
                    voiceMode: voiceMode,
                    direction: direction
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

    func handleOnDeviceResult(_ result: Result<(text: String, sourceLanguageID: String, targetLanguageID: String), Error>) {
        guard onDeviceGeneration == translateGeneration, onDeviceGeneration != 0 else { return }
        switch result {
        case .success(let payload):
            let draft = SpanishTranslatorAPI.appleOnDeviceDraft(
                translation: payload.text,
                sourceText: pendingOnDeviceSource.isEmpty ? sourceText : pendingOnDeviceSource,
                targetLanguageID: payload.targetLanguageID,
                sourceLanguageID: payload.sourceLanguageID
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
            pendingOnDeviceSource = ""
        }
    }

    func speakResultAgain() {
        let text = resultText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        speakResult(text)
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
            onDeviceDirection = direction
            pendingOnDeviceSource = source
            onDeviceGeneration = translateGeneration
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
        speakResult(draft.translation)
        pendingOnDeviceSource = ""
    }

    private var sourceText: String {
        direction.listensInSpanish ? spanishText : englishText
    }

    private var resultText: String {
        direction.listensInSpanish ? englishText : spanishText
    }

    private func applyDraft(_ draft: SpanishTranslationDraft) {
        let targetEnglish = draft.resultLanguageLabel == "English" || direction.listensInSpanish
        if targetEnglish {
            englishText = draft.translation
            if spanishText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                spanishText = draft.sourceText
            }
        } else {
            spanishText = draft.translation
            if englishText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                englishText = draft.sourceText
            }
        }
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

    private func rebuildSpeechRecognizer() {
        let available = SFSpeechRecognizer.supportedLocales().map(\.identifier)
        guard let id = SpanishTranslatorAPI.bestSpeechLocale(direction: direction, available: available) else {
            speechRecognizer = nil
            return
        }
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: id))
    }

    private func beginRecognition() {
        rebuildSpeechRecognizer()
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            phase = .error
            statusLabel = "Recognizer unavailable"
            errorMessage = SpanishTranslatorAPI.speechUnavailableMessage(direction: direction)
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
        statusLabel = direction.listensInSpanish ? "Listening · Spanish" : "Listening"
        if direction.listensInSpanish {
            spanishText = ""
        } else {
            englishText = ""
        }
        listenToken &+= 1
        let token = listenToken
        let listenDirection = direction

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                guard self.listenToken == token, self.direction == listenDirection else { return }
                if let result {
                    let heard = result.bestTranscription.formattedString
                    if self.direction.listensInSpanish {
                        self.spanishText = heard
                    } else {
                        self.englishText = heard
                    }
                }
                if let error, self.phase == .listening {
                    // Ignore benign end-of-audio cancellations after Stop.
                    let ns = error as NSError
                    if ns.domain == "kAFAssistantErrorDomain", ns.code == 1110 { return }
                    if !self.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func refreshVoice() {
        let wantEnglish = direction.listensInSpanish
        let voices = AVSpeechSynthesisVoice.speechVoices().filter {
            if wantEnglish {
                return SpanishTranslatorAPI.englishVoiceScore(language: $0.language) >= 0
            }
            return SpanishTranslatorAPI.spanishVoiceScore(language: $0.language) >= 0
        }
        let ranked = voices.sorted { lhs, rhs in
            let l = wantEnglish
                ? SpanishTranslatorAPI.englishPlaybackVoiceScore(
                    language: lhs.language,
                    genderRaw: lhs.gender.rawValue,
                    qualityRaw: lhs.quality.rawValue
                )
                : SpanishTranslatorAPI.jobsiteVoiceScore(
                    language: lhs.language,
                    genderRaw: lhs.gender.rawValue,
                    qualityRaw: lhs.quality.rawValue
                )
            let r = wantEnglish
                ? SpanishTranslatorAPI.englishPlaybackVoiceScore(
                    language: rhs.language,
                    genderRaw: rhs.gender.rawValue,
                    qualityRaw: rhs.quality.rawValue
                )
                : SpanishTranslatorAPI.jobsiteVoiceScore(
                    language: rhs.language,
                    genderRaw: rhs.gender.rawValue,
                    qualityRaw: rhs.quality.rawValue
                )
            if l != r { return l > r }
            return lhs.identifier < rhs.identifier
        }
        if wantEnglish {
            selectedVoice = ranked.first
                ?? AVSpeechSynthesisVoice(language: "en-US")
                ?? AVSpeechSynthesisVoice(language: "en-GB")
                ?? AVSpeechSynthesisVoice(language: "en")
        } else {
            selectedVoice = ranked.first
                ?? AVSpeechSynthesisVoice(language: "es-US")
                ?? AVSpeechSynthesisVoice(language: "es-MX")
                ?? AVSpeechSynthesisVoice(language: "es-ES")
        }

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
        if wantEnglish {
            voiceNote = SpanishTranslatorAPI.englishVoiceFallbackNote(
                selectedLanguage: selectedVoice?.language,
                genderLabel: genderLabel,
                voiceName: selectedVoice?.name
            )
        } else {
            voiceNote = SpanishTranslatorAPI.voiceFallbackNote(
                selectedLanguage: selectedVoice?.language,
                genderLabel: genderLabel,
                voiceName: selectedVoice?.name
            )
        }
    }

    private func speakResult(_ text: String) {
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
                let speakLanguage = direction.speakLanguage
                let result = try await Self.postSpeak(
                    text: trimmed,
                    customEndpoint: pendingCustomEndpoint,
                    token: pendingToken,
                    voiceMode: mode,
                    language: speakLanguage
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
        voiceMode: SpanishVoiceMode,
        language: String
    ) async throws -> (data: Data, model: String?, voice: String?) {
        guard let url = SpanishTranslatorAPI.speakURL(customEndpoint: customEndpoint) else {
            throw VisionHTTPError(
                status: 0,
                message: "Speak needs an HTTPS endpoint. Leave the custom URL blank to use api.beckify.com."
            )
        }
        let body = try SpanishTranslatorAPI.speakRequestJSON(
            text: text,
            voiceMode: voiceMode,
            language: language
        )
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
        voiceMode: SpanishVoiceMode,
        direction: SpanishTranslateDirection
    ) async throws -> SpanishTranslationDraft {
        guard let url = SpanishTranslatorAPI.translateURL(customEndpoint: customEndpoint) else {
            throw VisionHTTPError(
                status: 0,
                message: "Translate needs an HTTPS endpoint. Leave the custom URL blank to use api.beckify.com, or enter a https:// URL."
            )
        }
        let body = try SpanishTranslatorAPI.requestJSON(
            text: text,
            sourceLanguage: direction.sourceLanguage,
            targetLanguage: direction.targetLanguage,
            voiceMode: voiceMode
        )
        let auth = SpanishTranslatorAPI.authorizationToken(customEndpoint: customEndpoint, token: token)
        do {
            let payload = try await BeckifyAIClient.postJSON(
                url: url,
                body: body,
                bearerToken: auth,
                timeout: 30
            )
            guard let draft = SpanishTranslatorAPI.normalizeDraft(payload, fallbackSource: text) else {
                let noun = direction.listensInSpanish ? "English" : "Spanish"
                throw VisionHTTPError(status: 200, message: "Translate returned no \(noun) text.")
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
                let fallback = resultText.trimmingCharacters(in: .whitespacesAndNewlines)
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
