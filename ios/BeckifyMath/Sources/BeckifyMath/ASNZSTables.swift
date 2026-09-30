import Foundation

/// AS/NZS design-aid data that this package can cite without pretending to be AS/NZS 3008.
///
/// Current-carrying capacity (AS/NZS 3008.1) and mV/A·m voltage-drop tables are not
/// transcribed. Earthing sizes are the Table 5.1 minimums. Conductor resistance is
/// the IEC 60228 Class 2 maximum at 20 °C, then temperature-corrected. That is a
/// conservative resistance-only drop, not a wiring-rules stamp.
public enum ASNZSTables {
    public static let installationDropLimitPercent = 5.0

    public static let voltageDropCitation = CodeCitation(
        edition: .asnzs3000,
        articleOrTable: "Clause 3.6.2",
        units: "%",
        sourceDescription: "Voltage drop from the point of supply to any point in the installation shall not exceed 5% of the nominal voltage. A single run is only the length you entered. Design aid — not a PE or AEE stamp.",
        lastVerified: "2026-09-30"
    )

    public static let resistanceCitation = CodeCitation(
        edition: .iec60228,
        articleOrTable: "Class 2 maximum DC resistance at 20 °C",
        units: "Ω/km",
        sourceDescription: "Plain annealed copper or aluminium, Class 2 stranded, maximum resistance at 20 °C. Corrected with α 0.00393 /°C (Cu) or 0.00403 /°C (Al). Reactance is omitted. Not an AS/NZS 3008 mV/A·m table.",
        lastVerified: "2026-09-30"
    )

    public static let earthingCitation = CodeCitation(
        edition: .asnzs3000,
        articleOrTable: "Table 5.1",
        units: "mm²",
        sourceDescription: "Minimum copper earthing conductor from the active conductor size (Clause 5.3.3.1.2). A separate earth smaller than 2.5 mm² is raised to 2.5 mm² (Clause 5.3.3.4); 1 mm² and 1.5 mm² apply to multicore cable and flexible cord. Fault current and loop impedance (5.3.3.1.1 / 5.3.3.1.3) are not calculated. Not a PE or AEE stamp.",
        lastVerified: "2026-09-30"
    )

    /// Copper earthing conductor. `withAluminiumActive` is nil when that column does not apply.
    /// Sizes at 400 mm² and above are table minimums (the standard prints ≥).
    public static let table5_1: [(activeMM2: Double, copperActiveEarth: Double, aluminiumActiveEarth: Double?, minimumNotExact: Bool)] = [
        (1, 1, nil, false),
        (1.5, 1.5, nil, false),
        (2.5, 2.5, nil, false),
        (4, 2.5, nil, false),
        (6, 2.5, nil, false),
        (10, 4, nil, false),
        (16, 6, 4, false),
        (25, 6, 6, false),
        (35, 10, 6, false),
        (50, 16, 10, false),
        (70, 25, 10, false),
        (95, 25, 16, false),
        (120, 35, 25, false),
        (150, 50, 25, false),
        (185, 70, 35, false),
        (240, 95, 50, false),
        (300, 120, 70, false),
        (400, 120, 95, true),
        (500, 120, 95, true),
        (630, 120, 120, true),
    ]

    /// IEC 60228 Class 2 maximum DC resistance at 20 °C, Ω/km.
    public static let resistanceOhmPerKmAt20C: [(mm2: Double, copper: Double, aluminium: Double?)] = [
        (1, 18.1, nil),
        (1.5, 12.1, nil),
        (2.5, 7.41, nil),
        (4, 4.61, nil),
        (6, 3.08, nil),
        (10, 1.83, nil),
        (16, 1.15, 1.91),
        (25, 0.727, 1.20),
        (35, 0.524, 0.868),
        (50, 0.387, 0.641),
        (70, 0.268, 0.443),
        (95, 0.193, 0.320),
        (120, 0.153, 0.253),
        (150, 0.124, 0.206),
        (185, 0.0991, 0.164),
        (240, 0.0754, 0.125),
        (300, 0.0601, 0.100),
        (400, 0.0470, 0.0778),
        (500, 0.0366, 0.0605),
        (630, 0.0283, 0.0469),
    ]

    public static func matches(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.051
    }

    public static func token(for mm2: Double) -> String {
        if abs(mm2 - mm2.rounded()) < 0.01 {
            return "\(Int(mm2.rounded()))"
        }
        return String(format: "%.1f", mm2)
    }

    public static func label(for mm2: Double) -> String {
        "\(token(for: mm2)) mm²"
    }

    public static func materialName(_ material: ConductorMaterial) -> String {
        material == .copper ? "Copper" : "Aluminium"
    }

    public static func tokens(for material: ConductorMaterial) -> [String] {
        resistanceOhmPerKmAt20C.compactMap { row in
            switch material {
            case .copper: return token(for: row.mm2)
            case .aluminum: return row.aluminium == nil ? nil : token(for: row.mm2)
            }
        }
    }

    public static func mm2(from token: String) -> Double? {
        guard let value = Double(token), value > 0 else { return nil }
        guard resistanceOhmPerKmAt20C.contains(where: { matches($0.mm2, value) }) else { return nil }
        return resistanceOhmPerKmAt20C.first(where: { matches($0.mm2, value) })?.mm2
    }

    public static func alpha(for material: ConductorMaterial) -> Double {
        material == .copper ? 0.00393 : 0.00403
    }

    public static func resistanceOhmPerKm(sizeMM2: Double, material: ConductorMaterial, temperatureC: Double) -> Double? {
        guard let row = resistanceOhmPerKmAt20C.first(where: { matches($0.mm2, sizeMM2) }) else { return nil }
        let r20: Double
        switch material {
        case .copper: r20 = row.copper
        case .aluminum:
            guard let aluminium = row.aluminium else { return nil }
            r20 = aluminium
        }
        return r20 * (1 + alpha(for: material) * (temperatureC - 20))
    }
}

public struct ASNZSEarthingRecommendation: Equatable, Sendable {
    public var activeMM2: Double
    public var activeLabel: String
    public var activeMaterial: ConductorMaterial
    /// Table 5.1 copper earth before the separate-conductor floor.
    public var tableCopperMM2: Double
    /// Size to install as a separate earthing conductor (at least 2.5 mm²).
    public var separateCopperMM2: Double
    public var isTableMinimum: Bool
    public var citation: CodeCitation
    public var notes: [String]

    public var copyLine: String {
        "Earth \(ASNZSTables.token(for: separateCopperMM2)) mm² Cu · Table 5.1 · active \(activeLabel) \(ASNZSTables.materialName(activeMaterial))"
    }
}

public enum ASNZSEarthing {
    /// `nil` when the active size is not a Table 5.1 row, or aluminium has no column.
    public static func recommend(activeMM2: Double, activeMaterial: ConductorMaterial) -> ASNZSEarthingRecommendation? {
        guard let row = ASNZSTables.table5_1.first(where: { ASNZSTables.matches($0.activeMM2, activeMM2) }) else {
            return nil
        }
        let table: Double
        switch activeMaterial {
        case .copper:
            table = row.copperActiveEarth
        case .aluminum:
            guard let aluminium = row.aluminiumActiveEarth else { return nil }
            table = aluminium
        }

        var notes = [
            "AS/NZS 3000:2018 Table 5.1 is a minimum copper earthing conductor for the active size (Clause 5.3.3.1.2). Design aid — not a PE or AEE stamp.",
            "Clause 5.3.3.1.3 adiabatic sizing and earth-fault-loop impedance are not calculated. A larger earth may be required.",
        ]
        if row.minimumNotExact {
            notes.append("This active size is in the ≥ band of Table 5.1. \(ASNZSTables.token(for: table)) mm² is the printed minimum, not a proof that it is enough.")
        }
        let separate = max(table, 2.5)
        if separate > table + 1e-9 {
            notes.append("Clause 5.3.3.4: a separate single-core earthing conductor is at least 2.5 mm². \(ASNZSTables.token(for: table)) mm² is only for an earth core in a multicore cable or flexible cord.")
        } else {
            notes.append("A separate earthing conductor is shown at the table size, which is already at least 2.5 mm².")
        }

        return ASNZSEarthingRecommendation(
            activeMM2: row.activeMM2,
            activeLabel: ASNZSTables.label(for: row.activeMM2),
            activeMaterial: activeMaterial,
            tableCopperMM2: table,
            separateCopperMM2: separate,
            isTableMinimum: row.minimumNotExact,
            citation: ASNZSTables.earthingCitation,
            notes: notes
        )
    }
}

public struct ASNZSVoltageDropInput: Equatable, Sendable {
    public var system: ElectricalSystem
    public var supplyVolts: Double
    public var current: Double
    public var oneWayMetres: Double
    public var sizeMM2: Double
    public var material: ConductorMaterial
    public var parallelRuns: Int
    public var targetDropPercent: Double
    public var conductorTemperatureC: Double

    public init(
        system: ElectricalSystem,
        supplyVolts: Double,
        current: Double,
        oneWayMetres: Double,
        sizeMM2: Double,
        material: ConductorMaterial,
        parallelRuns: Int = 1,
        targetDropPercent: Double = 5,
        conductorTemperatureC: Double = 75
    ) {
        self.system = system
        self.supplyVolts = supplyVolts
        self.current = current
        self.oneWayMetres = oneWayMetres
        self.sizeMM2 = sizeMM2
        self.material = material
        self.parallelRuns = parallelRuns
        self.targetDropPercent = targetDropPercent
        self.conductorTemperatureC = conductorTemperatureC
    }
}

public struct ASNZSVoltageDropCandidate: Equatable, Sendable {
    public var sizeMM2: Double
    public var token: String
    public var label: String
    public var dropVolts: Double
    public var dropPercent: Double
    public var receivingVolts: Double
    public var meetsTarget: Bool
    public var meetsInstallationLimit: Bool
}

public struct ASNZSVoltageDropResult: Equatable, Sendable {
    public var system: ElectricalSystem
    public var material: ConductorMaterial
    public var sizeMM2: Double
    public var token: String
    public var label: String
    public var parallelRuns: Int
    public var conductorTemperatureC: Double
    public var resistanceOhmPerKm: Double

    public var dropVolts: Double
    public var dropPercent: Double
    public var receivingVolts: Double
    public var supplyVolts: Double
    public var loadAmps: Double
    public var oneWayMetres: Double

    public var meetsInstallationLimit: Bool
    public var meetsTarget: Bool
    public var targetDropPercent: Double
    public var recommendedMM2: Double?
    public var recommendedLabel: String?

    public var earth: ASNZSEarthingRecommendation?
    public var recommendedEarth: ASNZSEarthingRecommendation?
    public var conductorLossWatts: Double?
    public var candidates: [ASNZSVoltageDropCandidate]
    public var warnings: [DesignWarning]
    public var citations: [CodeCitation]
    public var formula: String
}

public enum ASNZSVoltageDrop {
    public static func calculate(_ input: ASNZSVoltageDropInput) throws -> ASNZSVoltageDropResult {
        let current = try Positive.require(input.current, name: "Current")
        let length = try Positive.require(input.oneWayMetres, name: "One-way length")
        let volts = try Positive.require(input.supplyVolts, name: "Supply voltage")
        let target = try Positive.require(input.targetDropPercent, name: "Target voltage drop")
        let runs = try WholeCount.parse(Double(max(input.parallelRuns, 1)), name: "Parallel runs")
        let temperature = input.conductorTemperatureC
        guard temperature.isFinite, temperature >= 0, temperature <= 250 else {
            throw CalcError.outOfRange("Conductor temperature must be between 0 °C and 250 °C.")
        }
        guard ASNZSTables.resistanceOhmPerKm(sizeMM2: input.sizeMM2, material: input.material, temperatureC: temperature) != nil else {
            if input.material == .aluminum, input.sizeMM2 + 0.05 < 16 {
                throw CalcError.notListed("Aluminium sizes in this table start at 16 mm². \(ASNZSTables.token(for: input.sizeMM2)) mm² aluminium is not listed.")
            }
            throw CalcError.notListed("Unknown conductor size \(ASNZSTables.token(for: input.sizeMM2)) mm².")
        }

        let selected = try candidate(
            system: input.system,
            current: current,
            oneWayMetres: length,
            supplyVolts: volts,
            sizeMM2: input.sizeMM2,
            material: input.material,
            parallelRuns: runs,
            targetDropPercent: target,
            temperatureC: temperature
        )

        var recommended: Double?
        var candidates: [ASNZSVoltageDropCandidate] = []
        for row in ASNZSTables.resistanceOhmPerKmAt20C {
            guard ASNZSTables.resistanceOhmPerKm(sizeMM2: row.mm2, material: input.material, temperatureC: temperature) != nil else { continue }
            let item = try candidate(
                system: input.system,
                current: current,
                oneWayMetres: length,
                supplyVolts: volts,
                sizeMM2: row.mm2,
                material: input.material,
                parallelRuns: runs,
                targetDropPercent: target,
                temperatureC: temperature
            )
            candidates.append(item)
            if recommended == nil, item.meetsTarget {
                recommended = row.mm2
            }
        }

        let rPerKm = try requiredResistance(sizeMM2: input.sizeMM2, material: input.material, temperatureC: temperature)
        var warnings: [DesignWarning] = [
            DesignWarning(
                severity: .info,
                message: "Resistance-only drop at power factor 1. Reactance is omitted, so this is not an AS/NZS 3008 mV/A·m value.",
                provenance: .engineeringApproximation
            ),
            DesignWarning(
                severity: .info,
                message: "AS/NZS 3000:2018 Clause 3.6.2 limits installation drop to 5% from the point of supply. This result is only the length you entered.",
                provenance: .codeRequirement
            ),
            DesignWarning(
                severity: .caution,
                message: "Current-carrying capacity is not checked. AS/NZS 3008 installation methods are not in this tool.",
                provenance: .missingInformation
            ),
        ]
        if !selected.meetsInstallationLimit {
            warnings.append(DesignWarning(
                severity: .critical,
                message: "Drop \(FormatTrace.percent(selected.dropPercent)) is over the 5% installation limit in Clause 3.6.2 for this length alone.",
                provenance: .codeRequirement
            ))
        }
        if !selected.meetsTarget {
            warnings.append(DesignWarning(
                severity: .caution,
                message: "Drop \(FormatTrace.percent(selected.dropPercent)) exceeds the preferred target \(FormatTrace.percent(target)).",
                provenance: .designPreference
            ))
        }
        if runs > 1 {
            warnings.append(DesignWarning(
                severity: .info,
                message: "Parallel runs split current in this estimate. AS/NZS rules for paralleling cables are not applied.",
                provenance: .engineeringApproximation
            ))
        }

        let formula = input.system == .threePhase
            ? "Vd = √3 × I × L × R    [R at \(FormatTrace.number(temperature, digits: 0)) °C, X = 0, PF = 1]"
            : "Vd = 2 × I × L × R    [R at \(FormatTrace.number(temperature, digits: 0)) °C, X = 0, PF = 1]"

        let earth = ASNZSEarthing.recommend(activeMM2: input.sizeMM2, activeMaterial: input.material)
        let recommendedEarth = recommended.flatMap { ASNZSEarthing.recommend(activeMM2: $0, activeMaterial: input.material) }

        return ASNZSVoltageDropResult(
            system: input.system,
            material: input.material,
            sizeMM2: selected.sizeMM2,
            token: selected.token,
            label: selected.label,
            parallelRuns: runs,
            conductorTemperatureC: temperature,
            resistanceOhmPerKm: rPerKm,
            dropVolts: selected.dropVolts,
            dropPercent: selected.dropPercent,
            receivingVolts: selected.receivingVolts,
            supplyVolts: volts,
            loadAmps: current,
            oneWayMetres: length,
            meetsInstallationLimit: selected.meetsInstallationLimit,
            meetsTarget: selected.meetsTarget,
            targetDropPercent: target,
            recommendedMM2: recommended,
            recommendedLabel: recommended.map(ASNZSTables.label(for:)),
            earth: earth,
            recommendedEarth: recommendedEarth,
            conductorLossWatts: lossWatts(
                system: input.system,
                current: current,
                oneWayMetres: length,
                resistanceOhmPerKm: rPerKm,
                parallelRuns: runs
            ),
            candidates: candidates,
            warnings: warnings,
            citations: [ASNZSTables.voltageDropCitation, ASNZSTables.resistanceCitation, ASNZSTables.earthingCitation],
            formula: formula
        )
    }

    private static func requiredResistance(sizeMM2: Double, material: ConductorMaterial, temperatureC: Double) throws -> Double {
        guard let r = ASNZSTables.resistanceOhmPerKm(sizeMM2: sizeMM2, material: material, temperatureC: temperatureC) else {
            throw CalcError.notListed("Unknown conductor size \(ASNZSTables.token(for: sizeMM2)) mm².")
        }
        guard r > 0 else {
            throw CalcError.outOfRange("Conductor resistance corrected to a non-positive value. Check the temperature.")
        }
        return r
    }

    private static func candidate(
        system: ElectricalSystem,
        current: Double,
        oneWayMetres: Double,
        supplyVolts: Double,
        sizeMM2: Double,
        material: ConductorMaterial,
        parallelRuns: Int,
        targetDropPercent: Double,
        temperatureC: Double
    ) throws -> ASNZSVoltageDropCandidate {
        let rPerKm = try requiredResistance(sizeMM2: sizeMM2, material: material, temperatureC: temperatureC)
        let rPerM = rPerKm / 1000
        let vd = system.voltageDropMultiplier * current * oneWayMetres * rPerM / Double(parallelRuns)
        let pct = vd / supplyVolts * 100
        return ASNZSVoltageDropCandidate(
            sizeMM2: sizeMM2,
            token: ASNZSTables.token(for: sizeMM2),
            label: ASNZSTables.label(for: sizeMM2),
            dropVolts: vd,
            dropPercent: pct,
            receivingVolts: supplyVolts - vd,
            meetsTarget: pct <= targetDropPercent + 1e-9,
            meetsInstallationLimit: pct <= ASNZSTables.installationDropLimitPercent + 1e-9
        )
    }

    /// I²R in the current-carrying conductors only. Earth loss is not included.
    private static func lossWatts(
        system: ElectricalSystem,
        current: Double,
        oneWayMetres: Double,
        resistanceOhmPerKm: Double,
        parallelRuns: Int
    ) -> Double {
        let conductors = system == .threePhase ? 3.0 : 2.0
        let rPerM = resistanceOhmPerKm / 1000
        return conductors * current * current * rPerM * oneWayMetres / Double(parallelRuns)
    }
}
