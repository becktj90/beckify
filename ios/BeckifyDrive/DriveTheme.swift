import BeckifyMath
import SwiftUI
import UIKit

/// Beckify Drive tokens. Dark is the default appearance; every token also has
/// a light value so the system appearance setting stays legible.
enum DriveTheme {
    // MARK: Surfaces

    static let background = adaptive(
        light: UIColor(red: 0.95, green: 0.96, blue: 0.97, alpha: 1),
        dark: UIColor(red: 0.015, green: 0.018, blue: 0.022, alpha: 1)
    )
    /// Card fill under the material.
    static let surface = adaptive(
        light: UIColor(white: 1, alpha: 0.72),
        dark: UIColor(red: 0.055, green: 0.062, blue: 0.072, alpha: 0.72)
    )
    /// Raised controls on a card: chips, text fields, segmented backgrounds.
    static let elevated = adaptive(
        light: UIColor(red: 0.90, green: 0.92, blue: 0.94, alpha: 1),
        dark: UIColor(red: 0.08, green: 0.09, blue: 0.105, alpha: 1)
    )
    static let stroke = adaptive(
        light: UIColor(white: 0, alpha: 0.08),
        dark: UIColor(white: 1, alpha: 0.08)
    )
    /// Unfilled gauge track.
    static let track = adaptive(
        light: UIColor(white: 0, alpha: 0.08),
        dark: UIColor(white: 1, alpha: 0.14)
    )

    // MARK: Text

    static let text = adaptive(
        light: UIColor(red: 0.06, green: 0.08, blue: 0.10, alpha: 1),
        dark: UIColor(red: 0.92, green: 0.95, blue: 0.97, alpha: 1)
    )
    static let muted = adaptive(
        light: UIColor(red: 0.36, green: 0.41, blue: 0.46, alpha: 1),
        dark: UIColor(red: 0.55, green: 0.61, blue: 0.67, alpha: 1)
    )

    // MARK: Semantic

    /// Beckify Drive teal. Darker in light mode so it passes contrast on white.
    static let accent = adaptive(
        light: UIColor(red: 0.0, green: 0.52, blue: 0.45, alpha: 1),
        dark: UIColor(red: 0.22, green: 0.98, blue: 0.84, alpha: 1)
    )
    /// Energy going back into the pack.
    static let regen = adaptive(
        light: UIColor(red: 0.16, green: 0.58, blue: 0.20, alpha: 1),
        dark: UIColor(red: 0.45, green: 0.90, blue: 0.42, alpha: 1)
    )
    static let warning = adaptive(
        light: UIColor(red: 0.78, green: 0.47, blue: 0.0, alpha: 1),
        dark: UIColor(red: 1.0, green: 0.74, blue: 0.28, alpha: 1)
    )
    static let critical = adaptive(
        light: UIColor(red: 0.80, green: 0.15, blue: 0.15, alpha: 1),
        dark: UIColor(red: 1.0, green: 0.38, blue: 0.36, alpha: 1)
    )
    /// Cold band on a temperature gauge.
    static let cold = adaptive(
        light: UIColor(red: 0.12, green: 0.42, blue: 0.85, alpha: 1),
        dark: UIColor(red: 0.45, green: 0.70, blue: 1.0, alpha: 1)
    )

    // MARK: Data provenance

    /// A value read from the car or the phone.
    static var measured: Color { text }
    /// A value computed from measured data plus a stated assumption. Always
    /// paired with the "est." badge so color is never the only cue.
    static let estimated = adaptive(
        light: UIColor(red: 0.40, green: 0.30, blue: 0.78, alpha: 1),
        dark: UIColor(red: 0.74, green: 0.68, blue: 1.0, alpha: 1)
    )
    /// Unlit segment behind retro digits.
    static let segmentGhost = adaptive(
        light: UIColor(white: 0, alpha: 0.06),
        dark: UIColor(white: 1, alpha: 0.07)
    )

    // MARK: Older names, kept so existing views read the same

    static var card: Color { surface }
    static var cardRaised: Color { elevated }
    static var amber: Color { warning }
    static var dim: Color { track }

    // MARK: Mapping

    static func color(for level: DriveLevel) -> Color {
        switch level {
        case .normal: return accent
        case .caution: return warning
        case .critical: return critical
        }
    }

    static func color(for band: DriveTemperatureBand) -> Color {
        switch band {
        case .cold: return cold
        case .nominal: return accent
        case .warm: return warning
        case .hot: return critical
        }
    }

    static func color(for flow: HVFlowState?) -> Color {
        switch flow {
        case .drive: return accent
        case .regen: return regen
        case .idle, .none: return muted
        }
    }

    static func ringColor(percent: Double?) -> Color {
        color(for: DriveThresholds.chargeLevel(percent: percent))
    }

    static let cardRadius: CGFloat = 22

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

extension View {
    /// Card chrome: material over a tinted surface, hairline stroke, continuous corners.
    func driveCard(cornerRadius: CGFloat = DriveTheme.cardRadius) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background {
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(DriveTheme.surface)
            }
        }
        .overlay(shape.strokeBorder(DriveTheme.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
    }

    /// Small uppercase section label, Health-app style.
    func driveSectionLabel() -> some View {
        font(.footnote.weight(.semibold))
            .foregroundStyle(DriveTheme.muted)
            .textCase(.uppercase)
            .tracking(0.6)
    }
}

/// "est." chip on every estimated value.
struct EstimateBadge: View {
    var body: some View {
        Text("est.")
            .font(.caption2.weight(.bold))
            .foregroundStyle(DriveTheme.estimated)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .overlay(Capsule().strokeBorder(DriveTheme.estimated.opacity(0.6), lineWidth: 1))
            .fixedSize()
            .accessibilityLabel("estimate")
    }
}
