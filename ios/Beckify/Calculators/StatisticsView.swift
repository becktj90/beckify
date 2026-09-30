import SwiftUI
import BeckifyMath

enum StatisticsPage: String, CaseIterable, Identifiable {
    case hub
    case distributions
    case rescale
    case paired
    case spread
    case dice

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hub: return "Statistics"
        case .distributions: return "Distributions"
        case .rescale: return "Rescale"
        case .paired: return "Paired normal"
        case .spread: return "Spread"
        case .dice: return "Two dice"
        }
    }

    var blurb: String {
        switch self {
        case .hub: return ""
        case .distributions: return "Pick a distribution, draw samples, and set them next to the formula."
        case .rescale: return "See how Y = aX + b moves the center, the width, and the shape."
        case .paired: return "Scatter a normal pair, then condition on a range of X."
        case .spread: return "Covariance, correlation, and the spread of aX + bY."
        case .dice: return "Condition two dice and read the exact chance."
        }
    }
}

private enum PairWindowKind: String, CaseIterable, Identifiable {
    case above
    case between

    var id: String { rawValue }

    var title: String {
        switch self {
        case .above: return "X above"
        case .between: return "X between"
        }
    }
}

extension StatFamily {
    var title: String {
        switch self {
        case .normal: return "Normal"
        case .uniform: return "Uniform"
        case .exponential: return "Exponential"
        case .binomial: return "Binomial"
        case .poisson: return "Poisson"
        }
    }
}

extension DiceCondition {
    var title: String {
        switch self {
        case .any: return "All faces"
        case .firstAtLeastFour: return "First die is 4–6"
        case .facesMatch: return "Faces match"
        case .sumIsSeven: return "Sum is 7"
        }
    }
}

struct StatisticsView: View {
    @StoredChoice(.statistics, "page", default: StatisticsPage.hub) private var page
    @StoredChoice(.statistics, "family", default: StatFamily.normal) private var family
    @StoredInput(.statistics, "distMean", default: "0") private var distMean
    @StoredInput(.statistics, "distSD", default: "1") private var distSD
    @StoredInput(.statistics, "distLow", default: "0") private var distHighLow
    @StoredInput(.statistics, "distHigh", default: "1") private var distHigh
    @StoredInput(.statistics, "distRate", default: "1") private var distRate
    @StoredInput(.statistics, "distTrials", default: "10") private var distTrials
    @StoredInput(.statistics, "distP", default: "0.5") private var distP
    @StoredInput(.statistics, "distLambda", default: "4") private var distLambda
    @StoredInput(.statistics, "draws", default: "4000") private var draws
    @StoredInput(.statistics, "factor", default: "2") private var factor
    @StoredInput(.statistics, "offset", default: "1") private var offset
    @StoredInput(.statistics, "mux", default: "500") private var mux
    @StoredInput(.statistics, "muy", default: "500") private var muy
    @StoredInput(.statistics, "sx", default: "100") private var sx
    @StoredInput(.statistics, "sy", default: "100") private var sy
    @StoredInput(.statistics, "rho", default: "0.6") private var rho
    @StoredChoice(.statistics, "window", default: PairWindowKind.above) private var windowKind
    @StoredInput(.statistics, "xCut", default: "600") private var xCut
    @StoredInput(.statistics, "xLow", default: "400") private var xLow
    @StoredInput(.statistics, "xHigh", default: "600") private var xHigh
    @StoredInput(.statistics, "yCut", default: "550") private var yCut
    @StoredInput(.statistics, "weightX", default: "1") private var weightX
    @StoredInput(.statistics, "weightY", default: "1") private var weightY
    @StoredChoice(.statistics, "dice", default: DiceCondition.firstAtLeastFour) private var dice
    @StoredInput(.statistics, "diceCut", default: "8") private var diceCut

    var body: some View {
        ToolScaffold(
            toolID: .statistics,
            stickyAnswer: stickyAnswer,
            copyText: copyText
        ) {
            switch page {
            case .hub:
                hub
            case .distributions:
                distributions
            case .rescale:
                rescale
            case .paired:
                paired
            case .spread:
                spread
            case .dice:
                diceScreen
            }
        }
    }

    private var hub: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text("One set of pictures for a single distribution, a rescale, a normal pair, and two dice.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(StatisticsPage.allCases.filter { $0 != .hub }) { item in
                Button {
                    page = item
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.foreground)
                        Text(item.blurb)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Space.sm)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                            .stroke(Theme.border, lineWidth: Theme.Stroke.hairline)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("statistics.page.\(item.rawValue)")
            }
        }
        .accessibilityIdentifier("statistics.hub")
    }

    private var distributions: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            backButton
            screenTitle(.distributions)
            familyPicker
            familyFields
            drawsField
            switch distributionResult {
            case .failure(let error):
                ErrorText(message: error.message)
            case .success(let draw):
                DensityChart(
                    draw: draw,
                    xTitle: "Value",
                    fullscreenTitle: "Distribution"
                )
                PlotLegend(items: [
                    (Theme.chartPrimary, "Draw"),
                    (Theme.chartSecondary, "Formula"),
                ])
                ResultCard(title: "Mean and spread", copyText: distributionCopy(draw)) {
                    ResultRow(label: "Formula mean", value: statText(draw.theory.mean))
                    ResultRow(label: "Formula SD", value: statText(draw.theory.standardDeviation))
                    ResultRow(label: "Draw mean", value: statText(draw.sample.mean), emphasis: true)
                    ResultRow(label: "Draw SD (n−1)", value: statText(draw.sample.standardDeviation), emphasis: true)
                    ResultRow(label: "Draws", value: "\(draw.sample.count)")
                }
                Text("Bars are the draw. Marks are the formula. The draw SD divides by n−1.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var rescale: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            backButton
            screenTitle(.rescale)
            Text("Uses the distribution on the Distributions screen.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
            familyPicker
            NumberField(title: "a", unit: "×", text: $factor, helpText: "Width and flip.", fieldID: "factor")
            NumberField(title: "b", unit: "+", text: $offset, helpText: "Shift.", fieldID: "offset")
            drawsField
            switch rescaleResult {
            case .failure(let error):
                ErrorText(message: error.message)
            case .success(let picture):
                Text(shapeSentence(picture))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                DensityChart(draw: picture.source, xTitle: "X", fullscreenTitle: "X")
                DensityChart(draw: picture.scaled, xTitle: "Y = aX + b", fullscreenTitle: "Rescaled Y")
                PlotLegend(items: [
                    (Theme.chartPrimary, "Draw"),
                    (Theme.chartSecondary, "Formula"),
                ])
                ResultCard(title: "Y against X", copyText: rescaleCopy(picture)) {
                    ResultRow(label: "X formula mean", value: statText(picture.source.theory.mean))
                    ResultRow(label: "X formula SD", value: statText(picture.source.theory.standardDeviation))
                    ResultRow(label: "Y formula mean", value: statText(picture.scaled.theory.mean), emphasis: true)
                    ResultRow(label: "Y formula SD", value: statText(picture.scaled.theory.standardDeviation), emphasis: true)
                    ResultRow(label: "Y draw mean", value: statText(picture.scaled.sample.mean))
                    ResultRow(label: "Y draw SD", value: statText(picture.scaled.sample.standardDeviation))
                }
            }
        }
    }

    private var paired: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            backButton
            screenTitle(.paired)
            exampleScoreNote
            pairFields
            windowFields
            NumberField(title: "Y at most", unit: "", text: $yCut, helpText: "Chance that Y is at or below this cut, inside the X range.", fieldID: "yCut")
            drawsField
            switch pairedResult {
            case .failure(let error):
                ErrorText(message: error.message)
            case .success(let picture):
                ScatterChart(picture: picture)
                PlotLegend(items: [
                    (Theme.accent, "In the X range"),
                    (Theme.muted, "Outside"),
                    (Theme.chartSecondary, "1 SD ellipse"),
                ])
                ResultCard(title: "Y inside the X range", copyText: pairedCopy(picture)) {
                    ResultRow(label: "Formula mean", value: statText(picture.conditional.mean), emphasis: true)
                    ResultRow(label: "Formula SD", value: statText(picture.conditional.standardDeviation), emphasis: true)
                    ResultRow(label: "Draw mean", value: statText(picture.sample.mean))
                    ResultRow(label: "Draw SD (n−1)", value: picture.sample.count > 1 ? statText(picture.sample.standardDeviation) : "—")
                    ResultRow(label: "P(event)", value: statPercent(picture.conditional.eventProbability))
                    ResultRow(label: "Formula P(Y at most cut)", value: statPercent(picture.conditional.probabilityAtMost), emphasis: true)
                    ResultRow(label: "Draw P(Y at most cut)", value: picture.sampleChance.map(statPercent) ?? "—")
                    ResultRow(label: "Draws in range", value: "\(picture.insideCount) / \(picture.totalCount)")
                }
                Text("Conditional mean and spread are exact for this normal pair. The formula chance is a numerical integral. The draw rows are Monte Carlo.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if picture.insideCount < 30 {
                    Text("Few draws landed in the X range, so the draw rows are noisy.")
                        .font(.footnote)
                        .foregroundStyle(Theme.warn)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var spread: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            backButton
            screenTitle(.spread)
            exampleScoreNote
            pairFields
            NumberField(title: "Weight on X", unit: "a", text: $weightX, fieldID: "weightX")
            NumberField(title: "Weight on Y", unit: "b", text: $weightY, fieldID: "weightY")
            drawsField
            switch spreadResult {
            case .failure(let error):
                ErrorText(message: error.message)
            case .success(let picture):
                Text("Same-sign corners raise covariance. Opposite corners lower it.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                SignGrid(balance: picture.balance)
                SpreadBars(parts: picture.parts)
                DensityChart(draw: picture.combination, xTitle: "aX + bY", fullscreenTitle: "Linear combination")
                ResultCard(title: "aX + bY", copyText: spreadCopy(picture)) {
                    ResultRow(label: "Covariance", value: statText(picture.parts.covariance), emphasis: true)
                    ResultRow(label: "Correlation", value: statText(picture.parts.correlation), emphasis: true)
                    ResultRow(label: "Draw covariance", value: statText(picture.balance.sampleCovariance))
                    ResultRow(label: "Formula mean", value: statText(picture.parts.mean))
                    ResultRow(label: "Formula SD", value: statText(picture.parts.standardDeviation))
                    ResultRow(label: "Draw mean", value: statText(picture.combination.sample.mean))
                    ResultRow(label: "Draw SD", value: statText(picture.combination.sample.standardDeviation))
                }
            }
        }
    }

    private var diceScreen: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            backButton
            screenTitle(.dice)
            Picker("Condition", selection: $dice) {
                ForEach(DiceCondition.allCases, id: \.self) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("statistics.dice")
            NumberField(title: "Sum at most", unit: "", text: $diceCut, helpText: "Whole number from 2 to 12.", fieldID: "diceCut")
            let picture = StatisticsMath.dice(condition: dice, sumAtMost: Int(diceCut) ?? 8)
            DiceChart(picture: picture)
            PlotLegend(items: [
                (Theme.chartPrimary, "In the condition"),
                (Theme.muted, "All faces"),
            ])
            ResultCard(title: "Conditional sum", copyText: diceCopy(picture)) {
                ResultRow(label: "Faces kept", value: "\(picture.kept) / \(picture.total)", emphasis: true)
                ResultRow(label: "Exact mean", value: statText(picture.mean))
                ResultRow(label: "Exact SD", value: statText(picture.standardDeviation))
                ResultRow(label: "Exact P(sum at most cut)", value: statPercent(picture.probabilityAtMost), emphasis: true)
            }
            Text("Both dice are fair. Every face is counted, so this screen is exact.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var familyPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DISTRIBUTION")
                .font(Theme.TypeRole.fieldLabel)
                .tracking(0.6)
                .foregroundStyle(Theme.muted)
            Picker("Distribution", selection: $family) {
                ForEach(StatFamily.allCases, id: \.self) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("statistics.family")
        }
    }

    @ViewBuilder
    private var familyFields: some View {
        switch family {
        case .normal:
            NumberField(title: "Mean", unit: "", text: $distMean, fieldID: "distMean")
            NumberField(title: "SD", unit: "", text: $distSD, helpText: "Must be greater than zero.", fieldID: "distSD")
        case .uniform:
            NumberField(title: "Low", unit: "", text: $distHighLow, fieldID: "distLow")
            NumberField(title: "High", unit: "", text: $distHigh, fieldID: "distHigh")
        case .exponential:
            NumberField(title: "Rate", unit: "1/mean", text: $distRate, helpText: "Mean and SD are both 1 / rate.", fieldID: "distRate")
        case .binomial:
            NumberField(title: "Tries", unit: "", text: $distTrials, helpText: "Whole number from 1 to 60.", fieldID: "distTrials")
            NumberField(title: "Success chance", unit: "", text: $distP, helpText: "From 0 to 1.", fieldID: "distP")
        case .poisson:
            NumberField(title: "Rate", unit: "mean", text: $distLambda, helpText: "Mean and variance match this rate. At most 40.", fieldID: "distLambda")
        }
    }

    private var drawsField: some View {
        NumberField(
            title: "Draws",
            unit: "",
            text: $draws,
            helpText: "Seeded Monte Carlo, from \(StatisticsMath.minimumDraws) to \(StatisticsMath.maximumDraws).",
            fieldID: "draws"
        )
    }

    private var pairFields: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            NumberField(title: "Mean X", unit: "", text: $mux, fieldID: "mux")
            NumberField(title: "Mean Y", unit: "", text: $muy, fieldID: "muy")
            NumberField(title: "SD X", unit: "", text: $sx, fieldID: "sx")
            NumberField(title: "SD Y", unit: "", text: $sy, fieldID: "sy")
            VStack(alignment: .leading, spacing: 6) {
                Text("CORRELATION")
                    .font(Theme.TypeRole.fieldLabel)
                    .tracking(0.6)
                    .foregroundStyle(Theme.muted)
                HStack {
                    Text("−1")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                    Slider(value: correlationBinding, in: -1...1, step: 0.01)
                        .tint(Theme.accent)
                        .accessibilityIdentifier("statistics.correlation")
                    Text("1")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                }
                Text(statText(Double(rho) ?? 0))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.foreground)
            }
        }
    }

    private var windowFields: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Picker("X range", selection: $windowKind) {
                ForEach(PairWindowKind.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("statistics.window")
            switch windowKind {
            case .above:
                NumberField(title: "X above", unit: "", text: $xCut, fieldID: "xCut")
            case .between:
                NumberField(title: "X low", unit: "", text: $xLow, fieldID: "xLow")
                NumberField(title: "X high", unit: "", text: $xHigh, fieldID: "xHigh")
            }
        }
    }

    private var exampleScoreNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Defaults are example scores on a 500 and 100 scale. Not an official College Board tool.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button("Load example scores") {
                loadExampleScores()
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent2)
            .frame(minHeight: Theme.touchTarget)
            .accessibilityIdentifier("statistics.exampleScores")
        }
    }

    private var backButton: some View {
        Button {
            page = .hub
        } label: {
            Label("All statistics", systemImage: "chevron.left")
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: Theme.touchTarget)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accent)
        .accessibilityIdentifier("statistics.back")
    }

    private func screenTitle(_ item: StatisticsPage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.foreground)
            Text(item.blurb)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var correlationBinding: Binding<Double> {
        Binding(
            get: { min(1, max(-1, Double(rho) ?? 0)) },
            set: { rho = String(format: "%.2f", $0) }
        )
    }

    private func loadExampleScores() {
        mux = "500"
        muy = "500"
        sx = "100"
        sy = "100"
        rho = "0.60"
        windowKind = .above
        xCut = "600"
        yCut = "550"
        weightX = "1"
        weightY = "1"
    }

    private func shapeSentence(_ picture: RescalePicture) -> String {
        if abs(picture.factor) < 1e-9 {
            return "a is 0, so Y sits at b."
        }
        var bits: [String] = []
        if picture.flipped {
            bits.append("negative a flips the shape")
        }
        let width = abs(picture.factor)
        if abs(width - 1) >= 1e-9 {
            bits.append(width > 1 ? "the width stretches by \(statText(width))" : "the width squeezes to \(statText(width))×")
        } else if !picture.flipped {
            bits.append("the width stays the same")
        }
        if abs(picture.offset) > 1e-9 {
            bits.append("b shifts the center by \(statText(picture.offset))")
        }
        guard let first = bits.first else {
            return "Y matches X. Spread scales with |a|."
        }
        let head = first.prefix(1).uppercased() + first.dropFirst()
        let rest = bits.dropFirst().joined(separator: ", ")
        let body = rest.isEmpty ? head : head + ", " + rest
        return body + ". Spread scales with |a|."
    }
}

// MARK: - Solved pictures

private extension StatisticsView {
    var distributionResult: Result<DistributionDraw, CalcError> {
        CalcCatch.run {
            try StatisticsMath.draw(spec: try makeSpec(), count: try makeCount())
        }
    }

    var rescaleResult: Result<RescalePicture, CalcError> {
        CalcCatch.run {
            try StatisticsMath.rescale(
                spec: try makeSpec(),
                factor: try Self.finite(factor, name: "a"),
                offset: try Self.finite(offset, name: "b"),
                count: try makeCount()
            )
        }
    }

    var pairedResult: Result<PairedPicture, CalcError> {
        CalcCatch.run {
            let model = try makeModel()
            let window = try makeWindow()
            let cut = try Self.finite(yCut, name: "the Y cut")
            let conditional = try StatisticsMath.conditionalY(model: model, window: window, yAtMost: cut)
            let pairs = try StatisticsMath.simulatePairs(model: model, count: try makeCount())
            let inside = pairs.filter { StatisticsMath.contains($0.x, window: window) }
            let hits = inside.filter { $0.y <= cut }.count
            return PairedPicture(
                model: model,
                window: window,
                pairs: pairs,
                conditional: conditional,
                sample: StatisticsMath.summarize(inside.map(\.y)),
                sampleChance: inside.isEmpty ? nil : Double(hits) / Double(inside.count),
                insideCount: inside.count,
                totalCount: pairs.count,
                yCut: cut
            )
        }
    }

    var spreadResult: Result<SpreadPicture, CalcError> {
        CalcCatch.run {
            let model = try makeModel()
            let a = try Self.finite(weightX, name: "the X weight")
            let b = try Self.finite(weightY, name: "the Y weight")
            let parts = try StatisticsMath.spread(model: model, weightX: a, weightY: b)
            let pairs = try StatisticsMath.simulatePairs(model: model, count: try makeCount(), seed: StatisticsMath.defaultSeed &+ 19)
            let values = StatisticsMath.combine(pairs, weightX: a, weightY: b)
            let theory = StatMoments(mean: parts.mean, standardDeviation: parts.standardDeviation, count: 0)
            let pad = 4 * max(parts.standardDeviation, 1e-6)
            let draw = DistributionDraw(
                theory: theory,
                sample: StatisticsMath.summarize(values),
                bins: StatisticsMath.histogram(
                    values: values,
                    binCount: 28,
                    windowStart: theory.mean - pad,
                    windowEnd: theory.mean + pad
                ),
                curve: normalCurve(mean: theory.mean, sd: theory.standardDeviation, start: theory.mean - pad, end: theory.mean + pad),
                windowStart: theory.mean - pad,
                windowEnd: theory.mean + pad,
                continuous: true
            )
            return SpreadPicture(
                parts: parts,
                balance: StatisticsMath.signBalance(pairs: pairs, model: model),
                combination: draw
            )
        }
    }

    func makeSpec() throws -> DistributionSpec {
        switch family {
        case .normal:
            return DistributionSpec(
                family: .normal,
                mean: try Self.finite(distMean, name: "Mean"),
                standardDeviation: try Self.finite(distSD, name: "SD")
            )
        case .uniform:
            return DistributionSpec(
                family: .uniform,
                low: try Self.finite(distHighLow, name: "Low"),
                high: try Self.finite(distHigh, name: "High")
            )
        case .exponential:
            return DistributionSpec(family: .exponential, rate: try Self.finite(distRate, name: "Rate"))
        case .binomial:
            return DistributionSpec(
                family: .binomial,
                trials: try Self.whole(distTrials, name: "Tries"),
                successProbability: try Self.finite(distP, name: "Success chance")
            )
        case .poisson:
            return DistributionSpec(family: .poisson, lambda: try Self.finite(distLambda, name: "Rate"))
        }
    }

    func makeModel() throws -> BivariateNormal {
        BivariateNormal(
            meanX: try Self.finite(mux, name: "Mean X"),
            meanY: try Self.finite(muy, name: "Mean Y"),
            sdX: try Self.finite(sx, name: "SD X"),
            sdY: try Self.finite(sy, name: "SD Y"),
            correlation: try Self.finite(rho, name: "Correlation")
        )
    }

    func makeWindow() throws -> XWindow {
        switch windowKind {
        case .above:
            return .above(try Self.finite(xCut, name: "the X cut"))
        case .between:
            return .between(
                try Self.finite(xLow, name: "X low"),
                try Self.finite(xHigh, name: "X high")
            )
        }
    }

    func makeCount() throws -> Int {
        try Self.whole(draws, name: "Draws")
    }

    static func finite(_ text: String, name: String) throws -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value.isFinite else {
            throw CalcError.missing(name)
        }
        return value
    }

    static func whole(_ text: String, name: String) throws -> Int {
        let value = try finite(text, name: name)
        guard value == value.rounded() else {
            throw CalcError.outOfRange("\(name) must be a whole number.")
        }
        return Int(value)
    }

    func normalCurve(mean: Double, sd: Double, start: Double, end: Double) -> [StatPoint] {
        guard sd > 1e-9 else { return [] }
        let spec = DistributionSpec(family: .normal, mean: mean, standardDeviation: sd)
        return (0...80).map { index in
            let x = start + (end - start) * Double(index) / 80
            return StatPoint(x: x, y: StatisticsMath.density(x, spec: spec))
        }
    }

    var stickyAnswer: String? {
        switch page {
        case .hub, .dice:
            return nil
        case .distributions:
            guard case .success(let draw) = distributionResult else { return nil }
            return "Draw mean \(statText(draw.sample.mean))"
        case .rescale:
            guard case .success(let picture) = rescaleResult else { return nil }
            return "Y SD \(statText(picture.scaled.theory.standardDeviation))"
        case .paired:
            guard case .success(let picture) = pairedResult else { return nil }
            return "Conditional mean \(statText(picture.conditional.mean))"
        case .spread:
            guard case .success(let picture) = spreadResult else { return nil }
            return "SD \(statText(picture.parts.standardDeviation))"
        }
    }

    var copyText: String? {
        switch page {
        case .hub:
            return nil
        case .distributions:
            guard case .success(let draw) = distributionResult else { return nil }
            return distributionCopy(draw)
        case .rescale:
            guard case .success(let picture) = rescaleResult else { return nil }
            return rescaleCopy(picture)
        case .paired:
            guard case .success(let picture) = pairedResult else { return nil }
            return pairedCopy(picture)
        case .spread:
            guard case .success(let picture) = spreadResult else { return nil }
            return spreadCopy(picture)
        case .dice:
            return diceCopy(StatisticsMath.dice(condition: dice, sumAtMost: Int(diceCut) ?? 8))
        }
    }

    func distributionCopy(_ draw: DistributionDraw) -> String {
        "Formula mean \(statText(draw.theory.mean)), SD \(statText(draw.theory.standardDeviation)). Draw mean \(statText(draw.sample.mean)), SD \(statText(draw.sample.standardDeviation))."
    }

    func rescaleCopy(_ picture: RescalePicture) -> String {
        "Y = \(statText(picture.factor)) X + \(statText(picture.offset)). Formula mean \(statText(picture.scaled.theory.mean)), SD \(statText(picture.scaled.theory.standardDeviation))."
    }

    func pairedCopy(_ picture: PairedPicture) -> String {
        "Conditional mean \(statText(picture.conditional.mean)), SD \(statText(picture.conditional.standardDeviation)). P(Y at most cut | event) \(statPercent(picture.conditional.probabilityAtMost)). Example parameters only."
    }

    func spreadCopy(_ picture: SpreadPicture) -> String {
        "Cov \(statText(picture.parts.covariance)), corr \(statText(picture.parts.correlation)), mean \(statText(picture.parts.mean)), SD \(statText(picture.parts.standardDeviation))."
    }

    func diceCopy(_ picture: DicePicture) -> String {
        "Kept \(picture.kept) of \(picture.total). Mean \(statText(picture.mean)), SD \(statText(picture.standardDeviation)), P \(statPercent(picture.probabilityAtMost))."
    }
}

private struct PairedPicture {
    var model: BivariateNormal
    var window: XWindow
    var pairs: [PairedSample]
    var conditional: ConditionalY
    var sample: StatMoments
    var sampleChance: Double?
    var insideCount: Int
    var totalCount: Int
    var yCut: Double
}

private struct SpreadPicture {
    var parts: SpreadParts
    var balance: SignBalance
    var combination: DistributionDraw
}

// MARK: - Charts

private struct DensityChart: View {
    var draw: DistributionDraw
    var xTitle: String
    var fullscreenTitle: String

    var body: some View {
        let peak = max(draw.bins.map(\.density).max() ?? 0, draw.curve.map(\.y).max() ?? 0, 1e-6)
        let yMax = peak * 1.12
        LabeledPlotChrome(
            xAxis: PlotAxis(
                title: xTitle,
                unit: "",
                start: statText(draw.windowStart),
                mid: statText((draw.windowStart + draw.windowEnd) / 2),
                end: statText(draw.windowEnd)
            ),
            yAxis: PlotAxis(title: "Density", unit: "", start: "0", mid: nil, end: statText(yMax)),
            accessibilityLabel: "\(fullscreenTitle). Draw beside the formula.",
            inspection: .inspect,
            plotHeight: 180,
            fullscreenTitle: fullscreenTitle,
            readout: { x, _ in
                let value = draw.windowStart + (draw.windowEnd - draw.windowStart) * Double(x)
                return "\(xTitle) \(statText(value))"
            }
        ) {
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                var grid = Path()
                let midY = mapY(yMax / 2, rect: rect, yMax: yMax)
                grid.move(to: CGPoint(x: rect.minX, y: midY))
                grid.addLine(to: CGPoint(x: rect.maxX, y: midY))
                context.stroke(grid, with: .color(Theme.chartGrid), lineWidth: 1)

                for bin in draw.bins where bin.count > 0 {
                    let x0 = mapX(bin.start, rect: rect, start: draw.windowStart, end: draw.windowEnd)
                    let x1 = mapX(bin.end, rect: rect, start: draw.windowStart, end: draw.windowEnd)
                    let y = mapY(bin.density, rect: rect, yMax: yMax)
                    let bar = CGRect(x: x0 + 0.5, y: y, width: max(1, x1 - x0 - 1), height: max(0, rect.maxY - y))
                    context.fill(Path(bar), with: .color(Theme.chartFill))
                    context.stroke(Path(bar), with: .color(Theme.chartPrimary.opacity(0.9)), lineWidth: 1)
                }

                if draw.continuous, draw.curve.count > 1 {
                    var curve = Path()
                    for (index, point) in draw.curve.enumerated() {
                        let p = CGPoint(
                            x: mapX(point.x, rect: rect, start: draw.windowStart, end: draw.windowEnd),
                            y: mapY(point.y, rect: rect, yMax: yMax)
                        )
                        if index == 0 { curve.move(to: p) } else { curve.addLine(to: p) }
                    }
                    context.stroke(curve, with: .color(Theme.chartSecondary), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                } else {
                    for point in draw.curve where point.y > 0 {
                        let center = CGPoint(
                            x: mapX(point.x, rect: rect, start: draw.windowStart, end: draw.windowEnd),
                            y: mapY(point.y, rect: rect, yMax: yMax)
                        )
                        let dot = CGRect(x: center.x - 2.5, y: center.y - 2.5, width: 5, height: 5)
                        context.fill(Path(ellipseIn: dot), with: .color(Theme.chartSecondary))
                    }
                }

                strokeRule(draw.theory.mean, color: Theme.chartSecondary, dash: [4, 3], rect: rect, context: &context)
                strokeRule(draw.sample.mean, color: Theme.chartPrimary, dash: [], rect: rect, context: &context)
            }
        }
    }

    private func strokeRule(
        _ value: Double,
        color: Color,
        dash: [CGFloat],
        rect: CGRect,
        context: inout GraphicsContext
    ) {
        let x = mapX(value, rect: rect, start: draw.windowStart, end: draw.windowEnd)
        var path = Path()
        path.move(to: CGPoint(x: x, y: rect.minY))
        path.addLine(to: CGPoint(x: x, y: rect.maxY))
        context.stroke(path, with: .color(color.opacity(0.85)), style: StrokeStyle(lineWidth: 1.25, dash: dash))
    }
}

private struct ScatterChart: View {
    var picture: PairedPicture

    var body: some View {
        let frame = scatterFrame
        LabeledPlotChrome(
            xAxis: PlotAxis(
                title: "X",
                unit: "",
                start: statText(frame.minX),
                mid: statText((frame.minX + frame.maxX) / 2),
                end: statText(frame.maxX)
            ),
            yAxis: PlotAxis(
                title: "Y",
                unit: "",
                start: statText(frame.minY),
                mid: nil,
                end: statText(frame.maxY)
            ),
            accessibilityLabel: "Scatter of the paired normal. Highlighted points sit in the X range.",
            inspection: .look,
            plotHeight: 220,
            fullscreenTitle: "Paired normal"
        ) {
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let ellipse = StatisticsMath.ellipse(model: picture.model)
                var ring = Path()
                for (index, point) in ellipse.enumerated() {
                    let p = place(point.x, point.y, rect: rect, frame: frame)
                    if index == 0 { ring.move(to: p) } else { ring.addLine(to: p) }
                }
                context.stroke(ring, with: .color(Theme.chartSecondary.opacity(0.9)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))

                let step = max(1, picture.pairs.count / 900)
                for (index, pair) in picture.pairs.enumerated() where index % step == 0 {
                    let inside = StatisticsMath.contains(pair.x, window: picture.window)
                    let dot = CGRect(
                        origin: place(pair.x, pair.y, rect: rect, frame: frame),
                        size: .zero
                    ).insetBy(dx: -2.2, dy: -2.2)
                    let color = inside ? Theme.accent : Theme.muted.opacity(0.45)
                    context.fill(Path(ellipseIn: dot), with: .color(color))
                }

                for cut in verticalCuts {
                    var path = Path()
                    let x = mapX(cut, rect: rect, start: frame.minX, end: frame.maxX)
                    path.move(to: CGPoint(x: x, y: rect.minY))
                    path.addLine(to: CGPoint(x: x, y: rect.maxY))
                    context.stroke(path, with: .color(Theme.warn), style: StrokeStyle(lineWidth: 1.25, dash: [3, 3]))
                }

                var mean = Path()
                let y = mapY(picture.conditional.mean, rect: rect, yMin: frame.minY, yMax: frame.maxY)
                mean.move(to: CGPoint(x: rect.minX, y: y))
                mean.addLine(to: CGPoint(x: rect.maxX, y: y))
                context.stroke(mean, with: .color(Theme.chartPrimary), style: StrokeStyle(lineWidth: 1.25, dash: [2, 3]))
            }
        }
    }

    private var scatterFrame: (minX: Double, maxX: Double, minY: Double, maxY: Double) {
        var minX = picture.model.meanX - 3.4 * picture.model.sdX
        var maxX = picture.model.meanX + 3.4 * picture.model.sdX
        var minY = picture.model.meanY - 3.4 * picture.model.sdY
        var maxY = picture.model.meanY + 3.4 * picture.model.sdY
        for cut in verticalCuts {
            minX = min(minX, cut)
            maxX = max(maxX, cut)
        }
        minY = min(minY, picture.conditional.mean)
        maxY = max(maxY, picture.conditional.mean)
        if maxX - minX < 1e-6 { maxX = minX + 1 }
        if maxY - minY < 1e-6 { maxY = minY + 1 }
        return (minX, maxX, minY, maxY)
    }

    private var verticalCuts: [Double] {
        switch picture.window {
        case .above(let cut):
            return [cut]
        case .between(let low, let high):
            return [low, high]
        }
    }

    private func place(_ x: Double, _ y: Double, rect: CGRect, frame: (minX: Double, maxX: Double, minY: Double, maxY: Double)) -> CGPoint {
        CGPoint(
            x: mapX(x, rect: rect, start: frame.minX, end: frame.maxX),
            y: mapY(y, rect: rect, yMin: frame.minY, yMax: frame.maxY)
        )
    }
}

private struct SpreadBars: View {
    var parts: SpreadParts

    var body: some View {
        let rows: [(String, Double, Color)] = [
            ("a² var X", parts.fromX, Theme.chartPrimary),
            ("b² var Y", parts.fromY, Theme.accent2),
            ("2ab cov", parts.fromProduct, parts.fromProduct < 0 ? Theme.bad : Theme.good),
        ]
        let peak = max(rows.map { abs($0.1) }.max() ?? 1, 1e-9)
        VStack(alignment: .leading, spacing: 8) {
            Text("VARIANCE PARTS")
                .font(Theme.TypeRole.sectionLabel)
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    Text(row.0)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.foreground)
                        .frame(width: 78, alignment: .leading)
                    GeometryReader { geo in
                        let width = geo.size.width * CGFloat(min(1, abs(row.1) / peak))
                        Capsule()
                            .fill(row.2.opacity(0.85))
                            .frame(width: max(2, width), height: 8)
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: 18)
                    Text(statText(row.1))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                        .frame(width: 64, alignment: .trailing)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Variance parts. From X \(statText(parts.fromX)), from Y \(statText(parts.fromY)), from the product \(statText(parts.fromProduct)).")
    }
}

private struct SignGrid: View {
    var balance: SignBalance

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                cell("X low, Y high", count: balance.xLowYHigh, same: false)
                cell("Both high", count: balance.bothHigh, same: true)
            }
            HStack(spacing: 6) {
                cell("Both low", count: balance.bothLow, same: true)
                cell("X high, Y low", count: balance.xHighYLow, same: false)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sign corners. Same sign \(balance.bothHigh + balance.bothLow). Opposite \(balance.xHighYLow + balance.xLowYHigh).")
    }

    private func cell(_ title: String, count: Int, same: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            Text("\(count)")
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.foreground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.sm)
        .background((same ? Theme.good : Theme.warn).opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    }
}

private struct DiceChart: View {
    var picture: DicePicture

    var body: some View {
        let peak = max(
            picture.conditional.map(\.probability).max() ?? 0,
            picture.baseline.map(\.probability).max() ?? 0,
            0.05
        ) * 1.15
        LabeledPlotChrome(
            xAxis: PlotAxis(title: "Sum", unit: "", start: "2", mid: "7", end: "12"),
            yAxis: PlotAxis(title: "Chance", unit: "", start: "0", mid: nil, end: statPercent(peak)),
            accessibilityLabel: "Chance of each dice sum, in the condition and across all faces.",
            inspection: .look,
            plotHeight: 180,
            fullscreenTitle: "Two dice"
        ) {
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let slot = rect.width / 11
                for bar in picture.baseline {
                    let x = rect.minX + CGFloat(bar.sum - 2) * slot
                    let h = CGFloat(bar.probability / peak) * rect.height
                    let mark = CGRect(x: x + slot * 0.18, y: rect.maxY - h, width: slot * 0.28, height: h)
                    context.fill(Path(mark), with: .color(Theme.muted.opacity(0.45)))
                }
                for bar in picture.conditional {
                    let x = rect.minX + CGFloat(bar.sum - 2) * slot
                    let h = CGFloat(bar.probability / peak) * rect.height
                    let mark = CGRect(x: x + slot * 0.5, y: rect.maxY - h, width: slot * 0.32, height: max(h, bar.probability > 0 ? 1.5 : 0))
                    context.fill(Path(roundedRect: mark, cornerRadius: 2), with: .color(Theme.chartPrimary))
                }
            }
        }
    }
}

private struct PlotLegend: View {
    var items: [(Color, String)]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(item.0)
                        .frame(width: 12, height: 8)
                    Text(item.1)
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }
}

private func statText(_ value: Double) -> String {
    guard value.isFinite else { return "—" }
    let magnitude = abs(value)
    if magnitude >= 100 || magnitude == 0 { return String(format: "%.1f", value) }
    if magnitude >= 10 { return String(format: "%.2f", value) }
    if magnitude >= 0.01 { return String(format: "%.3f", value) }
    return String(format: "%.2e", value)
}

private func statPercent(_ value: Double) -> String {
    guard value.isFinite else { return "—" }
    return String(format: "%.1f%%", value * 100)
}

private func mapX(_ x: Double, rect: CGRect, start: Double, end: Double) -> CGFloat {
    let u = (x - start) / max(end - start, 1e-9)
    return rect.minX + CGFloat(u) * rect.width
}

private func mapY(_ y: Double, rect: CGRect, yMax: Double) -> CGFloat {
    let v = y / max(yMax, 1e-9)
    return rect.maxY - CGFloat(min(1.2, max(0, v))) * rect.height
}

private func mapY(_ y: Double, rect: CGRect, yMin: Double, yMax: Double) -> CGFloat {
    let v = (y - yMin) / max(yMax - yMin, 1e-9)
    return rect.maxY - CGFloat(v) * rect.height
}
