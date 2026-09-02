import SwiftUI

enum Theme {
    static let background = Color(red: 5 / 255, green: 6 / 255, blue: 15 / 255)
    static let surface = Color.white.opacity(0.045)
    static let surfaceRaised = Color.white.opacity(0.07)
    static let foreground = Color(red: 238 / 255, green: 240 / 255, blue: 250 / 255)
    static let muted = Color(red: 148 / 255, green: 151 / 255, blue: 184 / 255)
    static let border = Color.white.opacity(0.10)
    static let accent = Color(red: 139 / 255, green: 123 / 255, blue: 255 / 255)
    static let accent2 = Color(red: 79 / 255, green: 139 / 255, blue: 255 / 255)
    static let good = Color(red: 110 / 255, green: 231 / 255, blue: 183 / 255)
    static let warn = Color(red: 245 / 255, green: 196 / 255, blue: 81 / 255)
    static let bad = Color(red: 251 / 255, green: 113 / 255, blue: 133 / 255)

    static let disclaimer = "Design aid only — not a PE stamp, permit, or substitute for the NEC or a qualified engineer."
}

enum Format {
    static func number(_ value: Double, digits: Int = 3) -> String {
        guard value.isFinite else { return "—" }
        let absv = abs(value)
        if absv >= 1_000_000 { return String(format: "%.2e", value) }
        if absv != 0 && absv < 0.001 { return String(format: "%.3e", value) }
        var formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = digits
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: value)) ?? "—"
    }

    static func amps(_ value: Double) -> String { "\(number(value, digits: 2)) A" }
    static func volts(_ value: Double) -> String { "\(number(value, digits: 2)) V" }
    static func watts(_ value: Double) -> String { "\(number(value, digits: 2)) W" }
    static func percent(_ value: Double) -> String { "\(number(value, digits: 2)) %" }

    static func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "—" }
        if seconds >= 1 { return "\(number(seconds, digits: 4)) s" }
        if seconds >= 1e-3 { return "\(number(seconds * 1e3, digits: 4)) ms" }
        if seconds >= 1e-6 { return "\(number(seconds * 1e6, digits: 4)) µs" }
        return "\(number(seconds * 1e9, digits: 4)) ns"
    }

    static func frequency(_ hz: Double) -> String {
        guard hz.isFinite, hz > 0 else { return "—" }
        if hz >= 1e6 { return "\(number(hz / 1e6, digits: 4)) MHz" }
        if hz >= 1e3 { return "\(number(hz / 1e3, digits: 4)) kHz" }
        return "\(number(hz, digits: 4)) Hz"
    }
}

extension String {
    /// Parses a decimal using the active locale and rejects leftover text.
    var parsedDouble: Double? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.isLenient = false
        guard let number = formatter.number(from: t) else { return nil }
        return number.doubleValue
    }
}
