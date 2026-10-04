import Foundation

// MARK: - Heater element material and helical coil

/// Resistance-wire alloy for the Heater Design Wizard. Resistivity is in Ω·mm²/m (= µΩ·m),
/// a typical 20 °C value. Confirm the alloy and any temperature coefficient with the supplier.
public struct HeaterMaterial: Equatable, Sendable, Identifiable {
    public var id: String
    public var label: String
    public var resistivity: Double
    /// Typical maximum element temperature in air, when the alloy has a well-known one.
    public var maxElementTempC: Double?
    public var note: String

    public init(id: String, label: String, resistivity: Double, maxElementTempC: Double? = nil, note: String) {
        self.id = id
        self.label = label
        self.resistivity = resistivity
        self.maxElementTempC = maxElementTempC
        self.note = note
    }
}

public enum HeaterMaterials {
    public static let customID = "custom"

    public static let all: [HeaterMaterial] = [
        HeaterMaterial(id: "nichrome80", label: "Nichrome 80 (80Ni / 20Cr)", resistivity: 1.09, maxElementTempC: 1200,
                       note: "Common heater wire. Good oxidation resistance."),
        HeaterMaterial(id: "nichrome60", label: "Nichrome 60 (60Ni / 16Cr)", resistivity: 1.12, maxElementTempC: 1150,
                       note: "Slightly higher resistivity and lower temperature rating than Nichrome 80."),
        HeaterMaterial(id: "kanthalA1", label: "Kanthal A-1 (FeCrAl)", resistivity: 1.45, maxElementTempC: 1400,
                       note: "Highest temperature rating here. Brittle after heating."),
        HeaterMaterial(id: "kanthalD", label: "Kanthal D (FeCrAl)", resistivity: 1.35, maxElementTempC: 1300,
                       note: "Iron-chrome-aluminium, a little lower resistivity than A-1."),
        HeaterMaterial(id: "constantan", label: "Constantan (Cu-Ni)", resistivity: 0.49,
                       note: "Low resistivity and stable. For low-temperature elements, not red-hot heaters."),
        HeaterMaterial(id: customID, label: "Custom", resistivity: 1.10,
                       note: "Type the resistivity from your supplier's data sheet."),
    ]

    public static func material(id: String) -> HeaterMaterial? {
        all.first { $0.id == id }
    }

    /// The listed alloy whose resistivity matches, or Custom.
    public static func material(matching resistivity: Double?) -> HeaterMaterial {
        if let resistivity, resistivity.isFinite {
            for item in all where item.id != customID && abs(item.resistivity - resistivity) < 1e-9 {
                return item
            }
        }
        return all[all.count - 1]
    }
}

/// Helical element shape. Wire length comes from the heater solver. The caller picks the wire
/// diameter, the mean coil diameter, and the gap between turns.
public struct HeaterCoilGeometry: Equatable, Sendable {
    public var wireDiameterMM: Double
    public var meanDiameterMM: Double
    public var gapMM: Double
    /// Axial distance from one turn to the next (wire diameter + gap).
    public var pitchMM: Double
    public var innerDiameterMM: Double
    public var outerDiameterMM: Double
    /// Wire in one full turn along the helix.
    public var wirePerTurnMM: Double
    public var turns: Double
    /// Axial length of the finished coil, first turn to last.
    public var coilLengthMM: Double
    public var wireLengthMM: Double
    /// Pitch divided by wire diameter. 1 is close-wound.
    public var pitchRatio: Double
}

public enum HeaterCoil {
    public static func design(
        wireLengthMeters: Double,
        wireDiameterMM: Double,
        meanDiameterMM: Double,
        gapMM: Double
    ) throws -> HeaterCoilGeometry {
        let length = try Positive.require(wireLengthMeters, name: "Wire length") * 1000
        let wire = try Positive.require(wireDiameterMM, name: "Wire diameter")
        let mean = try Positive.require(meanDiameterMM, name: "Coil diameter")
        guard gapMM.isFinite, gapMM >= 0 else {
            throw CalcError.outOfRange("Gap between turns cannot be negative.")
        }
        guard mean > wire else {
            throw CalcError.outOfRange("Coil diameter must be larger than the wire diameter.")
        }
        let pitch = wire + gapMM
        let perTurn = (Double.pi * mean * Double.pi * mean + pitch * pitch).squareRoot()
        let turns = length / perTurn
        guard turns >= 1 else {
            throw CalcError.outOfRange("This wire is too short for one turn at that coil diameter. Use a smaller coil diameter.")
        }
        return HeaterCoilGeometry(
            wireDiameterMM: wire,
            meanDiameterMM: mean,
            gapMM: gapMM,
            pitchMM: pitch,
            innerDiameterMM: mean - wire,
            outerDiameterMM: mean + wire,
            wirePerTurnMM: perTurn,
            turns: turns,
            coilLengthMM: (turns - 1) * pitch + wire,
            wireLengthMM: length,
            pitchRatio: pitch / wire
        )
    }
}

// MARK: - Chain and sprocket geometry

public struct SprocketChain: Equatable, Sendable, Identifiable {
    public var id: String
    public var label: String
    public var pitchMM: Double

    public init(id: String, label: String, pitchMM: Double) {
        self.id = id
        self.label = label
        self.pitchMM = pitchMM
    }
}

public enum SprocketChains {
    public static let all: [SprocketChain] = [
        SprocketChain(id: "25", label: "#25 (¼″ pitch)", pitchMM: 6.35),
        SprocketChain(id: "35", label: "#35 (⅜″ pitch)", pitchMM: 9.525),
        SprocketChain(id: "410", label: "Bicycle ½″ pitch", pitchMM: 12.7),
        SprocketChain(id: "420", label: "#420 (½″ pitch)", pitchMM: 12.7),
        SprocketChain(id: "428", label: "#428 (½″ pitch)", pitchMM: 12.7),
        SprocketChain(id: "520", label: "#520 (⅝″ pitch)", pitchMM: 15.875),
    ]

    public static func chain(id: String) -> SprocketChain {
        all.first { $0.id == id } ?? all[2]
    }
}

public struct SprocketSetup: Equatable, Sendable {
    public var chain: SprocketChain
    public var driveTeeth: Int
    public var drivenTeeth: Int
    public var drivePitchDiameterMM: Double
    public var drivenPitchDiameterMM: Double
    public var driveOutsideDiameterMM: Double
    public var drivenOutsideDiameterMM: Double
    public var centerDistanceMM: Double
    public var chainLinks: Int
    public var chainLengthMM: Double
    /// Degrees of chain wrapped around the smaller sprocket.
    public var smallWrapDegrees: Double
    public var ratio: Double
}

public enum SprocketGeometry {
    public static let minimumTeeth = 6
    public static let maximumTeeth = 200

    /// Pitch circle diameter: p / sin(180° / N).
    public static func pitchDiameterMM(teeth: Int, pitchMM: Double) -> Double {
        pitchMM / sin(Double.pi / Double(teeth))
    }

    /// Outside diameter, the usual approximation p · (0.6 + cot(180° / N)).
    public static func outsideDiameterMM(teeth: Int, pitchMM: Double) -> Double {
        pitchMM * (0.6 + 1 / tan(Double.pi / Double(teeth)))
    }

    /// Smallest even link count for a center distance, using the standard chain-length formula.
    public static func chainLinks(driveTeeth: Int, drivenTeeth: Int, centerDistanceMM: Double, pitchMM: Double) -> Int {
        let n1 = Double(driveTeeth)
        let n2 = Double(drivenTeeth)
        let c = centerDistanceMM / pitchMM
        let diff = (n2 - n1) / (2 * Double.pi)
        let exact = 2 * c + (n1 + n2) / 2 + diff * diff / c
        var links = Int(exact.rounded(.up))
        if links % 2 != 0 { links += 1 }
        return links
    }

    /// Center distance for a whole, even link count.
    public static func centerDistanceMM(links: Int, driveTeeth: Int, drivenTeeth: Int, pitchMM: Double) -> Double {
        let n1 = Double(driveTeeth)
        let n2 = Double(drivenTeeth)
        let a = Double(links) - (n1 + n2) / 2
        let diff = (n2 - n1) / (2 * Double.pi)
        let inside = max(a * a - 8 * diff * diff, 0)
        return pitchMM / 4 * (a + inside.squareRoot())
    }

    /// Nil when a tooth count is outside 6…200, where the drawing and formulas stop making sense.
    public static func setup(
        driveTeeth: Double,
        drivenTeeth: Double,
        chain: SprocketChain,
        centerDistanceMM requestedCenter: Double? = nil
    ) -> SprocketSetup? {
        guard driveTeeth.isFinite, drivenTeeth.isFinite else { return nil }
        let n1 = Int(driveTeeth.rounded())
        let n2 = Int(drivenTeeth.rounded())
        guard (minimumTeeth...maximumTeeth).contains(n1), (minimumTeeth...maximumTeeth).contains(n2) else { return nil }
        let p = chain.pitchMM
        let d1 = pitchDiameterMM(teeth: n1, pitchMM: p)
        let d2 = pitchDiameterMM(teeth: n2, pitchMM: p)
        let o1 = outsideDiameterMM(teeth: n1, pitchMM: p)
        let o2 = outsideDiameterMM(teeth: n2, pitchMM: p)
        // 30 pitches is the usual starting point. Never closer than the two sprockets plus 30 mm of air.
        let floor = (o1 + o2) / 2 + 30
        var requested = max(30 * p, floor)
        if let requestedCenter, requestedCenter.isFinite, requestedCenter > 0 {
            requested = max(requestedCenter, (d1 + d2) / 2 + p)
        }
        let links = chainLinks(driveTeeth: n1, drivenTeeth: n2, centerDistanceMM: requested, pitchMM: p)
        let center = centerDistanceMM(links: links, driveTeeth: n1, drivenTeeth: n2, pitchMM: p)
        let ratioSin = min(max(abs(d2 - d1) / (2 * center), -1), 1)
        let wrap = 180 - 2 * asin(ratioSin) * 180 / Double.pi
        return SprocketSetup(
            chain: chain,
            driveTeeth: n1,
            drivenTeeth: n2,
            drivePitchDiameterMM: d1,
            drivenPitchDiameterMM: d2,
            driveOutsideDiameterMM: o1,
            drivenOutsideDiameterMM: o2,
            centerDistanceMM: center,
            chainLinks: links,
            chainLengthMM: Double(links) * p,
            smallWrapDegrees: wrap,
            ratio: Double(n2) / Double(n1)
        )
    }
}

// MARK: - Battery pack outline

/// Cell positions and outer dimensions for a finished S×P pack. Each series group is one column of
/// P parallel cells. Dimensions are cells and nickel only, with no wrap, holder, or BMS.
public struct PackModel3D: Equatable, Sendable {
    public struct Cell: Equatable, Sendable {
        public var column: Int
        public var row: Int
        /// Center of the cell in mm from the pack's back-left corner.
        public var x: Double
        public var y: Double
    }

    public var series: Int
    public var parallel: Int
    public var cellDiameterMM: Double
    public var cellLengthMM: Double
    public var honeycomb: Bool
    public var stripThicknessMM: Double
    public var cells: [Cell]
    /// Overall size: length along the series direction, width across the parallel cells, and height.
    public var lengthMM: Double
    public var widthMM: Double
    public var heightMM: Double
}

public enum PackGeometry {
    public static let maximumDrawnCells = 400

    public static func model(
        series: Int,
        parallel: Int,
        cellDiameterMM: Double,
        cellLengthMM: Double,
        honeycomb: Bool,
        stripThicknessMM: Double = 0.15
    ) -> PackModel3D? {
        guard series >= 1, parallel >= 1, series * parallel <= maximumDrawnCells,
              cellDiameterMM.isFinite, cellDiameterMM > 0,
              cellLengthMM.isFinite, cellLengthMM > 0 else { return nil }
        let d = cellDiameterMM
        let columnPitch = honeycomb ? d * 3.0.squareRoot() / 2 : d
        let stagger = honeycomb && series > 1
        var cells: [PackModel3D.Cell] = []
        for column in 0..<series {
            let shift = (honeycomb && column % 2 == 1) ? d / 2 : 0
            for row in 0..<parallel {
                cells.append(PackModel3D.Cell(
                    column: column,
                    row: row,
                    x: d / 2 + Double(column) * columnPitch,
                    y: d / 2 + Double(row) * d + shift
                ))
            }
        }
        return PackModel3D(
            series: series,
            parallel: parallel,
            cellDiameterMM: d,
            cellLengthMM: cellLengthMM,
            honeycomb: honeycomb,
            stripThicknessMM: stripThicknessMM,
            cells: cells,
            lengthMM: Double(series - 1) * columnPitch + d,
            widthMM: Double(parallel) * d + (stagger ? d / 2 : 0),
            heightMM: cellLengthMM + 2 * stripThicknessMM
        )
    }
}

// MARK: - Part pinouts

public enum PinRole: String, Sendable, Equatable {
    case supplyPlus, supplyMinus, ground
    case inputPlus, inputMinus, output
    case powerIn, powerOut, adjust
    case gain, reference, offset
    case noConnect
}

public struct PartPin: Equatable, Sendable {
    public var number: Int
    public var name: String
    public var role: PinRole

    public init(_ number: Int, _ name: String, _ role: PinRole) {
        self.number = number
        self.name = name
        self.role = role
    }
}

public enum PartPackage: Equatable, Sendable {
    case dip(Int)
    case sot23_5
    case to220
    case sot223

    public var label: String {
        switch self {
        case .dip(let pins): return "DIP-\(pins) / SOIC-\(pins) (top view)"
        case .sot23_5: return "SOT-23-5 (top view)"
        case .to220: return "TO-220 (front view, tab behind)"
        case .sot223: return "SOT-223 (front view, tab on top)"
        }
    }
}

public enum PartFamily: String, Sendable, CaseIterable {
    case opAmp
    case instrumentationAmp
    case regulator
}

public struct PartPinout: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var family: PartFamily
    public var package: PartPackage
    public var pins: [PartPin]
    /// What the tab is tied to, when the package has one.
    public var tabNote: String?
    public var summary: String

    public init(
        id: String, name: String, family: PartFamily, package: PartPackage,
        pins: [PartPin], tabNote: String? = nil, summary: String
    ) {
        self.id = id
        self.name = name
        self.family = family
        self.package = package
        self.pins = pins
        self.tabNote = tabNote
        self.summary = summary
    }
}

/// Pin 1 is the dot / notch corner. Dual and quad parts label each amplifier A–D.
/// These are the standard industry pinouts. Always confirm against the data sheet for the exact suffix and package.
public enum PartPinouts {
    private static let single8: [PartPin] = [
        PartPin(1, "Offset null", .offset), PartPin(2, "IN−", .inputMinus), PartPin(3, "IN+", .inputPlus),
        PartPin(4, "V−", .supplyMinus), PartPin(5, "Offset null", .offset), PartPin(6, "OUT", .output),
        PartPin(7, "V+", .supplyPlus), PartPin(8, "NC", .noConnect),
    ]

    private static let dual8: [PartPin] = [
        PartPin(1, "OUT A", .output), PartPin(2, "IN− A", .inputMinus), PartPin(3, "IN+ A", .inputPlus),
        PartPin(4, "V−", .supplyMinus), PartPin(5, "IN+ B", .inputPlus), PartPin(6, "IN− B", .inputMinus),
        PartPin(7, "OUT B", .output), PartPin(8, "V+", .supplyPlus),
    ]

    private static let quad14: [PartPin] = [
        PartPin(1, "OUT A", .output), PartPin(2, "IN− A", .inputMinus), PartPin(3, "IN+ A", .inputPlus),
        PartPin(4, "V+", .supplyPlus), PartPin(5, "IN+ B", .inputPlus), PartPin(6, "IN− B", .inputMinus),
        PartPin(7, "OUT B", .output), PartPin(8, "OUT C", .output), PartPin(9, "IN− C", .inputMinus),
        PartPin(10, "IN+ C", .inputPlus), PartPin(11, "V−", .supplyMinus), PartPin(12, "IN+ D", .inputPlus),
        PartPin(13, "IN− D", .inputMinus), PartPin(14, "OUT D", .output),
    ]

    private static let inAmp8: [PartPin] = [
        PartPin(1, "RG", .gain), PartPin(2, "IN−", .inputMinus), PartPin(3, "IN+", .inputPlus),
        PartPin(4, "V−", .supplyMinus), PartPin(5, "REF", .reference), PartPin(6, "OUT", .output),
        PartPin(7, "V+", .supplyPlus), PartPin(8, "RG", .gain),
    ]

    public static let all: [PartPinout] = [
        PartPinout(id: "lm741", name: "LM741", family: .opAmp, package: .dip(8), pins: single8,
                   summary: "Single general-purpose op amp. Offset-null pins 1 and 5 take a trim pot to V−."),
        PartPinout(id: "tl071", name: "TL071", family: .opAmp, package: .dip(8), pins: single8,
                   summary: "Single JFET-input op amp. Same pin order as the 741."),
        PartPinout(id: "op07", name: "OP07", family: .opAmp, package: .dip(8), pins: [
            PartPin(1, "Trim", .offset), PartPin(2, "IN−", .inputMinus), PartPin(3, "IN+", .inputPlus),
            PartPin(4, "V−", .supplyMinus), PartPin(5, "NC", .noConnect), PartPin(6, "OUT", .output),
            PartPin(7, "V+", .supplyPlus), PartPin(8, "Trim", .offset),
        ], summary: "Single low-offset precision op amp. Trim pins are 1 and 8."),
        PartPinout(id: "lm358", name: "LM358", family: .opAmp, package: .dip(8), pins: dual8,
                   summary: "Dual single-supply op amp. V− is ground on a single supply."),
        PartPinout(id: "tl072", name: "TL072", family: .opAmp, package: .dip(8), pins: dual8,
                   summary: "Dual JFET-input op amp."),
        PartPinout(id: "ne5532", name: "NE5532", family: .opAmp, package: .dip(8), pins: dual8,
                   summary: "Dual low-noise audio op amp."),
        PartPinout(id: "lm324", name: "LM324", family: .opAmp, package: .dip(14), pins: quad14,
                   summary: "Quad single-supply op amp. V+ is pin 4 and V− is pin 11."),
        PartPinout(id: "tl074", name: "TL074", family: .opAmp, package: .dip(14), pins: quad14,
                   summary: "Quad JFET-input op amp. Same pin order as the LM324."),
        PartPinout(id: "mcp6001", name: "MCP6001", family: .opAmp, package: .sot23_5, pins: [
            PartPin(1, "OUT", .output), PartPin(2, "V−", .supplyMinus), PartPin(3, "IN+", .inputPlus),
            PartPin(4, "IN−", .inputMinus), PartPin(5, "V+", .supplyPlus),
        ], summary: "Single rail-to-rail op amp in SOT-23-5. Pin 1 is the dot corner."),

        PartPinout(id: "ina128", name: "INA128", family: .instrumentationAmp, package: .dip(8), pins: inAmp8,
                   summary: "Instrumentation amp. Gain = 1 + 50 kΩ / RG across pins 1 and 8."),
        PartPinout(id: "ad620", name: "AD620", family: .instrumentationAmp, package: .dip(8), pins: inAmp8,
                   summary: "Instrumentation amp. Gain = 1 + 49.4 kΩ / RG across pins 1 and 8."),

        PartPinout(id: "lm317", name: "LM317", family: .regulator, package: .to220, pins: [
            PartPin(1, "ADJ", .adjust), PartPin(2, "OUT", .powerOut), PartPin(3, "IN", .powerIn),
        ], tabNote: "Tab is OUT", summary: "Adjustable regulator. Vout = 1.25 V × (1 + R2 / R1) with R1 from OUT to ADJ."),
        PartPinout(id: "lm7805", name: "LM7805", family: .regulator, package: .to220, pins: [
            PartPin(1, "IN", .powerIn), PartPin(2, "GND", .ground), PartPin(3, "OUT", .powerOut),
        ], tabNote: "Tab is GND", summary: "Fixed 5 V regulator. The 78xx family shares this pin order."),
        PartPinout(id: "lm1117", name: "LM1117 / AMS1117", family: .regulator, package: .sot223, pins: [
            PartPin(1, "GND / ADJ", .adjust), PartPin(2, "OUT", .powerOut), PartPin(3, "IN", .powerIn),
        ], tabNote: "Tab is OUT", summary: "Low-dropout regulator. Pin 1 is GND on fixed versions and ADJ on the adjustable one."),
    ]

    public static func parts(family: PartFamily) -> [PartPinout] {
        all.filter { $0.family == family }
    }

    public static func part(id: String) -> PartPinout? {
        all.first { $0.id == id }
    }
}
