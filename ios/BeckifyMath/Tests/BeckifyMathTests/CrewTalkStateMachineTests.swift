import XCTest
@testable import BeckifyMath

/// Minimal speak plan for assertions. Not part of Sources — WP-103 must not declare this type there.
struct CrewTalkSpeakPlan: Equatable {
    enum Kind: Equatable {
        case neural
        case apple
    }

    var kind: Kind
    var text: String
    var utteranceID: UInt64
    var turnID: UInt64
    var crew: CrewTalkMember
}

final class CrewTalkStateMachineTests: XCTestCase {
    private func step(_ state: CrewTalkState, _ event: CrewTalkEvent) -> CrewTalkTransition {
        CrewTalkStateMachine.reduce(state, event)
    }

    private func draft(_ translation: String, source: String = "hello") -> SpanishTranslationDraft {
        SpanishTranslationDraft(
            translation: translation,
            sourceText: source,
            sourceLanguage: "en",
            targetLanguage: "es",
            engine: "beckify"
        )
    }

    private func speakPlans(_ effects: [CrewTalkEffect]) -> [CrewTalkSpeakPlan] {
        effects.compactMap { effect in
            switch effect {
            case .speakNeural(let text, let utteranceID, let turnID, let crew):
                return CrewTalkSpeakPlan(kind: .neural, text: text, utteranceID: utteranceID, turnID: turnID, crew: crew)
            case .speakApple(let text, let utteranceID, let turnID, let crew):
                return CrewTalkSpeakPlan(kind: .apple, text: text, utteranceID: utteranceID, turnID: turnID, crew: crew)
            default:
                return nil
            }
        }
    }

    private func hasSpeakApple(_ effects: [CrewTalkEffect]) -> Bool {
        effects.contains { effect in
            if case .speakApple = effect { return true }
            return false
        }
    }

    private func hasStopSpeech(_ effects: [CrewTalkEffect]) -> Bool {
        effects.contains { effect in
            if case .stopSpeech = effect { return true }
            return false
        }
    }

    private func listening(_ text: String = "Where's the breaker?") -> CrewTalkState {
        var state = CrewTalkState()
        let requested = step(state, .requestListen)
        state = requested.state
        let authed = step(state, .speechAuthorization(.authorized, turnID: state.turnID))
        state = authed.state
        return step(state, .partialTranscript(text, turnID: state.turnID)).state
    }

    private func translating(_ text: String = "Where's the breaker?") -> CrewTalkState {
        step(CrewTalkState(), .submitText(text)).state
    }

    private func preparing() -> (CrewTalkState, UInt64) {
        let translating = translating()
        let result = step(translating, .remoteTranslated(draft("¿Dónde está el breaker?"), turnID: translating.turnID))
        let utterance = result.state.preparingUtteranceID ?? 0
        return (result.state, utterance)
    }

    func testInvariantI1_staleTurnEventsIgnored() {
        let base = translating()
        let turn = base.turnID
        let staleTurn = turn &- 1
        let staleEvents: [CrewTalkEvent] = [
            .speechAuthorization(.authorized, turnID: staleTurn),
            .partialTranscript("nope", turnID: staleTurn),
            .recognizerEnded(turnID: staleTurn),
            .finishTimeout(turnID: staleTurn),
            .remoteTranslated(draft("stale"), turnID: staleTurn),
            .remoteFailed(httpStatus: 500, message: "stale", turnID: staleTurn),
            .onDeviceTranslated(draft("stale device"), turnID: staleTurn),
            .onDeviceFailed(message: "stale", turnID: staleTurn),
        ]
        for event in staleEvents {
            let result = step(base, event)
            XCTAssertEqual(result.state, base, "\(event)")
            XCTAssertTrue(result.effects.isEmpty, "\(event)")
        }

        let (preparingState, utterance) = preparing()
        let staleNeural = step(preparingState, .neuralFailed(utteranceID: utterance &- 1))
        XCTAssertEqual(staleNeural.state, preparingState)
        XCTAssertTrue(staleNeural.effects.isEmpty)
        XCTAssertFalse(hasSpeakApple(staleNeural.effects))

        let ready = step(preparingState, .neuralReady(utteranceID: utterance))
        XCTAssertEqual(ready.state.phase, .playing)
        let staleDone = step(ready.state, .playbackFinished(utteranceID: utterance &- 1))
        XCTAssertEqual(staleDone.state, ready.state)
        XCTAssertTrue(staleDone.effects.isEmpty)

        let finishing = step(listening(), .stopListening(translateAfter: true))
        XCTAssertEqual(finishing.state.phase, .finishingTranscript)
        let staleFinish = step(finishing.state, .finishTimeout(turnID: finishing.state.turnID &- 1))
        XCTAssertEqual(staleFinish.state, finishing.state)
        XCTAssertTrue(staleFinish.effects.isEmpty)
    }

    func testInvariantI2_cancelBackgroundInterruptionNeverEmitSpeakApple() {
        let (preparingState, _) = preparing()
        let playing = step(preparingState, .neuralReady(utteranceID: preparingState.preparingUtteranceID ?? 0)).state
        let busy: [CrewTalkState] = [preparingState, playing, listening()]
        let silencing: [CrewTalkEvent] = [.cancel, .enteredBackground, .audioInterruption]
        for state in busy {
            for event in silencing {
                let result = step(state, event)
                XCTAssertFalse(hasSpeakApple(result.effects), "\(event) from \(state.phase)")
            }
        }

        let cancelled = step(playing, .cancel)
        XCTAssertEqual(cancelled.state.phase, .cancelled)
        XCTAssertEqual(cancelled.state.draft, playing.draft)
        XCTAssertTrue(hasStopSpeech(cancelled.effects))
        XCTAssertFalse(hasSpeakApple(cancelled.effects))

        let background = step(playing, .enteredBackground)
        XCTAssertEqual(background.state.phase, .cancelled)
        XCTAssertTrue(hasStopSpeech(background.effects))
        XCTAssertFalse(hasSpeakApple(background.effects))

        let interrupted = step(playing, .audioInterruption)
        XCTAssertEqual(interrupted.state.phase, .ready)
        XCTAssertEqual(interrupted.state.draft, playing.draft)
        XCTAssertTrue(hasStopSpeech(interrupted.effects))
        XCTAssertFalse(hasSpeakApple(interrupted.effects))

        // Inactive is not background.
        let inactive = step(playing, .sceneBecameInactive)
        XCTAssertEqual(inactive.state, playing)
        XCTAssertTrue(inactive.effects.isEmpty)
        let idleBackground = step(CrewTalkState(), .enteredBackground)
        XCTAssertEqual(idleBackground.state.phase, .ready)
        XCTAssertTrue(idleBackground.effects.isEmpty)
    }

    func testInvariantI3_neuralFailedSpeaksAppleOnlyForSamePreparingUtterance() {
        let (preparingState, utterance) = preparing()
        let wrong = step(preparingState, .neuralFailed(utteranceID: utterance &+ 9))
        XCTAssertEqual(wrong.state, preparingState)
        XCTAssertTrue(speakPlans(wrong.effects).isEmpty)

        let failed = step(preparingState, .neuralFailed(utteranceID: utterance))
        let plans = speakPlans(failed.effects)
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans[0].kind, .apple)
        XCTAssertEqual(plans[0].text, "¿Dónde está el breaker?")
        XCTAssertEqual(plans[0].crew, .titoSolano)
        XCTAssertNotEqual(plans[0].utteranceID, utterance)
        XCTAssertEqual(failed.state.phase, .playing)
        XCTAssertEqual(failed.state.playingUtteranceID, plans[0].utteranceID)

        let again = step(failed.state, .neuralFailed(utteranceID: utterance))
        XCTAssertEqual(again.state, failed.state)
        XCTAssertTrue(again.effects.isEmpty)
    }

    func testInvariantI4_directionChangeClearsHeardTextDraftAndCancels() {
        var state = listening("Kill the power.")
        let translated = step(translating(), .remoteTranslated(draft("Corta la corriente."), turnID: translating().turnID))
        state.draft = translated.state.draft
        state.phase = .playing
        state.playingUtteranceID = 4
        state.crew = .titoSolano

        let flipped = step(state, .setDirection(.spanishToEnglish))
        XCTAssertEqual(flipped.state.heardText, "")
        XCTAssertNil(flipped.state.draft)
        XCTAssertEqual(flipped.state.direction, .spanishToEnglish)
        XCTAssertEqual(flipped.state.crew, .bodieHale)
        XCTAssertNotEqual(flipped.state.phase, .playing)
        XCTAssertNotEqual(flipped.state.phase, .listening)
        XCTAssertTrue(hasStopSpeech(flipped.effects))
        XCTAssertTrue(flipped.effects.contains { effect in
            if case .cancelInFlight = effect { return true }
            return false
        })
        XCTAssertFalse(hasSpeakApple(flipped.effects))

        let same = step(flipped.state, .setDirection(.spanishToEnglish))
        XCTAssertEqual(same.state, flipped.state)
        XCTAssertTrue(same.effects.isEmpty)
    }

    func testInvariantI5_finishingAlwaysResolves() {
        let withText = step(listening("Hand me that conduit."), .stopListening(translateAfter: true))
        XCTAssertEqual(withText.state.phase, .finishingTranscript)
        XCTAssertTrue(withText.effects.contains { effect in
            if case .armFinishTimeout = effect { return true }
            return false
        })

        let timed = step(withText.state, .finishTimeout(turnID: withText.state.turnID))
        XCTAssertNotEqual(timed.state.phase, .finishingTranscript)
        XCTAssertEqual(timed.state.phase, .translating)
        XCTAssertTrue(timed.effects.contains { effect in
            if case .translate(let text, _, _, let mode) = effect {
                return text == "Hand me that conduit." && mode == .jobsite
            }
            return false
        })

        let ended = step(withText.state, .recognizerEnded(turnID: withText.state.turnID))
        XCTAssertNotEqual(ended.state.phase, .finishingTranscript)
        XCTAssertEqual(ended.state.phase, .translating)

        var empty = listening("   ")
        empty.heardText = "   "
        let finishingEmpty = step(empty, .stopListening(translateAfter: true))
        XCTAssertEqual(finishingEmpty.state.phase, .ready)

        var stuck = withText.state
        stuck.heardText = "  \n"
        let resolvedEmpty = step(stuck, .finishTimeout(turnID: stuck.turnID))
        XCTAssertEqual(resolvedEmpty.state.phase, .ready)
        XCTAssertNotEqual(resolvedEmpty.state.phase, .finishingTranscript)
    }

    func testInvariantI6_remoteFailedFallbackMatchesShouldAttemptOnDeviceFallback() {
        let statuses = [0, 200, 204, 302, 401, 404, 405, 408, 429, 500, 503]
        for status in statuses {
            let state = translating("Move the ladder.")
            let result = step(state, .remoteFailed(httpStatus: status, message: "http \(status)", turnID: state.turnID))
            let expectFallback = SpanishTranslatorAPI.shouldAttemptOnDeviceFallback(httpStatus: status)
            let didFallback = result.effects.contains { effect in
                if case .translateOnDevice = effect { return true }
                return false
            }
            XCTAssertEqual(didFallback, expectFallback, "status \(status)")
            if expectFallback {
                XCTAssertEqual(result.state.phase, .translating)
                XCTAssertEqual(result.state.onDeviceTurnID, state.turnID)
            } else {
                XCTAssertEqual(result.state.phase, .failed)
                XCTAssertNil(result.state.onDeviceTurnID)
                XCTAssertFalse(didFallback)
            }
            XCTAssertFalse(hasSpeakApple(result.effects))
        }
    }

    func testInvariantI7_draftOnlyReplacedByMatchingTurn() {
        let old = draft("viejo")
        var state = translating("Watch your head.")
        state.draft = old
        let turn = state.turnID

        let mismatch = step(state, .remoteTranslated(draft("nuevo"), turnID: turn &- 1))
        XCTAssertEqual(mismatch.state.draft, old)
        XCTAssertTrue(mismatch.effects.isEmpty)

        let match = step(state, .remoteTranslated(draft("nuevo"), turnID: turn))
        XCTAssertEqual(match.state.draft?.translation, "nuevo")
        XCTAssertNotEqual(match.state.draft, old)

        var onDevice = state
        onDevice.draft = old
        onDevice.onDeviceTurnID = turn
        let deviceMismatch = step(onDevice, .onDeviceTranslated(draft("device"), turnID: turn &- 1))
        XCTAssertEqual(deviceMismatch.state.draft, old)
        let deviceMatch = step(onDevice, .onDeviceTranslated(draft("device"), turnID: turn))
        XCTAssertEqual(deviceMatch.state.draft?.translation, "device")

        let unrelated = step(match.state, .partialTranscript("nope", turnID: turn))
        XCTAssertEqual(unrelated.state.draft, match.state.draft)
    }

    func testInvariantI8_crewChangeWhilePlayingStopsSpeechKeepsDraft() {
        var state = CrewTalkState(direction: .spanishToEnglish, crew: .bodieHale)
        state.phase = .playing
        state.playingUtteranceID = 3
        state.draft = draft("Where is the breaker?", source: "¿Dónde está el breaker?")
        state.heardText = "¿Dónde está el breaker?"
        state.turnID = 8

        let changed = step(state, .setCrew(.juniePell))
        XCTAssertEqual(changed.state.crew, .juniePell)
        XCTAssertEqual(changed.state.draft, state.draft)
        XCTAssertEqual(changed.state.heardText, state.heardText)
        XCTAssertEqual(changed.state.phase, .ready)
        XCTAssertNil(changed.state.playingUtteranceID)
        XCTAssertTrue(hasStopSpeech(changed.effects))
        XCTAssertFalse(hasSpeakApple(changed.effects))

        let pearl = step(changed.state, .setCrew(.pearl))
        XCTAssertEqual(pearl.state.crew, .pearl)
        XCTAssertEqual(pearl.state.draft, state.draft)
    }

    func testInvariantI9_crewAlwaysOnTheRoster() {
        XCTAssertEqual(CrewTalkMember.roster(for: .englishToSpanish), [.titoSolano, .lupitaReyes])
        XCTAssertEqual(CrewTalkMember.roster(for: .englishToSpanish).count, 2)
        XCTAssertEqual(CrewTalkMember.roster(for: .spanishToEnglish).count, 4)
        XCTAssertEqual(
            CrewTalkMember.roster(for: .spanishToEnglish),
            [.bodieHale, .juniePell, .pearl, .sloaneMerritt]
        )
        XCTAssertEqual(CrewTalkMember.defaultMember(for: .englishToSpanish), .titoSolano)
        XCTAssertEqual(CrewTalkMember.defaultMember(for: .spanishToEnglish), .bodieHale)
        XCTAssertTrue(CrewTalkSettings.autoSpeakDefault)

        var english = CrewTalkState()
        for member in CrewTalkMember.allCases {
            let result = step(english, .setCrew(member))
            let roster = CrewTalkMember.roster(for: .englishToSpanish)
            XCTAssertTrue(roster.contains(result.state.crew))
            if roster.contains(member) {
                XCTAssertEqual(result.state.crew, member)
            } else {
                XCTAssertEqual(result.state.crew, .titoSolano)
            }
            english = result.state
        }

        var spanish = step(CrewTalkState(), .setDirection(.spanishToEnglish)).state
        XCTAssertEqual(spanish.crew, .bodieHale)
        for member in [CrewTalkMember.bodieHale, .juniePell, .pearl, .sloaneMerritt, .titoSolano, .lupitaReyes] {
            let result = step(spanish, .setCrew(member))
            let roster = CrewTalkMember.roster(for: .spanishToEnglish)
            XCTAssertTrue(roster.contains(result.state.crew))
            if roster.contains(member) {
                XCTAssertEqual(result.state.crew, member)
            } else {
                XCTAssertEqual(result.state.crew, .bodieHale)
            }
            spanish = result.state
        }

        let back = step(spanish, .setDirection(.englishToSpanish))
        XCTAssertEqual(back.state.crew, .titoSolano)
        XCTAssertTrue(CrewTalkMember.roster(for: back.state.direction).contains(back.state.crew))
    }

    func testHappyPath() {
        var state = CrewTalkState()
        XCTAssertEqual(state.crew, .titoSolano)
        XCTAssertEqual(state.autoSpeak, CrewTalkSettings.autoSpeakDefault)

        let requested = step(state, .requestListen)
        state = requested.state
        XCTAssertEqual(state.phase, .awaitingSpeechAuthorization)
        XCTAssertEqual(requested.effects, [.requestSpeechAuthorization(turnID: state.turnID)])

        let authed = step(state, .speechAuthorization(.authorized, turnID: state.turnID))
        state = authed.state
        XCTAssertEqual(state.phase, .listening)
        XCTAssertTrue(authed.effects.contains { effect in
            if case .startCapture(let turnID, let direction) = effect {
                return turnID == state.turnID && direction == .englishToSpanish
            }
            return false
        })

        state = step(state, .partialTranscript("Where's the breaker?", turnID: state.turnID)).state
        let finishing = step(state, .stopListening(translateAfter: true))
        state = finishing.state
        XCTAssertEqual(state.phase, .finishingTranscript)

        let translated = step(state, .recognizerEnded(turnID: state.turnID))
        state = translated.state
        XCTAssertEqual(state.phase, .translating)
        XCTAssertTrue(translated.effects.contains { effect in
            if case .translate(let text, _, let direction, let mode) = effect {
                return text == "Where's the breaker?" && direction == .englishToSpanish && mode == .jobsite
            }
            return false
        })

        let spoken = step(state, .remoteTranslated(draft("¿Dónde está el breaker?"), turnID: state.turnID))
        state = spoken.state
        XCTAssertEqual(state.draft?.translation, "¿Dónde está el breaker?")
        XCTAssertEqual(state.phase, .preparingVoice)
        let plans = speakPlans(spoken.effects)
        XCTAssertEqual(plans.map(\.kind), [.neural])
        XCTAssertEqual(plans[0].crew, .titoSolano)

        let playing = step(state, .neuralReady(utteranceID: state.preparingUtteranceID ?? 0))
        state = playing.state
        XCTAssertEqual(state.phase, .playing)

        let done = step(state, .playbackFinished(utteranceID: state.playingUtteranceID ?? 0))
        XCTAssertEqual(done.state.phase, .ready)
        XCTAssertEqual(done.state.draft?.translation, "¿Dónde está el breaker?")
        XCTAssertEqual(done.state.crew, .titoSolano)
        XCTAssertFalse(hasSpeakApple(spoken.effects + playing.effects + done.effects))
    }

    func testAuthAfterCancelDoesNotStartCapture() {
        let requested = step(CrewTalkState(), .requestListen)
        XCTAssertEqual(requested.state.phase, .awaitingSpeechAuthorization)
        let turn = requested.state.turnID
        let cancelled = step(requested.state, .cancel)
        XCTAssertEqual(cancelled.state.phase, .cancelled)
        XCTAssertNotEqual(cancelled.state.turnID, turn)

        let late = step(cancelled.state, .speechAuthorization(.authorized, turnID: turn))
        XCTAssertEqual(late.state, cancelled.state)
        XCTAssertTrue(late.effects.isEmpty)
        XCTAssertFalse(late.effects.contains { effect in
            if case .startCapture = effect { return true }
            return false
        })

        let sameTurnAfterCancel = step(cancelled.state, .speechAuthorization(.authorized, turnID: cancelled.state.turnID))
        XCTAssertNotEqual(sameTurnAfterCancel.state.phase, .listening)
        XCTAssertFalse(sameTurnAfterCancel.effects.contains { effect in
            if case .startCapture = effect { return true }
            return false
        })
    }

    func testFinishTimeout() {
        let finishing = step(listening("We need more wire."), .stopListening(translateAfter: true))
        XCTAssertEqual(finishing.state.phase, .finishingTranscript)
        let turn = finishing.state.turnID
        let timed = step(finishing.state, .finishTimeout(turnID: turn))
        XCTAssertEqual(timed.state.phase, .translating)
        XCTAssertEqual(timed.state.heardText, "We need more wire.")
        XCTAssertTrue(timed.effects.contains { effect in
            if case .translate(let text, let effectTurn, _, let mode) = effect {
                return text == "We need more wire." && effectTurn == turn && mode == .jobsite
            }
            return false
        })
        XCTAssertTrue(timed.effects.contains { effect in
            if case .cancelFinishTimeout = effect { return true }
            return false
        })
    }

    func testRecognizerEnded() {
        let heard = listening("Hold this for a second.")
        let ended = step(heard, .recognizerEnded(turnID: heard.turnID))
        XCTAssertEqual(ended.state.phase, .translating)
        XCTAssertNotEqual(ended.state.phase, .finishingTranscript)
        XCTAssertTrue(ended.effects.contains { effect in
            if case .stopCapture = effect { return true }
            return false
        })
        XCTAssertTrue(ended.effects.contains { effect in
            if case .translate(let text, _, _, let mode) = effect {
                return text == "Hold this for a second." && mode == .jobsite
            }
            return false
        })

        let quiet = listening("")
        var cleared = quiet
        cleared.heardText = ""
        let endedEmpty = step(cleared, .recognizerEnded(turnID: cleared.turnID))
        XCTAssertEqual(endedEmpty.state.phase, .ready)
        XCTAssertFalse(endedEmpty.effects.contains { effect in
            if case .translate = effect { return true }
            return false
        })
    }

    func testStalePlaybackFinished() {
        let (preparingState, utterance) = preparing()
        let playing = step(preparingState, .neuralReady(utteranceID: utterance)).state
        XCTAssertEqual(playing.phase, .playing)
        let stale = step(playing, .playbackFinished(utteranceID: utterance &+ 1))
        XCTAssertEqual(stale.state, playing)
        XCTAssertTrue(stale.effects.isEmpty)
        XCTAssertEqual(stale.state.phase, .playing)

        let finished = step(playing, .playbackFinished(utteranceID: utterance))
        XCTAssertEqual(finished.state.phase, .ready)
        XCTAssertEqual(finished.state.draft, playing.draft)
    }

    func testOnDeviceFail() {
        let state = translating("Lunch break.")
        let fallback = step(state, .remoteFailed(httpStatus: 503, message: "upstream", turnID: state.turnID))
        XCTAssertTrue(SpanishTranslatorAPI.shouldAttemptOnDeviceFallback(httpStatus: 503))
        XCTAssertEqual(fallback.state.phase, .translating)
        XCTAssertEqual(fallback.state.heardText, "Lunch break.")
        XCTAssertTrue(fallback.effects.contains { effect in
            if case .translateOnDevice(let text, let turnID, let direction) = effect {
                return text == "Lunch break." && turnID == state.turnID && direction == .englishToSpanish
            }
            return false
        })

        let failed = step(fallback.state, .onDeviceFailed(message: "languages not installed", turnID: state.turnID))
        XCTAssertEqual(failed.state.phase, .failed)
        XCTAssertEqual(failed.state.errorMessage, "languages not installed")
        XCTAssertEqual(failed.state.heardText, "Lunch break.")
        XCTAssertNil(failed.state.draft)
        XCTAssertNil(failed.state.onDeviceTurnID)
        XCTAssertFalse(hasSpeakApple(failed.effects))
        XCTAssertTrue(failed.effects.isEmpty)
    }

    func testSeededFuzz1000Steps() {
        let first = fuzz(seed: 103_000, steps: 1000)
        let second = fuzz(seed: 103_000, steps: 1000)
        XCTAssertEqual(first, second)
    }

    @discardableResult
    private func fuzz(seed: UInt64, steps: Int) -> CrewTalkState {
        var rng = LCG(state: seed)
        var state = CrewTalkState()
        let members: [CrewTalkMember] = [.titoSolano, .lupitaReyes, .bodieHale, .juniePell, .pearl, .sloaneMerritt]
        let directions: [SpanishTranslateDirection] = [.englishToSpanish, .spanishToEnglish]
        let auths: [CrewTalkSpeechAuthorization] = [.authorized, .denied, .restricted, .notDetermined]
        let statuses = [0, 200, 204, 401, 404, 408, 429, 500]
        for _ in 0..<steps {
            let event = fuzzEvent(
                state: state,
                rng: &rng,
                members: members,
                directions: directions,
                auths: auths,
                statuses: statuses
            )
            let before = state
            let result = step(state, event)
            state = result.state
            assertFuzzInvariants(before: before, event: event, after: result)
        }
        return state
    }

    private func fuzzEvent(
        state: CrewTalkState,
        rng: inout LCG,
        members: [CrewTalkMember],
        directions: [SpanishTranslateDirection],
        auths: [CrewTalkSpeechAuthorization],
        statuses: [Int]
    ) -> CrewTalkEvent {
        let turn = state.turnID &- UInt64(rng.int(2))
        switch rng.int(20) {
        case 0: return .requestListen
        case 1: return .speechAuthorization(auths[rng.int(auths.count)], turnID: turn)
        case 2: return .partialTranscript(["", "hey", "breaker"][rng.int(3)], turnID: turn)
        case 3: return .recognizerEnded(turnID: turn)
        case 4: return .stopListening(translateAfter: rng.int(2) == 0)
        case 5: return .finishTimeout(turnID: turn)
        case 6: return .submitText(["", "  ", "Kill the power.", "hola"][rng.int(4)])
        case 7: return .remoteTranslated(draft("sí \(rng.int(5))"), turnID: turn)
        case 8: return .remoteFailed(httpStatus: statuses[rng.int(statuses.count)], message: "x", turnID: turn)
        case 9: return .onDeviceTranslated(draft("on \(rng.int(5))"), turnID: turn)
        case 10: return .onDeviceFailed(message: "nope", turnID: turn)
        case 11: return .neuralReady(utteranceID: state.preparingUtteranceID ?? UInt64(rng.int(6)))
        case 12: return .neuralFailed(utteranceID: state.preparingUtteranceID ?? UInt64(rng.int(6) &+ 1))
        case 13: return .playbackFinished(utteranceID: state.playingUtteranceID ?? UInt64(rng.int(6) &+ 3))
        case 14: return .cancel
        case 15: return .enteredBackground
        case 16: return .sceneBecameInactive
        case 17: return .audioInterruption
        case 18: return .setDirection(directions[rng.int(directions.count)])
        default: return .setCrew(members[rng.int(members.count)])
        }
    }

    private func assertFuzzInvariants(
        before: CrewTalkState,
        event: CrewTalkEvent,
        after: CrewTalkTransition
    ) {
        let state = after.state
        XCTAssertTrue(CrewTalkMember.roster(for: state.direction).contains(state.crew))
        for effect in after.effects {
            if case .translate(_, _, _, let mode) = effect {
                XCTAssertEqual(mode, .jobsite)
            }
        }

        switch event {
        case .cancel, .enteredBackground, .audioInterruption:
            XCTAssertFalse(hasSpeakApple(after.effects))
        case .sceneBecameInactive:
            XCTAssertEqual(state, before)
            XCTAssertTrue(after.effects.isEmpty)
        case .setDirection(let direction) where direction != before.direction:
            XCTAssertEqual(state.heardText, "")
            XCTAssertNil(state.draft)
            XCTAssertFalse(hasSpeakApple(after.effects))
        case .setCrew:
            if before.phase == .playing || before.phase == .preparingVoice {
                XCTAssertEqual(state.draft, before.draft)
                XCTAssertFalse(hasSpeakApple(after.effects))
                if state.crew != before.crew {
                    XCTAssertTrue(hasStopSpeech(after.effects))
                    XCTAssertNotEqual(state.phase, .playing)
                    XCTAssertNotEqual(state.phase, .preparingVoice)
                }
            }
        case .remoteFailed(let status, _, let turnID)
            where turnID == before.turnID && before.phase == .translating && before.onDeviceTurnID == nil:
            let expect = SpanishTranslatorAPI.shouldAttemptOnDeviceFallback(httpStatus: status)
            let did = after.effects.contains { effect in
                if case .translateOnDevice = effect { return true }
                return false
            }
            XCTAssertEqual(did, expect)
        case .remoteTranslated(let draft, let turnID):
            if turnID == before.turnID && before.phase == .translating && before.onDeviceTurnID == nil {
                XCTAssertEqual(state.draft, draft)
            } else {
                XCTAssertEqual(state.draft, before.draft)
            }
        case .onDeviceTranslated(let draft, let turnID):
            if turnID == before.turnID && before.onDeviceTurnID == turnID && before.phase == .translating {
                XCTAssertEqual(state.draft, draft)
            } else {
                XCTAssertEqual(state.draft, before.draft)
            }
        case .finishTimeout(let turnID) where before.phase == .finishingTranscript && turnID == before.turnID:
            XCTAssertNotEqual(state.phase, .finishingTranscript)
        case .recognizerEnded(let turnID)
            where (before.phase == .finishingTranscript || before.phase == .listening) && turnID == before.turnID:
            XCTAssertNotEqual(state.phase, .finishingTranscript)
        default:
            break
        }

        if stale(event, before: before) {
            XCTAssertEqual(state, before)
            XCTAssertTrue(after.effects.isEmpty)
        }
    }

    private func stale(_ event: CrewTalkEvent, before: CrewTalkState) -> Bool {
        switch event {
        case .speechAuthorization(_, let turnID),
             .partialTranscript(_, let turnID),
             .recognizerEnded(let turnID),
             .finishTimeout(let turnID),
             .remoteTranslated(_, let turnID),
             .remoteFailed(_, _, let turnID),
             .onDeviceTranslated(_, let turnID),
             .onDeviceFailed(_, let turnID):
            return turnID != before.turnID
        case .neuralReady(let utteranceID), .neuralFailed(let utteranceID):
            return before.preparingUtteranceID != utteranceID
        case .playbackFinished(let utteranceID):
            return before.playingUtteranceID != utteranceID
        default:
            return false
        }
    }
}

/// Deterministic generator. The reducer itself does not call this.
private struct LCG {
    var state: UInt64

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func int(_ upper: Int) -> Int {
        precondition(upper > 0)
        return Int(next() % UInt64(upper))
    }
}
