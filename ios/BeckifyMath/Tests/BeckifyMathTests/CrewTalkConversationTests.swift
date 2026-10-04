import XCTest
@testable import BeckifyMath

final class CrewTalkConversationTests: XCTestCase {
    func testRostersFollowTheListenersLanguage() {
        XCTAssertEqual(Set(CrewTalkConversationLanguage.spanish.roster), [.titoSolano, .lupitaReyes])
        XCTAssertEqual(
            Set(CrewTalkConversationLanguage.english.roster),
            [.bodieHale, .juniePell, .pearl, .sloaneMerritt]
        )
        for language in CrewTalkConversationLanguage.allCases {
            for crew in language.roster {
                XCTAssertEqual(crew.speakLanguage, language.rawValue, crew.rawValue)
            }
            XCTAssertTrue(language.roster.contains(language.defaultCrew))
        }
    }

    func testResolvedCrewSnapsToTheLanguage() {
        XCTAssertEqual(CrewTalkConversationLanguage.spanish.resolvedCrew(.pearl), .titoSolano)
        XCTAssertEqual(CrewTalkConversationLanguage.english.resolvedCrew(.titoSolano), .bodieHale)
        XCTAssertEqual(CrewTalkConversationLanguage.spanish.resolvedCrew(.lupitaReyes), .lupitaReyes)
        XCTAssertEqual(CrewTalkConversationLanguage.english.resolvedCrew(nil), .bodieHale)
    }

    func testParseAndDirection() {
        XCTAssertEqual(CrewTalkConversationLanguage.parse("en-US"), .english)
        XCTAssertEqual(CrewTalkConversationLanguage.parse("ES_mx"), .spanish)
        XCTAssertNil(CrewTalkConversationLanguage.parse("ja"))
        XCTAssertNil(CrewTalkConversationLanguage.parse(nil))
        XCTAssertEqual(CrewTalkConversationLanguage.english.speakingDirection, .englishToSpanish)
        XCTAssertEqual(CrewTalkConversationLanguage.spanish.speakingDirection, .spanishToEnglish)
        XCTAssertEqual(CrewTalkConversationLanguage.english.other, .spanish)
    }

    func testLinesAreNeverEmptyForARealTranslation() {
        for crew in CrewTalkConversationLanguage.spanish.roster {
            let lines = CrewTalkConversation.lines(
                sourceText: "Kill the power.",
                translation: "Corta la corriente.",
                from: .english,
                listenerCrew: crew
            )
            XCTAssertFalse(lines.display.isEmpty, crew.rawValue)
            XCTAssertFalse(lines.speak.isEmpty, crew.rawValue)
            XCTAssertLessThanOrEqual(lines.speak.count, SpanishTranslatorAPI.maxSpeakCharacters)
        }
        for crew in CrewTalkConversationLanguage.english.roster {
            let lines = CrewTalkConversation.lines(
                sourceText: "Corta la corriente.",
                translation: "Kill the power.",
                from: .spanish,
                listenerCrew: crew
            )
            XCTAssertFalse(lines.display.isEmpty, crew.rawValue)
            XCTAssertFalse(lines.speak.isEmpty, crew.rawValue)
        }
    }

    func testWrongLanguageCrewIsCorrectedNotSpoken() {
        // Pearl speaks English. A Spanish listener must never get her voice.
        let lines = CrewTalkConversation.lines(
            sourceText: "Where is the breaker?",
            translation: "¿Dónde está el breaker?",
            from: .english,
            listenerCrew: .pearl
        )
        XCTAssertFalse(lines.speak.isEmpty)
    }

    func testLocalConversationTurnsAndSeats() {
        var talk = CrewTalkLocalConversation()
        XCTAssertEqual(talk.speaker.language, .english)
        XCTAssertEqual(talk.listener.language, .spanish)
        XCTAssertEqual(talk.listener.crew, .titoSolano)
        XCTAssertEqual(talk.speaker.crew, .bodieHale)

        XCTAssertTrue(talk.setCrew(.lupitaReyes, forSeat: 1))
        XCTAssertFalse(talk.setCrew(.pearl, forSeat: 1), "English character on the Spanish seat")
        XCTAssertFalse(talk.setCrew(.titoSolano, forSeat: 0), "Spanish character on the English seat")
        XCTAssertFalse(talk.setCrew(.pearl, forSeat: 5))
        XCTAssertEqual(talk.seats[1].crew, .lupitaReyes)

        talk.passTurn()
        XCTAssertEqual(talk.speaker.language, .spanish)
        XCTAssertEqual(talk.listener.language, .english)
        talk.passTurn()
        XCTAssertEqual(talk.speaker.language, .english)
        talk.giveTurn(to: 1)
        XCTAssertEqual(talk.speakerIndex, 1)
        talk.giveTurn(to: 9)
        XCTAssertEqual(talk.speakerIndex, 1)
    }

    func testRoomCodes() {
        XCTAssertEqual(CrewTalkRoomCode.normalize(" ab-c 123 "), "ABC123")
        XCTAssertTrue(CrewTalkRoomCode.isComplete("abc 123"))
        XCTAssertFalse(CrewTalkRoomCode.isComplete("abc12"))
    }

    func testRoomEventParsing() {
        XCTAssertEqual(
            CrewTalkRoomEvent.parse(sseLine: #"data: {"t":"ready","partnerLanguage":"en","partnerOnline":true}"#),
            .ready(partnerLanguage: .english, partnerOnline: true)
        )
        XCTAssertEqual(
            CrewTalkRoomEvent.parse(sseLine: #"data: {"t":"ready","partnerLanguage":null,"partnerOnline":false}"#),
            .ready(partnerLanguage: nil, partnerOnline: false)
        )
        XCTAssertEqual(
            CrewTalkRoomEvent.parse(sseLine: #"data: {"t":"peer","language":"es","online":false}"#),
            .peer(language: .spanish, online: false)
        )
        XCTAssertEqual(
            CrewTalkRoomEvent.parse(sseLine: #"data: {"t":"message","id":"ab12","language":"en","text":"Hold this."}"#),
            .message(id: "ab12", language: .english, text: "Hold this.")
        )
        XCTAssertEqual(CrewTalkRoomEvent.parse(sseLine: #"data: {"t":"closed"}"#), .closed)

        XCTAssertNil(CrewTalkRoomEvent.parse(sseLine: ": ping"))
        XCTAssertNil(CrewTalkRoomEvent.parse(sseLine: ""))
        XCTAssertNil(CrewTalkRoomEvent.parse(sseLine: "data: not json"))
        XCTAssertNil(CrewTalkRoomEvent.parse(sseLine: #"data: {"t":"message","id":"x","language":"fr","text":"hi"}"#))
        XCTAssertNil(CrewTalkRoomEvent.parse(sseLine: #"data: {"t":"message","id":"x","language":"en","text":"  "}"#))
        XCTAssertNil(CrewTalkRoomEvent.parse(sseLine: #"data: {"t":"unknown"}"#))
    }

    func testRoomRequestBodies() throws {
        let create = try JSONSerialization.jsonObject(with: CrewTalkRoomAPI.languageBody(.spanish)) as? [String: String]
        XCTAssertEqual(create, ["language": "es"])
        XCTAssertEqual(CrewTalkRoomAPI.path(code: "ab-c123", action: "join"), "/api/rooms/ABC123/join")
        let message = try JSONSerialization.jsonObject(
            with: CrewTalkRoomAPI.messageBody(pid: "p1", text: "  hola  ")
        ) as? [String: String]
        XCTAssertEqual(message, ["pid": "p1", "text": "hola"])
    }
}
