import Foundation

/// WP-302 owns the auto-speak toggle. Wave 0 only publishes the default.
public enum CrewTalkSettings {
    public static let autoSpeakDefault = true
}

/// Visible Crew Talk phases. Playback is `.playing` only after audio actually starts.
public enum CrewTalkPhase: Equatable, Sendable {
    case ready
    case awaitingSpeechAuthorization
    case listening
    case finishingTranscript
    case translating
    case preparingVoice
    case playing
    case cancelled
    case failed
}

public enum CrewTalkSpeechAuthorization: Equatable, Sendable {
    case authorized
    case denied
    case restricted
    case notDetermined
}

/// Pure Crew Talk session. No clock and no randomness — `reduce` is a function of this value.
public struct CrewTalkState: Equatable, Sendable {
    public var phase: CrewTalkPhase
    public var direction: SpanishTranslateDirection
    public var crew: CrewTalkMember
    public var heardText: String
    public var draft: SpanishTranslationDraft?
    public var turnID: UInt64
    public var nextUtteranceID: UInt64
    public var preparingUtteranceID: UInt64?
    public var playingUtteranceID: UInt64?
    /// Turn that armed on-device fallback. Nil means none.
    public var onDeviceTurnID: UInt64?
    public var preparingText: String
    public var errorMessage: String?
    public var autoSpeak: Bool

    public init(
        phase: CrewTalkPhase = .ready,
        direction: SpanishTranslateDirection = .englishToSpanish,
        crew: CrewTalkMember? = nil,
        heardText: String = "",
        draft: SpanishTranslationDraft? = nil,
        turnID: UInt64 = 0,
        nextUtteranceID: UInt64 = 1,
        preparingUtteranceID: UInt64? = nil,
        playingUtteranceID: UInt64? = nil,
        onDeviceTurnID: UInt64? = nil,
        preparingText: String = "",
        errorMessage: String? = nil,
        autoSpeak: Bool = CrewTalkSettings.autoSpeakDefault
    ) {
        self.phase = phase
        self.direction = direction
        let resolved = crew ?? CrewTalkMember.defaultMember(for: direction)
        self.crew = CrewTalkMember.roster(for: direction).contains(resolved)
            ? resolved
            : CrewTalkMember.defaultMember(for: direction)
        self.heardText = heardText
        self.draft = draft
        self.turnID = turnID
        self.nextUtteranceID = nextUtteranceID
        self.preparingUtteranceID = preparingUtteranceID
        self.playingUtteranceID = playingUtteranceID
        self.onDeviceTurnID = onDeviceTurnID
        self.preparingText = preparingText
        self.errorMessage = errorMessage
        self.autoSpeak = autoSpeak
    }
}

public enum CrewTalkEvent: Equatable, Sendable {
    case requestListen
    case speechAuthorization(CrewTalkSpeechAuthorization, turnID: UInt64)
    case partialTranscript(String, turnID: UInt64)
    case recognizerEnded(turnID: UInt64)
    case stopListening(translateAfter: Bool)
    case finishTimeout(turnID: UInt64)
    case submitText(String)
    case remoteTranslated(SpanishTranslationDraft, turnID: UInt64)
    case remoteFailed(httpStatus: Int, message: String, turnID: UInt64)
    case onDeviceTranslated(SpanishTranslationDraft, turnID: UInt64)
    case onDeviceFailed(message: String, turnID: UInt64)
    case neuralReady(utteranceID: UInt64)
    case neuralFailed(utteranceID: UInt64)
    case playbackFinished(utteranceID: UInt64)
    case cancel
    case enteredBackground
    /// Inactive is not background. This event is a no-op.
    case sceneBecameInactive
    case audioInterruption
    case setDirection(SpanishTranslateDirection)
    case setCrew(CrewTalkMember)
    case speakAgain
}

public enum CrewTalkEffect: Equatable, Sendable {
    case requestSpeechAuthorization(turnID: UInt64)
    case startCapture(turnID: UInt64, direction: SpanishTranslateDirection)
    case stopCapture
    case cancelInFlight(turnID: UInt64)
    case translate(
        text: String,
        turnID: UInt64,
        direction: SpanishTranslateDirection,
        voiceMode: SpanishVoiceMode
    )
    case translateOnDevice(text: String, turnID: UInt64, direction: SpanishTranslateDirection)
    case speakNeural(text: String, utteranceID: UInt64, turnID: UInt64, crew: CrewTalkMember)
    case speakApple(text: String, utteranceID: UInt64, turnID: UInt64, crew: CrewTalkMember)
    case stopSpeech
    case armFinishTimeout(turnID: UInt64)
    case cancelFinishTimeout
}

public struct CrewTalkTransition: Equatable, Sendable {
    public var state: CrewTalkState
    public var effects: [CrewTalkEffect]

    public init(state: CrewTalkState, effects: [CrewTalkEffect]) {
        self.state = state
        self.effects = effects
    }
}

/// Pure reducer for Crew Talk listen → translate → speak.
/// D3: every translate request is Jobsite. Clean is not selected here.
public enum CrewTalkStateMachine {
    public static func reduce(_ state: CrewTalkState, _ event: CrewTalkEvent) -> CrewTalkTransition {
        var state = state
        var effects: [CrewTalkEffect] = []

        switch event {
        case .sceneBecameInactive:
            return CrewTalkTransition(state: state, effects: [])

        case .requestListen:
            haltInFlight(&state, &effects, bumpTurn: true)
            state.heardText = ""
            state.errorMessage = nil
            state.phase = .awaitingSpeechAuthorization
            effects.append(.requestSpeechAuthorization(turnID: state.turnID))

        case .speechAuthorization(let auth, let turnID):
            guard turnID == state.turnID, state.phase == .awaitingSpeechAuthorization else {
                return CrewTalkTransition(state: state, effects: [])
            }
            switch auth {
            case .authorized:
                state.phase = .listening
                effects.append(.startCapture(turnID: state.turnID, direction: state.direction))
            case .denied, .restricted, .notDetermined:
                state.phase = .failed
                state.errorMessage = "Speech recognition not authorized."
            }

        case .partialTranscript(let text, let turnID):
            guard turnID == state.turnID, state.phase == .listening else {
                return CrewTalkTransition(state: state, effects: [])
            }
            state.heardText = text

        case .stopListening(let translateAfter):
            guard state.phase == .listening else {
                return CrewTalkTransition(state: state, effects: [])
            }
            effects.append(.stopCapture)
            let text = state.heardText.trimmingCharacters(in: .whitespacesAndNewlines)
            if translateAfter, !text.isEmpty {
                state.heardText = text
                state.phase = .finishingTranscript
                effects.append(.armFinishTimeout(turnID: state.turnID))
            } else {
                state.phase = .ready
            }

        case .recognizerEnded(let turnID):
            guard turnID == state.turnID else {
                return CrewTalkTransition(state: state, effects: [])
            }
            guard state.phase == .listening || state.phase == .finishingTranscript else {
                return CrewTalkTransition(state: state, effects: [])
            }
            resolveFinishing(&state, &effects)

        case .finishTimeout(let turnID):
            guard turnID == state.turnID, state.phase == .finishingTranscript else {
                return CrewTalkTransition(state: state, effects: [])
            }
            resolveFinishing(&state, &effects)

        case .submitText(let raw):
            let text = SpanishTranslatorAPI.clampSourceText(raw)
            guard !text.isEmpty else {
                state.errorMessage = SpanishTranslatorAPI.emptySourceMessage(direction: state.direction)
                return CrewTalkTransition(state: state, effects: [])
            }
            haltInFlight(&state, &effects, bumpTurn: true)
            state.heardText = text
            state.errorMessage = nil
            beginTranslate(&state, &effects, text: text)

        case .remoteTranslated(let draft, let turnID):
            guard turnID == state.turnID, state.phase == .translating, state.onDeviceTurnID == nil else {
                return CrewTalkTransition(state: state, effects: [])
            }
            acceptDraft(draft, &state, &effects)

        case .remoteFailed(let httpStatus, let message, let turnID):
            guard turnID == state.turnID, state.phase == .translating, state.onDeviceTurnID == nil else {
                return CrewTalkTransition(state: state, effects: [])
            }
            // I6: the predicate is the API helper, not a second copy of the status table.
            if SpanishTranslatorAPI.shouldAttemptOnDeviceFallback(httpStatus: httpStatus) {
                state.onDeviceTurnID = state.turnID
                state.errorMessage = message
                state.phase = .translating
                effects.append(.translateOnDevice(
                    text: state.heardText,
                    turnID: state.turnID,
                    direction: state.direction
                ))
            } else {
                state.phase = .failed
                state.errorMessage = message
                state.onDeviceTurnID = nil
            }

        case .onDeviceTranslated(let draft, let turnID):
            guard turnID == state.turnID, state.onDeviceTurnID == turnID, state.phase == .translating else {
                return CrewTalkTransition(state: state, effects: [])
            }
            acceptDraft(draft, &state, &effects)

        case .onDeviceFailed(let message, let turnID):
            guard turnID == state.turnID, state.onDeviceTurnID == turnID else {
                return CrewTalkTransition(state: state, effects: [])
            }
            state.phase = .failed
            state.errorMessage = message
            state.onDeviceTurnID = nil
            state.preparingUtteranceID = nil
            state.preparingText = ""

        case .neuralReady(let utteranceID):
            guard state.phase == .preparingVoice, state.preparingUtteranceID == utteranceID else {
                return CrewTalkTransition(state: state, effects: [])
            }
            state.phase = .playing
            state.playingUtteranceID = utteranceID
            state.preparingUtteranceID = nil
            state.preparingText = ""

        case .neuralFailed(let utteranceID):
            guard state.phase == .preparingVoice, state.preparingUtteranceID == utteranceID else {
                return CrewTalkTransition(state: state, effects: [])
            }
            let spoken = state.preparingText
            state.preparingUtteranceID = nil
            state.preparingText = ""
            guard !spoken.isEmpty else {
                state.phase = .ready
                return CrewTalkTransition(state: state, effects: [])
            }
            let appleID = state.nextUtteranceID
            state.nextUtteranceID &+= 1
            state.playingUtteranceID = appleID
            state.phase = .playing
            effects.append(.speakApple(
                text: spoken,
                utteranceID: appleID,
                turnID: state.turnID,
                crew: state.crew
            ))

        case .playbackFinished(let utteranceID):
            guard state.phase == .playing, state.playingUtteranceID == utteranceID else {
                return CrewTalkTransition(state: state, effects: [])
            }
            state.phase = .ready
            state.playingUtteranceID = nil

        case .cancel:
            haltInFlight(&state, &effects, bumpTurn: true)
            state.phase = .cancelled
            state.errorMessage = nil

        case .enteredBackground:
            switch state.phase {
            case .ready, .failed, .cancelled:
                return CrewTalkTransition(state: state, effects: [])
            case .awaitingSpeechAuthorization, .listening, .finishingTranscript,
                 .translating, .preparingVoice, .playing:
                haltInFlight(&state, &effects, bumpTurn: true)
                state.phase = .cancelled
                state.errorMessage = nil
            }

        case .audioInterruption:
            guard state.phase == .preparingVoice || state.phase == .playing else {
                return CrewTalkTransition(state: state, effects: [])
            }
            effects.append(.stopSpeech)
            state.phase = .ready
            state.preparingUtteranceID = nil
            state.playingUtteranceID = nil
            state.preparingText = ""

        case .setDirection(let direction):
            guard direction != state.direction else {
                return CrewTalkTransition(state: state, effects: [])
            }
            haltInFlight(&state, &effects, bumpTurn: true)
            state.direction = direction
            state.heardText = ""
            state.draft = nil
            state.errorMessage = nil
            state.phase = .ready
            if !CrewTalkMember.roster(for: direction).contains(state.crew) {
                state.crew = CrewTalkMember.defaultMember(for: direction)
            }

        case .setCrew(let member):
            let roster = CrewTalkMember.roster(for: state.direction)
            let resolved = roster.contains(member) ? member : CrewTalkMember.defaultMember(for: state.direction)
            guard resolved != state.crew else {
                return CrewTalkTransition(state: state, effects: [])
            }
            if state.phase == .playing || state.phase == .preparingVoice {
                effects.append(.stopSpeech)
                state.preparingUtteranceID = nil
                state.playingUtteranceID = nil
                state.preparingText = ""
                state.phase = .ready
            }
            state.crew = resolved

        case .speakAgain:
            let spoken = SpanishTranslatorAPI.clampSpeakText(state.draft?.translation ?? "")
            guard !spoken.isEmpty else {
                return CrewTalkTransition(state: state, effects: [])
            }
            if state.phase == .playing || state.phase == .preparingVoice {
                effects.append(.stopSpeech)
            }
            let id = state.nextUtteranceID
            state.nextUtteranceID &+= 1
            state.preparingUtteranceID = id
            state.playingUtteranceID = nil
            state.preparingText = spoken
            state.phase = .preparingVoice
            state.errorMessage = nil
            effects.append(.speakNeural(
                text: spoken,
                utteranceID: id,
                turnID: state.turnID,
                crew: state.crew
            ))
        }

        if !CrewTalkMember.roster(for: state.direction).contains(state.crew) {
            state.crew = CrewTalkMember.defaultMember(for: state.direction)
        }
        return CrewTalkTransition(state: state, effects: effects)
    }

    private static func haltInFlight(
        _ state: inout CrewTalkState,
        _ effects: inout [CrewTalkEffect],
        bumpTurn: Bool
    ) {
        switch state.phase {
        case .awaitingSpeechAuthorization, .listening, .finishingTranscript:
            effects.append(.stopCapture)
        case .preparingVoice, .playing:
            effects.append(.stopSpeech)
        case .ready, .translating, .cancelled, .failed:
            break
        }
        if state.phase == .finishingTranscript {
            effects.append(.cancelFinishTimeout)
        }
        switch state.phase {
        case .ready, .failed, .cancelled:
            break
        case .awaitingSpeechAuthorization, .listening, .finishingTranscript,
             .translating, .preparingVoice, .playing:
            effects.append(.cancelInFlight(turnID: state.turnID))
        }
        state.preparingUtteranceID = nil
        state.playingUtteranceID = nil
        state.preparingText = ""
        state.onDeviceTurnID = nil
        if bumpTurn {
            state.turnID &+= 1
        }
    }

    /// Leave `.finishingTranscript` (or a recognizer end while listening). Never sticks.
    private static func resolveFinishing(
        _ state: inout CrewTalkState,
        _ effects: inout [CrewTalkEffect]
    ) {
        if state.phase == .listening {
            effects.append(.stopCapture)
        }
        if state.phase == .finishingTranscript {
            effects.append(.cancelFinishTimeout)
        }
        let text = state.heardText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            state.phase = .ready
            return
        }
        state.heardText = text
        beginTranslate(&state, &effects, text: text)
    }

    private static func beginTranslate(
        _ state: inout CrewTalkState,
        _ effects: inout [CrewTalkEffect],
        text: String
    ) {
        state.phase = .translating
        state.onDeviceTurnID = nil
        state.preparingUtteranceID = nil
        state.playingUtteranceID = nil
        state.preparingText = ""
        // D3: Clean is gone. Every request is Jobsite. Chrome lives elsewhere.
        effects.append(.translate(
            text: text,
            turnID: state.turnID,
            direction: state.direction,
            voiceMode: .jobsite
        ))
    }

    private static func acceptDraft(
        _ draft: SpanishTranslationDraft,
        _ state: inout CrewTalkState,
        _ effects: inout [CrewTalkEffect]
    ) {
        state.draft = draft
        state.onDeviceTurnID = nil
        state.errorMessage = nil
        let spoken = SpanishTranslatorAPI.clampSpeakText(draft.translation)
        guard state.autoSpeak, !spoken.isEmpty else {
            state.phase = .ready
            state.preparingUtteranceID = nil
            state.preparingText = ""
            return
        }
        let id = state.nextUtteranceID
        state.nextUtteranceID &+= 1
        state.preparingUtteranceID = id
        state.playingUtteranceID = nil
        state.preparingText = spoken
        state.phase = .preparingVoice
        effects.append(.speakNeural(
            text: spoken,
            utteranceID: id,
            turnID: state.turnID,
            crew: state.crew
        ))
    }
}

extension CrewTalkMember {
    /// D1: direction picks the roster. English → Spanish is Tito only.
    public static func roster(for direction: SpanishTranslateDirection) -> [CrewTalkMember] {
        switch direction {
        case .englishToSpanish:
            return [.titoSolano]
        case .spanishToEnglish:
            return [.bodieHale, .juniePell, .pearl, .sloaneMerritt]
        }
    }

    /// D1 defaults: Tito for English → Spanish, Bodie for Spanish → English.
    public static func defaultMember(for direction: SpanishTranslateDirection) -> CrewTalkMember {
        switch direction {
        case .englishToSpanish:
            return .titoSolano
        case .spanishToEnglish:
            return .bodieHale
        }
    }
}
