import Foundation
import BeckifyMath

enum ToolID: String, Codable, CaseIterable, Identifiable {
    case ohmsLaw
    case power
    case powerWizard
    case voltageDrop
    case conduitFill
    case transformer
    case timer555
    case motorFLA
    case wireAmpacity
    case conductorCost
    case conductorLength
    case voltageDivider
    case seriesParallel
    case resistorColor
    case unitConverter
    case frequencyWave
    case ledRC
    case wifiStatus
    case bluetoothScan
    case noiseMeter
    case bubbleLevel
    case magnetometer
    case barometer
    case motionSnapshot
    case fieldPosition
    case deviceHealth
    case receptacleSelector
    case reactance
    case powerFactor
    case shortCircuit
    case circularMils
    case loadFactors
    case signalScaling
    case modbusAddress
    case plcTimer
    case panelDirectory
    case motorSpeed
    case rfLink
    case phasorDiagram
    case numberBase
    case batteryBank
    case referenceLibrary
    case magneticCircuit
    case fiberLink
    case gaussianBeam
    case transientCircuit
    case rackCurrent
    case diodeIV
    case isLoopVerifier
    case tapChanger
    case harmonicsTHD
    case upsSizing
    case motorNameplate
    case motorNameplateOCR
    case heaterDesign
    case empEmc
    case necCircuit
    case loadWorksheet
    case cableSchedule
    case solenoidDesign
    case solarDesign
    case analogWorkbench
    case noiseSNR
    case linearRegulator
    case instrumentationAmp
    case adcDac
    case eBikeTorqueRPM
    case eBikeSprocket
    case eBikeRange
    case eBikePackDesigner
    case nickelStrip
    case controlSystems

    var id: String { rawValue }
}

/// Color-coded shelves. Home IA is Field vs Toolkit (`ToolHomeArea`);
/// these cases stay stable so open catalog PRs can keep merging additively.
enum ToolCategory: String, CaseIterable, Identifiable {
    case field = "Field"
    case power = "Power & AC"
    case controls = "Controls"
    case homework = "Homework"
    case sensors = "Sensors"
    case reference = "Reference"

    var id: String { rawValue }

    /// Operator-facing shelf title. Raw values stay unchanged for merge stability.
    var displayName: String {
        switch self {
        case .field: return "Jobsite"
        case .power: return "Power & AC"
        case .controls: return "Controls"
        case .homework: return "Bench / homework"
        case .sensors: return "Instruments"
        case .reference: return "Reference"
        }
    }
}

extension ToolHomeArea {
    var title: String {
        switch self {
        case .field: return "Field"
        case .toolkit: return "Toolkit"
        }
    }

    var headline: String {
        switch self {
        case .field: return "Field EE Toolbox"
        case .toolkit: return "Toolkit"
        }
    }

    var blurb: String {
        switch self {
        case .field:
            return "Jobsite calculators, wizards, and instruments."
        case .toolkit:
            return "Basics, bench homework, and references."
        }
    }
}

extension ToolShelfKind {
    var title: String {
        switch self {
        case .jobsite: return "Jobsite"
        case .power: return "Power & AC"
        case .controls: return "Controls"
        case .instruments: return "Instruments"
        case .basics: return "Basics"
        case .bench: return "Bench / homework"
        case .reference: return "Reference"
        }
    }

    /// Shelves shown under one home area, in grid order.
    static func shelves(in area: ToolHomeArea) -> [ToolShelfKind] {
        allCases.filter { $0.homeArea == area }
    }

    /// Existing category glyph / color family for this shelf.
    var category: ToolCategory {
        switch self {
        case .jobsite: return .field
        case .power: return .power
        case .controls: return .controls
        case .instruments: return .sensors
        case .basics, .bench: return .homework
        case .reference: return .reference
        }
    }
}

extension ToolboxCatalog {
    /// The shelf a tool is filed under, for the breadcrumb color on its tile.
    static func category(of id: ToolID) -> ToolCategory? {
        ToolCategory.allCases.first { categories[$0]?.contains(id) == true }
    }

    /// Field (jobsite) vs Toolkit (basics / bench / reference). ToolIDs stay put.
    static func area(of id: ToolID) -> ToolHomeArea {
        ToolHomeAreaPolicy.area(forToolID: id.rawValue)
    }

    static func shelf(of id: ToolID) -> ToolShelfKind {
        ToolHomeAreaPolicy.shelf(forToolID: id.rawValue)
    }

    static func tools(in area: ToolHomeArea) -> [ToolDefinition] {
        tools.filter { Self.area(of: $0.id) == area }
    }

    static func tools(on shelf: ToolShelfKind) -> [ToolDefinition] {
        let ids: [ToolID]
        switch shelf {
        case .jobsite:
            ids = (categories[.field] ?? []).filter { area(of: $0) == .field }
        case .power:
            ids = (categories[.power] ?? []).filter { area(of: $0) == .field }
        case .controls:
            ids = (categories[.controls] ?? []).filter { area(of: $0) == .field }
        case .instruments:
            ids = categories[.sensors] ?? []
        case .basics:
            ids = [
                .ohmsLaw, .voltageDivider, .seriesParallel, .resistorColor,
                .ledRC, .frequencyWave, .unitConverter, .timer555,
            ]
        case .bench:
            // Listed tools in catalog order, plus any later ToolID that the
            // policy files under bench (AoE analog, etc.) once those PRs merge.
            let listed = tools.filter { ToolHomeAreaPolicy.shelf(forToolID: $0.id.rawValue) == .bench }.map(\.id)
            let extras = ToolID.allCases.filter { id in
                id != .powerWizard
                    && ToolHomeAreaPolicy.shelf(forToolID: id.rawValue) == .bench
                    && !listed.contains(id)
                    && allTools.contains(where: { $0.id == id })
            }
            ids = listed + extras
        case .reference:
            ids = categories[.reference] ?? []
        }
        return ids.compactMap { id in allTools.first { $0.id == id } }
    }
}

enum ToolKind: String, Codable {
    case calculator
    case homework
    case sensor
}

struct ToolDefinition: Identifiable {
    var id: ToolID
    var kind: ToolKind
    var title: String
    var subtitle: String
    /// SF Symbol used only as a fallback / related-row chevron context — primary
    /// artwork is the Beckify instrument glyph set (`IconWell` / `ToolGlyph`).
    var symbol: String
    var synonyms: [String]
    /// Live converters update on valid input; explicit tools require Calculate.
    var calculationMode: CalculationMode

    var searchBlob: String {
        ([title, subtitle] + synonyms).joined(separator: " ").lowercased()
    }

    init(
        id: ToolID,
        kind: ToolKind,
        title: String,
        subtitle: String,
        symbol: String,
        synonyms: [String],
        calculationMode: CalculationMode? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.synonyms = synonyms
        self.calculationMode = calculationMode ?? ToolCalculationPolicy.mode(forToolID: id.rawValue)
    }
}

enum ToolboxCatalog {
    static let tools: [ToolDefinition] = [
        ToolDefinition(
            id: .ohmsLaw,
            kind: .calculator,
            title: "Ohm's Law",
            subtitle: "Solve any two of V, I, R. Power follows.",
            symbol: "waveform.path.ecg",
            synonyms: ["ohm", "ohms", "voltage", "current", "resistance", "v=ir", "vir"]
        ),
        ToolDefinition(
            id: .power,
            kind: .calculator,
            title: "Power",
            subtitle: "DC identities (P=VI, I²R, V²/R) plus 1Ø / 3Ø kVA, kW, kVAR.",
            symbol: "bolt.fill",
            synonyms: ["dc power", "ac power", "watts", "kvar", "apparent", "true power", "reactive", "power wizard", "kva", "kw", "horsepower", "three phase", "3 phase", "single phase"]
        ),
        ToolDefinition(
            id: .voltageDrop,
            kind: .calculator,
            title: "Voltage Drop",
            subtitle: "Conductor sizing with K-factor VD, parallels, and ampacity check.",
            symbol: "arrow.down.right.and.arrow.up.left",
            synonyms: ["voltage drop", "vd", "feeder", "branch", "ampacity", "awg", "circular mils", "k-factor"]
        ),
        ToolDefinition(
            id: .conduitFill,
            kind: .calculator,
            title: "Conduit Fill",
            subtitle: "Same-size or mixed THHN (and other Table 5) fill vs Table 1.",
            symbol: "circle.hexagongrid.fill",
            synonyms: ["conduit", "fill", "emt", "thhn", "raceway", "chapter 9", "40 percent", "annex c", "mixed sizes"]
        ),
        ToolDefinition(
            id: .transformer,
            kind: .calculator,
            title: "Transformer Sizing",
            subtitle: "Standard kVA and 450.3(B) protection, Note 1.",
            symbol: "rectangle.split.2x1.fill",
            synonyms: ["transformer", "xfmr", "kva", "450.3", "ocpd", "primary", "secondary", "note 1"]
        ),
        ToolDefinition(
            id: .timer555,
            kind: .calculator,
            title: "555 Timer",
            subtitle: "Astable and monostable from ln(2) / ln(3).",
            symbol: "timer",
            synonyms: ["555", "astable", "monostable", "ne555", "oscillator", "one shot", "duty cycle"]
        ),
        ToolDefinition(
            id: .motorFLA,
            kind: .calculator,
            title: "Motor FLA Tables",
            subtitle: "NEC 430.248 and 430.250 table currents.",
            symbol: "fanblades.fill",
            synonyms: ["motor", "fla", "flc", "430.248", "430.250", "horsepower", "squirrel cage"]
        ),
        ToolDefinition(
            id: .wireAmpacity,
            kind: .calculator,
            title: "Wire Size & Ampacity",
            subtitle: "310.16 with ambient, CCC, termination cap, and continuous load.",
            symbol: "cable.connector.horizontal",
            synonyms: ["wire size", "ampacity", "awg", "310.16", "75c", "kcmil", "copper", "aluminum", "conductor", "derating", "310.15"]
        ),
        ToolDefinition(
            id: .conductorCost,
            kind: .calculator,
            title: "Conductor Cost Optimizer",
            subtitle: "Compare compliant sizes and parallels with planning $/kft and optional I²R.",
            symbol: "dollarsign.circle",
            synonyms: ["conductor cost", "optimize", "planning allowance", "parallel runs", "copper cost", "aluminum cost", "i2r", "kft", "wire select"]
        ),
        ToolDefinition(
            id: .conductorLength,
            kind: .calculator,
            title: "Conductor Length by Resistance",
            subtitle: "Estimate length from measured resistance with Cu/Al temperature compensation.",
            symbol: "ruler",
            synonyms: [
                "conductor length", "length from r", "resistance length", "loop resistance",
                "circular mils", "awg", "copper", "aluminum", "milliohm", "cable length",
            ]
        ),
        ToolDefinition(
            id: .receptacleSelector,
            kind: .calculator,
            title: "Receptacle Selector",
            subtitle: "NEMA / IEC 60309 best-fit faces, pinout, public PNs.",
            symbol: "poweroutlet.type.b",
            synonyms: ["receptacle", "outlet", "NEMA", "L5-30", "pin and sleeve", "Meltric", "Hubbell", "twist lock", "IEC 60309"]
        ),
        ToolDefinition(
            id: .voltageDivider,
            kind: .homework,
            title: "Voltage Divider",
            subtitle: "Vout from Vin, R1, R2 — or solve a resistor.",
            symbol: "slider.horizontal.3",
            synonyms: ["divider", "voltage divider", "potentiometer", "r1 r2", "vout"]
        ),
        ToolDefinition(
            id: .seriesParallel,
            kind: .homework,
            title: "Series / Parallel",
            subtitle: "Resistors and capacitors, series or parallel.",
            symbol: "point.3.connected.trianglepath.dotted",
            synonyms: ["series", "parallel", "equivalent", "network", "capacitor", "resistor combo"]
        ),
        ToolDefinition(
            id: .resistorColor,
            kind: .homework,
            title: "Resistor Color Code",
            subtitle: "4-band and 5-band decode + encode.",
            symbol: "circle.lefthalf.filled",
            synonyms: ["color code", "colour code", "bands", "tolerance", "gold", "silver"]
        ),
        ToolDefinition(
            id: .unitConverter,
            kind: .calculator,
            title: "Unit Converter",
            subtitle: "SI prefixes, dB, °C/°F, m/ft, mils/mm.",
            symbol: "arrow.left.arrow.right",
            synonyms: ["unit", "prefix", "db", "decibel", "celsius", "fahrenheit", "feet", "mils", "mm"]
        ),
        ToolDefinition(
            id: .frequencyWave,
            kind: .homework,
            title: "Frequency / LC",
            subtitle: "f, T, λ = c/f, and f = 1/(2π√(LC)).",
            symbol: "waveform",
            synonyms: ["frequency", "period", "wavelength", "lc", "resonance", "hertz"]
        ),
        ToolDefinition(
            id: .ledRC,
            kind: .homework,
            title: "LED / RC",
            subtitle: "LED current-limit R and τ = RC.",
            symbol: "lightbulb.fill",
            synonyms: ["led", "current limit", "tau", "time constant", "rc", "e24"]
        ),
        ToolDefinition(
            id: .wifiStatus,
            kind: .sensor,
            title: "Wi-Fi Path",
            subtitle: "Path + Apple 0…1 amplitude map. Not Wi-Fi dBm.",
            symbol: "wifi",
            synonyms: ["wifi", "wi-fi", "wlan", "ssid", "rssi", "signal", "hotspot", "network path", "heatmap", "coverage", "dbm"]
        ),
        ToolDefinition(
            id: .bluetoothScan,
            kind: .sensor,
            title: "BLE Scanner",
            subtitle: "CoreBluetooth names, identifiers, RSSI, advertised services.",
            symbol: "dot.radiowaves.left.and.right",
            synonyms: ["bluetooth", "ble", "corebluetooth", "peripheral", "rssi", "beacon"]
        ),
        ToolDefinition(
            id: .noiseMeter,
            kind: .sensor,
            title: "Noise Meter",
            subtitle: "Uncalibrated microphone dBFS. Not an SLM.",
            symbol: "mic.fill",
            synonyms: ["noise", "decibel", "db", "spl", "microphone", "sound", "dbfs"]
        ),
        ToolDefinition(
            id: .bubbleLevel,
            kind: .sensor,
            title: "Bubble Level",
            subtitle: "Pitch, roll, and plumb from CoreMotion gravity.",
            symbol: "level.fill",
            synonyms: ["level", "bubble", "inclinometer", "plumb", "conduit", "panel", "trig", "tilt"]
        ),
        ToolDefinition(
            id: .magnetometer,
            kind: .sensor,
            title: "Magnetometer",
            subtitle: "Heading and |B| in µT. Homework / field-ish.",
            symbol: "location.north.circle.fill",
            synonyms: ["compass", "magnetometer", "tesla", "microtesla", "gauss", "magnetic", "heading"]
        ),
        ToolDefinition(
            id: .barometer,
            kind: .sensor,
            title: "Barometer",
            subtitle: "Pressure and relative altitude (CMAltimeter).",
            symbol: "barometer",
            synonyms: ["barometer", "altitude", "pressure", "kpa", "altimeter"]
        ),
        ToolDefinition(
            id: .motionSnapshot,
            kind: .sensor,
            title: "g-Force Snapshot",
            subtitle: "Device motion gravity and user acceleration.",
            symbol: "gyroscope",
            synonyms: ["g-force", "gforce", "vibration", "accelerometer", "motion", "imu"]
        ),
        ToolDefinition(
            id: .fieldPosition,
            kind: .sensor,
            title: "Position",
            subtitle: "GPS coordinates, speed, altitude, homework distance.",
            symbol: "location.fill",
            synonyms: ["gps", "location", "coordinates", "latitude", "longitude", "distance", "haversine", "position"]
        ),
        ToolDefinition(
            id: .deviceHealth,
            kind: .sensor,
            title: "Device Health",
            subtitle: "Battery level and thermal state. Diagnostics only.",
            symbol: "battery.100",
            synonyms: ["battery", "thermal", "diagnostics", "temperature", "charge"]
        ),
        ToolDefinition(
            id: .reactance,
            kind: .calculator,
            title: "Reactance & Resonance",
            subtitle: "X_L, X_C, series Z and angle, plus LC resonance with Q and bandwidth.",
            symbol: "waveform.path",
            synonyms: ["reactance", "impedance", "resonance", "xl", "xc", "quality factor", "bandwidth", "lc"]
        ),
        ToolDefinition(
            id: .powerFactor,
            kind: .calculator,
            title: "Power Factor Correction",
            subtitle: "Capacitor kVAR to reach a target PF, plus bank capacitance.",
            symbol: "arrow.triangle.2.circlepath",
            synonyms: ["power factor", "pf", "kvar", "correction", "capacitor bank", "cos phi"]
        ),
        ToolDefinition(
            id: .shortCircuit,
            kind: .calculator,
            title: "Short-Circuit Current",
            subtitle: "Infinite-bus secondary fault current from kVA, volts, and %Z.",
            symbol: "bolt.trianglebadge.exclamationmark",
            synonyms: ["short circuit", "fault current", "aic", "sccr", "interrupting", "%z", "infinite bus"]
        ),
        ToolDefinition(
            id: .circularMils,
            kind: .calculator,
            title: "Circular Mils",
            subtitle: "Diameter, circular mils, and square inches for round conductors.",
            symbol: "circle.circle",
            synonyms: ["circular mils", "cm", "kcmil", "area", "diameter", "mils"]
        ),
        ToolDefinition(
            id: .loadFactors,
            kind: .calculator,
            title: "Load & Demand Factors",
            subtitle: "Demand, load, diversity, and capacity utilisation from metered data.",
            symbol: "chart.bar.xaxis",
            synonyms: ["demand factor", "load factor", "diversity", "coincidence", "utilization", "capacity"]
        ),
        ToolDefinition(
            id: .signalScaling,
            kind: .calculator,
            title: "Signal Scaling",
            subtitle: "4–20 mA to engineering units and back. Linear or √ for DP flow.",
            symbol: "chart.line.uptrend.xyaxis",
            synonyms: ["4-20", "signal", "scaling", "process value", "transmitter", "dp flow", "square root", "live zero"]
        ),
        ToolDefinition(
            id: .modbusAddress,
            kind: .calculator,
            title: "Modbus Address",
            subtitle: "PDU offset, entity number, 40001/400001 forms, and function code.",
            symbol: "number.square",
            synonyms: ["modbus", "register", "coil", "holding", "40001", "offset", "function code", "plc"]
        ),
        ToolDefinition(
            id: .plcTimer,
            kind: .calculator,
            title: "PLC Timer Preset",
            subtitle: "TON/TOF preset counts at a timebase, with quantisation error.",
            symbol: "stopwatch",
            synonyms: ["plc", "timer", "ton", "tof", "rto", "preset", "timebase", "scan"]
        ),
        ToolDefinition(
            id: .panelDirectory,
            kind: .calculator,
            title: "Panel Directory",
            subtitle: "Paste or OCR a panel schedule photo into circuit, name, trip, and poles.",
            symbol: "list.bullet.rectangle",
            synonyms: ["panel", "directory", "schedule", "circuit", "breaker", "ocr", "sticker", "legend"]
        ),
        ToolDefinition(
            id: .motorSpeed,
            kind: .calculator,
            title: "Motor Speed & Torque",
            subtitle: "Synchronous RPM, slip from a nameplate, and shaft torque from HP — with the curve.",
            symbol: "gauge.with.needle",
            synonyms: ["motor", "slip", "synchronous", "rpm", "poles", "torque", "shaft", "lb-ft", "nameplate", "5252"]
        ),
        ToolDefinition(
            id: .rfLink,
            kind: .calculator,
            title: "RF Power & Link",
            subtitle: "dBm to watts, VSWR and return loss, and free-space path loss vs. distance.",
            symbol: "antenna.radiowaves.left.and.right",
            synonyms: ["rf", "dbm", "watts", "vswr", "swr", "return loss", "antenna", "path loss", "fspl", "link budget", "reflection"]
        ),
        ToolDefinition(
            id: .phasorDiagram,
            kind: .homework,
            title: "Phasor Diagram",
            subtitle: "Plot 2–3 phasors and sum them — the balanced 3-phase set is one tap away.",
            symbol: "chart.dots.scatter",
            synonyms: ["phasor", "vector", "three phase", "balanced", "polar", "angle", "resultant"]
        ),
        ToolDefinition(
            id: .numberBase,
            kind: .calculator,
            title: "Number Base Converter",
            subtitle: "Binary, octal, decimal, hex — plus 8/16/32-bit signed read of the same bits.",
            symbol: "number",
            synonyms: ["binary", "hex", "hexadecimal", "octal", "decimal", "base converter", "twos complement", "register", "modbus"]
        ),
        ToolDefinition(
            id: .batteryBank,
            kind: .calculator,
            title: "Battery Bank Sizing",
            subtitle: "Series/parallel cells to bank voltage, amp-hours, and runtime at a load.",
            symbol: "minus.plus.batteryblock",
            synonyms: ["battery", "bank", "series", "parallel", "amp hours", "ah", "runtime", "depth of discharge", "dod", "cells"]
        ),
        ToolDefinition(
            id: .referenceLibrary,
            kind: .calculator,
            title: "Reference Library",
            subtitle: "NEMA, IP ratings, conductor colors, hazardous areas, insulation, torque, conduit, and standard sizes.",
            symbol: "books.vertical",
            synonyms: ["nema", "ip rating", "enclosure", "conductor color", "wire color", "hazardous", "classified", "insulation", "thhn", "torque", "bolt", "conduit", "fittings", "standard sizes", "reference", "table"]
        ),
        ToolDefinition(
            id: .magneticCircuit,
            kind: .calculator,
            title: "Magnetic Circuit",
            subtitle: "Reluctance, flux, and flux density from mmf, path length, area, and µr.",
            symbol: "atom",
            synonyms: ["magnetic circuit", "reluctance", "flux", "flux density", "mmf", "permeability", "core"]
        ),
        ToolDefinition(
            id: .fiberLink,
            kind: .homework,
            title: "Fiber Link / NA",
            subtitle: "Numerical aperture and acceptance angle from core/cladding index, plus V-number.",
            symbol: "line.diagonal",
            synonyms: ["fiber", "fibre", "optic", "numerical aperture", "na", "acceptance angle", "single mode", "multimode", "v number"]
        ),
        ToolDefinition(
            id: .gaussianBeam,
            kind: .homework,
            title: "Gaussian Beam",
            subtitle: "Rayleigh range, divergence, and beam radius at distance from a waist.",
            symbol: "smallcircle.filled.circle",
            synonyms: ["gaussian beam", "laser", "rayleigh range", "divergence", "waist", "beam radius", "photonics"]
        ),
        ToolDefinition(
            id: .transientCircuit,
            kind: .homework,
            title: "Transient Circuits",
            subtitle: "RC/RL charge and discharge — value at a time, percent complete, and the curve.",
            symbol: "waveform.path.ecg.rectangle",
            synonyms: ["transient", "rc circuit", "rl circuit", "time constant", "tau", "charging", "discharging", "step response"]
        ),
        ToolDefinition(
            id: .rackCurrent,
            kind: .calculator,
            title: "E-Bus / Rack Current",
            subtitle: "Sum device currents against a bus rating for headroom and percent utilization.",
            symbol: "server.rack",
            synonyms: ["e-bus", "rack current", "bus current", "backplane", "current budget", "headroom", "utilization", "24vdc", "5v logic"]
        ),
        ToolDefinition(
            id: .diodeIV,
            kind: .homework,
            title: "Semiconductor I-V",
            subtitle: "Diode forward current from the Shockley equation, with the I-V curve.",
            symbol: "triangle.righthalf.filled",
            synonyms: ["diode", "shockley", "iv curve", "forward voltage", "saturation current", "ideality factor", "junction", "semiconductor"]
        ),
        ToolDefinition(
            id: .isLoopVerifier,
            kind: .calculator,
            title: "IS Loop Verifier",
            subtitle: "Entity Concept check — barrier Voc/Isc/Ca/La against field device and cable parameters.",
            symbol: "checkmark.shield",
            synonyms: ["intrinsic safety", "is loop", "entity concept", "barrier", "voc", "isc", "ca", "la", "hazardous area", "zener barrier"]
        ),
        ToolDefinition(
            id: .tapChanger,
            kind: .calculator,
            title: "Tap-Changer Calculator",
            subtitle: "Transformer DETC tap recommendation from measured secondary voltage.",
            symbol: "dial.low",
            synonyms: ["tap", "oltc", "detc", "voltage regulation", "transformer tap", "23 kv"]
        ),
        ToolDefinition(
            id: .harmonicsTHD,
            kind: .calculator,
            title: "Harmonics (THD)",
            subtitle: "Current THD, dominant order, and IEEE 519 discussion bands.",
            symbol: "waveform.path.ecg",
            synonyms: ["thd", "harmonic", "ieee 519", "distortion", "thd-i", "nonlinear"]
        ),
        ToolDefinition(
            id: .upsSizing,
            kind: .calculator,
            title: "UPS / On-site Power",
            subtitle: "kVA, runtime, and battery Ah from IT / critical load.",
            symbol: "battery.100.bolt",
            synonyms: ["ups", "battery runtime", "on-site power", "inverter", "autonomy", "kva"]
        ),
        ToolDefinition(
            id: .motorNameplate,
            kind: .calculator,
            title: "Motor Nameplate Analyzer",
            subtitle: "Overload, Table 430.52 SCPD, 430.22 conductor, and code-letter LRA.",
            symbol: "doc.text.magnifyingglass",
            synonyms: ["nameplate", "overload", "430.52", "430.32", "lra", "code letter", "motor ocpd"]
        ),
        ToolDefinition(
            id: .motorNameplateOCR,
            kind: .calculator,
            title: "Motor Nameplate OCR",
            subtitle: "Photograph a plate; Vision + shared-schema fields, then you confirm.",
            symbol: "text.viewfinder",
            synonyms: ["ocr", "nameplate", "camera", "vision", "motor plate", "hp", "rpm", "fla", "scan"]
        ),
        ToolDefinition(
            id: .heaterDesign,
            kind: .calculator,
            title: "Heater Design Wizard",
            subtitle: "Resistive heater line current, leg R, and resistance-wire length.",
            symbol: "flame",
            synonyms: ["heater", "nichrome", "kanthal", "element", "resistive load", "wye", "delta"]
        ),
        ToolDefinition(
            id: .empEmc,
            kind: .calculator,
            title: "EMP / EMC Shielding",
            subtitle: "Skin depth, sheet SE, Faraday-loop voltage, and aperture leakage.",
            symbol: "shield.lefthalf.filled",
            synonyms: ["emp", "emc", "shielding", "skin depth", "faraday", "aperture", "se"]
        ),
        ToolDefinition(
            id: .necCircuit,
            kind: .calculator,
            title: "NEC Circuit Calculator",
            subtitle: "Design current, derated conductor, voltage drop, and OCPD in one pass.",
            symbol: "point.3.connected.trianglepath.dotted",
            synonyms: ["nec circuit", "branch circuit", "feeder", "ocpd", "voltage drop", "ampacity"]
        ),
        ToolDefinition(
            id: .loadWorksheet,
            kind: .calculator,
            title: "Load Calculation Worksheet",
            subtitle: "NEC 220.42 lighting demand plus motor/continuous VA totals.",
            symbol: "tablecells",
            synonyms: ["load calculation", "220.42", "demand factor", "service", "feeder worksheet"]
        ),
        ToolDefinition(
            id: .cableSchedule,
            kind: .calculator,
            title: "Cable Schedule Generator",
            subtitle: "Sequential cable IDs from a type catalog with CSV export.",
            symbol: "list.bullet.rectangle.portrait",
            synonyms: ["cable schedule", "cable id", "tray", "from to", "csv", "wire schedule"]
        ),
        ToolDefinition(
            id: .solenoidDesign,
            kind: .calculator,
            title: "Solenoid Design Wizard",
            subtitle: "Winding pack, center B, inductance, copper loss, axial field, and plunger force.",
            symbol: "cylinder.split.1x2",
            synonyms: ["solenoid", "coil", "electromagnet", "ampere turns", "plunger", "inductance", "winding"]
        ),
        ToolDefinition(
            id: .solarDesign,
            kind: .calculator,
            title: "Solar Design Wizard",
            subtitle: "PV from rooftop to utility — aim with phone sensors, optional storage sizing.",
            symbol: "sun.max.fill",
            synonyms: ["solar", "photovoltaic", "pv", "panel tilt", "azimuth", "peak sun hours", "battery storage", "bess", "array", "orientation"]
        ),
        ToolDefinition(
            id: .analogWorkbench,
            kind: .homework,
            title: "Analog Design Workbench",
            subtitle: "Op-amp golden-rule stages and RC / Sallen–Key filters with an ideal magnitude Bode sketch.",
            symbol: "triangle",
            synonyms: ["op amp", "op-amp", "inverting", "noninverting", "follower", "summing", "integrator", "differentiator", "sallen key", "sallen-key", "filter", "bode", "analog"]
        ),
        ToolDefinition(
            id: .noiseSNR,
            kind: .homework,
            title: "Noise & SNR",
            subtitle: "Johnson and optional shot noise, amp e_n / i_n, total referred noise, SNR, and a rough NF.",
            symbol: "waveform.path.ecg",
            synonyms: ["johnson", "thermal noise", "shot noise", "snr", "noise figure", "en", "in", "kT", "bandwidth"]
        ),
        ToolDefinition(
            id: .linearRegulator,
            kind: .calculator,
            title: "Linear / LDO Regulator",
            subtitle: "LM317-style Vout from R1/R2, dropout, Pd, and a θJA junction-temperature estimate.",
            symbol: "rectangle.portrait.and.arrow.right",
            synonyms: ["lm317", "ldo", "linear regulator", "dropout", "heatsink", "theta ja", "junction", "vout", "r1 r2"]
        ),
        ToolDefinition(
            id: .instrumentationAmp,
            kind: .homework,
            title: "Instrumentation Amp",
            subtitle: "3-op-amp InAmp gain from Rg, or a 4-resistor difference amp, plus swing vs rails.",
            symbol: "plusminus",
            synonyms: ["inamp", "instrumentation", "difference amp", "differential", "cmrr", "rg", "ad620", "ina"]
        ),
        ToolDefinition(
            id: .adcDac,
            kind: .calculator,
            title: "ADC / DAC & Sampling",
            subtitle: "LSB, code count, ideal quantization SNR, Nyquist, and an optional DAC code-to-voltage.",
            symbol: "square.stack.3d.up",
            synonyms: ["adc", "dac", "lsb", "nyquist", "sampling", "quantization", "enob", "anti alias", "bits", "full scale"]
        ),
        ToolDefinition(
            id: .eBikeTorqueRPM,
            kind: .calculator,
            title: "E-Bike Torque / RPM",
            subtitle: "Shaft torque or RPM from mechanical power — W, kW, or hp.",
            symbol: "gauge.with.dots.needle.67percent",
            synonyms: ["ebike", "e-bike", "torque", "rpm", "hub motor", "mid drive", "newton metre", "lb-ft", "drivetrain"]
        ),
        ToolDefinition(
            id: .eBikeSprocket,
            kind: .calculator,
            title: "Sprocket Ratio Designer",
            subtitle: "Drive/driven teeth to ratio, output RPM/torque, and wheel speed — or invert a target.",
            symbol: "circle.circle",
            synonyms: ["sprocket", "gear ratio", "chain", "driven", "drive teeth", "wheel speed", "ebike", "e-bike"]
        ),
        ToolDefinition(
            id: .eBikeRange,
            kind: .calculator,
            title: "Range Estimator",
            subtitle: "Pack V×Ah and Wh/mi to miles, kilometers, runtime, and implied speed.",
            symbol: "point.bottomleft.forward.to.point.topright.scurvepath",
            synonyms: ["range", "wh/mi", "watt hours", "ebike", "e-bike", "mileage", "runtime", "consumption"]
        ),
        ToolDefinition(
            id: .eBikePackDesigner,
            kind: .calculator,
            title: "Battery Pack Designer",
            subtitle: "Series/parallel pack planning from cell ratings or a voltage/current target.",
            symbol: "square.grid.3x3",
            synonyms: ["pack", "18650", "21700", "series parallel", "bms", "c-rate", "ebike", "e-bike", "cell layout"]
        ),
        ToolDefinition(
            id: .nickelStrip,
            kind: .calculator,
            title: "Nickel Strip",
            subtitle: "Strip cross-section to planning continuous and short-pulse current.",
            symbol: "rectangle.split.1x2",
            synonyms: ["nickel strip", "nickel plated", "spot weld", "busbar", "ampacity", "18650", "pack"]
        ),
        // Field → Controls hub (not Toolkit → Bench): same shelf as Signal
        // Scaling / PLC Timer. Analysis, not a second Analog Workbench.
        ToolDefinition(
            id: .controlSystems,
            kind: .calculator,
            title: "Control Systems",
            subtitle: "Pocket servo lab — plant library, P→PI→PID step, Bode margins, lead compensator.",
            symbol: "slider.horizontal.3",
            synonyms: [
                "control systems", "pid", "bode", "lead compensator", "servo", "transfer function",
                "plant", "step response", "phase margin", "gain margin", "tuner", "g(s)",
            ]
        ),
    ]

    /// Color-coded grouping. Home IA is Field vs Toolkit (`ToolHomeAreaPolicy`);
    /// do not delete IDs here — relocate via the policy if a tool changes area.
    /// Open PRs can keep appending to these arrays.
    static let categories: [ToolCategory: [ToolID]] = [
        .field: [
            .wireAmpacity, .conductorCost, .conductorLength, .voltageDrop, .conduitFill, .motorFLA, .motorSpeed, .motorNameplate,
            .motorNameplateOCR,
            .receptacleSelector, .panelDirectory, .shortCircuit, .circularMils, .loadFactors,
            .necCircuit, .loadWorksheet, .cableSchedule, .isLoopVerifier,
        ],
        .power: [
            .ohmsLaw, .power, .transformer, .tapChanger, .reactance, .powerFactor, .harmonicsTHD,
            .rfLink, .batteryBank, .solarDesign, .upsSizing, .heaterDesign, .solenoidDesign, .magneticCircuit, .empEmc,
            .linearRegulator,
            .eBikeTorqueRPM, .eBikeSprocket, .eBikeRange, .eBikePackDesigner, .nickelStrip,
        ],
        .controls: [
            .signalScaling, .modbusAddress, .plcTimer, .timer555, .numberBase, .rackCurrent, .adcDac,
            .controlSystems,
        ],
        .homework: [
            .voltageDivider, .seriesParallel, .resistorColor, .phasorDiagram,
            .frequencyWave, .ledRC, .unitConverter, .fiberLink, .gaussianBeam, .transientCircuit, .diodeIV,
            .analogWorkbench, .noiseSNR, .instrumentationAmp,
        ],
        .sensors: [
            .wifiStatus, .bluetoothScan, .noiseMeter, .bubbleLevel,
            .magnetometer, .barometer, .motionSnapshot, .fieldPosition, .deviceHealth,
        ],
        .reference: [
            .referenceLibrary,
        ],
    ]

    static func tools(in category: ToolCategory) -> [ToolDefinition] {
        (categories[category] ?? []).compactMap { id in
            allTools.first { $0.id == id }
        }
    }

    /// Saved-job / deep-link IDs that stay off the toolbox list.
    private static let hiddenTools: [ToolDefinition] = [
        ToolDefinition(
            id: .powerWizard,
            kind: .calculator,
            title: "Power Wizard",
            subtitle: "DC, 1Ø, and 3Ø — amps, kW, kVA, or HP.",
            symbol: "wand.and.stars",
            synonyms: ["power wizard", "kva", "kw", "horsepower", "three phase", "3 phase", "single phase"]
        ),
    ]

    private static var allTools: [ToolDefinition] { tools + hiddenTools }

    static func matching(_ query: String) -> [ToolDefinition] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return tools }
        return tools.filter { $0.searchBlob.contains(q) }
    }

    static func tool(_ id: ToolID) -> ToolDefinition {
        allTools.first { $0.id == id } ?? tools[0]
    }

    /// Nearby tools on a tool screen. Titles stay the catalog titles — not a second list of products.
    static func related(to id: ToolID) -> [ToolDefinition] {
        (relatedIDs[id] ?? []).compactMap { relatedID in
            allTools.first { $0.id == relatedID }
        }
    }

    private static let relatedIDs: [ToolID: [ToolID]] = [
        .ohmsLaw: [.power, .voltageDivider, .ledRC],
        .power: [.ohmsLaw, .transformer, .powerFactor],
        .powerWizard: [.power, .motorFLA, .transformer],
        .voltageDrop: [.wireAmpacity, .conductorCost, .conductorLength, .conduitFill],
        .conduitFill: [.wireAmpacity, .voltageDrop, .conductorCost],
        .conductorCost: [.wireAmpacity, .voltageDrop, .conductorLength],
        .conductorLength: [.wireAmpacity, .voltageDrop, .circularMils],
        .transformer: [.power, .shortCircuit, .motorFLA],
        .timer555: [.plcTimer, .ledRC, .frequencyWave],
        .motorFLA: [.motorNameplateOCR, .motorNameplate, .motorSpeed],
        .wireAmpacity: [.voltageDrop, .conductorCost, .conductorLength],
        .receptacleSelector: [.wireAmpacity, .motorFLA, .voltageDrop],
        .voltageDivider: [.ohmsLaw, .seriesParallel, .ledRC],
        .seriesParallel: [.voltageDivider, .resistorColor, .ohmsLaw],
        .resistorColor: [.seriesParallel, .ledRC, .unitConverter],
        .unitConverter: [.circularMils, .signalScaling, .wireAmpacity],
        .frequencyWave: [.reactance, .timer555, .ledRC],
        .ledRC: [.ohmsLaw, .timer555, .resistorColor],
        .wifiStatus: [.bluetoothScan, .fieldPosition, .deviceHealth],
        .bluetoothScan: [.wifiStatus, .deviceHealth],
        .noiseMeter: [.deviceHealth],
        .bubbleLevel: [.motionSnapshot, .magnetometer, .solarDesign],
        .magnetometer: [.bubbleLevel, .solarDesign, .motionSnapshot],
        .barometer: [.fieldPosition, .deviceHealth],
        .motionSnapshot: [.bubbleLevel, .magnetometer],
        .fieldPosition: [.magnetometer, .wifiStatus, .barometer],
        .deviceHealth: [.wifiStatus, .noiseMeter],
        .reactance: [.powerFactor, .frequencyWave, .ohmsLaw],
        .powerFactor: [.power, .reactance, .transformer],
        .shortCircuit: [.transformer, .wireAmpacity, .motorFLA],
        .circularMils: [.conductorLength, .wireAmpacity, .voltageDrop],
        .loadFactors: [.panelDirectory, .power, .motorFLA],
        .signalScaling: [.modbusAddress, .plcTimer, .unitConverter, .controlSystems],
        .modbusAddress: [.signalScaling, .plcTimer],
        .plcTimer: [.timer555, .modbusAddress, .signalScaling, .controlSystems],
        .panelDirectory: [.loadFactors, .wireAmpacity, .motorFLA],
        .motorSpeed: [.motorNameplateOCR, .motorFLA, .motorNameplate],
        .rfLink: [.frequencyWave, .reactance, .unitConverter],
        .phasorDiagram: [.reactance, .power, .ohmsLaw],
        .numberBase: [.modbusAddress, .signalScaling, .unitConverter],
        .batteryBank: [.power, .solarDesign, .ohmsLaw, .eBikePackDesigner, .eBikeRange],
        .solarDesign: [.batteryBank, .power, .bubbleLevel, .magnetometer],
        .eBikeTorqueRPM: [.eBikeSprocket, .motorSpeed, .power],
        .eBikeSprocket: [.eBikeTorqueRPM, .eBikeRange, .motorSpeed],
        .eBikeRange: [.eBikePackDesigner, .batteryBank, .eBikeTorqueRPM],
        .eBikePackDesigner: [.batteryBank, .nickelStrip, .eBikeRange],
        .nickelStrip: [.eBikePackDesigner, .batteryBank, .circularMils],
        .referenceLibrary: [.wireAmpacity, .conduitFill, .receptacleSelector],
        .magneticCircuit: [.reactance, .transformer, .ohmsLaw],
        .fiberLink: [.rfLink, .gaussianBeam, .unitConverter],
        .gaussianBeam: [.fiberLink, .frequencyWave, .unitConverter],
        .transientCircuit: [.frequencyWave, .ledRC, .reactance],
        .rackCurrent: [.modbusAddress, .signalScaling, .plcTimer],
        .diodeIV: [.ledRC, .resistorColor, .ohmsLaw],
        .isLoopVerifier: [.receptacleSelector, .signalScaling, .panelDirectory],
        .tapChanger: [.transformer, .voltageDrop, .shortCircuit],
        .harmonicsTHD: [.powerFactor, .power, .reactance],
        .upsSizing: [.batteryBank, .power, .rackCurrent],
        .motorNameplate: [.motorNameplateOCR, .motorFLA, .motorSpeed],
        .motorNameplateOCR: [.motorNameplate, .motorFLA, .motorSpeed],
        .heaterDesign: [.ohmsLaw, .wireAmpacity, .power],
        .empEmc: [.rfLink, .magneticCircuit, .reactance],
        .necCircuit: [.wireAmpacity, .voltageDrop, .loadWorksheet],
        .loadWorksheet: [.loadFactors, .panelDirectory, .necCircuit],
        .cableSchedule: [.wireAmpacity, .conduitFill, .panelDirectory],
        .solenoidDesign: [.magneticCircuit, .reactance, .heaterDesign],
        .analogWorkbench: [.voltageDivider, .frequencyWave, .instrumentationAmp, .controlSystems],
        .noiseSNR: [.analogWorkbench, .rfLink, .ohmsLaw],
        .linearRegulator: [.voltageDivider, .power, .ledRC],
        .instrumentationAmp: [.analogWorkbench, .voltageDivider, .signalScaling],
        .adcDac: [.signalScaling, .numberBase, .analogWorkbench],
        .controlSystems: [.signalScaling, .plcTimer, .analogWorkbench, .transientCircuit],
    ]
}
