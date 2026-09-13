import Foundation
import WebKit

/// Serves the packed Phaser cabinet from a real URL origin.
/// `file://` + `loadFileURL` can leave ES modules inert under WebKit CORS.
/// `kestrel-heavy://game/…` is same-origin for `./js/main.js` and audio/.
enum KestrelHeavyOrigin {
    static let scheme = "kestrel-heavy"
    static let host = "game"
    static let index = URL(string: "kestrel-heavy://game/index.html")!

    static func packRoot() -> URL? {
        let bundled = Bundle.main.bundleURL.appendingPathComponent("Game", isDirectory: true)
        let index = bundled.appendingPathComponent("index.html")
        if FileManager.default.fileExists(atPath: index.path) {
            return bundled
        }
        return nil
    }
}

final class KestrelHeavySchemeHandler: NSObject, WKURLSchemeHandler {
    private let lock = NSLock()
    private var stopped = Set<ObjectIdentifier>()

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let id = ObjectIdentifier(urlSchemeTask)
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        guard let fileURL = Self.fileURL(for: url) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let mime = Self.mimeType(for: fileURL.pathExtension)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": mime,
                    "Content-Length": String(data.count),
                    "Access-Control-Allow-Origin": "*",
                    "Cache-Control": "public, max-age=0",
                ]
            )
            guard let response else {
                urlSchemeTask.didFailWithError(URLError(.cannotParseResponse))
                return
            }
            if isStopped(id) { return }
            urlSchemeTask.didReceive(response)
            if isStopped(id) { return }
            urlSchemeTask.didReceive(data)
            if isStopped(id) { return }
            urlSchemeTask.didFinish()
        } catch {
            if !isStopped(id) {
                urlSchemeTask.didFailWithError(error)
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        lock.lock()
        stopped.insert(ObjectIdentifier(urlSchemeTask))
        lock.unlock()
    }

    private func isStopped(_ id: ObjectIdentifier) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopped.contains(id)
    }

    static func fileURL(for url: URL) -> URL? {
        guard url.scheme == KestrelHeavyOrigin.scheme else { return nil }
        var path = url.path
        if path.hasPrefix("/") { path.removeFirst() }
        if path.isEmpty { path = "index.html" }
        let parts = path.split(separator: "/").map(String.init)
        if parts.isEmpty || parts.contains("..") || parts.contains("~") { return nil }
        guard var root = KestrelHeavyOrigin.packRoot() else { return nil }
        for part in parts {
            root.appendPathComponent(part)
        }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDir), !isDir.boolValue else {
            return nil
        }
        return root
    }

    static func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": return "text/html; charset=utf-8"
        case "js", "mjs": return "text/javascript; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "json": return "application/json; charset=utf-8"
        case "svg": return "image/svg+xml"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "mp3": return "audio/mpeg"
        case "ogg": return "audio/ogg"
        case "wav": return "audio/wav"
        case "md", "txt": return "text/plain; charset=utf-8"
        default: return "application/octet-stream"
        }
    }
}
