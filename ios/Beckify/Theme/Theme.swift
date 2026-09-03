import SwiftUI
import UIKit
import BeckifyMath

/// Beckify instrument design tokens — semantic color, type, space, and motion.
/// Light and dark appearances track the system. Calculator work surfaces stay
/// calm; atmospheric brand treatment is reserved for home chrome and empty states.
enum Theme {
    /// Minimum comfortable thumb target (Apple HIG).
    static let touchTarget: CGFloat = 44

    // MARK: - Surfaces

    static let background = Color.adaptive(
        light: UIColor(red: 242 / 255, green: 244 / 255, blue: 248 / 255, alpha: 1),
        dark: UIColor(red: 8 / 255, green: 10 / 255, blue: 16 / 255, alpha: 1)
    )
    static let surface = Color.adaptive(
        light: UIColor(red: 255 / 255, green: 255 / 255, blue: 255 / 255, alpha: 1),
        dark: UIColor(red: 18 / 255, green: 20 / 255, blue: 28 / 255, alpha: 1)
    )
    static let surfaceRaised = Color.adaptive(
        light: UIColor(red: 232 / 255, green: 235 / 255, blue: 242 / 255, alpha: 1),
        dark: UIColor(red: 28 / 255, green: 31 / 255, blue: 42 / 255, alpha: 1)
    )
    static let surfaceInset = Color.adaptive(
        light: UIColor(red: 225 / 255, green: 229 / 255, blue: 238 / 255, alpha: 1),
        dark: UIColor(red: 12 / 255, green: 14 / 255, blue: 22 / 255, alpha: 1)
    )
    static let foreground = Color.adaptive(
        light: UIColor(red: 18 / 255, green: 22 / 255, blue: 32 / 255, alpha: 1),
        dark: UIColor(red: 236 / 255, green: 240 / 255, blue: 248 / 255, alpha: 1)
    )
    static let muted = Color.adaptive(
        light: UIColor(red: 78 / 255, green: 86 / 255, blue: 104 / 255, alpha: 1),
        dark: UIColor(red: 148 / 255, green: 156 / 255, blue: 176 / 255, alpha: 1)
    )
    static let border = Color.adaptive(
        light: UIColor.black.withAlphaComponent(0.10),
        dark: UIColor.white.withAlphaComponent(0.10)
    )
    static let borderStrong = Color.adaptive(
        light: UIColor.black.withAlphaComponent(0.18),
        dark: UIColor.white.withAlphaComponent(0.18)
    )
    static let gridLine = Color.adaptive(
        light: UIColor(red: 36 / 255, green: 94 / 255, blue: 168 / 255, alpha: 0.10),
        dark: UIColor(red: 94 / 255, green: 168 / 255, blue: 220 / 255, alpha: 0.12)
    )

    // MARK: - Brand / status

    /// Primary instrument accent — Beckify teal-blue (not template purple).
    static let accent = Color.adaptive(
        light: UIColor(red: 18 / 255, green: 112 / 255, blue: 168 / 255, alpha: 1),
        dark: UIColor(red: 72 / 255, green: 176 / 255, blue: 232 / 255, alpha: 1)
    )
    static let accent2 = Color.adaptive(
        light: UIColor(red: 12 / 255, green: 148 / 255, blue: 136 / 255, alpha: 1),
        dark: UIColor(red: 64 / 255, green: 212 / 255, blue: 196 / 255, alpha: 1)
    )
    /// Copper conductor highlight for energized cues.
    static let copper = Color.adaptive(
        light: UIColor(red: 176 / 255, green: 104 / 255, blue: 48 / 255, alpha: 1),
        dark: UIColor(red: 232 / 255, green: 156 / 255, blue: 88 / 255, alpha: 1)
    )
    static let energized = copper
    static let good = Color.adaptive(
        light: UIColor(red: 8 / 255, green: 132 / 255, blue: 94 / 255, alpha: 1),
        dark: UIColor(red: 110 / 255, green: 231 / 255, blue: 183 / 255, alpha: 1)
    )
    static let safe = good
    static let warn = Color.adaptive(
        light: UIColor(red: 171 / 255, green: 112 / 255, blue: 8 / 255, alpha: 1),
        dark: UIColor(red: 245 / 255, green: 196 / 255, blue: 81 / 255, alpha: 1)
    )
    static let bad = Color.adaptive(
        light: UIColor(red: 188 / 255, green: 38 / 255, blue: 64 / 255, alpha: 1),
        dark: UIColor(red: 251 / 255, green: 113 / 255, blue: 133 / 255, alpha: 1)
    )
    static let fault = bad

    static let disclaimer = "Design aid only — not a PE stamp, permit, or substitute for the NEC or a qualified engineer."
    static let sensorDisclaimer = "Not a calibrated instrument. Not a legal sound-level meter, survey, compass, or PE stamp. For field notes and homework only. Readings stay on this device unless you save a numeric snapshot."

    static let brandGradient = LinearGradient(
        colors: [accent, accent2],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let iconGradient = LinearGradient(
        colors: [accent.opacity(0.28), accent2.opacity(0.14), copper.opacity(0.10)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let panelGradient = LinearGradient(
        colors: [
            Color.adaptive(
                light: UIColor(red: 18 / 255, green: 28 / 255, blue: 42 / 255, alpha: 1),
                dark: UIColor(red: 10 / 255, green: 14 / 255, blue: 22 / 255, alpha: 1)
            ),
            Color.adaptive(
                light: UIColor(red: 28 / 255, green: 48 / 255, blue: 68 / 255, alpha: 1),
                dark: UIColor(red: 16 / 255, green: 24 / 255, blue: 36 / 255, alpha: 1)
            ),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Space / radius / stroke

    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        static let xxl: CGFloat = 36
    }

    enum Radius {
        static let control: CGFloat = 10
        static let card: CGFloat = 14
        static let panel: CGFloat = 18
        static let tile: CGFloat = 16
    }

    enum Stroke {
        static let hairline: CGFloat = 1
        static let emphasis: CGFloat = 1.5
        static let diagram: CGFloat = 2
    }

    // MARK: - Type roles

    enum TypeRole {
        static let display = Font.system(.largeTitle, design: .default).weight(.bold)
        static let title = Font.system(.title2, design: .default).weight(.semibold)
        static let headline = Font.system(.headline, design: .default)
        static let body = Font.system(.body, design: .default)
        static let label = Font.system(.caption, design: .default).weight(.semibold)
        static let help = Font.system(.caption2, design: .default)
        static let numeric = Font.system(.title3, design: .default).monospacedDigit().weight(.semibold)
        static let numericBody = Font.system(.body, design: .default).monospacedDigit()
        static let formula = Font.system(.body, design: .monospaced)
    }

    // MARK: - Motion

    enum Motion {
        static let result: Animation = .snappy(duration: 0.28)
        static let chrome: Animation = .easeInOut(duration: 0.22)
        static let subtle: Animation = .easeOut(duration: 0.18)

        static func preferred(_ animation: Animation, reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : animation
        }
    }
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
    /// Soft brand glow for home tiles and show-work cards — keep opacity low
    /// so field daylight readability stays intact.
    func brandGlow(radius: CGFloat = 14, opacity: Double = 0.16) -> some View {
        shadow(color: Theme.accent.opacity(opacity), radius: radius, x: 0, y: 5)
    }

    func instrumentPanelBackground() -> some View {
        background {
            ZStack {
                Theme.background
                BlueprintGrid()
                    .opacity(0.55)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .ignoresSafeArea()
        }
    }
}

/// Subtle drafting grid for atmospheric surfaces (home header / empty states).
struct BlueprintGrid: View {
    var spacing: CGFloat = 24

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(Theme.gridLine), lineWidth: 0.5)
        }
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
