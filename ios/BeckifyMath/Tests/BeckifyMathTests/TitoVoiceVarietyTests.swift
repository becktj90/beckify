import XCTest
@testable import BeckifyMath

final class TitoVoiceVarietyTests: XCTestCase {
    override func setUp() {
        super.setUp()
        TitoVoiceVariety.isEnabled = true
        TitoVoiceVariety.resetHistory()
    }

    private func corpus(_ n: Int) -> [String] {
        (0..<n).map { "¡Oye, coño! Pásame el cable número \($0), carajo." }
    }

    func testOyeConoIsRareAndNeverBackToBack() {
        var keptPrev = false
        var kept = 0
        for line in corpus(200) {
            let out = TitoVoiceVariety.apply(line)
            let display = CrewDialectRewrite.displayText(out)
            let isOye = TitoVoiceVariety.startsWithOyeCono(display)
            XCTAssertFalse(isOye && keptPrev, "back-to-back oye coño: \(out)")
            if isOye { kept += 1 }
            keptPrev = isOye
        }
        XCTAssertLessThan(kept, 60, "oye coño should be rare, got \(kept)/200")
    }

    func testReplacedOpenerKeepsProfanityAndAsk() {
        for line in corpus(50) {
            let out = CrewDialectRewrite.displayText(TitoVoiceVariety.vary(line, previousKeptOye: true).line)
            XCTAssertFalse(TitoVoiceVariety.startsWithOyeCono(out))
            XCTAssertTrue(out.contains("Pásame el cable"), out)
            XCTAssertTrue(out.contains("carajo"), out)
        }
    }

    func testOpenersVary() {
        let outs = Set(corpus(100).map {
            String(CrewDialectRewrite.displayText(TitoVoiceVariety.vary($0, previousKeptOye: true).line).prefix(8))
        })
        XCTAssertGreaterThan(outs.count, 6)
    }

    func testNonverbalRoughlyOneInFive() {
        let tagged = corpus(300).filter { TitoVoiceVariety.vary($0, previousKeptOye: false).line.contains("[") }.count
        XCTAssertGreaterThan(tagged, 25)
        XCTAssertLessThan(tagged, 110)
    }

    func testTagsStrippedForDisplay() {
        XCTAssertEqual(CrewDialectRewrite.displayText("[coughs] ¡Mira, asere! Corta eso."), "¡Mira, asere! Corta eso.")
        XCTAssertEqual(CrewDialectRewrite.displayText("[clears throat] Dale, papo, sube."), "Dale, papo, sube.")
        for line in corpus(100) {
            let out = TitoVoiceVariety.vary(line, previousKeptOye: false).line
            XCTAssertFalse(CrewDialectRewrite.displayText(out).contains("["))
        }
    }

    func testSameLineIsStable() {
        let a = TitoVoiceVariety.apply("¡Oye, coño! Baja esa escalera.")
        let b = TitoVoiceVariety.apply("¡Oye, coño! Baja esa escalera.")
        XCTAssertEqual(a, b)
    }

    func testDockAndSpeakAgreeForTito() {
        let spanish = "¡Oye, coño! Revisa ese tablero, carajo."
        let dock = SpanishTranslatorAPI.spokenAnswerForDock(crew: .titoSolano, direction: .englishToSpanish, english: "", spanish: spanish, fallback: spanish)
        let speak = SpanishTranslatorAPI.lineToSpeak(crew: .titoSolano, direction: .englishToSpanish, english: "", spanish: spanish, fallback: spanish)
        XCTAssertEqual(CrewDialectRewrite.displayText(dock), CrewDialectRewrite.displayText(speak))
    }

    func testDisabledPassesThrough() {
        TitoVoiceVariety.isEnabled = false
        defer { TitoVoiceVariety.isEnabled = true }
        XCTAssertEqual(TitoVoiceVariety.apply("¡Oye, coño! Ya."), "¡Oye, coño! Ya.")
    }
}
