import Foundation

/// Distributions, rescaling, paired normals, and exact two-dice counts.
///
/// Continuous pictures are seeded Monte Carlo plus closed formulas where a
/// formula exists. The conditional chance for a paired normal is a numerical
/// integral. Nothing here is a computer-algebra system.
public enum StatFamily: String, CaseIterable, Sendable, Codable {
    case normal
    case uniform
    case exponential
    case binomial
    case poisson

    public var isContinuous: Bool {
        switch self {
        case .normal, .uniform, .exponential: return true
        case .binomial, .poisson: return false
        }
    }
}

public struct DistributionSpec: Equatable, Sendable {
    public var family: StatFamily
    public var mean: Double
    public var standardDeviation: Double
    public var low: Double
    public var high: Double
    public var rate: Double
    public var trials: Int
    public var successProbability: Double
    public var lambda: Double

    public init(
        family: StatFamily,
        mean: Double = 0,
        standardDeviation: Double = 1,
        low: Double = 0,
        high: Double = 1,
        rate: Double = 1,
        trials: Int = 10,
        successProbability: Double = 0.5,
        lambda: Double = 4
    ) {
        self.family = family
        self.mean = mean
        self.standardDeviation = standardDeviation
        self.low = low
        self.high = high
        self.rate = rate
        self.trials = trials
        self.successProbability = successProbability
        self.lambda = lambda
    }

    public static let standardNormal = DistributionSpec(family: .normal, mean: 0, standardDeviation: 1)
}

public struct StatMoments: Equatable, Sendable {
    public var mean: Double
    public var standardDeviation: Double
    public var count: Int

    public init(mean: Double, standardDeviation: Double, count: Int) {
        self.mean = mean
        self.standardDeviation = standardDeviation
        self.count = count
    }
}

public struct StatPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct StatBin: Equatable, Sendable {
    public var start: Double
    public var end: Double
    public var count: Int
    /// Count / (n × width), so a continuous curve can sit on the same axis.
    public var density: Double

    public init(start: Double, end: Double, count: Int, density: Double) {
        self.start = start
        self.end = end
        self.count = count
        self.density = density
    }
}

public struct DistributionDraw: Equatable, Sendable {
    public var theory: StatMoments
    public var sample: StatMoments
    public var bins: [StatBin]
    public var curve: [StatPoint]
    public var windowStart: Double
    public var windowEnd: Double
    public var continuous: Bool

    public init(
        theory: StatMoments,
        sample: StatMoments,
        bins: [StatBin],
        curve: [StatPoint],
        windowStart: Double,
        windowEnd: Double,
        continuous: Bool
    ) {
        self.theory = theory
        self.sample = sample
        self.bins = bins
        self.curve = curve
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.continuous = continuous
    }
}

public struct RescalePicture: Equatable, Sendable {
    public var factor: Double
    public var offset: Double
    public var flipped: Bool
    public var source: DistributionDraw
    public var scaled: DistributionDraw

    public init(
        factor: Double,
        offset: Double,
        flipped: Bool,
        source: DistributionDraw,
        scaled: DistributionDraw
    ) {
        self.factor = factor
        self.offset = offset
        self.flipped = flipped
        self.source = source
        self.scaled = scaled
    }
}

public struct BivariateNormal: Equatable, Sendable {
    public var meanX: Double
    public var meanY: Double
    public var sdX: Double
    public var sdY: Double
    public var correlation: Double

    public init(meanX: Double, meanY: Double, sdX: Double, sdY: Double, correlation: Double) {
        self.meanX = meanX
        self.meanY = meanY
        self.sdX = sdX
        self.sdY = sdY
        self.correlation = correlation
    }

    /// Example scores on a 500 ± 100 scale. Not an official scoring product.
    public static let exampleScores = BivariateNormal(
        meanX: 500, meanY: 500, sdX: 100, sdY: 100, correlation: 0.6
    )
}

public enum XWindow: Equatable, Sendable {
    case above(Double)
    case between(Double, Double)
}

public struct ConditionalY: Equatable, Sendable {
    public var mean: Double
    public var standardDeviation: Double
    public var eventProbability: Double
    public var probabilityAtMost: Double

    public init(
        mean: Double,
        standardDeviation: Double,
        eventProbability: Double,
        probabilityAtMost: Double
    ) {
        self.mean = mean
        self.standardDeviation = standardDeviation
        self.eventProbability = eventProbability
        self.probabilityAtMost = probabilityAtMost
    }
}

public struct PairedSample: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct SpreadParts: Equatable, Sendable {
    public var covariance: Double
    public var correlation: Double
    public var mean: Double
    public var standardDeviation: Double
    public var fromX: Double
    public var fromY: Double
    public var fromProduct: Double

    public init(
        covariance: Double,
        correlation: Double,
        mean: Double,
        standardDeviation: Double,
        fromX: Double,
        fromY: Double,
        fromProduct: Double
    ) {
        self.covariance = covariance
        self.correlation = correlation
        self.mean = mean
        self.standardDeviation = standardDeviation
        self.fromX = fromX
        self.fromY = fromY
        self.fromProduct = fromProduct
    }
}

public struct SignBalance: Equatable, Sendable {
    public var bothHigh: Int
    public var bothLow: Int
    public var xHighYLow: Int
    public var xLowYHigh: Int
    public var sampleCovariance: Double

    public init(
        bothHigh: Int,
        bothLow: Int,
        xHighYLow: Int,
        xLowYHigh: Int,
        sampleCovariance: Double
    ) {
        self.bothHigh = bothHigh
        self.bothLow = bothLow
        self.xHighYLow = xHighYLow
        self.xLowYHigh = xLowYHigh
        self.sampleCovariance = sampleCovariance
    }
}

public enum DiceCondition: String, CaseIterable, Sendable, Codable {
    case any
    case firstAtLeastFour
    case facesMatch
    case sumIsSeven
}

public struct DiceBar: Equatable, Sendable {
    public var sum: Int
    public var probability: Double

    public init(sum: Int, probability: Double) {
        self.sum = sum
        self.probability = probability
    }
}

public struct DicePicture: Equatable, Sendable {
    public var conditional: [DiceBar]
    public var baseline: [DiceBar]
    public var mean: Double
    public var standardDeviation: Double
    public var probabilityAtMost: Double
    public var kept: Int
    public var total: Int

    public init(
        conditional: [DiceBar],
        baseline: [DiceBar],
        mean: Double,
        standardDeviation: Double,
        probabilityAtMost: Double,
        kept: Int,
        total: Int
    ) {
        self.conditional = conditional
        self.baseline = baseline
        self.mean = mean
        self.standardDeviation = standardDeviation
        self.probabilityAtMost = probabilityAtMost
        self.kept = kept
        self.total = total
    }
}

public enum StatisticsMath {
    public static let defaultSeed: UInt64 = 0xBEC5_7A75
    public static let minimumDraws = 100
    public static let maximumDraws = 20_000

    // MARK: - Normal curve

    public static func standardDensity(_ z: Double) -> Double {
        0.3989422804014327 * exp(-0.5 * z * z)
    }

    /// Abramowitz and Stegun 26.2.17. Absolute error under about 1e-7.
    public static func standardCDF(_ z: Double) -> Double {
        if z < -8 { return 0 }
        if z > 8 { return 1 }
        let x = abs(z)
        let t = 1 / (1 + 0.2316419 * x)
        let poly = (((((1.330274429 * t) - 1.821255978) * t) + 1.781477937) * t - 0.356563782) * t + 0.319381530
        let tail = standardDensity(x) * poly * t
        let upper = 1 - tail
        return z < 0 ? 1 - upper : upper
    }

    // MARK: - One variable

    public static func theory(_ spec: DistributionSpec) throws -> StatMoments {
        try validate(spec)
        switch spec.family {
        case .normal:
            return StatMoments(mean: spec.mean, standardDeviation: spec.standardDeviation, count: 0)
        case .uniform:
            let span = spec.high - spec.low
            return StatMoments(
                mean: (spec.low + spec.high) / 2,
                standardDeviation: span / sqrt(12),
                count: 0
            )
        case .exponential:
            let mean = 1 / spec.rate
            return StatMoments(mean: mean, standardDeviation: mean, count: 0)
        case .binomial:
            let mean = Double(spec.trials) * spec.successProbability
            let variance = mean * (1 - spec.successProbability)
            return StatMoments(mean: mean, standardDeviation: sqrt(max(0, variance)), count: 0)
        case .poisson:
            return StatMoments(mean: spec.lambda, standardDeviation: sqrt(spec.lambda), count: 0)
        }
    }

    public static func density(_ x: Double, spec: DistributionSpec) -> Double {
        switch spec.family {
        case .normal:
            let sd = spec.standardDeviation
            guard sd > 0 else { return 0 }
            return standardDensity((x - spec.mean) / sd) / sd
        case .uniform:
            guard spec.high > spec.low, x >= spec.low, x <= spec.high else { return 0 }
            return 1 / (spec.high - spec.low)
        case .exponential:
            guard spec.rate > 0, x >= 0 else { return 0 }
            return spec.rate * exp(-spec.rate * x)
        case .binomial:
            return mass(Int(x.rounded()), spec: spec)
        case .poisson:
            return mass(Int(x.rounded()), spec: spec)
        }
    }

    public static func mass(_ k: Int, spec: DistributionSpec) -> Double {
        switch spec.family {
        case .binomial:
            return binomialPMF(k: k, trials: spec.trials, probability: spec.successProbability)
        case .poisson:
            return poissonPMF(k: k, lambda: spec.lambda)
        case .normal, .uniform, .exponential:
            return 0
        }
    }

    public static func summarize(_ values: [Double]) -> StatMoments {
        let n = values.count
        guard n > 0 else { return StatMoments(mean: 0, standardDeviation: 0, count: 0) }
        let mean = values.reduce(0, +) / Double(n)
        guard n > 1 else { return StatMoments(mean: mean, standardDeviation: 0, count: 1) }
        var ss = 0.0
        for value in values {
            let d = value - mean
            ss += d * d
        }
        return StatMoments(mean: mean, standardDeviation: sqrt(ss / Double(n - 1)), count: n)
    }

    public static func histogram(
        values: [Double],
        binCount: Int,
        windowStart: Double,
        windowEnd: Double
    ) -> [StatBin] {
        let bins = max(1, binCount)
        let span = max(windowEnd - windowStart, 1e-9)
        let width = span / Double(bins)
        var counts = [Int](repeating: 0, count: bins)
        for value in values {
            var index = Int((value - windowStart) / width)
            if index < 0 { index = 0 }
            if index >= bins { index = bins - 1 }
            counts[index] += 1
        }
        let n = Double(max(values.count, 1))
        return counts.enumerated().map { index, count in
            let start = windowStart + Double(index) * width
            return StatBin(
                start: start,
                end: start + width,
                count: count,
                density: Double(count) / (n * width)
            )
        }
    }

    public static func draw(
        spec: DistributionSpec,
        count: Int,
        seed: UInt64 = defaultSeed
    ) throws -> DistributionDraw {
        let theory = try theory(spec)
        let samples = try sample(spec: spec, count: count, seed: seed)
        return picture(spec: spec, samples: samples, theory: theory)
    }

    public static func rescale(
        spec: DistributionSpec,
        factor: Double,
        offset: Double,
        count: Int,
        seed: UInt64 = defaultSeed
    ) throws -> RescalePicture {
        guard factor.isFinite, offset.isFinite else {
            throw CalcError.outOfRange("Scale and shift need finite numbers.")
        }
        let sourceTheory = try theory(spec)
        let samples = try sample(spec: spec, count: count, seed: seed)
        let source = picture(spec: spec, samples: samples, theory: sourceTheory)
        let scaledSamples = samples.map { factor * $0 + offset }
        let scaledTheory = StatMoments(
            mean: factor * sourceTheory.mean + offset,
            standardDeviation: abs(factor) * sourceTheory.standardDeviation,
            count: 0
        )
        let scaled = scaledPicture(
            spec: spec,
            samples: scaledSamples,
            factor: factor,
            offset: offset,
            theory: scaledTheory
        )
        return RescalePicture(
            factor: factor,
            offset: offset,
            flipped: factor < 0,
            source: source,
            scaled: scaled
        )
    }

    // MARK: - Paired normal

    public static func validate(_ model: BivariateNormal) throws {
        guard model.sdX > 0, model.sdY > 0 else {
            throw CalcError.nonPositive("Each spread")
        }
        guard model.meanX.isFinite, model.meanY.isFinite, model.sdX.isFinite, model.sdY.isFinite else {
            throw CalcError.outOfRange("Means and spreads need finite numbers.")
        }
        guard model.correlation >= -1, model.correlation <= 1 else {
            throw CalcError.outOfRange("Correlation must sit between −1 and 1.")
        }
    }

    public static func conditionalY(
        model: BivariateNormal,
        window: XWindow,
        yAtMost: Double
    ) throws -> ConditionalY {
        try validate(model)
        guard yAtMost.isFinite else {
            throw CalcError.outOfRange("The Y cut needs a finite number.")
        }
        let bounds = try standardBounds(window, model: model)
        let truncated = try truncatedStandard(low: bounds.low, high: bounds.high)
        let rho = model.correlation
        let mean = model.meanY + rho * model.sdY * truncated.mean
        let variance = model.sdY * model.sdY * (rho * rho * truncated.variance + (1 - rho * rho))
        let chance = conditionalProbability(
            model: model,
            low: bounds.low,
            high: bounds.high,
            eventProbability: truncated.probability,
            yAtMost: yAtMost
        )
        return ConditionalY(
            mean: mean,
            standardDeviation: sqrt(max(0, variance)),
            eventProbability: truncated.probability,
            probabilityAtMost: min(1, max(0, chance))
        )
    }

    public static func simulatePairs(
        model: BivariateNormal,
        count: Int,
        seed: UInt64 = defaultSeed
    ) throws -> [PairedSample] {
        try validate(model)
        let draws = try validatedCount(count)
        var rng = StatRNG(seed: seed)
        let rho = model.correlation
        let lateral = sqrt(max(0, 1 - rho * rho))
        var pairs: [PairedSample] = []
        pairs.reserveCapacity(draws)
        for _ in 0..<draws {
            let z1 = rng.normal()
            let z2 = rng.normal()
            let x = model.meanX + model.sdX * z1
            let y = model.meanY + model.sdY * (rho * z1 + lateral * z2)
            pairs.append(PairedSample(x: x, y: y))
        }
        return pairs
    }

    public static func contains(_ x: Double, window: XWindow) -> Bool {
        switch window {
        case .above(let cut):
            return x > cut
        case .between(let low, let high):
            return x > low && x < high
        }
    }

    public static func spread(
        model: BivariateNormal,
        weightX: Double,
        weightY: Double
    ) throws -> SpreadParts {
        try validate(model)
        guard weightX.isFinite, weightY.isFinite else {
            throw CalcError.outOfRange("Weights need finite numbers.")
        }
        let covariance = model.correlation * model.sdX * model.sdY
        let fromX = weightX * weightX * model.sdX * model.sdX
        let fromY = weightY * weightY * model.sdY * model.sdY
        let fromProduct = 2 * weightX * weightY * covariance
        return SpreadParts(
            covariance: covariance,
            correlation: model.correlation,
            mean: weightX * model.meanX + weightY * model.meanY,
            standardDeviation: sqrt(max(0, fromX + fromY + fromProduct)),
            fromX: fromX,
            fromY: fromY,
            fromProduct: fromProduct
        )
    }

    public static func signBalance(pairs: [PairedSample], model: BivariateNormal) -> SignBalance {
        var bothHigh = 0
        var bothLow = 0
        var xHighYLow = 0
        var xLowYHigh = 0
        for pair in pairs {
            let xHigh = pair.x >= model.meanX
            let yHigh = pair.y >= model.meanY
            switch (xHigh, yHigh) {
            case (true, true): bothHigh += 1
            case (false, false): bothLow += 1
            case (true, false): xHighYLow += 1
            case (false, true): xLowYHigh += 1
            }
        }
        let sample = summarize(pairs.map(\.x))
        let sampleY = summarize(pairs.map(\.y))
        var product = 0.0
        if pairs.count > 1 {
            for pair in pairs {
                product += (pair.x - sample.mean) * (pair.y - sampleY.mean)
            }
            product /= Double(pairs.count - 1)
        }
        return SignBalance(
            bothHigh: bothHigh,
            bothLow: bothLow,
            xHighYLow: xHighYLow,
            xLowYHigh: xLowYHigh,
            sampleCovariance: product
        )
    }

    public static func combine(_ pairs: [PairedSample], weightX: Double, weightY: Double) -> [Double] {
        pairs.map { weightX * $0.x + weightY * $0.y }
    }

    public static func ellipse(model: BivariateNormal, sigmas: Double = 1, steps: Int = 64) -> [StatPoint] {
        let rho = min(1, max(-1, model.correlation))
        let lateral = sqrt(max(0, 1 - rho * rho))
        let count = max(8, steps)
        return (0...count).map { index in
            let t = Double(index) / Double(count) * 2 * Double.pi
            let z1 = sigmas * cos(t)
            let z2 = sigmas * sin(t)
            return StatPoint(
                x: model.meanX + model.sdX * z1,
                y: model.meanY + model.sdY * (rho * z1 + lateral * z2)
            )
        }
    }

    // MARK: - Two dice

    public static func dice(condition: DiceCondition, sumAtMost: Int) -> DicePicture {
        var faces: [(Int, Int)] = []
        faces.reserveCapacity(36)
        for first in 1...6 {
            for second in 1...6 {
                faces.append((first, second))
            }
        }
        let kept = faces.filter { keep($0, condition: condition) }
        let cut = min(12, max(2, sumAtMost))
        func bars(_ rows: [(Int, Int)]) -> [DiceBar] {
            let total = Double(max(rows.count, 1))
            return (2...12).map { sum in
                let hits = rows.filter { $0.0 + $0.1 == sum }.count
                return DiceBar(sum: sum, probability: Double(hits) / total)
            }
        }
        let sums = kept.map { Double($0.0 + $0.1) }
        let moments = population(sums)
        let atMost = kept.filter { $0.0 + $0.1 <= cut }.count
        return DicePicture(
            conditional: bars(kept),
            baseline: bars(faces),
            mean: moments.mean,
            standardDeviation: moments.standardDeviation,
            probabilityAtMost: kept.isEmpty ? 0 : Double(atMost) / Double(kept.count),
            kept: kept.count,
            total: faces.count
        )
    }

    // MARK: - Private

    private static func validate(_ spec: DistributionSpec) throws {
        switch spec.family {
        case .normal:
            guard spec.standardDeviation > 0 else { throw CalcError.nonPositive("Spread") }
            guard spec.mean.isFinite else { throw CalcError.outOfRange("Mean needs a finite number.") }
        case .uniform:
            guard spec.high > spec.low else {
                throw CalcError.outOfRange("The high end must sit above the low end.")
            }
        case .exponential:
            guard spec.rate > 0 else { throw CalcError.nonPositive("Rate") }
        case .binomial:
            guard (1...60).contains(spec.trials) else {
                throw CalcError.outOfRange("Tries must be a whole number from 1 to 60.")
            }
            guard (0...1).contains(spec.successProbability) else {
                throw CalcError.outOfRange("Success chance must sit between 0 and 1.")
            }
        case .poisson:
            guard spec.lambda > 0, spec.lambda <= 40 else {
                throw CalcError.outOfRange("Rate must be greater than 0 and at most 40.")
            }
        }
    }

    private static func validatedCount(_ count: Int) throws -> Int {
        guard (minimumDraws...maximumDraws).contains(count) else {
            throw CalcError.outOfRange("Draws must be a whole number from \(minimumDraws) to \(maximumDraws).")
        }
        return count
    }

    private static func sample(spec: DistributionSpec, count: Int, seed: UInt64) throws -> [Double] {
        try validate(spec)
        let draws = try validatedCount(count)
        var rng = StatRNG(seed: seed)
        var values: [Double] = []
        values.reserveCapacity(draws)
        for _ in 0..<draws {
            values.append(rng.value(spec))
        }
        return values
    }

    private static func picture(
        spec: DistributionSpec,
        samples: [Double],
        theory: StatMoments
    ) -> DistributionDraw {
        let frame = window(spec: spec, theory: theory)
        let bins = histogram(
            values: samples,
            binCount: frame.bins,
            windowStart: frame.start,
            windowEnd: frame.end
        )
        return DistributionDraw(
            theory: theory,
            sample: summarize(samples),
            bins: bins,
            curve: curve(spec: spec, start: frame.start, end: frame.end, continuous: frame.continuous),
            windowStart: frame.start,
            windowEnd: frame.end,
            continuous: frame.continuous
        )
    }

    private static func window(
        spec: DistributionSpec,
        theory: StatMoments
    ) -> (start: Double, end: Double, bins: Int, continuous: Bool) {
        switch spec.family {
        case .normal:
            let pad = 4 * max(theory.standardDeviation, 1e-6)
            return (theory.mean - pad, theory.mean + pad, 28, true)
        case .uniform:
            return (spec.low, spec.high, 16, true)
        case .exponential:
            return (0, theory.mean + 6 * theory.standardDeviation, 28, true)
        case .binomial:
            let n = spec.trials
            return (-0.5, Double(n) + 0.5, n + 1, false)
        case .poisson:
            let hi = min(80, max(8, Int(ceil(spec.lambda + 4 * sqrt(spec.lambda)))))
            return (-0.5, Double(hi) + 0.5, hi + 1, false)
        }
    }

    private static func curve(
        spec: DistributionSpec,
        start: Double,
        end: Double,
        continuous: Bool
    ) -> [StatPoint] {
        if !continuous {
            let first = Int(ceil(start))
            let last = Int(floor(end))
            guard last >= first else { return [] }
            return (first...last).map { k in
                StatPoint(x: Double(k), y: mass(k, spec: spec))
            }
        }
        let steps = 80
        let span = end - start
        return (0...steps).map { index in
            let x = start + span * Double(index) / Double(steps)
            return StatPoint(x: x, y: density(x, spec: spec))
        }
    }

    private static func scaledPicture(
        spec: DistributionSpec,
        samples: [Double],
        factor: Double,
        offset: Double,
        theory: StatMoments
    ) -> DistributionDraw {
        let frame = scaledWindow(spec: spec, factor: factor, offset: offset, theory: theory)
        return DistributionDraw(
            theory: theory,
            sample: summarize(samples),
            bins: histogram(
                values: samples,
                binCount: frame.bins,
                windowStart: frame.start,
                windowEnd: frame.end
            ),
            curve: scaledCurve(
                spec: spec,
                factor: factor,
                offset: offset,
                start: frame.start,
                end: frame.end,
                continuous: frame.continuous
            ),
            windowStart: frame.start,
            windowEnd: frame.end,
            continuous: frame.continuous
        )
    }

    private static func scaledWindow(
        spec: DistributionSpec,
        factor: Double,
        offset: Double,
        theory: StatMoments
    ) -> (start: Double, end: Double, bins: Int, continuous: Bool) {
        if abs(factor) < 1e-9 {
            return (offset - 1, offset + 1, 12, true)
        }
        switch spec.family {
        case .normal:
            let pad = 4 * max(theory.standardDeviation, 1e-6)
            return (theory.mean - pad, theory.mean + pad, 28, true)
        case .uniform:
            let left = factor * spec.low + offset
            let right = factor * spec.high + offset
            return (min(left, right), max(left, right), 16, true)
        case .exponential:
            let reach = abs(factor) * (1 / spec.rate) * 7
            if factor > 0 {
                return (offset, offset + reach, 28, true)
            }
            return (offset - reach, offset, 28, true)
        case .binomial:
            let step = abs(factor)
            let images = (0...spec.trials).map { factor * Double($0) + offset }
            let start = (images.min() ?? offset) - step / 2
            let end = (images.max() ?? offset) + step / 2
            return (start, end, spec.trials + 1, false)
        case .poisson:
            let step = abs(factor)
            let hi = min(80, max(8, Int(ceil(spec.lambda + 4 * sqrt(spec.lambda)))))
            let images = (0...hi).map { factor * Double($0) + offset }
            let start = (images.min() ?? offset) - step / 2
            let end = (images.max() ?? offset) + step / 2
            return (start, end, hi + 1, false)
        }
    }

    private static func scaledCurve(
        spec: DistributionSpec,
        factor: Double,
        offset: Double,
        start: Double,
        end: Double,
        continuous: Bool
    ) -> [StatPoint] {
        guard abs(factor) > 1e-9 else { return [] }
        if continuous {
            let steps = 80
            let span = end - start
            return (0...steps).map { index in
                let y = start + span * Double(index) / Double(steps)
                let x = (y - offset) / factor
                return StatPoint(x: y, y: density(x, spec: spec) / abs(factor))
            }
        }
        let upper: Int
        switch spec.family {
        case .binomial: upper = spec.trials
        case .poisson: upper = min(80, max(8, Int(ceil(spec.lambda + 4 * sqrt(spec.lambda)))))
        default: upper = 0
        }
        let step = abs(factor)
        return (0...upper).map { k in
            StatPoint(x: factor * Double(k) + offset, y: mass(k, spec: spec) / step)
        }
    }

    private static func standardBounds(_ window: XWindow, model: BivariateNormal) throws -> (low: Double, high: Double?) {
        switch window {
        case .above(let cut):
            guard cut.isFinite else { throw CalcError.outOfRange("The X cut needs a finite number.") }
            return ((cut - model.meanX) / model.sdX, nil)
        case .between(let low, let high):
            guard low.isFinite, high.isFinite else {
                throw CalcError.outOfRange("Both ends of the X range need finite numbers.")
            }
            guard high > low else {
                throw CalcError.outOfRange("The high end must sit above the low end.")
            }
            return ((low - model.meanX) / model.sdX, (high - model.meanX) / model.sdX)
        }
    }

    private static func truncatedStandard(
        low: Double,
        high: Double?
    ) throws -> (mean: Double, variance: Double, probability: Double) {
        if let high {
            let probability = standardCDF(high) - standardCDF(low)
            guard probability > 1e-9 else {
                throw CalcError.outOfRange("That X range almost never happens. Widen it.")
            }
            let mean = (standardDensity(low) - standardDensity(high)) / probability
            let second = 1 + (low * standardDensity(low) - high * standardDensity(high)) / probability
            return (mean, max(0, second - mean * mean), probability)
        }
        let probability = 1 - standardCDF(low)
        guard probability > 1e-9 else {
            throw CalcError.outOfRange("That X range almost never happens. Widen it.")
        }
        let mills = standardDensity(low) / probability
        let variance = max(0, 1 + low * mills - mills * mills)
        return (mills, variance, probability)
    }

    private static func conditionalProbability(
        model: BivariateNormal,
        low: Double,
        high: Double?,
        eventProbability: Double,
        yAtMost: Double
    ) -> Double {
        let rho = model.correlation
        if abs(rho) >= 1 - 1e-8 {
            return degenerateChance(
                model: model,
                low: low,
                high: high,
                eventProbability: eventProbability,
                yAtMost: yAtMost
            )
        }
        let lateral = model.sdY * sqrt(1 - rho * rho)
        let upper = high ?? max(low + 10, 8)
        let integral = simpson(from: low, to: upper, intervals: 256) { z in
            let argument = (yAtMost - model.meanY - model.sdY * rho * z) / lateral
            return standardCDF(argument) * standardDensity(z)
        }
        return integral / eventProbability
    }

    private static func degenerateChance(
        model: BivariateNormal,
        low: Double,
        high: Double?,
        eventProbability: Double,
        yAtMost: Double
    ) -> Double {
        let slope = model.correlation * model.sdY / model.sdX
        if abs(slope) < 1e-12 {
            return model.meanY <= yAtMost ? 1 : 0
        }
        let zCut = (yAtMost - model.meanY) / slope
        let regionLow: Double
        let regionHigh: Double?
        if slope > 0 {
            regionLow = -1e9
            regionHigh = zCut
        } else {
            regionLow = zCut
            regionHigh = nil
        }
        let overlap = overlapProbability(low: low, high: high, otherLow: regionLow, otherHigh: regionHigh)
        return overlap / eventProbability
    }

    private static func overlapProbability(
        low: Double,
        high: Double?,
        otherLow: Double,
        otherHigh: Double?
    ) -> Double {
        let left = max(low, otherLow)
        let right: Double?
        switch (high, otherHigh) {
        case let (a?, b?): right = min(a, b)
        case let (a?, nil): right = a
        case let (nil, b?): right = b
        case (nil, nil): right = nil
        }
        if let right {
            return max(0, standardCDF(right) - standardCDF(left))
        }
        return max(0, 1 - standardCDF(left))
    }

    private static func simpson(
        from a: Double,
        to b: Double,
        intervals: Int,
        _ f: (Double) -> Double
    ) -> Double {
        guard b > a else { return 0 }
        let n = max(2, intervals - intervals % 2)
        let h = (b - a) / Double(n)
        var sum = f(a) + f(b)
        for index in 1..<n {
            let weight = index % 2 == 0 ? 2.0 : 4.0
            sum += weight * f(a + Double(index) * h)
        }
        return sum * h / 3
    }

    private static func binomialPMF(k: Int, trials: Int, probability: Double) -> Double {
        guard k >= 0, k <= trials else { return 0 }
        var choose = 1.0
        for index in 0..<k {
            choose *= Double(trials - index) / Double(index + 1)
        }
        let fail = 1 - probability
        return choose * pow(probability, Double(k)) * pow(fail, Double(trials - k))
    }

    private static func poissonPMF(k: Int, lambda: Double) -> Double {
        guard k >= 0, lambda > 0 else { return 0 }
        var value = exp(-lambda)
        if k == 0 { return value }
        for index in 1...k {
            value *= lambda / Double(index)
        }
        return value
    }

    private static func keep(_ face: (Int, Int), condition: DiceCondition) -> Bool {
        switch condition {
        case .any:
            return true
        case .firstAtLeastFour:
            return face.0 >= 4
        case .facesMatch:
            return face.0 == face.1
        case .sumIsSeven:
            return face.0 + face.1 == 7
        }
    }

    /// Whole population, so the divisor is n rather than n − 1.
    private static func population(_ values: [Double]) -> StatMoments {
        let n = values.count
        guard n > 0 else { return StatMoments(mean: 0, standardDeviation: 0, count: 0) }
        let mean = values.reduce(0, +) / Double(n)
        var ss = 0.0
        for value in values {
            let d = value - mean
            ss += d * d
        }
        return StatMoments(mean: mean, standardDeviation: sqrt(ss / Double(n)), count: n)
    }
}

private struct StatRNG {
    var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double {
        let bits = next() >> 11
        return (Double(bits) + 0.5) / 9007199254740992.0
    }

    mutating func normal() -> Double {
        let u1 = max(unit(), 1e-12)
        let u2 = unit()
        return sqrt(-2 * log(u1)) * cos(2 * Double.pi * u2)
    }

    mutating func value(_ spec: DistributionSpec) -> Double {
        switch spec.family {
        case .normal:
            return spec.mean + spec.standardDeviation * normal()
        case .uniform:
            return spec.low + (spec.high - spec.low) * unit()
        case .exponential:
            return -log(max(unit(), 1e-12)) / spec.rate
        case .binomial:
            var hits = 0
            if spec.successProbability <= 0 { return 0 }
            if spec.successProbability >= 1 { return Double(spec.trials) }
            for _ in 0..<spec.trials where unit() < spec.successProbability {
                hits += 1
            }
            return Double(hits)
        case .poisson:
            let limit = exp(-spec.lambda)
            var k = 0
            var p = 1.0
            repeat {
                k += 1
                p *= unit()
            } while p > limit && k < 10_000
            return Double(k - 1)
        }
    }
}
