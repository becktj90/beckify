import BeckifyMath
import Foundation

/// Network calls for Conversation Mode. Translate and speak reuse the shipped
/// `/api/translate` and `/api/speak` contracts. Rooms use `/api/rooms`.
enum CrewTalkTranslationService {
    /// Translate what the speaker said into the other person's language.
    static func translate(
        _ text: String,
        from speaker: CrewTalkConversationLanguage
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
            voiceMode: .jobsite
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
    static func speechAudio(_ text: String, crew: CrewTalkMember) async throws -> Data {
        guard let url = SpanishTranslatorAPI.speakURL(customEndpoint: "") else {
            throw CrewTalkConversationError(message: "Speak needs the Beckify API.")
        }
        let body = try SpanishTranslatorAPI.speakRequestJSON(
            text: SpanishTranslatorAPI.clampSpeakText(text),
            voiceMode: .jobsite,
            language: crew.speakLanguage,
            crew: crew
        )
        do {
            let result = try await BeckifyAIClient.postAudio(url: url, body: body, bearerToken: "", timeout: 30)
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
