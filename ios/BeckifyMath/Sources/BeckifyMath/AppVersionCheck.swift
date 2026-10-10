import Foundation

/// Semantic version comparison and update-check throttling for the
/// "update available" prompt. Pure logic so it is unit-testable on Linux.
public enum AppVersionCheck {
    /// Numeric components of a dotted version ("1.0.6" → [1, 0, 6]).
    /// Non-numeric suffixes in a component are ignored ("2b" → 2).
    public static func components(_ version: String) -> [Int] {
        version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ".")
            .map { part in Int(part.prefix(while: \.isNumber)) ?? 0 }
    }

    /// Compares two versions component-wise, padding missing parts with 0,
    /// so "1.0" == "1.0.0" and "1.0.10" > "1.0.9".
    public static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let a = components(lhs), b = components(rhs)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x < y { return .orderedAscending }
            if x > y { return .orderedDescending }
        }
        return .orderedSame
    }

    /// True only when the App Store version is strictly newer than installed.
    public static func isStoreNewer(store: String, installed: String) -> Bool {
        guard !components(store).isEmpty, !components(installed).isEmpty else { return false }
        return compare(store, installed) == .orderedDescending
    }

    /// Throttle: check at most once per `interval` (default one day).
    public static func shouldCheck(lastCheck: Date?, now: Date, interval: TimeInterval = 86_400) -> Bool {
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= interval || now < lastCheck
    }

    /// Extracts `results[0].version` from an iTunes lookup response.
    public static func storeVersion(fromLookup data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = obj["results"] as? [[String: Any]],
              let version = results.first?["version"] as? String,
              !version.isEmpty
        else { return nil }
        return version
    }
}
