import XCTest
@testable import BeckifyMath

final class ToolHowItWorksTests: XCTestCase {

    func testEveryKnownToolHasHowItWorksCopy() {
        let missing = ToolCalculationPolicy.knownToolIDs.filter { ToolHowItWorksCatalog.copy(forToolID: $0) == nil }
        XCTAssertTrue(
            missing.isEmpty,
            "Add ToolHowItWorksCatalog copy for: \(missing.sorted().joined(separator: ", "))"
        )
        XCTAssertEqual(ToolHowItWorksCatalog.coveredToolIDs.count, ToolCalculationPolicy.knownToolIDs.count)
    }

    func testCopyIsShortAndScannable() {
        for id in ToolCalculationPolicy.knownToolIDs {
            guard let copy = ToolHowItWorksCatalog.copy(forToolID: id) else {
                XCTFail("missing \(id)")
                continue
            }
            XCTAssertFalse(copy.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, id)
            XCTAssertFalse(copy.context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, id)
            XCTAssertLessThanOrEqual(copy.summary.count, 220, "\(id) summary is a wall of text")
            XCTAssertGreaterThanOrEqual(copy.summary.count, 36, "\(id) summary is too thin")
            XCTAssertLessThanOrEqual(copy.context.count, 160, "\(id) context is a wall of text")
            XCTAssertLessThanOrEqual(copy.bullets.count, 4, "\(id) has too many bullets")
            XCTAssertFalse(copy.bullets.isEmpty, "\(id) needs at least one honesty / assumption bullet")
            for bullet in copy.bullets {
                XCTAssertFalse(bullet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, id)
                XCTAssertLessThanOrEqual(bullet.count, 180, "\(id) bullet is a wall of text")
            }
        }
    }

    func testNoDuplicateSummaries() {
        let summaries = ToolCalculationPolicy.knownToolIDs.compactMap { ToolHowItWorksCatalog.copy(forToolID: $0)?.summary }
        XCTAssertEqual(Set(summaries).count, summaries.count, "two tools share the same how-it-works summary")
    }

    func testSensorCopyStatesPublicAPILimits() {
        let wifi = ToolHowItWorksCatalog.copy(forToolID: "wifiStatus")
        XCTAssertTrue(wifi?.bullets.contains(where: { $0.localizedCaseInsensitiveContains("dBm") }) == true)
        XCTAssertTrue(wifi?.summary.localizedCaseInsensitiveContains("RTT") == true)
        XCTAssertTrue(wifi?.summary.localizedCaseInsensitiveContains("Online / Captive") == true)

        let cellular = ToolHowItWorksCatalog.copy(forToolID: "cellularStatus")
        XCTAssertTrue(cellular?.bullets.contains(where: { $0.localizedCaseInsensitiveContains("RSRP") }) == true)
        XCTAssertTrue(cellular?.bullets.contains(where: { $0.localizedCaseInsensitiveContains("invent") }) == true)
        XCTAssertTrue(cellular?.summary.localizedCaseInsensitiveContains("Online / Captive") == true)

        let ble = ToolHowItWorksCatalog.copy(forToolID: "bluetoothScan")
        XCTAssertTrue(ble?.summary.localizedCaseInsensitiveContains("CoreBluetooth") == true)

        let noise = ToolHowItWorksCatalog.copy(forToolID: "noiseMeter")
        XCTAssertTrue(noise?.bullets.contains(where: { $0.localizedCaseInsensitiveContains("SLM") }) == true)
        XCTAssertTrue(noise?.summary.localizedCaseInsensitiveContains("dBFS") == true)
    }

    func testHomeworkDefaultsOpenFieldDefaultsCollapsed() {
        XCTAssertTrue(ToolHowItWorksCatalog.defaultExpanded(forToolID: "voltageDivider"))
        XCTAssertTrue(ToolHowItWorksCatalog.defaultExpanded(forToolID: "analogWorkbench"))
        XCTAssertTrue(ToolHowItWorksCatalog.defaultExpanded(forToolID: "phasorDiagram"))
        XCTAssertFalse(ToolHowItWorksCatalog.defaultExpanded(forToolID: "wireAmpacity"))
        XCTAssertFalse(ToolHowItWorksCatalog.defaultExpanded(forToolID: "wifiStatus"))
        XCTAssertFalse(ToolHowItWorksCatalog.defaultExpanded(forToolID: "controlSystems"))
        XCTAssertFalse(ToolHowItWorksCatalog.defaultExpanded(forToolID: "ohmsLaw"))
    }

    func testUnknownIDHasNoCopy() {
        XCTAssertNil(ToolHowItWorksCatalog.copy(forToolID: "notARealTool"))
    }
}
