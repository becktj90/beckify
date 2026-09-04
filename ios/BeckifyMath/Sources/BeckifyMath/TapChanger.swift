import Foundation

public struct TapPositionResult: Equatable, Sendable {
    public var tapPercent: Double
    public var expectedSecondaryVolts: Double
    public var errorVolts: Double
    public var isCurrent: Bool
    public var isRecommended: Bool

    public var label: String {
        if tapPercent > 0 { return "+\(FormatTrace.number(tapPercent, digits: 1))%" }
        if tapPercent < 0 { return "\(FormatTrace.number(tapPercent, digits: 1))%" }
        return "0% (Nominal)"
    }
}

public struct TapChangerResult: Equatable, Sendable {
    public var measuredSecondaryVolts: Double
    public var currentTapPercent: Double
    public var nominalPrimaryVolts: Double
    public var nominalSecondaryVolts: Double
    public var nominalRatio: Double
    public var impliedPrimaryVolts: Double
    public var positions: [TapPositionResult]
    public var recommendedTapPercent: Double
    public var recommendedSecondaryVolts: Double
    public var formula: String
}

/// DETC / off-load tap recommendation for a fixed primary/secondary pair.
/// Default model matches the website tool: 23 kV / 480 V with ±5% / ±2.5% / 0 taps.
public enum TapChanger {
    public static let defaultTapPercents: [Double] = [-5, -2.5, 0, 2.5, 5]

    public static func solve(
        measuredSecondaryVolts: Double,
        currentTapPercent: Double,
        nominalPrimaryVolts: Double = 23_000,
        nominalSecondaryVolts: Double = 480,
        tapPercents: [Double] = defaultTapPercents
    ) throws -> TapChangerResult {
        let measured = try Positive.require(measuredSecondaryVolts, name: "Measured secondary voltage")
        let primary = try Positive.require(nominalPrimaryVolts, name: "Nominal primary voltage")
        let secondary = try Positive.require(nominalSecondaryVolts, name: "Nominal secondary voltage")
        guard currentTapPercent.isFinite else {
            throw CalcError.missing("current tap setting")
        }
        guard !tapPercents.isEmpty else {
            throw CalcError.outOfRange("Need at least one tap position.")
        }
        for tap in tapPercents {
            guard tap.isFinite, tap > -100 else {
                throw CalcError.outOfRange("Tap positions must be finite and greater than −100%.")
            }
        }

        let ratio = primary / secondary
        // V_sec = V_pri / (ratio × (1 + tap/100))
        // Implied primary from measured secondary at the present tap.
        let impliedPrimary = measured * ratio * (1 + currentTapPercent / 100)

        var positions = tapPercents.map { tap -> TapPositionResult in
            let expected = impliedPrimary / (ratio * (1 + tap / 100))
            return TapPositionResult(
                tapPercent: tap,
                expectedSecondaryVolts: expected,
                errorVolts: abs(expected - secondary),
                isCurrent: abs(tap - currentTapPercent) < 1e-9,
                isRecommended: false
            )
        }
        guard let bestIndex = positions.indices.min(by: { positions[$0].errorVolts < positions[$1].errorVolts }) else {
            throw CalcError.outOfRange("Could not rank tap positions.")
        }
        positions[bestIndex].isRecommended = true
        let best = positions[bestIndex]

        return TapChangerResult(
            measuredSecondaryVolts: measured,
            currentTapPercent: currentTapPercent,
            nominalPrimaryVolts: primary,
            nominalSecondaryVolts: secondary,
            nominalRatio: ratio,
            impliedPrimaryVolts: impliedPrimary,
            positions: positions,
            recommendedTapPercent: best.tapPercent,
            recommendedSecondaryVolts: best.expectedSecondaryVolts,
            formula: "V_sec = V_pri / (N × (1 + tap/100))    N = V_pri_nom / V_sec_nom"
        )
    }
}
