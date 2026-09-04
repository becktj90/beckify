import Foundation

/// NEC edition used by transcribed table data in this package.
public enum CodeEdition: String, Codable, CaseIterable, Sendable, Hashable {
    case nec2023 = "NEC 2023"

    public var displayName: String { rawValue }
}

/// How a numeric result should be presented to the engineer.
public enum ResultProvenance: String, Codable, CaseIterable, Sendable, Hashable {
    /// Direct table or article requirement for the stated conditions.
    case codeRequirement
    /// NEC informational note or non-mandatory guidance (e.g. 3%/5% VD).
    case informationalNote
    /// Beckify design preference (spare capacity, preferred drop target).
    case designPreference
    /// Value that depends on a specific manufacturer product.
    case manufacturerDependent
    /// Engineering approximation (e.g. Chapter 9 Table 9 K-factor).
    case engineeringApproximation
    /// Required input was not supplied; no claim is made.
    case missingInformation
}

public enum WarningSeverity: String, Codable, CaseIterable, Sendable, Hashable {
    case info
    case caution
    case critical
}

/// Short citation for a code-derived number. Does not quote copyrighted commentary.
public struct CodeCitation: Equatable, Codable, Sendable, Hashable {
    public var edition: CodeEdition
    public var articleOrTable: String
    public var units: String
    public var sourceDescription: String
    public var lastVerified: String

    public init(
        edition: CodeEdition = .nec2023,
        articleOrTable: String,
        units: String,
        sourceDescription: String,
        lastVerified: String = "2026-09-03"
    ) {
        self.edition = edition
        self.articleOrTable = articleOrTable
        self.units = units
        self.sourceDescription = sourceDescription
        self.lastVerified = lastVerified
    }

    public var shortLabel: String {
        "\(edition.displayName) \(articleOrTable)"
    }
}

/// One stage in an explicit calculation trace (ampacity waterfall, protection path, etc.).
public struct CalculationTraceStep: Equatable, Codable, Sendable, Hashable {
    public var id: String
    public var title: String
    public var value: Double
    public var displayValue: String
    public var factor: Double?
    public var provenance: ResultProvenance
    public var citation: CodeCitation?
    public var note: String?

    public init(
        id: String,
        title: String,
        value: Double,
        displayValue: String,
        factor: Double? = nil,
        provenance: ResultProvenance,
        citation: CodeCitation? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.displayValue = displayValue
        self.factor = factor
        self.provenance = provenance
        self.citation = citation
        self.note = note
    }
}

public struct DesignWarning: Equatable, Codable, Sendable, Hashable {
    public var severity: WarningSeverity
    public var message: String
    public var provenance: ResultProvenance

    public init(severity: WarningSeverity, message: String, provenance: ResultProvenance) {
        self.severity = severity
        self.message = message
        self.provenance = provenance
    }
}

/// Typed seed for Continue-with-this-design handoffs between professional tools.
public struct ConductorDesignSeed: Equatable, Codable, Sendable {
    public var sourceToolID: String
    public var sourceSummary: String
    public var loadAmps: Double
    public var material: ConductorMaterial
    public var size: String
    public var system: ElectricalSystem?
    public var supplyVolts: Double?
    public var oneWayFeet: Double?
    public var parallelRuns: Int
    public var insulationCelsius: Int?
    public var terminationCelsius: Int?

    public init(
        sourceToolID: String,
        sourceSummary: String,
        loadAmps: Double,
        material: ConductorMaterial,
        size: String,
        system: ElectricalSystem? = nil,
        supplyVolts: Double? = nil,
        oneWayFeet: Double? = nil,
        parallelRuns: Int = 1,
        insulationCelsius: Int? = nil,
        terminationCelsius: Int? = nil
    ) {
        self.sourceToolID = sourceToolID
        self.sourceSummary = sourceSummary
        self.loadAmps = loadAmps
        self.material = material
        self.size = size
        self.system = system
        self.supplyVolts = supplyVolts
        self.oneWayFeet = oneWayFeet
        self.parallelRuns = max(1, parallelRuns)
        self.insulationCelsius = insulationCelsius
        self.terminationCelsius = terminationCelsius
    }
}

/// In-memory / UserDefaults bridge key for pending design seeds.
public enum DesignHandoffStore {
    public static let userDefaultsKey = "com.beckify.toolbox.pendingConductorDesignSeed"

    public static func encode(_ seed: ConductorDesignSeed) throws -> Data {
        try JSONEncoder().encode(seed)
    }

    public static func decode(_ data: Data) throws -> ConductorDesignSeed {
        try JSONDecoder().decode(ConductorDesignSeed.self, from: data)
    }
}
