import SwiftUI
import UIKit
import BeckifyMath

/// Beckify design tokens — industrial instrument language with blue/teal brand
/// identity, copper conductors, and restrained warning lights.
///
/// Prefer these tokens over ad-hoc colors so calculators stay consistent in
/// bright field light and dark shops.
enum Theme {
    /// Minimum comfortable thumb target (Apple HIG).
    static let touchTarget: CGFloat = 44

    // MARK: Surfaces

    static let background = Color.adaptive(
        light: UIColor(red: 236 / 255, green: 241 / 255, blue: 246 / 255, alpha: 1),
        dark: UIColor(red: 8 / 255, green: 11 / 255, blue: 16 / 255, alpha: 1)
    )
    static let surface = Color.adaptive(
        light: UIColor(red: 250 / 255, green: 252 / 255, blue: 254 / 255, alpha: 1),
        dark: UIColor(red: 18 / 255, green: 22 / 255, blue: 30 / 255, alpha: 1)
    )
    static let surfaceRaised = Color.adaptive(
        light: UIColor(red: 226 / 255, green: 233 / 255, blue: 240 / 255, alpha: 1),
        dark: UIColor(red: 28 / 255, green: 34 / 255, blue: 44 / 255, alpha: 1)
    )
    static let inputFill = Color.adaptive(
        light: UIColor.white,
        dark: UIColor(red: 14 / 255, green: 17 / 255, blue: 24 / 255, alpha: 1)
    )
    static let foreground = Color.adaptive(
        light: UIColor(red: 14 / 255, green: 22 / 255, blue: 32 / 255, alpha: 1),
        dark: UIColor(red: 232 / 255, green: 238 / 255, blue: 245 / 255, alpha: 1)
    )
    static let muted = Color.adaptive(
        light: UIColor(red: 74 / 255, green: 90 / 255, blue: 108 / 255, alpha: 1),
        dark: UIColor(red: 148 / 255, green: 162 / 255, blue: 178 / 255, alpha: 1)
    )
    static let border = Color.adaptive(
        light: UIColor(red: 28 / 255, green: 42 / 255, blue: 58 / 255, alpha: 0.14),
        dark: UIColor.white.withAlphaComponent(0.10)
    )
    static let hairline = Color.adaptive(
        light: UIColor(red: 28 / 255, green: 42 / 255, blue: 58 / 255, alpha: 0.08),
        dark: UIColor.white.withAlphaComponent(0.06)
    )

    // MARK: Semantic accents

    /// Primary brand — instrument teal/blue (not purple template defaults).
    static let accent = Color.adaptive(
        light: UIColor(red: 12 / 255, green: 110 / 255, blue: 148 / 255, alpha: 1),
        dark: UIColor(red: 64 / 255, green: 186 / 255, blue: 214 / 255, alpha: 1)
    )
    static let accent2 = Color.adaptive(
        light: UIColor(red: 18 / 255, green: 72 / 255, blue: 128 / 255, alpha: 1),
        dark: UIColor(red: 96 / 255, green: 156 / 255, blue: 230 / 255, alpha: 1)
    )
    /// Copper conductor cue for energized / secondary emphasis.
    static let energized = Color.adaptive(
        light: UIColor(red: 168 / 255, green: 98 / 255, blue: 42 / 255, alpha: 1),
        dark: UIColor(red: 224 / 255, green: 156 / 255, blue: 86 / 255, alpha: 1)
    )
    /// Named copper token used by facility / ampacity / voltage-drop tools.
    /// Same swatch as `energized` — keep both so glass chrome and calculator
    /// result rows stay on one conductor color.
    static let copper = energized
    static let good = Color.adaptive(
        light: UIColor(red: 8 / 255, green: 128 / 255, blue: 92 / 255, alpha: 1),
        dark: UIColor(red: 86 / 255, green: 214 / 255, blue: 164 / 255, alpha: 1)
    )
    static let warn = Color.adaptive(
        light: UIColor(red: 168 / 255, green: 108 / 255, blue: 8 / 255, alpha: 1),
        dark: UIColor(red: 240 / 255, green: 188 / 255, blue: 72 / 255, alpha: 1)
    )
    static let bad = Color.adaptive(
        light: UIColor(red: 176 / 255, green: 36 / 255, blue: 48 / 255, alpha: 1),
        dark: UIColor(red: 244 / 255, green: 112 / 255, blue: 120 / 255, alpha: 1)
    )

    // MARK: Category identity

    /// A two-stop gradient family per `ToolCategory`, so the tool grid reads as
    /// color-coded shelves instead of one flat wash behind every icon.
    static func categoryColors(_ category: ToolCategory) -> (primary: Color, secondary: Color) {
        switch category {
        case .field:
            // Copper — the conductor color, for wire/load/field work.
            return (energized, Color.adaptive(
                light: UIColor(red: 198 / 255, green: 132 / 255, blue: 58 / 255, alpha: 1),
                dark: UIColor(red: 240 / 255, green: 184 / 255, blue: 110 / 255, alpha: 1)
            ))
        case .power:
            // Brand teal/blue — the primary instrument identity.
            return (accent, accent2)
        case .controls:
            // Violet — instrumentation and PLC panels read this way in the field.
            return (
                Color.adaptive(
                    light: UIColor(red: 96 / 255, green: 60 / 255, blue: 176 / 255, alpha: 1),
                    dark: UIColor(red: 176 / 255, green: 140 / 255, blue: 244 / 255, alpha: 1)
                ),
                Color.adaptive(
                    light: UIColor(red: 132 / 255, green: 40 / 255, blue: 140 / 255, alpha: 1),
                    dark: UIColor(red: 216 / 255, green: 128 / 255, blue: 224 / 255, alpha: 1)
                )
            )
        case .homework:
            // Chalkboard green.
            return (good, Color.adaptive(
                light: UIColor(red: 52 / 255, green: 150 / 255, blue: 92 / 255, alpha: 1),
                dark: UIColor(red: 140 / 255, green: 226 / 255, blue: 176 / 255, alpha: 1)
            ))
        case .sensors:
            // Magenta — deliberately far from the electrical blues/greens so a
            // sensor reading is never mistaken for a calculated result.
            return (
                Color.adaptive(
                    light: UIColor(red: 176 / 255, green: 42 / 255, blue: 122 / 255, alpha: 1),
                    dark: UIColor(red: 240 / 255, green: 128 / 255, blue: 196 / 255, alpha: 1)
                ),
                Color.adaptive(
                    light: UIColor(red: 140 / 255, green: 54 / 255, blue: 168 / 255, alpha: 1),
                    dark: UIColor(red: 210 / 255, green: 150 / 255, blue: 240 / 255, alpha: 1)
                )
            )
        case .reference:
            // Slate — a table you read, not a value you compute. Deliberately
            // the quietest family so it doesn't compete with the calculators.
            return (
                Color.adaptive(
                    light: UIColor(red: 88 / 255, green: 100 / 255, blue: 116 / 255, alpha: 1),
                    dark: UIColor(red: 168 / 255, green: 180 / 255, blue: 196 / 255, alpha: 1)
                ),
                Color.adaptive(
                    light: UIColor(red: 60 / 255, green: 72 / 255, blue: 88 / 255, alpha: 1),
                    dark: UIColor(red: 140 / 255, green: 154 / 255, blue: 172 / 255, alpha: 1)
                )
            )
        }
    }

    /// A small, deterministic per-tool hue nudge so tiles in the same category
    /// aren't perfectly identical — individual without leaving the family.
    /// Uses a fixed string hash rather than `String.hashValue`, which Swift
    /// re-seeds every process launch and would make the nudge flicker between
    /// app opens instead of staying put on a given tool's tile.
    static func toolHueNudge(_ id: ToolID) -> Angle {
        var hash: UInt64 = 5381
        for byte in id.rawValue.utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        let bucket = hash % 9
        return .degrees(Double(bucket) * 3.2 - 12.8)
    }

    /// Soft tinted fill for a category-colored icon tile.
    static func categoryIconGradient(_ category: ToolCategory) -> LinearGradient {
        let colors = categoryColors(category)
        return LinearGradient(
            colors: [colors.primary.opacity(0.30), colors.secondary.opacity(0.16)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Pastel well behind an icon — TechBank-style soft containers, mapped to
    /// Beckify's industrial category families (not purple template defaults).
    static func categoryWellFill(_ category: ToolCategory) -> Color {
        categoryColors(category).primary.opacity(0.18)
    }

    /// Hairline rim for `IconWell` / category wells — category primary at low opacity.
    static func categoryWellStroke(_ category: ToolCategory) -> Color {
        categoryColors(category).primary.opacity(0.38)
    }

    /// Ambient page wash — depth without flat single-color backgrounds.
    static let ambientBackground = LinearGradient(
        colors: [
            Color.adaptive(
                light: UIColor(red: 228 / 255, green: 236 / 255, blue: 244 / 255, alpha: 1),
                dark: UIColor(red: 6 / 255, green: 10 / 255, blue: 16 / 255, alpha: 1)
            ),
            Color.adaptive(
                light: UIColor(red: 236 / 255, green: 241 / 255, blue: 246 / 255, alpha: 1),
                dark: UIColor(red: 8 / 255, green: 14 / 255, blue: 22 / 255, alpha: 1)
            ),
            Color.adaptive(
                light: UIColor(red: 220 / 255, green: 232 / 255, blue: 240 / 255, alpha: 1),
                dark: UIColor(red: 10 / 255, green: 18 / 255, blue: 26 / 255, alpha: 1)
            ),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Glass card fill for interactive tiles (favorites chips, tool wells).
    static let glassFill = Color.adaptive(
        light: UIColor.white.withAlphaComponent(0.72),
        dark: UIColor.white.withAlphaComponent(0.06)
    )

    static let glassStroke = Color.adaptive(
        light: UIColor.white.withAlphaComponent(0.85),
        dark: UIColor.white.withAlphaComponent(0.14)
    )

    // MARK: Chart

    static let chartPrimary = accent
    static let chartSecondary = energized
    static let chartTertiary = accent2
    static let chartGrid = muted.opacity(0.28)
    static let chartFill = accent.opacity(0.16)

    // MARK: Spacing / radius / stroke

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
        static let control: CGFloat = 12
        static let card: CGFloat = 18
        static let panel: CGFloat = 26
        static let tile: CGFloat = 22
        static let well: CGFloat = 18
        static let pill: CGFloat = 999
    }

    enum Stroke {
        static let hairline: CGFloat = 1
        static let emphasis: CGFloat = 1.5
        static let icon: CGFloat = 1.75
        /// Faint understroke behind glyph linework for optical depth.
        static let iconUnder: CGFloat = 3.2
    }

    // MARK: Typography roles — scientific / instrument hierarchy.
    // Native SF Pro keeps App Store footprint light; roles encode tracking
    // and mono/data contrast the way the web stack uses Exo 2 / Sora / Plex.

    enum TypeRole {
        /// Mission wordmark on atmospheric headers.
        static var heroBrand: Font { .system(.title, design: .default).weight(.bold) }
        /// Uppercase shelf / section chrome (pair with `.tracking(0.8…1.2)`).
        static var sectionLabel: Font { .system(.caption2, design: .default).weight(.semibold) }
        static var fieldLabel: Font { .system(.caption, design: .default).weight(.semibold) }
        static var body: Font { .system(.body, design: .default) }
        static var lead: Font { .system(.title3, design: .default).weight(.semibold) }
        static var numeric: Font { .system(.body, design: .monospaced).monospacedDigit() }
        static var numericEmphasis: Font { .system(.title3, design: .monospaced).weight(.semibold) }
        static var numericHero: Font { .system(.title2, design: .monospaced).weight(.bold) }
        static var help: Font { .system(.caption, design: .default) }
        static var formula: Font { .system(.body, design: .monospaced) }
        /// Compact HUD / telemetry strip.
        static var hud: Font { .system(.caption2, design: .monospaced).weight(.medium) }
    }

    // MARK: Copy

    static let disclaimer = "Design aid only — not a PE stamp, permit, or substitute for the NEC or a qualified engineer."
    static let sensorDisclaimer = "Not a calibrated instrument. Not a legal sound-level meter, survey, compass, or PE stamp. For field notes and homework only. Readings stay on this device unless you save a numeric snapshot."
    static let staleResultMessage = "Inputs changed — Calculate again."

    /// Brand wash for home header / empty states — not for calculator work areas.
    static let brandGradient = LinearGradient(
        colors: [accent, accent2],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Soft tinted fill for icon badges.
    static let iconGradient = LinearGradient(
        colors: [
            accent.opacity(0.22),
            accent2.opacity(0.10),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Blueprint-style panel wash for atmospheric headers only.
    static let instrumentPanel = LinearGradient(
        colors: [
            Color.adaptive(
                light: UIColor(red: 18 / 255, green: 42 / 255, blue: 64 / 255, alpha: 1),
                dark: UIColor(red: 12 / 255, green: 18 / 255, blue: 28 / 255, alpha: 1)
            ),
            Color.adaptive(
                light: UIColor(red: 10 / 255, green: 72 / 255, blue: 96 / 255, alpha: 1),
                dark: UIColor(red: 8 / 255, green: 28 / 255, blue: 40 / 255, alpha: 1)
            ),
        ],
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
    /// Shared segmented picker: system style with a ≥ `Theme.touchTarget` (44pt)
    /// glove-friendly hit target. Prefer this over a bare `.pickerStyle(.segmented)`.
    func segmentedControlStyle() -> some View {
        self
            .pickerStyle(.segmented)
            .controlSize(.large)
            .frame(minHeight: Theme.touchTarget)
    }

    /// Restrained depth for brand-forward surfaces. Avoid stacking on every card.
    func brandGlow(radius: CGFloat = 12, opacity: Double = 0.14) -> some View {
        shadow(color: Theme.accent.opacity(opacity), radius: radius, x: 0, y: 4)
    }

    /// Soft lift under glass tiles.
    func tileLift(tint: Color = Theme.accent, radius: CGFloat = 14, opacity: Double = 0.16) -> some View {
        shadow(color: tint.opacity(opacity), radius: radius, x: 0, y: 6)
    }

    /// Instrument panel chrome — raised surface with drafting stroke.
    func instrumentPanel(corner: CGFloat = Theme.Radius.card) -> some View {
        self
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Theme.border, lineWidth: Theme.Stroke.hairline)
            )
    }

    /// Frosted interactive card used by toolbox tiles and chips.
    func glassCard(corner: CGFloat = Theme.Radius.card, tint: Color = Theme.accent) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Theme.glassFill)
                    .background {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
            }
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Theme.glassStroke, lineWidth: Theme.Stroke.hairline)
            )
            .tileLift(tint: tint, radius: 12, opacity: 0.12)
    }
}

enum Format {
    static func number(_ value: Double, digits: Int = 3) -> String {
        guard value.isFinite else { return "—" }
        let absv = abs(value)
        if absv >= 1_000_000 { return String(format: "%.2e", value) }
        if absv != 0 && absv < 0.001 { return String(format: "%.3e", value) }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = digits
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: value)) ?? "—"
    }

    static func dollars(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = value >= 100 ? 0 : 2
        formatter.minimumFractionDigits = value >= 100 ? 0 : 2
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

/// Motion + haptic policy for calculator interactions.
enum BeckifyMotion {
    static let calculateSuccess = Animation.easeOut(duration: 0.22)
    static let navigation = Animation.easeInOut(duration: 0.28)
    static let staleReveal = Animation.easeInOut(duration: 0.18)
    static let homeReveal = Animation.easeInOut(duration: 0.36)
    static let tilePress = Animation.easeOut(duration: 0.16)

    static func withOptionalAnimation<Result>(
        _ animation: Animation?,
        reduceMotion: Bool,
        _ body: () -> Result
    ) -> Result {
        if reduceMotion {
            body()
        } else if let animation {
            withAnimation(animation, body)
        } else {
            body()
        }
    }
}
