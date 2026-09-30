import SwiftUI

/// How a plot should respond to fingers.
enum PlotInspection: Equatable {
    /// Pinch-zoom, pan once zoomed, and a value readout while full screen.
    /// One-finger drags stay off the inline plot so the page can still scroll.
    case inspect
    /// Pinch to enlarge detail. No crosshair. Used for packing diagrams.
    case magnify
    /// Labels and full screen only. Leaves taps alone (floor plans, schematics, gauges).
    case look
}

/// One Cartesian axis. `start` is the origin side (left or bottom). `end` is the far side.
struct PlotAxis: Equatable {
    var title: String
    var unit: String
    var start: String
    var mid: String?
    var end: String

    var titleWithUnit: String {
        let trimmed = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return title }
        if title.range(of: trimmed, options: .caseInsensitive) != nil { return title }
        return "\(title) (\(trimmed))"
    }
}

private struct PlotSurfaceIsImmersiveKey: EnvironmentKey {
    static let defaultValue = false
}

private struct PlotFullscreenIsProvidedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True inside a full-screen plot cover. One-finger readouts turn on here.
    var plotSurfaceIsImmersive: Bool {
        get { self[PlotSurfaceIsImmersiveKey.self] }
        set { self[PlotSurfaceIsImmersiveKey.self] = newValue }
    }

    /// The parent card already offers Full screen, so the plot hides its own button.
    var plotFullscreenIsProvided: Bool {
        get { self[PlotFullscreenIsProvidedKey.self] }
        set { self[PlotFullscreenIsProvidedKey.self] = newValue }
    }
}

enum PlotScaleMath {
    /// Window of `min...max` centered on `anchor` (0…1), shrunk by `magnification`.
    static func window(
        min: Double,
        max: Double,
        anchor: CGFloat,
        magnification: CGFloat,
        logarithmic: Bool
    ) -> ClosedRange<Double> {
        let mag = Double(max(magnification, 1))
        let anchor = Double(min(1, max(0, anchor)))
        if logarithmic {
            let lo = log(max(min, 1e-9))
            let hi = log(max(max, min * 1.000_001))
            let span = max((hi - lo) / mag, 1e-6)
            let mid = lo + (hi - lo) * anchor
            var start = mid - span / 2
            var end = mid + span / 2
            if start < lo { end += lo - start; start = lo }
            if end > hi { start -= end - hi; end = hi }
            start = max(lo, start)
            return exp(start)...exp(max(end, start + 1e-6))
        }
        let span = max((max - min) / mag, 1e-9)
        let mid = min + (max - min) * anchor
        var start = mid - span / 2
        var end = mid + span / 2
        if start < min { end += min - start; start = min }
        if end > max { start -= end - max; end = max }
        start = max(min, min(start, max))
        end = min(max, max(end, start))
        if end <= start { end = start + span }
        return start...end
    }
}

/// Shared axis titles, tick captions, full screen, and optional inspect gestures.
struct LabeledPlotChrome<Content: View>: View {
    var xAxis: PlotAxis
    var yAxis: PlotAxis
    var accessibilityLabel: String
    var inspection: PlotInspection = .inspect
    var plotHeight: CGFloat = 160
    var fullscreenTitle: String
    /// Normalized point: x is 0 at the left and 1 at the right. y is 0 at the bottom and 1 at the top.
    var readout: ((CGFloat, CGFloat) -> String)?
    @ViewBuilder var plot: () -> Content

    @Environment(\.plotFullscreenIsProvided) private var fullscreenProvided
    @Environment(\.plotSurfaceIsImmersive) private var immersive
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var presented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(yAxis.titleWithUnit)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
                Spacer(minLength: 8)
                if !fullscreenProvided {
                    expandButton
                }
            }
            HStack(alignment: .top, spacing: 6) {
                tickColumn(top: yAxis.end, mid: yAxis.mid, bottom: yAxis.start)
                    .frame(height: plotHeight)
                PlotGestureSurface(
                    inspection: inspection,
                    plotHeight: plotHeight,
                    accessibilityLabel: accessibilityLabel,
                    readout: readout
                ) {
                    plot()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            xCaption
            if immersive, inspection == .inspect {
                Text("Drag to read a value. Pinch to zoom.")
                    .font(Theme.TypeRole.hud)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
        .fullScreenCover(isPresented: $presented) {
            PlotFullscreenCover(title: fullscreenTitle, reduceMotion: reduceMotion) {
                LabeledPlotChrome(
                    xAxis: xAxis,
                    yAxis: yAxis,
                    accessibilityLabel: accessibilityLabel,
                    inspection: inspection,
                    plotHeight: 420,
                    fullscreenTitle: fullscreenTitle,
                    readout: readout,
                    plot: plot
                )
                .environment(\.plotFullscreenIsProvided, true)
            }
        }
    }

    private var expandButton: some View {
        Button {
            presented = true
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.body.weight(.semibold))
                .frame(minWidth: Theme.touchTarget, minHeight: Theme.touchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .tint(Theme.accent)
        .accessibilityLabel("View \(fullscreenTitle) full screen")
        .accessibilityHint("Opens a large plot. The Done button closes it.")
    }

    private var xCaption: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                tickLabel(xAxis.start)
                Spacer(minLength: 4)
                Text(xAxis.titleWithUnit)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.foreground)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 4)
                tickLabel(xAxis.end)
            }
            if let mid = xAxis.mid, !mid.isEmpty {
                Text(mid)
                    .font(Theme.TypeRole.hud)
                    .foregroundStyle(Theme.foreground)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func tickColumn(top: String, mid: String?, bottom: String) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            tickLabel(top)
            Spacer(minLength: 0)
            if let mid, !mid.isEmpty {
                tickLabel(mid)
                Spacer(minLength: 0)
            }
            tickLabel(bottom)
        }
        .accessibilityHidden(true)
    }

    private func tickLabel(_ text: String) -> some View {
        HStack(spacing: 3) {
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Rectangle()
                .fill(Theme.foreground)
                .frame(width: 6, height: 1)
                .accessibilityHidden(true)
        }
        .font(Theme.TypeRole.hud)
        .foregroundStyle(Theme.foreground)
    }
}

/// Pinch, pan, and an optional crosshair. The plot view itself keeps updating underneath.
struct PlotGestureSurface<Content: View>: View {
    var inspection: PlotInspection
    /// When set, the drawable plot is this tall and captions sit below it.
    var plotHeight: CGFloat?
    var accessibilityLabel: String = "Plot"
    var readout: ((CGFloat, CGFloat) -> String)?
    @ViewBuilder var content: () -> Content

    @Environment(\.plotSurfaceIsImmersive) private var immersive
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1
    @State private var pinchBase: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var panBase: CGSize = .zero
    @State private var crosshair: CGPoint?
    @State private var readoutText: String?
    @State private var plotSize: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            plotStack
            if scale > 1.02 || (inspection == .magnify && immersive) {
                HStack(spacing: 8) {
                    if scale > 1.02 {
                        Button("Reset zoom", action: resetZoom)
                            .buttonStyle(.bordered)
                            .tint(Theme.accent)
                            .frame(minHeight: Theme.touchTarget)
                            .accessibilityLabel("Reset zoom")
                            .accessibilityHint("Returns the plot to its original scale")
                    }
                    if inspection == .magnify, immersive {
                        Text("Pinch to enlarge.")
                            .font(Theme.TypeRole.hud)
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
            if let readoutText, inspection == .inspect {
                Text(readoutText)
                    .font(Theme.TypeRole.hud)
                    .foregroundStyle(Theme.foreground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(minHeight: Theme.touchTarget, alignment: .leading)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityLabel(readoutText)
            }
        }
    }

    private var plotStack: some View {
        let stack = ZStack(alignment: .topLeading) {
            content()
                .scaleEffect(scale, anchor: .center)
                .offset(offset)
            if let crosshair, inspection == .inspect {
                crosshairMark(at: crosshair)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: plotHeight)
        .clipped()
        .background(Theme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            GeometryReader { geo in
                Color.clear.preference(key: PlotSizeKey.self, value: geo.size)
            }
        }
        .onPreferenceChange(PlotSizeKey.self) { plotSize = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(readoutText ?? accessibilityLabel)
        .accessibilityAction(named: Text("Reset zoom")) { resetZoom() }

        return Group {
            if inspection == .look {
                stack
            } else if allowsOneFinger {
                stack
                    .simultaneousGesture(magnifyGesture)
                    .gesture(dragGesture)
            } else {
                stack.simultaneousGesture(magnifyGesture)
            }
        }
    }

    private var allowsOneFinger: Bool {
        if scale > 1.02 { return true }
        return inspection == .inspect && immersive
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let next = min(8, max(1, pinchBase * value.magnification))
                scale = next
                offset = clamped(panBase, scale: next)
                if inspection == .inspect { crosshair = nil }
            }
            .onEnded { _ in
                pinchBase = scale
                panBase = offset
                if scale < 1.02 { resetZoom() }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if scale > 1.02 {
                    let proposed = CGSize(
                        width: panBase.width + value.translation.width,
                        height: panBase.height + value.translation.height
                    )
                    offset = clamped(proposed, scale: scale)
                    crosshair = nil
                    readoutText = nil
                } else if inspection == .inspect {
                    crosshair = value.location
                    readoutText = describe(value.location)
                }
            }
            .onEnded { value in
                if scale > 1.02 {
                    panBase = offset
                } else if inspection == .inspect {
                    crosshair = value.location
                    readoutText = describe(value.location)
                }
            }
    }

    private func describe(_ viewPoint: CGPoint) -> String? {
        guard let readout, plotSize.width > 1, plotSize.height > 1 else { return nil }
        let data = dataPoint(from: viewPoint)
        let x = min(1, max(0, data.x / plotSize.width))
        let y = min(1, max(0, 1 - data.y / plotSize.height))
        let text = readout(x, y)
        return text.isEmpty ? nil : text
    }

    private func dataPoint(from viewPoint: CGPoint) -> CGPoint {
        let center = CGPoint(x: plotSize.width / 2, y: plotSize.height / 2)
        let safeScale = max(scale, 0.01)
        return CGPoint(
            x: center.x + (viewPoint.x - offset.width - center.x) / safeScale,
            y: center.y + (viewPoint.y - offset.height - center.y) / safeScale
        )
    }

    private func clamped(_ proposed: CGSize, scale: CGFloat) -> CGSize {
        let maxX = max(0, plotSize.width * (scale - 1) / 2)
        let maxY = max(0, plotSize.height * (scale - 1) / 2)
        return CGSize(
            width: min(maxX, max(-maxX, proposed.width)),
            height: min(maxY, max(-maxY, proposed.height))
        )
    }

    private func resetZoom() {
        if reduceMotion {
            scale = 1
            pinchBase = 1
            offset = .zero
            panBase = .zero
            crosshair = nil
        } else {
            withAnimation(.snappy(duration: 0.2)) {
                scale = 1
                pinchBase = 1
                offset = .zero
                panBase = .zero
                crosshair = nil
            }
        }
    }

    private func crosshairMark(at point: CGPoint) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Theme.foreground)
                .frame(width: 1, height: plotSize.height)
                .position(x: point.x, y: plotSize.height / 2)
            Rectangle()
                .fill(Theme.foreground)
                .frame(width: plotSize.width, height: 1)
                .position(x: plotSize.width / 2, y: point.y)
            Circle()
                .stroke(Theme.foreground, lineWidth: 1.5)
                .background(Circle().fill(Theme.copper))
                .frame(width: 8, height: 8)
                .position(point)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct PlotFullscreenCover<Content: View>: View {
    var title: String
    var reduceMotion: Bool
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                content()
                    .padding(Theme.Space.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .frame(minHeight: Theme.touchTarget)
                        .accessibilityLabel("Done")
                        .accessibilityHint("Closes the full screen plot")
                }
            }
        }
        .environment(\.plotSurfaceIsImmersive, true)
        .transaction { transaction in
            if reduceMotion { transaction.disablesAnimations = true }
        }
    }
}

/// Header control that presents any diagram full screen without adding fake axes.
struct PlotFullscreenControl<Cover: View>: View {
    var title: String
    var plotName: String
    @ViewBuilder var cover: () -> Cover

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var presented = false

    var body: some View {
        Button {
            presented = true
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.body.weight(.semibold))
                .frame(minWidth: Theme.touchTarget, minHeight: Theme.touchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .tint(Theme.accent)
        .accessibilityLabel("View \(plotName) full screen")
        .accessibilityHint("Opens a large view. The Done button closes it.")
        .fullScreenCover(isPresented: $presented) {
            PlotFullscreenCover(title: title, reduceMotion: reduceMotion) {
                cover()
            }
        }
    }
}

private struct PlotSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 0, next.height > 0 { value = next }
    }
}
