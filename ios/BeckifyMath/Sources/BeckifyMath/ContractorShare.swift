import Foundation

/// Snapshot a contractor can host as a public page. The link is not a second calculator.
public enum ContractorShareTool: String, Codable, Equatable, Sendable {
    case voltageDrop = "voltage-drop"
    case conduitFill = "conduit-fill"
}

public struct ContractorShareField: Equatable, Codable, Sendable {
    public var label: String
    public var value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

public enum ContractorShareValidation {
    public static let maxContractor = 80
    public static let maxFields = 16
    public static let maxLabel = 80
    public static let maxValue = 120

    public static func normalizedContractor(_ raw: String) -> String? {
        clean(raw, max: maxContractor)
    }

    public static func normalizedFields(_ fields: [ContractorShareField]) -> [ContractorShareField]? {
        guard (1...maxFields).contains(fields.count) else { return nil }
        var rows: [ContractorShareField] = []
        rows.reserveCapacity(fields.count)
        for field in fields {
            guard let label = clean(field.label, max: maxLabel),
                  let value = clean(field.value, max: maxValue) else { return nil }
            rows.append(ContractorShareField(label: label, value: value))
        }
        return rows
    }

    /// JSON body for `POST https://api.beckify.com/api/share`. Nil when the snapshot is not hostable.
    public static func requestJSON(tool: ContractorShareTool, contractor: String, fields: [ContractorShareField]) -> Data? {
        guard let name = normalizedContractor(contractor), let rows = normalizedFields(fields) else { return nil }
        let body: [String: Any] = [
            "tool": tool.rawValue,
            "contractor": name,
            "fields": rows.map { ["label": $0.label, "value": $0.value] },
        ]
        return try? JSONSerialization.data(withJSONObject: body)
    }

    private static func clean(_ raw: String, max: Int) -> String? {
        guard raw.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }) else { return nil }
        let collapsed = raw.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard !collapsed.isEmpty, collapsed.count <= max else { return nil }
        return collapsed
    }
}

public enum ContractorShareLink {
    public static let createURL = URL(string: "https://api.beckify.com/api/share")!

    /// Accept only a Beckify page URL returned by the share API.
    public static func acceptedPageURL(from data: Data) -> URL? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = object["url"] as? String,
              let url = URL(string: raw),
              url.scheme?.lowercased() == "https",
              url.user == nil,
              let host = url.host?.lowercased(),
              host == "beckify.com" || host == "www.beckify.com"
        else { return nil }
        let path = url.path
        guard path.hasPrefix("/share/") else { return nil }
        let token = String(path.dropFirst("/share/".count))
        guard token.range(of: #"^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil else { return nil }
        return url
    }
}
