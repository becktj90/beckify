import XCTest
@testable import BeckifyMath

final class CellularRadioTests: XCTestCase {
    func testKnownRATConstantsMapToGeneration() {
        let nr = CellularRadioIdentity.identify("CTRadioAccessTechnologyNR")
        XCTAssertEqual(nr.label, "5G NR (SA)")
        XCTAssertEqual(nr.generation, .fiveG)
        XCTAssertEqual(nr.raw, "CTRadioAccessTechnologyNR")

        let nsa = CellularRadioIdentity.identify("CTRadioAccessTechnologyNRNSA")
        XCTAssertEqual(nsa.label, "5G NR (NSA)")
        XCTAssertEqual(nsa.generation, .fiveG)

        let lte = CellularRadioIdentity.identify("CTRadioAccessTechnologyLTE")
        XCTAssertEqual(lte.label, "LTE")
        XCTAssertEqual(lte.generation, .fourG)
        XCTAssertEqual(lte.compact, "LTE (4G)")

        XCTAssertEqual(CellularRadioIdentity.identify("CTRadioAccessTechnologyWCDMA").generation, .threeG)
        XCTAssertEqual(CellularRadioIdentity.identify("CTRadioAccessTechnologyHSDPA").label, "HSDPA")
        XCTAssertEqual(CellularRadioIdentity.identify("CTRadioAccessTechnologyHSUPA").generation, .threeG)
        XCTAssertEqual(CellularRadioIdentity.identify("CTRadioAccessTechnologyeHRPD").label, "eHRPD")
        XCTAssertEqual(CellularRadioIdentity.identify("CTRadioAccessTechnologyCDMAEVDORevA").label, "EV-DO Rev A")
        XCTAssertEqual(CellularRadioIdentity.identify("CTRadioAccessTechnologyCDMA1x").generation, .twoG)
        XCTAssertEqual(CellularRadioIdentity.identify("CTRadioAccessTechnologyEdge").label, "EDGE")
        XCTAssertEqual(CellularRadioIdentity.identify("CTRadioAccessTechnologyGPRS").generation, .twoG)
    }

    func testBareSuffixAndPathStillMatch() {
        XCTAssertEqual(CellularRadioIdentity.identify("LTE").generation, .fourG)
        XCTAssertEqual(CellularRadioIdentity.identify("NR").label, "5G NR (SA)")
        XCTAssertEqual(CellularRadioIdentity.identify("nrnsa").label, "5G NR (NSA)")
        XCTAssertEqual(
            CellularRadioIdentity.identify("CoreTelephony/CTRadioAccessTechnologyLTE").label,
            "LTE"
        )
    }

    func testEmptyAndUnknownRATAreHonest() {
        let empty = CellularRadioIdentity.identify(nil)
        XCTAssertEqual(empty.label, "Not reported")
        XCTAssertEqual(empty.generation, .unknown)
        XCTAssertEqual(CellularRadioIdentity.identify("   ").label, "Not reported")
        XCTAssertEqual(CellularRadioIdentity.identify("--").label, "Not reported")

        let mystery = CellularRadioIdentity.identify("CTRadioAccessTechnologyFutureRadio")
        XCTAssertEqual(mystery.generation, .unknown)
        XCTAssertTrue(mystery.label.contains("CTRadioAccessTechnologyFutureRadio"))
    }

    func testServiceIDsDedupAndCountLabel() {
        let ids = CellularRadioIdentity.serviceIDs(
            ratKeys: ["0000000100000001", "0000000100000002", ""],
            carrierKeys: ["0000000100000001", "  0000000100000003  ", "--"]
        )
        XCTAssertEqual(ids, ["0000000100000001", "0000000100000002", "0000000100000003"])
        XCTAssertEqual(CellularRadioIdentity.serviceCountLabel(0), "none reported")
        XCTAssertEqual(CellularRadioIdentity.serviceCountLabel(1), "1 service")
        XCTAssertEqual(CellularRadioIdentity.serviceCountLabel(2), "2 services")
    }

    func testShortServiceIDAndPLMN() {
        XCTAssertEqual(CellularRadioIdentity.shortServiceID("0000000100000001"), "…0001")
        XCTAssertEqual(CellularRadioIdentity.shortServiceID("abcd"), "abcd")
        XCTAssertEqual(CellularRadioIdentity.shortServiceID("  "), "—")
        XCTAssertEqual(CellularRadioIdentity.plmn(mcc: "310", mnc: "260"), "310-260")
        XCTAssertNil(CellularRadioIdentity.plmn(mcc: "310", mnc: "--"))
        XCTAssertNil(CellularRadioIdentity.plmn(mcc: nil, mnc: "260"))
        XCTAssertEqual(CellularRadioIdentity.displayISO("us"), "US")
        XCTAssertEqual(CellularRadioIdentity.displayField(nil), "—")
        XCTAssertEqual(CellularRadioIdentity.displayField("Verizon"), "Verizon")
        XCTAssertEqual(CellularRadioIdentity.displayField("--"), "—")
    }

    func testCatalogCoversEveryKnownConstant() {
        let raws = Set(CellularRadioIdentity.catalog.map(\.raw))
        XCTAssertTrue(raws.contains("CTRadioAccessTechnologyNR"))
        XCTAssertTrue(raws.contains("CTRadioAccessTechnologyNRNSA"))
        XCTAssertTrue(raws.contains("CTRadioAccessTechnologyLTE"))
        XCTAssertEqual(CellularRadioIdentity.catalog.count, 13)
        XCTAssertEqual(Set(CellularRadioIdentity.catalog.map(\.raw)).count, 13)
    }

    func testTypicalMetricsAreLabeledReferenceNotLive() {
        let symbols = CellularRadioIdentity.typicalMetrics.map(\.symbol)
        XCTAssertEqual(symbols, ["RSRP", "RSRQ", "SINR", "RSSI"])
        for metric in CellularRadioIdentity.typicalMetrics {
            XCTAssertFalse(metric.excellent.isEmpty, metric.symbol)
            XCTAssertFalse(metric.meaning.isEmpty, metric.symbol)
            XCTAssertFalse(metric.unit.isEmpty, metric.symbol)
        }
    }

    func testNormalizeRATToken() {
        XCTAssertEqual(CellularRadioIdentity.normalizeRATToken("CTRadioAccessTechnologyLTE"), "lte")
        XCTAssertEqual(CellularRadioIdentity.normalizeRATToken("LTE"), "lte")
        XCTAssertEqual(CellularRadioIdentity.normalizeRATToken("  NRNSA  "), "nrnsa")
    }
}
