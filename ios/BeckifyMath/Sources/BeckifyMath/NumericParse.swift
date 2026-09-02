import Foundation

/// Locale-aware full-string decimal parse for calculator fields.
public enum NumericParse {
    /// Parses `raw` using `locale` decimal/grouping separators.
    /// Returns `nil` for empty input, non-finite values, or trailing junk (`12.5abc`).
    public static func parse(_ raw: String, locale: Locale = .current) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let decimal = locale.decimalSeparator ?? "."
        let grouping = locale.groupingSeparator ?? ","
        var allowed = CharacterSet.decimalDigits
        allowed.insert(charactersIn: "+-\(decimal)")
        if !grouping.isEmpty {
            allowed.insert(charactersIn: grouping)
        }
        allowed.insert(charactersIn: "eE")
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return nil
        }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.isLenient = false
        guard let number = formatter.number(from: trimmed) else { return nil }
        let value = number.doubleValue
        guard value.isFinite else { return nil }
        return value
    }
}
