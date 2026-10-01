import Foundation

/// Shared scale for a before/after power triangle.
///
/// Both reactive legs are divided by the longer hypotenuse, so the real-power
/// leg is one length. A per-triangle scale would stretch kW when kVAR shrinks.
public struct PowerTriangleComparison: Equatable, Sendable {
    public var realPowerKW: Double
    public var existingKVAR: Double
    public var targetKVAR: Double
    /// Longer of the two apparent-power hypotenuses.
    public var scaleKVA: Double
    public var bankMicrofarads: Double?

    public init(
        realPowerKW: Double,
        existingKVAR: Double,
        targetKVAR: Double,
        scaleKVA: Double,
        bankMicrofarads: Double?
    ) {
        self.realPowerKW = realPowerKW
        self.existingKVAR = existingKVAR
        self.targetKVAR = targetKVAR
        self.scaleKVA = scaleKVA
        self.bankMicrofarads = bankMicrofarads
    }

    /// Fraction of the drawing used by kW. Same value for the existing and corrected triangles.
    public var realLeg: Double { realPowerKW / scaleKVA }
    public var existingReactiveLeg: Double { abs(existingKVAR) / scaleKVA }
    public var targetReactiveLeg: Double { abs(targetKVAR) / scaleKVA }

    public var realLabel: String { "\(Self.quantity(realPowerKW)) kW" }
    public var existingLabel: String { "\(Self.quantity(existingKVAR)) kVAR" }
    public var targetLabel: String { "\(Self.quantity(targetKVAR)) kVAR" }

    /// Number first, with the unit. Nil when the bank size is not a usable microfarad value.
    public var bankLabel: String? {
        guard let bankMicrofarads, bankMicrofarads.isFinite, bankMicrofarads > 0 else { return nil }
        return "\(Self.quantity(bankMicrofarads)) µF"
    }

    public var bankCaption: String? {
        guard let bankLabel else { return nil }
        return "\(bankLabel) bank"
    }

    /// VoiceOver string. Each clause starts with the number and its unit.
    public var announcement: String {
        var clauses = [
            "\(existingLabel) existing",
            "\(targetLabel) after correction",
            realLabel,
        ]
        if let bankCaption {
            clauses.append(bankCaption)
        }
        return clauses.joined(separator: ", ") + "."
    }

    public static func correction(
        realPowerKW: Double,
        existingKVAR: Double,
        targetKVAR: Double,
        bankMicrofarads: Double?
    ) -> PowerTriangleComparison? {
        guard realPowerKW.isFinite, realPowerKW > 0,
              existingKVAR.isFinite, targetKVAR.isFinite
        else { return nil }
        let scale = max(hypot(realPowerKW, existingKVAR), hypot(realPowerKW, targetKVAR))
        guard scale.isFinite, scale > 0 else { return nil }
        let bank: Double? = (bankMicrofarads?.isFinite == true && (bankMicrofarads ?? 0) > 0) ? bankMicrofarads : nil
        return PowerTriangleComparison(
            realPowerKW: realPowerKW,
            existingKVAR: existingKVAR,
            targetKVAR: targetKVAR,
            scaleKVA: scale,
            bankMicrofarads: bank
        )
    }

    /// kW comes from the committed result, so a stale input field does not stretch the picture.
    public static func correction(from result: PowerFactorResult) -> PowerTriangleComparison? {
        let residual = result.newKVA * result.newKVA - result.targetKVAR * result.targetKVAR
        let kilowatts: Double
        if residual.isFinite, residual > 0 {
            kilowatts = residual.squareRoot()
        } else if result.newKVA.isFinite, result.newKVA > 0 {
            kilowatts = result.newKVA
        } else {
            return nil
        }
        let bank = result.capacitance.isFinite ? result.capacitance * 1e6 : nil
        return correction(
            realPowerKW: kilowatts,
            existingKVAR: result.existingKVAR,
            targetKVAR: result.targetKVAR,
            bankMicrofarads: bank
        )
    }

    private static func quantity(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        var text = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
        if text.contains(".") {
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        return text
    }
}
