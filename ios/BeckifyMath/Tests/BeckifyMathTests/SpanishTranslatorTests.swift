import XCTest
@testable import BeckifyMath

final class SpanishTranslatorTests: XCTestCase {
    func testTranslateURLDefaultsToApiBeckify() {
        let url = SpanishTranslatorAPI.defaultTranslateURL()
        XCTAssertEqual(url?.absoluteString, "https://api.beckify.com/api/translate")
    }

    func testCustomHTTPSEndpointWins() {
        let url = SpanishTranslatorAPI.translateURL(
            customEndpoint: "https://example.com/custom-translate"
        )
        XCTAssertEqual(url?.absoluteString, "https://example.com/custom-translate")
    }

    func testHTTPCustomEndpointFallsBackToDefault() {
        // Same rule as PhotoLookCheck: non-HTTPS custom is ignored; default API wins.
        let url = SpanishTranslatorAPI.translateURL(customEndpoint: "http://insecure.example/translate")
        XCTAssertEqual(url?.absoluteString, "https://api.beckify.com/api/translate")
    }

    func testClampSourceText() {
        let short = SpanishTranslatorAPI.clampSourceText("  hola  ")
        XCTAssertEqual(short, "hola")
        let long = String(repeating: "a", count: SpanishTranslatorAPI.maxSourceCharacters + 50)
        let clamped = SpanishTranslatorAPI.clampSourceText(long)
        XCTAssertEqual(clamped.count, SpanishTranslatorAPI.maxSourceCharacters)
    }

    func testNormalizeDraft() {
        let raw: [String: Any] = [
            "task": "translate",
            "translation": "¿Dónde está el breaker?",
            "dialect": "cuban_florida_latam",
            "sourceText": "Where is the breaker?",
            "provider": "openai",
            "model": "gpt-4o-mini",
        ]
        let draft = SpanishTranslatorAPI.normalizeDraft(raw)
        XCTAssertEqual(draft?.translation, "¿Dónde está el breaker?")
        XCTAssertEqual(draft?.sourceText, "Where is the breaker?")
        XCTAssertEqual(draft?.engine, "beckify")
        XCTAssertTrue(draft?.displayDialect.lowercased().contains("spanish") == true)
        XCTAssertFalse(draft?.displayDialect.lowercased().contains("cuban") == true)
        XCTAssertFalse(draft?.displayDialect.lowercased().contains("florida") == true)
    }

    func testNormalizeDraftRejectsEmptyTranslation() {
        XCTAssertNil(SpanishTranslatorAPI.normalizeDraft(["translation": "  "]))
    }

    func testRequestBodyShape() throws {
        let body = SpanishTranslatorAPI.requestBody(text: "Hello")
        XCTAssertEqual(body["task"] as? String, "translate")
        XCTAssertEqual(body["text"] as? String, "Hello")
        XCTAssertEqual(body["targetLanguage"] as? String, "es")
        let data = try SpanishTranslatorAPI.requestJSON(text: "Hello")
        XCTAssertFalse(data.isEmpty)
    }

    func testSpanishVoiceRankingPrefersUSThenMX() {
        XCTAssertGreaterThan(
            SpanishTranslatorAPI.spanishVoiceScore(language: "es-US"),
            SpanishTranslatorAPI.spanishVoiceScore(language: "es-MX")
        )
        XCTAssertGreaterThan(
            SpanishTranslatorAPI.spanishVoiceScore(language: "es-MX"),
            SpanishTranslatorAPI.spanishVoiceScore(language: "es-ES")
        )
        XCTAssertEqual(SpanishTranslatorAPI.spanishVoiceScore(language: "en-US"), -1)

        let best = SpanishTranslatorAPI.bestSpanishVoiceLanguage(
            from: ["en-US", "es-ES", "es-MX", "es-US", "fr-FR"]
        )
        XCTAssertEqual(best, "es-US")

        let mexicoOnly = SpanishTranslatorAPI.bestSpanishVoiceLanguage(from: ["es-ES", "es-MX"])
        XCTAssertEqual(mexicoOnly, "es-MX")
    }

    func testVoiceFallbackNote() {
        let us = SpanishTranslatorAPI.voiceFallbackNote(
            selectedLanguage: "es-US",
            genderLabel: "male",
            voiceName: "Juan"
        )
        XCTAssertTrue(us.lowercased().contains("es-us") || us.lowercased().contains("juan"))
        XCTAssertTrue(us.lowercased().contains("male"))
        let empty = SpanishTranslatorAPI.voiceFallbackNote(selectedLanguage: nil)
        XCTAssertTrue(empty.lowercased().contains("no spanish"))
        XCTAssertTrue(empty.lowercased().contains("openai") || empty.lowercased().contains("neural"))
    }

    func testJobsiteVoiceScorePrefersMaleUS() {
        let maleUS = SpanishTranslatorAPI.jobsiteVoiceScore(language: "es-US", genderRaw: 1, qualityRaw: 2)
        let femaleUS = SpanishTranslatorAPI.jobsiteVoiceScore(language: "es-US", genderRaw: 2, qualityRaw: 2)
        let maleMX = SpanishTranslatorAPI.jobsiteVoiceScore(language: "es-MX", genderRaw: 1, qualityRaw: 1)
        XCTAssertGreaterThan(maleUS, femaleUS)
        XCTAssertGreaterThan(maleUS, maleMX)
        XCTAssertEqual(SpanishTranslatorAPI.jobsiteSpeechRateFactor, Float(0.84), accuracy: 0.001)
        XCTAssertEqual(SpanishTranslatorAPI.jobsitePitchMultiplier, Float(0.92), accuracy: 0.001)
    }

    func testCatalogPolicyAndHowItWorks() {
        XCTAssertTrue(ToolCalculationPolicy.knownToolIDs.contains("spanishTranslator"))
        XCTAssertEqual(ToolCalculationPolicy.mode(forToolID: "spanishTranslator"), .explicit)
        XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: "spanishTranslator"), .toolkit)
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "spanishTranslator"), .reference)
        let copy = ToolHowItWorksCatalog.copy(forToolID: "spanishTranslator")
        XCTAssertNotNil(copy)
        XCTAssertTrue(copy!.summary.lowercased().contains("spanish"))
        let joined = (copy!.summary + " " + copy!.bullets.joined(separator: " ")).lowercased()
        XCTAssertTrue(joined.contains("clean") && joined.contains("jobsite"))
        XCTAssertFalse(joined.contains("cuban"))
        XCTAssertFalse(joined.contains("florida"))
        XCTAssertFalse(joined.contains("smart-ass"))
        XCTAssertFalse(joined.contains("profane"))
        XCTAssertTrue(joined.contains("on-device") || joined.contains("apple translation"))
        XCTAssertTrue(joined.contains("chip") || joined.contains("quick") || joined.contains("test"))
        XCTAssertTrue(joined.contains("/api/speak") || joined.contains("neural") || joined.contains("openai"))
    }

    func testQuickTranslatePhrasesAndRandom() {
        let phrases = SpanishTranslatorAPI.quickTranslatePhrases
        XCTAssertGreaterThanOrEqual(phrases.count, 8)
        XCTAssertLessThanOrEqual(phrases.count, 12)
        XCTAssertEqual(Set(phrases).count, phrases.count, "quick phrases must be unique")
        for phrase in phrases {
            XCTAssertFalse(phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertLessThanOrEqual(phrase.count, 80)
        }
        XCTAssertTrue(phrases.contains(where: { $0.lowercased().contains("breaker") }))
        XCTAssertTrue(phrases.contains(where: { $0.lowercased().contains("power") }))
        let a = SpanishTranslatorAPI.nextRandomTestPhrase(excluding: nil)
        XCTAssertTrue(phrases.contains(a))
        let b = SpanishTranslatorAPI.nextRandomTestPhrase(excluding: a)
        XCTAssertTrue(phrases.contains(b))
        if phrases.count > 1 {
            // Best-effort: avoid immediate repeat when pool allows.
            XCTAssertNotEqual(a, b)
        }
    }

    func testVoiceModeLabelsAndRequestBodies() throws {
        XCTAssertEqual(SpanishVoiceMode.jobsite.uiLabel, "Jobsite")
        XCTAssertEqual(SpanishVoiceMode.clean.uiLabel, "Clean")
        XCTAssertEqual(SpanishVoiceMode.jobsite.defaultSpeakVoice, "onyx")
        XCTAssertEqual(SpanishVoiceMode.clean.defaultSpeakVoice, "nova")
        XCTAssertFalse(SpanishVoiceMode.jobsite.uiLabel.lowercased().contains("cuban"))
        XCTAssertFalse(SpanishVoiceMode.clean.uiLabel.lowercased().contains("princess"))
        let jobsite = SpanishTranslatorAPI.requestBody(text: "Hello", voiceMode: .jobsite)
        XCTAssertEqual(jobsite["voiceMode"] as? String, "jobsite")
        let clean = try SpanishTranslatorAPI.speakRequestJSON(text: "Hola", voiceMode: .clean)
        XCTAssertFalse(clean.isEmpty)
        let note = SpanishTranslatorAPI.neuralVoiceNote(voiceMode: .clean)
        XCTAssertTrue(note.lowercased().contains("clean"))
        XCTAssertFalse(note.lowercased().contains("cuban"))
        XCTAssertFalse(note.lowercased().contains("florida"))
        let draft = SpanishTranslationDraft(translation: "Hola", dialect: "cuban_florida_jobsite")
        XCTAssertEqual(draft.displayDialect, "Spanish · Jobsite")
        let cleanDraft = SpanishTranslationDraft(translation: "Hola", dialect: "cuban_florida_clean")
        XCTAssertEqual(cleanDraft.displayDialect, "Spanish · Clean")
    }

    func testStatusLabelsAndAppleDraft() {
        XCTAssertEqual(SpanishTranslatorAPI.statusViaBeckifyAI, "Translated via Beckify AI")
        XCTAssertEqual(SpanishTranslatorAPI.statusOnDevice, "Translated on device")
        let draft = SpanishTranslatorAPI.appleOnDeviceDraft(
            translation: "  Hola  ",
            sourceText: "Hello",
            targetLanguageID: "es-MX"
        )
        XCTAssertEqual(draft.translation, "Hola")
        XCTAssertEqual(draft.engine, "apple")
        XCTAssertEqual(draft.provider, "apple")
        XCTAssertEqual(draft.targetLanguage, "es-MX")
        XCTAssertTrue(draft.displayDialect.lowercased().contains("on-device")
            || draft.displayDialect.lowercased().contains("apple"))
    }

    func testShouldAttemptOnDeviceFallback() {
        XCTAssertTrue(SpanishTranslatorAPI.shouldAttemptOnDeviceFallback(httpStatus: 0))
        XCTAssertTrue(SpanishTranslatorAPI.shouldAttemptOnDeviceFallback(httpStatus: 404))
        XCTAssertTrue(SpanishTranslatorAPI.shouldAttemptOnDeviceFallback(httpStatus: 405))
        XCTAssertTrue(SpanishTranslatorAPI.shouldAttemptOnDeviceFallback(httpStatus: 503))
        XCTAssertTrue(SpanishTranslatorAPI.shouldAttemptOnDeviceFallback(httpStatus: 500))
        XCTAssertTrue(SpanishTranslatorAPI.shouldAttemptOnDeviceFallback(httpStatus: 429))
        // Successful 2xx should not request fallback from this helper.
        XCTAssertFalse(SpanishTranslatorAPI.shouldAttemptOnDeviceFallback(httpStatus: 200))
    }

    func testBothPathsFailedMessage() {
        let both = SpanishTranslatorAPI.bothPathsFailedMessage(
            apiError: "Cannot POST",
            onDeviceError: "languages missing"
        )
        XCTAssertTrue(both.contains("Cannot POST"))
        XCTAssertTrue(both.lowercased().contains("on-device") || both.contains("languages"))
        let need = SpanishTranslatorAPI.onDeviceUnavailableMessage(apiError: "HTTP 404")
        XCTAssertTrue(need.contains("HTTP 404"))
        XCTAssertTrue(need.contains("iOS 18"))
    }


    func testSpeakURLDefaultsToApiBeckify() {
        let url = SpanishTranslatorAPI.defaultSpeakURL()
        XCTAssertEqual(url?.absoluteString, "https://api.beckify.com/api/speak")
    }

    func testSpeakURLMapsTranslateCustomEndpoint() {
        let url = SpanishTranslatorAPI.speakURL(
            customEndpoint: "https://example.com/api/translate"
        )
        XCTAssertEqual(url?.absoluteString, "https://example.com/api/speak")
    }

    func testSpeakURLFallsBackWhenCustomIsNotTranslate() {
        let url = SpanishTranslatorAPI.speakURL(
            customEndpoint: "https://example.com/custom-translate"
        )
        XCTAssertEqual(url?.absoluteString, "https://api.beckify.com/api/speak")
    }

    func testClampSpeakTextAndRequestBody() throws {
        let short = SpanishTranslatorAPI.clampSpeakText("  ¡Oye!  ")
        XCTAssertEqual(short, "¡Oye!")
        let long = String(repeating: "a", count: SpanishTranslatorAPI.maxSpeakCharacters + 40)
        XCTAssertEqual(SpanishTranslatorAPI.clampSpeakText(long).count, SpanishTranslatorAPI.maxSpeakCharacters)
        let body = SpanishTranslatorAPI.speakRequestBody(text: "Hola")
        XCTAssertEqual(body["task"] as? String, "speak")
        XCTAssertEqual(body["voice"] as? String, "onyx")
        XCTAssertEqual(body["format"] as? String, "mp3")
        let data = try SpanishTranslatorAPI.speakRequestJSON(text: "Hola")
        XCTAssertFalse(data.isEmpty)
        let note = SpanishTranslatorAPI.neuralVoiceNote(model: "gpt-4o-mini-tts", voice: "onyx")
        XCTAssertTrue(note.lowercased().contains("onyx"))
        XCTAssertTrue(note.lowercased().contains("neural"))
    }

    func testDisclaimerMentionsSpeakAPI() {
        let d = SpanishTranslatorAPI.disclaimer.lowercased()
        XCTAssertTrue(d.contains("/api/speak") || d.contains("neural"))
        XCTAssertTrue(d.contains("fallback") || d.contains("avspeech") || d.contains("apple"))
        XCTAssertTrue(d.contains("clean") && d.contains("jobsite"))
        XCTAssertFalse(d.contains("cuban"))
        XCTAssertFalse(d.contains("florida"))
        XCTAssertFalse(d.contains("profane"))
        XCTAssertFalse(d.contains("smart-ass"))
    }

}
