import XCTest
@testable import BeckifyMath

final class LabMathTests: XCTestCase {
    func testLowpassFractionAndSubscriptProduct() {
        let math = LabMath.parse(#"H(s) = \frac{1}{1 + sRC}"#)
        XCTAssertEqual(
            math?.structure,
            "row(italic[H] (italic[s]) relation[=] frac(number[1] / row(number[1] operation[+] italic[sRC])))"
        )
        XCTAssertEqual(math?.fractionCount, 1)
    }

    func testIntegratorUnaryMinus() {
        let math = LabMath.parse(#"H(s) = -\frac{1}{sRC}"#)
        XCTAssertEqual(
            math?.structure,
            "row(italic[H] (italic[s]) relation[=] operation[−] frac(number[1] / italic[sRC]))"
        )
    }

    func testDividerSubscripts() {
        let math = LabMath.parse(#"H = \frac{V_{out}}{V_{in}} = \frac{R_2}{R_1 + R_2}"#)
        XCTAssertEqual(math?.fractionCount, 2)
        XCTAssertEqual(
            math?.structure,
            "row(italic[H] relation[=] frac(script(italic[V]_(italic[out])) / script(italic[V]_(italic[in]))) relation[=] frac(script(italic[R]_(number[2])) / row(script(italic[R]_(number[1])) operation[+] script(italic[R]_(number[2])))))"
        )
    }

    func testNestedRadicalAndQuarterWaveSuperscript() {
        let q = LabMath.parse(#"Q = \sqrt{\frac{R_{hi}}{R_{lo}} - 1}"#)
        XCTAssertEqual(q?.fractionCount, 1)
        XCTAssertTrue(q?.structure.contains("sqrt(") == true)
        XCTAssertTrue(q?.structure.contains("italic[hi]") == true)
        XCTAssertTrue(q?.structure.contains("italic[lo]") == true)

        let zin = LabMath.parse(#"Z_{in}(f_0) = \frac{Z_0^{2}}{Z_{load}}"#)
        XCTAssertEqual(
            zin?.structure,
            "row(script(italic[Z]_(italic[in])) (script(italic[f]_(number[0]))) relation[=] frac(script(italic[Z]_(number[0])^(number[2])) / script(italic[Z]_(italic[load]))))"
        )
    }

    func testStubFunctionAndComplexAbsolute() {
        let stub = LabMath.parse(#"jX = j Z_0 \tan(\beta\ell)"#)
        XCTAssertNotNil(stub)
        XCTAssertTrue(stub?.structure.contains("upright[tan]") == true)
        XCTAssertTrue(stub?.structure.contains("script(italic[Z]_(number[0]))") == true)

        let plane = LabMath.parse(#"z = x + jy = |z| \angle \theta"#)
        XCTAssertEqual(
            plane?.structure,
            "row(italic[z] relation[=] italic[x] operation[+] italic[jy] relation[=] |italic[z]| relation[∠] italic[θ])"
        )
    }

    func testRejectsUnbalancedFraction() {
        XCTAssertNil(LabMath.parse(#"\frac{1}{1 + sRC"#))
        XCTAssertNil(LabMath.parse(""))
        XCTAssertNil(LabMath.parse(#"\unknown"#))
    }
}
