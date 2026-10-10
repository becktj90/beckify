import Foundation

/// Who Crew Talk is speaking as. Portrait stays on screen. Speech uses that ElevenLabs voice.
public enum CrewTalkMember: String, CaseIterable, Codable, Sendable {
    case bodieHale
    case titoSolano
    case lupitaReyes
    case juniePell
    case pearl
    /// ElevenLabs seed Cos locked for this voice: 50505. Speak client does not POST seed yet (route has no seed field).
    case sloaneMerritt

    public static let storageKey = "crewTalk.member"
    /// Playback model sent to `/api/speak`. The key stays on the server.
    public static let speakModel = "eleven_v3"
    /// ElevenLabs `/api/speak` settings for Junie only. Thick, slow, barely-straight delivery.
    /// The key stays on the server. Voice id stays `tdK8noxHGTBqk6F18tbZ`.
    public static let junieSpeakStability = 0.15
    public static let junieSpeakSimilarity = 0.72
    public static let junieSpeakStyle = 1.0
    public static let junieSpeakSpeed = 0.64

    public var displayName: String {
        switch self {
        case .bodieHale: return "Bodie Hale"
        case .titoSolano: return "Tito Solano"
        case .lupitaReyes: return "Lupita Reyes"
        case .juniePell: return "Junie Pell"
        case .pearl: return "Pearl"
        case .sloaneMerritt: return "Sloane Merritt"
        }
    }

    /// First name for 44 pt crew chips (not truncated full names).
    public var firstName: String {
        switch self {
        case .bodieHale: return "Bodie"
        case .titoSolano: return "Tito"
        case .lupitaReyes: return "Lupita"
        case .juniePell: return "Junie"
        case .pearl: return "Pearl"
        case .sloaneMerritt: return "Sloane"
        }
    }

    /// ElevenLabs voice id. Case-sensitive. Not an OpenAI voice name.
    public var voiceID: String {
        switch self {
        case .bodieHale: return "XVO6RhOYU9ZEKHFXrx6b"
        case .titoSolano: return "goyf4sY4AqSvMIeO1hb5"
        case .lupitaReyes: return "iGXRQ0smdhSFlb6iV1Pr"
        case .juniePell: return "tdK8noxHGTBqk6F18tbZ"
        case .pearl: return "xDnrPZyqSbomyfOcnNpu"
        case .sloaneMerritt: return "qMmZtYs7EKOOIm0u211n"
        }
    }

    /// Idle 16-bit sprite. Shown whenever audio is not playing.
    public var portraitAssetName: String {
        switch self {
        case .bodieHale: return "crewBodieHale"
        case .titoSolano: return "crewTitoSolano"
        case .lupitaReyes: return "crewLupitaReyes"
        case .juniePell: return "crewJuniePell"
        case .pearl: return "crewPearl"
        case .sloaneMerritt: return "crewSloaneMerritt"
        }
    }

    /// Talk frame. Swapped with the idle sprite while audio plays.
    public var talkAssetName: String {
        switch self {
        case .bodieHale: return "crewBodieHaleTalk"
        case .titoSolano: return "crewTitoSolanoTalk"
        case .lupitaReyes: return "crewLupitaReyesTalk"
        case .juniePell: return "crewJuniePellTalk"
        case .pearl: return "crewPearlTalk"
        case .sloaneMerritt: return "crewSloaneMerrittTalk"
        }
    }

    public var blurb: String {
        switch self {
        case .bodieHale: return "Laid-back California stoner buddy. Slow, raspy, and always laughing."
        case .titoSolano: return "Cuban jobsite Spanish. Raspy, direct, and steady."
        case .lupitaReyes: return "Mexican Spanish, Jalisco and Mexico City. Warm diminutives, light asides."
        case .juniePell: return "Rural Alabama English. Slow, low, and kind."
        case .pearl: return "Warm English. Softens a blunt ask and still makes it."
        case .sloaneMerritt: return "A polished HR lead who turns a blunt ask into a meeting."
        }
    }

    /// Language this person speaks. Tito is Spanish; Bodie and Junie are English.
    public var speakLanguage: String {
        switch self {
        case .titoSolano, .lupitaReyes: return "es"
        case .bodieHale, .juniePell, .pearl, .sloaneMerritt: return "en"
        }
    }

    /// Shipped crew are on a direction roster. A hidden voice would be false.
    public var isReleased: Bool {
        switch self {
        case .bodieHale, .titoSolano, .lupitaReyes, .juniePell, .pearl, .sloaneMerritt:
            return true
        }
    }

    public var prefersFemaleDeviceVoice: Bool {
        self == .lupitaReyes || self == .juniePell || self == .pearl || self == .sloaneMerritt
    }

    /// Apple fallback pace. Cloud voice is the real character.
    public var appleRateFactor: Float {
        switch self {
        case .bodieHale: return 0.86
        case .titoSolano: return 0.84
        case .lupitaReyes: return 0.92
        case .juniePell: return 0.70
        case .pearl: return 0.92
        case .sloaneMerritt: return 0.94
        }
    }

    public var applePitchMultiplier: Float {
        switch self {
        case .bodieHale: return 0.92
        case .titoSolano: return 0.86
        case .lupitaReyes: return 1.05
        case .juniePell: return 0.90
        case .pearl: return 1.0
        case .sloaneMerritt: return 1.0
        }
    }

    public static func parse(_ raw: String?) -> CrewTalkMember {
        let folded = (raw ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
        switch folded {
        case "bodiehale", "bodie": return .bodieHale
        case "juniepell", "junie": return .juniePell
        case "pearl": return .pearl
        case "sloanemerritt", "sloane": return .sloaneMerritt
        case "titosolano", "tito": return .titoSolano
        case "lupitareyes", "lupita": return .lupitaReyes
        default: return .titoSolano
        }
    }
}


/// Cloud translate / speak register. UI labels stay generic (`Clean` / `Jobsite`).
public enum SpanishVoiceMode: String, CaseIterable, Codable, Sendable {
    case jobsite
    case clean

    public static let storageKey = "spanishTranslator.voiceMode"

    public var apiValue: String { rawValue }

    /// Chrome label — never "princess" / "profane".
    public var uiLabel: String {
        switch self {
        case .jobsite: return "Jobsite"
        case .clean: return "Clean"
        }
    }

    public var defaultSpeakVoice: String {
        switch self {
        case .jobsite: return "onyx"
        case .clean: return "nova"
        }
    }

    /// Neural TTS voice id for `/api/speak`. English (ES→EN) uses male `echo`
    /// (California). Spanish still follows Clean (`nova`) / Jobsite (`onyx`).
    /// Deep South playback passes `ballad` itself — see `deepSouthSpeakVoice`.
    public func defaultSpeakVoice(language: String) -> String {
        let folded = SpanishTranslatorAPI.normalizeLocaleID(language)
        if SpanishTranslatorAPI.localePrimary(folded) == "en" {
            return SpanishTranslatorAPI.californiaSpeakVoice
        }
        return defaultSpeakVoice
    }

    public var dialectHint: String {
        switch self {
        case .jobsite: return "cuban_florida_jobsite"
        case .clean: return "cuban_florida_clean"
        }
    }

    public static func parse(_ raw: String?) -> SpanishVoiceMode {
        let folded = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if folded == "clean" || folded == "polished" || folded == "a" { return .clean }
        return .jobsite
    }
}

/// Which way Spanish Translator runs. English → Spanish stays the default.
public enum SpanishTranslateDirection: String, CaseIterable, Codable, Sendable {
    case englishToSpanish
    case spanishToEnglish

    public static let storageKey = "spanishTranslator.direction"

    public var uiLabel: String {
        switch self {
        case .englishToSpanish: return "English → Spanish"
        case .spanishToEnglish: return "Spanish → English"
        }
    }

    /// BCP-47-ish tag sent as `sourceLanguage`.
    public var sourceLanguage: String {
        switch self {
        case .englishToSpanish: return "en"
        case .spanishToEnglish: return "es"
        }
    }

    /// BCP-47-ish tag sent as `targetLanguage`.
    public var targetLanguage: String {
        switch self {
        case .englishToSpanish: return "es"
        case .spanishToEnglish: return "en"
        }
    }

    /// `/api/speak` `language` and the Apple fallback voice family.
    public var speakLanguage: String { targetLanguage }

    public var listensInSpanish: Bool { self == .spanishToEnglish }

    public static func parse(_ raw: String?) -> SpanishTranslateDirection {
        let folded = (raw ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
        switch folded {
        case "spanishtoenglish", "es-en", "es→en", "reverse", "spanish-to-english":
            return .spanishToEnglish
        default:
            return .englishToSpanish
        }
    }
}

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
    /// Crew line from a newer translate payload. Nil when the field is missing or blank.
    public var personaLine: String?
    /// Crew id from a newer translate payload. Nil when the field is missing or blank.
    public var personaCrew: String?

    public init(
        translation: String,
        dialect: String = "cuban_florida_latam",
        sourceText: String = "",
        sourceLanguage: String = "en",
        targetLanguage: String = "es",
        provider: String = "",
        model: String = "",
        notes: String = "",
        engine: String = "beckify",
        personaLine: String? = nil,
        personaCrew: String? = nil
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
        self.personaLine = personaLine
        self.personaCrew = personaCrew
    }

    /// Result language for chrome. English when `targetLanguage` is en / en-*.
    public var resultLanguageLabel: String {
        let target = targetLanguage
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
        if target == "en" || target.hasPrefix("en-") { return "English" }
        return "Spanish"
    }

    public var displayDialect: String {
        let folded = dialect.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let lang = resultLanguageLabel
        if folded.contains("clean") || folded.contains("polish") {
            return "\(lang) · Clean"
        }
        if folded.contains("jobsite") || folded.contains("smartass") || folded.contains("smart-ass") {
            return "\(lang) · Jobsite"
        }
        if engine == "apple" { return "On-device \(lang) (Apple)" }
        if dialect.isEmpty { return lang }
        // Never surface geographic dialect branding in UI.
        if folded.contains("cuba") || folded.contains("florida") || folded.contains("miami")
            || folded.contains("latam") || folded.contains("latin") {
            return lang
        }
        return lang
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
    /// gpt-4o-mini-tts male voice for California English.
    public static let californiaSpeakVoice = "echo"
    /// gpt-4o-mini-tts storyteller voice for Deep South English. Not `echo`.
    public static let deepSouthSpeakVoice = "ballad"
    /// `/api/speak` voiceMode for the Deep South character. English words only.
    public static let deepSouthDelivery = "deepSouth"
    public static let maxSourceCharacters = 2000

    /// Common English jobsite lines for one-tap translate → speak on the Beckify AI path.
    public static let quickTranslatePhrases: [String] = [
        "Where's the breaker?",
        "Kill the power.",
        "That's live — don't touch it.",
        "Hand me that conduit.",
        "We need more wire.",
        "Move the ladder.",
        "Watch your head.",
        "Hold this for a second.",
        "Who left this mess?",
        "Lunch break.",
        "Let's wrap it up.",
        "Can you hear me up there?",
    ]

    /// Spanish jobsite lines for one-tap translate → English speak. Same count and jobs as the English chips.
    /// Natural Cuban / Florida LatAm field speech — not Castilian textbook.
    public static let quickSpanishTranslatePhrases: [String] = [
        "¿Dónde está el breaker?",
        "Corta la corriente.",
        "Eso está vivo — no lo toques.",
        "Pásame ese conduit.",
        "Falta alambre.",
        "Mueve la escalera.",
        "Cuidado con la cabeza.",
        "Agárrame esto un segundo.",
        "¿Quién dejó este relajo?",
        "Vamos a almorzar.",
        "Ya vámonos, a recoger.",
        "¿Me oyes allá arriba?",
    ]

    public static func quickPhrases(direction: SpanishTranslateDirection) -> [String] {
        switch direction {
        case .englishToSpanish: return quickTranslatePhrases
        case .spanishToEnglish: return quickSpanishTranslatePhrases
        }
    }

    /// Short English attention seeds for the prominent Hey! / Get attention button.
    /// Beckify AI rewrite (Clean vs Jobsite) + `/api/speak` produce the spoken Spanish —
    /// Jobsite tends toward oye / mira / espérate energy; Clean stays polite and polished.
    /// UI labels stay generic ("Hey!", "Get attention") — no dialect branding.
    public static let attentionCallPhrases: [String] = [
        "Hey!",
        "Look!",
        "Hold up!",
        "Wait a second!",
        "Hey — over here!",
        "Look over here!",
    ]

    /// Chrome label for the attention-getter control (never dialect / geography).
    public static let attentionButtonTitle = "Hey!"
    public static let attentionButtonAccessibilityLabel = "Get attention"
    public static let attentionButtonHelp =
        "One tap — translate + speak a short attention call (Clean or Jobsite)."

    /// Shown instead of Hey! when the direction is Spanish → English.
    public static let reverseAttentionHelp =
        "Hey! is for English → Spanish. This way, speak or type Spanish and you’ll hear English."

    /// Rotating test pool (same lines as quick chips). Avoids immediate repeat when possible.
    public static func nextRandomTestPhrase(excluding previous: String? = nil) -> String {
        nextRandomTestPhrase(direction: .englishToSpanish, excluding: previous)
    }

    public static func nextRandomTestPhrase(
        direction: SpanishTranslateDirection,
        excluding previous: String? = nil
    ) -> String {
        let fallback = direction == .spanishToEnglish ? "Hola." : "Hello."
        return nextRotatingPhrase(
            from: quickPhrases(direction: direction),
            excluding: previous,
            fallback: fallback
        )
    }

    /// Rotating attention-call English seed for one-tap translate → speak.
    public static func nextAttentionCallPhrase(excluding previous: String? = nil) -> String {
        nextRotatingPhrase(from: attentionCallPhrases, excluding: previous, fallback: "Hey!")
    }

    private static func nextRotatingPhrase(
        from pool: [String],
        excluding previous: String?,
        fallback: String
    ) -> String {
        guard !pool.isEmpty else { return fallback }
        if pool.count == 1 { return pool[0] }
        let prior = (previous ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var pick = pool.randomElement() ?? pool[0]
        var guardCount = 0
        while pick == prior, guardCount < 8 {
            pick = pool.randomElement() ?? pool[0]
            guardCount += 1
        }
        return pick
    }

    public static let disclaimer =
        "Speech stays on this device for recognition. English → Spanish is the default. Beckify AI offers Clean or Jobsite wording via api.beckify.com. Pick who you are talking with — Bodie Hale, Tito Solano, Junie Pell, Pearl, or Sloane Merritt — and that person rewrites the line into their own wording while the meaning stays. Their 16-bit sprite stays on screen, swapping idle and talk frames while audio plays. Hey! is a short attention call on English → Spanish only. If translate is unreachable, the app falls back to on-device Apple Translation on iOS 18+ in the same direction. Translation text uploads only when the Beckify path runs. Loud playback sends the short line to api.beckify.com/api/speak with that person's voice (model eleven_v3). Apple AVSpeech is the fallback if cloud TTS fails. Copy Audio and Share Audio use that clip. Free to use. Not a certified interpreter."

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
        voiceMode: SpanishVoiceMode = .jobsite,
        voice: String? = nil,
        format: String = "mp3",
        language: String = "",
        delivery: String? = nil,
        crew: CrewTalkMember? = nil
    ) -> [String: Any] {
        if let crew {
            var resolvedLanguage = language.trimmingCharacters(in: .whitespacesAndNewlines)
            if resolvedLanguage.isEmpty { resolvedLanguage = crew.speakLanguage }
            var body: [String: Any] = [
                "task": "speak",
                "text": text,
                "voice": crew.voiceID,
                "model": CrewTalkMember.speakModel,
                "format": format,
                "language": resolvedLanguage,
                "voiceMode": voiceMode.apiValue,
                "mode": voiceMode.apiValue,
            ]
            if crew == .juniePell {
                body["stability"] = CrewTalkMember.junieSpeakStability
                body["similarity_boost"] = CrewTalkMember.junieSpeakSimilarity
                body["style"] = CrewTalkMember.junieSpeakStyle
                body["speed"] = CrewTalkMember.junieSpeakSpeed
            }
            return body
        }
        let passedVoice = (voice ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var resolvedLanguage = language.trimmingCharacters(in: .whitespacesAndNewlines)
        if resolvedLanguage.isEmpty { resolvedLanguage = "es" }
        let foldedDelivery = (delivery ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
        let isDeepSouth = foldedDelivery == "deepsouth"
        if isDeepSouth { resolvedLanguage = "en" }
        let modeValue = isDeepSouth ? deepSouthDelivery : voiceMode.apiValue
        let resolvedVoice: String
        if isDeepSouth {
            resolvedVoice = deepSouthSpeakVoice
        } else if !passedVoice.isEmpty {
            resolvedVoice = passedVoice
        } else {
            resolvedVoice = voiceMode.defaultSpeakVoice(language: resolvedLanguage)
        }
        return [
            "task": "speak",
            "text": text,
            "voice": resolvedVoice,
            "format": format,
            "language": resolvedLanguage,
            "voiceMode": modeValue,
            "mode": modeValue,
        ]
    }

    public static func speakRequestJSON(
        text: String,
        voiceMode: SpanishVoiceMode = .jobsite,
        voice: String? = nil,
        format: String = "mp3",
        language: String = "",
        delivery: String? = nil,
        crew: CrewTalkMember? = nil
    ) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: speakRequestBody(
                text: text,
                voiceMode: voiceMode,
                voice: voice,
                format: format,
                language: language,
                delivery: delivery,
                crew: crew
            ),
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
        targetLanguage: String = "es",
        voiceMode: SpanishVoiceMode = .jobsite,
        crew: CrewTalkMember? = nil
    ) -> [String: Any] {
        var body: [String: Any] = [
            "task": task,
            "text": text,
            "sourceText": text,
            "sourceLanguage": sourceLanguage,
            "targetLanguage": targetLanguage,
            "dialect": voiceMode.dialectHint,
            "voiceMode": voiceMode.apiValue,
            "mode": voiceMode.apiValue,
        ]
        // Spanish -> English: the server renders the meaning in this helper's voice.
        if let crew, crew.speakLanguage == "en" { body["crew"] = crew.rawValue }
        return body
    }

    /// English line shown and spoken for Spanish -> English: the server's in-character
    /// rendering when present, else the plain translation. Never a canned stock line.
    public static func englishResultLine(draft: SpanishTranslationDraft, crew: CrewTalkMember) -> String {
        if crew.speakLanguage == "en",
           let persona = draft.personaLine?.trimmingCharacters(in: .whitespacesAndNewlines),
           !persona.isEmpty {
            return persona
        }
        return draft.translation
    }

    public static func requestJSON(
        text: String,
        sourceLanguage: String = "en",
        targetLanguage: String = "es",
        voiceMode: SpanishVoiceMode = .jobsite,
        crew: CrewTalkMember? = nil
    ) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: requestBody(
                text: text,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                voiceMode: voiceMode,
                crew: crew
            ),
            options: []
        )
    }

    /// The register to request from `/api/translate` when `crew` will voice the result.
    /// The Jobsite prompt is Cuban and requires hard profanity on every line, which is
    /// Tito's character. Lupita is Mexican Spanish with no heavy profanity, so her
    /// unmatched lines ask for the clean register instead.
    public static func translateVoiceMode(requested: SpanishVoiceMode, crew: CrewTalkMember) -> SpanishVoiceMode {
        crew == .lupitaReyes ? .clean : requested
    }

    /// The `fallback` slot for the dock and Speak while the person has typed a line but
    /// no translation exists yet. A Spanish voice must never be handed the raw typed
    /// English, so its fallback stays empty until Spanish arrives.
    public static func dockFallbackLine(crew: CrewTalkMember, typed: String) -> String {
        crew.speakLanguage == "es" ? "" : typed
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

    /// Preferred Apple Translation Spanish identifiers (LatAm / Florida-relevant first).
    public static let preferredAppleSpanishLanguageIDs: [String] = [
        "es-MX",
        "es-US",
        "es-419",
        "es",
    ]

    /// Preferred Apple Translation English identifiers for Spanish → English.
    public static let preferredAppleEnglishLanguageIDs: [String] = [
        "en-US",
        "en",
        "en-GB",
    ]

    /// Source/target candidates for an on-device `TranslationSession` in `direction`.
    /// First entry of each list is the default if nothing is installed.
    public static func appleTranslationCandidates(
        direction: SpanishTranslateDirection
    ) -> (sources: [String], targets: [String]) {
        switch direction {
        case .englishToSpanish:
            return (["en"], preferredAppleSpanishLanguageIDs)
        case .spanishToEnglish:
            return (preferredAppleSpanishLanguageIDs, preferredAppleEnglishLanguageIDs)
        }
    }

    public static func appleOnDeviceDraft(
        translation: String,
        sourceText: String,
        targetLanguageID: String = "es",
        sourceLanguageID: String = "en"
    ) -> SpanishTranslationDraft {
        let target = targetLanguageID.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = sourceLanguageID.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetEnglish = target.lowercased().hasPrefix("en")
        return SpanishTranslationDraft(
            translation: translation.trimmingCharacters(in: .whitespacesAndNewlines),
            dialect: targetEnglish ? "apple_on_device_en" : "apple_on_device_es",
            sourceText: sourceText,
            sourceLanguage: source.isEmpty ? (targetEnglish ? "es" : "en") : source,
            targetLanguage: target.isEmpty ? (targetEnglish ? "en" : "es") : target,
            provider: "apple",
            model: "TranslationSession",
            notes: targetEnglish
                ? "On-device Apple Translation. Generic English — not the Beckify AI Clean/Jobsite cloud rewrite."
                : "On-device Apple Translation. Generic Spanish — not the Beckify AI Clean/Jobsite cloud rewrite.",
            engine: "apple"
        )
    }

    /// Network / HTTP failures that should trigger on-device fallback.
    /// Recoverable: transport (0), missing route (404/405), timeout (408), rate limit (429), and 5xx.
    /// Not recoverable on device: bad payload (400), auth (401/403), and oversize (413).
    /// Any other non-2xx still falls back. 2xx does not.
    public static func shouldAttemptOnDeviceFallback(httpStatus: Int) -> Bool {
        if (200..<300).contains(httpStatus) { return false }
        switch httpStatus {
        case 0, 404, 405, 408, 429:
            return true
        case 400, 401, 403, 413:
            return false
        default:
            return true
        }
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
            engine: "beckify",
            personaLine: stringValue(object["personaLine"]),
            personaCrew: stringValue(object["personaCrew"])
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
    public static let jobsitePitchMultiplier: Float = 0.86

    /// Device voices cannot reproduce the cloud voice's rasp; keep the fallback intelligible.
    public static func speechRateFactor(voiceMode: SpanishVoiceMode) -> Float {
        voiceMode == .jobsite ? jobsiteSpeechRateFactor : 0.94
    }

    public static func speechPitchMultiplier(voiceMode: SpanishVoiceMode) -> Float {
        voiceMode == .jobsite ? jobsitePitchMultiplier : 1.0
    }

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

    /// Preferred `AVSpeechSynthesisVoice.language` codes for English playback, best first.
    public static let preferredEnglishVoiceLanguages: [String] = [
        "en-US",
        "en-GB",
        "en-AU",
        "en-CA",
        "en",
    ]

    public static func englishVoiceScore(language: String) -> Int {
        let folded = normalizeLocaleID(language)
        guard localePrimary(folded) == "en" else { return -1 }
        for (index, preferred) in preferredEnglishVoiceLanguages.enumerated() {
            if folded == preferred.lowercased() {
                return 1000 - index
            }
        }
        if folded.hasPrefix("en-us") { return 999 }
        if folded.hasPrefix("en-gb") { return 900 }
        if folded.hasPrefix("en-") { return 500 }
        if folded == "en" { return 100 }
        return 50
    }

    public static func bestEnglishVoiceLanguage(from languages: [String]) -> String? {
        let ranked = languages
            .map { ($0, englishVoiceScore(language: $0)) }
            .filter { $0.1 >= 0 }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0 < rhs.0
            }
        return ranked.first?.0
    }

    /// Male + en-US first, same shape as `jobsiteVoiceScore` for Spanish.
    public static func englishPlaybackVoiceScore(language: String, genderRaw: Int, qualityRaw: Int) -> Int {
        let locale = englishVoiceScore(language: language)
        guard locale >= 0 else { return -1 }
        let genderBonus: Int
        switch genderRaw {
        case 1: genderBonus = 5000
        case 0: genderBonus = 1000
        default: genderBonus = 0
        }
        return genderBonus + locale * 10 + max(0, qualityRaw)
    }

    public static func englishVoiceFallbackNote(
        selectedLanguage: String?,
        genderLabel: String? = nil,
        voiceName: String? = nil
    ) -> String {
        let lang = (selectedLanguage ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if lang.isEmpty {
            return "No English system voice found for Apple fallback. Install an English voice in Settings → Accessibility → Spoken Content → Voices. Prefers neural crew speech from api.beckify.com/api/speak."
        }
        let gender = (genderLabel ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let name = (voiceName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let who = name.isEmpty ? lang : "\(name) (\(lang))"
        let sex: String
        if gender == "male" {
            sex = "male"
        } else if gender == "female" {
            sex = "female"
        } else {
            sex = "system"
        }
        let folded = normalizeLocaleID(lang)
        let localeNote = folded.hasPrefix("en-us") ? "en-US" : folded
        return "Apple fallback: \(who), \(sex), \(localeNote). Prefers the selected crew voice from api.beckify.com when reachable. Device voices approximate pace only."
    }

    public static func normalizeLocaleID(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
    }

    public static func localePrimary(_ raw: String) -> String {
        let folded = normalizeLocaleID(raw)
        return folded.split(separator: "-").first.map(String.init) ?? folded
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

    /// Preferred on-device Speech locales for Spanish → English (es-US, then es-MX, then es, then other Spanish).
    public static let preferredSpanishSpeechLocales: [String] = [
        "es-US",
        "es-MX",
        "es",
        "es-419",
        "es-CO",
        "es-AR",
        "es-CL",
        "es-PE",
        "es-VE",
        "es-ES",
    ]

    public static let preferredEnglishSpeechLocales: [String] = [
        "en-US",
        "en-GB",
        "en-AU",
        "en",
    ]

    public static func speechLocaleCandidates(direction: SpanishTranslateDirection) -> [String] {
        switch direction {
        case .englishToSpanish: return preferredEnglishSpeechLocales
        case .spanishToEnglish: return preferredSpanishSpeechLocales
        }
    }

    /// Best installed Speech locale for `direction`, or nil when that language is not available.
    /// `available` is typically `SFSpeechRecognizer.supportedLocales()` identifiers (`es-US` or `es_US`).
    public static func bestSpeechLocale(direction: SpanishTranslateDirection, available: [String]) -> String? {
        let prefix = direction.listensInSpanish ? "es" : "en"
        let matches = available.filter { localePrimary($0) == prefix }
        guard !matches.isEmpty else { return nil }
        for candidate in speechLocaleCandidates(direction: direction) {
            let wanted = normalizeLocaleID(candidate)
            if let exact = matches.first(where: { normalizeLocaleID($0) == wanted }) {
                return exact
            }
        }
        return matches.sorted { lhs, rhs in
            let l = direction.listensInSpanish
                ? spanishVoiceScore(language: lhs)
                : englishVoiceScore(language: lhs)
            let r = direction.listensInSpanish
                ? spanishVoiceScore(language: rhs)
                : englishVoiceScore(language: rhs)
            if l != r { return l > r }
            return lhs < rhs
        }.first
    }

    public static func speechUnavailableMessage(direction: SpanishTranslateDirection) -> String {
        if direction.listensInSpanish {
            return "Spanish speech recognition isn’t available on this device. Type the Spanish, or add a Spanish dictation language in Settings."
        }
        return "English speech recognition is not available on this device right now."
    }

    public static func emptySourceMessage(direction: SpanishTranslateDirection) -> String {
        if direction.listensInSpanish {
            return "Say or type something in Spanish first."
        }
        return "Say or type something in English first."
    }

    public static func modeHelp(direction: SpanishTranslateDirection, voiceMode: SpanishVoiceMode) -> String {
        let register = voiceMode == .clean
            ? "Clean keeps the wording polished and warm. Jobsite keeps it direct on a noisy site."
            : "Jobsite keeps the wording direct on a noisy site. Clean keeps it polished and warm."
        if direction.listensInSpanish {
            return register + " Who speaks is the person you pick."
        }
        return register + " Who speaks is the person you pick."
    }

    /// Dialect flavor for the selected person. Not the dock Speak string.
    /// English crew rewrites English. Tito rewrites into jobsite Spanish.
    public static func lineForCrew(
        crew: CrewTalkMember,
        english: String,
        spanish: String,
        fallback: String
    ) -> String {
        let englishLine = english.trimmingCharacters(in: .whitespacesAndNewlines)
        let spanishLine = spanish.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackLine = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        let source: String
        if crew.speakLanguage == "es" {
            if !englishLine.isEmpty { source = englishLine }
            else if !spanishLine.isEmpty { source = spanishLine }
            else { source = fallbackLine }
        } else if !englishLine.isEmpty {
            source = englishLine
        } else if !fallbackLine.isEmpty {
            source = fallbackLine
        } else {
            source = spanishLine
        }
        return CrewDialectRewrite.rewrite(crew: crew, raw: source)
    }

    /// Dock Speak string: the other language for the active direction.
    /// A matching Cuban/Mexican template is the Spanish result. Unmatched Tito
    /// (empty rewrite, A2) uses the API Spanish, then fallback — never "".
    /// Bodie/Junie/Pearl/Sloane show the translated other-language line.
    public static func spokenAnswerForDock(
        crew: CrewTalkMember,
        direction: SpanishTranslateDirection,
        english: String,
        spanish: String,
        fallback: String
    ) -> String {
        let englishLine = english.trimmingCharacters(in: .whitespacesAndNewlines)
        let spanishLine = spanish.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackLine = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        if crew.speakLanguage == "es" {
            let rewrite = lineForCrew(crew: crew, english: englishLine, spanish: spanishLine, fallback: fallbackLine)
            if !rewrite.isEmpty { return rewrite }
            if !spanishLine.isEmpty { return spanishLine }
            return fallbackLine
        }
        if direction.listensInSpanish {
            if !englishLine.isEmpty { return englishLine }
            if !fallbackLine.isEmpty { return fallbackLine }
            return spanishLine
        }
        if !spanishLine.isEmpty { return spanishLine }
        if !fallbackLine.isEmpty { return fallbackLine }
        return englishLine
    }

    /// Short dialect flavor under the dock answer. Empty for Tito (rewrite is the answer).
    public static func dialectHelperLine(
        crew: CrewTalkMember,
        direction: SpanishTranslateDirection,
        english: String,
        spanish: String,
        fallback: String
    ) -> String {
        if crew.speakLanguage == "es" { return "" }
        // Spanish -> English: the main line is already in character (server). No
        // local template / stock line underneath it.
        if direction.listensInSpanish { return "" }
        let flavor = lineForCrew(crew: crew, english: english, spanish: spanish, fallback: fallback)
        let spoken = spokenAnswerForDock(
            crew: crew,
            direction: direction,
            english: english,
            spanish: spanish,
            fallback: fallback
        )
        if flavor.isEmpty || flavor == spoken { return "" }
        return flavor
    }

    /// What Speak must say: the dialect / other-language / rewritten line on screen.
    /// Never the raw text field. English helpers speak their rewrite even when the
    /// dock's big line is still the typed sentence (translation not back yet).
    public static func lineToSpeak(
        crew: CrewTalkMember,
        direction: SpanishTranslateDirection,
        english: String,
        spanish: String,
        fallback: String
    ) -> String {
        // Spanish -> English: the Spanish speaker's words must come out as the
        // translated English line. The persona rephrase stays on screen only;
        // speaking it replaced the translation with a canned helper line
        // ("...easy does it", "when you have a moment...").
        if direction.listensInSpanish && crew.speakLanguage != "es" {
            let englishLine = english.trimmingCharacters(in: .whitespacesAndNewlines)
            if !englishLine.isEmpty { return englishLine }
        }
        let helper = dialectHelperLine(
            crew: crew,
            direction: direction,
            english: english,
            spanish: spanish,
            fallback: fallback
        )
        if !helper.isEmpty { return helper }
        let dock = spokenAnswerForDock(
            crew: crew,
            direction: direction,
            english: english,
            spanish: spanish,
            fallback: fallback
        )
        let rewrite = lineForCrew(crew: crew, english: english, spanish: spanish, fallback: fallback)
        let source = (direction.listensInSpanish ? spanish : english)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let dockTrim = dock.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rewrite.isEmpty {
            let rewriteIsRaw = !source.isEmpty && rewrite.compare(source, options: .caseInsensitive) == .orderedSame
            let dockIsRaw = dockTrim.isEmpty || (!source.isEmpty && dockTrim.compare(source, options: .caseInsensitive) == .orderedSame)
            if dockIsRaw && !rewriteIsRaw { return rewrite }
        }
        if !dockTrim.isEmpty { return dockTrim }
        if !rewrite.isEmpty { return rewrite }
        // A2: Tito and Lupita have no template for unmatched text. Speak the API
        // Spanish, else the fallback, so Speak is not handed "" after a successful translate.
        if crew.speakLanguage == "es" {
            let spanishLine = spanish.trimmingCharacters(in: .whitespacesAndNewlines)
            if !spanishLine.isEmpty { return spanishLine }
            let fallbackLine = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
            if !fallbackLine.isEmpty { return fallbackLine }
        }
        return rewrite
    }

    /// What to do once a draft is applied. `.speak` leaves `.translating`.
    /// `.ready` is the empty-text escape so translate cannot stick.
    public enum FinishSpeak: Equatable, Sendable {
        case speak(String)
        case ready
    }

    /// Prefer the dock/speak line. If that is empty, speak `draftTranslation`.
    /// If both are empty, finish `.ready` instead of staying in translating.
    public static func finishSpeakAfterDraft(
        crew: CrewTalkMember,
        direction: SpanishTranslateDirection,
        english: String,
        spanish: String,
        draftTranslation: String
    ) -> FinishSpeak {
        var spoken = lineToSpeak(
            crew: crew,
            direction: direction,
            english: english,
            spanish: spanish,
            fallback: draftTranslation
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        if spoken.isEmpty {
            spoken = draftTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        spoken = clampSpeakText(spoken)
        if spoken.isEmpty { return .ready }
        return .speak(spoken)
    }

    /// BCP-47 language for `lineToSpeak`. English rewrites stay English even when
    /// the direction's other language is Spanish. Tito stays Spanish.
    public static func speakLanguageForLineToSpeak(
        crew: CrewTalkMember,
        direction: SpanishTranslateDirection,
        english: String,
        spanish: String,
        fallback: String
    ) -> String {
        if crew.speakLanguage == "es" { return "es" }
        let line = lineToSpeak(
            crew: crew,
            direction: direction,
            english: english,
            spanish: spanish,
            fallback: fallback
        )
        let spanishLine = spanish.trimmingCharacters(in: .whitespacesAndNewlines)
        if !spanishLine.isEmpty && line.compare(spanishLine, options: .caseInsensitive) == .orderedSame {
            return "es"
        }
        return "en"
    }

    /// BCP-47 language Speak should use for the dock string.
    public static func speakLanguageForDirection(_ direction: SpanishTranslateDirection) -> String {
        direction.targetLanguage.hasPrefix("en") ? "en" : "es"
    }

    /// Pearl speaks the same ask in warm, convincing English. She does not scold and does not drop the request.
    public static func pearlWarmRewrite(_ raw: String) -> String {
        CrewDialectRewrite.rewrite(crew: .pearl, raw: raw)
    }

    /// Sloane speaks as a polished HR lead. Blunt or hostile English still leaves as meeting-speak.
    /// Jargon rotates. The original insult is not echoed.
    public static func sloaneCorporateRewrite(_ raw: String) -> String {
        CrewDialectRewrite.rewrite(crew: .sloaneMerritt, raw: raw)
    }

    public static func junieDialectRewrite(_ raw: String) -> String {
        CrewDialectRewrite.rewrite(crew: .juniePell, raw: raw)
    }

    public static func bodieDialectRewrite(_ raw: String) -> String {
        CrewDialectRewrite.rewrite(crew: .bodieHale, raw: raw)
    }

    /// Strips ElevenLabs laugh tags for anything a person reads or Apple speaks.
    public static func displayText(_ raw: String) -> String {
        CrewDialectRewrite.displayText(raw)
    }

    public static func titoDialectRewrite(_ raw: String) -> String {
        CrewDialectRewrite.rewrite(crew: .titoSolano, raw: raw)
    }

    /// Shown on the Deep South card. Same English words, different neural character.
    public static let deepSouthCardTitle = "Deep South"
    public static let deepSouthHelp =
        "English only. Speaks this English as Deep South — not California. Same words, not a rewrite. Copy Audio and Share Audio keep that clip."
    public static let deepSouthButtonTitle = "Speak Deep South"

    public static func statusHelp(direction: SpanishTranslateDirection) -> String {
        if direction.listensInSpanish {
            return "Spanish in → English out. Clean or Jobsite. Apple Translation is the offline fallback."
        }
        return "English in → Spanish out. Clean or Jobsite. Hey! for attention. Apple Translation is the offline fallback."
    }

    public static func playbackHelp(direction: SpanishTranslateDirection) -> String {
        if direction.listensInSpanish {
            return "Speak plays English audio. Cloud TTS first; Apple voice if that fails."
        }
        return "Speak plays Spanish audio. Cloud TTS first; Apple voice if that fails."
    }

    public static func quickLinesHelp(direction: SpanishTranslateDirection) -> String {
        if direction.listensInSpanish {
            return "Tap a chip to fill Spanish and run Beckify AI translate + English speak on the selected mode."
        }
        return "Tap a chip to fill English and run Beckify AI translate + speak on the selected mode."
    }

    public static func typedPlaceholder(direction: SpanishTranslateDirection) -> String {
        direction.listensInSpanish ? "Or type Spanish here" : "Or type English here"
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


    public static func neuralVoiceNote(
        model: String = "gpt-4o-mini-tts",
        voice: String = "",
        voiceMode: SpanishVoiceMode = .jobsite,
        language: String = "es",
        delivery: String? = nil,
        crew: CrewTalkMember? = nil
    ) -> String {
        if let crew {
            let shown = model.trimmingCharacters(in: .whitespacesAndNewlines)
            let modelLabel = shown.isEmpty ? CrewTalkMember.speakModel : shown
            return "Neural TTS · \(crew.displayName) · \(modelLabel) · max speaker volume"
        }
        let m = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let v = voice.trimmingCharacters(in: .whitespacesAndNewlines)
        let foldedDelivery = (delivery ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
        if foldedDelivery == "deepsouth" {
            let voiceLabel = v.isEmpty ? deepSouthSpeakVoice : v
            let modelLabel = m.isEmpty ? "gpt-4o-mini-tts" : m
            return "Neural TTS · \(voiceLabel) · \(modelLabel) · Deep South · max speaker volume"
        }
        let fallbackVoice = voiceMode.defaultSpeakVoice(language: language)
        let label = [v.isEmpty ? fallbackVoice : v, m.isEmpty ? "gpt-4o-mini-tts" : m].joined(separator: " · ")
        let register = voiceMode == .clean ? "Clean" : "Jobsite"
        let folded = normalizeLocaleID(language)
        let accent: String
        if localePrimary(folded) == "en" {
            accent = voiceMode == .jobsite ? " · California, loud" : " · California"
        } else {
            accent = voiceMode == .jobsite ? " · gravelly, weathered tradesman" : ""
        }
        return "Neural TTS · \(label) · \(register)\(accent) · max speaker volume"
    }

    /// Legacy alias — prefer `statusPreparingVoice` / `stillPreparingVoiceStatus(elapsedSeconds:)`.
    public static let preparingAudioStatus = statusPreparingVoice

    /// Distinct turn phases for Spanish Translator chrome (PR1 visible states).
    public static let statusReady = "Ready"
    public static let statusListening = "Listening"
    public static let statusListeningSpanish = "Listening · Spanish"
    public static let statusFinishingTranscript = "Finishing transcript"
    public static let statusTranslating = "Translating"
    public static let statusPreparingVoice = "Preparing voice…"
    public static let statusPlaying = "Playing"
    public static let statusCancelled = "Cancelled"
    public static let statusFailed = "Failed"
    public static let cancelActionTitle = "Cancel"
    public static let stopActionTitle = "Stop"
    public static let speakNowDeviceVoiceTitle = "Speak now with device voice"

    /// After ~3s of voice prep, show elapsed seconds (no fake %).
    public static let preparingVoiceLongThresholdSeconds = 3

    public static func stillPreparingVoiceStatus(elapsedSeconds: Int) -> String {
        let secs = max(0, elapsedSeconds)
        return "Still preparing your voice… \(secs)s"
    }

    public static func preparingVoiceStatus(elapsedSeconds: Int) -> String {
        if elapsedSeconds >= preparingVoiceLongThresholdSeconds {
            return stillPreparingVoiceStatus(elapsedSeconds: elapsedSeconds)
        }
        return statusPreparingVoice
    }

    public static func voiceFallbackNote(
        selectedLanguage: String?,
        genderLabel: String? = nil,
        voiceName: String? = nil
    ) -> String {
        let lang = (selectedLanguage ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if lang.isEmpty {
            return "No Spanish system voice found for Apple fallback. Install a Spanish voice in Settings → Accessibility → Spoken Content → Voices. Prefers neural crew speech from api.beckify.com/api/speak."
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
            localeNote = "es-US"
        } else if folded.hasPrefix("es-mx") {
            localeNote = "es-MX"
        } else if folded.hasPrefix("es-es") {
            localeNote = "es-ES — prefer es-US or es-MX if available"
        } else {
            localeNote = "closest Spanish"
        }
        return "Apple fallback: \(who), \(sex), \(localeNote). Prefers neural crew speech from api.beckify.com when reachable; this note is the on-device fallback path."
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
