import SwiftUI
import AVFoundation
import Speech
import Translation
import BeckifyMath
import UniformTypeIdentifiers
import UIKit

/// Toolkit → Reference: Crew Talk. English ↔ Spanish, spoken by the person you pick.
/// Person, line, and Speak. Dialect rewrite is a short helper. Clean/Jobsite is off this screen.
struct SpanishTranslatorView: View {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var engine = SpanishTranslatorEngine()
    @AppStorage(SpanishVoiceMode.storageKey) private var voiceModeRaw = SpanishVoiceMode.jobsite.rawValue
    @AppStorage(SpanishTranslateDirection.storageKey) private var directionRaw = SpanishTranslateDirection.englishToSpanish.rawValue
    @AppStorage(CrewTalkMember.storageKey) private var crewRaw = CrewTalkMember.titoSolano.rawValue
    @State private var typedLine = ""
    @State private var customEndpoint = ""
    @State private var apiToken = ""
    @State private var showAdvanced = false
    @State private var lastTestPhrase = ""
    @State private var lastAttentionPhrase = ""
    @FocusState private var composerFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Height of this destination above the tab bar. Only used to decide when the header goes compact.
    @State private var layoutHeight: CGFloat = 900

    private var voiceMode: SpanishVoiceMode {
        get { SpanishVoiceMode.parse(voiceModeRaw) }
        nonmutating set { voiceModeRaw = newValue.rawValue }
    }

    private var direction: SpanishTranslateDirection {
        get { SpanishTranslateDirection.parse(directionRaw) }
        nonmutating set { directionRaw = newValue.rawValue }
    }

    private var crew: CrewTalkMember {
        get { CrewTalkMember.parse(crewRaw) }
        nonmutating set { crewRaw = newValue.rawValue }
    }

    var body: some View {
        ToolScaffold(
            toolID: .spanishTranslator,
            stickyAnswer: nil,
            copyText: copyText,
            disclaimer: .designAidExtra(SpanishTranslatorAPI.disclaimer),
            showsIdentityHeader: false,
            showsRelatedTools: false,
            showsKeyboardToolbar: false
        ) {
            answerCard
            quickPhrasesCard
            if showAdvanced {
                advancedCard
            } else {
                Button("API endpoint / token / test phrase") {
                    showAdvanced = true
                }
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .frame(minHeight: Theme.touchTarget, alignment: .leading)
            }
            if let err = engine.errorMessage, !err.isEmpty {
                Text(err)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.warn)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("spanishTranslator.error")
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
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            crewHelperBar
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composerDock
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    composerFocused = false
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
                .accessibilityIdentifier("keyboardDone")
            }
        }
        .onAppear {
            alignCrewWithDirectionRoster()
            engine.applyVoiceMode(voiceMode, invalidateInFlight: false)
            engine.setDirection(direction)
            engine.applyCrew(crew, invalidateInFlight: false)
        }
        .onChange(of: voiceModeRaw) { _, raw in
            engine.applyVoiceMode(SpanishVoiceMode.parse(raw), invalidateInFlight: true)
        }
        .onChange(of: crewRaw) { _, raw in
            engine.applyCrew(CrewTalkMember.parse(raw), invalidateInFlight: true)
        }
        .onChange(of: directionRaw) { _, raw in
            typedLine = ""
            lastTestPhrase = ""
            lastAttentionPhrase = ""
            let next = SpanishTranslateDirection.parse(raw)
            alignCrewWithDirectionRoster(next)
            engine.setDirection(next)
            engine.applyCrew(crew, invalidateInFlight: true)
        }
        .onDisappear {
            engine.invalidateOutdatedWork(markCancelled: true)
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: CrewTalkLayoutHeightKey.self, value: proxy.size.height)
            }
        }
        .onPreferenceChange(CrewTalkLayoutHeightKey.self) { newValue in
            guard newValue > 1, abs(layoutHeight - newValue) > 0.5 else { return }
            layoutHeight = newValue
        }
    }

    /// The pinned header shrinks when the keyboard is up, at accessibility text sizes, and on short screens,
    /// so it never squeezes the answer and Quick Lines out of view.
    private var crewIsCompact: Bool {
        composerFocused || dynamicTypeSize.isAccessibilitySize || layoutHeight < 640
    }

    /// D1: the picker and stored helper stay on this direction's roster.
    /// English → Spanish is Tito and Lupita. Spanish → English is Bodie, Junie, Pearl, Sloane.
    private func alignCrewWithDirectionRoster(_ next: SpanishTranslateDirection? = nil) {
        let way = next ?? direction
        let roster = CrewTalkMember.roster(for: way)
        if !roster.contains(crew) {
            crewRaw = CrewTalkMember.defaultMember(for: way).rawValue
        }
    }

    /// Copy the dock Speak string — the other-language line on screen, without laugh tags.
    private var copyText: String {
        SpanishTranslatorAPI.displayText(dockSpokenAnswer)
    }

    /// English / Spanish slots for dock + dialect. Typed input wins for the listen side.
    private var dockEnglishSpanish: (english: String, spanish: String, fallback: String) {
        let typed = typedLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let heardEnglish = engine.englishText.trimmingCharacters(in: .whitespacesAndNewlines)
        let heardSpanish = engine.spanishText.trimmingCharacters(in: .whitespacesAndNewlines)
        if direction.listensInSpanish {
            return (heardEnglish, typed.isEmpty ? heardSpanish : typed, typed)
        }
        return (typed.isEmpty ? heardEnglish : typed, heardSpanish, typed)
    }

    /// Other-language line Speak plays. Tito's rewrite is the Spanish result.
    private var dockSpokenAnswer: String {
        let pair = dockEnglishSpanish
        return SpanishTranslatorAPI.spokenAnswerForDock(
            crew: crew,
            direction: direction,
            english: pair.english,
            spanish: pair.spanish,
            fallback: pair.fallback
        )
    }

    /// Short dialect flavor under the answer. Empty for Tito.
    private var dockDialectHelper: String {
        let pair = dockEnglishSpanish
        return SpanishTranslatorAPI.dialectHelperLine(
            crew: crew,
            direction: direction,
            english: pair.english,
            spanish: pair.spanish,
            fallback: pair.fallback
        )
    }

    /// Speak string: dialect / other-language / rewrite on screen, never the raw field.
    private var dockSpeakLine: String {
        let pair = dockEnglishSpanish
        return SpanishTranslatorAPI.lineToSpeak(
            crew: crew,
            direction: direction,
            english: pair.english,
            spanish: pair.spanish,
            fallback: pair.fallback
        )
    }

    private var dockSpeakLanguage: String {
        // Each helper speaks only their own language. Tito is Spanish; the English roster is English.
        crew.speakLanguage
    }

    // MARK: - Layout

    private func translate(_ phrase: String) {
        engine.applyVoiceMode(voiceMode, invalidateInFlight: false)
        engine.setDirection(direction)
        engine.translateText(phrase, customEndpoint: customEndpoint, token: apiToken)
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
        case .finishingTranscript, .translating, .preparingVoice:
            return true
        case .ready, .listening, .playing, .cancelled, .failed:
            return false
        }
    }

    private var speakAgainDisabled: Bool {
        dockSpeakLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || engine.phase == .listening
            || engine.phase == .finishingTranscript
            || engine.phase == .translating
    }

    private var quickPhrases: [String] {
        SpanishTranslatorAPI.quickPhrases(direction: direction)
    }

    private var typedTrimmed: String {
        typedLine.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// What the person said or typed, shown small above the answer.
    private var heardLine: String {
        let heard = direction.listensInSpanish ? engine.spanishText : engine.englishText
        return heard.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The translated line, its status, and Speak. Lives at the top of the scroll area, so the
    /// result is the first thing seen and nothing pinned covers it.
    private var answerCard: some View {
        let answer = SpanishTranslatorAPI.displayText(dockSpokenAnswer)
        let helper = SpanishTranslatorAPI.displayText(dockDialectHelper)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if showsActionBusyChrome {
                    ProgressView()
                }
                Text(engine.actionFeedbackLabel)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(statusTone)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("spanishTranslator.phase")
            }
            if !heardLine.isEmpty {
                Text("“\(heardLine)”")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("spanishTranslator.heard")
            }
            Text(answer.isEmpty ? "Tap the mic or type a line. The translation shows here." : answer)
                .font(.system(size: answer.isEmpty ? 16 : 24, weight: .semibold, design: .rounded))
                .foregroundStyle(answer.isEmpty ? Theme.muted : Theme.foreground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .accessibilityIdentifier("spanishTranslator.answer")
            if !helper.isEmpty {
                Text(helper)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("spanishTranslator.dialectHelper")
            }
            HStack(spacing: 8) {
                if engine.canCancelInFlight {
                    Button(role: .destructive) {
                        engine.cancelInFlightWork()
                    } label: {
                        Label(SpanishTranslatorAPI.cancelActionTitle, systemImage: "xmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: Theme.touchTarget)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("spanishTranslator.cancel")
                }
                Button {
                    engine.applyVoiceMode(voiceMode, invalidateInFlight: false)
                    engine.speakDockAnswer(dockSpeakLine, language: dockSpeakLanguage)
                } label: {
                    Label("Speak", systemImage: "speaker.wave.3.fill")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(speakAgainDisabled)
                .accessibilityIdentifier("spanishTranslator.speakAgain")
                if let audioURL = engine.translatedAudioURL {
                    Button {
                        engine.copyTranslatedAudio()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .frame(width: Theme.touchTarget, height: Theme.touchTarget)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Copy audio")
                    .accessibilityIdentifier("spanishTranslator.copyAudio")
                    ShareLink(item: audioURL) {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: Theme.touchTarget, height: Theme.touchTarget)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Share audio")
                    .accessibilityIdentifier("spanishTranslator.shareAudio")
                }
            }
            if engine.phase == .preparingVoice, engine.canSpeakWithDeviceVoice {
                Button {
                    engine.speakNowWithDeviceVoice()
                } label: {
                    Label(SpanishTranslatorAPI.speakNowDeviceVoiceTitle, systemImage: "iphone.and.arrow.forward")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("spanishTranslator.speakDeviceNow")
            }
            if let notice = engine.audioCopyNotice {
                Text(notice)
                    .font(.footnote)
                    .foregroundStyle(Theme.warn)
            }
        }
        .padding(Theme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// Two columns of full chips. Nothing is clipped or hidden behind a sideways scroll.
    private var quickPhrasesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK LINES")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                if !direction.listensInSpanish {
                    Button {
                        let phrase = SpanishTranslatorAPI.nextAttentionCallPhrase(excluding: lastAttentionPhrase)
                        lastAttentionPhrase = phrase
                        typedLine = phrase
                        translate(phrase)
                    } label: {
                        Label(SpanishTranslatorAPI.attentionButtonTitle, systemImage: "hand.wave.fill")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.accent)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.accent.opacity(0.16))
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(engine.isBusyForNewInput)
                    .accessibilityIdentifier("spanishTranslator.attention")
                    .accessibilityLabel(SpanishTranslatorAPI.attentionButtonAccessibilityLabel)
                }
                ForEach(Array(quickPhrases.enumerated()), id: \.offset) { index, phrase in
                    Button {
                        typedLine = phrase
                        translate(phrase)
                    } label: {
                        Text(phrase)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.foreground)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.surfaceRaised)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(engine.isBusyForNewInput)
                    .accessibilityIdentifier("spanishTranslator.quickPhrase.\(index)")
                    .accessibilityLabel("Quick translate: \(phrase)")
                }
            }
        }
    }

    private var primaryIsStop: Bool {
        engine.phase == .listening || engine.phase == .playing || engine.phase == .preparingVoice
    }

    private var primarySymbol: String {
        if primaryIsStop { return "stop.fill" }
        if !typedTrimmed.isEmpty { return "arrow.up" }
        return "mic.fill"
    }

    private var primaryLabel: String {
        if primaryIsStop { return SpanishTranslatorAPI.stopActionTitle }
        if !typedTrimmed.isEmpty { return "Translate" }
        return "Record"
    }

    private func primaryTapped() {
        if engine.phase == .listening {
            engine.stopListening(translateAfter: true)
        } else if engine.phase == .playing || engine.phase == .preparingVoice {
            engine.stopPlayback()
        } else if !typedTrimmed.isEmpty {
            submitTypedLine()
        } else {
            engine.applyVoiceMode(voiceMode, invalidateInFlight: false)
            engine.setDirection(direction)
            engine.startListening(customEndpoint: customEndpoint, token: apiToken)
        }
    }

    /// One field and one button, like a messaging app. The button is Record when the field is empty,
    /// Translate when it has text, and Stop while the mic or voice is running. The dock is opaque, so
    /// scrolled content never shows through it, and it sits directly above the tab bar.
    private var composerDock: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(SpanishTranslatorAPI.typedPlaceholder(direction: direction), text: $typedLine, axis: .vertical)
                .lineLimit(1...3)
                .focused($composerFocused)
                .submitLabel(.send)
                .onSubmit { submitTypedLine() }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Theme.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .accessibilityIdentifier("spanishTranslator.composer")
            Button(action: primaryTapped) {
                Image(systemName: primarySymbol)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.background)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(primaryIsStop ? Theme.warn : Theme.accent))
            }
            .buttonStyle(.plain)
            .disabled(engine.isBusyForNewInput && engine.phase != .listening)
            .opacity(engine.isBusyForNewInput && engine.phase != .listening ? 0.5 : 1)
            .accessibilityLabel(primaryLabel)
            .accessibilityIdentifier("spanishTranslator.record")
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.vertical, 10)
        // Not `ignoresSafeArea`: that painted the plate through the tab bar band (WP-0B root cause).
        // The plate stops at the top of the floating tab bar.
        .background(Theme.surfaceRaised, ignoresSafeAreaEdges: [])
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
        }
    }

    private func submitTypedLine() {
        composerFocused = false
        translate(typedLine)
    }

    /// Direction, Conversation, and the person on screen. One compact block, so the answer and
    /// Quick Lines keep most of the screen. The sprite shrinks while the keyboard is up.
    private var crewHelperBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Picker("Direction", selection: $directionRaw) {
                    ForEach(SpanishTranslateDirection.allCases, id: \.rawValue) { way in
                        Text(way.uiLabel).tag(way.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("spanishTranslator.direction")
                NavigationLink {
                    CrewTalkConversationView()
                } label: {
                    Image(systemName: "person.2.wave.2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: Theme.touchTarget, height: Theme.touchTarget)
                        .background(Circle().fill(Theme.accent.opacity(0.16)))
                }
                .accessibilityLabel("Conversation")
                .accessibilityHint("Two people take turns, or link two phones")
                .accessibilityIdentifier("spanishTranslator.conversation")
            }
            HStack(spacing: 12) {
                CrewTalkSprite(
                    crew: crew,
                    isTalking: engine.phase == .playing,
                    height: crewIsCompact ? 56 : 84
                )
                .frame(width: crewIsCompact ? 100 : 150, height: crewIsCompact ? 56 : 84)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(crew.firstName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.foreground)
                    if !crewIsCompact {
                        Text(crew.blurb)
                            .font(Theme.TypeRole.help)
                            .foregroundStyle(Theme.muted)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CrewTalkMember.roster(for: direction), id: \.rawValue) { member in
                        Button {
                            crewRaw = member.rawValue
                        } label: {
                            Text(member.firstName)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(member == crew ? Theme.background : Theme.foreground)
                                .frame(minWidth: Theme.touchTarget, minHeight: 40)
                                .padding(.horizontal, 12)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(member == crew ? Theme.accent : Theme.surfaceRaised)
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Theme.border, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(member.displayName)
                        .accessibilityAddTraits(member == crew ? .isSelected : [])
                    }
                }
            }
            .accessibilityIdentifier("spanishTranslator.crew")
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.top, Theme.Space.xs)
        .padding(.bottom, Theme.Space.sm)
        .background(Theme.background)
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
            Button {
                let phrase = SpanishTranslatorAPI.nextRandomTestPhrase(
                    direction: direction,
                    excluding: lastTestPhrase
                )
                lastTestPhrase = phrase
                typedLine = phrase
                translate(phrase)
            } label: {
                Label("Test with a random phrase", systemImage: "shuffle")
                    .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
            }
            .buttonStyle(.bordered)
            .disabled(engine.isBusyForNewInput)
            .accessibilityIdentifier("spanishTranslator.testRandom")
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

private struct CrewTalkLayoutHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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
    @Published private(set) var translatedAudioURL: URL?
    @Published private(set) var audioCopyNotice: String?

    func copyTranslatedAudio() {
        guard let url = translatedAudioURL else { return }
        do {
            let data = try Data(contentsOf: url)
            UIPasteboard.general.setItems([[(UTType(filenameExtension: url.pathExtension) ?? .audio).identifier: data]])
            audioCopyNotice = "Audio copied. Open Messages and paste. If Paste isn’t available, use Share Audio."
        } catch {
            audioCopyNotice = "Couldn’t copy the recording. Try Speak again to generate a new recording."
        }
    }
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
    /// Active Clean / Jobsite register for translate wording (set from the view).
    private(set) var voiceMode: SpanishVoiceMode = .jobsite
    /// Person on screen. Their ElevenLabs voice speaks.
    private(set) var crew: CrewTalkMember = .titoSolano
    /// English → Spanish by default. Recreated speech recognizer follows this.
    private(set) var direction: SpanishTranslateDirection = .englishToSpanish

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private var audioExporter: TranslatorAudioExporter?
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
    private var lastTTSModel = CrewTalkMember.speakModel
    private var lastTTSVoice = CrewTalkMember.titoSolano.voiceID
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
    private var turnCrew: CrewTalkMember = .titoSolano
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
        snapCrewToRoster()
        refreshVoice()
    }

    /// Tito is not offered on Spanish → English, and English helpers are not offered the other way.
    private func snapCrewToRoster() {
        let roster = CrewTalkMember.roster(for: direction)
        if !roster.contains(crew) {
            crew = CrewTalkMember.defaultMember(for: direction)
        }
    }

    func applyVoiceMode(_ newMode: SpanishVoiceMode, invalidateInFlight: Bool) {
        let changed = voiceMode != newMode
        voiceMode = newMode
        if changed, invalidateInFlight {
            invalidateOutdatedWork(markCancelled: true)
        }
    }

    func applyCrew(_ newCrew: CrewTalkMember, invalidateInFlight: Bool) {
        let roster = CrewTalkMember.roster(for: direction)
        let resolved = roster.contains(newCrew) ? newCrew : CrewTalkMember.defaultMember(for: direction)
        let changed = crew != resolved
        crew = resolved
        refreshVoice()
        if changed, invalidateInFlight {
            invalidateOutdatedWork(markCancelled: true)
        }
    }

    /// Switch direction. Stops the mic and any in-flight translate/speak so a flip
    /// cannot finish against the previous locale.
    func setDirection(_ newDirection: SpanishTranslateDirection) {
        if direction == newDirection {
            snapCrewToRoster()
            return
        }
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
        snapCrewToRoster()
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
        speakDockAnswer(currentLineToSpeak(), language: currentSpeakLanguage())
    }

    /// Speak the dialect / other-language / rewritten line, never the raw field.
    func speakDockAnswer(_ text: String, language: String? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Snapshot the person on screen. A Speak tap is not a translate turn,
        // and turnCrew would otherwise stay the last translation's helper.
        turnCrew = crew
        turnDirection = direction
        turnVoiceMode = voiceMode
        speakResult(trimmed, preferNeural: true, language: language)
    }

    private func currentDockSpokenAnswer() -> String {
        SpanishTranslatorAPI.spokenAnswerForDock(
            crew: crew,
            direction: direction,
            english: englishText,
            spanish: spanishText,
            fallback: resultText
        )
    }

    private func currentLineToSpeak() -> String {
        SpanishTranslatorAPI.lineToSpeak(
            crew: crew,
            direction: direction,
            english: englishText,
            spanish: spanishText,
            fallback: resultText
        )
    }

    private func currentSpeakLanguage() -> String {
        crew.speakLanguage
    }

    /// Optional: once translation text is ready, cancel cloud speak and use Apple now.
    func speakNowWithDeviceVoice() {
        let text = currentLineToSpeak()
        guard !text.isEmpty else { return }
        allowAppleSpeakFallback = true
        turnCrew = crew
        turnDirection = direction
        turnVoiceMode = voiceMode
        cancelSpeakPipeline(silence: true)
        let generation = speakGeneration
        let turn = turnID
        startPreparingTicker(turn: turn)
        phase = .preparingVoice
        isPreparingSpeak = true
        preparingElapsedSeconds = 0
        statusLabel = SpanishTranslatorAPI.statusPreparingVoice
        let apple = currentSpeakLanguage() == "es" ? "es-US" : "en-US"
        speakWithAppleFallback(SpanishTranslatorAPI.clampSpeakText(text), turn: turn, speakGen: generation, language: apple)
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
        translatedAudioURL = nil
        audioCopyNotice = nil
        turnID &+= 1
        translateGeneration = turnID
        listenToken = turnID
        // Speak counter only moves forward (may run ahead of turnID).
        speakGeneration &+= 1
        if snapshotFromCurrent {
            turnDirection = direction
            turnVoiceMode = voiceMode
            turnCrew = crew
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
        audioExporter?.cancel()
        audioExporter = nil
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
        // Empty Tito rewrite must not leave phase on .translating.
        // Prefer the dock line, then the API translation, else go ready.
        switch SpanishTranslatorAPI.finishSpeakAfterDraft(
            crew: turnCrew,
            direction: turnDirection,
            english: englishText,
            spanish: spanishText,
            draftTranslation: draft.translation
        ) {
        case .ready:
            phase = .ready
            isPreparingSpeak = false
            preparingElapsedSeconds = 0
        case .speak(let spoken):
            speakResult(spoken, preferNeural: true, language: turnCrew.speakLanguage)
        }
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
            // allowBluetoothHFP not in Xcode 16.4 SDK; rename when CI upgrades.
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
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
        let wantEnglish = SpanishTranslatorAPI.speakLanguageForDirection(direction) != "es"
        let preferFemale = crew.prefersFemaleDeviceVoice
        let voices = AVSpeechSynthesisVoice.speechVoices().filter {
            if wantEnglish {
                return SpanishTranslatorAPI.englishVoiceScore(language: $0.language) >= 0
            }
            return SpanishTranslatorAPI.spanishVoiceScore(language: $0.language) >= 0
        }
        func genderForScore(_ raw: Int) -> Int {
            guard preferFemale else { return raw }
            if raw == 1 { return 2 }
            if raw == 2 { return 1 }
            return raw
        }
        let ranked = voices.sorted { lhs, rhs in
            let l = wantEnglish
                ? SpanishTranslatorAPI.englishPlaybackVoiceScore(
                    language: lhs.language,
                    genderRaw: genderForScore(lhs.gender.rawValue),
                    qualityRaw: lhs.quality.rawValue
                )
                : SpanishTranslatorAPI.jobsiteVoiceScore(
                    language: lhs.language,
                    genderRaw: genderForScore(lhs.gender.rawValue),
                    qualityRaw: lhs.quality.rawValue
                )
            let r = wantEnglish
                ? SpanishTranslatorAPI.englishPlaybackVoiceScore(
                    language: rhs.language,
                    genderRaw: genderForScore(rhs.gender.rawValue),
                    qualityRaw: rhs.quality.rawValue
                )
                : SpanishTranslatorAPI.jobsiteVoiceScore(
                    language: rhs.language,
                    genderRaw: genderForScore(rhs.gender.rawValue),
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

    private func speakResult(_ text: String, preferNeural: Bool, language: String? = nil) {
        let trimmed = SpanishTranslatorAPI.clampSpeakText(text)
        guard !trimmed.isEmpty else {
            // Nothing to say after a draft. Exit .translating so the UI cannot hang.
            if phase == .translating {
                phase = .ready
                statusLabel = lastSuccessStatus.isEmpty
                    ? SpanishTranslatorAPI.statusReady
                    : lastSuccessStatus
                isPreparingSpeak = false
                preparingElapsedSeconds = 0
            }
            return
        }
        allowAppleSpeakFallback = preferNeural
        cancelSpeakPipeline(silence: true)
        // cancelSpeakPipeline already advanced speakGeneration; never reset it downward.
        let generation = speakGeneration
        let turn = turnID
        let snapshotMode = turnVoiceMode
        let snapshotCrew = turnCrew
        let speakLanguage = language ?? SpanishTranslatorAPI.speakLanguageForDirection(turnDirection)
        let appleLanguage = speakLanguage == "es" ? "es-US" : "en-US"

        phase = .preparingVoice
        isPreparingSpeak = true
        preparingElapsedSeconds = 0
        statusLabel = SpanishTranslatorAPI.statusPreparingVoice
        voiceNote = SpanishTranslatorAPI.statusPreparingVoice
        startPreparingTicker(turn: turn)

        guard preferNeural else {
            speakWithAppleFallback(trimmed, turn: turn, speakGen: generation, language: appleLanguage)
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
                    language: speakLanguage,
                    crew: snapshotCrew
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
                    language: speakLanguage,
                    crew: snapshotCrew
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
                self.speakWithAppleFallback(trimmed, turn: turn, speakGen: generation, language: appleLanguage)
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
        // Keep a real MP3 attachment independent of the player's lifetime.
        // A unique filename also prevents an open share sheet from reading a
        // subsequent translation. The OS manages these temporary recordings.
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Beckify-Translation-\(UUID().uuidString).mp3")
        do {
            try data.write(to: audioURL, options: .atomic)
            translatedAudioURL = audioURL
            audioCopyNotice = nil
        } catch {
            translatedAudioURL = nil
            audioCopyNotice = "Couldn’t save the recording. Try Speak again."
        }
        clearPreparingIfCurrent(turn: turn)
        phase = .playing
        statusLabel = SpanishTranslatorAPI.statusPlaying
    }

    private func speakWithAppleFallback(_ text: String, turn: UInt64, speakGen: UInt64, language: String? = nil) {
        guard turn == turnID, speakGen == speakGeneration else { return }
        refreshVoice()
        prepareLoudPlaybackSession()
        // Apple reads the line a person sees. ElevenLabs still gets the tags.
        let spoken = SpanishTranslatorAPI.displayText(text)
        guard !spoken.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: spoken)
        utterance.voice = language.flatMap { AVSpeechSynthesisVoice(language: $0) } ?? selectedVoice
        utterance.volume = 1.0
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * crew.appleRateFactor
        utterance.pitchMultiplier = crew.applePitchMultiplier
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0.08

        // Stay on Preparing voice until didStart — never label Playing early.
        phase = .preparingVoice
        isPreparingSpeak = true
        statusLabel = SpanishTranslatorAPI.preparingVoiceStatus(elapsedSeconds: preparingElapsedSeconds)
        translatedAudioURL = nil
        audioCopyNotice = nil
        let recordingUtterance = AVSpeechUtterance(string: spoken)
        recordingUtterance.voice = utterance.voice
        recordingUtterance.rate = utterance.rate
        recordingUtterance.pitchMultiplier = utterance.pitchMultiplier
        let exporter = TranslatorAudioExporter()
        audioExporter = exporter
        exporter.start(recordingUtterance) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, turn == self.turnID, speakGen == self.speakGeneration else { return }
                switch result {
                case .success(let url): self.translatedAudioURL = url
                case .failure: self.audioCopyNotice = "Couldn’t save device audio. Try Speak again."
                }
            }
        }
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
        language: String,
        crew: CrewTalkMember
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
            language: language,
            crew: crew
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


/// Writes device speech buffers directly to a shareable M4A file. The callback
/// can run off the main thread; the lock protects the file and cancellation.
private final class TranslatorAudioExporter: @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    private let lock = NSLock()
    private var file: AVAudioFile?
    private var finished = false
    private var wroteFrames = false
    private let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("Beckify-Translation-\(UUID().uuidString).m4a")

    func cancel() {
        lock.lock()
        let wasFinished = finished
        finished = true
        file = nil
        lock.unlock()
        synthesizer.stopSpeaking(at: .immediate)
        // Completed files may still be used by a presented share sheet.
        if !wasFinished { try? FileManager.default.removeItem(at: url) }
    }

    func start(_ utterance: AVSpeechUtterance,
               completion: @escaping @Sendable (Result<URL, Error>) -> Void) {
        synthesizer.write(utterance) { [weak self] buffer in
            guard let self, let pcm = buffer as? AVAudioPCMBuffer else { return }
            self.lock.lock()
            guard !self.finished else { self.lock.unlock(); return }
            var result: Result<URL, Error>?
            do {
                if pcm.frameLength == 0 {
                    self.finished = true
                    self.file = nil // Close the file before exposing it to Messages.
                    if self.wroteFrames {
                        result = .success(self.url)
                    } else {
                        throw NSError(domain: "Beckify.AudioExport", code: 1)
                    }
                } else {
                    if self.file == nil {
                        self.file = try AVAudioFile(forWriting: self.url,
                            settings: [
                                AVFormatIDKey: kAudioFormatMPEG4AAC,
                                AVSampleRateKey: pcm.format.sampleRate,
                                AVNumberOfChannelsKey: Int(pcm.format.channelCount),
                                AVEncoderBitRateKey: 64_000,
                            ],
                            commonFormat: pcm.format.commonFormat,
                            interleaved: pcm.format.isInterleaved)
                    }
                    try self.file?.write(from: pcm)
                    self.wroteFrames = true
                }
            } catch {
                self.finished = true
                self.file = nil
                try? FileManager.default.removeItem(at: self.url)
                result = .failure(error)
            }
            self.lock.unlock()
            if let result { completion(result) }
        }
    }
}
