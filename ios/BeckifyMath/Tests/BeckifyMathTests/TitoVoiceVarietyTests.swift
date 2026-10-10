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
            XCTAssertTrue(out.lowercased().contains("pásame el cable"), out)
            XCTAssertTrue(out.contains("carajo"), out)
        }
    }

    func testOpenersVary() {
        let outs = Set(corpus(100).map {
            String(CrewDialectRewrite.displayText(TitoVoiceVariety.vary($0, previousKeptOye: true).line).prefix(8))
        })
        XCTAssertGreaterThan(outs.count, 6)
    }

    private func tags(_ line: String) -> [Range<String.Index>] {
        var out: [Range<String.Index>] = []
        var start = line.startIndex
        while let r = line.range(of: #"\[[^\]]{1,24}\]"#, options: .regularExpression, range: start..<line.endIndex) {
            out.append(r); start = r.upperBound
        }
        return out
    }

    func testSmokersCoughRoughlyOneInThreeAtPausesMaxTwo() {
        let lines = (0..<300).map { "¡Asere, pásame el cable \($0), coño! Dale, comemierda. Que esto no se hace solo." }
        let outs = lines.map { TitoVoiceVariety.vary($0, previousKeptOye: false).line }
        let tagged = outs.filter { !tags($0).isEmpty }
        XCTAssertGreaterThan(tagged.count, 70, "about 1 in 3")
        XCTAssertLessThan(tagged.count, 130, "about 1 in 3")
        XCTAssertTrue(outs.contains { tags($0).count == 2 }, "some lines get a second cough")
        let allowed: Set<String> = ["[coughs]", "[clears throat]", "[coughs heavily]", "[wheezes]"]
        for out in tagged {
            let found = tags(out)
            XCTAssertLessThanOrEqual(found.count, 2, out)
            for r in found {
                XCTAssertTrue(allowed.contains(String(out[r])), out)
                if r.lowerBound != out.startIndex {
                    let before = out[..<r.lowerBound].trimmingCharacters(in: .whitespaces)
                    XCTAssertTrue(".!?".contains(before.last ?? " "), "tag not at a pause: \(out)")
                }
            }
            XCTAssertEqual(CrewDialectRewrite.displayText(out), CrewDialectRewrite.displayText(out).replacingOccurrences(of: "[", with: ""))
        }
        let mostlyPlain = tagged.flatMap { o in tags(o).map { String(o[$0]) } }
        let common = mostlyPlain.filter { $0 == "[coughs]" || $0 == "[clears throat]" }.count
        XCTAssertGreaterThan(common * 2, mostlyPlain.count, "mostly [coughs] / [clears throat]")
    }

    func testTagsStrippedForDisplay() {
        XCTAssertEqual(CrewDialectRewrite.displayText("[coughs] ¡Mira, asere! Corta eso."), "¡Mira, asere! Corta eso.")
        XCTAssertEqual(CrewDialectRewrite.displayText("[clears throat] Dale, papo, sube."), "Dale, papo, sube.")
        XCTAssertEqual(CrewDialectRewrite.displayText("¡Asere, coño! [coughs heavily] Dale. [wheezes] Ya."), "¡Asere, coño! Dale. Ya.")
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
