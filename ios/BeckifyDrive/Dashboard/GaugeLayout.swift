import BeckifyMath
import SwiftUI

/// Size of the whole dashboard viewport, set once by `DashboardView`.
private struct DashboardViewportKey: EnvironmentKey {
    static let defaultValue = CGSize(width: 393, height: 760)
}

/// Width available to the card grid (the right pane in landscape).
private struct DashboardPaneWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 361
}

/// Width of one card in the current grid, for sizing its main number.
private struct DashboardCardWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 170
}

extension EnvironmentValues {
    var dashboardViewport: CGSize {
        get { self[DashboardViewportKey.self] }
        set { self[DashboardViewportKey.self] = newValue }
    }

    var dashboardPaneWidth: CGFloat {
        get { self[DashboardPaneWidthKey.self] }
        set { self[DashboardPaneWidthKey.self] = newValue }
    }

    var dashboardCardWidth: CGFloat {
        get { self[DashboardCardWidthKey.self] }
        set { self[DashboardCardWidthKey.self] = newValue }
    }
}

/// Rows of equal cells. The last row is stretched to the full width, so a
/// short row never leaves a blank hole. Row sizes come from `GaugeLayoutMath`.
struct FillGridLayout: Layout {
    var columns: Int
    var spacing: CGFloat = 12

    private func rows(_ count: Int) -> [Range<Int>] {
        var start = 0
        return GaugeLayoutMath.rowSizes(count: count, columns: columns).map { size in
            defer { start += size }
            return start..<(start + size)
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 361
        var height: CGFloat = 0
        let all = rows(subviews.count)
        for (index, range) in all.enumerated() {
            let cell = (width - spacing * CGFloat(range.count - 1)) / CGFloat(range.count)
            let rowHeight = range.map { subviews[$0].sizeThatFits(ProposedViewSize(width: cell, height: nil)).height }.max() ?? 0
            height += rowHeight + (index > 0 ? spacing : 0)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for range in rows(subviews.count) {
            let cell = (bounds.width - spacing * CGFloat(range.count - 1)) / CGFloat(range.count)
            let rowHeight = range.map { subviews[$0].sizeThatFits(ProposedViewSize(width: cell, height: nil)).height }.max() ?? 0
            var x = bounds.minX
            for index in range {
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(width: cell, height: rowHeight))
                x += cell + spacing
            }
            y += rowHeight + spacing
        }
    }
}
