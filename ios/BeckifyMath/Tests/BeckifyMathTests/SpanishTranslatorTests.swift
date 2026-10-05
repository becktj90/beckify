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
        XCTAssertEqual(SpanishTranslatorAPI.jobsitePitchMultiplier, Float(0.86), accuracy: 0.001)
    }

    func testCatalogPolicyAndHowItWorks() {
        XCTAssertTrue(ToolCalculationPolicy.knownToolIDs.contains("spanishTranslator"))
        XCTAssertEqual(ToolCalculationPolicy.mode(forToolID: "spanishTranslator"), .explicit)
        XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: "spanishTranslator"), .field)
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "spanishTranslator"), .crew)
        let copy = ToolHowItWorksCatalog.copy(forToolID: "spanishTranslator")
        XCTAssertNotNil(copy)
        let joined = (copy!.summary + " " + copy!.bullets.joined(separator: " ")).lowercased()
        XCTAssertTrue(joined.contains("spanish"))
        // Clean/Jobsite chrome is off the Crew Talk screen; HowItWorks covers dock + Speak instead.
        XCTAssertFalse(joined.contains("clean") || joined.contains("jobsite"))
        XCTAssertTrue(joined.contains("dock") && joined.contains("speak"))
        XCTAssertTrue(joined.contains("bodie") && joined.contains("tito") && joined.contains("junie") && joined.contains("pearl") && joined.contains("sloane"))
        XCTAssertTrue(joined.contains("cuban"))
        XCTAssertFalse(joined.contains("florida"))
        XCTAssertFalse(joined.contains("smart-ass"))
        XCTAssertFalse(joined.contains("profane"))
        XCTAssertFalse(joined.contains("comedy"))
        XCTAssertTrue(joined.contains("on-device") || joined.contains("apple translation") || joined.contains("apple voice"))
        XCTAssertTrue(joined.contains("chip") || joined.contains("quick") || joined.contains("test"))
        XCTAssertTrue(joined.contains("hey") || joined.contains("attention"))
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

    func testAttentionCallPhrasesAndLabels() {
        let phrases = SpanishTranslatorAPI.attentionCallPhrases
        XCTAssertGreaterThanOrEqual(phrases.count, 4)
        XCTAssertLessThanOrEqual(phrases.count, 8)
        XCTAssertEqual(Set(phrases).count, phrases.count, "attention phrases must be unique")
        for phrase in phrases {
            XCTAssertFalse(phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertLessThanOrEqual(phrase.count, 40)
        }
        XCTAssertTrue(phrases.contains(where: { $0.lowercased().contains("hey") }))
        XCTAssertTrue(phrases.contains(where: { $0.lowercased().contains("look") || $0.lowercased().contains("hold") || $0.lowercased().contains("wait") }))
        let a = SpanishTranslatorAPI.nextAttentionCallPhrase(excluding: nil)
        XCTAssertTrue(phrases.contains(a))
        let b = SpanishTranslatorAPI.nextAttentionCallPhrase(excluding: a)
        XCTAssertTrue(phrases.contains(b))
        if phrases.count > 1 {
            XCTAssertNotEqual(a, b)
        }
        XCTAssertEqual(SpanishTranslatorAPI.attentionButtonTitle, "Hey!")
        XCTAssertEqual(SpanishTranslatorAPI.attentionButtonAccessibilityLabel, "Get attention")
        let help = SpanishTranslatorAPI.attentionButtonHelp.lowercased()
        XCTAssertTrue(help.contains("attention") || help.contains("translate"))
        XCTAssertFalse(help.contains("cuban"))
        XCTAssertFalse(help.contains("florida"))
        XCTAssertFalse(SpanishTranslatorAPI.attentionButtonTitle.lowercased().contains("cuban"))
        XCTAssertFalse(SpanishTranslatorAPI.attentionButtonAccessibilityLabel.lowercased().contains("oy"))
    }

    func testVoiceModeLabelsAndRequestBodies() throws {
        XCTAssertEqual(SpanishVoiceMode.jobsite.uiLabel, "Jobsite")
        XCTAssertEqual(SpanishVoiceMode.clean.uiLabel, "Clean")
        XCTAssertEqual(SpanishVoiceMode.jobsite.defaultSpeakVoice, "onyx")
        XCTAssertEqual(SpanishVoiceMode.clean.defaultSpeakVoice, "nova")
        XCTAssertEqual(SpanishVoiceMode.clean.defaultSpeakVoice(language: "en"), "echo")
        XCTAssertEqual(SpanishVoiceMode.jobsite.defaultSpeakVoice(language: "en"), "echo")
        XCTAssertEqual(SpanishVoiceMode.clean.defaultSpeakVoice(language: "es"), "nova")
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

    func testReverseDirectionRequestAndSpeakBodies() throws {
        XCTAssertEqual(SpanishTranslateDirection.parse(nil), .englishToSpanish)
        XCTAssertEqual(SpanishTranslateDirection.parse("spanishToEnglish"), .spanishToEnglish)
        XCTAssertEqual(SpanishTranslateDirection.parse("es-en"), .spanishToEnglish)
        XCTAssertEqual(SpanishTranslateDirection.englishToSpanish.sourceLanguage, "en")
        XCTAssertEqual(SpanishTranslateDirection.englishToSpanish.targetLanguage, "es")
        XCTAssertEqual(SpanishTranslateDirection.spanishToEnglish.sourceLanguage, "es")
        XCTAssertEqual(SpanishTranslateDirection.spanishToEnglish.targetLanguage, "en")
        XCTAssertEqual(SpanishTranslateDirection.spanishToEnglish.speakLanguage, "en")
        XCTAssertEqual(SpanishTranslateDirection.storageKey, "spanishTranslator.direction")

        let body = SpanishTranslatorAPI.requestBody(
            text: "¿Dónde está el breaker?",
            sourceLanguage: SpanishTranslateDirection.spanishToEnglish.sourceLanguage,
            targetLanguage: SpanishTranslateDirection.spanishToEnglish.targetLanguage,
            voiceMode: .jobsite
        )
        XCTAssertEqual(body["sourceLanguage"] as? String, "es")
        XCTAssertEqual(body["targetLanguage"] as? String, "en")
        XCTAssertEqual(body["voiceMode"] as? String, "jobsite")
        XCTAssertEqual(body["mode"] as? String, "jobsite")
        let data = try SpanishTranslatorAPI.requestJSON(
            text: "Corta la corriente.",
            sourceLanguage: "es",
            targetLanguage: "en",
            voiceMode: .clean
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["targetLanguage"] as? String, "en")
        XCTAssertEqual(object["voiceMode"] as? String, "clean")

        let speak = SpanishTranslatorAPI.speakRequestBody(
            text: "Kill the power.",
            voiceMode: .jobsite,
            language: SpanishTranslateDirection.spanishToEnglish.speakLanguage
        )
        XCTAssertEqual(speak["language"] as? String, "en")
        XCTAssertEqual(speak["task"] as? String, "speak")
        XCTAssertEqual(speak["voice"] as? String, "echo")
        let speakCleanEN = SpanishTranslatorAPI.speakRequestBody(
            text: "Kill the power.",
            voiceMode: .clean,
            language: "en"
        )
        XCTAssertEqual(speakCleanEN["voice"] as? String, "echo", "ES→EN stays the California voice even in Clean")
        let defaultSpeak = SpanishTranslatorAPI.speakRequestBody(text: "Hola")
        XCTAssertEqual(defaultSpeak["language"] as? String, "es")
        XCTAssertEqual(defaultSpeak["voice"] as? String, "onyx")
        let cleanES = SpanishTranslatorAPI.speakRequestBody(text: "Hola", voiceMode: .clean, language: "es")
        XCTAssertEqual(cleanES["voice"] as? String, "nova")
        let deepSouth = SpanishTranslatorAPI.speakRequestBody(
            text: "Hand me that conduit.",
            voiceMode: .jobsite,
            language: "es",
            delivery: SpanishTranslatorAPI.deepSouthDelivery
        )
        XCTAssertEqual(deepSouth["voice"] as? String, "ballad")
        XCTAssertEqual(deepSouth["language"] as? String, "en")
        XCTAssertEqual(deepSouth["voiceMode"] as? String, "deepSouth")
        XCTAssertEqual(deepSouth["text"] as? String, "Hand me that conduit.")
        XCTAssertFalse((deepSouth["text"] as? String ?? "").lowercased().contains("y'all"))
    }

    func testSpanishQuickPhrasesAndSpeechLocales() {
        let phrases = SpanishTranslatorAPI.quickSpanishTranslatePhrases
        XCTAssertEqual(phrases.count, SpanishTranslatorAPI.quickTranslatePhrases.count)
        XCTAssertGreaterThanOrEqual(phrases.count, 8)
        XCTAssertLessThanOrEqual(phrases.count, 12)
        XCTAssertEqual(Set(phrases).count, phrases.count)
        let joined = phrases.joined(separator: " ").lowercased()
        XCTAssertTrue(joined.contains("breaker"))
        XCTAssertTrue(joined.contains("corriente") || joined.contains("vivo"))
        XCTAssertTrue(joined.contains("conduit"))
        XCTAssertTrue(joined.contains("alambre") || joined.contains("wire"))
        XCTAssertTrue(joined.contains("escalera"))
        XCTAssertTrue(joined.contains("cabeza"))
        XCTAssertFalse(joined.contains("vosotros"))
        XCTAssertEqual(
            SpanishTranslatorAPI.quickPhrases(direction: .englishToSpanish),
            SpanishTranslatorAPI.quickTranslatePhrases
        )
        let pick = SpanishTranslatorAPI.nextRandomTestPhrase(direction: .spanishToEnglish, excluding: nil)
        XCTAssertTrue(phrases.contains(pick))

        XCTAssertEqual(
            SpanishTranslatorAPI.bestSpeechLocale(
                direction: .spanishToEnglish,
                available: ["en-US", "es-ES", "es-MX", "es_US"]
            ),
            "es_US"
        )
        XCTAssertEqual(
            SpanishTranslatorAPI.bestSpeechLocale(
                direction: .spanishToEnglish,
                available: ["en-US", "es-ES", "es-MX"]
            ),
            "es-MX"
        )
        XCTAssertEqual(
            SpanishTranslatorAPI.bestSpeechLocale(
                direction: .spanishToEnglish,
                available: ["en-US", "fr-FR"]
            ),
            nil
        )
        XCTAssertEqual(
            SpanishTranslatorAPI.bestSpeechLocale(
                direction: .englishToSpanish,
                available: ["es-US", "en-GB", "en-US"]
            ),
            "en-US"
        )
        let unavailable = SpanishTranslatorAPI.speechUnavailableMessage(direction: .spanishToEnglish).lowercased()
        XCTAssertTrue(unavailable.contains("spanish"))
        XCTAssertTrue(unavailable.contains("type"))
        XCTAssertEqual(
            SpanishTranslatorAPI.emptySourceMessage(direction: .englishToSpanish),
            "Say or type something in English first."
        )
    }

    func testAppleDraftReverseDirection() {
        let draft = SpanishTranslatorAPI.appleOnDeviceDraft(
            translation: "  Kill the power.  ",
            sourceText: "Corta la corriente.",
            targetLanguageID: "en-US",
            sourceLanguageID: "es-US"
        )
        XCTAssertEqual(draft.translation, "Kill the power.")
        XCTAssertEqual(draft.engine, "apple")
        XCTAssertEqual(draft.sourceLanguage, "es-US")
        XCTAssertEqual(draft.targetLanguage, "en-US")
        XCTAssertEqual(draft.resultLanguageLabel, "English")
        XCTAssertTrue(draft.displayDialect.lowercased().contains("english"))
        XCTAssertTrue(draft.displayDialect.lowercased().contains("on-device")
            || draft.displayDialect.lowercased().contains("apple"))
        XCTAssertFalse(draft.displayDialect.lowercased().contains("cuban"))
        XCTAssertFalse(draft.displayDialect.lowercased().contains("florida"))

        let cloud = SpanishTranslationDraft(
            translation: "Where's the breaker?",
            dialect: "english_jobsite",
            sourceText: "¿Dónde está el breaker?",
            sourceLanguage: "es",
            targetLanguage: "en",
            engine: "beckify"
        )
        XCTAssertEqual(cloud.displayDialect, "English · Jobsite")
        let clean = SpanishTranslationDraft(
            translation: "Where is the breaker?",
            dialect: "english_clean",
            sourceLanguage: "es",
            targetLanguage: "en"
        )
        XCTAssertEqual(clean.displayDialect, "English · Clean")
        let pair = SpanishTranslatorAPI.appleTranslationCandidates(direction: .spanishToEnglish)
        XCTAssertEqual(pair.targets.first, "en-US")
        XCTAssertTrue(pair.sources.first?.hasPrefix("es") == true)
        let forward = SpanishTranslatorAPI.appleTranslationCandidates(direction: .englishToSpanish)
        XCTAssertEqual(forward.sources, ["en"])
        XCTAssertEqual(forward.targets.first, "es-MX")
    }

    func testReverseHelpCopyHasNoDialectBranding() {
        let help = (
            SpanishTranslatorAPI.reverseAttentionHelp + " "
            + SpanishTranslatorAPI.modeHelp(direction: .spanishToEnglish, voiceMode: .jobsite) + " "
            + SpanishTranslatorAPI.statusHelp(direction: .spanishToEnglish) + " "
            + SpanishTranslatorAPI.playbackHelp(direction: .spanishToEnglish)
        ).lowercased()
        XCTAssertTrue(help.contains("english"))
        XCTAssertTrue(help.contains("spanish"))
        XCTAssertFalse(help.contains("cuban"))
        XCTAssertFalse(help.contains("florida"))
        XCTAssertTrue(SpanishTranslatorAPI.reverseAttentionHelp.lowercased().contains("hey"))
        let forward = SpanishTranslatorAPI.statusHelp(direction: .englishToSpanish).lowercased()
        XCTAssertTrue(forward.contains("hey"))
        XCTAssertTrue(forward.contains("apple"))
        let how = ToolHowItWorksCatalog.copy(forToolID: "spanishTranslator")
        let joined = ((how?.summary ?? "") + " " + (how?.bullets.joined(separator: " ") ?? "")).lowercased()
        XCTAssertTrue(joined.contains("spanish → english") || joined.contains("spanish speech"))
        XCTAssertTrue(joined.contains("english → spanish") || joined.contains("english speech"))
        XCTAssertTrue(joined.contains("bodie") && joined.contains("tito") && joined.contains("junie"))
        XCTAssertTrue(joined.contains("eleven_v3") || joined.contains("/api/speak"))
        XCTAssertFalse(joined.contains("comedy"))
        XCTAssertFalse(joined.contains("stoner"))
    }

    func testEnglishVoiceRankingPrefersUS() {
        XCTAssertGreaterThan(
            SpanishTranslatorAPI.englishVoiceScore(language: "en-US"),
            SpanishTranslatorAPI.englishVoiceScore(language: "en-GB")
        )
        XCTAssertEqual(SpanishTranslatorAPI.englishVoiceScore(language: "es-US"), -1)
        XCTAssertEqual(
            SpanishTranslatorAPI.bestEnglishVoiceLanguage(from: ["es-MX", "en-GB", "en-US"]),
            "en-US"
        )
        let maleUS = SpanishTranslatorAPI.englishPlaybackVoiceScore(language: "en-US", genderRaw: 1, qualityRaw: 1)
        let femaleUS = SpanishTranslatorAPI.englishPlaybackVoiceScore(language: "en-US", genderRaw: 2, qualityRaw: 2)
        XCTAssertGreaterThan(maleUS, femaleUS)
        let note = SpanishTranslatorAPI.englishVoiceFallbackNote(selectedLanguage: "en-US", genderLabel: "male", voiceName: "Aaron")
        XCTAssertTrue(note.lowercased().contains("en-us") || note.lowercased().contains("aaron"))
        XCTAssertTrue(note.lowercased().contains("device voices"))
        XCTAssertTrue(note.lowercased().contains("crew"))
        XCTAssertFalse(note.lowercased().contains("cuban"))
        XCTAssertFalse(note.lowercased().contains("comedy"))
        let neuralEN = SpanishTranslatorAPI.neuralVoiceNote(voiceMode: .clean, language: "en")
        XCTAssertTrue(neuralEN.lowercased().contains("california"))
        XCTAssertTrue(neuralEN.lowercased().contains("echo"))
        XCTAssertFalse(neuralEN.lowercased().contains("stoner"))
        let neuralES = SpanishTranslatorAPI.neuralVoiceNote(voiceMode: .jobsite, language: "es")
        XCTAssertFalse(neuralES.lowercased().contains("california"))
        XCTAssertTrue(neuralES.lowercased().contains("gravelly"))
        XCTAssertTrue(SpanishTranslatorAPI.neuralVoiceNote(voiceMode: .jobsite, language: "en").contains("California"))
        let deepNote = SpanishTranslatorAPI.neuralVoiceNote(voice: "", language: "en", delivery: "deepSouth")
        XCTAssertTrue(deepNote.contains("Deep South"))
        XCTAssertTrue(deepNote.contains("ballad"))
        XCTAssertFalse(deepNote.lowercased().contains("comedy"))
        XCTAssertLessThan(SpanishTranslatorAPI.speechPitchMultiplier(voiceMode: .jobsite), SpanishTranslatorAPI.speechPitchMultiplier(voiceMode: .clean))
        XCTAssertLessThan(SpanishTranslatorAPI.speechRateFactor(voiceMode: .jobsite), SpanishTranslatorAPI.speechRateFactor(voiceMode: .clean))
        XCTAssertEqual(SpanishTranslatorAPI.preparingAudioStatus, "Preparing voice…")
        XCTAssertEqual(SpanishTranslatorAPI.statusPreparingVoice, "Preparing voice…")
        XCTAssertEqual(SpanishTranslatorAPI.statusFinishingTranscript, "Finishing transcript")
        XCTAssertEqual(SpanishTranslatorAPI.statusPlaying, "Playing")
        XCTAssertEqual(SpanishTranslatorAPI.statusCancelled, "Cancelled")
        XCTAssertEqual(SpanishTranslatorAPI.preparingVoiceStatus(elapsedSeconds: 2), "Preparing voice…")
        XCTAssertEqual(SpanishTranslatorAPI.preparingVoiceStatus(elapsedSeconds: 3), "Still preparing your voice… 3s")
        XCTAssertEqual(SpanishTranslatorAPI.preparingVoiceStatus(elapsedSeconds: 12), "Still preparing your voice… 12s")
        XCTAssertEqual(SpanishTranslatorAPI.speakNowDeviceVoiceTitle, "Speak now with device voice")
        XCTAssertEqual(SpanishTranslatorAPI.cancelActionTitle, "Cancel")
    }

    func testDisclaimerMentionsSpeakAPI() {
        let d = SpanishTranslatorAPI.disclaimer.lowercased()
        XCTAssertTrue(d.contains("/api/speak") || d.contains("neural"))
        XCTAssertTrue(d.contains("fallback") || d.contains("avspeech") || d.contains("apple"))
        XCTAssertTrue(d.contains("clean") && d.contains("jobsite"))
        XCTAssertTrue(d.contains("hey") || d.contains("attention"))
        XCTAssertFalse(d.contains("cuban"))
        XCTAssertFalse(d.contains("florida"))
        XCTAssertFalse(d.contains("profane"))
        XCTAssertFalse(d.contains("smart-ass"))
        XCTAssertFalse(d.contains("comedy"))
        XCTAssertFalse(d.contains("stoner"))
        XCTAssertTrue(d.contains("bodie hale"))
        XCTAssertTrue(d.contains("tito solano"))
        XCTAssertTrue(d.contains("junie pell"))
        XCTAssertTrue(d.contains("pearl"))
        XCTAssertTrue(d.contains("sloane merritt"))
        XCTAssertTrue(d.contains("eleven_v3"))
    }


    func testCrewTalkMembersAndSpeakBody() throws {
        XCTAssertEqual(CrewTalkMember.allCases.count, 6)
        XCTAssertEqual(CrewTalkMember.parse(nil), .titoSolano)
        XCTAssertEqual(CrewTalkMember.parse("bodie"), .bodieHale)
        XCTAssertEqual(CrewTalkMember.parse("Junie Pell"), .juniePell)
        XCTAssertEqual(CrewTalkMember.bodieHale.voiceID, "XVO6RhOYU9ZEKHFXrx6b")
        XCTAssertEqual(CrewTalkMember.titoSolano.voiceID, "goyf4sY4AqSvMIeO1hb5")
        XCTAssertEqual(CrewTalkMember.lupitaReyes.voiceID, "iGXRQ0smdhSFlb6iV1Pr")
        XCTAssertTrue(CrewTalkMember.lupitaReyes.isReleased)
        XCTAssertEqual(CrewTalkMember.lupitaReyes.speakLanguage, "es")
        XCTAssertEqual(CrewTalkMember.lupitaReyes.portraitAssetName, "crewLupitaReyes")
        XCTAssertEqual(CrewTalkMember.lupitaReyes.talkAssetName, "crewLupitaReyesTalk")
        XCTAssertTrue(CrewTalkMember.lupitaReyes.prefersFemaleDeviceVoice)
        XCTAssertEqual(CrewTalkMember.parse("lupita"), .lupitaReyes)

        XCTAssertEqual(CrewTalkMember.juniePell.voiceID, "tdK8noxHGTBqk6F18tbZ")
        XCTAssertEqual(CrewTalkMember.speakModel, "eleven_v3")
        XCTAssertEqual(CrewTalkMember.bodieHale.speakLanguage, "en")
        XCTAssertEqual(CrewTalkMember.titoSolano.speakLanguage, "es")
        XCTAssertEqual(CrewTalkMember.juniePell.speakLanguage, "en")
        XCTAssertEqual(CrewTalkMember.bodieHale.portraitAssetName, "crewBodieHale")
        XCTAssertEqual(CrewTalkMember.titoSolano.portraitAssetName, "crewTitoSolano")
        XCTAssertEqual(CrewTalkMember.juniePell.portraitAssetName, "crewJuniePell")
        XCTAssertEqual(CrewTalkMember.bodieHale.talkAssetName, "crewBodieHaleTalk")
        XCTAssertEqual(CrewTalkMember.titoSolano.talkAssetName, "crewTitoSolanoTalk")
        XCTAssertEqual(CrewTalkMember.juniePell.talkAssetName, "crewJuniePellTalk")
        XCTAssertEqual(CrewTalkMember.parse("Pearl"), .pearl)
        XCTAssertEqual(CrewTalkMember.parse("pearl"), .pearl)
        XCTAssertEqual(CrewTalkMember.pearl.displayName, "Pearl")
        XCTAssertEqual(CrewTalkMember.pearl.voiceID, "xDnrPZyqSbomyfOcnNpu")
        XCTAssertEqual(CrewTalkMember.pearl.speakLanguage, "en")
        XCTAssertEqual(CrewTalkMember.pearl.portraitAssetName, "crewPearl")
        XCTAssertEqual(CrewTalkMember.pearl.talkAssetName, "crewPearlTalk")
        XCTAssertTrue(CrewTalkMember.pearl.prefersFemaleDeviceVoice)
        XCTAssertTrue(CrewTalkMember.juniePell.prefersFemaleDeviceVoice)
        XCTAssertFalse(CrewTalkMember.bodieHale.prefersFemaleDeviceVoice)
        let names = CrewTalkMember.allCases.map(\.displayName).joined(separator: " ").lowercased()
        XCTAssertFalse(names.contains("comedy"))
        XCTAssertFalse(names.contains("stoner"))

        let tito = SpanishTranslatorAPI.speakRequestBody(text: "Pásame el conduit.", voiceMode: .jobsite, crew: .titoSolano)
        XCTAssertEqual(tito["voice"] as? String, CrewTalkMember.titoSolano.voiceID)
        XCTAssertEqual(tito["model"] as? String, "eleven_v3")
        XCTAssertEqual(tito["language"] as? String, "es")
        XCTAssertEqual(tito["voiceMode"] as? String, "jobsite")
        let bodie = SpanishTranslatorAPI.speakRequestBody(text: "Kill the power.", voiceMode: .clean, language: "es", crew: .bodieHale)
        XCTAssertEqual(bodie["voice"] as? String, "XVO6RhOYU9ZEKHFXrx6b")
        // Speak language follows the direction override (es), not Bodie's default en.
        XCTAssertEqual(bodie["language"] as? String, "es")
        XCTAssertEqual(bodie["model"] as? String, "eleven_v3")
        let junie = try SpanishTranslatorAPI.speakRequestJSON(text: "Leave that breaker be.", crew: .juniePell)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: junie) as? [String: Any])
        XCTAssertEqual(object["voice"] as? String, "tdK8noxHGTBqk6F18tbZ")
        XCTAssertEqual(object["model"] as? String, "eleven_v3")
        XCTAssertEqual(object["stability"] as? Double ?? -1, CrewTalkMember.junieSpeakStability, accuracy: 0.001)
        XCTAssertEqual(object["similarity_boost"] as? Double ?? -1, CrewTalkMember.junieSpeakSimilarity, accuracy: 0.001)
        XCTAssertEqual(object["style"] as? Double ?? -1, CrewTalkMember.junieSpeakStyle, accuracy: 0.001)
        XCTAssertEqual(object["speed"] as? Double ?? -1, CrewTalkMember.junieSpeakSpeed, accuracy: 0.001)
        XCTAssertNil(bodie["stability"])
        let note = SpanishTranslatorAPI.neuralVoiceNote(model: "", crew: .bodieHale)
        XCTAssertTrue(note.contains("Bodie Hale"))
        XCTAssertTrue(note.contains("eleven_v3"))
        XCTAssertFalse(note.lowercased().contains("comedy"))
        let titoLine = SpanishTranslatorAPI.lineForCrew(crew: .titoSolano, english: "Kill the power.", spanish: "Corta la corriente.", fallback: "nope")
        XCTAssertNotEqual(titoLine, "Kill the power.")
        XCTAssertNotEqual(titoLine, "Corta la corriente.")
        XCTAssertTrue(titoLine.lowercased().contains("corriente"))
        assertTitoHitsProfanityCeiling(titoLine)
        let titoSamples = [
            "Hand me that conduit.",
            "Move the ladder.",
            "Watch your head.",
            "We need more wire.",
            "Who left this mess?",
            "Hola",
            "Stop talking and get that feeder in before lunch.",
            "Corta la corriente ahora.",
        ]
        for sample in titoSamples {
            let line = SpanishTranslatorAPI.titoDialectRewrite(sample)
            assertTitoHitsProfanityCeiling(line)
            XCTAssertFalse(line.lowercased().contains(sample.lowercased()), sample)
        }
        // A2: Tito has no .free template. Unmatched text is empty so callers use the translation.
        XCTAssertEqual(
            SpanishTranslatorAPI.titoDialectRewrite("Bring the torque wrench over here."),
            ""
        )
        // hold + breaker is two intents, so the guard refuses a template (A2 empty, not a free line).
        XCTAssertEqual(
            SpanishTranslatorAPI.titoDialectRewrite("Hold this breaker."),
            ""
        )
        XCTAssertTrue(SpanishTranslatorAPI.titoDialectRewrite("Hand me that conduit.").lowercased().contains("conduit"))
        XCTAssertTrue(SpanishTranslatorAPI.titoDialectRewrite("Move the ladder.").lowercased().contains("escalera"))
        XCTAssertTrue(SpanishTranslatorAPI.titoDialectRewrite("We need more wire.").lowercased().contains("cable")
            || SpanishTranslatorAPI.titoDialectRewrite("We need more wire.").lowercased().contains("alambre"))
        let hostile = SpanishTranslatorAPI.titoDialectRewrite("Shut up you idiot and kill the damn power.")
        assertTitoHitsProfanityCeiling(hostile)
        XCTAssertTrue(hostile.lowercased().contains("corriente"))
        XCTAssertFalse(hostile.lowercased().contains("idiot"))
        XCTAssertFalse(hostile.lowercased().contains("damn"))
        XCTAssertFalse(hostile.lowercased().contains("shut"))
        let slur = SpanishTranslatorAPI.titoDialectRewrite("you spic kill the power")
        assertTitoHitsProfanityCeiling(slur)
        XCTAssertFalse(slur.lowercased().contains("spic"))
        XCTAssertTrue(slur.lowercased().contains("corriente"))
        let onlyInsult = SpanishTranslatorAPI.titoDialectRewrite("fuck you")
        assertTitoHitsProfanityCeiling(onlyInsult)
        XCTAssertFalse(onlyInsult.lowercased().contains("fuck"))
        let others = [
            SpanishTranslatorAPI.bodieDialectRewrite("Kill the power."),
            SpanishTranslatorAPI.junieDialectRewrite("Kill the power."),
            SpanishTranslatorAPI.pearlWarmRewrite("Kill the power."),
            SpanishTranslatorAPI.sloaneCorporateRewrite("Kill the power."),
        ].joined(separator: " ").lowercased()
        for word in ["coño", "carajo", "mierda", "pinga", "joder", "cabrón", "puta"] {
            XCTAssertFalse(others.contains(word), word)
        }
        let chrome = (
            CrewTalkMember.titoSolano.displayName + " "
            + CrewTalkMember.titoSolano.blurb + " "
            + (ToolHowItWorksCatalog.copy(forToolID: "spanishTranslator")?.summary ?? "") + " "
            + SpanishTranslatorAPI.disclaimer
        ).lowercased()
        for word in ["coño", "carajo", "mierda", "pinga", "joder", "cabrón", "puta", "profanity", "smart-ass", "comedy", "stoner"] {
            XCTAssertFalse(chrome.contains(word), word)
        }
        let junieLine = SpanishTranslatorAPI.lineForCrew(crew: .juniePell, english: "Kill the power.", spanish: "Corta la corriente.", fallback: "nope")
        XCTAssertNotEqual(junieLine.lowercased(), "kill the power.")
        XCTAssertTrue(junieLine.lowercased().contains("power"))
        XCTAssertFalse(junieLine.lowercased().contains("kill"))
        let bodieHello = SpanishTranslatorAPI.lineForCrew(crew: .bodieHale, english: "  ", spanish: "Hola", fallback: "Hola")
        XCTAssertNotEqual(bodieHello, "Hola")
        XCTAssertTrue(bodieHello.lowercased().contains("hey") || bodieHello.lowercased().contains("good"))
        let pearlBody = SpanishTranslatorAPI.speakRequestBody(text: "Kill the power.", voiceMode: .clean, crew: .pearl)
        XCTAssertEqual(pearlBody["voice"] as? String, "xDnrPZyqSbomyfOcnNpu")
        XCTAssertEqual(pearlBody["model"] as? String, "eleven_v3")
        XCTAssertEqual(pearlBody["language"] as? String, "en")
        let kill = SpanishTranslatorAPI.pearlWarmRewrite("Kill the power.")
        XCTAssertFalse(CrewDialectRewrite.fold(kill).contains("kill the power"))
        XCTAssertFalse(kill.lowercased().hasPrefix("would you please"))
        XCTAssertTrue(kill.lowercased().contains("power"))
        XCTAssertFalse(kill.lowercased().contains("kill"))
        XCTAssertEqual(
            SpanishTranslatorAPI.lineForCrew(crew: .pearl, english: "Kill the power.", spanish: "Corta la corriente.", fallback: "nope"),
            kill
        )
        let conduit = SpanishTranslatorAPI.pearlWarmRewrite("Hand me that conduit.")
        XCTAssertTrue(conduit.lowercased().contains("conduit"))
        XCTAssertFalse(CrewDialectRewrite.fold(conduit).contains("hand me that conduit"))
        let ladder = SpanishTranslatorAPI.pearlWarmRewrite("Move the ladder.")
        XCTAssertTrue(ladder.lowercased().contains("ladder"))
        XCTAssertFalse(CrewDialectRewrite.fold(ladder).contains("move the ladder"))
        XCTAssertTrue(SpanishTranslatorAPI.pearlWarmRewrite("Watch your head.").lowercased().contains("head"))
        let generic = SpanishTranslatorAPI.pearlWarmRewrite("Hold this for a second.")
        XCTAssertTrue(generic.lowercased().contains("hold this"))
        // Pearl frames rotate; this ask lands on "Could you … for me?" and may omit "please".
        let warmed = (
            kill + " " + SpanishTranslatorAPI.pearlWarmRewrite("Who left this mess?") + " " + CrewTalkMember.pearl.blurb
        ).lowercased()
        XCTAssertFalse(warmed.contains("comedy"))
        XCTAssertFalse(warmed.contains("stoner"))
        XCTAssertFalse(warmed.contains("smart-ass"))
        XCTAssertFalse(warmed.contains("florida"))
        XCTAssertEqual(
            SpanishTranslatorAPI.lineForCrew(crew: .pearl, english: "  ", spanish: "Hola", fallback: "Move the ladder."),
            ladder
        )
        XCTAssertFalse(ladder.lowercased().contains("hola"))
        XCTAssertEqual(CrewTalkMember.parse("Sloane Merritt"), .sloaneMerritt)
        XCTAssertEqual(CrewTalkMember.parse("sloane"), .sloaneMerritt)
        XCTAssertEqual(CrewTalkMember.sloaneMerritt.displayName, "Sloane Merritt")
        XCTAssertEqual(CrewTalkMember.sloaneMerritt.voiceID, "qMmZtYs7EKOOIm0u211n")
        XCTAssertEqual(CrewTalkMember.sloaneMerritt.speakLanguage, "en")
        XCTAssertEqual(CrewTalkMember.sloaneMerritt.portraitAssetName, "crewSloaneMerritt")
        XCTAssertEqual(CrewTalkMember.sloaneMerritt.talkAssetName, "crewSloaneMerrittTalk")
        XCTAssertTrue(CrewTalkMember.sloaneMerritt.prefersFemaleDeviceVoice)
        XCTAssertEqual(
            CrewTalkMember.sloaneMerritt.blurb,
            "A polished HR lead who turns a blunt ask into a meeting."
        )
        let sloaneBody = SpanishTranslatorAPI.speakRequestBody(
            text: "Stop talking and get that feeder in before lunch.",
            voiceMode: .clean,
            crew: .sloaneMerritt
        )
        XCTAssertEqual(sloaneBody["voice"] as? String, "qMmZtYs7EKOOIm0u211n")
        XCTAssertEqual(sloaneBody["model"] as? String, "eleven_v3")
        XCTAssertEqual(sloaneBody["language"] as? String, "en")
        let feeder = SpanishTranslatorAPI.sloaneCorporateRewrite(
            "Stop talking and get that feeder in before lunch."
        )
        XCTAssertEqual(
            feeder,
            "Team, I want to circle back on landing the feeder before lunch. I'll piggyback with leadership so they hear it was you."
        )
        XCTAssertTrue(feeder.lowercased().contains("circle back"))
        XCTAssertTrue(feeder.lowercased().contains("piggyback"))
        // Feeder known-string is the new two-line meeting-speak (no leftover "align"/"offline").
        XCTAssertTrue(feeder.lowercased().contains("feeder"))
        XCTAssertEqual(
            SpanishTranslatorAPI.lineForCrew(
                crew: .sloaneMerritt,
                english: "Stop talking and get that feeder in before lunch.",
                spanish: "Corta la corriente.",
                fallback: "nope"
            ),
            feeder
        )
        let genericSloane = SpanishTranslatorAPI.sloaneCorporateRewrite("Hold this for a second.")
        XCTAssertFalse(genericSloane.lowercased().contains("hold this for a second"))
        XCTAssertTrue(genericSloane.lowercased().contains("hold"))
        let sloaneHostile = SpanishTranslatorAPI.sloaneCorporateRewrite("Shut up you idiot and kill the damn power.")
        XCTAssertFalse(sloaneHostile.lowercased().contains("idiot"))
        XCTAssertFalse(sloaneHostile.lowercased().contains("shut up"))
        XCTAssertFalse(sloaneHostile.lowercased().contains("damn"))
        XCTAssertTrue(sloaneHostile.lowercased().contains("power"))
        XCTAssertNotEqual(sloaneHostile.lowercased().filter { !$0.isWhitespace }, "shutupyouidiotandkillthedamnpower.")
        let jargon = [
            "north star", "flywheel", "paradigm shift", "synergy", "move the needle",
            "boil the ocean", "low-hanging fruit", "pivot", "touch base", "ping",
            "offline", "circle back", "bifurcate", "bandwidth", "on my radar",
            "in the loop", "hard stop", "piggyback",
        ]
        let samples = [
            "Hold this for a second.",
            "Shut up you idiot and kill the damn power.",
            "We are out of staples.",
            "The panel is buzzing.",
            "Bring the torque wrench.",
            "Tell them the inspection moved.",
            "Leave the breaker off.",
            "Call me when the lift is free.",
        ].map { SpanishTranslatorAPI.sloaneCorporateRewrite($0).lowercased() }
        let hit = Set(jargon.filter { term in samples.contains { $0.contains(term) } })
        XCTAssertGreaterThanOrEqual(hit.count, 6, "Sloane should rotate a wide jargon bank, hit \(hit)")
        XCTAssertGreaterThanOrEqual(Set(samples).count, 4)
        let junieHostile = SpanishTranslatorAPI.junieDialectRewrite("Shut up you idiot and kill the damn power.")
        XCTAssertFalse(junieHostile.lowercased().contains("idiot"))
        XCTAssertFalse(junieHostile.lowercased().contains("damn"))
        XCTAssertNotEqual(junieHostile.lowercased(), "shut up you idiot and kill the damn power.")
        let bodieLine = SpanishTranslatorAPI.bodieDialectRewrite("Kill the power.")
        XCTAssertTrue(bodieLine.lowercased().contains("kill"))
        XCTAssertTrue(bodieLine.lowercased().contains("power"))
        XCTAssertFalse(bodieLine.lowercased().contains("kill the power"))
        let pearlHostile = SpanishTranslatorAPI.pearlWarmRewrite("Shut up you idiot and kill the damn power.")
        XCTAssertFalse(pearlHostile.lowercased().contains("idiot"))
        XCTAssertFalse(pearlHostile.lowercased().contains("shut"))
        XCTAssertTrue(pearlHostile.lowercased().contains("please") || pearlHostile.lowercased().contains("would you"))
        let corporate = (
            feeder + " " + genericSloane + " " + sloaneHostile + " " + CrewTalkMember.sloaneMerritt.blurb
        ).lowercased()
        XCTAssertFalse(corporate.contains("comedy"))
        XCTAssertFalse(corporate.contains("stoner"))
        XCTAssertFalse(corporate.contains("smart-ass"))
        XCTAssertFalse(corporate.contains("florida"))
        XCTAssertFalse(corporate.contains("profanity"))
        XCTAssertEqual(
            SpanishTranslatorAPI.lineForCrew(
                crew: .sloaneMerritt,
                english: "  ",
                spanish: "Hola",
                fallback: "Kill the power."
            ),
            SpanishTranslatorAPI.sloaneCorporateRewrite("Kill the power.")
        )
    }



    func testSpeakRequestBodyLanguageFollowsDirectionNotOnlyCrew() throws {
        let pearlES = SpanishTranslatorAPI.speakRequestBody(
            text: "Corta la corriente.",
            voiceMode: .jobsite,
            language: "es",
            crew: .pearl
        )
        XCTAssertEqual(pearlES["voice"] as? String, CrewTalkMember.pearl.voiceID)
        XCTAssertEqual(pearlES["language"] as? String, "es")
        let pearlDefault = SpanishTranslatorAPI.speakRequestBody(
            text: "Cut the power.",
            voiceMode: .clean,
            crew: .pearl
        )
        XCTAssertEqual(pearlDefault["language"] as? String, "en")
        let titoEN = SpanishTranslatorAPI.speakRequestBody(
            text: "Cut the power.",
            voiceMode: .jobsite,
            language: "en",
            crew: .titoSolano
        )
        XCTAssertEqual(titoEN["language"] as? String, "en")
        XCTAssertEqual(titoEN["voice"] as? String, CrewTalkMember.titoSolano.voiceID)
    }

    func testDialectRewriteNoStockOpenerGlueAndRequestSurvives() {
        let pearl = SpanishTranslatorAPI.pearlWarmRewrite("Hi I need you to clean up all these racks")
        XCTAssertFalse(pearl.lowercased().contains("would you please hi"))
        XCTAssertFalse(pearl.lowercased().hasPrefix("would you please hi"))
        XCTAssertTrue(pearl.lowercased().contains("rack"))
        XCTAssertTrue(pearl.lowercased().contains("clean"))
        XCTAssertNotEqual(pearl.lowercased(), "hi i need you to clean up all these racks")
        XCTAssertNotEqual(
            pearl.lowercased().replacingOccurrences(of: "?", with: ""),
            "would you please hi i need you to clean up all these racks"
        )

        let bodie = SpanishTranslatorAPI.bodieDialectRewrite("Hi I need you to clean up all these racks")
        XCTAssertFalse(bodie.lowercased().contains("hi i need you"))
        XCTAssertTrue(bodie.lowercased().contains("rack") || bodie.lowercased().contains("clean"))

        let junie = SpanishTranslatorAPI.junieDialectRewrite("Hi I need you to clean up all these racks")
        XCTAssertFalse(junie.lowercased().contains("hi i need you"))
        XCTAssertTrue(junie.lowercased().contains("rack") || junie.lowercased().contains("clean"))

        let tito = SpanishTranslatorAPI.titoDialectRewrite("Hi I need you to clean up all these racks")
        XCTAssertFalse(tito.lowercased().contains("hi i need"))
        XCTAssertTrue(tito.lowercased().contains("rack"))

        let sloane = SpanishTranslatorAPI.sloaneCorporateRewrite("Hi I need you to clean up all these racks")
        XCTAssertFalse(sloane.lowercased().contains("hi i need you to clean up all these racks"))
        XCTAssertTrue(sloane.lowercased().contains("rack"))

        let praise = "You are so good at this"
        for line in [
            SpanishTranslatorAPI.bodieDialectRewrite(praise),
            SpanishTranslatorAPI.junieDialectRewrite(praise),
            SpanishTranslatorAPI.pearlWarmRewrite(praise),
            SpanishTranslatorAPI.sloaneCorporateRewrite(praise),
            SpanishTranslatorAPI.titoDialectRewrite(praise),
        ] {
            let folded = CrewDialectRewrite.fold(line)
            XCTAssertFalse(folded.contains(CrewDialectRewrite.fold(praise)), line)
            XCTAssertFalse(folded.contains("im fixin to " + CrewDialectRewrite.fold(praise)), line)
            XCTAssertFalse(folded.contains("would you please " + CrewDialectRewrite.fold(praise)), line)
            XCTAssertFalse(folded.hasPrefix("im fixin to"), line)
            XCTAssertFalse(folded.hasPrefix("would you please"), line)
        }
        XCTAssertTrue(SpanishTranslatorAPI.junieDialectRewrite(praise).lowercased().contains("gift"))
        XCTAssertTrue(SpanishTranslatorAPI.pearlWarmRewrite(praise).lowercased().contains("gift"))
        XCTAssertTrue(SpanishTranslatorAPI.bodieDialectRewrite(praise).lowercased().contains("natural"))
        XCTAssertTrue(SpanishTranslatorAPI.sloaneCorporateRewrite(praise).lowercased().contains("strong")
            || SpanishTranslatorAPI.sloaneCorporateRewrite(praise).lowercased().contains("circle"))
        assertTitoHitsProfanityCeiling(SpanishTranslatorAPI.titoDialectRewrite(praise))
        // Meeting-speak, two sentences.
        let sentenceEnds = sloane.filter { ".!?".contains($0) }.count
        XCTAssertLessThanOrEqual(sentenceEnds, 2)
        XCTAssertGreaterThanOrEqual(sentenceEnds, 1)
    }

    func testSloaneMeetingSpeakNoInsultEchoTwoLines() {
        let hostile = SpanishTranslatorAPI.sloaneCorporateRewrite("Shut up you idiot and kill the damn power.")
        XCTAssertFalse(hostile.lowercased().contains("idiot"))
        XCTAssertFalse(hostile.lowercased().contains("shut up"))
        XCTAssertFalse(hostile.lowercased().contains("damn"))
        XCTAssertFalse(hostile.lowercased().contains("kill the damn"))
        XCTAssertTrue(hostile.lowercased().contains("power") || hostile.lowercased().contains("circle"))
        let ends = hostile.filter { ".!?".contains($0) }.count
        XCTAssertLessThanOrEqual(ends, 2)
        // Must not echo the insult string.
        XCTAssertNotEqual(
            hostile.lowercased().filter { !$0.isWhitespace },
            "shutupyouidiotandkillthedamnpower."
        )
    }

    func testDockSpokenAnswerIsOtherLanguageNotEnglishDialect() {
        let english = "Kill the power."
        let spanish = "Corta la corriente."
        let pearlSpoken = SpanishTranslatorAPI.spokenAnswerForDock(
            crew: .pearl,
            direction: .englishToSpanish,
            english: english,
            spanish: spanish,
            fallback: english
        )
        XCTAssertEqual(pearlSpoken, spanish)
        let pearlHelper = SpanishTranslatorAPI.dialectHelperLine(
            crew: .pearl,
            direction: .englishToSpanish,
            english: english,
            spanish: spanish,
            fallback: english
        )
        XCTAssertEqual(pearlHelper, SpanishTranslatorAPI.pearlWarmRewrite(english))
        XCTAssertNotEqual(pearlHelper, pearlSpoken)

        let bodieSpoken = SpanishTranslatorAPI.spokenAnswerForDock(
            crew: .bodieHale,
            direction: .englishToSpanish,
            english: english,
            spanish: spanish,
            fallback: english
        )
        XCTAssertEqual(bodieSpoken, spanish)

        let esToEn = SpanishTranslatorAPI.spokenAnswerForDock(
            crew: .juniePell,
            direction: .spanishToEnglish,
            english: "Cut the power.",
            spanish: "Corta la corriente.",
            fallback: "Corta la corriente."
        )
        XCTAssertEqual(esToEn, "Cut the power.")

        let titoSpoken = SpanishTranslatorAPI.spokenAnswerForDock(
            crew: .titoSolano,
            direction: .englishToSpanish,
            english: english,
            spanish: spanish,
            fallback: english
        )
        XCTAssertNotEqual(titoSpoken, english)
        XCTAssertTrue(titoSpoken.lowercased().contains("corriente") || titoSpoken.lowercased().contains("coño") || titoSpoken.lowercased().contains("cono"))
        XCTAssertEqual(
            SpanishTranslatorAPI.dialectHelperLine(
                crew: .titoSolano,
                direction: .englishToSpanish,
                english: english,
                spanish: spanish,
                fallback: english
            ),
            ""
        )
        XCTAssertEqual(SpanishTranslatorAPI.speakLanguageForDirection(.englishToSpanish), "es")
        XCTAssertEqual(SpanishTranslatorAPI.speakLanguageForDirection(.spanishToEnglish), "en")

        let typed = "You are so good at this"
        let junieSpoken = SpanishTranslatorAPI.lineToSpeak(
            crew: .juniePell,
            direction: .englishToSpanish,
            english: typed,
            spanish: "",
            fallback: typed
        )
        XCTAssertEqual(
            junieSpoken,
            SpanishTranslatorAPI.dialectHelperLine(
                crew: .juniePell,
                direction: .englishToSpanish,
                english: typed,
                spanish: "",
                fallback: typed
            )
        )
        XCTAssertNotEqual(junieSpoken, typed)
        XCTAssertFalse(CrewDialectRewrite.fold(junieSpoken).contains(CrewDialectRewrite.fold(typed)))
        XCTAssertEqual(
            SpanishTranslatorAPI.speakLanguageForLineToSpeak(
                crew: .juniePell,
                direction: .englishToSpanish,
                english: typed,
                spanish: "",
                fallback: typed
            ),
            "en"
        )
        let junieWithSpanish = SpanishTranslatorAPI.lineToSpeak(
            crew: .juniePell,
            direction: .englishToSpanish,
            english: typed,
            spanish: "Eres muy bueno en esto.",
            fallback: typed
        )
        XCTAssertEqual(junieWithSpanish, SpanishTranslatorAPI.junieDialectRewrite(typed))
        XCTAssertNotEqual(junieWithSpanish, "Eres muy bueno en esto.")
        XCTAssertEqual(
            SpanishTranslatorAPI.speakLanguageForLineToSpeak(
                crew: .juniePell,
                direction: .englishToSpanish,
                english: typed,
                spanish: "Eres muy bueno en esto.",
                fallback: typed
            ),
            "en"
        )
        let titoLineToSpeak = SpanishTranslatorAPI.lineToSpeak(
            crew: .titoSolano,
            direction: .englishToSpanish,
            english: typed,
            spanish: "",
            fallback: typed
        )
        XCTAssertNotEqual(titoLineToSpeak, typed)
        XCTAssertFalse(CrewDialectRewrite.fold(titoLineToSpeak).contains(CrewDialectRewrite.fold(typed)))
        XCTAssertEqual(
            SpanishTranslatorAPI.speakLanguageForLineToSpeak(
                crew: .titoSolano,
                direction: .englishToSpanish,
                english: typed,
                spanish: "",
                fallback: typed
            ),
            "es"
        )
        XCTAssertEqual(CrewTalkMember.pearl.firstName, "Pearl")
        XCTAssertEqual(CrewTalkMember.sloaneMerritt.firstName, "Sloane")
        XCTAssertEqual(CrewTalkMember.bodieHale.firstName, "Bodie")
    }

    private func assertTitoHitsProfanityCeiling(_ line: String, file: StaticString = #filePath, lineNumber: UInt = #line) {
        let folded = line.folding(options: .diacriticInsensitive, locale: Locale(identifier: "es")).lowercased()
        let markers = ["cono", "carajo", "mierda", "pinga", "joder", "cabron", "puta"]
        let hits = markers.filter { folded.contains($0) }
        XCTAssertGreaterThanOrEqual(hits.count, 2, "Tito line should hit the profanity ceiling, got \(line)", file: file, line: lineNumber)
        let banned = ["nigger", "nigga", "spic", "chink", "kike", "faggot", "wetback", "retard"]
        for word in banned {
            XCTAssertFalse(folded.contains(word), file: file, line: lineNumber)
        }
    }


    func testBodieVoiceKeepsTheAskAndStripsLaughTagsForDisplay() throws {
        XCTAssertEqual(
            CrewTalkMember.bodieHale.blurb,
            "Laid-back California stoner buddy. Slow, raspy, and always laughing."
        )
        XCTAssertEqual(CrewTalkMember.bodieHale.appleRateFactor, 0.86)
        XCTAssertEqual(CrewTalkMember.bodieHale.applePitchMultiplier, 0.92)

        let samples: [(String, String)] = [
            ("Kill the power.", "power"),
            ("Hand me that conduit.", "conduit"),
            ("Move the ladder.", "ladder"),
            ("Watch your head.", "head"),
            ("We need more wire.", "wire"),
            ("Someone left this mess.", "mess"),
            ("Land that feeder before lunch.", "feeder"),
            ("Leave the breaker alone.", "breaker"),
            ("Clean up all these racks.", "rack"),
            ("Hold this for a second.", "hold"),
            ("You are so good at this.", "natural"),
            ("Hey", "hey"),
            ("Bring the drill to the truck", "drill"),
        ]
        let tag = #"\[[^\]]{1,24}\]"#
        var laughing = 0
        for (raw, ask) in samples {
            let line = SpanishTranslatorAPI.bodieDialectRewrite(raw)
            XCTAssertTrue(line.lowercased().contains(ask), "\(raw) -> \(line)")
            XCTAssertLessThan(line.count, 200, line)
            var tagCount = 0
            var rest = line.startIndex..<line.endIndex
            while let found = line.range(of: tag, options: .regularExpression, range: rest) {
                tagCount += 1
                rest = found.upperBound..<line.endIndex
            }
            XCTAssertLessThanOrEqual(tagCount, 2, line)
            if tagCount > 0 { laughing += 1 }
            let shown = CrewDialectRewrite.displayText(line)
            XCTAssertFalse(shown.contains("["), shown)
            XCTAssertFalse(shown.contains("]"), shown)
            XCTAssertFalse(shown.contains("  "), shown)
            XCTAssertTrue(shown.lowercased().contains(ask), shown)
        }
        XCTAssertGreaterThanOrEqual(laughing, samples.count / 2)

        let cut = SpanishTranslatorAPI.bodieDialectRewrite("Kill the power.")
        let power = try XCTUnwrap(cut.range(of: "power"))
        let laugh = try XCTUnwrap(cut.range(of: "["))
        XCTAssertGreaterThanOrEqual(laugh.lowerBound, power.upperBound, cut)
        XCTAssertFalse(CrewDialectRewrite.displayText(cut).contains("chuckles"))

        let rejected = SpanishTranslatorAPI.bodieDialectRewrite("Don't kill the power")
        XCTAssertFalse(rejected.lowercased().contains("kill"), rejected)
        XCTAssertTrue(rejected.contains("[chuckles]"), rejected)
        XCTAssertFalse(CrewDialectRewrite.displayText(rejected).contains("["))
    }


    /// A2: unmatched Tito is empty. Dock and Speak must use the API Spanish
    /// so finish-after-draft leaves `.translating` instead of hanging.
    func testTitoFreeTextDockAndSpeakUseTranslationAndLeaveTranslating() {
        let english = "Bring the drill to the truck"
        let spanish = "Trae el taladro al camión."
        XCTAssertEqual(CrewDialectRewrite.tito(english), "")
        XCTAssertEqual(CrewRewriteGuard.intent(english), .free)

        let dock = SpanishTranslatorAPI.spokenAnswerForDock(
            crew: .titoSolano,
            direction: .englishToSpanish,
            english: english,
            spanish: spanish,
            fallback: english
        )
        XCTAssertEqual(dock, spanish)

        let speak = SpanishTranslatorAPI.lineToSpeak(
            crew: .titoSolano,
            direction: .englishToSpanish,
            english: english,
            spanish: spanish,
            fallback: english
        )
        XCTAssertEqual(speak, spanish)

        // Translation only on the fallback slot (draft.translation) still speaks it.
        let fromFallback = SpanishTranslatorAPI.lineToSpeak(
            crew: .titoSolano,
            direction: .englishToSpanish,
            english: english,
            spanish: "",
            fallback: spanish
        )
        XCTAssertEqual(fromFallback, spanish)

        let finish = SpanishTranslatorAPI.finishSpeakAfterDraft(
            crew: .titoSolano,
            direction: .englishToSpanish,
            english: english,
            spanish: spanish,
            draftTranslation: spanish
        )
        guard case .speak(let line) = finish else {
            return XCTFail("free-text Tito must leave translating and speak the translation")
        }
        XCTAssertEqual(line, spanish)

        let nothingToSay = SpanishTranslatorAPI.finishSpeakAfterDraft(
            crew: .titoSolano,
            direction: .englishToSpanish,
            english: english,
            spanish: "",
            draftTranslation: ""
        )
        XCTAssertEqual(nothingToSay, .ready)
    }

    func testTitoKeywordStillUsesCubanRewriteNotAPISpanish() {
        let english = "Kill the power."
        let spanish = "Corta la corriente."
        let rewrite = CrewDialectRewrite.tito(english)
        XCTAssertFalse(rewrite.isEmpty)
        XCTAssertNotEqual(rewrite, spanish)

        let dock = SpanishTranslatorAPI.spokenAnswerForDock(
            crew: .titoSolano,
            direction: .englishToSpanish,
            english: english,
            spanish: spanish,
            fallback: english
        )
        XCTAssertEqual(dock, rewrite)

        let speak = SpanishTranslatorAPI.lineToSpeak(
            crew: .titoSolano,
            direction: .englishToSpanish,
            english: english,
            spanish: spanish,
            fallback: english
        )
        XCTAssertEqual(speak, rewrite)

        let finish = SpanishTranslatorAPI.finishSpeakAfterDraft(
            crew: .titoSolano,
            direction: .englishToSpanish,
            english: english,
            spanish: spanish,
            draftTranslation: spanish
        )
        XCTAssertEqual(finish, .speak(rewrite))
    }

    /// Regression: Lupita answered every question, negation, and long sentence with one
    /// canned line, so recorded speech never seemed to be understood.
    func testLupitaSpeaksTheRealTranslationWhenNoTemplateMatches() {
        let cases: [(english: String, spanish: String)] = [
            ("Bring the drill to the truck", "Trae el taladro al camión."),
            ("Where is the panel for the second floor?", "¿Dónde está el panel del segundo piso?"),
            ("Don't touch that wire", "No toques ese cable."),
            ("We need to finish the rough in on the third floor before the inspector shows up tomorrow morning",
             "Hay que terminar la instalación del tercer piso antes de que llegue el inspector mañana."),
        ]
        var spoken = Set<String>()
        for item in cases {
            XCTAssertEqual(CrewDialectRewrite.lupita(item.english), "", item.english)
            let dock = SpanishTranslatorAPI.spokenAnswerForDock(
                crew: .lupitaReyes,
                direction: .englishToSpanish,
                english: item.english,
                spanish: item.spanish,
                fallback: item.english
            )
            XCTAssertEqual(dock, item.spanish)
            let line = SpanishTranslatorAPI.lineToSpeak(
                crew: .lupitaReyes,
                direction: .englishToSpanish,
                english: item.english,
                spanish: item.spanish,
                fallback: item.english
            )
            XCTAssertEqual(line, item.spanish)
            spoken.insert(line)
        }
        XCTAssertEqual(spoken.count, cases.count, "different speech must give different lines")
    }

    func testBodieFreeTextUnchangedWhenTitoFallsBack() {
        let english = "Bring the drill to the truck"
        let spanish = "Trae el taladro al camión."

        let bodieRewrite = SpanishTranslatorAPI.bodieDialectRewrite(english)
        XCTAssertFalse(bodieRewrite.isEmpty)
        XCTAssertNotEqual(bodieRewrite, spanish)
        XCTAssertEqual(
            SpanishTranslatorAPI.spokenAnswerForDock(
                crew: .bodieHale,
                direction: .englishToSpanish,
                english: english,
                spanish: spanish,
                fallback: english
            ),
            spanish
        )
        XCTAssertEqual(
            SpanishTranslatorAPI.lineToSpeak(
                crew: .bodieHale,
                direction: .englishToSpanish,
                english: english,
                spanish: spanish,
                fallback: english
            ),
            bodieRewrite
        )
    }


}
