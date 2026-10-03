import XCTest
@testable import BeckifyMath

/// WP-102. A template must not flip polarity, negation, or question-ness,
/// and keyword hits are whole words on folded text.
final class CrewDialectRewriteSafetyTests: XCTestCase {
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

}
