import XCTest
@testable import BeckifyMath

final class NumberBaseConvertTests: XCTestCase {
    func testDecimalToAllBases() throws {
        let result = try NumberBaseConvert.parse("202", from: .decimal)

        XCTAssertEqual(result.value, 202)
        XCTAssertEqual(result.binary, "11001010")
        XCTAssertEqual(result.octal, "312")
        XCTAssertEqual(result.decimal, "202")
        XCTAssertEqual(result.hexadecimal, "CA")
    }

    func testHexWithPrefixParses() throws {
        let result = try NumberBaseConvert.parse("0xCA", from: .hexadecimal)
        XCTAssertEqual(result.value, 202)
    }

    func testBinaryWithPrefixParses() throws {
        let result = try NumberBaseConvert.parse("0b11001010", from: .binary)
        XCTAssertEqual(result.value, 202)
    }

    func testOctalWithPrefixParses() throws {
        let result = try NumberBaseConvert.parse("0o312", from: .octal)
        XCTAssertEqual(result.value, 202)
    }

    func testCaseInsensitiveHex() throws {
        XCTAssertEqual(try NumberBaseConvert.parse("ca", from: .hexadecimal).value, 202)
        XCTAssertEqual(try NumberBaseConvert.parse("CA", from: .hexadecimal).value, 202)
    }

    func testZeroRoundTrips() throws {
        let result = try NumberBaseConvert.parse("0", from: .decimal)
        XCTAssertEqual(result.binary, "0")
        XCTAssertEqual(result.hexadecimal, "0")
    }

    /// 0xFF as an 8-bit signed value is -1; as 16-bit it's still +255.
    func testSignedInterpretationAtEachWidth() throws {
        let result = try NumberBaseConvert.parse("FF", from: .hexadecimal)

        XCTAssertEqual(result.signed8, -1)
        XCTAssertEqual(result.signed16, 255)
        XCTAssertEqual(result.signed32, 255)
    }

    /// 0x8000 as 16-bit signed is the minimum 16-bit value, -32768.
    func testSixteenBitSignBitFlips() throws {
        let result = try NumberBaseConvert.parse("8000", from: .hexadecimal)
        XCTAssertEqual(result.signed16, -32768)
        XCTAssertEqual(result.signed32, 32768)
    }

    func testInvalidDigitForBaseThrows() {
        XCTAssertThrowsError(try NumberBaseConvert.parse("102", from: .binary))
        XCTAssertThrowsError(try NumberBaseConvert.parse("XYZ", from: .hexadecimal))
        XCTAssertThrowsError(try NumberBaseConvert.parse("", from: .decimal))
        XCTAssertThrowsError(try NumberBaseConvert.parse("   ", from: .decimal))
    }

    func testGroupedBinaryPadsToNibbles() {
        XCTAssertEqual(NumberBaseConvert.groupedBinary("1010"), "1010")
        XCTAssertEqual(NumberBaseConvert.groupedBinary("101"), "0101")
        XCTAssertEqual(NumberBaseConvert.groupedBinary("11001010"), "1100 1010")
        XCTAssertEqual(NumberBaseConvert.groupedBinary("0"), "0000")
    }
}
