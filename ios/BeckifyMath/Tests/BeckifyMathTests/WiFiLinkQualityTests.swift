import XCTest
@testable import BeckifyMath

final class WiFiLinkQualityTests: XCTestCase {
    func testSummarizeMedianMinMaxAndLoss() {
        let s = WiFiLinkQuality.summarize(samplesMS: [10, 30, 20, nil, 40])
        XCTAssertEqual(s.attempts, 5)
        XCTAssertEqual(s.successCount, 4)
        XCTAssertEqual(s.failureCount, 1)
        XCTAssertEqual(s.minMS ?? -1, 10, accuracy: 1e-9)
        XCTAssertEqual(s.maxMS ?? -1, 40, accuracy: 1e-9)
        XCTAssertEqual(s.medianMS ?? -1, 25, accuracy: 1e-9)
        XCTAssertEqual(s.meanMS ?? -1, 25, accuracy: 1e-9)
        XCTAssertEqual(s.lossPercent, 20, accuracy: 1e-9)
        XCTAssertEqual(s.band, .good)
    }

    func testSummarizeTreatsNonFiniteAsLoss() {
        let s = WiFiLinkQuality.summarize(samplesMS: [.nan, .infinity, -4, nil])
        XCTAssertEqual(s.successCount, 0)
        XCTAssertEqual(s.lossPercent, 100, accuracy: 1e-9)
        XCTAssertEqual(s.band, .unavailable)
        XCTAssertNil(s.medianMS)
    }

    func testEmptySummaryIsUnavailable() {
        let s = WiFiLinkQuality.summarize(samplesMS: [])
        XCTAssertEqual(s.attempts, 0)
        XCTAssertEqual(s.lossPercent, 100, accuracy: 1e-9)
        XCTAssertEqual(s.band, .unavailable)
    }

    func testOddMedian() {
        let s = WiFiLinkQuality.summarize(samplesMS: [9, 1, 3])
        XCTAssertEqual(s.medianMS ?? -1, 3, accuracy: 1e-9)
        XCTAssertEqual(s.band, .excellent)
    }

    func testBandThresholds() {
        XCTAssertEqual(WiFiLinkQuality.band(medianMS: 24.9, lossPercent: 0), .excellent)
        XCTAssertEqual(WiFiLinkQuality.band(medianMS: 25, lossPercent: 0), .good)
        XCTAssertEqual(WiFiLinkQuality.band(medianMS: 59.9, lossPercent: 0), .good)
        XCTAssertEqual(WiFiLinkQuality.band(medianMS: 60, lossPercent: 0), .fair)
        XCTAssertEqual(WiFiLinkQuality.band(medianMS: 119.9, lossPercent: 0), .fair)
        XCTAssertEqual(WiFiLinkQuality.band(medianMS: 120, lossPercent: 0), .slow)
        XCTAssertEqual(WiFiLinkQuality.band(medianMS: 249.9, lossPercent: 0), .slow)
        XCTAssertEqual(WiFiLinkQuality.band(medianMS: 250, lossPercent: 0), .poor)
        XCTAssertEqual(WiFiLinkQuality.band(medianMS: 18, lossPercent: 100), .unavailable)
        XCTAssertEqual(WiFiLinkQuality.band(medianMS: nil, lossPercent: 40), .unavailable)
        XCTAssertEqual(WiFiLinkQuality.band(medianMS: .nan, lossPercent: 0), .unavailable)
    }

    func testParseHostPortSchemesAndPorts() {
        let a = WiFiLinkQuality.parseHostPort("1.1.1.1")
        XCTAssertEqual(a?.host, "1.1.1.1")
        XCTAssertEqual(a?.port, 443)

        let b = WiFiLinkQuality.parseHostPort("beckify.com:8443")
        XCTAssertEqual(b?.host, "beckify.com")
        XCTAssertEqual(b?.port, 8443)

        let c = WiFiLinkQuality.parseHostPort("https://beckify.com/wifi")
        XCTAssertEqual(c?.host, "beckify.com")
        XCTAssertEqual(c?.port, 443)

        let d = WiFiLinkQuality.parseHostPort("[::1]:80")
        XCTAssertEqual(d?.host, "::1")
        XCTAssertEqual(d?.port, 80)

        let e = WiFiLinkQuality.parseHostPort("fe80::1")
        XCTAssertEqual(e?.host, "fe80::1")
        XCTAssertEqual(e?.port, 443)

        XCTAssertNil(WiFiLinkQuality.parseHostPort(""))
        XCTAssertNil(WiFiLinkQuality.parseHostPort("   "))
        XCTAssertNil(WiFiLinkQuality.parseHostPort("host:99999"))
        XCTAssertNil(WiFiLinkQuality.parseHostPort("host:0"))
        XCTAssertNil(WiFiLinkQuality.parseHostPort("[]:80"))
    }

    func testParseHostPortUsesCallerDefault() {
        let lan = WiFiLinkQuality.parseHostPort("192.168.1.1", defaultPort: 80)
        XCTAssertEqual(lan?.host, "192.168.1.1")
        XCTAssertEqual(lan?.port, 80)
    }

    func testPrivateAndLocalHostsNeedLocalNetwork() {
        XCTAssertTrue(WiFiLinkQuality.isPrivateOrLocalIPv4("10.0.0.1"))
        XCTAssertTrue(WiFiLinkQuality.isPrivateOrLocalIPv4("192.168.1.1"))
        XCTAssertTrue(WiFiLinkQuality.isPrivateOrLocalIPv4("172.16.0.1"))
        XCTAssertTrue(WiFiLinkQuality.isPrivateOrLocalIPv4("172.31.255.1"))
        XCTAssertTrue(WiFiLinkQuality.isPrivateOrLocalIPv4("127.0.0.1"))
        XCTAssertTrue(WiFiLinkQuality.isPrivateOrLocalIPv4("169.254.1.1"))
        XCTAssertFalse(WiFiLinkQuality.isPrivateOrLocalIPv4("172.32.0.1"))
        XCTAssertFalse(WiFiLinkQuality.isPrivateOrLocalIPv4("1.1.1.1"))
        XCTAssertFalse(WiFiLinkQuality.isPrivateOrLocalIPv4("8.8.8.8"))
        XCTAssertFalse(WiFiLinkQuality.isPrivateOrLocalIPv4("192.168.1"))
        XCTAssertFalse(WiFiLinkQuality.isPrivateOrLocalIPv4("192.168.1.1.1"))
        XCTAssertFalse(WiFiLinkQuality.isPrivateOrLocalIPv4("192.168.01.1"))

        XCTAssertTrue(WiFiLinkQuality.needsLocalNetworkPrompt(host: "192.168.0.1"))
        XCTAssertTrue(WiFiLinkQuality.needsLocalNetworkPrompt(host: "router.local"))
        XCTAssertTrue(WiFiLinkQuality.needsLocalNetworkPrompt(host: "localhost"))
        XCTAssertTrue(WiFiLinkQuality.needsLocalNetworkPrompt(host: "[::1]"))
        XCTAssertTrue(WiFiLinkQuality.needsLocalNetworkPrompt(host: "fe80::1"))
        XCTAssertTrue(WiFiLinkQuality.needsLocalNetworkPrompt(host: "fd12::1"))
        XCTAssertFalse(WiFiLinkQuality.needsLocalNetworkPrompt(host: "1.1.1.1"))
        XCTAssertFalse(WiFiLinkQuality.needsLocalNetworkPrompt(host: "beckify.com"))
        XCTAssertFalse(WiFiLinkQuality.needsLocalNetworkPrompt(host: "facebook.com"))
        XCTAssertFalse(WiFiLinkQuality.needsLocalNetworkPrompt(host: "fdic.gov"))
    }

    func testDefaultPortLANVersusPublic() {
        XCTAssertEqual(WiFiLinkQuality.defaultPort(forHost: "192.168.1.1"), 80)
        XCTAssertEqual(WiFiLinkQuality.defaultPort(forHost: "1.1.1.1"), 443)
        XCTAssertEqual(WiFiLinkQuality.defaultPort(forHost: "beckify.com"), 443)
    }
}
