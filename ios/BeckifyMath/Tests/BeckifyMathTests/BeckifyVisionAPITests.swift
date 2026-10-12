import XCTest
@testable import BeckifyMath

final class BeckifyVisionAPITests: XCTestCase {

    func testDefaultAnalyzeURLsHitLiveAPI() {
        XCTAssertEqual(
            BeckifyVisionAPI.analyzeURL(task: .nameplate, customEndpoint: nil)?.absoluteString,
            "https://api.beckify.com/api/analyze-nameplate"
        )
        XCTAssertEqual(
            BeckifyVisionAPI.analyzeURL(task: .panel, customEndpoint: nil)?.absoluteString,
            "https://api.beckify.com/api/analyze-panel"
        )
        XCTAssertEqual(
            BeckifyVisionAPI.defaultAnalyzeURL(for: .panel)?.absoluteString,
            "https://api.beckify.com/api/analyze-panel"
        )
        XCTAssertEqual(
            BeckifyVisionAPI.analyzeURL(task: .nameplate, customEndpoint: "https://proxy.example/ocr")?.absoluteString,
            "https://proxy.example/ocr"
        )
        XCTAssertNil(BeckifyVisionAPI.httpsBase("http://insecure.example/ocr"))
        XCTAssertNil(BeckifyVisionAPI.analyzeURL(task: .panel, customEndpoint: nil, apiBase: "http://beckify.com"))
    }

    func testUploadLimitsAndDefaultHost() {
        XCTAssertEqual(BeckifyVisionAPI.defaultAPIBase, "https://api.beckify.com")
        XCTAssertEqual(BeckifyVisionAPI.maxPickBytes, 12 * 1024 * 1024)
        XCTAssertEqual(BeckifyVisionAPI.maxUploadBytes, 8 * 1024 * 1024)
        XCTAssertEqual(BeckifyVisionAPI.maxUploadEdge, 2048)
        XCTAssertTrue(BeckifyVisionAPI.disclaimer.localizedCaseInsensitiveContains("tap Analyze"))
    }

    func testHTTPSBaseAndDataURLHelpers() {
        XCTAssertEqual(BeckifyVisionAPI.httpsBase("https://beckify.com/"), "https://beckify.com")
        XCTAssertEqual(BeckifyVisionAPI.httpsBase("  https://proxy.example:8443/ocr/?k=1 "), "https://proxy.example:8443/ocr?k=1")
        XCTAssertNil(BeckifyVisionAPI.httpsBase("http://insecure.example/ocr"))
        XCTAssertNil(BeckifyVisionAPI.httpsBase("not a url"))
        XCTAssertNil(BeckifyVisionAPI.httpsBase(nil))
        XCTAssertNil(BeckifyVisionAPI.httpsBase("   "))
        XCTAssertEqual(BeckifyVisionAPI.mimeType(fromDataURL: "data:image/png;base64,aa"), "image/png")
        XCTAssertEqual(BeckifyVisionAPI.mimeType(fromDataURL: "data:image/webp;base64,aa"), "image/webp")
        XCTAssertEqual(BeckifyVisionAPI.mimeType(fromDataURL: "data:image/jpeg;base64,aa"), "image/jpeg")
        XCTAssertEqual(BeckifyVisionAPI.mimeType(fromDataURL: "data:image/jpg;base64,aa"), "image/jpeg")
        XCTAssertEqual(BeckifyVisionAPI.mimeType(fromDataURL: "data:image/heic;base64,aa", fallback: "image/heic"), "image/heic")
        XCTAssertEqual(BeckifyVisionAPI.dataURL(jpegBase64: "abc"), "data:image/jpeg;base64,abc")
    }

    func testRequestBodyMatchesWebContract() throws {
        let body = BeckifyVisionAPI.requestBody(
            imageBase64: "data:image/jpeg;base64,abc",
            mimeType: "image/jpeg",
            task: .nameplate
        )
        XCTAssertEqual(body, [
            "imageBase64": "data:image/jpeg;base64,abc",
            "mimeType": "image/jpeg",
            "task": "nameplate",
        ])

        let data = try BeckifyVisionAPI.requestJSON(
            imageBase64: "data:image/jpeg;base64,abc",
            mimeType: "image/jpeg",
            task: .panel
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
        XCTAssertEqual(object["task"], "panel")
        XCTAssertEqual(object.count, 3)
    }

    func testAuthorizationTokenStaysOffDefaultHost() {
        XCTAssertEqual(
            BeckifyVisionAPI.authorizationToken(customEndpoint: nil, token: "secret-token"),
            ""
        )
        XCTAssertEqual(
            BeckifyVisionAPI.authorizationToken(customEndpoint: "https://proxy.example/ocr", token: "secret-token"),
            "secret-token"
        )
        XCTAssertEqual(
            BeckifyVisionAPI.authorizationToken(
                customEndpoint: "https://api.beckify.com/api/analyze-nameplate",
                token: "secret-token"
            ),
            ""
        )
    }

    func testVisionErrorCopyIsTaskAware() {
        XCTAssertTrue(BeckifyVisionAPI.formatVisionError(status: 429, message: nil, retryAfter: 12, task: .nameplate).contains("12 s"))
        XCTAssertTrue(BeckifyVisionAPI.formatVisionError(status: 429, message: nil, retryAfter: 12, task: .nameplate).contains("nameplate"))
        XCTAssertTrue(BeckifyVisionAPI.formatVisionError(status: 504, message: nil, task: .panel).localizedCaseInsensitiveContains("timed out"))
        XCTAssertTrue(BeckifyVisionAPI.formatVisionError(status: 404, message: nil, task: .panel).contains("/api/analyze-panel"))
        XCTAssertTrue(
            BeckifyVisionAPI.formatVisionError(
                status: 405,
                message: nil,
                endpoint: "https://beckify.com/api/analyze-nameplate",
                task: .nameplate
            ).contains("GitHub Pages")
        )
        XCTAssertFalse(BeckifyVisionAPI.hostIsGitHubPages("https://api.beckify.com/api/analyze-nameplate"))
        XCTAssertTrue(BeckifyVisionAPI.hostIsGitHubPages("https://www.beckify.com/"))
        XCTAssertTrue(BeckifyVisionAPI.hostIsGitHubPages("beckify.com"))
        XCTAssertFalse(BeckifyVisionAPI.hostIsGitHubPages(nil))
        XCTAssertTrue(BeckifyVisionAPI.formatVisionError(status: 429, message: nil, retryAfter: 90, task: .panel).contains("2 min"))
        XCTAssertTrue(BeckifyVisionAPI.formatVisionError(status: 413, message: nil, task: .panel).contains("8 MB"))
        XCTAssertFalse(BeckifyVisionAPI.formatVisionError(status: 405, message: nil, task: .panel).contains("GitHub Pages"))
        XCTAssertEqual(
            BeckifyVisionAPI.formatVisionError(status: 502, message: "The vision provider could not analyze this image.", task: .panel),
            "The vision provider could not analyze this image."
        )
        XCTAssertTrue(BeckifyVisionAPI.formatVisionError(status: 503, message: nil, task: .nameplate).localizedCaseInsensitiveContains("not configured"))
        XCTAssertEqual(
            BeckifyVisionAPI.formatVisionError(status: 500, message: nil, task: .nameplate),
            "Nameplate analysis failed with HTTP 500."
        )
    }

    func testUnwrapsAnalysisEnvelope() {
        let nested = BeckifyVisionAPI.visionDraftInput([
            "provider": "openai",
            "analysis": ["fields": ["ratedHP": ["value": 10, "confidence": 0.9]]],
        ] as [String: Any])
        XCTAssertNotNil(nested["fields"])
    }
}
