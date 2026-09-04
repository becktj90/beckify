import XCTest
@testable import BeckifyMath

final class LookCheckTests: XCTestCase {
    private let wifiUp = LookCheckPathContext(satisfied: true, usesWiFi: true)
    private let cellUp = LookCheckPathContext(satisfied: true, usesCellular: true)
    private let down = LookCheckPathContext(satisfied: false)

    func testAppleSuccessHTMLIsOnline() {
        let raw = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html\r
        Content-Length: 68\r
        \r
        <HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>
        """
        let response = LookCheck.parseHTTPResponse(raw)
        XCTAssertEqual(response?.status, 200)
        XCTAssertTrue(LookCheck.isAppleSuccess(response!))
        let v = LookCheck.classify(path: wifiUp, response: response, connected: true, localEndpoint: "192.168.1.24:51234")
        XCTAssertEqual(v.kind, .online)
        XCTAssertEqual(v.headline, "No captive portal")
        XCTAssertEqual(v.localIPv4, "192.168.1.24")
        XCTAssertEqual(v.transportLabel, "Wi-Fi")
        XCTAssertTrue(v.detail.localizedCaseInsensitiveContains("Success"))
        XCTAssertFalse(v.headline.localizedCaseInsensitiveContains("dBm"))
        XCTAssertFalse(v.headline.localizedCaseInsensitiveContains("RSSI"))
    }

    func testPlainSuccessBodyIsOnline() {
        let raw = "HTTP/1.0 200 OK\nContent-Length: 7\n\nSuccess"
        let response = LookCheck.parseHTTPResponse(raw)
        XCTAssertTrue(LookCheck.isAppleSuccess(response!))
        let v = LookCheck.classify(path: cellUp, response: response, connected: true)
        XCTAssertEqual(v.kind, .online)
        XCTAssertEqual(v.transportLabel, "cellular")
    }

    func testRedirectIsCaptive() {
        let raw = """
        HTTP/1.1 302 Found
        Location: http://10.0.0.1/login

        <html><body>Redirect</body></html>
        """
        let response = LookCheck.parseHTTPResponse(raw)
        XCTAssertEqual(response?.status, 302)
        XCTAssertEqual(response?.location, "http://10.0.0.1/login")
        XCTAssertFalse(LookCheck.isAppleLocation(response?.location))
        let v = LookCheck.classify(path: wifiUp, response: response, connected: true)
        XCTAssertEqual(v.kind, .captive)
        XCTAssertEqual(v.headline, "Captive portal")
        XCTAssertTrue(v.detail.localizedCaseInsensitiveContains("Safari"))
    }

    func testLoginHTMLIsCaptive() {
        let raw = """
        HTTP/1.1 200 OK
        Content-Type: text/html

        <html><body><form action="/auth">Sign in to Guest Wi-Fi</form></body></html>
        """
        let response = LookCheck.parseHTTPResponse(raw)!
        XCTAssertTrue(LookCheck.looksLikePortalPage(response))
        let v = LookCheck.classify(path: wifiUp, response: response, connected: true)
        XCTAssertEqual(v.kind, .captive)
    }

    func testUnsatisfiedPathIsOfflineWithoutProbe() {
        let v = LookCheck.classify(path: down, response: nil, connected: false)
        XCTAssertEqual(v.kind, .offline)
        XCTAssertEqual(v.headline, "No path")
    }

    func testSatisfiedButNoAnswerIsLocalOnly() {
        let v = LookCheck.classify(path: wifiUp, response: nil, connected: false)
        XCTAssertEqual(v.kind, .localOnly)
        XCTAssertEqual(v.headline, "Local only")
        XCTAssertTrue(v.detail.localizedCaseInsensitiveContains("captive.apple.com"))
    }

    func testConnectedEmptyBodyIsUnclear() {
        let v = LookCheck.classify(path: wifiUp, response: nil, connected: true)
        XCTAssertEqual(v.kind, .unclear)
        XCTAssertEqual(v.headline, "Unclear")
        XCTAssertTrue(v.detail.localizedCaseInsensitiveContains("will not invent"))
    }

    func testUnexpectedJSONIsUnclear() {
        let raw = "HTTP/1.1 200 OK\nContent-Type: application/json\n\n{\"ok\":true}"
        let response = LookCheck.parseHTTPResponse(raw)!
        XCTAssertFalse(LookCheck.isAppleSuccess(response))
        XCTAssertFalse(LookCheck.looksLikePortalPage(response))
        let v = LookCheck.classify(path: wifiUp, response: response, connected: true)
        XCTAssertEqual(v.kind, .unclear)
    }

    func testParseRejectsNonHTTP() {
        XCTAssertNil(LookCheck.parseHTTPResponse("not http"))
        XCTAssertNil(LookCheck.parseHTTPResponse("HTTP/1.1 OK\n\n"))
    }

    func testHasCompleteHTTPMessageUsesContentLength() {
        let partial = "HTTP/1.1 200 OK\nContent-Length: 7\n\nSucc"
        XCTAssertFalse(LookCheck.hasCompleteHTTPMessage(partial))
        let full = "HTTP/1.1 200 OK\nContent-Length: 7\n\nSuccess"
        XCTAssertTrue(LookCheck.hasCompleteHTTPMessage(full))
        let noLength = "HTTP/1.1 200 OK\n\nSuccess"
        XCTAssertFalse(LookCheck.hasCompleteHTTPMessage(noLength))
    }

    func testChunkedBodyDecodes() {
        let raw = "HTTP/1.1 200 OK\nTransfer-Encoding: chunked\n\n7\nSuccess\n0\n\n"
        let response = LookCheck.parseHTTPResponse(raw)
        XCTAssertEqual(response?.body, "Success")
        XCTAssertTrue(LookCheck.isAppleSuccess(response!))
        XCTAssertTrue(LookCheck.hasCompleteHTTPMessage(raw))
    }

    func testIPv4FromEndpoint() {
        XCTAssertEqual(LookCheck.ipv4Host(fromEndpoint: "10.0.0.8:443"), "10.0.0.8")
        XCTAssertEqual(LookCheck.hostFromEndpoint("10.0.0.8:443"), "10.0.0.8")
        XCTAssertNil(LookCheck.ipv4Host(fromEndpoint: "[fe80::1]:80"))
        XCTAssertEqual(LookCheck.hostFromEndpoint("[fe80::1]:80"), "fe80::1")
        XCTAssertNil(LookCheck.ipv4Host(fromEndpoint: "fe80::1"))
        XCTAssertTrue(LookCheck.isIPv4("192.168.0.1"))
        XCTAssertFalse(LookCheck.isIPv4("192.168.0"))
        XCTAssertFalse(LookCheck.isIPv4("192.168.01.1"))
        XCTAssertNil(LookCheck.ipv4Host(fromEndpoint: nil))
    }

    func testLocationHostParsing() {
        XCTAssertEqual(LookCheck.hostFromLocation("https://login.hotel.example/a"), "login.hotel.example")
        XCTAssertEqual(LookCheck.hostFromLocation("/hotspot-detect.html"), LookCheck.probeHost)
        XCTAssertTrue(LookCheck.isAppleLocation("http://captive.apple.com/hotspot-detect.html"))
        XCTAssertFalse(LookCheck.isAppleLocation("http://10.1.1.1/splash"))
    }

    func testPathFingerprintAndTransport() {
        let both = LookCheckPathContext(satisfied: true, usesWiFi: true, usesCellular: true)
        XCTAssertEqual(both.fingerprint, "up|wifi|cell")
        XCTAssertEqual(both.transportLabel, "Wi-Fi + cellular")
        XCTAssertEqual(down.fingerprint, "down")
    }

    func testCopyLineAndHTTPRequest() {
        let v = LookCheck.classify(
            path: wifiUp,
            response: LookCheck.parseHTTPResponse("HTTP/1.1 200 OK\nContent-Length: 7\n\nSuccess"),
            connected: true,
            localEndpoint: "172.16.4.9:9"
        )
        XCTAssertTrue(v.copyLine.contains("Look Check: No captive portal"))
        XCTAssertTrue(v.copyLine.contains("local IPv4 172.16.4.9"))
        XCTAssertTrue(LookCheck.httpRequest().contains("GET /hotspot-detect.html HTTP/1.1"))
        XCTAssertTrue(LookCheck.httpRequest().contains("Host: captive.apple.com"))
    }

    func testRedirectStatuses() {
        XCTAssertTrue(LookCheck.isRedirect(302))
        XCTAssertTrue(LookCheck.isRedirect(307))
        XCTAssertFalse(LookCheck.isRedirect(200))
        XCTAssertFalse(LookCheck.isRedirect(404))
    }
}
