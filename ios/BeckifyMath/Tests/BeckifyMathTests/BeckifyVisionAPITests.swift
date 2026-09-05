import XCTest
@testable import BeckifyMath

final class BeckifyVisionAPITests: XCTestCase {

    func testDefaultAnalyzeURLsHitLiveAPI() {
        XCTAssertEqual(
            BeckifyVisionAPI.analyzeURL(task: .look, customEndpoint: nil)?.absoluteString,
            "https://api.beckify.com/api/analyze-look"
        )
        XCTAssertEqual(
            BeckifyVisionAPI.analyzeURL(task: .nameplate, customEndpoint: nil)?.absoluteString,
            "https://api.beckify.com/api/analyze-nameplate"
        )
        XCTAssertEqual(
            BeckifyVisionAPI.analyzeURL(task: .panel, customEndpoint: nil)?.absoluteString,
            "https://api.beckify.com/api/analyze-panel"
        )
        XCTAssertEqual(
            BeckifyVisionAPI.analyzeURL(task: .nameplate, customEndpoint: "https://proxy.example/ocr")?.absoluteString,
            "https://proxy.example/ocr"
        )
        XCTAssertNil(BeckifyVisionAPI.httpsBase("http://insecure.example/ocr"))
        XCTAssertNil(BeckifyVisionAPI.analyzeURL(task: .panel, customEndpoint: nil, apiBase: "http://beckify.com"))
    }

    func testRequestBodyMatchesLookCheckContract() throws {
        let body = BeckifyVisionAPI.requestBody(
            imageBase64: "data:image/jpeg;base64,abc",
            mimeType: "image/jpeg",
            task: .nameplate
        )
        XCTAssertEqual(body["imageBase64"], "data:image/jpeg;base64,abc")
        XCTAssertEqual(body["mimeType"], "image/jpeg")
        XCTAssertEqual(body["task"], "nameplate")

        let data = try BeckifyVisionAPI.requestJSON(
            imageBase64: "data:image/jpeg;base64,abc",
            mimeType: "image/jpeg",
            task: .panel
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
        XCTAssertEqual(object["task"], "panel")
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
    }

    func testUnwrapsAnalysisEnvelope() {
        let nested = BeckifyVisionAPI.visionDraftInput([
            "provider": "openai",
            "analysis": ["fields": ["ratedHP": ["value": 10, "confidence": 0.9]]],
        ] as [String: Any])
        XCTAssertNotNil(nested["fields"])
    }
}
