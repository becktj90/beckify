import XCTest
@testable import BeckifyMath

final class CrewTalkContractsTests: XCTestCase {
    private let omittedVoiceSettingKeys = [
        "stability",
        "similarity_boost",
        "similarityBoost",
        "style",
        "speed",
    ]

    func testSpeakRequestOmitsVoiceSettingsAndForcesJobsite() throws {
        for crew in CrewTalkMember.allCases {
            let request = CrewTalkSpeakRequest(text: "Leave that breaker be.", crew: crew, language: "EN")
            XCTAssertEqual(request.voiceMode, "jobsite", crew.rawValue)
            XCTAssertEqual(request.mode, "jobsite", crew.rawValue)
            XCTAssertEqual(request.voice, crew.voiceID, crew.rawValue)
            XCTAssertEqual(request.model, CrewTalkMember.speakModel, crew.rawValue)
            XCTAssertEqual(request.language, "en", crew.rawValue)
            XCTAssertEqual(request.task, "speak")
            XCTAssertEqual(request.format, "mp3")

            let object = request.jsonObject()
            for key in omittedVoiceSettingKeys {
                XCTAssertNil(object[key], "\(crew.rawValue) sent \(key)")
            }
            XCTAssertEqual(object["voiceMode"] as? String, "jobsite")
            XCTAssertEqual(object["mode"] as? String, "jobsite")
            XCTAssertEqual(Set(object.keys).count, 8)

            let encoded = try JSONEncoder().encode(request)
            let decodedObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
            for key in omittedVoiceSettingKeys {
                XCTAssertNil(decodedObject[key], "encoded \(key)")
            }
            XCTAssertEqual(decodedObject["voiceMode"] as? String, "jobsite")
            XCTAssertEqual(decodedObject["mode"] as? String, "jobsite")
        }
    }

    func testDecodeDropsVoiceSettingsAndIgnoresCleanVoiceMode() throws {
        let json = """
        {
          "text": "Leave that breaker be.",
          "voice": "tdK8noxHGTBqk6F18tbZ",
          "voiceMode": "clean",
          "mode": "clean",
          "style": 1.0,
          "stability": 0.15,
          "similarity_boost": 0.72,
          "speed": 0.64
        }
        """
        let decoded = try JSONDecoder().decode(CrewTalkSpeakRequest.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.voiceMode, "jobsite")
        XCTAssertEqual(decoded.mode, "jobsite")
        XCTAssertEqual(decoded.model, "eleven_v3")
        XCTAssertEqual(decoded.format, "mp3")
        XCTAssertEqual(decoded.task, "speak")
        XCTAssertEqual(decoded.voice, "tdK8noxHGTBqk6F18tbZ")
        let again = try JSONEncoder().encode(decoded)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: again) as? [String: Any])
        for key in omittedVoiceSettingKeys {
            XCTAssertNil(object[key])
        }
        XCTAssertEqual(object["voiceMode"] as? String, "jobsite")
    }

    func testAudioCacheKeyGoldenAndCrossPlatform() {
        let tito = CrewTalkSpeakRequest(text: "Kill the power.", crew: .titoSolano)
        XCTAssertEqual(
            tito.canonicalCacheDocument,
            [
                "crewtalk-speak-v1",
                "voiceMode=jobsite",
                "model=eleven_v3",
                "voice=goyf4sY4AqSvMIeO1hb5",
                "language=es",
                "format=mp3",
                "text=Kill the power.",
            ].joined(separator: "\n")
        )
        XCTAssertEqual(
            tito.audioCacheKey,
            "613fabd7244fe30beca7f88811e980d818b3ad65d4570501cf04cd3735abb5f6"
        )
        XCTAssertEqual(CrewTalkDigest.sha256Hex(utf8: ""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        XCTAssertEqual(CrewTalkDigest.sha256Hex(utf8: "abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")

        let padded = CrewTalkSpeakRequest(text: "  Kill the power.\n", crew: .titoSolano)
        XCTAssertEqual(padded.audioCacheKey, tito.audioCacheKey)

        let crlf = CrewTalkSpeakRequest(text: "Kill the power.\r\nNow.", crew: .titoSolano)
        let lf = CrewTalkSpeakRequest(text: "Kill the power.\nNow.", crew: .titoSolano)
        XCTAssertEqual(crlf.text, lf.text)
        XCTAssertEqual(crlf.audioCacheKey, lf.audioCacheKey)

        let nfc = CrewTalkSpeakRequest(text: "caf\u{00e9}", crew: .bodieHale)
        let nfd = CrewTalkSpeakRequest(text: "cafe\u{0301}", crew: .bodieHale)
        XCTAssertEqual(nfc.text, nfd.text)
        XCTAssertEqual(nfc.audioCacheKey, nfd.audioCacheKey)
        XCTAssertEqual(nfc.voiceMode, "jobsite")
        XCTAssertEqual(nfc.language, "en")
        XCTAssertNotEqual(nfc.audioCacheKey, tito.audioCacheKey)
    }

    func testOnDeviceFallbackMatrix() {
        for status in [0, 404, 405, 408, 429, 500, 502, 503, 504] {
            XCTAssertTrue(
                SpanishTranslatorAPI.shouldAttemptOnDeviceFallback(httpStatus: status),
                "expected fallback for \(status)"
            )
        }
        for status in [400, 401, 403, 413] {
            XCTAssertFalse(
                SpanishTranslatorAPI.shouldAttemptOnDeviceFallback(httpStatus: status),
                "expected no fallback for \(status)"
            )
        }
        for status in [200, 201, 204, 299] {
            XCTAssertFalse(
                SpanishTranslatorAPI.shouldAttemptOnDeviceFallback(httpStatus: status),
                "expected no fallback for \(status)"
            )
        }
        for status in [100, 301, 302, 402, 409, 422, 451] {
            XCTAssertTrue(
                SpanishTranslatorAPI.shouldAttemptOnDeviceFallback(httpStatus: status),
                "expected fallback for other non-2xx \(status)"
            )
        }
    }

    func testNormalizeDraftToleratesMissingPersonaFields() throws {
        let bare = SpanishTranslatorAPI.normalizeDraft([
            "translation": "Corta la corriente.",
            "sourceText": "Kill the power.",
        ])
        let draft = try XCTUnwrap(bare)
        XCTAssertNil(draft.personaLine)
        XCTAssertNil(draft.personaCrew)
        XCTAssertEqual(draft.translation, "Corta la corriente.")

        let blank = SpanishTranslatorAPI.normalizeDraft([
            "translation": "Corta la corriente.",
            "personaLine": "   ",
            "personaCrew": NSNull(),
        ])
        XCTAssertNil(blank?.personaLine)
        XCTAssertNil(blank?.personaCrew)

        let json = """
        {"translation":"Hey — over here.","sourceText":"Hey!"}
        """
        let fromString = try XCTUnwrap(SpanishTranslatorAPI.normalizeDraft(json))
        XCTAssertNil(fromString.personaLine)
        XCTAssertNil(fromString.personaCrew)

        let withPersona = SpanishTranslatorAPI.normalizeDraft([
            "translation": "Corta la corriente.",
            "personaLine": "  Corta la corriente, ya. ",
            "personaCrew": " titoSolano ",
        ])
        XCTAssertEqual(withPersona?.personaLine, "Corta la corriente, ya.")
        XCTAssertEqual(withPersona?.personaCrew, "titoSolano")

        let defaults = SpanishTranslationDraft(translation: "Hola")
        XCTAssertNil(defaults.personaLine)
        XCTAssertNil(defaults.personaCrew)
        XCTAssertEqual(defaults.engine, "beckify")
    }
}
