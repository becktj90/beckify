import SwiftUI
import BeckifyMath

/// Orthographic conductor cross-section for Wire Size & Ampacity.
/// Geometry from `AmpacityConductorLayout` — drawn to scale, not actual size.
struct ConductorCrossSectionDiagram: View {
    let layout: AmpacityConductorLayout
    @State private var showInspector = false

    var body: some View {
        DiagramCard(
            title: "Conductor cross-section",
            accessibilitySummary: layout.accessibilitySummary,
            exportName: "wire-ampacity-section"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                drawing
                    .frame(height: 220)
                    .accessibilityHidden(true)
                scaleBarRow
                calloutChips
                Text(layout.packingNote)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    showInspector = true
                } label: {
                    Label("Parameter inspector", systemImage: "list.bullet.rectangle")
                        .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Opens geometry and ampacity values for this conductor.")
            }
        }
        .accessibilityIdentifier("wireAmpacity.conductorSection")
        .sheet(isPresented: $showInspector) {
            NavigationStack {
                List {
                    Section("Geometry") {
                        ForEach(layout.inspectorRows.filter { $0.section == .geometry }) { row in
                            LabeledContent(row.title, value: row.value)
                        }
                    }
                    Section("Ampacity") {
                        ForEach(layout.inspectorRows.filter { $0.section == .ampacity }) { row in
                            LabeledContent(row.title, value: row.value)
                        }
                    }
                    Section("Sources / limits") {
                        Text(layout.phaseGeometry.geometryNote)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                        ForEach(Array(layout.phaseGeometry.citations.enumerated()), id: \.offset) { _, cite in
                            Text("\(cite.articleOrTable) — \(cite.sourceDescription)")
                                .font(.caption2)
                                .foregroundStyle(Theme.muted)
                        }
                        Text("3D cutaway deferred. Construction type is not invented from the 60/75/90 °C columns.")
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .navigationTitle("Conductor parameters")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showInspector = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var drawing: some View {
        GeometryReader { geo in
            let scene = ConductorSectionScene(size: geo.size, layout: layout)
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.background)
                ForEach(layout.conductors) { conductor in
                    conductorMark(conductor, scene: scene)
                }
                ForEach(layout.callouts) { callout in
                    leader(callout, scene: scene)
                }
            }
        }
    }

    private func conductorMark(_ conductor: AmpacityDrawnConductor, scene: ConductorSectionScene) -> some View {
        let od = max(CGFloat(conductor.geometry.overallDiameterInches) * scene.pointsPerInch, 2)
        let metal = max(CGFloat(conductor.geometry.metalDiameterInches) * scene.pointsPerInch, 1)
        let center = scene.point(x: conductor.centerXInches, y: conductor.centerYInches)
        return ZStack {
            Circle()
                .fill(conductor.role == .egc ? Theme.good.opacity(0.35) : Theme.copper.opacity(0.28))
            Circle()
                .fill(conductor.role == .egc ? Theme.good.opacity(0.85) : Theme.energized)
                .frame(width: metal, height: metal)
            Circle()
                .stroke(Theme.foreground.opacity(0.85), lineWidth: 1)
            if od >= 16 {
                Text(conductor.role == .egc ? "G" : (layout.parallelRuns > 1 ? "\(conductor.id + 1)" : "φ"))
                    .font(.system(size: min(12, od * 0.32), weight: .bold))
                    .foregroundStyle(Theme.foreground)
            }
        }
        .frame(width: od, height: od)
        .position(center)
    }

    private func leader(_ callout: AmpacityCallout, scene: ConductorSectionScene) -> some View {
        let anchor = scene.point(x: callout.anchorXInches, y: callout.anchorYInches)
        let label = scene.point(x: callout.labelXInches, y: callout.labelYInches)
        let color: Color = callout.kind == .geometry ? Theme.accent : Theme.copper
        return ZStack {
            Path { path in
                path.move(to: anchor)
                path.addLine(to: label)
            }
            .stroke(color.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: callout.kind == .ampacity ? [4, 3] : []))
            Circle()
                .fill(color)
                .frame(width: 4, height: 4)
                .position(anchor)
            Text("\(callout.title) \(callout.value)")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Theme.surfaceRaised.opacity(0.92), in: Capsule())
                .position(label)
        }
    }

    private var scaleBarRow: some View {
        HStack(spacing: 8) {
            ScaleBarView(inches: layout.scaleBarInches, pointsPerInch: scalePointsPerInch)
            Text("Drawn to scale")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 0)
            Text(String(format: "%.2f in bar", layout.scaleBarInches))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Drawn to scale. Scale bar \(String(format: "%.2f", layout.scaleBarInches)) inches.")
    }

    private var scalePointsPerInch: CGFloat {
        // Match the drawing's fitted scale for a typical card width.
        let fit = 280 / max(layout.viewWidthInches, 0.1)
        return CGFloat(fit)
    }

    private var calloutChips: some View {
        let geometry = layout.callouts.filter { $0.kind == .geometry }
        let ampacity = layout.callouts.filter { $0.kind == .ampacity }
        return VStack(alignment: .leading, spacing: 6) {
            if !geometry.isEmpty {
                Text("Geometry")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                chipRow(geometry, tint: Theme.accent)
            }
            if !ampacity.isEmpty {
                Text("Ampacity")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                chipRow(ampacity, tint: Theme.copper)
            }
        }
    }

    private func chipRow(_ items: [AmpacityCallout], tint: Color) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
            ForEach(items) { item in
                HStack {
                    Text(item.title)
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                    Spacer(minLength: 4)
                    Text(item.value)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(tint)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

private struct ScaleBarView: View {
    let inches: Double
    let pointsPerInch: CGFloat

    var body: some View {
        let width = max(CGFloat(inches) * pointsPerInch, 12)
        return ZStack(alignment: .bottom) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 8))
                path.addLine(to: CGPoint(x: width, y: 8))
                path.move(to: CGPoint(x: 0, y: 4))
                path.addLine(to: CGPoint(x: 0, y: 12))
                path.move(to: CGPoint(x: width, y: 4))
                path.addLine(to: CGPoint(x: width, y: 12))
            }
            .stroke(Theme.accent, lineWidth: 1.5)
        }
        .frame(width: width, height: 14)
        .accessibilityHidden(true)
    }
}

private struct ConductorSectionScene {
    let size: CGSize
    let layout: AmpacityConductorLayout
    let pointsPerInch: CGFloat
    let center: CGPoint

    init(size: CGSize, layout: AmpacityConductorLayout) {
        self.size = size
        self.layout = layout
        let pad: CGFloat = 28
        let usableW = max(size.width - pad * 2, 1)
        let usableH = max(size.height - pad * 2, 1)
        let sx = usableW / CGFloat(max(layout.viewWidthInches, 0.1))
        let sy = usableH / CGFloat(max(layout.viewHeightInches, 0.1))
        pointsPerInch = min(sx, sy)
        center = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    func point(x: Double, y: Double) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(x) * pointsPerInch,
            y: center.y - CGFloat(y) * pointsPerInch
        )
    }
}
