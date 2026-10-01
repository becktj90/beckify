import XCTest
@testable import BeckifyMath

final class StatisticsTests: XCTestCase {

    func testNormalUniformAndExponentialMoments() throws {
        let normal = try StatisticsMath.theory(.standardNormal)
        XCTAssertEqual(normal.mean, 0, accuracy: 1e-12)
        XCTAssertEqual(normal.standardDeviation, 1, accuracy: 1e-12)

        let uniform = try StatisticsMath.theory(DistributionSpec(family: .uniform, low: 0, high: 1))
        XCTAssertEqual(uniform.mean, 0.5, accuracy: 1e-12)
        XCTAssertEqual(uniform.standardDeviation, 1 / sqrt(12), accuracy: 1e-12)

        let exponential = try StatisticsMath.theory(DistributionSpec(family: .exponential, rate: 0.5))
        XCTAssertEqual(exponential.mean, 2, accuracy: 1e-12)
        XCTAssertEqual(exponential.standardDeviation, 2, accuracy: 1e-12)
    }

    func testBinomialAndPoissonMoments() throws {
        let binomial = try StatisticsMath.theory(
            DistributionSpec(family: .binomial, trials: 10, successProbability: 0.3)
        )
        XCTAssertEqual(binomial.mean, 3, accuracy: 1e-12)
        XCTAssertEqual(binomial.standardDeviation, sqrt(2.1), accuracy: 1e-12)

        let poisson = try StatisticsMath.theory(DistributionSpec(family: .poisson, lambda: 4))
        XCTAssertEqual(poisson.mean, 4, accuracy: 1e-12)
        XCTAssertEqual(poisson.standardDeviation, 2, accuracy: 1e-12)
        XCTAssertEqual(StatisticsMath.mass(0, spec: DistributionSpec(family: .poisson, lambda: 1)), exp(-1), accuracy: 1e-12)
    }

    func testStandardNormalCurve() {
        XCTAssertEqual(StatisticsMath.standardDensity(0), 0.3989422804014327, accuracy: 1e-12)
        XCTAssertEqual(StatisticsMath.standardCDF(0), 0.5, accuracy: 1e-6)
        XCTAssertEqual(StatisticsMath.standardCDF(1), 0.8413447460685429, accuracy: 1e-6)
        XCTAssertEqual(StatisticsMath.standardCDF(1.96), 0.9750021048517796, accuracy: 1e-5)
        XCTAssertEqual(StatisticsMath.standardCDF(-1), 1 - StatisticsMath.standardCDF(1), accuracy: 1e-6)
        let density = StatisticsMath.density(0, spec: .standardNormal)
        XCTAssertEqual(density, StatisticsMath.standardDensity(0), accuracy: 1e-12)
    }

    func testRescaleMeanSpreadAndDensity() throws {
        let picture = try StatisticsMath.rescale(
            spec: .standardNormal,
            factor: -2,
            offset: 3,
            count: 400
        )
        XCTAssertTrue(picture.flipped)
        XCTAssertEqual(picture.scaled.theory.mean, 3, accuracy: 1e-12)
        XCTAssertEqual(picture.scaled.theory.standardDeviation, 2, accuracy: 1e-12)
        let atPeak = picture.scaled.curve.min { abs($0.x - 3) < abs($1.x - 3) }
        XCTAssertEqual(atPeak?.y ?? 0, StatisticsMath.standardDensity(0) / 2, accuracy: 1e-6)
        XCTAssertEqual(picture.source.bins.reduce(0) { $0 + $1.count }, 400)
        XCTAssertEqual(picture.scaled.bins.reduce(0) { $0 + $1.count }, 400)
    }

    func testSeededDrawIsStableAndNearTheFormula() throws {
        let first = try StatisticsMath.draw(spec: .standardNormal, count: 4_000, seed: 7)
        let second = try StatisticsMath.draw(spec: .standardNormal, count: 4_000, seed: 7)
        XCTAssertEqual(first.sample.mean, second.sample.mean, accuracy: 1e-12)
        XCTAssertEqual(first.sample.mean, 0, accuracy: 0.08)
        XCTAssertEqual(first.sample.standardDeviation, 1, accuracy: 0.08)
        let uniform = try StatisticsMath.draw(
            spec: DistributionSpec(family: .uniform, low: -2, high: 4),
            count: 4_000,
            seed: 3
        )
        XCTAssertEqual(uniform.sample.mean, 1, accuracy: 0.12)
    }

    func testHalfLineConditionalMoments() throws {
        let model = BivariateNormal(meanX: 0, meanY: 0, sdX: 1, sdY: 1, correlation: 0.5)
        let result = try StatisticsMath.conditionalY(model: model, window: .above(0), yAtMost: 0)
        XCTAssertEqual(result.eventProbability, 0.5, accuracy: 1e-6)
        XCTAssertEqual(result.mean, 0.3989422804014327, accuracy: 1e-5)
        XCTAssertEqual(result.standardDeviation, 0.916976039440565, accuracy: 1e-4)
        XCTAssertEqual(result.probabilityAtMost, 1.0 / 3.0, accuracy: 1e-3)
    }

    func testIndependentAndIntervalConditioning() throws {
        let model = BivariateNormal(meanX: 0, meanY: 2, sdX: 1, sdY: 1.5, correlation: 0)
        let half = try StatisticsMath.conditionalY(model: model, window: .above(0), yAtMost: 2)
        XCTAssertEqual(half.mean, 2, accuracy: 1e-8)
        XCTAssertEqual(half.standardDeviation, 1.5, accuracy: 1e-8)
        XCTAssertEqual(half.probabilityAtMost, 0.5, accuracy: 1e-3)

        let linked = BivariateNormal(meanX: 0, meanY: 0, sdX: 1, sdY: 1, correlation: 0.5)
        let band = try StatisticsMath.conditionalY(model: linked, window: .between(0, 1), yAtMost: 0)
        XCTAssertEqual(band.eventProbability, 0.3413447460685429, accuracy: 1e-5)
        XCTAssertEqual(band.mean, 0.22993111464321328, accuracy: 1e-4)
        XCTAssertEqual(band.standardDeviation, 0.8774468395362353, accuracy: 1e-4)
    }

    func testPerfectLineReducesToOneVariable() throws {
        let model = BivariateNormal(meanX: 0, meanY: 0, sdX: 1, sdY: 1, correlation: 1)
        let result = try StatisticsMath.conditionalY(model: model, window: .above(1), yAtMost: 2)
        let expected = (StatisticsMath.standardCDF(2) - StatisticsMath.standardCDF(1))
            / (1 - StatisticsMath.standardCDF(1))
        XCTAssertEqual(result.probabilityAtMost, expected, accuracy: 1e-6)
        let impossible = try StatisticsMath.conditionalY(model: model, window: .above(1), yAtMost: 0)
        XCTAssertEqual(impossible.probabilityAtMost, 0, accuracy: 1e-8)
    }

    func testExampleScoreConditional() throws {
        let result = try StatisticsMath.conditionalY(
            model: .exampleScores,
            window: .above(600),
            yAtMost: 550
        )
        XCTAssertEqual(result.eventProbability, 0.15865525393145707, accuracy: 1e-5)
        XCTAssertEqual(result.mean, 591.5081165696589, accuracy: 1e-2)
        XCTAssertEqual(result.standardDeviation, 84.36084160351446, accuracy: 1e-2)
        XCTAssertEqual(result.probabilityAtMost, 0.31283849717245926, accuracy: 2e-3)
    }

    func testLinearCombinationParts() throws {
        let model = BivariateNormal(meanX: 10, meanY: 4, sdX: 2, sdY: 3, correlation: 0.5)
        let parts = try StatisticsMath.spread(model: model, weightX: 2, weightY: -1)
        XCTAssertEqual(parts.covariance, 3, accuracy: 1e-12)
        XCTAssertEqual(parts.mean, 16, accuracy: 1e-12)
        XCTAssertEqual(parts.fromX, 16, accuracy: 1e-12)
        XCTAssertEqual(parts.fromY, 9, accuracy: 1e-12)
        XCTAssertEqual(parts.fromProduct, -12, accuracy: 1e-12)
        XCTAssertEqual(parts.standardDeviation, sqrt(13), accuracy: 1e-12)

        let pairs = try StatisticsMath.simulatePairs(model: model, count: 4_000, seed: 11)
        let combined = StatisticsMath.summarize(StatisticsMath.combine(pairs, weightX: 2, weightY: -1))
        XCTAssertEqual(combined.mean, 16, accuracy: 0.4)
        XCTAssertEqual(combined.standardDeviation, sqrt(13), accuracy: 0.35)
        let signs = StatisticsMath.signBalance(pairs: pairs, model: model)
        XCTAssertEqual(signs.bothHigh + signs.bothLow + signs.xHighYLow + signs.xLowYHigh, 4_000)
        XCTAssertGreaterThan(signs.bothHigh + signs.bothLow, signs.xHighYLow + signs.xLowYHigh)
        XCTAssertEqual(signs.sampleCovariance, 3, accuracy: 0.4)
    }

    func testRejectedInputs() {
        XCTAssertThrowsError(try StatisticsMath.theory(DistributionSpec(family: .normal, standardDeviation: 0)))
        XCTAssertThrowsError(try StatisticsMath.theory(DistributionSpec(family: .uniform, low: 2, high: 2)))
        XCTAssertThrowsError(try StatisticsMath.draw(spec: .standardNormal, count: 10))
        let wild = BivariateNormal(meanX: 0, meanY: 0, sdX: 1, sdY: 1, correlation: 1.2)
        XCTAssertThrowsError(try StatisticsMath.conditionalY(model: wild, window: .above(0), yAtMost: 0))
        XCTAssertThrowsError(
            try StatisticsMath.conditionalY(model: .exampleScores, window: .above(5_000), yAtMost: 500)
        )
    }

    func testTwoDiceAreExact() {
        let open = StatisticsMath.dice(condition: .any, sumAtMost: 7)
        XCTAssertEqual(open.total, 36)
        XCTAssertEqual(open.kept, 36)
        XCTAssertEqual(open.mean, 7, accuracy: 1e-12)
        XCTAssertEqual(open.standardDeviation, sqrt(35.0 / 6.0), accuracy: 1e-12)
        XCTAssertEqual(open.baseline.first { $0.sum == 7 }?.probability ?? 0, 6.0 / 36.0, accuracy: 1e-12)

        let high = StatisticsMath.dice(condition: .firstAtLeastFour, sumAtMost: 6)
        XCTAssertEqual(high.kept, 18)
        XCTAssertEqual(high.mean, 8.5, accuracy: 1e-12)
        XCTAssertEqual(high.probabilityAtMost, 3.0 / 18.0, accuracy: 1e-12)

        let matched = StatisticsMath.dice(condition: .facesMatch, sumAtMost: 7)
        XCTAssertEqual(matched.kept, 6)
        XCTAssertEqual(matched.mean, 7, accuracy: 1e-12)

        let seven = StatisticsMath.dice(condition: .sumIsSeven, sumAtMost: 7)
        XCTAssertEqual(seven.kept, 6)
        XCTAssertEqual(seven.mean, 7, accuracy: 1e-12)
        XCTAssertEqual(seven.standardDeviation, 0, accuracy: 1e-12)
        XCTAssertEqual(seven.probabilityAtMost, 1, accuracy: 1e-12)
    }

    func testStatisticsLivesOnFieldAnalysisAndHasCopy() {
        XCTAssertTrue(ToolCalculationPolicy.knownToolIDs.contains("statistics"))
        XCTAssertEqual(ToolCalculationPolicy.mode(forToolID: "statistics"), .live)
        XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: "statistics"), .field)
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "statistics"), .analysis)
        let copy = ToolHowItWorksCatalog.copy(forToolID: "statistics")
        XCTAssertNotNil(copy)
        let blob = ([copy?.summary, copy?.context] + (copy?.bullets ?? [])).compactMap { $0 }.joined(separator: " ")
        for banned in ["textbook", "stat 350", "symbulate", "colab", "homework", "investigation", "lab exercise"] {
            XCTAssertFalse(blob.localizedCaseInsensitiveContains(banned), banned)
        }
        XCTAssertTrue(blob.localizedCaseInsensitiveContains("Monte Carlo"))
        XCTAssertTrue(blob.localizedCaseInsensitiveContains("College Board"))
    }
}
