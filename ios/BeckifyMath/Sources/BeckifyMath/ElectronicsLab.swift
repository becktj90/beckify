import Foundation

/// Field electronics bench: ideal topologies, node readings, and solve-any-value.
///
/// DC results are nodal / sequential. AC results are phasors. BJT bias uses a
/// fixed 0.7 V base-emitter drop and constant β. MOSFETs use the square law.
/// Timers use the classic 1/3–2/3 identities. Stubs and matches are lossless
/// lines. This is not a SPICE netlist.
public enum ElectronicsFamily: String, CaseIterable, Sendable, Identifiable {
    case passive
    case transient
    case diode
    case bjt
    case mosfet
    case opamp
    case timer
    case digital
    case amplifier
    case power
    case mathTools

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .passive: return "Passive DC"
        case .transient: return "RC, RL, and RLC"
        case .diode: return "Diodes"
        case .bjt: return "BJT"
        case .mosfet: return "MOSFET"
        case .opamp: return "Op-amps"
        case .timer: return "555 timers"
        case .digital: return "LED and display"
        case .amplifier: return "Amplifiers"
        case .power: return "Power basics"
        case .mathTools: return "Complex and matching"
        }
    }
}

public enum ElectronicsCircuit: String, CaseIterable, Sendable, Identifiable {
    case seriesResistors
    case parallelResistors
    case voltageDivider
    case kirchhoffLoop
    case theveninNorton
    case rcStep
    case rlStep
    case firstOrderFilter
    case seriesRLC
    case halfWave
    case fullBridge
    case shuntClipper
    case clamper
    case ledSeries
    case bjtBias
    case ceAmp
    case bjtSwitch
    case csAmp
    case mosSwitch
    case cmosInverter
    case invertingAmp
    case nonInvertingAmp
    case summingAmp
    case diffAmp
    case integrator
    case differentiator
    case comparator
    case astable555
    case monostable555
    case ledFlasher
    case sevenSegment
    case classOverview
    case discretePower
    case opAmpPower
    case linearDrop
    case idealBuck
    case complexConvert
    case impedanceCombo
    case lMatch
    case quarterWave
    case stubCancel

    public var id: String { rawValue }
}

public struct LabPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum LabPart: String, Sendable, Equatable {
    case wire
    case resistor
    case capacitor
    case inductor
    case voltageSource
    case diode
    case led
    case ground
    case npn
    case nmos
    case pmos
    case opAmp
    case timer555
    case sevenSegment
    case zBlock
    case line
}

public struct LabElement: Equatable, Sendable, Identifiable {
    public var id: String
    public var part: LabPart
    public var label: String
    public var detail: String
    public var a: LabPoint
    public var b: LabPoint
    public var flags: Int

    public init(
        id: String,
        part: LabPart,
        label: String,
        detail: String,
        a: LabPoint,
        b: LabPoint,
        flags: Int = 0
    ) {
        self.id = id
        self.part = part
        self.label = label
        self.detail = detail
        self.a = a
        self.b = b
        self.flags = flags
    }
}

public struct LabNode: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var value: Double
    public var unit: String
    public var at: LabPoint

    public init(id: String, name: String, value: Double, unit: String, at: LabPoint) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
        self.at = at
    }
}

public struct LabBranch: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var value: Double
    public var unit: String
    public var a: LabPoint
    public var b: LabPoint

    public init(id: String, name: String, value: Double, unit: String, a: LabPoint, b: LabPoint) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
        self.a = a
        self.b = b
    }
}

public struct LabQuantity: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var value: Double
    public var unit: String
    public var emphasis: Bool

    public init(id: String, name: String, value: Double, unit: String, emphasis: Bool = false) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
        self.emphasis = emphasis
    }
}

public struct LabChoice: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public struct LabField: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var unit: String
    public var help: String
    public var choices: [LabChoice]
    public var optional: Bool
    /// `"ac"` or `"dc"` when this field belongs to one source kind. Nil stays visible either way.
    public var sourceMode: String?

    public init(
        id: String,
        title: String,
        unit: String,
        help: String = "",
        choices: [LabChoice] = [],
        optional: Bool = false,
        sourceMode: String? = nil
    ) {
        self.id = id
        self.title = title
        self.unit = unit
        self.help = help
        self.choices = choices
        self.optional = optional
        self.sourceMode = sourceMode
    }
}

public struct LabUnknown: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public struct LabSolution: Equatable, Sendable {
    public var circuit: ElectronicsCircuit
    public var headline: String
    public var elements: [LabElement]
    public var nodes: [LabNode]
    public var branches: [LabBranch]
    public var quantities: [LabQuantity]
    public var steps: [String]
    public var notes: [String]
    public var warning: String?
    public var io: LabIO

    public init(
        circuit: ElectronicsCircuit,
        headline: String,
        elements: [LabElement],
        nodes: [LabNode],
        branches: [LabBranch],
        quantities: [LabQuantity],
        steps: [String],
        notes: [String],
        warning: String? = nil,
        io: LabIO = .empty
    ) {
        self.circuit = circuit
        self.headline = headline
        self.elements = elements
        self.nodes = nodes
        self.branches = branches
        self.quantities = quantities
        self.steps = steps
        self.notes = notes
        self.warning = warning
        self.io = io
    }

    public func quantity(_ id: String) -> Double? {
        quantities.first { $0.id == id }?.value
    }

    public func node(_ id: String) -> LabNode? {
        nodes.first { $0.id == id }
    }

    public func branch(_ id: String) -> LabBranch? {
        branches.first { $0.id == id }
    }
}

public struct ElectronicsCircuitInfo: Equatable, Sendable, Identifiable {
    public var id: ElectronicsCircuit
    public var family: ElectronicsFamily
    public var title: String
    public var blurb: String
    public var unknowns: [LabUnknown]
    public var defaultUnknown: String
    public var defaults: [String: String]

    public init(
        id: ElectronicsCircuit,
        family: ElectronicsFamily,
        title: String,
        blurb: String,
        unknowns: [LabUnknown],
        defaultUnknown: String,
        defaults: [String: String]
    ) {
        self.id = id
        self.family = family
        self.title = title
        self.blurb = blurb
        self.unknowns = unknowns
        self.defaultUnknown = defaultUnknown
        self.defaults = defaults
    }
}

public enum LabCanvas {
    public static let width: Double = 100
    public static let height: Double = 80
}

/// Spoken source kind and the schematic mark. `acSineFlag` on a voltage source draws a sine, not a DC plus.
public enum LabSourceSpeech {
    public static let acSineFlag = 1

    public static func kind(ac: Bool) -> String {
        ac ? "AC sine" : "DC"
    }

    /// One sentence per source symbol. VoiceOver uses this so VAC and VDC are not the same word.
    public static func schematicSummary(_ elements: [LabElement]) -> String {
        let sources = elements.filter { $0.part == .voltageSource }
        guard !sources.isEmpty else { return "" }
        return sources.map { element in
            let kind = kind(ac: element.flags & acSineFlag != 0)
            let marked = [element.label, element.detail].filter { !$0.isEmpty }.joined(separator: " ")
            return marked.isEmpty ? "\(kind) source" : "\(kind) source, \(marked)"
        }.joined(separator: ". ")
    }

    /// The other amplitude, so a Vrms field also speaks peak and a Vp field also speaks RMS.
    public static func pairedAmplitude(id: String, raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = NumericParse.parseEngineering(trimmed, locale: Locale(identifier: "en_US_POSIX"))
            ?? NumericParse.parseEngineering(trimmed),
            value.isFinite, value > 0
        else { return nil }
        switch id {
        case "vrms":
            let peak = value * sqrt(2)
            return "Peak \(LabKit.eng(peak)) volts, from \(LabKit.eng(value)) volts RMS"
        case "vp":
            let rms = value / sqrt(2)
            return "RMS \(LabKit.eng(rms)) volts, from \(LabKit.eng(value)) volts peak"
        default:
            return nil
        }
    }
}

public enum ElectronicsLab {
    public static var catalog: [ElectronicsCircuitInfo] { LabCatalog.infos }

    public static func info(_ circuit: ElectronicsCircuit) -> ElectronicsCircuitInfo {
        LabCatalog.info(circuit)
    }

    public static func circuits(in family: ElectronicsFamily) -> [ElectronicsCircuitInfo] {
        catalog.filter { $0.family == family }
    }

    public static func fields(
        for circuit: ElectronicsCircuit,
        unknown: String,
        inputs: [String: String] = [:]
    ) -> [LabField] {
        LabCatalog.fields(for: circuit, unknown: unknown, inputs: inputs)
    }

    public static func solve(
        _ circuit: ElectronicsCircuit,
        unknown: String,
        inputs: [String: String]
    ) throws -> LabSolution {
        try LabSolve.run(circuit, unknown: unknown, inputs: inputs)
    }
}
