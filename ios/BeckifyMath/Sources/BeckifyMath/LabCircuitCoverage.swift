import Foundation

/// How Electronics Lab presents each catalog circuit on the bench.
public enum LabBenchMode: String, Sendable, CaseIterable, Identifiable {
    case breadboard
    case schematic
    case moduleConceptual

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .breadboard: return "Breadboard + schematic"
        case .schematic: return "Schematic bench"
        case .moduleConceptual: return "Module / conceptual"
        }
    }
}

public enum LabCoverageStatus: String, Sendable {
    case ready
    case priority
    case deferred
}

public struct LabCoverageRow: Equatable, Sendable, Identifiable {
    public var circuit: ElectronicsCircuit
    public var mode: LabBenchMode
    public var status: LabCoverageStatus
    public var note: String

    public var id: String { circuit.rawValue }

    public init(circuit: ElectronicsCircuit, mode: LabBenchMode, status: LabCoverageStatus, note: String) {
        self.circuit = circuit
        self.mode = mode
        self.status = status
        self.note = note
    }
}

/// Coverage matrix for all catalog circuits. Breadboard support is the source of truth
/// via `BreadboardLayouts.supports`; this table documents the intended bench mode.
public enum LabCircuitCoverage {
    public static var matrix: [LabCoverageRow] {
        ElectronicsCircuit.allCases.map(row(for:))
    }

    public static func row(for circuit: ElectronicsCircuit) -> LabCoverageRow {
        if BreadboardLayouts.supports(circuit) {
            let priority: Set<ElectronicsCircuit> = [
                .fullBridge, .seriesRLC, .ceAmp, .csAmp, .cmosInverter,
            ]
            return LabCoverageRow(
                circuit: circuit,
                mode: .breadboard,
                status: priority.contains(circuit) ? .priority : .ready,
                note: BreadboardLayouts.disclosure
            )
        }
        switch circuit {
        case .classOverview, .discretePower, .opAmpPower:
            return LabCoverageRow(
                circuit: circuit,
                mode: .moduleConceptual,
                status: .deferred,
                note: "Conceptual amplifier / class overview — schematic and notes; no solderless board."
            )
        case .idealBuck:
            return LabCoverageRow(
                circuit: circuit,
                mode: .moduleConceptual,
                status: .deferred,
                note: "Ideal buck module sketch — schematic only; not a switcher layout."
            )
        case .complexConvert, .impedanceCombo:
            return LabCoverageRow(
                circuit: circuit,
                mode: .moduleConceptual,
                status: .deferred,
                note: "Math / impedance tool — no physical hookup."
            )
        case .lMatch, .quarterWave, .stubCancel:
            return LabCoverageRow(
                circuit: circuit,
                mode: .moduleConceptual,
                status: .deferred,
                note: "Transmission-line / matching module — schematic and formulas; not a breadboard."
            )
        default:
            return LabCoverageRow(
                circuit: circuit,
                mode: .schematic,
                status: .deferred,
                note: "Schematic bench with node/branch readings. Breadboard layout not mapped yet."
            )
        }
    }

    public static func markdownTable() -> String {
        var lines = [
            "| Circuit | Bench mode | Status | Note |",
            "|---|---|---|---|",
        ]
        for row in matrix {
            let title = ElectronicsLab.info(row.circuit).title
            let note = row.note.replacingOccurrences(of: "|", with: "/")
            lines.append("| \(title) (`\(row.circuit.rawValue)`) | \(row.mode.title) | \(row.status.rawValue) | \(note) |")
        }
        return lines.joined(separator: "\n")
    }
}
