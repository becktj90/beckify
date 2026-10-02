import SwiftUI
import Charts
import BeckifyMath

// MARK: - Shared diagram helpers

struct EngineeringDiagramFrame<Content: View>: View {
    var summary: String
    @ViewBuilder var content: Content

    var body: some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary)
    }
}

// MARK: - Voltage drop conductor run

/// Strip geometry in `Double` space. The run is 0% at the supply node through
/// a scale that always keeps the 3% and 5% marks on the bar.
private struct VoltageDropStripLayout {
    let width: CGFloat
    let height: CGFloat
    let trackMinX: CGFloat
    let trackMaxX: CGFloat
    let runMinX: CGFloat
    let runMaxX: CGFloat
    let trackY: CGFloat
    let trackHeight: CGFloat
    let nodeRadius: CGFloat
    let scaleMax: Double
    let dropPercent: Double
    let targetPercent: Double?

    init(size: CGSize, dropPercent: Double, targetPercent: Double?) {
        let w: Double = Double(size.width)
        let h: Double = Double(size.height)
        let inset: Double = min(28, w * 0.08)

        width = CGFloat(w)
        height = CGFloat(h)
        trackMinX = CGFloat(inset)
        trackMaxX = CGFloat(w - inset)
        nodeRadius = 8
        trackHeight = 14
        trackY = CGFloat(h * 0.34)
        runMinX = trackMinX + nodeRadius + 8
        runMaxX = trackMaxX - nodeRadius - 8
        let span: Double = max(dropPercent, targetPercent ?? 0, 5)
        scaleMax = span * 1.12
        self.dropPercent = dropPercent
        self.targetPercent = targetPercent
    }

    var supply: CGPoint { CGPoint(x: trackMinX, y: trackY) }
    var load: CGPoint { CGPoint(x: trackMaxX, y: trackY) }
    var midX: CGFloat { (runMinX + runMaxX) / 2 }
    var runWidth: CGFloat { max(runMaxX - runMinX, 1) }

    func x(for percent: Double) -> CGFloat {
        guard scaleMax > 0 else { return runMinX }
        let t: Double = min(max(percent / scaleMax, 0), 1)
        return runMinX + CGFloat(t) * runWidth
    }

    var fillWidth: CGFloat { max(0, x(for: dropPercent) - runMinX) }

    var dropLabelY: CGFloat { max(trackY - 22, 12) }
    var bandLabelY: CGFloat { trackY + trackHeight / 2 + 22 }
    var bandLabelYStacked: CGFloat { bandLabelY + 16 }
    var targetMarkY: CGFloat { bandLabelYStacked + 18 }
    var targetLabelY: CGFloat { targetMarkY + 14 }

    func tick(at percent: Double) -> Path {
        let x: CGFloat = x(for: percent)
        let top: CGFloat = trackY - trackHeight / 2 - 2
        let bottom: CGFloat = trackY + trackHeight / 2 + 12
        var path = Path()
        path.move(to: CGPoint(x: x, y: top))
        path.addLine(to: CGPoint(x: x, y: bottom))
        return path
    }

    /// Sits in the slot the preferred-target label uses, when this tool has no target.
    var ampacityChipY: CGFloat { min(height - 18, bandLabelYStacked + 30) }

    var targetMark: Path {
        guard let targetPercent else { return Path() }
        let x: CGFloat = x(for: targetPercent)
        let y: CGFloat = targetMarkY
        var path = Path()
        path.move(to: CGPoint(x: x, y: y - 7))
        path.addLine(to: CGPoint(x: x - 5, y: y + 2))
        path.addLine(to: CGPoint(x: x + 5, y: y + 2))
        path.closeSubpath()
        return path
    }

    var bandGap: CGFloat { abs(x(for: 5) - x(for: 3)) }
    /// Room for the word "note" under each mark. Narrow runs keep the percent only.
    var showsBandNote: Bool { bandGap >= 68 }
    /// Percent labels move to two rows when the marks themselves are close.
    var stacksBandLabels: Bool { bandGap < 36 }
}

/// Ampacity status drawn on the voltage-drop strip. Meet is good, short is bad.
struct VoltageDropAmpacityChip: Equatable {
    var line: String
    var meets: Bool
}

struct VoltageDropDiagram: View {
    let supply: Double
    let drop: Double
    let receiving: Double
    let dropPercent: Double
    let oneWayLength: String
    let parallelRuns: Int
    var targetPercent: Double? = nil
    var meetsTarget: Bool? = nil
    var ampacityChip: VoltageDropAmpacityChip? = nil
    /// When set, the run fill uses this tone instead of the 3% / 5% good-warn-bad scale.
    /// The 3% and 5% marks stay informational either way.
    var dropFill: Color? = nil
    /// When set, VoiceOver reads this instead of the strip's own sentence. Numbers first.
    var spokenSummary: String? = nil
    var exportName: String = "voltage-drop-run"
    var accessibilityID: String? = nil

    private var summary: String {
        if let spokenSummary { return spokenSummary }
        var clauses: [String] = [
            "\(Format.volts(drop)) drop, \(Format.percent(dropPercent))",
            "\(Format.volts(supply)) supply",
            "\(Format.volts(receiving)) load",
            "\(oneWayLength) one-way",
            "\(parallelRuns) \(parallelRuns == 1 ? "parallel run" : "parallel runs")",
        ]
        if let targetPercent {
            clauses.append("\(Format.percent(targetPercent)) preferred target, \((meetsTarget ?? false) ? "meets" : "over")")
        }
        clauses.append("3% and 5% marks are informational")
        return clauses.joined(separator: ". ") + "."
    }

    /// Within 3% good, between 3% and 5% warn, over 5% bad — unless the caller
    /// already has a drop tone of its own. Bands stay notes in either case.
    private var dropTone: Color {
        if let dropFill { return dropFill }
        if dropPercent <= 3 { return Theme.good }
        if dropPercent <= 5 { return Theme.warn }
        return Theme.bad
    }

    private var targetTone: Color { (meetsTarget ?? false) ? Theme.good : Theme.warn }

    private var lengthLine: String {
        let runs = parallelRuns == 1 ? "1 run" : "\(parallelRuns) runs"
        return "\(oneWayLength) · \(runs)"
    }

    private var dropLine: String { "\(Format.volts(drop)) · \(Format.percent(dropPercent))" }

    private var targetLine: String {
        guard let targetPercent else { return "" }
        return "\(Format.percent(targetPercent)) · \((meetsTarget ?? false) ? "MEETS" : "OVER")"
    }

    var body: some View {
        DiagramCard(title: "Conductor run", accessibilitySummary: summary, exportName: exportName) {
            VStack(alignment: .leading, spacing: 6) {
                EngineeringDiagramFrame(summary: summary) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            endpoint("Supply", Format.volts(supply), alignment: .leading)
                            Spacer(minLength: 8)
                            endpoint("Load", Format.volts(receiving), alignment: .trailing)
                        }
                        Text(lengthLine)
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity, alignment: .center)
                        GeometryReader { geo in
                            strip(VoltageDropStripLayout(
                                size: geo.size,
                                dropPercent: dropPercent,
                                targetPercent: targetPercent
                            ))
                        }
                        .frame(minHeight: 164)
                    }
                }
                Text("3% and 5% marks are informational.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .accessibilityHidden(true)
            }
        }
        .modifier(OptionalAccessibilityID(id: accessibilityID))
    }

    private func endpoint(_ title: String, _ value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    @ViewBuilder
    private func strip(_ layout: VoltageDropStripLayout) -> some View {
        ZStack {
            Capsule()
                .fill(Theme.chartGrid)
                .frame(width: layout.runWidth, height: layout.trackHeight)
                .position(x: layout.midX, y: layout.trackY)
            if layout.fillWidth > 0.5 {
                Capsule()
                    .fill(dropTone)
                    .frame(width: layout.fillWidth, height: layout.trackHeight)
                    .position(x: layout.runMinX + layout.fillWidth / 2, y: layout.trackY)
            }
            layout.tick(at: 3)
                .stroke(Theme.foreground.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            layout.tick(at: 5)
                .stroke(Theme.foreground.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            Circle()
                .fill(Theme.surfaceRaised)
                .overlay(Circle().stroke(Theme.accent, lineWidth: Theme.Stroke.emphasis))
                .frame(width: layout.nodeRadius * 2, height: layout.nodeRadius * 2)
                .position(layout.supply)
            RoundedRectangle(cornerRadius: 3)
                .fill(Theme.surfaceRaised)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.energized, lineWidth: Theme.Stroke.emphasis))
                .frame(width: layout.nodeRadius * 2, height: layout.nodeRadius * 2)
                .position(layout.load)
            if layout.targetPercent != nil {
                layout.targetMark
                    .fill(targetTone)
            }
            stripLabels(layout)
            if let ampacityChip, layout.targetPercent == nil {
                ampacityChipView(ampacityChip, layout: layout)
            }
        }
    }

    private func ampacityChipView(_ chip: VoltageDropAmpacityChip, layout: VoltageDropStripLayout) -> some View {
        let tone = chip.meets ? Theme.good : Theme.bad
        return Text(chip.line)
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(tone)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tone.opacity(0.16), in: Capsule())
            .overlay(Capsule().stroke(tone, lineWidth: Theme.Stroke.hairline))
            .frame(maxWidth: max(layout.width - 24, 40))
            .position(x: layout.midX, y: layout.ampacityChipY)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func stripLabels(_ layout: VoltageDropStripLayout) -> some View {
        Text(dropLine)
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(dropTone)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .position(x: layout.midX, y: layout.dropLabelY)

        bandLabel(layout.showsBandNote ? "3% note" : "3%", at: layout.x(for: 3), y: layout.bandLabelY)
        bandLabel(
            layout.showsBandNote ? "5% note" : "5%",
            at: layout.x(for: 5),
            y: layout.stacksBandLabels ? layout.bandLabelYStacked : layout.bandLabelY
        )

        if let targetPercent = layout.targetPercent {
            Text(targetLine)
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(targetTone)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .position(x: clampedLabelX(layout.x(for: targetPercent), width: layout.width), y: layout.targetLabelY)
        }
    }

    private func bandLabel(_ text: String, at x: CGFloat, y: CGFloat) -> some View {
        Text(text)
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(Theme.muted)
            .lineLimit(1)
            .position(x: x, y: y)
    }

    private func clampedLabelX(_ x: CGFloat, width: CGFloat) -> CGFloat {
        min(max(x, 40), max(width - 40, 40))
    }

    /// Prefer `VoltageDropRunReadout` / `NECCircuitRunReadout` so table % and strip % share one model field.
    /// Pass `dropPercent` (never volts) into the percent slot — volts-as-% made the classic #4 Cu example read ~6%.
    static func model(
        supply: Double,
        drop: Double,
        receiving: Double,
        dropPercent: Double,
        oneWayLength: String,
        parallelRuns: Int,
        targetPercent: Double? = nil,
        meetsTarget: Bool? = nil,
        ampacityChip: VoltageDropAmpacityChip? = nil,
        dropFill: Color? = nil,
        spokenSummary: String? = nil,
        exportName: String = "voltage-drop-run",
        accessibilityID: String? = nil
    ) -> VoltageDropDiagram? {
        guard supply.isFinite, supply > 0,
              drop.isFinite, drop >= 0,
              receiving.isFinite,
              dropPercent.isFinite, dropPercent >= 0,
              parallelRuns >= 1,
              !oneWayLength.isEmpty
        else { return nil }
        if let targetPercent {
            guard targetPercent.isFinite, targetPercent > 0 else { return nil }
        } else if meetsTarget != nil {
            return nil
        }
        if let ampacityChip, ampacityChip.line.isEmpty { return nil }
        if let spokenSummary, spokenSummary.isEmpty { return nil }
        return VoltageDropDiagram(
            supply: supply,
            drop: drop,
            receiving: receiving,
            dropPercent: dropPercent,
            oneWayLength: oneWayLength,
            parallelRuns: parallelRuns,
            targetPercent: targetPercent,
            meetsTarget: meetsTarget,
            ampacityChip: ampacityChip,
            dropFill: dropFill,
            spokenSummary: spokenSummary,
            exportName: exportName,
            accessibilityID: accessibilityID
        )
    }
}

/// Applies an accessibility identifier only when the caller has one.
private struct OptionalAccessibilityID: ViewModifier {
    var id: String?

    func body(content: Content) -> some View {
        if let id {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}

// MARK: - Power triangle

/// Leg lengths in points plus the shared triangle path, so the stroke and its
/// fill reuse one path instead of rebuilding the same expression twice.
private struct PowerTriangleLayout {
    let origin: CGPoint
    let realLeg: CGFloat
    let reactiveLeg: CGFloat
    let isDrawable: Bool

    init(size: CGSize, kw: Double, kvar: Double, kva: Double) {
        let w: Double = Double(size.width)
        let h: Double = Double(size.height)
        let drawable: Bool = kw.isFinite && kvar.isFinite && kva.isFinite && kva > 0
        let maxLeg: Double = min(w * 0.7, h * 0.7)
        let scale: Double = max(kva, 0.001)

        origin = CGPoint(x: CGFloat(w * 0.14), y: CGFloat(h * 0.82))
        realLeg = drawable ? CGFloat(kw / scale * maxLeg) : 0
        reactiveLeg = drawable ? CGFloat(abs(kvar) / scale * maxLeg) : 0
        isDrawable = drawable
    }

    var trianglePath: Path {
        var path = Path()
        guard isDrawable else { return path }
        path.move(to: origin)
        path.addLine(to: CGPoint(x: origin.x + realLeg, y: origin.y))
        path.addLine(to: CGPoint(x: origin.x + realLeg, y: origin.y - reactiveLeg))
        path.closeSubpath()
        return path
    }
}

/// Before/after legs in one drawing. kW is resolved once from the shared scale.
private struct PowerFactorTriangleLayout {
    let origin: CGPoint
    let realLeg: CGFloat
    let existingLeg: CGFloat
    let targetLeg: CGFloat

    init(size: CGSize, comparison: PowerTriangleComparison) {
        let w: Double = Double(size.width)
        let h: Double = Double(size.height)
        let maxLeg: Double = min(w * 0.56, h * 0.52)
        origin = CGPoint(x: CGFloat(w * 0.12), y: CGFloat(h * 0.72))
        realLeg = CGFloat(comparison.realLeg * maxLeg)
        existingLeg = CGFloat(comparison.existingReactiveLeg * maxLeg)
        targetLeg = CGFloat(comparison.targetReactiveLeg * maxLeg)
    }
}

/// Right triangle whose reactive leg can shrink. The real leg is not animatable.
private struct RightTriangleShape: Shape {
    var origin: CGPoint
    var realLeg: CGFloat
    var reactiveLeg: CGFloat

    var animatableData: CGFloat {
        get { reactiveLeg }
        set { reactiveLeg = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: origin)
        path.addLine(to: CGPoint(x: origin.x + realLeg, y: origin.y))
        path.addLine(to: CGPoint(x: origin.x + realLeg, y: origin.y - reactiveLeg))
        path.closeSubpath()
        return path
    }
}

struct PowerTriangleDiagram: View {
    let kw: Double
    let kvar: Double
    let kva: Double
    var title: String = "Power triangle"
    var comparison: PowerTriangleComparison? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shrinkProgress: CGFloat = 0

    init(kw: Double, kvar: Double, kva: Double, title: String = "Power triangle") {
        self.kw = kw
        self.kvar = kvar
        self.kva = kva
        self.title = title
        self.comparison = nil
    }

    init(comparison: PowerTriangleComparison) {
        self.kw = comparison.realPowerKW
        self.kvar = comparison.targetKVAR
        self.kva = comparison.scaleKVA
        self.title = "Power triangle"
        self.comparison = comparison
    }

    private var summary: String {
        if let comparison {
            return comparison.announcement
        }
        return "Power triangle. True \(Format.number(kw, digits: 2)) kW, reactive \(Format.number(kvar, digits: 2)) kVAR, apparent \(Format.number(kva, digits: 2)) kVA."
    }

    var body: some View {
        if let comparison {
            beforeAfter(comparison)
        } else {
            singleTriangle
        }
    }

    private var singleTriangle: some View {
        DiagramCard(title: title, accessibilitySummary: summary) {
            EngineeringDiagramFrame(summary: summary) {
                GeometryReader { geo in
                    triangle(PowerTriangleLayout(size: geo.size, kw: kw, kvar: kvar, kva: kva))
                }
            }
        }
    }

    private func beforeAfter(_ comparison: PowerTriangleComparison) -> some View {
        DiagramCard(title: "Power triangle", accessibilitySummary: comparison.announcement) {
            VStack(alignment: .leading, spacing: 6) {
                EngineeringDiagramFrame(summary: comparison.announcement) {
                    GeometryReader { geo in
                        comparisonCanvas(
                            PowerFactorTriangleLayout(size: geo.size, comparison: comparison),
                            comparison: comparison
                        )
                    }
                }
                .frame(minHeight: 168)
                if let caption = comparison.bankCaption {
                    Text(caption)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                        .accessibilityHidden(true)
                }
            }
        }
        .onAppear(perform: playShrink)
        .onChange(of: comparison) { _, _ in
            replayShrink()
        }
    }

    @ViewBuilder
    private func triangle(_ layout: PowerTriangleLayout) -> some View {
        layout.trianglePath
            .stroke(Theme.accent, lineWidth: 2)
            .background(layout.trianglePath.fill(Theme.chartFill))

        legLabels(layout)
    }

    @ViewBuilder
    private func legLabels(_ layout: PowerTriangleLayout) -> some View {
        let origin: CGPoint = layout.origin
        let p: CGFloat = layout.realLeg
        let q: CGFloat = layout.reactiveLeg

        Text("kW")
            .font(.caption2)
            .foregroundStyle(Theme.muted)
            .position(x: origin.x + p / 2, y: origin.y + 12)
        Text("kVAR")
            .font(.caption2)
            .foregroundStyle(Theme.muted)
            .position(x: origin.x + p + 22, y: origin.y - q / 2)
        Text("kVA")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.accent2)
            .position(x: origin.x + p / 2 - 8, y: origin.y - q / 2 - 8)
    }

    private func comparisonCanvas(_ layout: PowerFactorTriangleLayout, comparison: PowerTriangleComparison) -> some View {
        let moving: CGFloat = movingLeg(layout)
        return ZStack {
            RightTriangleShape(origin: layout.origin, realLeg: layout.realLeg, reactiveLeg: layout.existingLeg)
                .stroke(Theme.warn, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            RightTriangleShape(origin: layout.origin, realLeg: layout.realLeg, reactiveLeg: moving)
                .fill(Theme.good.opacity(0.16))
            RightTriangleShape(origin: layout.origin, realLeg: layout.realLeg, reactiveLeg: moving)
                .stroke(Theme.good, lineWidth: 2.5)
            Path { path in
                path.move(to: layout.origin)
                path.addLine(to: CGPoint(x: layout.origin.x + layout.realLeg, y: layout.origin.y))
            }
            .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            comparisonLabels(layout, comparison: comparison)
        }
    }

    /// Reduce Motion draws the target leg in place. Otherwise the good triangle eases down from the existing leg.
    private func movingLeg(_ layout: PowerFactorTriangleLayout) -> CGFloat {
        if reduceMotion { return layout.targetLeg }
        return layout.existingLeg + (layout.targetLeg - layout.existingLeg) * shrinkProgress
    }

    private func comparisonLabels(_ layout: PowerFactorTriangleLayout, comparison: PowerTriangleComparison) -> some View {
        let origin: CGPoint = layout.origin
        let real: CGFloat = layout.realLeg
        let existing: CGFloat = layout.existingLeg
        let target: CGFloat = layout.targetLeg
        let crowded: Bool = abs(existing - target) < 26
        return ZStack {
            Text(comparison.realLabel)
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .position(x: origin.x + real / 2, y: origin.y + 14)
            Text(comparison.existingLabel)
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.warn)
                .position(x: origin.x + real + 46, y: origin.y - existing)
            Text(comparison.targetLabel)
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.good)
                .position(x: origin.x + real + (crowded ? -46 : 46), y: origin.y - target)
        }
    }

    private func playShrink() {
        guard !reduceMotion else {
            shrinkProgress = 1
            return
        }
        shrinkProgress = 0
        withAnimation(.easeInOut(duration: 0.7)) {
            shrinkProgress = 1
        }
    }

    private func replayShrink() {
        guard !reduceMotion else {
            shrinkProgress = 1
            return
        }
        shrinkProgress = 0
        withAnimation(.easeInOut(duration: 0.7).delay(0.02)) {
            shrinkProgress = 1
        }
    }
}

// MARK: - Signal scaling transfer curve

struct SignalScalingChart: View {
    let rawMin: Double
    let rawMax: Double
    let euMin: Double
    let euMax: Double
    let rawValue: Double
    let engineeringValue: Double
    let curve: SignalCurve

    private var summary: String {
        "Transfer curve from raw \(Format.number(rawMin, digits: 2))–\(Format.number(rawMax, digits: 2)) to engineering \(Format.number(euMin, digits: 2))–\(Format.number(euMax, digits: 2)). Point at raw \(Format.number(rawValue, digits: 2)) maps to \(Format.number(engineeringValue, digits: 2))."
    }

    private var samples: [(raw: Double, eu: Double)] {
        let steps = 24
        return (0...steps).compactMap { step in
            let t = Double(step) / Double(steps)
            let raw = rawMin + (rawMax - rawMin) * t
            let span = rawMax - rawMin
            guard span != 0 else { return nil }
            let norm = (raw - rawMin) / span
            let shaped: Double
            switch curve {
            case .linear: shaped = norm
            case .squareRoot: shaped = max(0, norm).squareRoot()
            }
            let eu = euMin + shaped * (euMax - euMin)
            return (raw, eu)
        }
    }

    var body: some View {
        DiagramCard(title: "Transfer curve", accessibilitySummary: summary) {
            Chart {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                    LineMark(
                        x: .value("Raw", sample.raw),
                        y: .value("EU", sample.eu)
                    )
                    .foregroundStyle(Theme.chartPrimary)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                PointMark(
                    x: .value("Raw", rawValue),
                    y: .value("EU", engineeringValue)
                )
                .foregroundStyle(Theme.energized)
                .symbolSize(64)
            }
            .chartXAxisLabel("Raw input")
            .chartYAxisLabel("Engineering (EU)")
            .frame(height: 160)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Load factor demand profile

struct LoadFactorChart: View {
    let average: Double
    let peak: Double
    let capacity: Double

    private var summary: String {
        "Demand profile. Average \(Format.number(average, digits: 1)), peak \(Format.number(peak, digits: 1)), capacity \(Format.number(capacity, digits: 1))."
    }

    var body: some View {
        DiagramCard(title: "Demand profile", accessibilitySummary: summary) {
            Chart {
                BarMark(x: .value("Metric", "Avg"), y: .value("kW", average))
                    .foregroundStyle(Theme.chartPrimary)
                BarMark(x: .value("Metric", "Peak"), y: .value("kW", peak))
                    .foregroundStyle(Theme.chartSecondary)
                RuleMark(y: .value("Capacity", capacity))
                    .foregroundStyle(Theme.bad)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Capacity")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.foreground)
                    }
            }
            .chartXAxisLabel("Case")
            .chartYAxisLabel("Demand (kW)")
            .frame(height: 160)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - 555 waveform sketch

struct Timer555WaveformDiagram: View {
    let frequency: Double
    let dutyPercent: Double

    private var summary: String {
        "Astable output waveform near \(Format.frequency(frequency)) with \(Format.percent(dutyPercent)) duty cycle."
    }

    var body: some View {
        DiagramCard(title: "Output waveform", accessibilitySummary: summary) {
            EngineeringDiagramFrame(summary: summary) {
                GeometryReader { geo in
                    let duty = min(max(dutyPercent / 100, 0.05), 0.95)
                    let w = geo.size.width
                    let high = geo.size.height * 0.25
                    let low = geo.size.height * 0.75
                    let period = w / 3
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: low))
                        for cycle in 0..<3 {
                            let x0 = CGFloat(cycle) * period
                            path.addLine(to: CGPoint(x: x0, y: low))
                            path.addLine(to: CGPoint(x: x0, y: high))
                            path.addLine(to: CGPoint(x: x0 + period * duty, y: high))
                            path.addLine(to: CGPoint(x: x0 + period * duty, y: low))
                            path.addLine(to: CGPoint(x: x0 + period, y: low))
                        }
                    }
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineJoin: .miter))
                }
            }
        }
    }
}

// MARK: - Short-circuit callout

/// One field callout for infinite-bus secondary fault current.
/// The plate is an original flag, not a transformer drawing and not an AIC bar.
struct ShortCircuitDiagram: View {
    let callout: ShortCircuitCallout

    var body: some View {
        DiagramCard(
            title: "Available fault",
            accessibilitySummary: callout.announcement,
            exportName: "short-circuit-fault"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                calloutFace
                Text(ShortCircuitCallout.designAidLine)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityIdentifier("shortCircuit.callout")
    }

    private var calloutFace: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(callout.faultAmpsLabel)
                    .font(.largeTitle.monospacedDigit().weight(.bold))
                    .foregroundStyle(Theme.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let kiloamps = callout.kiloampsLabel {
                    Text(kiloamps)
                        .font(.title2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            Text("Available fault")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
            Rectangle()
                .fill(Theme.border)
                .frame(height: Theme.Stroke.hairline)
            Text(ShortCircuitCallout.methodLine)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 28)
        .padding(.trailing, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Canvas { context, size in
                calloutPath(in: context, size: size)
            }
        }
        .accessibilityHidden(true)
    }

    /// Rounded plate with a left pointer. No windings, no gear bar, no pass or fail mark.
    private func calloutPath(in context: GraphicsContext, size: CGSize) {
        let pointer: CGFloat = 14
        let radius: CGFloat = 10
        let inset: CGFloat = 1.25
        let left = pointer
        let right = size.width - inset
        let top = inset
        let bottom = max(top + radius * 2, size.height - inset)
        let tipY = min(max(size.height * 0.38, top + radius + 12), bottom - radius - 12)
        let notch: CGFloat = 11

        var path = Path()
        path.move(to: CGPoint(x: left + radius, y: top))
        path.addLine(to: CGPoint(x: right - radius, y: top))
        path.addQuadCurve(to: CGPoint(x: right, y: top + radius), control: CGPoint(x: right, y: top))
        path.addLine(to: CGPoint(x: right, y: bottom - radius))
        path.addQuadCurve(to: CGPoint(x: right - radius, y: bottom), control: CGPoint(x: right, y: bottom))
        path.addLine(to: CGPoint(x: left + radius, y: bottom))
        path.addQuadCurve(to: CGPoint(x: left, y: bottom - radius), control: CGPoint(x: left, y: bottom))
        path.addLine(to: CGPoint(x: left, y: tipY + notch))
        path.addLine(to: CGPoint(x: inset, y: tipY))
        path.addLine(to: CGPoint(x: left, y: tipY - notch))
        path.addLine(to: CGPoint(x: left, y: top + radius))
        path.addQuadCurve(to: CGPoint(x: left + radius, y: top), control: CGPoint(x: left, y: top))
        path.closeSubpath()

        context.fill(path, with: .color(Theme.surface))
        context.stroke(
            path,
            with: .color(Theme.foreground.opacity(0.88)),
            style: StrokeStyle(lineWidth: Theme.Stroke.emphasis, lineJoin: .round)
        )
    }
}

// MARK: - Motor torque-speed curve

struct MotorTorqueCurveChart: View {
    let horsepower: Double
    let ratedRPM: Double
    let ratedTorqueLbFt: Double

    private var points: [(rpm: Double, torqueLbFt: Double)] {
        MotorTorque.curve(horsepower: horsepower, minRPM: max(200, ratedRPM * 0.3), maxRPM: ratedRPM * 2.2)
    }

    private var summary: String {
        "Constant \(Format.number(horsepower, digits: 1)) horsepower torque curve. Rated point \(Format.number(ratedTorqueLbFt, digits: 2)) pound-feet at \(Format.number(ratedRPM, digits: 0)) RPM."
    }

    var body: some View {
        DiagramCard(title: "Torque vs. speed", accessibilitySummary: summary) {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    LineMark(x: .value("RPM", point.rpm), y: .value("Torque", point.torqueLbFt))
                        .foregroundStyle(Theme.chartPrimary)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }
                PointMark(x: .value("RPM", ratedRPM), y: .value("Torque", ratedTorqueLbFt))
                    .foregroundStyle(Theme.energized)
                    .symbolSize(64)
            }
            .chartXAxisLabel("Speed (RPM)")
            .chartYAxisLabel("Torque (lb·ft)")
            .frame(height: 160)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - RF path loss vs. distance

struct PathLossDistanceChart: View {
    let frequencyMHz: Double
    let currentDistance: Double
    let currentLossDB: Double

    private var points: [(distance: Double, lossDB: Double)] {
        FreeSpacePathLoss.distanceSweep(
            frequencyMHz: frequencyMHz,
            minMetres: max(1, currentDistance * 0.05),
            maxMetres: max(currentDistance * 4, 10)
        )
    }

    private var summary: String {
        "Free-space path loss versus distance at \(Format.number(frequencyMHz, digits: 0)) megahertz. Current point \(Format.number(currentDistance, digits: 1)) metres, \(Format.number(currentLossDB, digits: 1)) decibels."
    }

    var body: some View {
        DiagramCard(title: "Loss vs. distance", accessibilitySummary: summary) {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    LineMark(x: .value("Distance", point.distance), y: .value("Loss", point.lossDB))
                        .foregroundStyle(Theme.chartPrimary)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }
                PointMark(x: .value("Distance", currentDistance), y: .value("Loss", currentLossDB))
                    .foregroundStyle(Theme.energized)
                    .symbolSize(64)
            }
            .chartXScale(type: .log)
            .chartXAxisLabel("Distance (m, log)")
            .chartYAxisLabel("Loss (dB)")
            .frame(height: 160)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Phasor plot

struct PhasorPolarDiagram: View {
    let phasors: [Phasor]
    let resultantMagnitude: Double
    let resultantAngleDegrees: Double

    private var maxMagnitude: Double {
        max(phasors.map(\.magnitude).max() ?? 1, resultantMagnitude, 1)
    }

    private var summary: String {
        "Phasor diagram with \(phasors.count) inputs. Resultant \(Format.number(resultantMagnitude, digits: 2)) at \(Format.number(resultantAngleDegrees, digits: 1)) degrees."
    }

    private static let palette: [Color] = [Theme.chartPrimary, Theme.chartSecondary, Theme.chartTertiary]

    var body: some View {
        DiagramCard(title: "Phasor plot", accessibilitySummary: summary) {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 * 0.82
                let scale = radius / CGFloat(maxMagnitude)

                context.stroke(
                    Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(Theme.chartGrid),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )

                for (index, phasor) in phasors.enumerated() {
                    let rad = phasor.angleDegrees * .pi / 180
                    let length = CGFloat(phasor.magnitude) * scale
                    let tip = CGPoint(x: center.x + cos(rad) * length, y: center.y - sin(rad) * length)
                    var path = Path()
                    path.move(to: center)
                    path.addLine(to: tip)
                    let color = Self.palette[index % Self.palette.count]
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    context.fill(
                        Path(ellipseIn: CGRect(x: tip.x - 3, y: tip.y - 3, width: 6, height: 6)),
                        with: .color(color)
                    )
                }

                guard resultantMagnitude > 0 else { return }
                let rad = resultantAngleDegrees * .pi / 180
                let length = CGFloat(resultantMagnitude) * scale
                let tip = CGPoint(x: center.x + cos(rad) * length, y: center.y - sin(rad) * length)
                var resultantPath = Path()
                resultantPath.move(to: center)
                resultantPath.addLine(to: tip)
                context.stroke(resultantPath, with: .color(Theme.bad), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 3]))
            }
            .frame(height: 180)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - RC/RL transient response curve

struct TransientResponseChart: View {
    let curve: [(time: Double, value: Double)]
    let currentTime: Double
    let currentValue: Double
    let unit: String
    var timeConstant: Double? = nil
    /// `currentTime` reads the live Time field while `currentValue`/`curve` hold
    /// the last calculated result — after an edit without recalculating, those
    /// disagree. Suppress the marker rather than plot it at a point the curve
    /// never actually passes through.
    var isStale: Bool = false

    private var summary: String {
        "Step response curve. At \(Format.number(currentTime, digits: 3)) s, value is \(Format.number(currentValue, digits: 3)) \(unit)."
    }

    private var points: [PlotPoint] {
        curve.map { PlotPoint(x: $0.time, y: $0.value) }
    }

    var body: some View {
        DiagramCard(title: "Response curve", accessibilitySummary: summary, exportName: "transient-response") {
            EngineerLinePlot(
                series: [EngineerSeries(name: unit, points: points, color: Theme.chartPrimary, fills: true)],
                xLabel: "Time (s)",
                yLabel: unit,
                markers: isStale ? [] : [
                    EngineerMarker(x: currentTime, y: currentValue, label: "t", color: Theme.energized),
                ],
                xGuides: timeConstant.map { [EngineerGuide(value: $0, label: "τ", axis: .x)] } ?? []
            )
        }
    }
}

// MARK: - Diode forward I-V curve

struct DiodeIVChart: View {
    let curve: [(voltage: Double, current: Double)]
    let operatingVoltage: Double
    let operatingCurrent: Double

    private var summary: String {
        "Forward I-V curve. Operating point \(Format.number(operatingVoltage, digits: 3)) V, \(Format.number(operatingCurrent * 1000, digits: 3)) mA."
    }

    private var points: [PlotPoint] {
        curve.map { PlotPoint(x: $0.voltage, y: $0.current * 1000) }
    }

    var body: some View {
        DiagramCard(title: "Forward I-V curve", accessibilitySummary: summary, exportName: "diode-iv") {
            EngineerLinePlot(
                series: [EngineerSeries(name: "I_f", points: points, color: Theme.chartPrimary, fills: false)],
                xLabel: "V (V)",
                yLabel: "I (mA)",
                markers: [
                    EngineerMarker(
                        x: operatingVoltage,
                        y: operatingCurrent * 1000,
                        label: "Q",
                        color: Theme.energized
                    ),
                ]
            )
        }
    }
}

// MARK: - Battery bank usable capacity

struct BatteryBankChart: View {
    let usableWattHours: Double
    let totalWattHours: Double
    let runtimeHours: Double

    private var summary: String {
        "Usable \(Format.number(usableWattHours, digits: 0)) watt-hours of \(Format.number(totalWattHours, digits: 0)) total. Runtime \(Format.number(runtimeHours, digits: 2)) hours."
    }

    var body: some View {
        DiagramCard(title: "Usable capacity", accessibilitySummary: summary, exportName: "battery-bank") {
            Chart {
                BarMark(x: .value("Metric", "Total"), y: .value("Wh", totalWattHours))
                    .foregroundStyle(Theme.chartGrid)
                BarMark(x: .value("Metric", "Usable"), y: .value("Wh", usableWattHours))
                    .foregroundStyle(Theme.chartPrimary)
            }
            .chartXAxisLabel("Portion")
            .chartYAxisLabel("Energy (Wh)")
            .frame(height: 160)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Ampacity derating stack

/// Shared bar column. Stages share a left rail. Length is ampacity on one scale
/// that also fits the required-current mark.
private struct DeratingStackLayout {
    let width: CGFloat
    let height: CGFloat
    let titleWidth: CGFloat
    let valueWidth: CGFloat
    let stageCount: Int
    let scale: Double
    let designCurrent: Double?

    init(size: CGSize, scale: Double, stageCount: Int, designCurrent: Double?) {
        width = size.width
        height = size.height
        titleWidth = min(78, max(56, size.width * 0.24))
        valueWidth = min(76, max(52, size.width * 0.22))
        self.stageCount = max(stageCount, 1)
        self.scale = scale
        self.designCurrent = designCurrent
    }

    var showsRequired: Bool { designCurrent != nil }
    var plotMinX: CGFloat { titleWidth + 8 }
    var plotMaxX: CGFloat { max(plotMinX + 1, width - valueWidth - 8) }
    var plotWidth: CGFloat { max(plotMaxX - plotMinX, 1) }
    var footer: CGFloat { showsRequired ? 22 : 4 }
    var rowsHeight: CGFloat { max(height - footer, 1) }

    private func rowHeight() -> CGFloat { rowsHeight / CGFloat(stageCount) }

    func rowMidY(_ index: Int) -> CGFloat {
        let span = rowHeight()
        return CGFloat(index) * span + span / 2
    }

    private func barThickness() -> CGFloat { min(12, rowHeight() * 0.46) }

    func trackRect(_ index: Int) -> CGRect {
        let thickness = barThickness()
        return CGRect(
            x: plotMinX,
            y: rowMidY(index) - thickness / 2,
            width: plotWidth,
            height: thickness
        )
    }

    func barRect(_ index: Int, ampacity: Double) -> CGRect {
        let track = trackRect(index)
        let fraction = scale > 0 ? min(max(ampacity / scale, 0), 1) : 0
        return CGRect(x: track.minX, y: track.minY, width: track.width * CGFloat(fraction), height: track.height)
    }

    func markX() -> CGFloat? {
        guard let designCurrent, scale > 0 else { return nil }
        let fraction = min(max(designCurrent / scale, 0), 1)
        return plotMinX + CGFloat(fraction) * plotWidth
    }

    var requiredLabelY: CGFloat { height - 9 }

    func clampedLabelX(_ x: CGFloat) -> CGFloat {
        let half: CGFloat = 58
        return min(max(x, half), max(width - half, half))
    }

    var rail: Path {
        var path = Path()
        let x = plotMinX - 3
        path.move(to: CGPoint(x: x, y: trackRect(0).minY))
        path.addLine(to: CGPoint(x: x, y: trackRect(stageCount - 1).maxY))
        return path
    }

    func markLine() -> Path? {
        guard let x = markX() else { return nil }
        var path = Path()
        path.move(to: CGPoint(x: x, y: trackRect(0).minY - 3))
        path.addLine(to: CGPoint(x: x, y: trackRect(stageCount - 1).maxY + 4))
        return path
    }
}

/// One picture of the ampacity trace: 310.16 base, ambient, bundling, 110.14(C).
/// Required current is a mark. The canvas is not the VoiceOver value.
struct DeratingStack: View {
    let readout: DeratingStackReadout

    private var verdictColor: Color? {
        switch readout.verdict {
        case .meetsRequired: return Theme.good
        case .belowRequired: return Theme.bad
        case .notCompared: return nil
        }
    }

    var body: some View {
        DiagramCard(
            title: "Derating stack",
            accessibilitySummary: readout.announcement,
            exportName: "derating-stack"
        ) {
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        Canvas { context, size in
                            drawStack(in: context, size: size)
                        }
                        stackLabels(in: geo.size)
                    }
                }
                .frame(height: readout.designCurrent == nil ? 148 : 172)
                .accessibilityHidden(true)
                Text(readout.caption)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityIdentifier("wireAmpacity.deratingStack")
    }

    private func drawStack(in context: GraphicsContext, size: CGSize) {
        let layout = layout(for: size)
        context.stroke(
            layout.rail,
            with: .color(Theme.foreground.opacity(0.45)),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
        )
        for (index, stage) in readout.stages.enumerated() {
            let track = Path(roundedRect: layout.trackRect(index), cornerRadius: 3)
            context.fill(track, with: .color(Theme.chartGrid))
            let barRect = layout.barRect(index, ampacity: stage.ampacity)
            guard barRect.width > 0.4 else { continue }
            let bar = Path(roundedRect: barRect, cornerRadius: min(3, barRect.height / 2))
            let fill = index == readout.stages.count - 1 ? (verdictColor ?? Theme.accent) : Theme.accent
            context.fill(bar, with: .color(fill))
        }
        if let line = layout.markLine(), let verdictColor {
            context.stroke(line, with: .color(Theme.surface), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            context.stroke(line, with: .color(verdictColor), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }

    private func stackLabels(in size: CGSize) -> some View {
        let layout = layout(for: size)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(readout.stages.enumerated()), id: \.element.id) { index, stage in
                Text(stage.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: layout.titleWidth, alignment: .leading)
                    .position(x: layout.titleWidth / 2, y: layout.rowMidY(index))
                Text(DeratingStackReadout.ampsLabel(stage.ampacity))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(index == readout.stages.count - 1 ? (verdictColor ?? Theme.foreground) : Theme.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: layout.valueWidth, alignment: .trailing)
                    .position(x: layout.width - layout.valueWidth / 2, y: layout.rowMidY(index))
            }
            if let required = readout.designCurrentLabel, let mark = layout.markX() {
                Text("Required \(required)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(verdictColor ?? Theme.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .position(x: layout.clampedLabelX(mark), y: layout.requiredLabelY)
            }
        }
    }

    private func layout(for size: CGSize) -> DeratingStackLayout {
        DeratingStackLayout(
            size: size,
            scale: readout.scaleAmpacity,
            stageCount: readout.stages.count,
            designCurrent: readout.designCurrent
        )
    }
}


// MARK: - Conductor cost ranking

struct ConductorCostRankingDiagram: View {
    let options: [ConductorCostOption]
    let recommendedID: String
    var includeEGC: Bool = false

    private var rows: [ConductorCostOption] {
        Array(options.prefix(8))
    }

    private var summary: String {
        guard let first = rows.first else { return "No compliant options." }
        var parts = ["Lowest first-cost \(first.typeString) at \(Format.dollars(first.firstCost))."]
        if includeEGC {
            parts.append("Ranking includes the recommended Table 250.122 EGC.")
        }
        return parts.joined(separator: " ")
    }

    var body: some View {
        DiagramCard(title: "First-cost ranking", accessibilitySummary: summary, exportName: "conductor-cost-rank") {
            Chart(rows, id: \.typeString) { option in
                BarMark(
                    x: .value("Cost", option.firstCost),
                    y: .value("Option", shortLabel(option))
                )
                .foregroundStyle(option.typeString == recommendedID ? Theme.good : Theme.chartPrimary.opacity(0.72))
                .annotation(position: .trailing, alignment: .leading, spacing: 4) {
                    Text(Format.dollars(option.firstCost))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                }
            }
            .chartXAxisLabel("Modeled first-cost ($)")
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .chartXAxis {
                AxisMarks(position: .bottom) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let dollars = value.as(Double.self) {
                            Text(Format.dollars(dollars))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: max(160, CGFloat(rows.count) * 28 + 40))
            .accessibilityHidden(true)

            if includeEGC {
                Text("Bars include one Table 250.122 EGC per run when Include recommended EGC is on. Planning allowance — not a bid.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func shortLabel(_ option: ConductorCostOption) -> String {
        let run = option.parallelRuns > 1 ? "\(option.parallelRuns)× " : ""
        var label = "\(run)\(option.label)"
        if option.includedEGC, let egc = option.egcLabel {
            label += " +E \(egc)"
        }
        return label
    }
}

// MARK: - Shared engineer XY plot (Swift Charts — Charty-class craft)

struct EngineerSeries: Identifiable {
    var id: String { name }
    var name: String
    var points: [PlotPoint]
    var color: Color
    var fills: Bool = false
}

struct EngineerMarker: Identifiable {
    var id: String { "\(label)-\(x)-\(y)" }
    var x: Double
    var y: Double
    var label: String
    var color: Color
}

struct EngineerGuide: Identifiable {
    enum Axis { case x, y }
    var id: String { "\(label)-\(value)-\(axis)" }
    var value: Double
    var label: String
    var axis: Axis
}

/// Multi-series XY plot with grid, units, markers, and τ-style guides —
/// detailed enough for lab notes, exportable via the parent `DiagramCard`.
struct EngineerLinePlot: View {
    var series: [EngineerSeries]
    var xLabel: String
    var yLabel: String
    var markers: [EngineerMarker] = []
    var xGuides: [EngineerGuide] = []
    var yGuides: [EngineerGuide] = []
    var logX: Bool = false
    var height: CGFloat = 200
    /// Catmull-Rom for smooth plant responses. Linear keeps relay and hysteresis corners square.
    var smooth: Bool = true

    @State private var magnification: CGFloat = 1
    @State private var pinchBase: CGFloat = 1
    /// Turns on one-finger pan only after a pinch ends, so the pinch gesture is not rebuilt mid-gesture.
    @State private var zoomed = false
    @State private var anchorX: CGFloat = 0.5
    @State private var anchorY: CGFloat = 0.5
    @State private var anchorXBase: CGFloat = 0.5
    @State private var anchorYBase: CGFloat = 0.5
    @State private var inspectX: Double?
    @Environment(\.plotSurfaceIsImmersive) private var immersive
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            scaledChart
            if let inspectCaption {
                Text(inspectCaption)
                    .font(Theme.TypeRole.hud)
                    .foregroundStyle(Theme.foreground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, minHeight: Theme.touchTarget, alignment: .leading)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityLabel(inspectCaption)
            }
            if magnification > 1.02 || immersive {
                HStack(spacing: 8) {
                    if magnification > 1.02 {
                        Button("Reset zoom", action: resetZoom)
                            .buttonStyle(.bordered)
                            .tint(Theme.accent)
                            .frame(minHeight: Theme.touchTarget)
                            .accessibilityLabel("Reset zoom")
                    }
                    if immersive {
                        Text("Drag to read a value. Pinch to zoom.")
                            .font(Theme.TypeRole.hud)
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(yLabel) versus \(xLabel). \(inspectCaption ?? "")")
        .simultaneousGesture(magnifyGesture)
    }

    @ViewBuilder
    private var scaledChart: some View {
        if logX {
            baseChart
                .chartXScale(domain: visibleX, type: .log)
                .chartYScale(domain: visibleY)
        } else {
            baseChart
                .chartXScale(domain: visibleX)
                .chartYScale(domain: visibleY)
        }
    }

    private var baseChart: some View {
        let interpolation: InterpolationMethod = smooth ? .catmullRom : .linear
        let oneFinger = immersive || zoomed
        return Chart {
            ForEach(series) { s in
                ForEach(Array(s.points.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value(xLabel, point.x),
                        y: .value(yLabel, point.y),
                        series: .value("Series", s.name)
                    )
                    .foregroundStyle(by: .value("Series", s.name))
                    .lineStyle(StrokeStyle(lineWidth: 2.25, lineJoin: .round))
                    .interpolationMethod(interpolation)

                    if s.fills {
                        AreaMark(
                            x: .value(xLabel, point.x),
                            y: .value(yLabel, point.y),
                            series: .value("Series", s.name)
                        )
                        .foregroundStyle(by: .value("Series", s.name))
                        .opacity(0.14)
                        .interpolationMethod(interpolation)
                    }
                }
            }
            ForEach(markers) { mark in
                PointMark(x: .value(xLabel, mark.x), y: .value(yLabel, mark.y))
                    .foregroundStyle(mark.color)
                    .symbolSize(72)
                    .annotation(position: .top, spacing: 4) {
                        Text(mark.label)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(mark.color)
                    }
            }
            ForEach(xGuides) { guide in
                RuleMark(x: .value(guide.label, guide.value))
                    .foregroundStyle(Theme.foreground.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text(guide.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.foreground)
                    }
            }
            ForEach(yGuides) { guide in
                RuleMark(y: .value(guide.label, guide.value))
                    .foregroundStyle(Theme.foreground.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text(guide.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.foreground)
                    }
            }
            if let inspectX {
                RuleMark(x: .value(xLabel, inspectX))
                    .foregroundStyle(Theme.foreground)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }
        }
        .chartForegroundStyleScale(
            domain: series.map(\.name),
            range: series.map(\.color)
        )
        .chartXAxis {
            AxisMarks(position: .bottom, values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Theme.chartGrid)
                AxisTick()
                AxisValueLabel(format: floatingFormat)
                    .font(.caption.monospacedDigit())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Theme.chartGrid)
                AxisTick()
                AxisValueLabel(format: floatingFormat)
                    .font(.caption.monospacedDigit())
            }
        }
        .chartXAxisLabel(xLabel, position: .bottom, alignment: .center)
        .chartYAxisLabel(yLabel, position: .leading, alignment: .center)
        .chartLegend(series.count > 1 ? .visible : .hidden)
        .chartOverlay { proxy in
            GeometryReader { geo in
                let frame = proxy.plotFrame.map { geo[$0] } ?? .zero
                if oneFinger {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(inspectDrag(proxy: proxy, frame: frame))
                        .simultaneousGesture(magnifyGesture)
                } else {
                    Color.clear
                        .contentShape(Rectangle())
                        .simultaneousGesture(magnifyGesture)
                }
            }
        }
        .frame(height: height)
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                magnification = min(12, max(1, pinchBase * value.magnification))
            }
            .onEnded { _ in
                pinchBase = magnification
                zoomed = magnification > 1.02
                if magnification < 1.02 { resetZoom() }
            }
    }

    private func inspectDrag(proxy: ChartProxy, frame: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard frame.contains(value.location) || zoomed else { return }
                if zoomed {
                    let dx = value.translation.width / max(frame.width, 1)
                    let dy = value.translation.height / max(frame.height, 1)
                    anchorX = min(1, max(0, anchorXBase - dx))
                    anchorY = min(1, max(0, anchorYBase + dy))
                    inspectX = nil
                } else if let x: Double = proxy.value(atX: value.location.x - frame.minX, as: Double.self) {
                    inspectX = x
                }
            }
            .onEnded { _ in
                anchorXBase = anchorX
                anchorYBase = anchorY
            }
    }

    private var visibleX: ClosedRange<Double> {
        let extent = xExtent
        return PlotScaleMath.window(
            min: extent.0,
            max: extent.1,
            anchor: anchorX,
            magnification: magnification,
            logarithmic: logX
        )
    }

    private var visibleY: ClosedRange<Double> {
        let extent = yExtent
        return PlotScaleMath.window(
            min: extent.0,
            max: extent.1,
            anchor: anchorY,
            magnification: magnification,
            logarithmic: false
        )
    }

    private var xExtent: (Double, Double) {
        extent(series.flatMap { $0.points.map(\.x) } + markers.map(\.x) + xGuides.map(\.value), logarithmic: logX)
    }

    private var yExtent: (Double, Double) {
        extent(series.flatMap { $0.points.map(\.y) } + markers.map(\.y) + yGuides.map(\.value), logarithmic: false)
    }

    private func extent(_ raw: [Double], logarithmic: Bool) -> (Double, Double) {
        var values = raw.filter(\.isFinite)
        if logarithmic { values = values.filter { $0 > 0 } }
        let lo = values.min() ?? (logarithmic ? 1 : 0)
        let hi = values.max() ?? (lo + 1)
        if hi <= lo { return logarithmic ? (max(lo, 1e-6), max(lo, 1e-6) * 10) : (lo, lo + 1) }
        if logarithmic {
            let loLog = log(lo)
            let hiLog = log(hi)
            let pad = max((hiLog - loLog) * 0.05, 0.02)
            return (exp(loLog - pad), exp(hiLog + pad))
        }
        let pad = (hi - lo) * 0.05
        return (lo - pad, hi + pad)
    }

    private var inspectCaption: String? {
        guard let inspectX else { return nil }
        var best: (name: String, x: Double, y: Double, distance: Double)?
        for item in series {
            for point in item.points where point.x.isFinite && point.y.isFinite {
                let distance = abs(point.x - inspectX)
                if best == nil || distance < best!.distance {
                    best = (item.name, point.x, point.y, distance)
                }
            }
        }
        guard let best else { return "\(xLabel) \(formatTick(inspectX))" }
        return "\(best.name): \(xLabel) \(formatTick(best.x)), \(yLabel) \(formatTick(best.y))"
    }

    private func formatTick(_ value: Double) -> String {
        value.formatted(floatingFormat)
    }

    private func resetZoom() {
        if reduceMotion {
            magnification = 1
            pinchBase = 1
            zoomed = false
            anchorX = 0.5
            anchorY = 0.5
            anchorXBase = 0.5
            anchorYBase = 0.5
            inspectX = nil
        } else {
            withAnimation(.snappy(duration: 0.2)) {
                magnification = 1
                pinchBase = 1
                zoomed = false
                anchorX = 0.5
                anchorY = 0.5
                anchorXBase = 0.5
                anchorYBase = 0.5
                inspectX = nil
            }
        }
    }

    private var floatingFormat: FloatingPointFormatStyle<Double> {
        .number.precision(.significantDigits(1...4))
    }
}

// MARK: - RC charge / discharge (LED·RC tool)

struct RCChargeDischargeChart: View {
    let tau: Double
    var finalValue: Double = 1

    private var charge: [PlotPoint] { PlotSampling.rcCharge(tau: tau, finalValue: finalValue) }
    private var discharge: [PlotPoint] { PlotSampling.rcDischarge(tau: tau, initialValue: finalValue) }

    private var summary: String {
        "RC charge and discharge over 5τ. τ = \(Format.time(tau)). At one τ the capacitor is ~63% charged or discharged."
    }

    var body: some View {
        DiagramCard(title: "Charge / discharge", accessibilitySummary: summary, exportName: "rc-charge-discharge") {
            EngineerLinePlot(
                series: [
                    EngineerSeries(name: "Charge", points: charge, color: Theme.chartPrimary, fills: true),
                    EngineerSeries(name: "Discharge", points: discharge, color: Theme.chartSecondary, fills: false),
                ],
                xLabel: "Time (s)",
                yLabel: "v / V",
                markers: [
                    EngineerMarker(
                        x: tau,
                        y: finalValue * (1 - exp(-1)),
                        label: "0.63 V",
                        color: Theme.energized
                    ),
                ],
                xGuides: [
                    EngineerGuide(value: tau, label: "τ", axis: .x),
                    EngineerGuide(value: 5 * tau, label: "5τ", axis: .x),
                ],
                height: 220
            )
        }
    }
}

// MARK: - Frequency / period sine wave

struct SineWaveChart: View {
    let frequency: Double
    var amplitude: Double = 1
    var cycles: Double = 2

    private var points: [PlotPoint] {
        PlotSampling.sineWave(frequencyHz: frequency, cycles: cycles, amplitude: amplitude)
    }

    private var summary: String {
        "\(Format.number(cycles, digits: 0))-cycle sine at \(Format.frequency(frequency)), amplitude \(Format.number(amplitude, digits: 2))."
    }

    var body: some View {
        DiagramCard(title: "Waveform", accessibilitySummary: summary, exportName: "sine-wave") {
            EngineerLinePlot(
                series: [EngineerSeries(name: "v(t)", points: points, color: Theme.chartPrimary, fills: false)],
                xLabel: "Time (s)",
                yLabel: "Amplitude (rel)",
                yGuides: [
                    EngineerGuide(value: 0, label: "0", axis: .y),
                ],
                height: 200
            )
        }
    }
}

// MARK: - Ohm's law load line

struct OhmsLawLoadLineChart: View {
    let voltage: Double
    let current: Double
    let resistance: Double

    private var points: [PlotPoint] { PlotSampling.ohmsLoadLine(voltage: voltage, current: current) }

    private var summary: String {
        "Load line through \(Format.volts(voltage)), \(Format.amps(current)). R = \(Format.number(resistance, digits: 3)) Ω."
    }

    var body: some View {
        DiagramCard(title: "V–I load line", accessibilitySummary: summary, exportName: "ohms-load-line") {
            EngineerLinePlot(
                series: [EngineerSeries(name: "Load line", points: points, color: Theme.chartPrimary, fills: true)],
                xLabel: "Voltage (V)",
                yLabel: "Current (A)",
                markers: [
                    EngineerMarker(x: voltage, y: current, label: "OP", color: Theme.energized),
                ],
                height: 200
            )
        }
    }
}

// MARK: - Series RLC impedance magnitude

struct ResonanceImpedanceChart: View {
    let resistance: Double
    let inductance: Double
    let capacitance: Double
    let resonantFrequency: Double
    var bandwidth: Double = .nan

    private var marker: ReactancePlotReadout.ResonanceMarker? {
        ReactancePlotReadout.resonanceMarker(
            resonantHertz: resonantFrequency,
            resistance: resistance,
            bandwidth: bandwidth
        )
    }

    private var points: [PlotPoint] {
        var fMin = max(resonantFrequency / 20, 1e-3)
        var fMax = max(resonantFrequency * 20, fMin * 10)
        if let low = marker?.lowHertz, low > 0, low < fMin {
            fMin = max(low / 1.5, 1e-3)
        }
        if let high = marker?.highHertz, high.isFinite, high > fMax {
            fMax = high * 1.25
        }
        guard fMax > fMin else { return [] }
        return PlotSampling.seriesImpedanceMagnitude(
            resistance: resistance,
            inductance: inductance,
            capacitance: capacitance,
            fMin: fMin,
            fMax: fMax
        )
    }

    private var summary: String {
        guard let marker else { return "Ideal lumped parts." }
        return ReactancePlotReadout.resonanceAnnouncement(marker)
    }

    var body: some View {
        let mark = marker
        return DiagramCard(title: "|Z| vs frequency", accessibilitySummary: summary, exportName: "rlc-impedance") {
            EngineerLinePlot(
                series: [EngineerSeries(name: "|Z|", points: points, color: Theme.chartPrimary, fills: true)],
                xLabel: "Frequency (Hz)",
                yLabel: "|Z| (Ω)",
                markers: impedanceMarkers(mark),
                xGuides: impedanceGuides(mark),
                logX: true,
                height: 220
            )
            Text("Ideal lumped parts.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
    }

    private func impedanceMarkers(_ mark: ReactancePlotReadout.ResonanceMarker?) -> [EngineerMarker] {
        guard let mark else { return [] }
        return [
            EngineerMarker(
                x: mark.resonantHertz,
                y: mark.impedanceOhms,
                label: "f0",
                color: Theme.energized
            ),
        ]
    }

    private func impedanceGuides(_ mark: ReactancePlotReadout.ResonanceMarker?) -> [EngineerGuide] {
        guard let mark else { return [] }
        var guides = [EngineerGuide(value: mark.resonantHertz, label: "f0", axis: .x)]
        if let low = mark.lowHertz {
            guides.append(EngineerGuide(value: low, label: "BW", axis: .x))
        }
        if let high = mark.highHertz {
            guides.append(EngineerGuide(value: high, label: "BW", axis: .x))
        }
        return guides
    }
}

// MARK: - Reactance X_L / X_C vs frequency

struct ReactanceSweepChart: View {
    let inductance: Double
    let capacitance: Double
    let frequency: Double

    private var marker: ReactancePlotReadout.SeriesMarker? {
        ReactancePlotReadout.seriesMarker(
            hertz: frequency,
            inductance: inductance,
            capacitance: capacitance
        )
    }

    private var curves: (xl: [PlotPoint], xc: [PlotPoint]) {
        let lo = max(frequency / 20, 0.1)
        let hi = max(frequency * 20, lo * 10)
        return PlotSampling.reactanceVsFrequency(
            inductance: inductance,
            capacitance: capacitance,
            fMin: lo,
            fMax: hi
        )
    }

    private var summary: String {
        guard let marker else { return "Ideal lumped parts." }
        return ReactancePlotReadout.seriesAnnouncement(marker)
    }

    private var title: String {
        switch (marker?.inductiveOhms != nil, marker?.capacitiveOhms != nil) {
        case (true, true): return "XL and XC vs f"
        case (true, false): return "XL vs f"
        case (false, true): return "XC vs f"
        default: return "Reactance vs f"
        }
    }

    var body: some View {
        let sampled = curves
        let mark = marker
        return DiagramCard(title: title, accessibilitySummary: summary, exportName: "reactance-sweep") {
            EngineerLinePlot(
                series: sweepSeries(sampled),
                xLabel: "Frequency (Hz)",
                yLabel: "Reactance (Ω)",
                markers: sweepMarkers(mark),
                xGuides: mark.map { [EngineerGuide(value: $0.hertz, label: "f", axis: .x)] } ?? [],
                logX: true,
                height: 220
            )
            Text("Ideal lumped parts.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
    }

    private func sweepSeries(_ sampled: (xl: [PlotPoint], xc: [PlotPoint])) -> [EngineerSeries] {
        var rows: [EngineerSeries] = []
        if sampled.xl.count >= 2 {
            rows.append(EngineerSeries(name: "XL", points: sampled.xl, color: Theme.chartPrimary, fills: false))
        }
        if sampled.xc.count >= 2 {
            rows.append(EngineerSeries(name: "XC", points: sampled.xc, color: Theme.chartSecondary, fills: false))
        }
        return rows
    }

    private func sweepMarkers(_ mark: ReactancePlotReadout.SeriesMarker?) -> [EngineerMarker] {
        guard let mark else { return [] }
        var rows: [EngineerMarker] = []
        if let xl = mark.inductiveOhms {
            rows.append(EngineerMarker(x: mark.hertz, y: xl, label: "XL", color: Theme.chartPrimary))
        }
        if let xc = mark.capacitiveOhms {
            rows.append(EngineerMarker(x: mark.hertz, y: xc, label: "XC", color: Theme.chartSecondary))
        }
        return rows
    }
}

// MARK: - 555 monostable capacitor charge

struct MonostableCapChargeChart: View {
    let pulseWidth: Double
    var vcc: Double = 5

    private var points: [PlotPoint] {
        PlotSampling.monostableCapVoltage(pulseWidth: pulseWidth, vcc: vcc)
    }

    private var summary: String {
        "Timing capacitor charges toward \(Format.volts(vcc)) and trips at ⅔ Vcc when t = \(Format.time(pulseWidth))."
    }

    var body: some View {
        DiagramCard(title: "Capacitor charge", accessibilitySummary: summary, exportName: "555-monostable") {
            EngineerLinePlot(
                series: [EngineerSeries(name: "Vc", points: points, color: Theme.chartPrimary, fills: true)],
                xLabel: "Time (s)",
                yLabel: "Vc (V)",
                markers: [
                    EngineerMarker(x: pulseWidth, y: vcc * 2 / 3, label: "⅔ Vcc", color: Theme.energized),
                ],
                xGuides: [EngineerGuide(value: pulseWidth, label: "t", axis: .x)],
                yGuides: [EngineerGuide(value: vcc * 2 / 3, label: "⅔", axis: .y)],
                height: 210
            )
        }
    }
}

// MARK: - Solenoid design visualizations

/// Every pixel value the coil cross-section needs, resolved once in `Double`
/// space and handed to the view layers as explicit `CGFloat`. Keeping the
/// unit-to-point math out of the view builders is what lets the Swift type
/// checker finish: mixing `Double` metres with `CGFloat` points inside a
/// `ZStack` made the whole body one unsolvable expression.
private struct SolenoidCrossSectionLayout {
    let centerX: CGFloat
    let centerY: CGFloat
    let halfLength: CGFloat
    let meanRadius: CGFloat
    let layerCount: Int
    let layerWidth: CGFloat
    let layerStep: CGFloat
    let canvasHeight: CGFloat

    init(size: CGSize, lengthM: Double, meanRadiusM: Double, outerRadiusM: Double, layers: Int) {
        let w: Double = Double(size.width)
        let h: Double = Double(size.height)
        let maxR: Double = max(outerRadiusM, meanRadiusM, 1e-6)
        let scaleY: Double = (h * 0.78) / max(lengthM, 1e-6)
        let scaleX: Double = (w * 0.28) / maxR
        let scale: Double = min(scaleX, scaleY)
        let count: Int = max(1, min(layers, 8))
        let bandWidth: Double = (outerRadiusM - meanRadiusM) * scale / Double(count)

        centerX = CGFloat(w * 0.5)
        centerY = CGFloat(h * 0.52)
        halfLength = CGFloat(lengthM * scale / 2)
        meanRadius = CGFloat(meanRadiusM * scale)
        layerCount = count
        layerWidth = CGFloat(max(5, bandWidth - 1))
        layerStep = CGFloat(bandWidth)
        canvasHeight = CGFloat(h)
    }

    var coilHeight: CGFloat { halfLength * 2 }
    var boreWidth: CGFloat { meanRadius * 2 }
    var glowEndRadius: CGFloat { max(meanRadius * 1.4, 20) }
    var axisTip: CGPoint { CGPoint(x: centerX, y: centerY - halfLength * 0.85) }
    var axisTail: CGPoint { CGPoint(x: centerX, y: centerY + halfLength * 0.85) }

    func windingInset(_ layer: Int) -> CGFloat { CGFloat(layer) * layerStep }
}

/// Soft field glow inside the bore.
private struct SolenoidBoreGlow: View {
    let layout: SolenoidCrossSectionLayout

    var body: some View {
        Capsule()
            .fill(glow)
            .frame(width: layout.meanRadius * 2.2, height: layout.halfLength * 2.1)
            .position(x: layout.centerX, y: layout.centerY)
    }

    private var glow: RadialGradient {
        RadialGradient(
            colors: [Theme.accent.opacity(0.28), Theme.accent.opacity(0.04), .clear],
            center: .center,
            startRadius: 2,
            endRadius: layout.glowEndRadius
        )
    }
}

/// One mirrored pair of winding bands, left and right of the bore.
private struct SolenoidWindingLayer: View {
    let layout: SolenoidCrossSectionLayout
    let layer: Int

    var body: some View {
        let inset: CGFloat = layout.windingInset(layer)
        let shade: Double = 0.55 - Double(layer) * 0.04
        Group {
            band(shade: shade)
                .position(x: layout.centerX - layout.meanRadius - inset - 4, y: layout.centerY)
            band(shade: shade)
                .position(x: layout.centerX + layout.meanRadius + inset + 4, y: layout.centerY)
        }
    }

    private func band(shade: Double) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Theme.energized.opacity(shade))
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Theme.energized.opacity(0.9), lineWidth: 1)
            )
            .frame(width: layout.layerWidth, height: layout.coilHeight)
    }
}

private struct SolenoidWindingStack: View {
    let layout: SolenoidCrossSectionLayout

    var body: some View {
        ForEach(0..<layout.layerCount, id: \.self) { layer in
            SolenoidWindingLayer(layout: layout, layer: layer)
        }
    }
}

private struct SolenoidBoreOutline: View {
    let layout: SolenoidCrossSectionLayout

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
            .frame(width: layout.boreWidth, height: layout.coilHeight)
            .position(x: layout.centerX, y: layout.centerY)
    }
}

/// Axis line, arrow head, and the `B` marker.
private struct SolenoidAxisArrow: View {
    let layout: SolenoidCrossSectionLayout

    var body: some View {
        let tip: CGPoint = layout.axisTip
        Group {
            Path { path in
                path.move(to: layout.axisTail)
                path.addLine(to: tip)
            }
            .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))

            Path { path in
                path.move(to: tip)
                path.addLine(to: CGPoint(x: tip.x - 6, y: tip.y + 10))
                path.move(to: tip)
                path.addLine(to: CGPoint(x: tip.x + 6, y: tip.y + 10))
            }
            .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            Text("B")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.accent)
                .position(x: layout.centerX + 14, y: layout.centerY - layout.halfLength * 0.7)
        }
    }
}

private struct SolenoidDimensionLabels: View {
    let layout: SolenoidCrossSectionLayout
    let lengthLabel: String
    let boreLabel: String

    var body: some View {
        Group {
            label(lengthLabel)
                .position(x: layout.centerX, y: 14)
            label(boreLabel)
                .position(x: layout.centerX, y: layout.canvasHeight - 12)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(Theme.muted)
    }
}

struct SolenoidCrossSectionDiagram: View {
    let lengthM: Double
    let meanRadiusM: Double
    let outerRadiusM: Double
    let layers: Int
    let bCenterTesla: Double

    private var summary: String {
        "Solenoid cross-section. Length \(Format.number(lengthM * 1000, digits: 0)) mm, mean radius \(Format.number(meanRadiusM * 1000, digits: 1)) mm, \(layers) layers. Center B \(Format.number(bCenterTesla * 1000, digits: 2)) mT."
    }

    private var lengthLabel: String {
        "ℓ \(Format.number(lengthM * 1000, digits: 0)) mm"
    }

    private var boreLabel: String {
        "Ø \(Format.number(meanRadiusM * 2000, digits: 1)) mm"
    }

    var body: some View {
        DiagramCard(title: "Coil cross-section", accessibilitySummary: summary) {
            EngineeringDiagramFrame(summary: summary) {
                GeometryReader { geo in
                    crossSection(crossSectionLayout(for: geo.size))
                }
                .frame(height: 200)
            }
        }
    }

    private func crossSectionLayout(for size: CGSize) -> SolenoidCrossSectionLayout {
        SolenoidCrossSectionLayout(
            size: size,
            lengthM: lengthM,
            meanRadiusM: meanRadiusM,
            outerRadiusM: outerRadiusM,
            layers: layers
        )
    }

    @ViewBuilder
    private func crossSection(_ layout: SolenoidCrossSectionLayout) -> some View {
        ZStack {
            SolenoidBoreGlow(layout: layout)
            SolenoidWindingStack(layout: layout)
            SolenoidBoreOutline(layout: layout)
            SolenoidAxisArrow(layout: layout)
            SolenoidDimensionLabels(layout: layout, lengthLabel: lengthLabel, boreLabel: boreLabel)
        }
    }
}

struct SolenoidBCurrentChart: View {
    let points: [SolenoidPlotPoint]
    let operatingCurrent: Double
    let operatingB: Double

    private var summary: String {
        "Center flux density versus current. Operating point \(Format.number(operatingCurrent, digits: 2)) A, \(Format.number(operatingB * 1000, digits: 2)) mT."
    }

    var body: some View {
        DiagramCard(title: "B vs. current", accessibilitySummary: summary) {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    LineMark(x: .value("I", point.x), y: .value("B", point.y * 1000))
                        .foregroundStyle(Theme.chartPrimary)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                }
                PointMark(x: .value("I", operatingCurrent), y: .value("B", operatingB * 1000))
                    .foregroundStyle(Theme.energized)
                    .symbolSize(72)
            }
            .chartXAxisLabel("Current (A)")
            .chartYAxisLabel("B (mT)")
            .frame(height: 170)
            .accessibilityHidden(true)
        }
    }
}

struct SolenoidForceGapChart: View {
    let points: [SolenoidPlotPoint]
    let operatingGapMm: Double?
    let operatingForce: Double?

    private var summary: String {
        if let g = operatingGapMm, let f = operatingForce {
            return "Plunger force versus air gap. At \(Format.number(g, digits: 2)) mm, force \(Format.number(f, digits: 3)) N."
        }
        return "Plunger force versus air gap estimate for the designed ampere-turns."
    }

    var body: some View {
        DiagramCard(title: "Force vs. air gap", accessibilitySummary: summary) {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    LineMark(x: .value("Gap", point.x), y: .value("Force", point.y))
                        .foregroundStyle(Theme.chartSecondary)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                }
                if let g = operatingGapMm, let f = operatingForce {
                    PointMark(x: .value("Gap", g), y: .value("Force", f))
                        .foregroundStyle(Theme.energized)
                        .symbolSize(72)
                }
            }
            .chartXAxisLabel("Air gap (mm)")
            .chartYAxisLabel("Force (N)")
            .frame(height: 170)
            .accessibilityHidden(true)
        }
    }
}

struct SolenoidAxialFieldChart: View {
    let points: [SolenoidPlotPoint]
    let lengthM: Double
    let bCenter: Double

    private var summary: String {
        "On-axis flux density along the coil. Center \(Format.number(bCenter * 1000, digits: 2)) mT over \(Format.number(lengthM * 1000, digits: 0)) mm length."
    }

    var body: some View {
        DiagramCard(title: "Axial B(z)", accessibilitySummary: summary) {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    AreaMark(x: .value("z", point.x), y: .value("B", point.y * 1000))
                        .foregroundStyle(Theme.chartFill)
                    LineMark(x: .value("z", point.x), y: .value("B", point.y * 1000))
                        .foregroundStyle(Theme.chartPrimary)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }
                RuleMark(x: .value("End−", -lengthM * 500))
                    .foregroundStyle(Theme.muted.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                RuleMark(x: .value("End+", lengthM * 500))
                    .foregroundStyle(Theme.muted.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            .chartXAxisLabel("z from center (mm)")
            .chartYAxisLabel("B (mT)")
            .frame(height: 180)
            .accessibilityHidden(true)
        }
    }
}
