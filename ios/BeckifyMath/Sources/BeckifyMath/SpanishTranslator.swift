import Foundation

/// Outcome of one `/api/translate` call (Beckify AI → Cuban / Florida LatAm Spanish).
public struct SpanishTranslationDraft: Equatable, Sendable {
    public var translation: String
    public var dialect: String
    public var sourceText: String
    public var sourceLanguage: String
    public var targetLanguage: String
    public var provider: String
    public var model: String
    public var notes: String
    /// `beckify` = cloud API; `apple` = on-device Translation framework fallback.
    public var engine: String

    public init(
        translation: String,
        dialect: String = "cuban_florida_latam",
        sourceText: String = "",
        sourceLanguage: String = "en",
        targetLanguage: String = "es",
        provider: String = "",
        model: String = "",
        notes: String = "",
        engine: String = "beckify"
    ) {
        self.translation = translation
        self.dialect = dialect
        self.sourceText = sourceText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.provider = provider
        self.model = model
        self.notes = notes
        self.engine = engine
    }

    public var displayDialect: String {
        let folded = dialect.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if folded.contains("cuba") || folded.contains("florida") || folded.contains("miami") {
            return "Cuban / Florida Spanish"
        }
        if folded.contains("latam") || folded.contains("latin") || folded.contains("mx") || folded.contains("mexico") {
            return "Latin American Spanish"
        }
        if engine == "apple" { return "On-device Spanish (Apple)" }
        if dialect.isEmpty { return "LatAm Spanish" }
        return dialect
    }
}

/// Shared contract with `https://api.beckify.com/api/translate`.
/// Pure helpers for Linux tests — no UIKit / Speech / AVFoundation.
public enum SpanishTranslatorAPI {
    public static let task = "translate"
    public static let defaultAPIBase = PhotoLookCheck.defaultAPIBase
    public static let translatePath = "/api/translate"
    public static let speakPath = "/api/speak"
    /// Short neural TTS clips (cost control).
    public static let maxSpeakCharacters = 500
    public static let maxSourceCharacters = 2000
    public static let disclaimer =
        "Speech stays on this device for recognition. Prefers blunt Cuban / South Florida jobsite Spanish via the Beckify API (api.beckify.com). If that API is unreachable, falls back to on-device Apple Translation on iOS 18+ (generic Spanish, not Cuban-tuned). Translation text uploads only when the Beckify path runs. Loud playback prefers OpenAI neural TTS from api.beckify.com/api/speak (short clips); Apple AVSpeech is the fallback if cloud TTS fails. Not a certified interpreter."

    public static func defaultTranslateURL() -> URL? {
        translateURL(customEndpoint: nil, apiBase: defaultAPIBase)
    }

    /// Custom HTTPS URL wins. Otherwise `{apiBase}/api/translate`.
    public static func translateURL(customEndpoint: String?, apiBase: String? = defaultAPIBase) -> URL? {
        if let custom = PhotoLookCheck.httpsBase(customEndpoint), let url = URL(string: custom) {
            return url
        }
        guard let base = PhotoLookCheck.httpsBase(apiBase), !base.isEmpty else { return nil }
        return URL(string: base + translatePath)
    }


    public static func defaultSpeakURL() -> URL? {
        speakURL(customEndpoint: nil, apiBase: defaultAPIBase)
    }

    /// Neural TTS endpoint. Custom HTTPS URL that ends with `/api/translate` maps to `/api/speak`
    /// on the same host; other custom URLs still fall back to `{apiBase}/api/speak` so a private
    /// translate proxy without TTS does not break loud playback.
    public static func speakURL(customEndpoint: String?, apiBase: String? = defaultAPIBase) -> URL? {
        if let custom = PhotoLookCheck.httpsBase(customEndpoint), let url = URL(string: custom) {
            let absolute = url.absoluteString
            if absolute.lowercased().contains("/api/translate") {
                let mapped = absolute.replacingOccurrences(
                    of: "/api/translate",
                    with: speakPath,
                    options: [.caseInsensitive]
                )
                if let speak = URL(string: mapped) { return speak }
            }
        }
        guard let base = PhotoLookCheck.httpsBase(apiBase), !base.isEmpty else { return nil }
        return URL(string: base + speakPath)
    }

    public static func speakRequestBody(
        text: String,
        voice: String = "onyx",
        format: String = "mp3"
    ) -> [String: Any] {
        [
            "task": "speak",
            "text": text,
            "voice": voice,
            "format": format,
            "language": "es",
        ]
    }

    public static func speakRequestJSON(
        text: String,
        voice: String = "onyx",
        format: String = "mp3"
    ) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: speakRequestBody(text: text, voice: voice, format: format),
            options: []
        )
    }

    public static func clampSpeakText(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= maxSpeakCharacters { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: maxSpeakCharacters)
        return String(trimmed[..<end])
    }

    public static func formatSpeakError(
        status: Int,
        message: String?,
        endpoint: String
    ) -> String {
        let trimmed = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if status == 0 {
            return trimmed.isEmpty
                ? "Could not reach the Beckify speak API. Falling back to Apple TTS."
                : trimmed
        }
        if !trimmed.isEmpty { return trimmed }
        if status == 404 || status == 405 {
            return "Speak is not on this API host yet (HTTP \(status)). Redeploy api.beckify.com, or Apple TTS will play."
        }
        if status == 429 {
            return "Too many speak requests right now. Using Apple TTS this time."
        }
        if status == 503 {
            return "The Beckify speak API is missing a provider key (HTTP 503)."
        }
        if PhotoLookCheck.hostIsGitHubPages(endpoint) {
            return "GitHub Pages cannot accept speak POSTs. Use https://api.beckify.com."
        }
        return "The Beckify speak API is unavailable (HTTP \(status))."
    }

    /// Same Authorization rule as Look Check / vision: token only for a custom endpoint.
    public static func authorizationToken(customEndpoint: String?, token: String) -> String {
        PhotoLookCheck.authorizationToken(customEndpoint: customEndpoint, token: token)
    }

    public static func requestBody(
        text: String,
        sourceLanguage: String = "en",
        targetLanguage: String = "es"
    ) -> [String: Any] {
        [
            "task": task,
            "text": text,
            "sourceText": text,
            "sourceLanguage": sourceLanguage,
            "targetLanguage": targetLanguage,
            "dialect": "cuban_florida_latam",
        ]
    }

    public static func requestJSON(
        text: String,
        sourceLanguage: String = "en",
        targetLanguage: String = "es"
    ) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: requestBody(
                text: text,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            ),
            options: []
        )
    }

    public static func clampSourceText(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= maxSourceCharacters { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: maxSourceCharacters)
        return String(trimmed[..<end])
    }

    /// Sticky / phase label after a successful Beckify API translation.
    public static let statusViaBeckifyAI = "Translated via Beckify AI"
    /// Sticky / phase label after a successful on-device Apple Translation fallback.
    public static let statusOnDevice = "Translated on device"

    /// Minimum OS for Apple TranslationSession (Translation framework).
    public static let onDeviceTranslationMinimumOS = "iOS 18"

    /// Preferred Apple Translation target language identifiers (LatAm / Florida-relevant first).
    public static let preferredAppleSpanishLanguageIDs: [String] = [
        "es-MX",
        "es-US",
        "es-419",
        "es",
    ]

    public static func appleOnDeviceDraft(
        translation: String,
        sourceText: String,
        targetLanguageID: String = "es"
    ) -> SpanishTranslationDraft {
        SpanishTranslationDraft(
            translation: translation.trimmingCharacters(in: .whitespacesAndNewlines),
            dialect: "apple_on_device_es",
            sourceText: sourceText,
            sourceLanguage: "en",
            targetLanguage: targetLanguageID,
            provider: "apple",
            model: "TranslationSession",
            notes: "On-device Apple Translation. Generic Spanish (closest LatAm pair when available) — not Cuban jobsite register like Beckify AI.",
            engine: "apple"
        )
    }

    /// Network / HTTP failures that should trigger on-device fallback (not auth-only client errors we cannot recover).
    public static func shouldAttemptOnDeviceFallback(httpStatus: Int) -> Bool {
        if httpStatus == 0 { return true } // transport / DNS / offline
        if httpStatus == 404 || httpStatus == 405 { return true }
        if httpStatus == 408 || httpStatus == 429 { return true }
        if httpStatus >= 500 { return true }
        // Treat unexpected 3xx / other failures as fallback-worthy so the Answer never sticks on English-only.
        if httpStatus < 200 || httpStatus >= 300 { return true }
        return false
    }

    public static func onDeviceUnavailableMessage(apiError: String?) -> String {
        let api = (apiError ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let need = "On-device Apple Translation needs \(onDeviceTranslationMinimumOS) or later (or languages are not installed). English stays on screen for retry."
        if api.isEmpty { return need }
        return "\(api) \(need)"
    }

    public static func bothPathsFailedMessage(apiError: String?, onDeviceError: String?) -> String {
        let api = (apiError ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let device = (onDeviceError ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        switch (api.isEmpty, device.isEmpty) {
        case (false, false):
            return "Beckify AI: \(api) On-device: \(device)"
        case (false, true):
            return api
        case (true, false):
            return "On-device translation failed: \(device)"
        case (true, true):
            return "Translation failed. Check the network or install English ↔ Spanish in Apple Translate, then try again."
        }
    }

    public static func normalizeDraft(_ raw: Any?, fallbackSource: String = "") -> SpanishTranslationDraft? {
        let object: [String: Any]
        if let dict = raw as? [String: Any] {
            object = dict
        } else if let s = raw as? String,
                  let data = s.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            object = dict
        } else {
            return nil
        }

        let translation = firstNonEmpty(
            stringValue(object["translation"]),
            stringValue(object["translatedText"]),
            stringValue(object["spanish"]),
            stringValue(object["text"])
        )
        guard !translation.isEmpty else { return nil }

        let source = firstNonEmpty(
            stringValue(object["sourceText"]),
            stringValue(object["text"]),
            fallbackSource
        )

        return SpanishTranslationDraft(
            translation: translation,
            dialect: stringValue(object["dialect"]) ?? "cuban_florida_latam",
            sourceText: source,
            sourceLanguage: stringValue(object["sourceLanguage"]) ?? "en",
            targetLanguage: stringValue(object["targetLanguage"]) ?? "es",
            provider: stringValue(object["provider"]) ?? "",
            model: stringValue(object["model"]) ?? "",
            notes: stringValue(object["notes"]) ?? "",
            engine: "beckify"
        )
    }

    public static func formatTranslateError(
        status: Int,
        message: String?,
        endpoint: String
    ) -> String {
        let trimmed = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if status == 0 {
            return trimmed.isEmpty
                ? "Could not reach the Beckify translate API. Check the network, then try again."
                : trimmed
        }
        if !trimmed.isEmpty { return trimmed }
        if status == 404 || status == 405 {
            return "Translate is not on this API host yet (HTTP \(status)). Use https://api.beckify.com after a Vercel redeploy, or enter a custom HTTPS translate URL."
        }
        if status == 429 {
            return "Too many translations right now. Wait a moment and try again."
        }
        if status == 503 {
            return "The Beckify translate API is missing a provider key (HTTP 503)."
        }
        if PhotoLookCheck.hostIsGitHubPages(endpoint) {
            return "GitHub Pages cannot accept translate POSTs. Use https://api.beckify.com."
        }
        return "The Beckify translate API is unavailable (HTTP \(status))."
    }

    // MARK: - Voice locale ranking (Florida / Cuban jobsite TTS)

    /// Preferred `AVSpeechSynthesisVoice.language` codes, best first.
    /// Apple does not ship a dedicated Cuban (`es-CU`) voice on most devices;
    /// `es-US` / `es-MX` are the Florida / LatAm choices, then other LatAm, then Spain.
    public static let preferredSpanishVoiceLanguages: [String] = [
        "es-US",
        "es-MX",
        "es-CO",
        "es-AR",
        "es-CL",
        "es-PE",
        "es-VE",
        "es-419",
        "es-ES",
        "es",
    ]

    /// Speech rate multiplier vs `AVSpeechUtteranceDefaultSpeechRate` for noisy sites.
    public static let jobsiteSpeechRateFactor: Float = 0.84
    /// Slight pitch drop so male system voices read a bit thicker / deeper.
    public static let jobsitePitchMultiplier: Float = 0.92

    /// Score a voice language for Florida Cuban / LatAm preference. Higher is better.
    public static func spanishVoiceScore(language: String) -> Int {
        let folded = language.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
        guard folded.hasPrefix("es") else { return -1 }
        for (index, preferred) in preferredSpanishVoiceLanguages.enumerated() {
            if folded == preferred.lowercased() {
                return 1000 - index
            }
        }
        if folded.hasPrefix("es-us") { return 999 }
        if folded.hasPrefix("es-mx") { return 998 }
        if folded.hasPrefix("es-") && folded != "es-es" { return 500 }
        if folded == "es" || folded.hasPrefix("es-es") { return 100 }
        return 50
    }

    /// Combined rank for jobsite playback: male + LatAm locale + higher quality first.
    /// `genderRaw` matches `AVSpeechSynthesisVoiceGender.rawValue` (1 = male, 2 = female, 0 = unspecified on Apple platforms).
    public static func jobsiteVoiceScore(language: String, genderRaw: Int, qualityRaw: Int) -> Int {
        let locale = spanishVoiceScore(language: language)
        guard locale >= 0 else { return -1 }
        let genderBonus: Int
        switch genderRaw {
        case 1: genderBonus = 5000  // male
        case 0: genderBonus = 1000  // unspecified
        default: genderBonus = 0    // female / other
        }
        return genderBonus + locale * 10 + max(0, qualityRaw)
    }

    /// Pick the best language code from an installed-voice list.
    public static func bestSpanishVoiceLanguage(from languages: [String]) -> String? {
        let ranked = languages
            .map { ($0, spanishVoiceScore(language: $0)) }
            .filter { $0.1 >= 0 }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0 < rhs.0
            }
        return ranked.first?.0
    }


    public static func neuralVoiceNote(model: String = "gpt-4o-mini-tts", voice: String = "onyx") -> String {
        let m = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let v = voice.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = [v.isEmpty ? "onyx" : v, m.isEmpty ? "gpt-4o-mini-tts" : m].joined(separator: " · ")
        return "Neural TTS · \(label) · Cuban / South Florida jobsite yell · max speaker volume"
    }

    public static func voiceFallbackNote(
        selectedLanguage: String?,
        genderLabel: String? = nil,
        voiceName: String? = nil
    ) -> String {
        let lang = (selectedLanguage ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if lang.isEmpty {
            return "No Spanish system voice found for Apple fallback. Install a Spanish voice in Settings → Accessibility → Spoken Content → Voices. Prefers OpenAI neural TTS from api.beckify.com/api/speak (onyx / gpt-4o-mini-tts)."
        }
        let gender = (genderLabel ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let name = (voiceName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let who = name.isEmpty ? lang : "\(name) (\(lang))"
        let sex: String
        if gender == "male" {
            sex = "male"
        } else if gender == "female" {
            sex = "female (no male Spanish voice installed — add a male es-US/es-MX voice in Spoken Content for the jobsite vibe)"
        } else {
            sex = "system"
        }
        let folded = lang.lowercased()
        let localeNote: String
        if folded.hasPrefix("es-us") {
            localeNote = "US / Florida-relevant"
        } else if folded.hasPrefix("es-mx") {
            localeNote = "LatAm (Cuban es-CU is not shipped by Apple)"
        } else if folded.hasPrefix("es-es") {
            localeNote = "Spain — prefer installing male es-US or es-MX"
        } else {
            localeNote = "closest available Spanish"
        }
        return "Apple fallback: \(who), \(sex), \(localeNote). Prefers OpenAI neural TTS (onyx) from api.beckify.com when reachable; this note is the on-device fallback path."
    }

    // MARK: - Internals

    private static func stringValue(_ raw: Any?) -> String? {
        guard let raw, !(raw is NSNull) else { return nil }
        if let s = raw as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        if let n = raw as? NSNumber { return n.stringValue }
        return nil
    }

    private static func firstNonEmpty(_ values: String?...) -> String {
        for value in values {
            let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return ""
    }
}
