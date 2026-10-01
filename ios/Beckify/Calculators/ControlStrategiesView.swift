import SwiftUI
import Charts
import BeckifyMath

/// Field comparison of control strategies. Sits next to the Control Systems lab.
/// The lab still owns PID, Bode, and lead. This screen does not retune a plant.
struct ControlStrategiesView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case matrix = "Matrix"
        case plots = "Plots"
        case map = "Map"
        case pick = "Pick"
        var id: String { rawValue }
    }

    @Environment(\.openRelatedTool) private var openRelated
    @StoredChoice(.controlStrategies, "section", default: Section.matrix) private var section
    @StoredChoice(.controlStrategies, "strategy", default: ControlStrategyID.pid) private var selected
    @StoredChoice(.controlStrategies, "linearity", default: ControlLinearityPick.any) private var linearity
    @StoredChoice(.controlStrategies, "channels", default: ControlChannelPick.any) private var channelFilter
    @StoredChoice(.controlStrategies, "loopFilter", default: ControlLoopPick.any) private var loopFilter
    @StoredChoice(.controlStrategies, "loop", default: ControlLoopPace.process) private var loop
    @StoredChoice(.controlStrategies, "channel", default: ControlChannelClass.siso) private var channels
    @StoredChoice(.controlStrategies, "plant", default: ControlPlantCharacter.linear) private var plant
    @StoredChoice(.controlStrategies, "model", default: ControlModelAvailability.rough) private var model
    @StoredChoice(.controlStrategies, "disturbanceKind", default: ControlDisturbanceDemand.mild) private var disturbanceKind
    @StoredChoice(.controlStrategies, "actuator", default: ControlActuatorKind.modulating) private var actuator
    @StoredChoice(.controlStrategies, "priority", default: ControlFieldPriority.maintain) private var priority

    @State private var loadStep = 0.25
    @State private var hysteresisBand = 0.12
    @State private var boundary = 0.02

    private var constraints: ControlStrategyConstraints {
        ControlStrategyConstraints(
            loop: loop,
            channels: channels,
            plant: plant,
            model: model,
            disturbance: disturbanceKind,
            actuator: actuator,
            priority: priority
        )
    }

    private var recommendation: ControlStrategyRecommendation {
        ControlStrategyGuide.recommend(constraints)
    }

    private var sketch: ControlStrategyStepSketch {
        ControlStrategyGuide.stepSketch(disturbance: loadStep)
    }

    private var sticky: String {
        recommendation.headline
    }

    var body: some View {
        ToolScaffold(
            toolID: .controlStrategies,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .designAidExtra("Teaching sketches for field techs — not a PE stamp and not a tuner. Nothing here guarantees stability on your hardware. DRL, PINN, and ML-MPC are when-to-use notes. This app does not train a policy.")
        ) {
            Picker("Section", selection: $section) {
                ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
            }
            .segmentedControlStyle()
            .accessibilityIdentifier("controlStrategies.section")

            switch section {
            case .matrix:
                matrix
            case .plots:
                plots
            case .map:
                map
            case .pick:
                pick
            }
        }
    }

    private var copyText: String {
        let pick = recommendation
        let lines = pick.reasons.joined(separator: " ")
        return "\(pick.headline). \(lines) Also: \(ControlStrategyGuide.profile(pick.alternate).title). \(pick.caution)"
    }

    // MARK: - Matrix

    private var matrix: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("Dimmed names are a poor fit for the filters. The table stays complete.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Linearity", selection: $linearity) {
                ForEach(ControlLinearityPick.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .segmentedControlStyle()
            .accessibilityLabel("Linear or nonlinear")

            Picker("Channels", selection: $channelFilter) {
                ForEach(ControlChannelPick.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .segmentedControlStyle()
            .accessibilityLabel("SISO or MIMO")

            Picker("Loop time", selection: $loopFilter) {
                ForEach(ControlLoopPick.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .segmentedControlStyle()
            .accessibilityLabel("Loop time")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ControlStrategyGuide.profiles) { profile in
                        Button {
                            selected = profile.id
                        } label: {
                            Text(profile.shortName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selected == profile.id ? Theme.accent : Theme.foreground)
                                .padding(.horizontal, 12)
                                .frame(minHeight: Theme.touchTarget)
                                .background(
                                    selected == profile.id ? Theme.accent.opacity(0.16) : Theme.surfaceRaised,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                        .opacity(matches(profile.id) ? 1 : 0.38)
                        .accessibilityLabel(columnLabel(profile))
                        .accessibilityAddTraits(selected == profile.id ? .isSelected : [])
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(ControlMatrixAxis.allCases) { axis in
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text(axis.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.muted)
                                .frame(width: 84, alignment: .leading)
                            ForEach(ControlStrategyGuide.profiles) { profile in
                                Text(axis.cell(profile))
                                    .font(.caption2)
                                    .foregroundStyle(selected == profile.id ? Theme.foreground : Theme.muted)
                                    .frame(width: 108, alignment: .leading)
                                    .opacity(matches(profile.id) ? 1 : 0.38)
                            }
                        }
                        .padding(.vertical, 6)
                        Divider().overlay(Theme.hairline)
                    }
                }
                .padding(Theme.Space.sm)
            }
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))

            strategyDetail(ControlStrategyGuide.profile(selected))
        }
    }

    private func matches(_ id: ControlStrategyID) -> Bool {
        ControlStrategyGuide.matches(id, linearity: linearity, channels: channelFilter, loop: loopFilter)
    }

    private func columnLabel(_ profile: ControlStrategyProfile) -> String {
        var parts = [profile.title]
        for axis in ControlMatrixAxis.allCases {
            parts.append("\(axis.title) \(axis.cell(profile))")
        }
        if !matches(profile.id) {
            parts.append("Poor fit for the current filters")
        }
        return parts.joined(separator: ", ")
    }

    private func strategyDetail(_ profile: ControlStrategyProfile) -> some View {
        ResultCard(title: profile.shortName, copyText: "\(profile.title). \(profile.summary) \(profile.limit)") {
            Text(profile.title)
                .font(.headline)
                .foregroundStyle(Theme.foreground)
            if profile.explanatoryOnly {
                Text("When-to-use only — no trained policy on this device.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.warn)
            }
            Text(profile.summary)
                .font(.subheadline)
                .foregroundStyle(Theme.foreground)
                .fixedSize(horizontal: false, vertical: true)
            Text(profile.limit)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            regimeLine(profile)
        }
    }

    private func regimeLine(_ profile: ControlStrategyProfile) -> some View {
        Text(regimeSentence(profile))
            .font(.caption.monospacedDigit())
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func regimeSentence(_ profile: ControlStrategyProfile) -> String {
        "Linear \(word(profile.linear)) · Nonlinear \(word(profile.nonlinear)) · SISO \(word(profile.siso)) · MIMO \(word(profile.mimo)) · <1 ms \(word(profile.fastLoop)) · >1 s \(word(profile.processLoop))"
    }

    private func word(_ fit: ControlFit) -> String {
        switch fit {
        case .typical: return "typical"
        case .possible: return "possible"
        case .poor: return "poor"
        }
    }

    // MARK: - Plots

    private var plots: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text(sketch.note)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            sliderRow(
                title: "Load step",
                value: loadStepText,
                range: 0...0.45,
                binding: $loadStep
            )

            DiagramCard(
                title: "Step response",
                accessibilitySummary: stepSummary,
                exportName: "control-strategy-step"
            ) {
                EngineerLinePlot(
                    series: [
                        EngineerSeries(name: "Bang-bang", points: sketch.bangBang.output, color: Theme.chartSecondary, fills: false),
                        EngineerSeries(name: "PID", points: sketch.pid.output, color: Theme.chartPrimary, fills: true),
                        EngineerSeries(name: "ADRC", points: sketch.adrc.output, color: Theme.chartTertiary, fills: false),
                    ],
                    xLabel: "Time (s)",
                    yLabel: "Process variable",
                    xGuides: [EngineerGuide(value: sketch.disturbanceTime, label: "Load", axis: .x)],
                    yGuides: [EngineerGuide(value: sketch.reference, label: "SP", axis: .y)],
                    height: 230
                )
            }
            Text(stepSummary)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            DiagramCard(
                title: "Actuator",
                accessibilitySummary: "Actuator command. Bang-bang is a square wave. PID and ADRC stay between 0 and 1.",
                exportName: "control-strategy-actuator"
            ) {
                EngineerLinePlot(
                    series: [
                        EngineerSeries(name: "Bang-bang", points: sketch.bangBang.actuator, color: Theme.chartSecondary),
                        EngineerSeries(name: "PID", points: sketch.pid.actuator, color: Theme.chartPrimary),
                        EngineerSeries(name: "ADRC", points: sketch.adrc.actuator, color: Theme.chartTertiary),
                    ],
                    xLabel: "Time (s)",
                    yLabel: "Command (0–1)",
                    height: 200,
                    smooth: false
                )
            }

            sliderRow(
                title: "Hysteresis band",
                value: bandText,
                range: 0.02...0.35,
                binding: $hysteresisBand
            )
            hysteresisChart

            sliderRow(
                title: "SMC boundary φ",
                value: boundaryText,
                range: 0.015...0.55,
                binding: $boundary
            )
            slidingCharts

            computeChart
        }
    }

    private var stepSummary: String {
        "Bang-bang switches \(sketch.bangBang.switchCount) times on this lag. PID switches \(sketch.pid.switchCount). ADRC switches \(sketch.adrc.switchCount). Same setpoint, load step at \(Int(sketch.disturbanceTime)) s. Teaching sketch — not your scan."
    }

    private var hysteresisChart: some View {
        let loop = ControlStrategyGuide.hysteresisLoop(band: hysteresisBand)
        return DiagramCard(
            title: "Hysteresis",
            accessibilitySummary: "Relay with memory. Output trips to +1 above \(loop.risingTrip) and back to −1 below \(loop.fallingTrip).",
            exportName: "control-strategy-hysteresis"
        ) {
            EngineerLinePlot(
                series: [
                    EngineerSeries(name: "Relay", points: loop.samples, color: Theme.chartSecondary),
                ],
                xLabel: "Input",
                yLabel: "Command (0–1)",
                xGuides: [
                    EngineerGuide(value: loop.risingTrip, label: "+\(bandText)", axis: .x),
                    EngineerGuide(value: loop.fallingTrip, label: "−\(bandText)", axis: .x),
                ],
                height: 200,
                smooth: false
            )
        }
    }

    private var slidingCharts: some View {
        let slide = ControlStrategyGuide.slidingSketch(boundary: boundary)
        return VStack(alignment: .leading, spacing: Theme.Space.sm) {
            DiagramCard(
                title: "Sliding surface",
                accessibilitySummary: "Phase plane. The line is s = 0. The dashed band is the boundary layer. Chatter index \(slide.chatterIndex).",
                exportName: "control-strategy-sliding"
            ) {
                EngineerLinePlot(
                    series: [
                        EngineerSeries(name: "Path", points: slide.phase, color: Theme.chartPrimary),
                        EngineerSeries(name: "s = 0", points: slide.surface, color: Theme.chartSecondary),
                        EngineerSeries(name: "+φ", points: slide.upperBand, color: Theme.muted),
                        EngineerSeries(name: "−φ", points: slide.lowerBand, color: Theme.muted),
                    ],
                    xLabel: "Error",
                    yLabel: "Error rate (1/s)",
                    height: 230,
                    smooth: false
                )
            }
            DiagramCard(
                title: "SMC command",
                accessibilitySummary: "Sliding-mode command. A thin boundary chatters between the rails. A wide boundary stays smooth.",
                exportName: "control-strategy-smc-command"
            ) {
                EngineerLinePlot(
                    series: [
                        EngineerSeries(name: "u", points: slide.actuator, color: Theme.warn),
                    ],
                    xLabel: "Time (s)",
                    yLabel: "Command (0–1)",
                    height: 180,
                    smooth: false
                )
            }
            Text("Chatter index \(slide.chatterIndex, format: .number.precision(.fractionLength(3))). Thin φ switches hard after the error reaches the line. A wider layer spends the effort inside the band. Sampled planning sketch — not a drive tune.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var computeChart: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
        DiagramCard(
            title: "Cost vs tracking",
            accessibilitySummary: computeSummary,
            exportName: "control-strategy-compute"
        ) {
            Chart(ControlStrategyGuide.computeSketch) { point in
                PointMark(
                    x: .value("On-device cost", point.compute),
                    y: .value("Tracking sketch", point.tracking)
                )
                .foregroundStyle(color(for: point.id))
                .symbolSize(CGFloat(selected == point.id ? 140 : 80))
                .annotation(position: .top, spacing: 4) {
                    Text(ControlStrategyGuide.profile(point.id).shortName)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(color(for: point.id))
                }
            }
            .chartXScale(domain: 0...1)
            .chartYScale(domain: 0.2...1)
            .chartXAxisLabel("On-device cost →")
            .chartYAxisLabel("Cleaner tracking →")
            .chartXAxis {
                AxisMarks(values: [0, 0.5, 1]) { value in
                    AxisGridLine().foregroundStyle(Theme.chartGrid)
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text(number, format: .number.precision(.fractionLength(1)))
                                .font(.caption2.monospacedDigit())
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: [0.4, 0.6, 0.8]) { value in
                    AxisGridLine().foregroundStyle(Theme.chartGrid)
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text(number, format: .number.precision(.fractionLength(1)))
                                .font(.caption2.monospacedDigit())
                        }
                    }
                }
            }
            .frame(height: 240)
            .accessibilityHidden(true)
        }
        Text(ControlStrategyGuide.computeSketchNote)
            .font(.caption)
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var computeSummary: String {
        let bits = ControlStrategyGuide.computeSketch.map { point in
            let name = ControlStrategyGuide.profile(point.id).shortName
            return "\(name) cost \(point.compute) tracking \(point.tracking)"
        }
        return "Relative sketch, not a benchmark. " + bits.joined(separator: ", ") + ". " + ControlStrategyGuide.computeSketchNote
    }

    // MARK: - Map

    private var map: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text("Concrete jobs, not a catalog of every plant. The strategy is the usual field pick, with the limit in the sentence.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(ControlStrategyGuide.industryOrder, id: \.self) { industry in
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(industry.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.muted)
                    ForEach(ControlStrategyGuide.applications.filter { $0.industry == industry }) { note in
                        applicationCard(note)
                    }
                }
            }
        }
    }

    private func applicationCard(_ note: ControlApplicationNote) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(note.example)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(ControlStrategyGuide.profile(note.strategy).shortName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color(for: note.strategy))
            }
            Text("\(note.loop) · \(note.channels)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.accent)
            Text(note.why)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Pick

    private var pick: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("Constraints in, one suggestion out. It does not write gains.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            MenuField(title: "Loop", selection: $loop, options: ControlLoopPace.allCases) { $0.displayName }
            MenuField(title: "Channels", selection: $channels, options: ControlChannelClass.allCases) { $0.displayName }
            MenuField(title: "Plant", selection: $plant, options: ControlPlantCharacter.allCases) { $0.displayName }
            MenuField(title: "Model", selection: $model, options: ControlModelAvailability.allCases) { $0.displayName }
            MenuField(title: "Disturbance", selection: $disturbanceKind, options: ControlDisturbanceDemand.allCases) { $0.displayName }
            MenuField(title: "Actuator", selection: $actuator, options: ControlActuatorKind.allCases) { $0.displayName }
            MenuField(title: "What matters", selection: $priority, options: ControlFieldPriority.allCases) { $0.displayName }

            recommendationCard
        }
    }

    private var recommendationCard: some View {
        let pick = recommendation
        let primary = ControlStrategyGuide.profile(pick.primary)
        let alternate = ControlStrategyGuide.profile(pick.alternate)
        return ResultCard(title: "Suggested", copyText: copyText) {
            Text(pick.headline)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .accessibilityIdentifier("controlStrategies.recommendation")
            if pick.variant != nil {
                Text(primary.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            if primary.explanatoryOnly {
                Text("Explanatory. No weights, no training, no download.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.warn)
            }
            ForEach(pick.reasons, id: \.self) { reason in
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Also \(alternate.title). \(pick.alternateReason)")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text(pick.caution)
                .font(.caption)
                .foregroundStyle(Theme.warn)
                .fixedSize(horizontal: false, vertical: true)
            if pick.opensControlSystemsLab {
                Button {
                    openRelated(.controlSystems)
                } label: {
                    Label("Open Control Systems lab", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .accessibilityIdentifier("controlStrategies.openLab")
            }
        }
    }

    // MARK: - Bits

    private func sliderRow(title: String, value: String, range: ClosedRange<Double>, binding: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text(value)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.foreground)
            }
            Slider(value: binding, in: range)
                .tint(Theme.accent)
                .accessibilityLabel(title)
                .accessibilityValue(value)
        }
    }

    private var loadStepText: String {
        loadStep.formatted(.number.precision(.fractionLength(2)))
    }

    private var bandText: String {
        hysteresisBand.formatted(.number.precision(.fractionLength(2)))
    }

    private var boundaryText: String {
        boundary.formatted(.number.precision(.fractionLength(2)))
    }

    private func color(for id: ControlStrategyID) -> Color {
        switch id {
        case .bangBang: return Theme.energized
        case .pid: return Theme.accent
        case .mpc: return Theme.accent2
        case .fuzzy: return Theme.good
        case .slidingMode: return Theme.warn
        case .drl: return Theme.bad
        case .adrc: return Theme.chartTertiary
        case .nnAdaptive: return Theme.muted
        }
    }
}
