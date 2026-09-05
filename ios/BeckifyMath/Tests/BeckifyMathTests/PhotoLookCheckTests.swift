import XCTest
@testable import BeckifyMath

final class PhotoLookCheckTests: XCTestCase {

    func testAsLookScoreMatchesWebsite() {
        XCTAssertNil(PhotoLookCheck.asLookScore(nil))
        XCTAssertNil(PhotoLookCheck.asLookScore(""))
        XCTAssertNil(PhotoLookCheck.asLookScore("  "))
        XCTAssertNil(PhotoLookCheck.asLookScore(NSNull()))
        XCTAssertEqual(PhotoLookCheck.asLookScore(0), 0)
        XCTAssertEqual(PhotoLookCheck.asLookScore(88.4), 88)
        XCTAssertEqual(PhotoLookCheck.asLookScore(90.2), 90)
        XCTAssertEqual(PhotoLookCheck.asLookScore("200"), 100)
        XCTAssertEqual(PhotoLookCheck.asLookScore(-4), 0)
        XCTAssertNil(PhotoLookCheck.asLookScore("not-a-number"))
    }

    func testNormalizeLooksGoodDraft() throws {
        let json = """
        {
          "verdict": "looks_good",
          "score": 88.4,
          "headline": "Strong light",
          "summary": "You look sharp in this frame.",
          "roast": "  Chin up like you billed overtime for that jawline.  ",
          "metrics": { "lighting": 90.2, "framing": 70, "expression": 84, "sharpness": 88 },
          "reasons": ["Even light"],
          "fixes": ["Smile"]
        }
        """
        let draft = try PhotoLookCheck.normalizeDraft(jsonText: json)
        XCTAssertEqual(draft.task, "look")
        XCTAssertEqual(draft.verdict, .looksGood)
        XCTAssertEqual(draft.score, 88)
        XCTAssertEqual(draft.summary, "You look sharp in this frame.")
        XCTAssertEqual(draft.roast, "Chin up like you billed overtime for that jawline.")
        XCTAssertTrue(draft.showsRoast)
        XCTAssertEqual(draft.headline, "Strong light")
        XCTAssertEqual(draft.metrics.lighting, 90)
        XCTAssertEqual(draft.metrics.overall, 88)
        XCTAssertTrue(draft.showsMetrics)
        XCTAssertTrue(draft.showsScore)
        XCTAssertEqual(draft.verdict.badge, "Looks good")
        XCTAssertTrue(draft.copyLine.contains("Look Check: Looks good"))
        XCTAssertTrue(draft.copyLine.contains("BroGPT: Chin up like you billed overtime for that jawline."))
    }

    func testNormalizeRoastPresentAndAbsent() {
        let withRoast = PhotoLookCheck.normalizeDraft([
            "verdict": "mixed",
            "score": 61,
            "roast": "Lighting said maybe. That fit said absolutely not.",
        ] as [String: Any])
        XCTAssertEqual(withRoast.roast, "Lighting said maybe. That fit said absolutely not.")
        XCTAssertTrue(withRoast.showsRoast)
        XCTAssertTrue(withRoast.copyLine.contains("BroGPT:"))

        let absent = PhotoLookCheck.normalizeDraft([
            "verdict": "looks_good",
            "score": 80,
        ] as [String: Any])
        XCTAssertEqual(absent.roast, "")
        XCTAssertFalse(absent.showsRoast)
        XCTAssertFalse(absent.copyLine.contains("BroGPT:"))

        let declined = PhotoLookCheck.normalizeDraft([
            "verdict": "declined",
            "roast": "should be stripped",
        ] as [String: Any])
        XCTAssertEqual(declined.roast, "")
        XCTAssertFalse(declined.showsRoast)

        let noPerson = PhotoLookCheck.normalizeDraft([
            "verdict": "no_person",
            "roast": "nope",
        ] as [String: Any])
        XCTAssertEqual(noPerson.roast, "")
        XCTAssertFalse(noPerson.showsRoast)
    }

    func testNormalizeWrappedAnalysisPayload() throws {
        let json = """
        {
          "provider": "openai",
          "model": "gpt-4o",
          "analysis": {
            "verdict": "mixed",
            "score": 61,
            "headline": "Some things work",
            "brief": "Light is kind. Angle is not.",
            "metrics": { "lighting": 80, "framing": 40, "expression": 70, "focus": 75, "overall": 61 },
            "reasons": ["Soft window light"],
            "fixes": ["Step back"],
            "photo_notes": ["Phone was rotated"],
            "warnings": []
          }
        }
        """
        let draft = try PhotoLookCheck.normalizeDraft(jsonText: json)
        XCTAssertEqual(draft.verdict, .mixed)
        XCTAssertEqual(draft.score, 61)
        XCTAssertEqual(draft.summary, "Light is kind. Angle is not.")
        XCTAssertEqual(draft.metrics.sharpness, 75)
        XCTAssertEqual(draft.photoNotes, ["Phone was rotated"])
        XCTAssertEqual(draft.verdict.badge, "Mixed")
    }

    func testDeclinedNullsScoresAndMetrics() throws {
        let json = """
        {
          "verdict": "declined",
          "score": 12,
          "headline": "No",
          "metrics": { "lighting": 80, "overall": 90 }
        }
        """
        let draft = try PhotoLookCheck.normalizeDraft(jsonText: json)
        XCTAssertEqual(draft.verdict, .declined)
        XCTAssertNil(draft.score)
        XCTAssertNil(draft.metrics.lighting)
        XCTAssertNil(draft.metrics.overall)
        XCTAssertFalse(draft.showsMetrics)
        XCTAssertFalse(draft.showsScore)
        XCTAssertEqual(draft.summary, "No")
        XCTAssertEqual(draft.verdict.badge, "Not rated")
        XCTAssertEqual(draft.verdict.defaultHeadline, "This photo cannot be rated.")
    }

    func testUnknownVerdictClampsToMixed() {
        let draft = PhotoLookCheck.normalizeDraft(["verdict": "amazing", "score": 200] as [String: Any])
        XCTAssertEqual(draft.verdict, .mixed)
        XCTAssertEqual(draft.score, 100)
    }

    func testNullMetricsStayNullAndOverallFallsBackToScore() {
        let draft = PhotoLookCheck.normalizeDraft([
            "verdict": "looks_good",
            "score": 88,
            "metrics": [
                "lighting": NSNull(),
                "framing": 70,
                "expression": NSNull(),
                "sharpness": 88,
            ],
        ] as [String: Any])
        XCTAssertNil(draft.metrics.lighting)
        XCTAssertNil(draft.metrics.expression)
        XCTAssertEqual(draft.metrics.framing, 70)
        XCTAssertEqual(draft.metrics.overall, 88)
    }

    func testNoPersonNullsExpression() {
        let draft = PhotoLookCheck.normalizeDraft([
            "verdict": "no_person",
            "score": 55,
            "metrics": [
                "lighting": 60,
                "framing": 50,
                "expression": 99,
                "sharpness": 70,
                "overall": 55,
            ],
        ] as [String: Any])
        XCTAssertEqual(draft.verdict, .noPerson)
        XCTAssertNil(draft.metrics.expression)
        XCTAssertEqual(draft.metrics.lighting, 60)
        XCTAssertEqual(draft.verdict.badge, "No person")
    }

    func testLooksBadBadgeAndDefaultHeadline() {
        let draft = PhotoLookCheck.normalizeDraft(["verdict": "looks_bad"] as [String: Any])
        XCTAssertEqual(draft.verdict.badge, "Looks off")
        XCTAssertEqual(draft.displayHeadline, "This is not your strongest photo.")
    }

    func testRequestBodyMatchesWebContract() throws {
        let body = PhotoLookCheck.requestBody(
            imageBase64: "data:image/jpeg;base64,abc",
            mimeType: "image/jpeg"
        )
        XCTAssertEqual(body["imageBase64"], "data:image/jpeg;base64,abc")
        XCTAssertEqual(body["mimeType"], "image/jpeg")
        XCTAssertEqual(body["task"], "look")

        let data = try PhotoLookCheck.requestJSON(
            imageBase64: "data:image/jpeg;base64,abc",
            mimeType: "image/jpeg"
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
        XCTAssertEqual(object["task"], "look")
    }

    func testHTTPSEndpointRules() {
        XCTAssertEqual(
            PhotoLookCheck.analyzeURL(customEndpoint: nil)?.absoluteString,
            "https://api.beckify.com/api/analyze-look"
        )
        XCTAssertEqual(
            PhotoLookCheck.analyzeURL(customEndpoint: "https://proxy.example/ocr")?.absoluteString,
            "https://proxy.example/ocr"
        )
        XCTAssertEqual(
            PhotoLookCheck.httpsBase("https://beckify.com/"),
            "https://beckify.com"
        )
        XCTAssertNil(PhotoLookCheck.httpsBase("http://insecure.example/ocr"))
        XCTAssertNil(PhotoLookCheck.httpsBase("not a url"))
        XCTAssertNil(PhotoLookCheck.analyzeURL(customEndpoint: nil, apiBase: "http://beckify.com"))
        XCTAssertEqual(PhotoLookCheck.mimeType(fromDataURL: "data:image/png;base64,aa"), "image/png")
        XCTAssertEqual(PhotoLookCheck.mimeType(fromDataURL: "data:image/jpeg;base64,aa"), "image/jpeg")
        XCTAssertTrue(PhotoLookCheck.dataURL(jpegBase64: "abc").hasPrefix("data:image/jpeg;base64,"))
    }

    func testVisionErrorCopy() {
        XCTAssertTrue(PhotoLookCheck.formatVisionError(status: 429, message: nil, retryAfter: 90).contains("min"))
        XCTAssertTrue(PhotoLookCheck.formatVisionError(status: 429, message: nil, retryAfter: 12).contains("12 s"))
        XCTAssertTrue(PhotoLookCheck.formatVisionError(status: 504, message: nil).localizedCaseInsensitiveContains("timed out"))
        XCTAssertTrue(PhotoLookCheck.formatVisionError(status: 413, message: nil).contains("8 MB"))
        XCTAssertEqual(
            PhotoLookCheck.formatVisionError(status: 502, message: "The vision provider could not analyze this image."),
            "The vision provider could not analyze this image."
        )
        XCTAssertTrue(PhotoLookCheck.formatVisionError(status: 404, message: nil).contains("api.beckify.com"))
        XCTAssertTrue(PhotoLookCheck.formatVisionError(status: 405, message: nil).contains("stale or missing"))
        XCTAssertFalse(PhotoLookCheck.formatVisionError(status: 405, message: nil).contains("GitHub Pages"))
        XCTAssertTrue(
            PhotoLookCheck.formatVisionError(
                status: 405,
                message: nil,
                endpoint: "https://beckify.com/api/analyze-look"
            ).contains("GitHub Pages")
        )
        XCTAssertFalse(PhotoLookCheck.hostIsGitHubPages("https://api.beckify.com/api/analyze-look"))
        XCTAssertEqual(
            PhotoLookCheck.authorizationToken(customEndpoint: nil, token: "secret-token"),
            ""
        )
        XCTAssertEqual(
            PhotoLookCheck.authorizationToken(customEndpoint: "https://proxy.example/ocr", token: "secret-token"),
            "secret-token"
        )
        XCTAssertTrue(PhotoLookCheck.formatVisionError(status: 503, message: nil).localizedCaseInsensitiveContains("not configured"))
        XCTAssertEqual(
            PhotoLookCheck.formatVisionError(status: 503, message: "The vision provider key is missing (OPENAI_API_KEY)."),
            "The vision provider key is missing (OPENAI_API_KEY)."
        )
    }

    func testPolicyToolIDIsExplicitAndOnJobsite() {
        XCTAssertEqual(ToolCalculationPolicy.mode(forToolID: "lookCheck"), .explicit)
        XCTAssertTrue(ToolCalculationPolicy.knownToolIDs.contains("lookCheck"))
        XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: "lookCheck"), .field)
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "lookCheck"), .jobsite)
        let copy = ToolHowItWorksCatalog.copy(forToolID: "lookCheck")
        XCTAssertNotNil(copy)
        XCTAssertTrue(copy?.summary.localizedCaseInsensitiveContains("Analyze Look") == true)
        XCTAssertTrue(copy?.bullets.contains(where: { $0.localizedCaseInsensitiveContains("not medical") }) == true)
    }

    func testConnectivityCopyLineNoLongerSaysLookCheck() {
        let wifiUp = LookCheckPathContext(satisfied: true, usesWiFi: true)
        let v = LookCheck.classify(
            path: wifiUp,
            response: LookCheck.parseHTTPResponse("HTTP/1.1 200 OK\nContent-Length: 7\n\nSuccess"),
            connected: true,
            localEndpoint: "172.16.4.9:9"
        )
        XCTAssertTrue(v.copyLine.contains("Online / Captive: No captive portal"))
        XCTAssertFalse(v.copyLine.localizedCaseInsensitiveContains("Look Check"))
    }
}
