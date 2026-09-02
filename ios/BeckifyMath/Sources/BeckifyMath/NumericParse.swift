import Foundation

/// Locale-aware full-string decimal parse for calculator fields.
public enum NumericParse {
    /// Parses `raw` using `locale` decimal/grouping separators and sign symbols.
    /// Returns `nil` for empty input, non-finite values, leftover junk, or malformed tokens (`12.5.6`).
    public static func parse(_ raw: String, locale: Locale = .current) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.isLenient = false

        let decimal = formatter.decimalSeparator ?? locale.decimalSeparator ?? "."
        let grouping = formatter.groupingSeparator ?? locale.groupingSeparator ?? ","
        let plus = formatter.plusSign ?? "+"
        let minus = formatter.minusSign ?? "-"

        var allowed = CharacterSet.decimalDigits
        allowed.insert(charactersIn: "+-eE")
        allowed.insert(charactersIn: plus)
        allowed.insert(charactersIn: minus)
        allowed.insert(charactersIn: "\u{2212}\u{200E}\u{200F}")
        allowed.insert(charactersIn: decimal)
        if !grouping.isEmpty {
            allowed.insert(charactersIn: grouping)
        }
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return nil
        }
        guard isSingleNumericToken(trimmed, decimal: decimal, grouping: grouping) else {
            return nil
        }

        guard let number = formatter.number(from: trimmed) else { return nil }
        let value = number.doubleValue
        guard value.isFinite else { return nil }
        return value
    }

    /// Rejects prefix matches that NumberFormatter still accepts (`12.5.6`, `1e2e3`, `1,,2`).
    private static func isSingleNumericToken(_ raw: String, decimal: String, grouping: String) -> Bool {
        let bidi = CharacterSet(charactersIn: "\u{200E}\u{200F}")
        let cleaned = String(raw.unicodeScalars.filter { !bidi.contains($0) })
        if !grouping.isEmpty, cleaned.contains(grouping + grouping) {
            return false
        }
        if !decimal.isEmpty {
            let parts = cleaned.components(separatedBy: decimal)
            if parts.count > 2 { return false }
        }
        let exponents = cleaned.unicodeScalars.filter { $0 == "e" || $0 == "E" }.count
        if exponents > 1 { return false }
        return true
    }
}
