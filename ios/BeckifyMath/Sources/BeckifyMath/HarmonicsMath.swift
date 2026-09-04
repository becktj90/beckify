import Foundation

public struct HarmonicComponent: Equatable, Sendable {
    public var order: Int
    public var amps: Double

    public init(order: Int, amps: Double) {
        self.order = order
        self.amps = amps
    }
}

public struct HarmonicsTHDResult: Equatable, Sendable {
    public var fundamentalAmps: Double
    public var components: [HarmonicComponent]
    public var harmonicRMS: Double
    public var thdPercent: Double
    public var status: String
    public var dominantOrder: Int?
    public var dominantAmps: Double
    public var mitigationHint: String
    public var formula: String
}

/// Current THD from harmonic order amplitudes. Status bands are engineering
/// guidance aligned with common IEEE 519 discussion — not a site PCC study.
public enum HarmonicsTHD {
    public static let defaultOrders = [2, 3, 5, 7, 9, 11, 13]

    public static func calculate(
        fundamentalAmps: Double,
        harmonics: [HarmonicComponent]
    ) throws -> HarmonicsTHDResult {
        let i1 = try Positive.require(fundamentalAmps, name: "Fundamental current I₁")
        var cleaned: [HarmonicComponent] = []
        for h in harmonics {
            guard h.order >= 2 else {
                throw CalcError.outOfRange("Harmonic order must be 2 or higher.")
            }
            guard h.amps.isFinite, h.amps >= 0 else {
                throw CalcError.outOfRange("Harmonic currents must be finite and not negative.")
            }
            cleaned.append(HarmonicComponent(order: h.order, amps: h.amps))
        }

        let sumSq = cleaned.reduce(0.0) { $0 + $1.amps * $1.amps }
        let harmonicRMS = sumSq.squareRoot()
        let thd = harmonicRMS / i1 * 100

        let dominant = cleaned.max(by: { $0.amps < $1.amps })
        let dominantOrder = (dominant?.amps ?? 0) > 0 ? dominant?.order : nil
        let dominantAmps = dominant?.amps ?? 0

        let mitigation: String
        switch dominantOrder {
        case 3, 9:
            mitigation = "Zero-sequence blocking transformer (ZSB) or active harmonic filter"
        case 5, 7:
            mitigation = "Passive 5th/7th filter, 12-pulse transformer, or active harmonic filter"
        case 11, 13:
            mitigation = "Passive 11th/13th filter or active harmonic filter"
        case .some:
            mitigation = "Active harmonic filter (broadband)"
        case nil:
            mitigation = "—"
        }

        let status: String
        if thd < 5 {
            status = "ACCEPTABLE (<5% typical IEEE 519 discussion band)"
        } else if thd < 15 {
            status = "MODERATE — evaluate IEEE 519 limits at the PCC"
        } else {
            status = "HIGH — likely exceeds IEEE 519 discussion limits; mitigation recommended"
        }

        return HarmonicsTHDResult(
            fundamentalAmps: i1,
            components: cleaned,
            harmonicRMS: harmonicRMS,
            thdPercent: thd,
            status: status,
            dominantOrder: dominantOrder,
            dominantAmps: dominantAmps,
            mitigationHint: mitigation,
            formula: "%THD = √(Σ Iₙ²) / I₁ × 100"
        )
    }
}
