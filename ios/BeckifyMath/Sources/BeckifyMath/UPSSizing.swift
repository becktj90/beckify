import Foundation

public struct UPSSizingResult: Equatable, Sendable {
    public var loadKW: Double
    public var powerFactor: Double
    public var runtimeMinutes: Double
    public var efficiency: Double
    public var dcBusVolts: Double
    public var loadKVA: Double
    public var designKVA: Double
    public var batteryWattHours: Double
    public var batteryAmpHours: Double
    public var recommendedKVA: Double
    public var formula: String
}

/// Quick UPS / battery estimate. Design kVA uses 1.25 headroom (design preference),
/// not a manufacturer-specific sizing letter.
public enum UPSSizing {
    public static let standardKVA: [Double] = [
        0.5, 1, 1.5, 2, 3, 5, 6, 7.5, 10, 15, 20, 25, 30, 40, 50, 60, 75,
        100, 125, 150, 200, 250, 300, 400, 500,
    ]

    public static func size(
        loadKW: Double,
        powerFactor: Double,
        runtimeMinutes: Double,
        efficiency: Double,
        dcBusVolts: Double
    ) throws -> UPSSizingResult {
        let kw = try Positive.require(loadKW, name: "Load")
        let pf = try Positive.require(powerFactor, name: "Power factor")
        let minutes = try Positive.require(runtimeMinutes, name: "Runtime")
        let eff = try Positive.require(efficiency, name: "Efficiency")
        let dcV = try Positive.require(dcBusVolts, name: "DC bus voltage")

        guard pf <= 1 else {
            throw CalcError.outOfRange("Power factor must be between 0 and 1 (enter 0.90 for 90%).")
        }
        guard eff <= 1 else {
            throw CalcError.outOfRange("Efficiency must be between 0 and 1 (enter 0.92 for 92%).")
        }

        let loadKVA = kw / pf
        let designKVA = loadKVA * 1.25
        let runtimeH = minutes / 60
        let battWh = (kw * 1000 / eff) * runtimeH
        let battAh = battWh / dcV
        let recommended = nextStandardKVA(designKVA)

        return UPSSizingResult(
            loadKW: kw,
            powerFactor: pf,
            runtimeMinutes: minutes,
            efficiency: eff,
            dcBusVolts: dcV,
            loadKVA: loadKVA,
            designKVA: designKVA,
            batteryWattHours: battWh,
            batteryAmpHours: battAh,
            recommendedKVA: recommended,
            formula: "kVA = kW / PF    design = 1.25 × kVA    Wh = (kW·1000 / η) × h    Ah = Wh / V_dc"
        )
    }

    public static func nextStandardKVA(_ designKVA: Double) -> Double {
        if let match = standardKVA.first(where: { $0 + 1e-9 >= designKVA }) {
            return match
        }
        return (designKVA / 50).rounded(.up) * 50
    }
}
