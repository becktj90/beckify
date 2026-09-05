import Foundation

/// Playful photo verdict from the website Look Check product.
/// Distinct from the Wi-Fi / Cellular **Online / Captive** hotspot-detect probe
/// (`LookCheck`). Entertainment only — not medical or dating advice.
public enum PhotoLookVerdict: String, Equatable, Sendable, CaseIterable {
    case looksGood = "looks_good"
    case mixed = "mixed"
    case looksBad = "looks_bad"
    case noPerson = "no_person"
    case declined = "declined"

    public var badge: String {
        switch self {
        case .looksGood: return "Looks good"
        case .looksBad: return "Looks off"
        case .noPerson: return "No person"
        case .declined: return "Not rated"
        case .mixed: return "Mixed"
        }
    }

    public var defaultHeadline: String {
        switch self {
        case .looksGood: return "You look good in this frame."
        case .looksBad: return "This is not your strongest photo."
        case .noPerson: return "Nobody is in this shot — rating the photo instead."
        case .declined: return "This photo cannot be rated."
        case .mixed: return "Some things work. Some things to retake."
        }
    }
}

/// 0…100 photo-quality scores. Null when declined or unused.
public struct PhotoLookMetrics: Equatable, Sendable {
    public var lighting: Int?
    public var framing: Int?
    public var expression: Int?
    public var sharpness: Int?
    public var overall: Int?

    public init(
        lighting: Int? = nil,
        framing: Int? = nil,
        expression: Int? = nil,
        sharpness: Int? = nil,
        overall: Int? = nil
    ) {
        self.lighting = lighting
        self.framing = framing
        self.expression = expression
        self.sharpness = sharpness
        self.overall = overall
    }

    public var hasAnyScore: Bool {
        [lighting, framing, expression, sharpness, overall].contains { $0 != nil }
    }

    public static let metricRows: [(key: String, label: String)] = [
        ("lighting", "Lighting"),
        ("framing", "Framing"),
        ("expression", "Expression"),
        ("sharpness", "Sharpness"),
        ("overall", "Overall"),
    ]

    public func value(forKey key: String) -> Int? {
        switch key {
        case "lighting": return lighting
        case "framing": return framing
        case "expression": return expression
        case "sharpness": return sharpness
        case "overall": return overall
        default: return nil
        }
    }
}

/// Normalized Look Check draft — same shape as website `normalizeLookDraft`.
public struct PhotoLookDraft: Equatable, Sendable {
    public var task: String
    public var verdict: PhotoLookVerdict
    public var score: Int?
    public var headline: String
    public var summary: String
    public var metrics: PhotoLookMetrics
    public var reasons: [String]
    public var fixes: [String]
    public var photoNotes: [String]
    public var warnings: [String]

    public init(
        task: String = PhotoLookCheck.task,
        verdict: PhotoLookVerdict,
        score: Int? = nil,
        headline: String = "",
        summary: String = "",
        metrics: PhotoLookMetrics = PhotoLookMetrics(),
        reasons: [String] = [],
        fixes: [String] = [],
        photoNotes: [String] = [],
        warnings: [String] = []
    ) {
        self.task = task
        self.verdict = verdict
        self.score = score
        self.headline = headline
        self.summary = summary
        self.metrics = metrics
        self.reasons = reasons
        self.fixes = fixes
        self.photoNotes = photoNotes
        self.warnings = warnings
    }

    public var displayHeadline: String {
        let trimmed = headline.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? verdict.defaultHeadline : trimmed
    }

    public var showsMetrics: Bool {
        verdict != .declined && metrics.hasAnyScore
    }

    public var showsScore: Bool {
        verdict != .declined && score != nil
    }

    public var copyLine: String {
        var parts = ["Look Check: \(verdict.badge)"]
        if showsScore, let score {
            parts.append("score \(score)")
        }
        let head = displayHeadline.trimmingCharacters(in: .whitespacesAndNewlines)
        if !head.isEmpty { parts.append(head) }
        return parts.joined(separator: " · ")
    }
}

/// Shared Look Check photo contract with the website `/api/analyze-look` path.
/// Parsing lives here so Linux tests can lock the web-compatible draft shape.
public enum PhotoLookCheck {
    public static let task = BeckifyVisionTask.look.rawValue
    /// Same host the website injects via `meta[name="beckify-api-base-url"]`.
    /// Do not use `https://beckify.com` — GitHub Pages cannot POST (`405`).
    public static let defaultAPIBase = BeckifyVisionAPI.defaultAPIBase
    public static let analyzePath = BeckifyVisionAPI.analyzePath(for: .look)
    public static let maxPickBytes = BeckifyVisionAPI.maxPickBytes
    public static let maxUploadBytes = BeckifyVisionAPI.maxUploadBytes
    public static let maxUploadEdge = BeckifyVisionAPI.maxUploadEdge
    public static let disclaimer =
        "Entertainment only — not medical or dating advice. Photos upload only when you tap Analyze Look."

    public static func defaultAnalyzeURL() -> URL? {
        BeckifyVisionAPI.defaultAnalyzeURL(for: .look)
    }

    /// Custom HTTPS URL wins. Otherwise `{apiBase}/api/analyze-look`.
    /// Non-HTTPS bases are rejected — same rule as the website VLM helper.
    public static func analyzeURL(customEndpoint: String?, apiBase: String? = defaultAPIBase) -> URL? {
        BeckifyVisionAPI.analyzeURL(task: .look, customEndpoint: customEndpoint, apiBase: apiBase)
    }

    public static func httpsBase(_ raw: String?) -> String? {
        BeckifyVisionAPI.httpsBase(raw)
    }

    /// Clamp a metric / score to 0…100 the way website `asLookScore` does.
    public static func asLookScore(_ value: Any?) -> Int? {
        guard let value else { return nil }
        if value is NSNull { return nil }
        if let s = value as? String {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            guard let n = Double(trimmed), n.isFinite else { return nil }
            return clampScore(n)
        }
        if let n = value as? Int { return clampScore(Double(n)) }
        if let n = value as? Double, n.isFinite { return clampScore(n) }
        if let n = value as? NSNumber { return clampScore(n.doubleValue) }
        return nil
    }

    public static func clampScore(_ n: Double) -> Int {
        Int((min(100, max(0, n))).rounded())
    }

    public static func parseVerdict(_ raw: String?) -> PhotoLookVerdict {
        let folded = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return PhotoLookVerdict(rawValue: folded) ?? .mixed
    }

    /// Accepts the website payload (`analysis` / `draft` / raw object) or a JSON string.
    public static func normalizeDraft(_ raw: Any?) -> PhotoLookDraft {
        let object = visionDraftInput(raw)
        let verdict = parseVerdict(stringValue(object["verdict"]))
        var score = asLookScore(object["score"])
        if verdict == .declined { score = nil }

        var summary = firstNonEmpty(
            stringValue(object["summary"]),
            stringValue(object["brief"])
        )
        if verdict == .declined, summary.isEmpty {
            summary = stringValue(object["headline"]) ?? ""
        }

        return PhotoLookDraft(
            task: task,
            verdict: verdict,
            score: score,
            headline: stringValue(object["headline"]) ?? "",
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
            metrics: normalizeMetrics(object, overallScore: score, verdict: verdict),
            reasons: stringList(object["reasons"]),
            fixes: stringList(object["fixes"]),
            photoNotes: stringList(object["photoNotes"] ?? object["photo_notes"]),
            warnings: stringList(object["warnings"])
        )
    }

    public static func normalizeDraft(jsonData: Data) throws -> PhotoLookDraft {
        let value = try JSONSerialization.jsonObject(with: jsonData)
        return normalizeDraft(value)
    }

    public static func normalizeDraft(jsonText: String) throws -> PhotoLookDraft {
        guard let data = jsonText.data(using: .utf8) else {
            throw PhotoLookCheckError.unreadableJSON
        }
        return try normalizeDraft(jsonData: data)
    }

    /// POST body matching website `analyzeLook` / `lookRunSameOrigin`.
    public static func requestBody(imageBase64: String, mimeType: String) -> [String: String] {
        BeckifyVisionAPI.requestBody(imageBase64: imageBase64, mimeType: mimeType, task: .look)
    }

    public static func requestJSON(imageBase64: String, mimeType: String) throws -> Data {
        try BeckifyVisionAPI.requestJSON(imageBase64: imageBase64, mimeType: mimeType, task: .look)
    }

    /// Apex GitHub Pages host only — not `api.beckify.com`.
    public static func hostIsGitHubPages(_ raw: String?) -> Bool {
        BeckifyVisionAPI.hostIsGitHubPages(raw)
    }

    /// Custom-endpoint Bearer tokens stay off the default Beckify proxy.
    public static func authorizationToken(customEndpoint: String?, token: String) -> String {
        BeckifyVisionAPI.authorizationToken(customEndpoint: customEndpoint, token: token)
    }

    public static func formatVisionError(status: Int, message: String?, retryAfter: Int = 0, endpoint: String? = nil) -> String {
        BeckifyVisionAPI.formatVisionError(
            status: status,
            message: message,
            retryAfter: retryAfter,
            endpoint: endpoint,
            task: .look
        )
    }

    public static func dataURL(jpegBase64: String) -> String {
        BeckifyVisionAPI.dataURL(jpegBase64: jpegBase64)
    }

    public static func mimeType(fromDataURL dataURL: String, fallback: String = "image/jpeg") -> String {
        BeckifyVisionAPI.mimeType(fromDataURL: dataURL, fallback: fallback)
    }

    // MARK: - Internals

    private static func visionDraftInput(_ raw: Any?) -> [String: Any] {
        BeckifyVisionAPI.visionDraftInput(raw)
    }

    private static func normalizeMetrics(
        _ raw: [String: Any],
        overallScore: Int?,
        verdict: PhotoLookVerdict
    ) -> PhotoLookMetrics {
        if verdict == .declined {
            return PhotoLookMetrics()
        }
        let src: [String: Any]
        if let metrics = raw["metrics"] as? [String: Any] {
            src = metrics
        } else {
            src = raw
        }
        var metrics = PhotoLookMetrics(
            lighting: asLookScore(src["lighting"]),
            framing: asLookScore(src["framing"]),
            expression: asLookScore(src["expression"]),
            sharpness: asLookScore(src["sharpness"] ?? src["focus"]),
            overall: asLookScore(src["overall"])
        )
        if metrics.overall == nil {
            metrics.overall = overallScore
        }
        if verdict == .noPerson {
            metrics.expression = nil
        }
        return metrics
    }

    private static func stringList(_ raw: Any?) -> [String] {
        guard let raw else { return [] }
        if let rows = raw as? [Any] {
            return rows.compactMap { item in
                let text = String(describing: item).trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? nil : text
            }
        }
        return []
    }

    private static func stringValue(_ raw: Any?) -> String? {
        guard let raw, !(raw is NSNull) else { return nil }
        if let s = raw as? String { return s }
        return String(describing: raw)
    }

    private static func firstNonEmpty(_ values: String?...) -> String {
        for value in values {
            if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return ""
    }
}

public enum PhotoLookCheckError: Error, Equatable, Sendable {
    case unreadableJSON
    case missingPhoto
    case photoTooLarge
    case httpsRequired
    case httpStatus(Int, String)
}
