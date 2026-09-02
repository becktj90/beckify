import Foundation

public struct AmpacityRow: Equatable, Sendable {
    public var size: String
    public var label: String
    public var copper75C: Int?
    public var aluminum75C: Int?

    public init(size: String, label: String, copper75C: Int?, aluminum75C: Int?) {
        self.size = size
        self.label = label
        self.copper75C = copper75C
        self.aluminum75C = aluminum75C
    }
}

public struct WireSizeResult: Equatable, Sendable {
    public var loadAmps: Double
    public var material: ConductorMaterial
    public var size: String
    public var label: String
    public var ampacity: Int
    public var formula: String

    public init(loadAmps: Double, material: ConductorMaterial, size: String, label: String, ampacity: Int, formula: String) {
        self.loadAmps = loadAmps
        self.material = material
        self.size = size
        self.label = label
        self.ampacity = ampacity
        self.formula = formula
    }
}

/// NEC Table 310.16, 75 °C column, ≤3 current-carrying conductors, 30 °C ambient.
public enum WireAmpacity {
    public static var table310_16_75C: [AmpacityRow] {
        NECTables.wireSizeOrder.map { size in
            AmpacityRow(
                size: size,
                label: NECTables.wireLabel(size),
                copper75C: NECTables.ampacity75C(size: size, material: .copper),
                aluminum75C: NECTables.ampacity75C(size: size, material: .aluminum)
            )
        }
    }

    public static func smallestConductor(loadAmps: Double, material: ConductorMaterial) throws -> WireSizeResult {
        let amps = try Positive.require(loadAmps, name: "Load current")
        for size in NECTables.wireSizeOrder {
            if let rating = NECTables.ampacity75C(size: size, material: material), Double(rating) >= amps {
                return WireSizeResult(
                    loadAmps: amps,
                    material: material,
                    size: size,
                    label: NECTables.wireLabel(size),
                    ampacity: rating,
                    formula: "NEC Table 310.16, 75 °C column, ≤3 CCC, 30 °C ambient"
                )
            }
        }
        throw CalcError.notListed("Load \(amps) A exceeds 1000 kcmil \(material.displayName) at 75 °C. Consider parallel runs.")
    }
}
