import SwiftUI
import BeckifyMath

/// To-scale raceway cross-section. Geometry comes from `ConduitCrossSection`.
struct ConduitFillDiagram: View {
    let layout: ConduitCrossSectionLayout
    var showsASNZSGuidance: Bool = false
    var recommendedEGCNote: String?

    @State private var zoom: CGFloat = 1
    @State private var liveZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var panOrigin: CGSize = .zero

    var body: some View {
        DiagramCard(
            title: "Raceway cross-section",
            accessibilitySummary: layout.accessibilitySummary + " Pinch to zoom. Double-tap to reset.",
            exportName: "conduit-fill-section"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                statusRow
                fillBar
                zoomableDrawing
                    .frame(height: 300)
                    .clipped()
                    .accessibilityHint("Pinch to zoom the bore. Double-tap to reset.")
                if zoomed {
                    Button("Reset view") {
                        zoom = 1
                        liveZoom = 1
                        pan = .zero
                        panOrigin = .zero
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
                } else {
                    Text("Pinch to zoom. Share saves a PNG of this section.")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
                callouts
                legend
                if showsASNZSGuidance {
                    asnzsLine
                }
                if let recommendedEGCNote {
                    Text(recommendedEGCNote)
                        .font(.caption2)
                        .foregroundStyle(Theme.copper)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let jam = layout.jamNote {
                    Text(jam)
                        .font(.caption2)
                        .foregroundStyle(Theme.warn)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(layout.packingNote)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                guidance
            }
        }
        .accessibilityIdentifier("conduitFillSection")
    }

    private var zoomed: Bool {
        zoom > 1.02 || pan != .zero
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Image(systemName: layout.passes ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .foregroundStyle(layout.passes ? Theme.good : Theme.bad)
                .accessibilityHidden(true)
            Text("\(layout.tradeSize)\" \(layout.raceway.displayName)")
                .font(.caption.weight(.semibold))
            Spacer(minLength: 8)
            Text(layout.passes ? "PASS" : "FAIL")
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(layout.passes ? Theme.good : Theme.bad)
        }
        .accessibilityElement(children: .combine)
    }

    private var fillBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let width = max(geo.size.width, 1)
                let allowed = CGFloat(min(max(layout.allowedPercent, 0), 100) / 100)
                let actual = CGFloat(min(max(layout.fillPercent, 0), 100) / 100)
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hairline)
                    Capsule()
                        .fill(layout.passes ? Theme.good : Theme.bad)
                        .frame(width: max(width * actual, actual > 0 ? 4 : 0))
                    Rectangle()
                        .fill(Theme.foreground)
                        .frame(width: 2, height: 16)
                        .offset(x: min(max(width * allowed - 1, 0), width - 2))
                }
            }
            .frame(height: 16)
            .accessibilityHidden(true)
            Text("\(Format.percent(layout.fillPercent)) filled  ·  \(Format.percent(layout.allowedPercent)) allowed")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Theme.muted)
            Text(layout.fillBasis)
                .font(.caption2)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fill \(Format.percent(layout.fillPercent)) of \(Format.percent(layout.allowedPercent)) allowed. \(layout.fillBasis)")
    }

    private var zoomableDrawing: some View {
        let drawing = GeometryReader { geo in
            crossSection(ConduitSectionScene(size: geo.size, bore: layout.bore))
        }
        .scaleEffect(zoom * liveZoom)
        .offset(pan)
        .contentShape(Rectangle())
        .gesture(magnify)
        .onTapGesture(count: 2) {
            zoom = 1
            liveZoom = 1
            pan = .zero
            panOrigin = .zero
        }
        return Group {
            if zoom > 1.02 {
                drawing.simultaneousGesture(panGesture)
            } else {
                drawing
            }
        }
    }

    private var magnify: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                liveZoom = value
            }
            .onEnded { value in
                zoom = min(4, max(1, zoom * value))
                liveZoom = 1
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                pan = CGSize(
                    width: panOrigin.width + value.translation.width,
                    height: panOrigin.height + value.translation.height
                )
            }
            .onEnded { value in
                pan = CGSize(
                    width: panOrigin.width + value.translation.width,
                    height: panOrigin.height + value.translation.height
                )
                panOrigin = pan
            }
    }

    private func crossSection(_ scene: ConduitSectionScene) -> some View {
        ZStack {
            raceway(scene)
            ForEach(layout.conductors) { conductor in
                conductorMark(conductor, scene: scene)
            }
            Text("\(layout.tradeSize)\" \(layout.raceway.displayName)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.foreground)
                .position(x: scene.center.x, y: scene.center.y - scene.outerPoints / 2 - 12)
            dimensionLine(scene)
        }
    }

    @ViewBuilder
    private func raceway(_ scene: ConduitSectionScene) -> some View {
        if layout.bore.outsideDiameterInches != nil {
            Circle()
                .fill(wallColor)
                .frame(width: scene.outerPoints, height: scene.outerPoints)
                .position(scene.center)
            Circle()
                .fill(Theme.background)
                .frame(width: scene.innerPoints, height: scene.innerPoints)
                .position(scene.center)
            Circle()
                .stroke(Theme.foreground.opacity(0.55), lineWidth: 1)
                .frame(width: scene.outerPoints, height: scene.outerPoints)
                .position(scene.center)
        } else {
            Circle()
                .fill(Theme.background)
                .frame(width: scene.innerPoints, height: scene.innerPoints)
                .position(scene.center)
            Circle()
                .stroke(Theme.accent, lineWidth: 3)
                .frame(width: scene.innerPoints, height: scene.innerPoints)
                .position(scene.center)
        }
    }

    private func conductorMark(_ conductor: ConduitPackedConductor, scene: ConduitSectionScene) -> some View {
        let diameter = max(CGFloat(conductor.overallDiameterInches) * scene.scale, 1)
        let center = scene.point(x: conductor.centerXInches, y: conductor.centerYInches)
        return ZStack {
            Circle().fill(conductor.colorName.flatMap { conventionColor($0) } ?? Theme.surfaceRaised)
            if let metal = conductor.metalDiameterInches {
                Circle()
                    .fill(Theme.energized)
                    .frame(
                        width: max(CGFloat(metal) * scene.scale, 1),
                        height: max(CGFloat(metal) * scene.scale, 1)
                    )
            }
            Circle()
                .stroke(conductor.overlaps ? Theme.bad : Theme.foreground.opacity(0.8), lineWidth: conductor.overlaps ? 2 : 1)
            if diameter >= 18, !conductor.role.letter.isEmpty {
                Text(conductor.role.letter)
                    .font(.system(size: min(13, diameter * 0.36), weight: .bold))
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(ink(on: conductor.colorName))
            }
        }
        .frame(width: diameter, height: diameter)
        .position(center)
    }

    private func dimensionLine(_ scene: ConduitSectionScene) -> some View {
        let y = scene.center.y + scene.outerPoints / 2 + 14
        let left = scene.center.x - scene.innerPoints / 2
        let right = scene.center.x + scene.innerPoints / 2
        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: left, y: y))
                path.addLine(to: CGPoint(x: right, y: y))
                path.move(to: CGPoint(x: left, y: y - 4))
                path.addLine(to: CGPoint(x: left, y: y + 4))
                path.move(to: CGPoint(x: right, y: y - 4))
                path.addLine(to: CGPoint(x: right, y: y + 4))
            }
            .stroke(Theme.accent, lineWidth: 1)
            Text("ID \(Format.number(layout.bore.internalDiameterInches, digits: 3)) in")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .position(x: scene.center.x, y: y + 12)
        }
    }

    private var callouts: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            callout("ID", Format.number(layout.bore.internalDiameterInches, digits: 3) + " in")
            callout("OD", outsideCallout)
            callout("Wall", wallCallout)
            callout("Wire OD", wireCallout)
            callout("Free area", Format.percent(layout.freeAreaPercent))
            callout("Conductors", "\(layout.conductors.count)")
        }
    }

    private func callout(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.4)
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: Theme.touchTarget, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var outsideCallout: String {
        if let outside = layout.bore.outsideDiameterInches {
            return Format.number(outside, digits: 3) + " in"
        }
        return "Not a single listed OD"
    }

    private var wallCallout: String {
        if let wall = layout.bore.wallThicknessInches {
            return Format.number(wall, digits: 3) + " in"
        }
        return "Bore only"
    }

    private var wireCallout: String {
        let diameters = Set(layout.legend.map { Format.number($0.overallDiameterInches, digits: 3) })
        if diameters.count == 1, let only = diameters.first {
            return "\(only) in"
        }
        return "Mixed — see legend"
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = layout.colorSystemTitle {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            ForEach(layout.legend) { line in
                HStack(spacing: 8) {
                    Circle()
                        .fill(line.colorName.flatMap { conventionColor($0) } ?? Theme.surfaceRaised)
                        .overlay(Circle().stroke(Theme.foreground.opacity(0.45), lineWidth: 1))
                        .frame(width: 14, height: 14)
                        .accessibilityHidden(true)
                    Text(legendTitle(line))
                        .font(.caption2.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Text("OD \(Format.number(line.overallDiameterInches, digits: 3)) in")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                }
                .accessibilityElement(children: .combine)
            }
            Text(layout.legendDisclaimer)
                .font(.caption2)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text(layout.bore.dimensionNote)
                .font(.caption2)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func legendTitle(_ line: ConduitLegendLine) -> String {
        let role = line.role == .unmarked ? "" : " \(line.role.displayName)"
        let color = line.colorName.map { " · \($0)" } ?? ""
        return "\(line.count) × \(line.sizeLabel) \(line.insulationName)\(role)\(color)"
    }

    private var asnzsLine: some View {
        let tone = layout.exceedsASNZSGuidance ? Theme.warn : Theme.muted
        return Text("AS/NZS 3000 Appendix C C6.2 space factor \(Format.percent(layout.asnzsSpaceFactorPercent)) for this count. Guidance only — the pass/fail is still NEC, and metric bores are not listed.")
            .font(.caption2)
            .foregroundStyle(tone)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var guidance: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(layout.guidance) { note in
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                    Text(note.body)
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var wallColor: Color {
        switch layout.raceway {
        case .pvc40, .pvc80, .ent:
            return Theme.accent.opacity(0.28)
        default:
            return Theme.muted.opacity(0.45)
        }
    }

    private func conventionColor(_ name: String) -> Color? {
        switch name.lowercased() {
        case "black": return Color(white: 0.12)
        case "red": return Color(red: 0.78, green: 0.12, blue: 0.14)
        case "blue": return Color(red: 0.15, green: 0.35, blue: 0.78)
        case "white": return Color(white: 0.96)
        case "green": return Color(red: 0.12, green: 0.55, blue: 0.28)
        case "brown": return Color(red: 0.45, green: 0.28, blue: 0.14)
        case "orange": return Color(red: 0.90, green: 0.48, blue: 0.10)
        case "yellow": return Color(red: 0.93, green: 0.78, blue: 0.15)
        case "grey", "gray": return Color(white: 0.62)
        default: return nil
        }
    }

    private func ink(on name: String?) -> Color {
        switch name?.lowercased() {
        case "white", "yellow", "orange", "grey", "gray", nil:
            return Color(white: 0.12)
        default:
            return Color.white
        }
    }
}

/// Points-per-inch mapping for one bore drawing. Kept out of the `ZStack`
/// so the view builder does not mix `Double` geometry with `CGFloat` frames.
private struct ConduitSectionScene {
    let center: CGPoint
    let scale: CGFloat
    let outerPoints: CGFloat
    let innerPoints: CGFloat

    init(size: CGSize, bore: ConduitRacewayBore) {
        let outer = bore.outsideDiameterInches ?? bore.internalDiameterInches
        let top: Double = 22
        let bottom: Double = 48
        let availableW = max(Double(size.width) - 12, 80)
        let availableH = max(Double(size.height) - top - bottom, 80)
        let pointsPerInch = min(availableW, availableH) / outer
        scale = CGFloat(pointsPerInch)
        outerPoints = CGFloat(outer * pointsPerInch)
        innerPoints = CGFloat(bore.internalDiameterInches * pointsPerInch)
        center = CGPoint(x: size.width / 2, y: top + outerPoints / 2)
    }

    func point(x: Double, y: Double) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(x) * scale,
            y: center.y - CGFloat(y) * scale
        )
    }
}
