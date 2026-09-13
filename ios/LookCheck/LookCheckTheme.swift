import SwiftUI
import UIKit
import BeckifyMath

/// Entertainment tokens for the standalone Look Check product.
/// Distinct from Beckify Toolbox teal / copper field chrome.
enum LookTheme {
    static let touchTarget: CGFloat = 44

    static let background = Color(uiColor: UIColor(red: 10 / 255, green: 8 / 255, blue: 14 / 255, alpha: 1))
    static let surface = Color(uiColor: UIColor(red: 22 / 255, green: 18 / 255, blue: 28 / 255, alpha: 1))
    static let surfaceRaised = Color(uiColor: UIColor(red: 34 / 255, green: 28 / 255, blue: 44 / 255, alpha: 1))
    static let foreground = Color(uiColor: UIColor(red: 246 / 255, green: 241 / 255, blue: 234 / 255, alpha: 1))
    static let muted = Color(uiColor: UIColor(red: 168 / 255, green: 156 / 255, blue: 176 / 255, alpha: 1))
    static let border = Color.white.opacity(0.10)

    static let mean = Color(uiColor: UIColor(red: 255 / 255, green: 77 / 255, blue: 109 / 255, alpha: 1))
    static let nice = Color(uiColor: UIColor(red: 61 / 255, green: 220 / 255, blue: 151 / 255, alpha: 1))
    static let gold = Color(uiColor: UIColor(red: 245 / 255, green: 193 / 255, blue: 92 / 255, alpha: 1))
    static let good = Color(uiColor: UIColor(red: 86 / 255, green: 214 / 255, blue: 164 / 255, alpha: 1))
    static let warn = Color(uiColor: UIColor(red: 240 / 255, green: 188 / 255, blue: 72 / 255, alpha: 1))
    static let bad = Color(uiColor: UIColor(red: 244 / 255, green: 112 / 255, blue: 120 / 255, alpha: 1))

    static func tone(_ mode: LookCheckTone) -> Color {
        mode == .mean ? mean : nice
    }
}

enum LookCheckTone: String, CaseIterable, Identifiable {
    case mean
    case nice

    var id: String { rawValue }

    var roastMode: LookRoastMode {
        self == .mean ? .mean : .nice
    }

    var title: String {
        switch self {
        case .mean: return "Mean"
        case .nice: return "Nice"
        }
    }

    var subtitle: String {
        switch self {
        case .mean: return "Savage comedy roast"
        case .nice: return "Over-the-top hype"
        }
    }
}
