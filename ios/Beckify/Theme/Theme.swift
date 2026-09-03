import SwiftUI
import UIKit
import BeckifyMath

enum Theme {
    /// Minimum comfortable thumb target (Apple HIG).
    static let touchTarget: CGFloat = 44

    static let background = Color.adaptive(
        light: UIColor(red: 244 / 255, green: 245 / 255, blue: 252 / 255, alpha: 1),
        dark: UIColor(red: 5 / 255, green: 6 / 255, blue: 15 / 255, alpha: 1)
    )
    static let surface = Color.adaptive(
        light: UIColor(red: 255 / 255, green: 255 / 255, blue: 255 / 255, alpha: 1),
        dark: UIColor.white.withAlphaComponent(0.035)
    )
    static let surfaceRaised = Color.adaptive(
        light: UIColor(red: 236 / 255, green: 237 / 255, blue: 246 / 255, alpha: 1),
        dark: UIColor.white.withAlphaComponent(0.065)
    )
    static let foreground = Color.adaptive(
        light: UIColor(red: 22 / 255, green: 24 / 255, blue: 38 / 255, alpha: 1),
        dark: UIColor(red: 238 / 255, green: 240 / 255, blue: 250 / 255, alpha: 1)
    )
    static let muted = Color.adaptive(
        light: UIColor(red: 86 / 255, green: 88 / 255, blue: 116 / 255, alpha: 1),
        dark: UIColor(red: 148 / 255, green: 151 / 255, blue: 184 / 255, alpha: 1)
    )
    static let border = Color.adaptive(
        light: UIColor.black.withAlphaComponent(0.12),
        dark: UIColor.white.withAlphaComponent(0.09)
    )
    static let accent = Color.adaptive(
        light: UIColor(red: 92 / 255, green: 74 / 255, blue: 214 / 255, alpha: 1),
        dark: UIColor(red: 139 / 255, green: 123 / 255, blue: 255 / 255, alpha: 1)
    )
    static let accent2 = Color.adaptive(
        light: UIColor(red: 36 / 255, green: 94 / 255, blue: 204 / 255, alpha: 1),
        dark: UIColor(red: 79 / 255, green: 139 / 255, blue: 255 / 255, alpha: 1)
    )
    static let good = Color.adaptive(
        light: UIColor(red: 8 / 255, green: 132 / 255, blue: 94 / 255, alpha: 1),
        dark: UIColor(red: 110 / 255, green: 231 / 255, blue: 183 / 255, alpha: 1)
    )
    static let warn = Color.adaptive(
        light: UIColor(red: 171 / 255, green: 112 / 255, blue: 8 / 255, alpha: 1),
        dark: UIColor(red: 245 / 255, green: 196 / 255, blue: 81 / 255, alpha: 1)
    )
    static let bad = Color.adaptive(
        light: UIColor(red: 188 / 255, green: 38 / 255, blue: 64 / 255, alpha: 1),
        dark: UIColor(red: 251 / 255, green: 113 / 255, blue: 133 / 255, alpha: 1)
    )

    static let disclaimer = "Design aid only — not a PE stamp, permit, or substitute for the NEC or a qualified engineer."
    static let sensorDisclaimer = "Not a calibrated instrument. Not a legal sound-level meter, survey, compass, or PE stamp. For field notes and homework only. Readings stay on this device unless you save a numeric snapshot."

    /// Nebula violet → blue, matching the beckify.com brand gradient.
    static let brandGradient = LinearGradient(
        colors: [accent, accent2],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Soft tinted fill for icon badges, echoing the site's glowing accent chips.
    static let iconGradient = LinearGradient(
        colors: [accent.opacity(0.32), accent2.opacity(0.18)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    /// Follows the system light/dark appearance. Not a custom in-app theme picker.
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

extension View {
    /// The site's card-hover glow — a soft violet shadow — applied statically
    /// to brand-forward surfaces (formula/show-work cards) instead of on hover.
    func brandGlow(radius: CGFloat = 16, opacity: Double = 0.22) -> some View {
        shadow(color: Theme.accent.opacity(opacity), radius: radius, x: 0, y: 6)
    }
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
    static func degrees(_ value: Double) -> String { "\(number(value, digits: 2)) °" }
    static func microtesla(_ value: Double) -> String { "\(number(value, digits: 2)) µT" }
    static func dbfs(_ value: Double) -> String { "\(number(value, digits: 1)) dBFS" }
    static func meters(_ value: Double) -> String { "\(number(value, digits: 2)) m" }

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
    /// Locale-aware full-string parse; trailing junk is rejected (see `NumericParse`).
    var parsedDouble: Double? {
        NumericParse.parse(self)
    }
}
