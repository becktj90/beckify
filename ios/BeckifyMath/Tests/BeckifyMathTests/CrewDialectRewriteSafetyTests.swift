import XCTest
@testable import BeckifyMath

/// WP-102. A template must not flip polarity, negation, or question-ness,
/// and keyword hits are whole words on folded text.
final class CrewDialectRewriteSafetyTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // These tests pin exact Tito templates; TitoVoiceVarietyTests covers the variety layer.
        TitoVoiceVariety.isEnabled = false
    }

    override func tearDown() {
        TitoVoiceVariety.isEnabled = true
        super.tearDown()
    }

    private let unsafePower = [
        "Turn the power back on",
        "Don't kill the power",
        "Is the power off?",
        "Never cut the power while I'm up here",
        "Prende la corriente",
    ]

    private let deenergize = #"\b(kill|kills|killed|killing|cut|cuts|cutting|corta|corte|cortes|corten|cortar|apaga|apagar|desconecta|desconectar|disconnect|disconnects|off|mata|matar)\b"#

    func testUnsafePowerLinesDoNotBecomeDeenergize() {
        for sample in unsafePower {
            XCTAssertNil(CrewRewriteGuard.intent(sample), sample)
            for crew in CrewTalkMember.allCases {
                let line = CrewDialectRewrite.rewrite(crew: crew, raw: sample)
                let folded = CrewDialectRewrite.fold(line)
                XCTAssertNil(
                    folded.range(of: deenergize, options: .regularExpression),
                    "\(crew) deenergize verb in \(line) for \(sample)"
                )
            }
        }
    }

    func testWordBoundaryDoesNotHitHeadRacksOrHold() {
        let samples = [
            "Go ahead and start",
            "overhead",
            "track",
            "crack",
            "Household",
        ]
        let banned = #"\b(head|cabeza|rack|racks|hold)\b"#
        for sample in samples {
            let intent = CrewRewriteGuard.intent(sample)
            XCTAssertEqual(intent, .free, sample)
            XCTAssertNotEqual(intent, .head, sample)
            XCTAssertNotEqual(intent, .racks, sample)
            XCTAssertNotEqual(intent, .hold, sample)
            for crew in CrewTalkMember.allCases {
                let folded = CrewDialectRewrite.fold(CrewDialectRewrite.rewrite(crew: crew, raw: sample))
                XCTAssertNil(
                    folded.range(of: banned, options: .regularExpression),
                    "\(crew) hit a banned word in \(folded) for \(sample)"
                )
            }
        }
    }

    /// A2: unmatched Tito text is empty so the caller speaks the translation.
    func testTitoFreeTextReturnsEmpty() {
        let english = "Bring the drill to the truck"
        let spanish = "Trae el taladro al camión."
        XCTAssertEqual(CrewDialectRewrite.tito(english), "")
        XCTAssertEqual(CrewRewriteGuard.intent(english), .free)
        XCTAssertEqual(
            SpanishTranslatorAPI.spokenAnswerForDock(
                crew: .titoSolano,
                direction: .englishToSpanish,
                english: english,
                spanish: spanish,
                fallback: english
            ),
            spanish
        )
        XCTAssertEqual(
            SpanishTranslatorAPI.lineToSpeak(
                crew: .titoSolano,
                direction: .englishToSpanish,
                english: english,
                spanish: spanish,
                fallback: english
            ),
            spanish
        )
        let finish = SpanishTranslatorAPI.finishSpeakAfterDraft(
            crew: .titoSolano,
            direction: .englishToSpanish,
            english: english,
            spanish: spanish,
            draftTranslation: spanish
        )
        XCTAssertEqual(finish, .speak(spanish))
        XCTAssertNotEqual(finish, .ready)
    }

    func testEnglishUnmatchedKeepsShortOpenerWithoutRawGlue() {
        let raw = "Bring the drill to the truck"
        let line = CrewDialectRewrite.bodie(raw)
        XCTAssertFalse(line.isEmpty)
        XCTAssertTrue(line.lowercased().contains("drill"), line)
        XCTAssertFalse(CrewDialectRewrite.fold(line).contains(CrewDialectRewrite.fold(raw)), line)
        XCTAssertTrue(CrewRewriteGuard.isConsistent(translation: raw, persona: line))
    }

    func testCutPowerStillRequiresDeenergizePolarity() {
        XCTAssertEqual(CrewRewriteGuard.intent("Kill the power"), .cutPower)
        XCTAssertEqual(CrewRewriteGuard.intent("Corta la corriente"), .cutPower)
        XCTAssertEqual(CrewRewriteGuard.intent("Turn the power off"), .cutPower)
        XCTAssertNil(CrewRewriteGuard.intent("Turn the power back on"))
        XCTAssertNil(CrewRewriteGuard.intent("Hold this breaker"))
        XCTAssertNil(
            CrewRewriteGuard.intent("please cut the power at the far left side of the building now")
        )
    }

    func testIsConsistentChecksPolarityNegationAndQuestion() {
        let cut = "Please cut the power, and let's stay clear of it."
        XCTAssertTrue(CrewRewriteGuard.isConsistent(translation: "Kill the power.", persona: cut))
        XCTAssertTrue(CrewRewriteGuard.isConsistent(
            translation: "Corta la corriente.",
            persona: "¡Coño, corta esa pinga de corriente ahora mismo, carajo!"
        ))
        XCTAssertTrue(CrewRewriteGuard.isConsistent(
            translation: "Kill the power.",
            persona: "That power needs to come off, bless your heart. Don't get your knickers in a knot."
        ))
        XCTAssertFalse(CrewRewriteGuard.isConsistent(translation: "Don't kill the power", persona: cut))
        XCTAssertFalse(CrewRewriteGuard.isConsistent(translation: "Is the power off?", persona: cut))
        XCTAssertFalse(CrewRewriteGuard.isConsistent(translation: "Turn the power back on", persona: cut))
        XCTAssertFalse(CrewRewriteGuard.isConsistent(
            translation: "Prende la corriente",
            persona: "¡Coño, corta esa pinga de corriente ahora mismo, carajo!"
        ))
    }

    func testSlurScrubStillDropsTheSlur() {
        let line = CrewDialectRewrite.tito("you spic kill the power")
        XCTAssertFalse(line.lowercased().contains("spic"), line)
        XCTAssertTrue(line.lowercased().contains("corriente"), line)
        XCTAssertFalse(line.lowercased().contains("fuck"))
    }

    func testLupitaKeepsTheAskWithoutHeavyProfanity() {
        XCTAssertTrue(CrewTalkMember.lupitaReyes.isReleased)
        let cut = CrewDialectRewrite.lupita("Kill the power.")
        XCTAssertTrue(cut.lowercased().contains("corriente"), cut)
        XCTAssertFalse(cut.contains("?"), cut)
        let heavy = ["coño", "carajo", "mierda", "pinga", "joder", "cabrón", "puta", "fuck"]
        XCTAssertTrue(cut.lowercased().contains("no manches") || cut.lowercased().contains("chin"), cut)
        for word in heavy {
            XCTAssertFalse(cut.lowercased().contains(word), word)
        }
        let rejected = CrewDialectRewrite.lupita("Don't kill the power")
        XCTAssertFalse(rejected.lowercased().contains("corriente"), rejected)
        XCTAssertFalse(rejected.lowercased().contains("corta"), rejected)
        let samples = [
            ("Hand me that conduit.", "conduit"),
            ("Move the ladder.", "escalera"),
            ("Watch your head.", "cabeza"),
            ("We need more wire.", "cable"),
            ("Someone left this mess.", "desorden"),
        ]
        for (raw, ask) in samples {
            let line = CrewDialectRewrite.lupita(raw)
            XCTAssertTrue(line.lowercased().contains(ask), "\(raw) -> \(line)")
            for word in heavy {
                XCTAssertFalse(line.lowercased().contains(word), "\(word) in \(line)")
            }
        }
    }

    func testHumbertoIsPolishedCaracasSpanishAndCourteousEnglish() {
        let crude = ["coño", "carajo", "mierda", "pinga", "verga", "cabrón", "arrech", "fuck", "shit", "asere", "güey"]
        let rejected = CrewDialectRewrite.humberto("Don't kill the power")
        XCTAssertFalse(rejected.lowercased().contains("corte"), rejected)
        XCTAssertEqual(CrewDialectRewrite.humberto("Can you explain the load calc for panel B tomorrow"), "")
        let samples = [
            ("Kill the power.", "corriente", "power"),
            ("Hand me that conduit.", "conduit", "conduit"),
            ("Move the ladder.", "escalera", "ladder"),
            ("Watch your head.", "cabeza", "head"),
            ("We need more wire.", "cable", "wire"),
            ("Someone left this mess.", "desorden", "mess"),
        ]
        for (raw, es, en) in samples {
            let spanish = CrewDialectRewrite.humberto(raw).lowercased()
            let english = CrewDialectRewrite.humbertoEnglish(raw).lowercased()
            XCTAssertTrue(spanish.contains(es), "\(raw) -> \(spanish)")
            XCTAssertTrue(english.contains(en), "\(raw) -> \(english)")
            XCTAssertTrue((Self.humbertoMarkers + ["cuidado"]).contains { spanish.contains($0) }, spanish)
            XCTAssertTrue(["please", "my friend", "with all respect", "careful"].contains { english.contains($0) }, english)
            for word in crude {
                XCTAssertFalse(spanish.contains(word), "\(word) in \(spanish)")
                XCTAssertFalse(english.contains(word), "\(word) in \(english)")
            }
        }
    }
    static let titoMarkers = ["asere", "acere", "qué bolá", "qué vola", "chico", "mi hermano", "pinga", "cojones",
                              "coño", "me cago en", "singao", "comemierda", "candela", "jeva", "fula", "guagua",
                              "jamar", "pinchando", "tremendo", "oyiste", "dale"]
    static let humbertoMarkers = ["mi estimado", "caballero", "con todo respeto", "hágame el favor", "por favor",
                                  "chamo", "pana", "chévere", "vale", "me explico", "si dios quiere", "a la orden",
                                  "epa", "bueno pues"]

    private func hasMarker(_ line: String, _ markers: [String]) -> Bool {
        let l = line.lowercased()
        return markers.contains { m in
            l.range(of: "\\b" + NSRegularExpression.escapedPattern(for: m) + "\\b", options: .regularExpression) != nil
        }
    }

    func testGoldenBringMoreWire() {
        XCTAssertEqual(CrewDialectRewrite.tito("Bring more wire."), "¡Asere, tráeme más cable, coño! ¿Qué tú haces parado ahí, comemierda? ¡Dale, que esto no se hace solo, me cago en tu madre!")
        XCTAssertEqual(CrewDialectRewrite.tito("We need more wire."), "¡Asere, tráeme más cable, coño! ¿Qué tú haces parado ahí, comemierda? ¡Dale, que esto no se hace solo, me cago en tu madre!")
        XCTAssertEqual(CrewDialectRewrite.humberto("We need more wire."), "Mi estimado, hágame el favor de traerme un poquito más de cable. Gracias, caballero.")
    }

    func testTitoAndHumbertoNeverBorrowEachOthersWords() {
        let asks = ["Kill the power.", "Hand me that conduit.", "Move the ladder.", "Watch your head.", "We need more wire.",
                    "Who left this mess?", "Leave the breaker alone.", "Clean those racks.", "Hold this.", "Nice work.",
                    "Stop talking and get that feeder in before lunch", "hola"]
        var titoCount = 0, humbertoCount = 0
        for ask in asks {
            let tito = CrewDialectRewrite.tito(ask)
            if !tito.isEmpty {
                titoCount += 1
                XCTAssertTrue(hasMarker(tito, Self.titoMarkers), "Tito lacks Cuban marker: \(tito)")
                XCTAssertFalse(hasMarker(tito, Self.humbertoMarkers), "Tito used Humberto's words: \(tito)")
            }
            let humberto = CrewDialectRewrite.humberto(ask)
            if !humberto.isEmpty {
                humbertoCount += 1
                XCTAssertTrue(hasMarker(humberto, Self.humbertoMarkers), "Humberto lacks Caracas marker: \(humberto)")
                XCTAssertFalse(hasMarker(humberto, Self.titoMarkers), "Humberto used Tito's words: \(humberto)")
            }
        }
        XCTAssertGreaterThan(titoCount, 5)
        XCTAssertGreaterThan(humbertoCount, 5)
        for opener in TitoVoiceVariety.openers {
            XCTAssertFalse(hasMarker(opener, Self.humbertoMarkers), "Tito opener uses Humberto's words: \(opener)")
        }
    }
    /// Tito insults the person and his work, never a group. Spanish and English slur terms.
    static let groupSlurs = ["maricón", "maricon", "marica", "pato", "negro", "negra", "chino", "china", "sudaca",
                             "mongólico", "retrasado", "judío", "faggot", "fag", "nigger", "nigga", "chink", "spic",
                             "retard", "kike", "wetback", "dyke", "tranny"]

    func testTitoNeverUsesGroupSlurs() {
        let asks = ["Kill the power.", "Hand me that conduit.", "Move the ladder.", "Watch your head.", "Bring more wire.",
                    "We need more wire.", "Who left this mess?", "Leave the breaker alone.", "Clean those racks.",
                    "Hold this.", "Nice work.", "Stop talking and get that feeder in before lunch", "hola",
                    "you faggot kill the power", "move the ladder you spic", "corta la corriente"]
        var lines = asks.map { CrewDialectRewrite.tito($0) }
        lines += TitoVoiceVariety.openers
        lines += asks.map { TitoVoiceVariety.vary("¡Oye, coño! " + CrewDialectRewrite.tito($0), previousKeptOye: true).line }
        for line in lines where !line.isEmpty {
            for slur in Self.groupSlurs {
                XCTAssertFalse(hasMarker(line, [slur]), "group slur \(slur) in Tito line: \(line)")
            }
        }
        // Still heavy: personal insults land on the listener.
        let heavy = ["comemierda", "cabrón", "hijo de puta", "singao", "guanajo", "estúpido", "mamalanga", "me cago en"]
        XCTAssertTrue(heavy.contains { CrewDialectRewrite.tito("Bring more wire.").lowercased().contains($0) })
    }
}
