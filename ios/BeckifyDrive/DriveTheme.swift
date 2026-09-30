import SwiftUI

enum DriveTheme {
    static let background = Color(red: 0.015, green: 0.018, blue: 0.022)
    static let card = Color(red: 0.055, green: 0.062, blue: 0.072)
    static let cardRaised = Color(red: 0.08, green: 0.09, blue: 0.105)
    static let stroke = Color.white.opacity(0.08)
    static let text = Color(red: 0.92, green: 0.95, blue: 0.97)
    static let muted = Color(red: 0.55, green: 0.61, blue: 0.67)
    static let accent = Color(red: 0.22, green: 0.98, blue: 0.84)
    static let amber = Color(red: 1.0, green: 0.74, blue: 0.28)
    static let dim = Color.white.opacity(0.14)

    static func ringColor(percent: Double?) -> Color {
        guard let percent else { return accent }
        if percent < 15 { return amber }
        return accent
    }
}
