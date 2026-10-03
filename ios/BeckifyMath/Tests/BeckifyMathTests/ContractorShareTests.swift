import XCTest
@testable import BeckifyMath

final class ContractorShareTests: XCTestCase {
    func testRequestJSONCollapsesNameAndKeepsTool() throws {
        let data = try XCTUnwrap(ContractorShareValidation.requestJSON(
            tool: .voltageDrop,
            contractor: "  Harbor   Electric  ",
            fields: [
                ContractorShareField(label: "Voltage drop", value: "6.02 V"),
                ContractorShareField(label: " Status ", value: " OVER "),
            ]
        ))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["tool"] as? String, "voltage-drop")
        XCTAssertEqual(object["contractor"] as? String, "Harbor Electric")
        let fields = try XCTUnwrap(object["fields"] as? [[String: String]])
        XCTAssertEqual(fields.count, 2)
        XCTAssertEqual(fields[1]["label"], "Status")
        XCTAssertEqual(fields[1]["value"], "OVER")
        XCTAssertNil(object["billingStatus"])
    }

    func testRejectsEmptyNameControlCharsAndTooManyFields() {
        XCTAssertNil(ContractorShareValidation.normalizedContractor("   "))
        XCTAssertNil(ContractorShareValidation.normalizedContractor(String(repeating: "A", count: 81)))
        XCTAssertNil(ContractorShareValidation.normalizedContractor("North\nSide"))
        let tooMany = (0..<17).map { ContractorShareField(label: "L\($0)", value: "1") }
        XCTAssertNil(ContractorShareValidation.normalizedFields(tooMany))
        XCTAssertNil(ContractorShareValidation.requestJSON(tool: .conduitFill, contractor: "A", fields: []))
    }

    func testAcceptedPageURLIsBeckifyShareOnly() throws {
        let token = "eyJ2IjoxfQ.hmacsig"
        let good = try XCTUnwrap(ContractorShareLink.acceptedPageURL(from: Data(
            #"{"url":"https://beckify.com/share/\#(token)"}"#.utf8
        )))
        XCTAssertEqual(good.absoluteString, "https://beckify.com/share/\(token)")
        XCTAssertEqual(ContractorShareLink.createURL.absoluteString, "https://api.beckify.com/api/share")
        XCTAssertNil(ContractorShareLink.acceptedPageURL(from: Data(
            #"{"url":"https://evil.example/share/\#(token)"}"#.utf8
        )))
        XCTAssertNil(ContractorShareLink.acceptedPageURL(from: Data(
            #"{"url":"http://beckify.com/share/\#(token)"}"#.utf8
        )))
        XCTAssertNil(ContractorShareLink.acceptedPageURL(from: Data(
            #"{"url":"https://beckify.com/privacy"}"#.utf8
        )))
    }
}
