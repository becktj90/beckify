import Foundation

/// User-initiated cloud vision tasks that POST to `api.beckify.com`.
/// Nameplate and panel Analyze use this type. Look Check keeps `PhotoLookCheck`
/// (`.look` exists so the POST body and path stay aligned with that contract).
public enum BeckifyVisionTask: String, Equatable, Sendable {
    case look
    case nameplate
    case panel
}

/// HTTPS contract for Motor Nameplate OCR and Panel Directory cloud Analyze.
///
/// Mirrors `PhotoLookCheck` (`imageBase64` + `mimeType` + `task`, HTTPS-only,
/// default `https://api.beckify.com`). Limits and host rules alias that type
/// so Look Check stays the source of truth. Do not rewrite Look Check to use
/// this surface. Photos leave the device only when the user taps Analyze.
/// Never use `beckify.com` (GitHub Pages returns 405).
public enum BeckifyVisionAPI {
    public static let defaultAPIBase = PhotoLookCheck.defaultAPIBase
    public static let maxPickBytes = PhotoLookCheck.maxPickBytes
    public static let maxUploadBytes = PhotoLookCheck.maxUploadBytes
    public static let maxUploadEdge = PhotoLookCheck.maxUploadEdge
    public static let disclaimer =
        "Photos upload only when you tap Analyze."

    public static func analyzePath(for task: BeckifyVisionTask) -> String {
        switch task {
        case .look: return "/api/analyze-look"
        case .nameplate: return "/api/analyze-nameplate"
        case .panel: return "/api/analyze-panel"
        }
    }

    public static func defaultAnalyzeURL(for task: BeckifyVisionTask) -> URL? {
        analyzeURL(task: task, customEndpoint: nil, apiBase: defaultAPIBase)
    }

    /// Custom HTTPS URL wins. Otherwise `{apiBase}{task path}`.
    /// Non-HTTPS bases are rejected — same rule as the website VLM helper.
    public static func analyzeURL(
        task: BeckifyVisionTask,
        customEndpoint: String?,
        apiBase: String? = defaultAPIBase
    ) -> URL? {
        if let custom = httpsBase(customEndpoint), let url = URL(string: custom) {
            return url
        }
        guard let base = httpsBase(apiBase), !base.isEmpty else { return nil }
        return URL(string: base + analyzePath(for: task))
    }

    public static func httpsBase(_ raw: String?) -> String? {
        PhotoLookCheck.httpsBase(raw)
    }

    /// POST body matching website `analyzeLook` / nameplate / panel helpers.
    public static func requestBody(
        imageBase64: String,
        mimeType: String,
        task: BeckifyVisionTask
    ) -> [String: String] {
        [
            "imageBase64": imageBase64,
            "mimeType": mimeType,
            "task": task.rawValue,
        ]
    }

    public static func requestJSON(
        imageBase64: String,
        mimeType: String,
        task: BeckifyVisionTask
    ) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: requestBody(imageBase64: imageBase64, mimeType: mimeType, task: task),
            options: []
        )
    }

    /// Apex GitHub Pages host only — not `api.beckify.com`.
    public static func hostIsGitHubPages(_ raw: String?) -> Bool {
        PhotoLookCheck.hostIsGitHubPages(raw)
    }

    /// Bearer tokens stay off the default Beckify host, even if that host is
    /// pasted as a "custom" URL. Look Check keeps its own PhotoLookCheck rule.
    public static func authorizationToken(customEndpoint: String?, token: String) -> String {
        guard let custom = httpsBase(customEndpoint) else { return "" }
        if hostIsGitHubPages(custom) { return "" }
        if let host = URL(string: custom)?.host?.lowercased(), host == "api.beckify.com" {
            return ""
        }
        return token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func formatVisionError(
        status: Int,
        message: String?,
        retryAfter: Int = 0,
        endpoint: String? = nil,
        task: BeckifyVisionTask
    ) -> String {
        let noun = errorNoun(for: task)
        if status == 429 {
            if retryAfter >= 60 {
                return "Too many \(noun)s. Try again in about \((retryAfter + 59) / 60) min."
            }
            if retryAfter > 0 {
                return "Too many \(noun)s. Try again in \(retryAfter) s."
            }
            return "Too many \(noun)s right now. Wait a few minutes."
        }
        if status == 413 {
            return message?.isEmpty == false
                ? message!
                : task == .look
                    ? "The photo is too large for Analyze Look (8 MB after JPEG encode)."
                    : "The photo is too large for Analyze (8 MB after JPEG encode)."
        }
        if status == 504 {
            return "The vision provider timed out. Please try again."
        }
        if status == 404 || status == 405 {
            let path = analyzePath(for: task)
            let action = task == .look ? "Analyze Look" : "Analyze"
            if hostIsGitHubPages(endpoint) {
                return "The Beckify \(noun) API is unavailable (HTTP \(status)). GitHub Pages cannot accept \(action). Use https://api.beckify.com or a custom HTTPS endpoint."
            }
            return "The Beckify \(noun) API is unavailable (HTTP \(status)). A stale or missing \(path) route also returns this. Use https://api.beckify.com or a custom HTTPS endpoint."
        }
        if status == 503 {
            return message?.isEmpty == false
                ? message!
                : "The Beckify vision API is not configured (missing provider key)."
        }
        if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message
        }
        return "\(failureNoun(for: task)) failed with HTTP \(status)."
    }

    public static func dataURL(jpegBase64: String) -> String {
        PhotoLookCheck.dataURL(jpegBase64: jpegBase64)
    }

    public static func mimeType(fromDataURL dataURL: String, fallback: String = "image/jpeg") -> String {
        PhotoLookCheck.mimeType(fromDataURL: dataURL, fallback: fallback)
    }

    /// Unwrap `{ analysis | draft | raw }` the way website `visionDraftInput` does.
    public static func visionDraftInput(_ raw: Any?) -> [String: Any] {
        guard let raw else { return [:] }
        if let text = raw as? String {
            if let data = text.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) {
                return visionDraftInput(parsed)
            }
            return [:]
        }
        guard let object = raw as? [String: Any] else { return [:] }
        if let analysis = object["analysis"], !(analysis is NSNull) {
            let nested = visionDraftInput(analysis)
            if !nested.isEmpty { return nested }
        }
        if let draft = object["draft"], !(draft is NSNull) {
            let nested = visionDraftInput(draft)
            if !nested.isEmpty { return nested }
        }
        return object
    }

    public static func stringValue(_ raw: Any?) -> String? {
        guard let raw, !(raw is NSNull) else { return nil }
        if let s = raw as? String {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let n = raw as? Bool {
            return n ? "true" : "false"
        }
        if let n = raw as? NSNumber {
            let value = n.doubleValue
            if value == floor(value), value >= Double(Int.min), value <= Double(Int.max) {
                return String(Int(value))
            }
            return String(value)
        }
        return String(describing: raw)
    }

    public static func stringList(_ raw: Any?) -> [String] {
        guard let raw else { return [] }
        if let rows = raw as? [Any] {
            return rows.compactMap { item in
                stringValue(item)
            }
        }
        return []
    }

    /// `{ value, confidence }` cell or a bare value.
    public static func unwrapValue(_ raw: Any?) -> Any? {
        guard let raw, !(raw is NSNull) else { return nil }
        if let object = raw as? [String: Any], object.keys.contains("value") {
            let value = object["value"]
            if value is NSNull { return nil }
            return value
        }
        return raw
    }

    public static func unwrapConfidence(_ raw: Any?, fallback: Double = 0.5) -> Double {
        if let object = raw as? [String: Any] {
            if let n = asFiniteDouble(object["confidence"]) {
                return clampConfidence(n)
            }
        }
        return clampConfidence(fallback)
    }

    public static func clampConfidence(_ value: Double) -> Double {
        var n = value
        if n > 1, n <= 100 { n /= 100 }
        return min(max(n, 0), 1)
    }

    public static func asFiniteDouble(_ raw: Any?) -> Double? {
        guard let raw, !(raw is NSNull) else { return nil }
        if let n = raw as? Double, n.isFinite { return n }
        if let n = raw as? Int { return Double(n) }
        if let n = raw as? NSNumber { return n.doubleValue }
        if let s = raw as? String {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "")
            if trimmed.isEmpty { return nil }
            if dualNumberPair(trimmed) != nil { return nil }
            return Double(trimmed)
        }
        return nil
    }

    public static func formatNumber(_ value: Double) -> String {
        if value == floor(value), value >= Double(Int.min), value <= Double(Int.max) {
            return String(Int(value))
        }
        var text = String(value)
        if text.contains("e") || text.contains("E") {
            text = String(format: "%g", value)
        }
        return text
    }

    public static func dualNumberPair(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "/")
        guard parts.count == 2 else { return nil }
        let left = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let right = String(parts[1]).trimmingCharacters(in: .whitespaces)
        guard Double(left) != nil, Double(right) != nil else { return nil }
        return "\(left)/\(right)"
    }

    // MARK: - Internals

    private static func errorNoun(for task: BeckifyVisionTask) -> String {
        switch task {
        case .look: return "look check"
        case .nameplate: return "nameplate analysis"
        case .panel: return "panel analysis"
        }
    }

    private static func failureNoun(for task: BeckifyVisionTask) -> String {
        switch task {
        case .look: return "Look check"
        case .nameplate: return "Nameplate analysis"
        case .panel: return "Panel analysis"
        }
    }
}

public enum BeckifyVisionAPIError: Error, Equatable, Sendable {
    case unreadableJSON
    case missingPhoto
    case photoTooLarge
    case httpsRequired
    case httpStatus(Int, String)
}
