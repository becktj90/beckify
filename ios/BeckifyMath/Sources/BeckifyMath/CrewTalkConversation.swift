import Foundation

/// Conversation Mode and device linking. Two people, two languages, one translator each.
///
/// Each person picks a character who speaks *their own* language, so they hear the
/// other person's words in a familiar voice: Spanish listeners get Tito or Lupita,
/// English listeners get Bodie, Junie, Pearl, or Sloane. Pure logic only, so it runs
/// under `swift test` on Linux.
public enum CrewTalkConversationLanguage: String, CaseIterable, Codable, Sendable {
    case english = "en"
    case spanish = "es"

    public var other: CrewTalkConversationLanguage {
        self == .english ? .spanish : .english
    }

    /// Label shown on the person's side of the screen.
    public var label: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        }
    }

    /// Direction when this person is the one speaking.
    public var speakingDirection: SpanishTranslateDirection {
        switch self {
        case .english: return .englishToSpanish
        case .spanish: return .spanishToEnglish
        }
    }

    /// Characters who speak this language, for the person who *listens* in it.
    public var roster: [CrewTalkMember] {
        switch self {
        case .english: return CrewTalkMember.roster(for: .spanishToEnglish)
        case .spanish: return CrewTalkMember.roster(for: .englishToSpanish)
        }
    }

    public var defaultCrew: CrewTalkMember {
        switch self {
        case .english: return CrewTalkMember.defaultMember(for: .spanishToEnglish)
        case .spanish: return CrewTalkMember.defaultMember(for: .englishToSpanish)
        }
    }

    /// `en`, `en-US`, `es_MX`, and so on. Anything else is nil.
    public static func parse(_ raw: String?) -> CrewTalkConversationLanguage? {
        let folded = (raw ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
        let primary = folded.split(separator: "-").first.map(String.init) ?? ""
        return CrewTalkConversationLanguage(rawValue: primary)
    }

    /// The character must speak this language. Anything else snaps to the default.
    public func resolvedCrew(_ crew: CrewTalkMember?) -> CrewTalkMember {
        if let crew, roster.contains(crew) { return crew }
        return defaultCrew
    }
}

/// What the listener sees and hears for one translated line.
public struct CrewTalkConversationLines: Equatable, Sendable {
    /// On-screen text, without laugh tags.
    public var display: String
    /// The string sent to `/api/speak`. Clamped to the speak limit.
    public var speak: String

    public init(display: String, speak: String) {
        self.display = display
        self.speak = speak
    }
}

public enum CrewTalkConversation {
    /// Build the listener's line from the speaker's words and the API translation.
    /// The listener's character does the dialect rewrite, exactly as on the main Crew Talk screen.
    public static func lines(
        sourceText: String,
        translation: String,
        from speakerLanguage: CrewTalkConversationLanguage,
        listenerCrew: CrewTalkMember
    ) -> CrewTalkConversationLines {
        let source = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let translated = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        let crew = speakerLanguage.other.resolvedCrew(listenerCrew)
        let direction = speakerLanguage.speakingDirection
        let english = speakerLanguage == .english ? source : translated
        let spanish = speakerLanguage == .english ? translated : source

        let shown = SpanishTranslatorAPI.spokenAnswerForDock(
            crew: crew,
            direction: direction,
            english: english,
            spanish: spanish,
            fallback: translated
        )
        let spoken = SpanishTranslatorAPI.lineToSpeak(
            crew: crew,
            direction: direction,
            english: english,
            spanish: spanish,
            fallback: translated
        )
        let display = SpanishTranslatorAPI.displayText(shown)
        let speakLine = spoken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? translated : spoken
        return CrewTalkConversationLines(
            display: display.isEmpty ? SpanishTranslatorAPI.displayText(translated) : display,
            speak: SpanishTranslatorAPI.clampSpeakText(speakLine)
        )
    }
}

/// One side of the conversation.
public struct CrewTalkSeat: Equatable, Sendable {
    public var language: CrewTalkConversationLanguage
    public var crew: CrewTalkMember

    public init(language: CrewTalkConversationLanguage, crew: CrewTalkMember? = nil) {
        self.language = language
        self.crew = language.resolvedCrew(crew)
    }
}

/// Two people sharing one phone. Seat 0 speaks English, seat 1 speaks Spanish.
/// The listener's character voices each line, then the turn passes.
public struct CrewTalkLocalConversation: Equatable, Sendable {
    public private(set) var seats: [CrewTalkSeat]
    public private(set) var speakerIndex: Int

    public init(englishCrew: CrewTalkMember? = nil, spanishCrew: CrewTalkMember? = nil) {
        self.seats = [
            CrewTalkSeat(language: .english, crew: englishCrew),
            CrewTalkSeat(language: .spanish, crew: spanishCrew),
        ]
        self.speakerIndex = 0
    }

    public var speaker: CrewTalkSeat { seats[speakerIndex] }
    public var listener: CrewTalkSeat { seats[1 - speakerIndex] }

    /// Returns false when the character does not speak that seat's language.
    @discardableResult
    public mutating func setCrew(_ crew: CrewTalkMember, forSeat index: Int) -> Bool {
        guard seats.indices.contains(index), seats[index].language.roster.contains(crew) else {
            return false
        }
        seats[index].crew = crew
        return true
    }

    public mutating func passTurn() {
        speakerIndex = 1 - speakerIndex
    }

    public mutating func giveTurn(to index: Int) {
        guard seats.indices.contains(index) else { return }
        speakerIndex = index
    }
}

/// Short pairing codes. The alphabet drops 0/O and 1/I so a code is easy to read aloud.
public enum CrewTalkRoomCode {
    public static let length = 6

    public static func normalize(_ raw: String) -> String {
        String(raw.uppercased().filter { $0.isLetter || $0.isNumber })
    }

    public static func isComplete(_ raw: String) -> Bool {
        normalize(raw).count == length
    }
}

/// Events from `GET /api/rooms/:code/events`. One JSON object per `data:` line.
public enum CrewTalkRoomEvent: Equatable, Sendable {
    case ready(partnerLanguage: CrewTalkConversationLanguage?, partnerOnline: Bool)
    case peer(language: CrewTalkConversationLanguage, online: Bool)
    case message(id: String, language: CrewTalkConversationLanguage, text: String)
    case closed

    /// Returns nil for comments (`: ping`), blank lines, and anything malformed.
    public static func parse(sseLine: String) -> CrewTalkRoomEvent? {
        let line = sseLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard line.hasPrefix("data:") else { return nil }
        let json = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
        guard let data = json.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let kind = object["t"] as? String else {
            return nil
        }
        let language = CrewTalkConversationLanguage.parse(object["language"] as? String)
        switch kind {
        case "ready":
            let partner = CrewTalkConversationLanguage.parse(object["partnerLanguage"] as? String)
            return .ready(partnerLanguage: partner, partnerOnline: (object["partnerOnline"] as? Bool) ?? false)
        case "peer":
            guard let language else { return nil }
            return .peer(language: language, online: (object["online"] as? Bool) ?? false)
        case "message":
            guard let language,
                  let id = object["id"] as? String,
                  let text = object["text"] as? String,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return .message(id: id, language: language, text: text)
        case "closed":
            return .closed
        default:
            return nil
        }
    }
}

/// JSON bodies for the room routes.
public enum CrewTalkRoomAPI {
    public static let roomsPath = "/api/rooms"

    public static func path(code: String, action: String) -> String {
        "\(roomsPath)/\(CrewTalkRoomCode.normalize(code))/\(action)"
    }

    public static func languageBody(_ language: CrewTalkConversationLanguage) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["language": language.rawValue], options: [.sortedKeys])
    }

    public static func messageBody(pid: String, text: String) throws -> Data {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return try JSONSerialization.data(
            withJSONObject: ["pid": pid, "text": SpanishTranslatorAPI.clampSpeakText(trimmed)],
            options: [.sortedKeys]
        )
    }

    public static func leaveBody(pid: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["pid": pid], options: [.sortedKeys])
    }
}
