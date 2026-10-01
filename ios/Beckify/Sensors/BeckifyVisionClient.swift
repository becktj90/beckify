import Foundation
import UIKit
import BeckifyMath

/// Outcome of one user-initiated HTTPS vision POST. Encoding happens only here.
struct VisionHTTPError: LocalizedError {
    var status: Int
    var message: String
    var errorDescription: String? { message }
}

/// Small shared HTTPS POST helper for Beckify API text routes (translate / speak);
/// Look Check / OCR photo clients stay separate until a later consolidation.
enum BeckifyAIClient {
    /// POST `application/json` and return the decoded object on 2xx.
    /// Throws `VisionHTTPError` with HTTP status (0 = transport) on failure.
    static func postJSON(
        url: URL,
        body: Data,
        bearerToken: String = "",
        timeout: TimeInterval = 30,
        retryOnBadGateway: Bool = false
    ) async throws -> [String: Any] {
        do {
            return try await postOnce(url: url, body: body, bearerToken: bearerToken, timeout: timeout)
        } catch let error as VisionHTTPError where retryOnBadGateway && (error.status == 502 || error.status == 504) {
            try await Task.sleep(nanoseconds: 800_000_000)
            return try await postOnce(url: url, body: body, bearerToken: bearerToken, timeout: timeout)
        }
    }

    /// POST `application/json` and return raw audio bytes on 2xx (`audio/mpeg` / `audio/wav`).
    /// On error responses that are JSON, surfaces `error` when present.
    static func postAudio(
        url: URL,
        body: Data,
        bearerToken: String = "",
        timeout: TimeInterval = 30
    ) async throws -> (data: Data, contentType: String, model: String?, voice: String?) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg, audio/wav, application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = timeout
        let trimmed = bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw VisionHTTPError(status: 0, message: error.localizedDescription)
        }
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        let contentType = (http?.value(forHTTPHeaderField: "Content-Type") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if status < 200 || status >= 300 {
            let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            let message = (payload["error"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw VisionHTTPError(
                status: status,
                message: (message?.isEmpty == false) ? message! : "Beckify speak API unavailable (HTTP \(status))."
            )
        }
        guard !data.isEmpty else {
            throw VisionHTTPError(status: status, message: "Speak returned empty audio.")
        }
        let model = http?.value(forHTTPHeaderField: "X-Beckify-TTS-Model")
        let voice = http?.value(forHTTPHeaderField: "X-Beckify-TTS-Voice")
        return (data, contentType, model, voice)
    }

    private static func postOnce(
        url: URL,
        body: Data,
        bearerToken: String,
        timeout: TimeInterval
    ) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        let trimmed = bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw VisionHTTPError(status: 0, message: error.localizedDescription)
        }
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if status < 200 || status >= 300 {
            let message = (payload["error"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw VisionHTTPError(
                status: status,
                message: (message?.isEmpty == false) ? message! : "Beckify API unavailable (HTTP \(status))."
            )
        }
        return payload
    }
}

/// URLSession client for `/api/analyze-nameplate` and `/api/analyze-panel`.
/// JPEG encode matches Look Check (8 MB / 2048 edge). Look Check keeps its
/// own `PhotoLookCheckClient`. Photos are encoded only after Analyze.
enum BeckifyVisionClient {
    struct PreparedUpload: Equatable {
        var dataURL: String
        var mimeType: String
        var byteCount: Int
    }

    static func prepareUpload(from image: UIImage) -> PreparedUpload? {
        guard let jpeg = uprightJPEG(from: image) else { return nil }
        let dataURL = BeckifyVisionAPI.dataURL(jpegBase64: jpeg.base64EncodedString())
        return PreparedUpload(dataURL: dataURL, mimeType: "image/jpeg", byteCount: jpeg.count)
    }

    static func postJSON(
        url: URL,
        body: Data,
        token: String,
        timeout: TimeInterval = 60,
        task: BeckifyVisionTask = .look
    ) async throws -> [String: Any] {
        do {
            return try await post(url: url, body: body, token: token, timeout: timeout, task: task)
        } catch let error as VisionHTTPError where error.status == 502 || error.status == 504 {
            try await Task.sleep(nanoseconds: 800_000_000)
            return try await post(url: url, body: body, token: token, timeout: timeout, task: task)
        }
    }

    static func analyze(
        image: UIImage,
        task: BeckifyVisionTask,
        customEndpoint: String,
        token: String,
        timeout: TimeInterval = 60
    ) async throws -> [String: Any] {
        guard let url = BeckifyVisionAPI.analyzeURL(task: task, customEndpoint: customEndpoint) else {
            throw VisionHTTPError(
                status: 0,
                message: "Analyze needs an HTTPS endpoint. Leave the custom URL blank to use api.beckify.com, or enter a https:// URL."
            )
        }
        guard let prepared = prepareUpload(from: image) else {
            throw VisionHTTPError(status: 0, message: "Could not encode an upright JPEG under 8 MB.")
        }
        let body = try BeckifyVisionAPI.requestJSON(
            imageBase64: prepared.dataURL,
            mimeType: prepared.mimeType,
            task: task
        )
        return try await postJSON(
            url: url,
            body: body,
            token: BeckifyVisionAPI.authorizationToken(customEndpoint: customEndpoint, token: token),
            timeout: timeout,
            task: task
        )
    }

    private static func post(
        url: URL,
        body: Data,
        token: String,
        timeout: TimeInterval,
        task: BeckifyVisionTask
    ) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if status < 200 || status >= 300 {
            let retry = retryAfter(http: http, payload: payload)
            let message = BeckifyVisionAPI.formatVisionError(
                status: status,
                message: payload["error"] as? String,
                retryAfter: retry,
                endpoint: url.absoluteString,
                task: task
            )
            throw VisionHTTPError(status: status, message: message)
        }
        return payload
    }

    private static func retryAfter(http: HTTPURLResponse?, payload: [String: Any]) -> Int {
        if let header = http?.value(forHTTPHeaderField: "Retry-After"), let n = Int(header), n > 0 {
            return n
        }
        if let n = payload["retryAfter"] as? Int, n > 0 { return n }
        if let n = payload["retry_after"] as? Int, n > 0 { return n }
        return 0
    }

    private static func uprightJPEG(from image: UIImage) -> Data? {
        let rendered = uprightImage(image)
        let scaled = scaleToMaxEdge(rendered, edge: BeckifyVisionAPI.maxUploadEdge)
        for quality in [0.82, 0.7, 0.55, 0.4] as [CGFloat] {
            guard let data = scaled.jpegData(compressionQuality: quality) else { continue }
            if data.count <= BeckifyVisionAPI.maxUploadBytes { return data }
        }
        return scaled.jpegData(compressionQuality: 0.32).flatMap { data in
            data.count <= BeckifyVisionAPI.maxUploadBytes ? data : nil
        }
    }

    private static func uprightImage(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func scaleToMaxEdge(_ image: UIImage, edge: Int) -> UIImage {
        let maxSide = max(image.size.width, image.size.height)
        guard maxSide > CGFloat(edge), maxSide > 0 else { return image }
        let scale = CGFloat(edge) / maxSide
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
