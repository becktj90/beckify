import Foundation
import UIKit
import BeckifyMath

/// URLSession client for the standalone Look Check app.
/// Encoding happens only here. Taking or choosing a photo does not upload it.
enum LookCheckVisionClient {
    struct PreparedUpload: Equatable {
        var dataURL: String
        var mimeType: String
        var byteCount: Int
    }

    static func prepareUpload(from image: UIImage) -> PreparedUpload? {
        guard let jpeg = uprightJPEG(from: image) else { return nil }
        let dataURL = PhotoLookCheck.dataURL(jpegBase64: jpeg.base64EncodedString())
        return PreparedUpload(dataURL: dataURL, mimeType: "image/jpeg", byteCount: jpeg.count)
    }

    static func analyze(
        dataURL: String,
        mimeType: String,
        url: URL,
        roastMode: LookRoastMode
    ) async throws -> PhotoLookDraft {
        let body = try PhotoLookCheck.requestJSON(
            imageBase64: dataURL,
            mimeType: mimeType,
            roastMode: roastMode
        )
        do {
            return try await post(url: url, body: body)
        } catch let error as LookCheckHTTPError where error.status == 502 || error.status == 504 {
            try await Task.sleep(nanoseconds: 800_000_000)
            return try await post(url: url, body: body)
        }
    }

    private static func post(url: URL, body: Data) async throws -> PhotoLookDraft {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if status < 200 || status >= 300 {
            let retry = retryAfter(http: http, payload: payload)
            let message = PhotoLookCheck.formatVisionError(
                status: status,
                message: payload["error"] as? String,
                retryAfter: retry,
                endpoint: url.absoluteString
            )
            throw LookCheckHTTPError(status: status, message: message)
        }
        return PhotoLookCheck.normalizeDraft(payload)
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
        let scaled = scaleToMaxEdge(rendered, edge: PhotoLookCheck.maxUploadEdge)
        for quality in [0.82, 0.7, 0.55, 0.4] as [CGFloat] {
            guard let data = scaled.jpegData(compressionQuality: quality) else { continue }
            if data.count <= PhotoLookCheck.maxUploadBytes { return data }
        }
        return scaled.jpegData(compressionQuality: 0.32).flatMap { data in
            data.count <= PhotoLookCheck.maxUploadBytes ? data : nil
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

struct LookCheckHTTPError: LocalizedError {
    var status: Int
    var message: String
    var errorDescription: String? { message }
}
