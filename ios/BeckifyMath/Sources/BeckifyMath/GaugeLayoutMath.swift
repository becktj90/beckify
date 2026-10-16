import Foundation

/// Sizing rules for the Drive dashboard so gauges fill the screen. Pure
/// functions: the views pass in the viewport and draw what comes back.
public enum GaugeLayoutMath {
    public static let margin = 16.0
    public static let minDiameter = 170.0
    public static let maxDiameter = 640.0

    public static func isLandscape(width: Double, height: Double) -> Bool {
        width > height
    }

    /// Diameter of the hero dial. Portrait: the full content width, capped at
    /// 55% of the height so cards stay in view. Landscape: the dial takes the
    /// left pane, as tall as the screen allows, at most 48% of the width.
    public static func heroDiameter(width: Double, height: Double) -> Double {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { return minDiameter }
        let raw: Double
        if isLandscape(width: width, height: height) {
            raw = min(height - margin * 2, width * 0.48)
        } else {
            raw = min(width - margin * 2, height * 0.55)
        }
        return min(max(raw, minDiameter), maxDiameter)
    }

    /// Columns for the card grid: as many as fit at `minCell`, never fewer than one.
    public static func columnCount(width: Double, minCell: Double, spacing: Double) -> Int {
        guard width.isFinite, width > 0, minCell > 0 else { return 1 }
        return max(1, Int(((width + spacing) / (minCell + spacing)).rounded(.down)))
    }

    /// Smallest card width: wider on big screens so numbers grow with them.
    public static func minCellWidth(containerWidth: Double, accessibilitySize: Bool) -> Double {
        if accessibilitySize { return containerWidth }
        return containerWidth >= 700 ? 240 : 170
    }

    /// Items per row so the last row is never a lone orphan cell next to blank space.
    /// Each returned row is stretched to the full width by the layout.
    public static func rowSizes(count: Int, columns: Int) -> [Int] {
        guard count > 0 else { return [] }
        let columns = max(1, columns)
        var rows = [Int](repeating: columns, count: count / columns)
        if count % columns != 0 { rows.append(count % columns) }
        return rows
    }

    /// Point size for a card's main number from the card width, bounded for
    /// readability. `scale` is the Dynamic Type multiplier (capped at 1.3).
    public static func cardValueSize(cardWidth: Double, scale: Double) -> Double {
        let base = min(max(cardWidth * 0.30, 34), 84)
        return base * min(max(scale, 1), 1.3)
    }

    /// Point size for the hero speed number inside a dial.
    public static func heroSpeedSize(diameter: Double, scale: Double) -> Double {
        diameter * 0.34 * min(max(scale, 1), 1.15)
    }
}
