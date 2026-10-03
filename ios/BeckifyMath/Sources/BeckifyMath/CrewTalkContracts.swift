import Foundation

/// Crew Talk wire contract for `/api/speak`.
///
/// Voice settings (`stability`, `similarity_boost`, `style`, `speed`) stay on the server.
/// This request never sends them. `voiceMode` and `mode` are always `jobsite`.
///
/// The audio cache key is SHA-256 of a canonical UTF-8 document (LF separators, NFC text).
/// It does not use `Hasher`, so the same clip maps to the same key on Linux and Apple platforms.
public struct CrewTalkSpeakRequest: Equatable, Sendable, Codable {
    public var task: String
    public var text: String
    public var voice: String
    public var model: String
    public var format: String
    public var language: String
    /// Always `jobsite`. Clean is not a Crew Talk speak mode.
    public var voiceMode: String
    /// Always `jobsite`. Mirrors `voiceMode` for the existing speak route.
    public var mode: String

    public static let voiceModeValue = "jobsite"

    private enum CodingKeys: String, CodingKey {
        case task
        case text
        case voice
        case model
        case format
        case language
        case voiceMode
        case mode
    }

    /// - Parameters:
    ///   - language: BCP-47-ish tag. Empty uses `crew.speakLanguage`.
    public init(
        text: String,
        crew: CrewTalkMember,
        format: String = "mp3",
        language: String = ""
    ) {
        let resolvedFormat = Self.canonicalToken(format).lowercased()
        let resolvedLanguage = Self.canonicalToken(language).lowercased()
        self.task = "speak"
        self.text = Self.canonicalText(text)
        self.voice = crew.voiceID
        self.model = CrewTalkMember.speakModel
        self.format = resolvedFormat.isEmpty ? "mp3" : resolvedFormat
        self.language = resolvedLanguage.isEmpty ? crew.speakLanguage : resolvedLanguage
        self.voiceMode = Self.voiceModeValue
        self.mode = Self.voiceModeValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.task = Self.canonicalToken(try container.decodeIfPresent(String.self, forKey: .task) ?? "")
        if self.task.isEmpty { self.task = "speak" }
        self.text = Self.canonicalText(try container.decode(String.self, forKey: .text))
        self.voice = Self.canonicalToken(try container.decode(String.self, forKey: .voice))
        let decodedModel = Self.canonicalToken(try container.decodeIfPresent(String.self, forKey: .model) ?? "")
        self.model = decodedModel.isEmpty ? CrewTalkMember.speakModel : decodedModel
        let decodedFormat = Self.canonicalToken(try container.decodeIfPresent(String.self, forKey: .format) ?? "").lowercased()
        self.format = decodedFormat.isEmpty ? "mp3" : decodedFormat
        self.language = Self.canonicalToken(try container.decodeIfPresent(String.self, forKey: .language) ?? "").lowercased()
        // Ignore any voiceMode / mode / voice-settings keys on the wire.
        self.voiceMode = Self.voiceModeValue
        self.mode = Self.voiceModeValue
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(task, forKey: .task)
        try container.encode(text, forKey: .text)
        try container.encode(voice, forKey: .voice)
        try container.encode(model, forKey: .model)
        try container.encode(format, forKey: .format)
        try container.encode(language, forKey: .language)
        try container.encode(Self.voiceModeValue, forKey: .voiceMode)
        try container.encode(Self.voiceModeValue, forKey: .mode)
    }

    public func jsonObject() -> [String: Any] {
        [
            "task": task,
            "text": text,
            "voice": voice,
            "model": model,
            "format": format,
            "language": language,
            "voiceMode": Self.voiceModeValue,
            "mode": Self.voiceModeValue,
        ]
    }

    public func jsonData() throws -> Data {
        try JSONSerialization.data(withJSONObject: jsonObject(), options: [.sortedKeys])
    }

    /// Stable clip id. Golden vector: Tito + "Kill the power." →
    /// `613fabd7244fe30beca7f88811e980d818b3ad65d4570501cf04cd3735abb5f6`.
    public var audioCacheKey: String {
        CrewTalkDigest.sha256Hex(utf8: canonicalCacheDocument)
    }

    /// LF-only document. No trailing newline. Text is already NFC with LF newlines.
    public var canonicalCacheDocument: String {
        [
            "crewtalk-speak-v1",
            "voiceMode=\(Self.voiceModeValue)",
            "model=\(model)",
            "voice=\(voice)",
            "language=\(language)",
            "format=\(format)",
            "text=\(text)",
        ].joined(separator: "\n")
    }

    /// NFC, trimmed, CR/LF folded to LF, so macOS NFD and Windows CRLF hit one cache entry.
    static func canonicalText(_ raw: String) -> String {
        let nfc = (raw as NSString).precomposedStringWithCanonicalMapping
        let trimmed = nfc.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private static func canonicalToken(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum CrewTalkDigest {
    static func sha256Hex(utf8 string: String) -> String {
        let bytes = Array(string.utf8)
        let digest = sha256(bytes)
        let digits = Array("0123456789abcdef")
        var hex = ""
        hex.reserveCapacity(digest.count * 2)
        for byte in digest {
            hex.append(digits[Int(byte >> 4)])
            hex.append(digits[Int(byte & 0x0f)])
        }
        return hex
    }

    static func sha256(_ message: [UInt8]) -> [UInt8] {
        var h: [UInt32] = [
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
        ]
        var msg = message
        let bitCount = UInt64(message.count) &* 8
        msg.append(0x80)
        while msg.count % 64 != 56 {
            msg.append(0)
        }
        for shift in stride(from: 56, through: 0, by: -8) {
            msg.append(UInt8((bitCount >> UInt64(shift)) & 0xff))
        }

        var chunk = 0
        while chunk < msg.count {
            var w = [UInt32](repeating: 0, count: 64)
            for i in 0..<16 {
                let j = chunk + i * 4
                w[i] = (UInt32(msg[j]) << 24)
                    | (UInt32(msg[j + 1]) << 16)
                    | (UInt32(msg[j + 2]) << 8)
                    | UInt32(msg[j + 3])
            }
            for i in 16..<64 {
                let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
                let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
                w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
            }
            var a = h[0]
            var b = h[1]
            var c = h[2]
            var d = h[3]
            var e = h[4]
            var f = h[5]
            var g = h[6]
            var hh = h[7]
            for i in 0..<64 {
                let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
                let ch = (e & f) ^ ((~e) & g)
                let temp1 = hh &+ s1 &+ ch &+ k[i] &+ w[i]
                let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = s0 &+ maj
                hh = g
                g = f
                f = e
                e = d &+ temp1
                d = c
                c = b
                b = a
                a = temp1 &+ temp2
            }
            h[0] = h[0] &+ a
            h[1] = h[1] &+ b
            h[2] = h[2] &+ c
            h[3] = h[3] &+ d
            h[4] = h[4] &+ e
            h[5] = h[5] &+ f
            h[6] = h[6] &+ g
            h[7] = h[7] &+ hh
            chunk += 64
        }

        var out: [UInt8] = []
        out.reserveCapacity(32)
        for value in h {
            out.append(UInt8((value >> 24) & 0xff))
            out.append(UInt8((value >> 16) & 0xff))
            out.append(UInt8((value >> 8) & 0xff))
            out.append(UInt8(value & 0xff))
        }
        return out
    }

    private static func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 {
        (x >> n) | (x << (32 - n))
    }

    private static let k: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ]
}
