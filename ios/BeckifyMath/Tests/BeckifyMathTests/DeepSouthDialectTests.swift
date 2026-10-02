import XCTest
@testable import BeckifyMath

final class DeepSouthDialectTests: XCTestCase {
    func testEmptyInputReturnsUnchanged() {
        XCTAssertEqual(DeepSouthDialect.stylize(""), "")
        XCTAssertEqual(DeepSouthDialect.stylize("   "), "   ")
    }

    func testPhraseSwapWinsOverWordSwap() {
        let result = DeepSouthDialect.stylize("You are going to love this.", seed: 0)
        XCTAssertTrue(result.contains("fixin' to"), "expected phrase swap in: \(result)")
        XCTAssertFalse(result.contains("going to"), "should not leave the original phrase in: \(result)")
    }

    func testCapitalizedWordKeepsCapitalization() {
        let result = DeepSouthDialect.stylize("You need help.", seed: 0)
        XCTAssertTrue(result.hasPrefix("Y'all"), "expected capitalized swap, got: \(result)")
    }

    func testLowercaseWordStaysLowercase() {
        let result = DeepSouthDialect.stylize("I think you need help.", seed: 0)
        XCTAssertTrue(result.contains("reckon"), "expected 'think' -> 'reckon' in: \(result)")
    }

    func testContractionSwap() {
        let result = DeepSouthDialect.stylize("That isn't right.", seed: 0)
        XCTAssertTrue(result.contains("ain't"), "expected isn't -> ain't in: \(result)")
    }

    func testTrailingGDrop() {
        let result = DeepSouthDialect.stylize("We are working hard.", seed: 0)
        XCTAssertTrue(result.contains("workin'"), "expected working -> workin' in: \(result)")
    }

    /// A 3-letter-stem minimum would silently skip common short "-ing" words.
    func testTrailingGDropCatchesShortStems() {
        XCTAssertTrue(DeepSouthDialect.stylize("We are doing fine.", seed: 0).contains("doin'"))
        XCTAssertTrue(DeepSouthDialect.stylize("He is being rude.", seed: 0).contains("bein'"))
    }

    func testWordBoundaryDoesNotMangleLongerWords() {
        // "willingly" must not be partially caught by the "will" rule
        // (-> "gonna"), and must not be caught by the -ing dropper either
        // (it doesn't end in "ing" at a word boundary).
        let result = DeepSouthDialect.stylize("She agreed willingly.", seed: 0)
        XCTAssertFalse(result.contains("gonna"), "the word 'willingly' should not partially match 'will': \(result)")
        XCTAssertTrue(result.contains("willingly"), "willingly should pass through unchanged: \(result)")
    }

    /// A longer overlapping phrase must win over a shorter one that is also
    /// a substring of it, regardless of which is listed first in source.
    func testLongerOverlappingPhraseWinsRegardlessOfListOrder() {
        let result = DeepSouthDialect.stylize("I am going to fix the panel.", seed: 0)
        XCTAssertTrue(result.contains("I'm fixin' to"), "expected the longer phrase rule to win: \(result)")
    }

    /// A replacement that happens to contain another rule's source word
    /// (e.g. "fast" -> "...a hot tin roof") must not have that inserted text
    /// re-matched and mangled by the other rule — everything is matched
    /// against the original text in one pass.
    func testReplacementTextIsNotReScannedByOtherRules() {
        let result = DeepSouthDialect.stylize("That is fast.", seed: 0)
        XCTAssertTrue(result.contains("quick as a cat on a hot tin roof"), "expected the literal reference text unmangled: \(result)")
        XCTAssertFalse(result.contains("hotter than"), "the 'hot' inside fast's reference text must not be re-matched: \(result)")
    }

    /// Combined terminal punctuation (e.g. "?!") must be fully stripped, not
    /// just the last character, before the closer is appended.
    func testCombinedTrailingPunctuationIsFullyStripped() {
        let result = DeepSouthDialect.stylize("Really?!", seed: 0)
        XCTAssertFalse(result.contains("?,"), "should not leave a '?' before the inserted comma: \(result)")
        XCTAssertFalse(result.contains("!,"), "should not leave a '!' before the inserted comma: \(result)")
    }

    func testSameInputAndSeedIsDeterministic() {
        let a = DeepSouthDialect.stylize("Where is the breaker?", seed: 3)
        let b = DeepSouthDialect.stylize("Where is the breaker?", seed: 3)
        XCTAssertEqual(a, b)
    }

    func testDifferentSeedsCanProduceDifferentClosers() {
        let outputs = Set((0..<6).map { DeepSouthDialect.stylize("Hello there.", seed: $0) })
        XCTAssertGreaterThan(outputs.count, 1, "expected at least some variety across seeds")
    }

    func testEndingPunctuationIsNotDoubled() {
        let result = DeepSouthDialect.stylize("That is hot.", seed: 0)
        XCTAssertFalse(result.contains(". ,"), "should not double up punctuation: \(result)")
        XCTAssertFalse(result.contains(".."), "should not double up periods: \(result)")
    }

    func testAlwaysEndsWithOneOfTheClosers() {
        for seed in 0..<6 {
            let result = DeepSouthDialect.stylize("Hand me that wire.", seed: seed)
            XCTAssertTrue(result.hasSuffix("."), "expected the result to end with a period: \(result)")
        }
    }
}
