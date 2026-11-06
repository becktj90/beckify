import BeckifyMath
import Foundation

/// Network calls for Conversation Mode. Translate and speak reuse the shipped
/// `/api/translate` and `/api/speak` contracts. Rooms use `/api/rooms`.
enum CrewTalkTranslationService {
    /// Translate what the speaker said into the other person's language.
    static func translate(
        _ text: String,
        from speaker: CrewTalkConversationLanguage,
        listener: CrewTalkMember
    ) async throws -> SpanishTranslationDraft {
        let source = SpanishTranslatorAPI.clampSourceText(text)
        guard !source.isEmpty else {
            throw CrewTalkConversationError(message: SpanishTranslatorAPI.emptySourceMessage(direction: speaker.speakingDirection))
        }
        guard let url = SpanishTranslatorAPI.translateURL(customEndpoint: "") else {
            throw CrewTalkConversationError(message: "Translate needs the Beckify API.")
        }
        let direction = speaker.speakingDirection
        let body = try SpanishTranslatorAPI.requestJSON(
            text: source,
            sourceLanguage: direction.sourceLanguage,
            targetLanguage: direction.targetLanguage,
            voiceMode: SpanishTranslatorAPI.translateVoiceMode(requested: .jobsite, crew: listener)
        )
        do {
            let payload = try await BeckifyAIClient.postJSON(url: url, body: body, bearerToken: "", timeout: 30)
            guard let draft = SpanishTranslatorAPI.normalizeDraft(payload, fallbackSource: source) else {
                throw CrewTalkConversationError(message: "Translate returned no text.")
            }
            return draft
        } catch let error as VisionHTTPError {
            throw CrewTalkConversationError(
                message: SpanishTranslatorAPI.formatTranslateError(
                    status: error.status,
                    message: error.message,
                    endpoint: url.absoluteString
                )
            )
        }
    }

    /// Neural audio in the listener's character voice.
    /// Repeat lines are served from the on-device speech cache
    /// (`CrewTalkSpeechAudioCache`) instead of re-synthesizing them.
    static func speechAudio(_ text: String, crew: CrewTalkMember) async throws -> Data {
        guard let url = SpanishTranslatorAPI.speakURL(customEndpoint: "") else {
            throw CrewTalkConversationError(message: "Speak needs the Beckify API.")
        }
        let speakText = SpanishTranslatorAPI.clampSpeakText(text)
        // Same canonical document the server hashes, so the on-device key
        // and the server key agree for a given line + character.
        let cacheKey = CrewTalkSpeakRequest(text: speakText, crew: crew).audioCacheKey
        if let cached = await CrewTalkSpeechAudioCache.shared.cachedAudio(forKey: cacheKey) {
            return cached
        }
        let body = try SpanishTranslatorAPI.speakRequestJSON(
            text: speakText,
            voiceMode: .jobsite,
            language: crew.speakLanguage,
            crew: crew
        )
        do {
            let result = try await BeckifyAIClient.postAudio(url: url, body: body, bearerToken: "", timeout: 30)
            // Only cache successful, non-empty audio. Failures throw and are
            // never stored, so the next line retries the network — and the
            // caller falls back to the Apple voice on failure, as before.
            if !result.data.isEmpty {
                await CrewTalkSpeechAudioCache.shared.store(result.data, forKey: cacheKey)
            }
            return result.data
        } catch let error as VisionHTTPError {
            throw CrewTalkConversationError(
                message: SpanishTranslatorAPI.formatSpeakError(
                    status: error.status,
                    message: error.message,
                    endpoint: url.absoluteString
                )
            )
        }
    }
}

/// On-device file cache for Crew Talk speech audio.
///
/// Keyed by `CrewTalkSpeakRequest.audioCacheKey` — the same SHA-256 canonical
/// document the server uses — so a line cached here is the same clip the
/// server would cache. Files live in the app Caches directory
/// (`CrewTalkSpeech/<key>.mp3`) and may be purged by the system at any time;
/// a missing file is just a cache miss.
///
/// Caps: 200 clips / 50 MB, least-recently-used first. A 128 kbps MP3 is
/// ~16 KB per second of speech and Crew Talk lines are at most 500
/// characters (~30 s), so 200 clips is roughly 15–40 MB in practice and the
/// byte cap is the binding limit. The cache never throws: every failure is
/// a miss (or a skipped store), so a corrupt or full cache degrades to the
/// old behaviour — synthesize, then fall back to the Apple voice.
actor CrewTalkSpeechAudioCache {
    static let shared = CrewTalkSpeechAudioCache()

    /// Maximum clips held. Beyond this the oldest are evicted.
    static let maxFiles = 200
    /// Maximum total bytes held. Beyond this the oldest are evicted.
    static let maxBytes: Int64 = 50 * 1024 * 1024

    private let folder: URL

    init(folder: URL? = nil) {
        if let folder {
            self.folder = folder
        } else {
            self.folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("CrewTalkSpeech", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.folder, withIntermediateDirectories: true)
    }

    /// Cached audio for a key, or nil. A hit refreshes recency (LRU).
    /// Corrupt files are deleted and treated as misses.
    func cachedAudio(forKey key: String) -> Data? {
        let url = fileURL(forKey: key)
        guard let data = try? Data(contentsOf: url), Self.isPlausibleMP3(data) else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        // Touch so eviction keeps recently played lines.
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return data
    }

    /// Stores audio under a key. Empty or implausible audio is never stored.
    func store(_ data: Data, forKey key: String) {
        guard Self.isPlausibleMP3(data) else { return }
        let url = fileURL(forKey: key)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard (try? data.write(to: url, options: .atomic)) != nil else { return }
        evictIfNeeded()
    }

    private func fileURL(forKey key: String) -> URL {
        folder.appendingPathComponent("\(key).mp3")
    }

    /// MP3s from ElevenLabs start with an ID3 tag or an MPEG frame sync.
    /// Anything else is not a speech clip (e.g. an error page saved as data).
    private static func isPlausibleMP3(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        if data[0] == 0x49 && data[1] == 0x44 && data[2] == 0x33 { return true } // "ID3"
        return data[0] == 0xFF && (data[1] & 0xE0) == 0xE0
    }

    /// Deletes oldest files until the file and byte caps both hold.
    private func evictIfNeeded() {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else { return }
        var entries: [(url: URL, size: Int64, date: Date)] = []
        var totalBytes: Int64 = 0
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                  let size = values.fileSize else { continue }
            let size64 = Int64(size)
            totalBytes += size64
            entries.append((url, size64, values.contentModificationDate ?? .distantPast))
        }
        guard entries.count > Self.maxFiles || totalBytes > Self.maxBytes else { return }
        entries.sort { $0.date < $1.date }
        var remainingCount = entries.count
        for entry in entries {
            if remainingCount <= Self.maxFiles && totalBytes <= Self.maxBytes { break }
            try? FileManager.default.removeItem(at: entry.url)
            totalBytes -= entry.size
            remainingCount -= 1
        }
    }
}

/// A seat in a linked room. `pid` is this device's secret; keep it in memory only.
struct CrewTalkRoomSession: Equatable {
    var code: String
    var pid: String
    var language: CrewTalkConversationLanguage
    var partnerLanguage: CrewTalkConversationLanguage?
}

/// Simple relay client. Sends text, listens over Server-Sent Events.
/// Nothing is stored. Rooms end when both people leave or go quiet.
enum CrewTalkRoomClient {
    static func create(language: CrewTalkConversationLanguage) async throws -> CrewTalkRoomSession {
        let payload = try await post(CrewTalkRoomAPI.roomsPath, body: CrewTalkRoomAPI.languageBody(language))
        guard let code = payload["code"] as? String, let pid = payload["pid"] as? String else {
            throw CrewTalkConversationError(message: "Could not start a room.")
        }
        return CrewTalkRoomSession(code: code, pid: pid, language: language, partnerLanguage: nil)
    }

    static func join(code: String, language: CrewTalkConversationLanguage) async throws -> CrewTalkRoomSession {
        let path = CrewTalkRoomAPI.path(code: code, action: "join")
        let payload = try await post(path, body: CrewTalkRoomAPI.languageBody(language))
        guard let pid = payload["pid"] as? String else {
            throw CrewTalkConversationError(message: "Could not join that room.")
        }
        return CrewTalkRoomSession(
            code: CrewTalkRoomCode.normalize(code),
            pid: pid,
            language: language,
            partnerLanguage: CrewTalkConversationLanguage.parse(payload["partnerLanguage"] as? String)
        )
    }

    static func send(_ text: String, in session: CrewTalkRoomSession) async throws {
        let path = CrewTalkRoomAPI.path(code: session.code, action: "messages")
        _ = try await post(path, body: CrewTalkRoomAPI.messageBody(pid: session.pid, text: text))
    }

    /// Best effort. The room also expires on its own.
    static func leave(_ session: CrewTalkRoomSession) async {
        let path = CrewTalkRoomAPI.path(code: session.code, action: "leave")
        guard let body = try? CrewTalkRoomAPI.leaveBody(pid: session.pid) else { return }
        _ = try? await post(path, body: body)
    }

    /// Every event for this seat. Ends when the connection drops; the caller decides whether to reconnect.
    static func events(for session: CrewTalkRoomSession) -> AsyncThrowingStream<CrewTalkRoomEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard var components = URLComponents(string: SpanishTranslatorAPI.defaultAPIBase) else {
                        throw CrewTalkConversationError(message: "Bad API address.")
                    }
                    components.path = CrewTalkRoomAPI.path(code: session.code, action: "events")
                    components.queryItems = [URLQueryItem(name: "pid", value: session.pid)]
                    guard let url = components.url else {
                        throw CrewTalkConversationError(message: "Bad API address.")
                    }
                    var request = URLRequest(url: url)
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    // The server pings every 15 s, so a quiet minute means the link is dead.
                    request.timeoutInterval = 60
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard (200..<300).contains(status) else {
                        throw CrewTalkConversationError(
                            message: status == 404 ? "That room has ended." : "Room connection failed (HTTP \(status)).",
                            fatal: status == 404
                        )
                    }
                    for try await line in bytes.lines {
                        guard let event = CrewTalkRoomEvent.parse(sseLine: line) else { continue }
                        continuation.yield(event)
                        if case .closed = event { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func post(_ path: String, body: Data) async throws -> [String: Any] {
        guard let url = URL(string: SpanishTranslatorAPI.defaultAPIBase + path) else {
            throw CrewTalkConversationError(message: "Bad API address.")
        }
        do {
            return try await BeckifyAIClient.postJSON(url: url, body: body, bearerToken: "", timeout: 15)
        } catch let error as VisionHTTPError {
            throw CrewTalkConversationError(message: error.message)
        }
    }
}
