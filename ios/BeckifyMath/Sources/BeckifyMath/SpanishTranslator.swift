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
    public static let maxSourceCharacters = 2000
    public static let disclaimer =
        "Speech stays on this device for recognition. Prefers Cuban / Florida LatAm Spanish via the Beckify API (api.beckify.com). If that API is unreachable, falls back to on-device Apple Translation on iOS 18+ (generic Spanish, not Cuban-tuned). Translation text uploads only when the Beckify path runs. Not a certified interpreter."

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
            notes: "On-device Apple Translation. Generic Spanish (closest LatAm pair when available) — not Cuban / Florida-tuned like Beckify AI.",
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

    // MARK: - Voice locale ranking (Florida / Cuban / LatAm)

    /// Preferred `AVSpeechSynthesisVoice.language` codes, best first.
    /// Apple does not ship a dedicated Cuban (`es-CU`) voice on most devices;
    /// `es-US` is the Florida-relevant choice, then Mexican / other LatAm, then Spain.
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

    public static func voiceFallbackNote(selectedLanguage: String?) -> String {
        let lang = (selectedLanguage ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if lang.isEmpty {
            return "No Spanish system voice found. Install a Spanish voice in Settings → Accessibility → Spoken Content → Voices, or iOS will use a default voice."
        }
        let folded = lang.lowercased()
        if folded.hasPrefix("es-us") {
            return "Speaking with es-US (US / Florida-relevant Spanish)."
        }
        if folded.hasPrefix("es-mx") {
            return "Speaking with es-MX (closest LatAm voice; Cuban es-CU is not shipped by Apple)."
        }
        if folded.hasPrefix("es-es") {
            return "Only es-ES (Spain) is installed — accents may sound Peninsular. Prefer installing es-US or es-MX in Spoken Content."
        }
        return "Speaking with \(lang) (closest available Spanish voice; Cuban es-CU is not typically shipped)."
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
