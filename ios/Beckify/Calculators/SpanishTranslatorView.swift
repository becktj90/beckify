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

    // Deep South: comedy-only English dialect stylizer. Same-language
    // wordplay, not a translation and not an accent/voice impression — see
    // `DeepSouthDialect.honestLimit`. Its own synthesizer so this novelty
    // button never touches the main engine's translation/speech state machine.
    @State private var deepSouthOutput = ""
    @State private var deepSouthSeed = 0
    @State private var deepSouthSynthesizer = AVSpeechSynthesizer()

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
            phaseLine
            directionCard
            modeCard
            attentionCard
            recordCard
            quickPhrasesCard
            textCards
            deepSouthCard
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
                engine.invalidateOutdatedWork(markCancelled: true)
                deepSouthSynthesizer.stopSpeaking(at: .immediate)
            }
        }
        .onAppear {
            engine.applyVoiceMode(voiceMode, invalidateInFlight: false)
            engine.setDirection(direction)
        }
        .onChange(of: voiceModeRaw) { _, raw in
            engine.applyVoiceMode(SpanishVoiceMode.parse(raw), invalidateInFlight: true)
        }
        .onChange(of: directionRaw) { _, raw in
            typedLine = ""
            lastTestPhrase = ""
            lastAttentionPhrase = ""
            deepSouthOutput = ""
            deepSouthSynthesizer.stopSpeaking(at: .immediate)
            engine.setDirection(SpanishTranslateDirection.parse(raw))
        }
        .onDisappear {
            engine.invalidateOutdatedWork(markCancelled: true)
            deepSouthSynthesizer.stopSpeaking(at: .immediate)
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

    /// Just the translated message — not the source text, labels, or
    /// disclaimer. The toolbar/sticky-bar copy button is the one-tap "copy
    /// what I just heard" action; the full EN/ES/engine breakdown is still
    /// available per-field via each language card's own copy button.
    private var copyText: String {
        direction.listensInSpanish ? engine.englishText : engine.spanishText
    }

    /// One short phase word — no STATUS essay, engine/URL notes, or voice tech.
    private var phaseLine: some View {
        Text(engine.statusLabel)
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(statusTone)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("spanishTranslator.phase")
            .accessibilityLabel(engine.statusLabel)
    }

    private var statusTone: Color {
        switch engine.phase {
        case .listening: return Theme.good
        case .finishingTranscript, .translating, .preparingVoice: return Theme.copper
        case .playing: return Theme.warn
        case .failed, .cancelled: return Theme.warn
        case .ready:
            if engine.statusLabel == SpanishTranslatorAPI.statusViaBeckifyAI
                || engine.statusLabel == SpanishTranslatorAPI.statusOnDevice {
                return Theme.good
            }
            return Theme.muted
        }
    }

    private var showsActionBusyChrome: Bool {
        switch engine.phase {
        case .listening, .finishingTranscript, .translating, .preparingVoice, .playing:
            return true
        case .ready, .cancelled, .failed:
            return false
        }
    }

    private var modeCard: some View {
        ResultCard(title: "Clean / Jobsite", copyText: voiceMode.uiLabel) {
            Picker("Mode", selection: $voiceModeRaw) {
                ForEach(SpanishVoiceMode.allCases, id: \.rawValue) { mode in
                    Text(mode.uiLabel).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("spanishTranslator.voiceMode")
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
        }
    }

    private var attentionCard: some View {
        Group {
            if !direction.listensInSpanish {
                Button {
                    let phrase = SpanishTranslatorAPI.nextAttentionCallPhrase(excluding: lastAttentionPhrase)
                    lastAttentionPhrase = phrase
                    typedLine = phrase
                    engine.applyVoiceMode(voiceMode, invalidateInFlight: false)
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
                .disabled(engine.isBusyForNewInput)
                .accessibilityIdentifier("spanishTranslator.attention")
                .accessibilityLabel(SpanishTranslatorAPI.attentionButtonAccessibilityLabel)
                .padding(.vertical, 4)
            }
        }
    }

    private var recordCard: some View {
        VStack(spacing: 14) {
            Button {
                if engine.phase == .listening {
                    engine.stopListening(translateAfter: true)
                } else if engine.phase == .playing || engine.phase == .preparingVoice {
                    engine.stopPlayback()
                } else {
                    engine.applyVoiceMode(voiceMode, invalidateInFlight: false)
                    engine.setDirection(direction)
                    engine.startListening(customEndpoint: customEndpoint, token: apiToken)
                }
            } label: {
                Label(
                    primaryRecordLabel,
                    systemImage: primaryRecordSymbol
                )
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 72)
            }
            .buttonStyle(.borderedProminent)
            .tint(primaryRecordIsStop ? Theme.warn : Theme.copper)
            .accessibilityIdentifier("spanishTranslator.record")

            HStack(spacing: 12) {
                Button {
                    let typed = typedLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    let heard = direction.listensInSpanish ? engine.spanishText : engine.englishText
                    let source = typed.isEmpty ? heard : typed
                    engine.applyVoiceMode(voiceMode, invalidateInFlight: false)
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
                    engine.applyVoiceMode(voiceMode, invalidateInFlight: false)
                    engine.speakResultAgain()
                } label: {
                    Label("Speak", systemImage: "speaker.wave.3.fill")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.good)
                .disabled(speakAgainDisabled)
                .accessibilityIdentifier("spanishTranslator.speakAgain")
            }

            if showsActionBusyChrome {
                actionBusyRow
            }

            if engine.phase == .preparingVoice, engine.canSpeakWithDeviceVoice {
                Button {
                    engine.speakNowWithDeviceVoice()
                } label: {
                    Label(SpanishTranslatorAPI.speakNowDeviceVoiceTitle, systemImage: "iphone.and.arrow.forward")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("spanishTranslator.speakDeviceNow")
            }

            if engine.canCancelInFlight {
                Button(role: .destructive) {
                    engine.cancelInFlightWork()
                } label: {
                    Label(SpanishTranslatorAPI.cancelActionTitle, systemImage: "xmark.circle.fill")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("spanishTranslator.cancel")
            }

            Button {
                let phrase = SpanishTranslatorAPI.nextRandomTestPhrase(
                    direction: direction,
                    excluding: lastTestPhrase
                )
                lastTestPhrase = phrase
                typedLine = phrase
                engine.applyVoiceMode(voiceMode, invalidateInFlight: false)
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
            .disabled(engine.isBusyForNewInput)
            .accessibilityIdentifier("spanishTranslator.testRandom")
            .accessibilityLabel("Test with a random phrase")

            TextField(SpanishTranslatorAPI.typedPlaceholder(direction: direction), text: $typedLine, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
                .onSubmit {
                    engine.applyVoiceMode(voiceMode, invalidateInFlight: false)
                    engine.setDirection(direction)
                    engine.translateText(typedLine, customEndpoint: customEndpoint, token: apiToken)
                }
        }
        .padding(.vertical, 4)
    }

    /// Spinner + phase beside Record / Translate / Speak (not only under the transcript).
    private var actionBusyRow: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(engine.actionFeedbackLabel)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(engine.actionFeedbackLabel)
        .accessibilityIdentifier("spanishTranslator.actionBusy")
    }

    private var primaryRecordIsStop: Bool {
        engine.phase == .listening || engine.phase == .playing || engine.phase == .preparingVoice
    }

    private var primaryRecordLabel: String {
        if engine.phase == .listening || engine.phase == .playing || engine.phase == .preparingVoice {
            return SpanishTranslatorAPI.stopActionTitle
        }
        return "Record"
    }

    private var primaryRecordSymbol: String {
        primaryRecordIsStop ? "stop.circle.fill" : "mic.circle.fill"
    }

    private var translateDisabled: Bool {
        let typed = typedLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let heard = direction.listensInSpanish ? engine.spanishText : engine.englishText
        return (heard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && typed.isEmpty)
            || engine.isBusyForNewInput
    }

    private var speakAgainDisabled: Bool {
        let result = direction.listensInSpanish ? engine.englishText : engine.spanishText
        return result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || engine.phase == .listening
            || engine.phase == .finishingTranscript
            || engine.phase == .translating
    }

    private var quickPhrases: [String] {
        SpanishTranslatorAPI.quickPhrases(direction: direction)
    }

    private var quickPhrasesCard: some View {
        ResultCard(title: "Quick lines", copyText: quickPhrases.joined(separator: " · ")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(quickPhrases.enumerated()), id: \.offset) { index, phrase in
                        Button {
                            typedLine = phrase
                            engine.applyVoiceMode(voiceMode, invalidateInFlight: false)
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
                        .disabled(engine.isBusyForNewInput)
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
                languageCard(title: "Answer · English", text: engine.englishText, prominent: true)
            } else {
                languageCard(title: "English (heard / typed)", text: engine.englishText, prominent: false)
                languageCard(title: "Answer · Spanish", text: engine.spanishText, prominent: true)
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

    /// Comedy-only: stylizes whatever English text is on screen into an
    /// exaggerated "Deep South" drawl. Not a translation, not a real accent —
    /// see `DeepSouthDialect.honestLimit`. Uses its own synthesizer so it
    /// never touches the main translate/speak state machine above.
    @ViewBuilder
    private var deepSouthCard: some View {
        if !engine.englishText.isEmpty {
            ResultCard(title: "Deep South (comedy)", copyText: deepSouthOutput.isEmpty ? nil : deepSouthOutput) {
                Text(DeepSouthDialect.honestLimit)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if !deepSouthOutput.isEmpty {
                    Text(deepSouthOutput)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }

                ThumbButtonRow {
                    Button("Make it Deep South") {
                        deepSouthSeed += 1
                        deepSouthOutput = DeepSouthDialect.stylize(engine.englishText, seed: deepSouthSeed)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .frame(minHeight: Theme.touchTarget)
                    .accessibilityIdentifier("spanishTranslator.deepSouthButton")

                    if !deepSouthOutput.isEmpty {
                        Button("Speak it") {
                            speakDeepSouth()
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.accent)
                        .frame(minHeight: Theme.touchTarget)
                    }
                }
            }
        }
    }

    private func speakDeepSouth() {
        guard !deepSouthOutput.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: deepSouthOutput)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        deepSouthSynthesizer.speak(utterance)
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
    /// Distinct visible phases (PR1). Never label `.playing` before audio actually starts.
    enum Phase: Equatable {
        case ready
        case listening
        case finishingTranscript
        case translating
        case preparingVoice
        case playing
        case cancelled
        case failed
    }

    @Published var phase: Phase = .ready
    @Published var englishText = ""
    @Published var spanishText = ""
    @Published var dialectLabel = ""
    @Published var engineLabel = ""
    @Published var voiceNote = ""
    /// True only while preparing neural/device voice — not while Playing.
    @Published var isPreparingSpeak = false
    /// Elapsed seconds in `.preparingVoice` for “Still preparing…” copy.
    @Published var preparingElapsedSeconds: Int = 0
    @Published var errorMessage: String?
    @Published var statusLabel = SpanishTranslatorAPI.statusReady
    /// Incremented to ask the view for an on-device TranslationSession pass.
    @Published var onDeviceRequestID: UInt64 = 0
    /// Source snapshot for the in-flight on-device request (English or Spanish).
    @Published var pendingOnDeviceSource = ""
    /// Direction captured when the on-device request was armed.
    @Published var onDeviceDirection: SpanishTranslateDirection = .englishToSpanish
    /// Active Clean / Jobsite register for translate + speak (set from the view).
    private(set) var voiceMode: SpanishVoiceMode = .jobsite
    /// English → Spanish by default. Recreated speech recognizer follows this.
    private(set) var direction: SpanishTranslateDirection = .englishToSpanish

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var activePlayerID: ObjectIdentifier?
    private var selectedVoice: AVSpeechSynthesisVoice?
    private var pendingCustomEndpoint = ""
    private var pendingToken = ""
    private var lastSuccessStatus = ""
    private var speakGeneration: UInt64 = 0
    private var speakTask: Task<Void, Never>?
    private var translateTask: Task<Void, Never>?
    private var preparingTicker: Task<Void, Never>?
    private var lastTTSModel = "gpt-4o-mini-tts"
    private var lastTTSVoice = "onyx"
    private var lastAPIError: String?
    private var translateGeneration: UInt64 = 0
    private var onDeviceGeneration: UInt64 = 0
    /// Bumped when direction changes or a new listen starts so a late recognition
    /// callback cannot write text for the wrong locale.
    private var listenToken: UInt64 = 0
    /// Whole-turn identity. Snapshot mode/direction at start of each turn.
    private var turnID: UInt64 = 0
    private var turnDirection: SpanishTranslateDirection = .englishToSpanish
    private var turnVoiceMode: SpanishVoiceMode = .jobsite
    /// When false, cancelled cloud speak must not fall through to Apple TTS.
    private var allowAppleSpeakFallback = true

    var isBusyForNewInput: Bool {
        switch phase {
        case .listening, .finishingTranscript, .translating:
            return true
        case .ready, .preparingVoice, .playing, .cancelled, .failed:
            return false
        }
    }

    var canCancelInFlight: Bool {
        switch phase {
        case .finishingTranscript, .translating, .preparingVoice, .playing:
            return true
        case .ready, .listening, .cancelled, .failed:
            return false
        }
    }

    var canSpeakWithDeviceVoice: Bool {
        !resultText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && phase == .preparingVoice
    }

    /// Feedback beside primary actions (spinner row).
    var actionFeedbackLabel: String {
        switch phase {
        case .listening:
            return statusLabel
        case .finishingTranscript:
            return SpanishTranslatorAPI.statusFinishingTranscript
        case .translating:
            return statusLabel
        case .preparingVoice:
            return SpanishTranslatorAPI.preparingVoiceStatus(elapsedSeconds: preparingElapsedSeconds)
        case .playing:
            return SpanishTranslatorAPI.statusPlaying
        case .cancelled:
            return SpanishTranslatorAPI.statusCancelled
        case .failed:
            return statusLabel
        case .ready:
            return statusLabel
        }
    }

    override init() {
        super.init()
        synthesizer.delegate = self
        rebuildSpeechRecognizer()
        refreshVoice()
    }

    func applyVoiceMode(_ newMode: SpanishVoiceMode, invalidateInFlight: Bool) {
        let changed = voiceMode != newMode
        voiceMode = newMode
        if changed, invalidateInFlight {
            invalidateOutdatedWork(markCancelled: true)
        }
    }

    /// Switch direction. Stops the mic and any in-flight translate/speak so a flip
    /// cannot finish against the previous locale.
    func setDirection(_ newDirection: SpanishTranslateDirection) {
        guard direction != newDirection else { return }
        invalidateOutdatedWork(markCancelled: true)
        pendingOnDeviceSource = ""
        direction = newDirection
        englishText = ""
        spanishText = ""
        dialectLabel = ""
        engineLabel = ""
        errorMessage = nil
        lastSuccessStatus = ""
        lastAPIError = nil
        phase = .ready
        statusLabel = SpanishTranslatorAPI.statusReady
        rebuildSpeechRecognizer()
        refreshVoice()
    }

    /// Cancel translate + speak for leave/background/mode flip/new turn.
    /// Never triggers Apple fallback speech.
    func invalidateOutdatedWork(markCancelled: Bool) {
        allowAppleSpeakFallback = false
        beginNewTurn(snapshotFromCurrent: true)
        stopListeningInternal()
        cancelSpeakPipeline(silence: true)
        translateTask?.cancel()
        translateTask = nil
        pendingOnDeviceSource = ""
        onDeviceGeneration = 0
        stopPreparingTicker()
        isPreparingSpeak = false
        preparingElapsedSeconds = 0
        if markCancelled {
            switch phase {
            case .listening, .finishingTranscript, .translating, .preparingVoice, .playing:
                phase = .cancelled
                statusLabel = SpanishTranslatorAPI.statusCancelled
            default:
                break
            }
        }
    }

    /// User Cancel — abort in-flight work without Apple fallback.
    func cancelInFlightWork() {
        allowAppleSpeakFallback = false
        beginNewTurn(snapshotFromCurrent: true)
        stopListeningInternal()
        cancelSpeakPipeline(silence: true)
        translateTask?.cancel()
        translateTask = nil
        pendingOnDeviceSource = ""
        onDeviceGeneration = 0
        stopPreparingTicker()
        isPreparingSpeak = false
        preparingElapsedSeconds = 0
        phase = .cancelled
        statusLabel = SpanishTranslatorAPI.statusCancelled
        errorMessage = nil
    }

    /// Stop silences playback / prep promptly (no Apple fallback).
    func stopPlayback() {
        allowAppleSpeakFallback = false
        cancelSpeakPipeline(silence: true)
        stopPreparingTicker()
        isPreparingSpeak = false
        preparingElapsedSeconds = 0
        if phase == .preparingVoice || phase == .playing {
            phase = .ready
            statusLabel = lastSuccessStatus.isEmpty ? SpanishTranslatorAPI.statusReady : lastSuccessStatus
        }
    }

    func startListening(customEndpoint: String = "", token: String = "") {
        pendingCustomEndpoint = customEndpoint
        pendingToken = token
        errorMessage = nil
        allowAppleSpeakFallback = false
        beginNewTurn(snapshotFromCurrent: true)
        cancelSpeakPipeline(silence: true)
        translateTask?.cancel()
        translateTask = nil
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
                    self.phase = .failed
                    self.statusLabel = "Speech recognition blocked"
                    self.errorMessage = "Enable Speech Recognition for Beckify in Settings."
                case .notDetermined:
                    self.phase = .failed
                    self.statusLabel = "Speech recognition needed"
                    self.errorMessage = "Allow Speech Recognition when prompted."
                @unknown default:
                    self.phase = .failed
                    self.statusLabel = "Speech recognition unavailable"
                }
            }
        }
    }

    func stopListening(translateAfter: Bool) {
        let source = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        stopListeningInternal()
        if translateAfter, !source.isEmpty {
            phase = .finishingTranscript
            statusLabel = SpanishTranslatorAPI.statusFinishingTranscript
            let endpoint = pendingCustomEndpoint
            let token = pendingToken
            // Yield so Finishing transcript can paint before Translating.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard self.phase == .finishingTranscript else { return }
                self.translateText(source, customEndpoint: endpoint, token: token)
            }
        } else if phase == .listening || phase == .finishingTranscript {
            phase = .ready
            statusLabel = source.isEmpty ? SpanishTranslatorAPI.statusReady : "Ready to translate"
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

        allowAppleSpeakFallback = false
        beginNewTurn(snapshotFromCurrent: true)
        cancelSpeakPipeline(silence: true)
        translateTask?.cancel()

        let snapshotDirection = turnDirection
        let snapshotMode = turnVoiceMode
        let generation = translateGeneration

        if snapshotDirection.listensInSpanish {
            spanishText = source
            englishText = ""
        } else {
            englishText = source
            spanishText = ""
        }
        phase = .translating
        statusLabel = SpanishTranslatorAPI.statusTranslating
        errorMessage = nil
        engineLabel = "Beckify AI…"
        lastAPIError = nil

        translateTask = Task { [weak self] in
            guard let self else { return }
            do {
                let draft = try await Self.postTranslate(
                    text: source,
                    customEndpoint: customEndpoint,
                    token: token,
                    voiceMode: snapshotMode,
                    direction: snapshotDirection
                )
                try Task.checkCancellation()
                guard generation == self.translateGeneration, self.turnID == generation else { return }
                self.finishWithDraft(draft, successStatus: SpanishTranslatorAPI.statusViaBeckifyAI, turn: generation)
            } catch is CancellationError {
                guard generation == self.translateGeneration else { return }
                // Cancel path already set phase when user cancelled.
            } catch {
                guard generation == self.translateGeneration, generation == self.turnID else { return }
                let message = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
                let status = (error as? VisionHTTPError)?.status ?? 0
                self.lastAPIError = message

                if SpanishTranslatorAPI.shouldAttemptOnDeviceFallback(httpStatus: status) {
                    self.beginOnDeviceFallback(source: source, apiError: message, turn: generation, direction: snapshotDirection)
                } else {
                    self.phase = .failed
                    self.statusLabel = SpanishTranslatorAPI.statusFailed
                    self.engineLabel = ""
                    self.errorMessage = message
                }
            }
        }
    }

    func handleOnDeviceResult(_ result: Result<(text: String, sourceLanguageID: String, targetLanguageID: String), Error>) {
        guard onDeviceGeneration == translateGeneration, onDeviceGeneration != 0, onDeviceGeneration == turnID else { return }
        let turn = onDeviceGeneration
        switch result {
        case .success(let payload):
            let draft = SpanishTranslatorAPI.appleOnDeviceDraft(
                translation: payload.text,
                sourceText: pendingOnDeviceSource.isEmpty ? sourceText : pendingOnDeviceSource,
                targetLanguageID: payload.targetLanguageID,
                sourceLanguageID: payload.sourceLanguageID
            )
            if let api = lastAPIError, !api.isEmpty {
                errorMessage = "Beckify AI unavailable — used on-device Apple Translation. (\(api))"
            } else {
                errorMessage = nil
            }
            finishWithDraft(draft, successStatus: SpanishTranslatorAPI.statusOnDevice, turn: turn)
        case .failure(let error):
            phase = .failed
            statusLabel = SpanishTranslatorAPI.statusFailed
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
        speakResult(text, preferNeural: true)
    }

    /// Optional: once translation text is ready, cancel cloud speak and use Apple now.
    func speakNowWithDeviceVoice() {
        let text = resultText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        allowAppleSpeakFallback = true
        cancelSpeakPipeline(silence: true)
        let generation = speakGeneration
        let turn = turnID
        startPreparingTicker(turn: turn)
        phase = .preparingVoice
        isPreparingSpeak = true
        preparingElapsedSeconds = 0
        statusLabel = SpanishTranslatorAPI.statusPreparingVoice
        speakWithAppleFallback(SpanishTranslatorAPI.clampSpeakText(text), turn: turn, speakGen: generation)
    }

    /// Legacy name used by older call sites; silences without Apple fallback.
    func stopSpeaking() {
        allowAppleSpeakFallback = false
        cancelSpeakPipeline(silence: true)
        stopPreparingTicker()
        isPreparingSpeak = false
        preparingElapsedSeconds = 0
    }

    private func beginNewTurn(snapshotFromCurrent: Bool) {
        turnID &+= 1
        translateGeneration = turnID
        listenToken = turnID
        // Speak counter only moves forward (may run ahead of turnID).
        speakGeneration &+= 1
        if snapshotFromCurrent {
            turnDirection = direction
            turnVoiceMode = voiceMode
        }
    }

    private func stopListeningInternal() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    private func cancelSpeakPipeline(silence: Bool) {
        speakGeneration &+= 1
        speakTask?.cancel()
        speakTask = nil
        if silence {
            if synthesizer.isSpeaking {
                synthesizer.stopSpeaking(at: .immediate)
            }
            if let player = audioPlayer {
                if player.isPlaying { player.stop() }
            }
            audioPlayer = nil
            activePlayerID = nil
        }
    }

    private func beginOnDeviceFallback(
        source: String,
        apiError: String,
        turn: UInt64,
        direction: SpanishTranslateDirection
    ) {
        if #available(iOS 18.0, *) {
            phase = .translating
            statusLabel = "Translating on device…"
            engineLabel = "Apple Translation…"
            onDeviceDirection = direction
            pendingOnDeviceSource = source
            onDeviceGeneration = turn
            onDeviceRequestID &+= 1
        } else {
            phase = .failed
            statusLabel = SpanishTranslatorAPI.statusFailed
            engineLabel = ""
            errorMessage = SpanishTranslatorAPI.onDeviceUnavailableMessage(apiError: apiError)
        }
    }

    private func finishWithDraft(_ draft: SpanishTranslationDraft, successStatus: String, turn: UInt64) {
        guard turn == turnID, turn == translateGeneration else { return }
        // Show translated text immediately while voice still prepares.
        applyDraft(draft)
        lastSuccessStatus = successStatus
        statusLabel = successStatus
        pendingOnDeviceSource = ""
        speakResult(draft.translation, preferNeural: true)
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
            phase = .failed
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
            phase = .failed
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
            phase = .failed
            statusLabel = "Mic failed"
            errorMessage = error.localizedDescription
            return
        }

        phase = .listening
        statusLabel = direction.listensInSpanish
            ? SpanishTranslatorAPI.statusListeningSpanish
            : SpanishTranslatorAPI.statusListening
        if direction.listensInSpanish {
            spanishText = ""
        } else {
            englishText = ""
        }
        let token = listenToken
        let listenDirection = turnDirection
        let turn = turnID

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                guard self.listenToken == token, self.turnID == turn, self.direction == listenDirection else { return }
                if let result {
                    let heard = result.bestTranscription.formattedString
                    if self.direction.listensInSpanish {
                        self.spanishText = heard
                    } else {
                        self.englishText = heard
                    }
                }
                if let error, self.phase == .listening {
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

    private func speakResult(_ text: String, preferNeural: Bool) {
        let trimmed = SpanishTranslatorAPI.clampSpeakText(text)
        guard !trimmed.isEmpty else { return }
        allowAppleSpeakFallback = preferNeural
        cancelSpeakPipeline(silence: true)
        // cancelSpeakPipeline already advanced speakGeneration; never reset it downward.
        let generation = speakGeneration
        let turn = turnID
        let snapshotMode = turnVoiceMode
        let speakLanguage = turnDirection.speakLanguage

        phase = .preparingVoice
        isPreparingSpeak = true
        preparingElapsedSeconds = 0
        statusLabel = SpanishTranslatorAPI.statusPreparingVoice
        voiceNote = SpanishTranslatorAPI.statusPreparingVoice
        startPreparingTicker(turn: turn)

        guard preferNeural else {
            speakWithAppleFallback(trimmed, turn: turn, speakGen: generation)
            return
        }

        speakTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await Self.postSpeak(
                    text: trimmed,
                    customEndpoint: self.pendingCustomEndpoint,
                    token: self.pendingToken,
                    voiceMode: snapshotMode,
                    language: speakLanguage
                )
                try Task.checkCancellation()
                guard generation == self.speakGeneration, turn == self.turnID else { return }
                self.lastTTSModel = result.model ?? self.lastTTSModel
                self.lastTTSVoice = result.voice ?? self.lastTTSVoice
                try self.playNeuralAudio(result.data, turn: turn, speakGen: generation)
                self.voiceNote = SpanishTranslatorAPI.neuralVoiceNote(
                    model: self.lastTTSModel,
                    voice: self.lastTTSVoice,
                    voiceMode: snapshotMode,
                    language: speakLanguage
                )
            } catch is CancellationError {
                guard generation == self.speakGeneration else { return }
                self.clearPreparingIfCurrent(turn: turn)
                // Cancel must not trigger Apple fallback.
            } catch {
                guard generation == self.speakGeneration, turn == self.turnID else { return }
                self.clearPreparingIfCurrent(turn: turn)
                guard self.allowAppleSpeakFallback else {
                    self.phase = .ready
                    self.statusLabel = self.lastSuccessStatus.isEmpty
                        ? SpanishTranslatorAPI.statusReady
                        : self.lastSuccessStatus
                    return
                }
                let detail = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                if !detail.isEmpty {
                    self.errorMessage = "Neural TTS unavailable — Apple voice. (\(detail))"
                }
                self.speakWithAppleFallback(trimmed, turn: turn, speakGen: generation)
            }
        }
    }

    private func startPreparingTicker(turn: UInt64) {
        preparingTicker?.cancel()
        preparingTicker = Task { [weak self] in
            var elapsed = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                guard let self else { return }
                guard self.turnID == turn, self.phase == .preparingVoice else { return }
                elapsed += 1
                self.preparingElapsedSeconds = elapsed
                self.statusLabel = SpanishTranslatorAPI.preparingVoiceStatus(elapsedSeconds: elapsed)
            }
        }
    }

    private func stopPreparingTicker() {
        preparingTicker?.cancel()
        preparingTicker = nil
    }

    private func clearPreparingIfCurrent(turn: UInt64) {
        guard turn == turnID else { return }
        stopPreparingTicker()
        isPreparingSpeak = false
        preparingElapsedSeconds = 0
    }

    private func playNeuralAudio(_ data: Data, turn: UInt64, speakGen: UInt64) throws {
        guard turn == turnID, speakGen == speakGeneration else { return }
        prepareLoudPlaybackSession()
        let player = try AVAudioPlayer(data: data)
        player.delegate = self
        player.volume = 1.0
        player.prepareToPlay()
        audioPlayer = player
        activePlayerID = ObjectIdentifier(player)
        // Only flip to Playing once audio actually starts.
        guard player.play() else {
            activePlayerID = nil
            audioPlayer = nil
            throw VisionHTTPError(status: 0, message: "AVAudioPlayer failed to start.")
        }
        clearPreparingIfCurrent(turn: turn)
        phase = .playing
        statusLabel = SpanishTranslatorAPI.statusPlaying
    }

    private func speakWithAppleFallback(_ text: String, turn: UInt64, speakGen: UInt64) {
        guard turn == turnID, speakGen == speakGeneration else { return }
        refreshVoice()
        prepareLoudPlaybackSession()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectedVoice
        utterance.volume = 1.0
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * SpanishTranslatorAPI.jobsiteSpeechRateFactor
        utterance.pitchMultiplier = SpanishTranslatorAPI.jobsitePitchMultiplier
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0.08

        // Stay on Preparing voice until didStart — never label Playing early.
        phase = .preparingVoice
        isPreparingSpeak = true
        statusLabel = SpanishTranslatorAPI.preparingVoiceStatus(elapsedSeconds: preparingElapsedSeconds)
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
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            // Playing only after Apple audio actually starts.
            if phase == .preparingVoice {
                clearPreparingIfCurrent(turn: turnID)
                phase = .playing
                statusLabel = SpanishTranslatorAPI.statusPlaying
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            clearPreparingIfCurrent(turn: turnID)
            if phase == .playing {
                phase = .ready
                statusLabel = lastSuccessStatus.isEmpty ? SpanishTranslatorAPI.statusReady : lastSuccessStatus
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            clearPreparingIfCurrent(turn: turnID)
            if phase == .playing || phase == .preparingVoice {
                // User stop/cancel already set phase when intended.
                if phase == .playing {
                    phase = .ready
                    statusLabel = lastSuccessStatus.isEmpty ? SpanishTranslatorAPI.statusReady : lastSuccessStatus
                }
            }
        }
    }
}

extension SpanishTranslatorEngine: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard ObjectIdentifier(player) == activePlayerID else { return }
            clearPreparingIfCurrent(turn: turnID)
            if phase == .playing {
                phase = .ready
                statusLabel = lastSuccessStatus.isEmpty ? SpanishTranslatorAPI.statusReady : lastSuccessStatus
            }
            if ObjectIdentifier(player) == activePlayerID {
                audioPlayer = nil
                activePlayerID = nil
            }
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            guard ObjectIdentifier(player) == activePlayerID else { return }
            audioPlayer = nil
            activePlayerID = nil
            guard phase == .preparingVoice || phase == .playing else { return }
            guard allowAppleSpeakFallback else {
                phase = .ready
                statusLabel = lastSuccessStatus.isEmpty ? SpanishTranslatorAPI.statusReady : lastSuccessStatus
                return
            }
            let fallback = resultText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !fallback.isEmpty {
                errorMessage = "Neural audio decode failed — Apple voice."
                speakWithAppleFallback(SpanishTranslatorAPI.clampSpeakText(fallback), turn: turnID, speakGen: speakGeneration)
            } else {
                phase = .ready
                statusLabel = lastSuccessStatus.isEmpty ? SpanishTranslatorAPI.statusReady : lastSuccessStatus
            }
        }
    }
}
