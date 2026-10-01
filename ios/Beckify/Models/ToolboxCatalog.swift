import Foundation
import BeckifyMath

enum ToolID: String, Codable, CaseIterable, Identifiable {
    case ohmsLaw
    case power
    case threePhasePower
    case powerWizard
    case voltageDrop
    case conduitFill
    case cableLadder
    case equipmentGround
    case transformer
    case timer555
    case motorFLA
    case wireAmpacity
    case flexibleCable
    case conductorCost
    case conductorLength
    case voltageDivider
    case seriesParallel
    case resistorColor
    case unitConverter
    case frequencyWave
    case ledRC
    case wifiStatus
    case cellularStatus
    case bluetoothScan
    case noiseMeter
    case acousticImager
    case setupCheck
    case bubbleLevel
    case magnetometer
    case barometer
    case motionSnapshot
    case stillnessWatch
    case breathFlute
    case coupledVibration
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
    case lookCheck
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
    case controlStrategies
    case electronicsLab
    case phasorImpedance
    case ul508aPanelLab
    case magneticsLab
    case emFields
    case statistics
    case spanishTranslator

    var id: String { rawValue }
}

/// Color-coded shelves. Home IA is Field vs Toolkit (`ToolHomeAreaPolicy`
/// owns area + shelf); these cases stay stable so open catalog PRs can keep
/// merging additively. Category color is display/grouping aligned to shelves.
enum ToolCategory: String, CaseIterable, Identifiable {
    case field = "Field"
    case power = "Power & AC"
    case controls = "Controls"
    case homework = "Homework"
    case sensors = "Sensors"
    case reference = "Reference"
    case analysis = "Analysis"

    var id: String { rawValue }

    /// Operator-facing shelf title. Raw values stay unchanged for merge stability.
    var displayName: String {
        switch self {
        case .field: return "Jobsite"
        case .power: return "Power & AC"
        case .controls: return "Controls"
        case .homework: return "Bench"
        case .sensors: return "Instruments"
        case .reference: return "Reference"
        case .analysis: return "Analysis"
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
            return "Basics, bench, and references."
        }
    }
}

extension ToolShelfKind {
    var title: String {
        switch self {
        case .jobsite: return "Jobsite"
        case .power: return "Power & AC"
        case .controls: return "Controls"
        case .magnetics: return "Magnetics & Fields"
        case .analysis: return "Analysis"
        case .instruments: return "Instruments"
        case .basics: return "Basics"
        case .bench: return "Bench"
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
        case .magnetics: return .power
        case .analysis: return .analysis
        case .instruments: return .sensors
        case .basics, .bench: return .homework
        case .reference: return .reference
        }
    }
}

extension ToolboxCatalog {
    /// Display/grouping color for a tool. Always follows `ToolHomeAreaPolicy.shelf`
    /// so a Toolkit bench tool never wears Field Power teal.
    static func category(of id: ToolID) -> ToolCategory? {
        shelf(of: id).category
    }

    /// Field (jobsite) vs Toolkit (basics / bench / reference). Policy is canonical.
    static func area(of id: ToolID) -> ToolHomeArea {
        ToolHomeAreaPolicy.area(forToolID: id.rawValue)
    }

    static func shelf(of id: ToolID) -> ToolShelfKind {
        ToolHomeAreaPolicy.shelf(forToolID: id.rawValue)
    }

    static func tools(in area: ToolHomeArea) -> [ToolDefinition] {
        tools.filter { Self.area(of: $0.id) == area }
    }

    /// Shelf membership comes from `ToolHomeAreaPolicy`. Category arrays supply
    /// preferred grid order only; extras (policy members not yet listed) append.
    static func tools(on shelf: ToolShelfKind) -> [ToolDefinition] {
        let members = tools.filter { Self.shelf(of: $0.id) == shelf }
        let preferred = categories[shelf.category] ?? []
        var seen = Set<ToolID>()
        var ordered: [ToolDefinition] = []
        for id in preferred {
            if let tool = members.first(where: { $0.id == id }), seen.insert(id).inserted {
                ordered.append(tool)
            }
        }
        for tool in members where seen.insert(tool.id).inserted {
            ordered.append(tool)
        }
        return ordered
    }
}

enum ToolKind: String, Codable {
    case calculator
    /// Bench / homework tools. About / How it works and Show Work default open.
    case homework
    case sensor
}

struct ToolDefinition: Identifiable {
    var id: ToolID
    var kind: ToolKind
    var title: String
    var subtitle: String
    /// SF Symbol used only as a fallback / related-row chevron context — primary
    /// artwork is the Beckify instrument glyph set (`IconWell` / `ToolGlyph` —
    /// solid fill + even-odd holes; open marks stay stroke).
    var symbol: String
    var synonyms: [String]
    /// Live converters update on valid input; explicit tools require Calculate.
    var calculationMode: CalculationMode

    var searchBlob: String {
        ([title, subtitle] + synonyms).joined(separator: " ").lowercased()
    }

    /// Data-driven About / how-it-works copy. Nil only if the catalog ID is unknown.
    var howItWorks: ToolHowItWorks? {
        ToolHowItWorksCatalog.copy(forToolID: id.rawValue)
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
    /// Listed tools plus hidden deep-link IDs (Power Wizard). Every id needs
    /// `ToolHowItWorksCatalog` copy — Linux tests fail if a new ToolID is omitted.
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
            id: .threePhasePower,
            kind: .calculator,
            title: "Three-Phase Power",
            subtitle: "Balanced Y and Δ line, phase, and P + jQ.",
            symbol: "triangle",
            synonyms: [
                "three phase", "3 phase", "wye", "delta", "y-y", "y-delta", "delta-wye", "delta-delta",
                "line voltage", "phase voltage", "power triangle", "complex power",
            ]
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
            subtitle: "Chapter 9 fill with a to-scale bore, wall, and conductor packing.",
            symbol: "circle.hexagongrid.fill",
            synonyms: ["conduit", "fill", "emt", "thhn", "raceway", "chapter 9", "40 percent", "annex c", "mixed sizes", "cross section", "nipple"]
        ),
        ToolDefinition(
            id: .cableLadder,
            kind: .calculator,
            title: "Cable Ladder",
            subtitle: "Article 392 fill, hangers, and a tray cross-section.",
            symbol: "rectangle.split.3x1",
            synonyms: [
                "cable ladder", "cable tray", "tray fill", "article 392", "nema ve 1",
                "tc-er", "tray cable", "hanger", "392", "ladder tray",
            ]
        ),
        ToolDefinition(
            id: .equipmentGround,
            kind: .calculator,
            title: "Equipment Grounding",
            subtitle: "NEC Table 250.122 minimum EGC from the OCPD, copper or aluminum.",
            symbol: "shield.lefthalf.filled",
            synonyms: [
                "egc", "equipment grounding", "equipment grounding conductor", "ground wire",
                "grounding conductor", "equipment ground", "250.122", "table 250.122",
                "copper ground", "aluminum ground", "green wire",
            ]
        ),
        ToolDefinition(
            id: .transformer,
            kind: .calculator,
            title: "Transformer Sizing",
            subtitle: "Standard kVA, 450.3(B), and a winding diagram.",
            symbol: "rectangle.split.2x1.fill",
            synonyms: [
                "transformer", "xfmr", "kva", "450.3", "ocpd", "primary", "secondary", "note 1",
                "high-leg", "high leg", "delta-wye", "delta wye", "wye-delta", "winding", "phasor",
                "wire color", "conductor color", "corner-grounded", "zig-zag", "open delta", "buck-boost",
                "impedance", "referred", "turns ratio", "line loss",
            ]
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
            id: .flexibleCable,
            kind: .calculator,
            title: "Flexible Cable Ampacity",
            subtitle: "Type W and SO/SJO cord from NEC Table 400.5, sized up to 400 A.",
            symbol: "cable.connector",
            synonyms: [
                "type w", "type-w", "soow", "so cord", "sjo", "sjow", "sjoow", "sto", "sjt",
                "portable cord", "flexible cord", "flexible cable", "mining cable", "400.5",
                "article 400", "cord ampacity", "portable power",
            ]
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
            subtitle: "Length from a milliohm (mΩ) reading — end-to-end or short-to-parallel — plus estimated copper or aluminum weight.",
            symbol: "ruler",
            synonyms: [
                "conductor length", "length from resistance", "length from r", "resistance length",
                "milliohm", "mohm", "mΩ", "cable length", "loop resistance",
                "shorted parallel", "short to parallel", "shorted to parallel",
                "fault location resistance", "end to end", "end-to-end",
                "kelvin", "duct bank", "circular mils", "awg", "copper", "aluminum",
                "copper weight", "aluminum weight", "conductor weight",
            ]
        ),
        ToolDefinition(
            id: .receptacleSelector,
            kind: .calculator,
            title: "Receptacle Selector",
            subtitle: "NEMA, IEC 60309, household, and Meltric faces through 400 A — schematic pinout and cited PNs.",
            symbol: "poweroutlet.type.b",
            synonyms: [
                "receptacle", "outlet", "NEMA", "L5-30", "pin and sleeve", "Meltric", "Decontactor",
                "Hubbell", "twist lock", "IEC 60309", "Schuko", "BS 1363", "Type F", "Type E", "Type I",
            ]
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
            subtitle: "Online / Captive, Apple strength %/bars, TCP RTT. Not a dBm meter.",
            symbol: "wifi",
            synonyms: [
                "wifi", "wi-fi", "wlan", "ssid", "rssi", "signal", "hotspot", "network path",
                "heatmap", "coverage", "dbm", "rtt", "latency", "link quality",
                "online captive", "captive", "portal", "hotspot detect", "connectivity", "local ip",
            ]
        ),
        ToolDefinition(
            id: .cellularStatus,
            kind: .sensor,
            title: "Cellular Path",
            subtitle: "Online / Captive, generation + TCP RTT gauges, carrier / RAT. Not RSRP / dBm.",
            symbol: "antenna.radiowaves.left.and.right",
            synonyms: [
                "cellular", "cell", "lte", "5g", "nr", "4g", "3g", "wcdma", "carrier",
                "mcc", "mnc", "plmn", "rsrp", "rsrq", "sinr", "rssi", "dbm", "dual sim",
                "radio access", "telephony", "coretelephony", "signal", "rtt", "latency",
                "online captive", "captive", "portal", "connectivity",
            ]
        ),
        ToolDefinition(
            id: .bluetoothScan,
            kind: .sensor,
            title: "BLE Scanner",
            subtitle: "RF activity, room mix, churn, and radar. Device count ≠ people.",
            symbol: "dot.radiowaves.left.and.right",
            synonyms: [
                "bluetooth", "ble", "corebluetooth", "peripheral", "rssi", "beacon",
                "radar", "proximity", "layout", "manufacturer", "advertisement", "company id",
                "activity", "churn", "density", "rf activity",
            ]
        ),
        ToolDefinition(
            id: .noiseMeter,
            kind: .sensor,
            title: "Noise Meter",
            subtitle: "Uncalibrated dBFS plus an audible-band spectrum. Not an SLM.",
            symbol: "mic.fill",
            synonyms: ["noise", "decibel", "db", "spl", "microphone", "sound", "dbfs", "fft", "spectrum"]
        ),
        ToolDefinition(
            id: .acousticImager,
            kind: .sensor,
            title: "Acoustic Imager",
            subtitle: "Mic level, spectrum, and time activity. Not a sound camera.",
            symbol: "waveform",
            synonyms: [
                "acoustic", "imager", "spectrum", "fft", "spectrogram",
                "level", "time activity", "microphone",
            ]
        ),
        ToolDefinition(
            id: .setupCheck,
            kind: .sensor,
            title: "Room & Rig Check",
            subtitle: "Leave it open, then run a relative listen test. Not a lab mic.",
            symbol: "speaker.wave.2.fill",
            synonyms: [
                "room & rig check", "room and rig", "setup check", "speaker setup", "acoustic setup",
                "room", "rig", "audiophile", "listening", "rta", "test",
                "fft", "spectrogram", "pink noise", "sweep", "speaker",
                "frequency response", "crest", "waterfall",
            ]
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
            subtitle: "Heading, |B| in µT, and a Mag Sweep delta. DC field only.",
            symbol: "location.north.circle.fill",
            synonyms: ["compass", "magnetometer", "tesla", "microtesla", "gauss", "magnetic", "heading", "mag sweep", "sweep", "steel", "speaker"]
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
            subtitle: "Gravity and user acceleration snapshot. Not a machine spectrum.",
            symbol: "gyroscope",
            synonyms: ["g-force", "gforce", "vibration", "accelerometer", "motion", "imu"]
        ),
        ToolDefinition(
            id: .stillnessWatch,
            kind: .sensor,
            title: "Stillness Anomaly Watch",
            subtitle: "Baseline ticks for |B|, pressure, mic impulses, and BLE advertisers. Not a presence meter.",
            symbol: "dot.radiowaves.left.and.right",
            synonyms: ["stillness", "anomaly", "baseline", "impulse", "advertisers", "pressure", "watch"]
        ),
        ToolDefinition(
            id: .breathFlute,
            kind: .sensor,
            title: "Breath Flute",
            subtitle: "Blow the bottom edge. Silent until you blow. Big finger holes.",
            symbol: "music.note",
            synonyms: ["flute", "breath", "blow", "blow here", "bottom mic", "finger holes", "toy", "play", "pitch", "tone"]
        ),
        ToolDefinition(
            id: .coupledVibration,
            kind: .sensor,
            title: "Coupled Vibration",
            subtitle: "Phone-on-machine user-acceleration RMS and spectrum. Relative A/B only.",
            symbol: "waveform.path",
            synonyms: ["vibration", "duct", "machine", "spectrum", "rms", "coupled", "fft"]
        ),
        ToolDefinition(
            id: .fieldPosition,
            kind: .sensor,
            title: "Position",
            subtitle: "GPS coordinates, speed, altitude, field distance.",
            symbol: "location.fill",
            synonyms: ["gps", "location", "coordinates", "latitude", "longitude", "distance", "haversine", "position"]
        ),
        ToolDefinition(
            id: .deviceHealth,
            kind: .sensor,
            title: "Device Health",
            subtitle: "Battery, thermal, storage, and uptime. Diagnostics only.",
            symbol: "battery.100",
            synonyms: ["battery", "thermal", "diagnostics", "temperature", "charge", "storage", "uptime", "low power", "disk", "brightness"]
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
            subtitle: "Photo a schedule. On-device Vision, scan quality, editable rows, then confirm demand.",
            symbol: "list.bullet.rectangle",
            synonyms: ["panel", "directory", "schedule", "circuit", "breaker", "ocr", "sticker", "legend", "demand", "capacity", "vision", "confirm", "analyze"]
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
            id: .spanishTranslator,
            kind: .sensor,
            title: "Spanish Translator",
            subtitle: "Speak English, hear Cuban / Florida LatAm Spanish (Beckify AI, on-device fallback) — loud playback.",
            symbol: "character.bubble",
            synonyms: ["translator", "spanish", "cuban", "florida spanish", "translate", "interpreter", "español", "latam", "miami", "speech"]
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
            subtitle: "Take a picture of a plate; Vision first, optional Analyze, then you confirm.",
            symbol: "text.viewfinder",
            synonyms: ["ocr", "nameplate", "camera", "vision", "motor plate", "hp", "rpm", "fla", "scan", "analyze"]
        ),
        ToolDefinition(
            id: .lookCheck,
            kind: .calculator,
            title: "Look Check",
            subtitle: "Take or choose a photo for a playful look verdict plus a roast. Entertainment only.",
            symbol: "person.crop.rectangle",
            synonyms: [
                "look check", "looks good", "looks bad", "selfie", "appearance", "photo verdict",
                "analyze look", "camera", "lighting", "framing", "expression", "entertainment",
                "roast",
            ]
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
            subtitle: "Pocket servo lab — plant library, PID tuning overlays, Bode margins, lead compensator.",
            symbol: "slider.horizontal.3",
            synonyms: [
                "control systems", "pid", "pid tuning", "ziegler nichols", "bode", "lead compensator",
                "servo", "transfer function", "plant", "step response", "phase margin", "gain margin",
                "tuner", "g(s)", "overlay",
            ]
        ),
        ToolDefinition(
            id: .ul508aPanelLab,
            kind: .calculator,
            title: "UL 508A Panel Lab",
            subtitle: "SCCR, feeder and branch sizing, wire, enclosure, control power, and the nameplate.",
            symbol: "square.split.2x2",
            synonyms: [
                "ul 508a", "508a", "industrial control panel", "sccr", "short circuit current rating",
                "supplement sb", "sb4.1", "feeder", "branch circuit", "panel nameplate", "nema",
                "enclosure", "control transformer", "wire color", "mtw", "panel builder",
            ]
        ),
        ToolDefinition(
            id: .controlStrategies,
            kind: .calculator,
            title: "Control Strategies",
            subtitle: "Compare bang-bang, PID, MPC, and ADRC — plots and a picker. Not a tuner.",
            symbol: "arrow.triangle.branch",
            synonyms: [
                "control strategies", "bang bang", "bang-bang", "hysteresis", "mpc", "model predictive",
                "adrc", "sliding mode", "smc", "fuzzy", "anfis", "drl", "reinforcement", "pinn",
                "gain schedule", "disturbance", "chattering", "selector", "servo strategy",
            ]
        ),
        ToolDefinition(
            id: .electronicsLab,
            kind: .calculator,
            title: "Electronics Lab",
            subtitle: "Schematics and a solderless breadboard — node voltages, branch currents, and solve-any-value.",
            symbol: "point.3.connected.trianglepath.dotted",
            synonyms: [
                "electronics lab", "schematic", "breadboard", "bjt", "mosfet", "op amp", "op-amp", "555",
                "thevenin", "norton", "rectifier", "clipper", "clamper", "7 segment", "seven segment",
                "impedance match", "l match", "quarter wave", "stub", "complex", "polar", "phasor",
                "voltage divider", "kirchhoff", "cmos", "buck", "class a", "led flasher",
            ],
            calculationMode: .live
        ),
        ToolDefinition(
            id: .phasorImpedance,
            kind: .calculator,
            title: "Phasors & Impedance",
            subtitle: "Sinusoids, lead and lag, R L C laws, and Z with admittance.",
            symbol: "wave.3.right.circle",
            synonyms: ["phasor", "impedance", "admittance", "lead lag", "sinusoid", "reactance", "polar", "phasor diagram", "quick sum", "three phase", "resultant"],
            calculationMode: .live
        ),
        ToolDefinition(
            id: .magneticsLab,
            kind: .calculator,
            title: "Magnetics Lab",
            subtitle: "Core reluctance, flux, inductance, and a transformer, motor, or generator check.",
            symbol: "atom",
            synonyms: [
                "magnetics", "magnetic circuit", "reluctance", "mmf", "flux", "air gap",
                "inductance", "stacking", "fringing", "three leg", "transformer", "generator",
            ],
            calculationMode: .live
        ),
        ToolDefinition(
            id: .emFields,
            kind: .calculator,
            title: "EM Fields",
            subtitle: "Induced emf, point charges, Lorentz force, and a vector check.",
            symbol: "arrow.up.and.down.and.arrow.left.and.right",
            synonyms: [
                "faraday", "induced emf", "lorentz", "point charge", "electric field",
                "vector", "cylindrical", "spherical", "divergence", "curl",
            ],
            calculationMode: .live
        ),
        ToolDefinition(
            id: .statistics,
            kind: .calculator,
            title: "Statistics",
            subtitle: "Distributions, rescale, paired normals, and correlation.",
            symbol: "chart.bar.xaxis",
            synonyms: [
                "statistics", "distribution", "normal", "gaussian", "histogram", "standard deviation",
                "mean", "correlation", "covariance", "bivariate", "binomial", "poisson", "uniform",
                "exponential", "dice", "simulation", "monte carlo", "rescale", "conditional",
            ],
            calculationMode: .live
        ),
    ]

    /// Display/grouping colors aligned to `ToolHomeAreaPolicy` shelves.
    /// Policy owns home area + shelf; these arrays are color bags and preferred
    /// grid order. Keep membership in sync with the policy — a tool’s category
    /// color must not imply a different home than the policy.
    /// Open PRs can keep appending to these arrays after updating the policy.
    static let categories: [ToolCategory: [ToolID]] = [
        .field: [
            .wireAmpacity, .conductorCost, .conductorLength, .voltageDrop, .conduitFill, .cableLadder, .equipmentGround, .flexibleCable, .motorFLA, .motorSpeed, .motorNameplate,
            .motorNameplateOCR, .lookCheck,
            .receptacleSelector, .shortCircuit, .circularMils, .loadFactors,
            .necCircuit, .isLoopVerifier,
        ],
        .power: [
            .power, .threePhasePower, .transformer, .tapChanger, .powerFactor, .harmonicsTHD,
            .batteryBank, .solarDesign, .upsSizing,
        ],
        .controls: [
            .ul508aPanelLab,
            .signalScaling, .modbusAddress, .plcTimer, .rackCurrent,
            .controlSystems, .controlStrategies, .phasorImpedance,
        ],
        .analysis: [
            .statistics,
        ],
        .homework: [
            .ohmsLaw, .voltageDivider, .seriesParallel, .resistorColor, .timer555,
            .frequencyWave, .ledRC, .unitConverter,
            .electronicsLab, .reactance, .numberBase, .magneticCircuit,
            .fiberLink, .gaussianBeam, .transientCircuit, .diodeIV, .rfLink,
            .analogWorkbench, .noiseSNR, .linearRegulator, .instrumentationAmp, .adcDac,
            .heaterDesign, .solenoidDesign, .empEmc,
            .eBikeTorqueRPM, .eBikeSprocket, .eBikeRange, .eBikePackDesigner, .nickelStrip,
        ],
        .sensors: [
            .wifiStatus, .cellularStatus, .bluetoothScan, .noiseMeter, .acousticImager, .setupCheck, .breathFlute, .bubbleLevel,
            .magnetometer, .barometer, .stillnessWatch, .motionSnapshot, .coupledVibration, .fieldPosition, .deviceHealth,
        ],
        .reference: [
            .referenceLibrary, .spanishTranslator, .panelDirectory, .loadWorksheet, .cableSchedule,
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
            id: .phasorDiagram,
            kind: .homework,
            title: "Quick sum",
            subtitle: "2–3 phasors and their resultant. The same sum lives in Phasors & Impedance.",
            symbol: "chart.dots.scatter",
            synonyms: ["phasor diagram", "quick sum", "vector", "three phase", "balanced", "polar", "angle", "resultant"]
        ),
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
        .power: [.threePhasePower, .ohmsLaw, .powerFactor],
        .threePhasePower: [.power, .transformer, .phasorImpedance],
        .powerWizard: [.power, .motorFLA, .transformer],
        .voltageDrop: [.wireAmpacity, .equipmentGround, .conductorCost, .conduitFill],
        .conduitFill: [.ul508aPanelLab, .cableLadder, .equipmentGround, .flexibleCable, .wireAmpacity, .voltageDrop],
        .cableLadder: [.conduitFill, .cableSchedule, .equipmentGround, .referenceLibrary],
        .equipmentGround: [.ul508aPanelLab, .cableLadder, .conduitFill, .flexibleCable, .wireAmpacity, .necCircuit],
        .conductorCost: [.wireAmpacity, .voltageDrop, .conductorLength],
        .conductorLength: [.wireAmpacity, .voltageDrop, .circularMils],
        .transformer: [.threePhasePower, .power, .shortCircuit, .motorFLA],
        .timer555: [.electronicsLab, .plcTimer, .ledRC, .frequencyWave],
        .motorFLA: [.ul508aPanelLab, .motorNameplateOCR, .motorNameplate, .motorSpeed],
        .wireAmpacity: [.ul508aPanelLab, .flexibleCable, .equipmentGround, .voltageDrop, .conductorCost],
        .flexibleCable: [.wireAmpacity, .conduitFill, .equipmentGround, .cableSchedule],
        .receptacleSelector: [.wireAmpacity, .motorFLA, .voltageDrop],
        .voltageDivider: [.electronicsLab, .ohmsLaw, .seriesParallel, .ledRC],
        .seriesParallel: [.voltageDivider, .resistorColor, .ohmsLaw],
        .resistorColor: [.seriesParallel, .ledRC, .unitConverter],
        .unitConverter: [.circularMils, .signalScaling, .wireAmpacity],
        .frequencyWave: [.reactance, .timer555, .ledRC],
        .ledRC: [.ohmsLaw, .timer555, .resistorColor],
        .wifiStatus: [.cellularStatus, .bluetoothScan, .deviceHealth],
        .cellularStatus: [.wifiStatus, .rfLink, .bluetoothScan],
        .bluetoothScan: [.stillnessWatch, .wifiStatus, .cellularStatus],
        .noiseMeter: [.setupCheck, .acousticImager, .breathFlute],
        .acousticImager: [.setupCheck, .noiseMeter, .breathFlute],
        .setupCheck: [.noiseMeter, .acousticImager, .breathFlute],
        .breathFlute: [.noiseMeter, .acousticImager, .setupCheck],
        .bubbleLevel: [.motionSnapshot, .magnetometer, .solarDesign],
        .magnetometer: [.stillnessWatch, .bubbleLevel, .motionSnapshot],
        .barometer: [.stillnessWatch, .fieldPosition, .deviceHealth],
        .stillnessWatch: [.magnetometer, .barometer, .noiseMeter, .bluetoothScan],
        .motionSnapshot: [.coupledVibration, .bubbleLevel, .magnetometer],
        .coupledVibration: [.motionSnapshot, .bubbleLevel],
        .fieldPosition: [.magnetometer, .wifiStatus, .barometer],
        .deviceHealth: [.wifiStatus, .noiseMeter, .acousticImager],
        .reactance: [.phasorImpedance, .powerFactor, .frequencyWave, .ohmsLaw],
        .powerFactor: [.power, .reactance, .transformer],
        .shortCircuit: [.ul508aPanelLab, .transformer, .wireAmpacity, .motorFLA],
        .circularMils: [.conductorLength, .wireAmpacity, .voltageDrop],
        .loadFactors: [.panelDirectory, .power, .motorFLA],
        .signalScaling: [.modbusAddress, .plcTimer, .unitConverter, .controlSystems, .controlStrategies],
        .modbusAddress: [.signalScaling, .plcTimer],
        .plcTimer: [.timer555, .modbusAddress, .signalScaling, .controlSystems, .controlStrategies],
        .panelDirectory: [.ul508aPanelLab, .equipmentGround, .loadWorksheet, .necCircuit],
        .motorSpeed: [.motorNameplateOCR, .motorFLA, .motorNameplate],
        .rfLink: [.cellularStatus, .frequencyWave, .unitConverter],
        .phasorDiagram: [.phasorImpedance, .reactance, .power, .ohmsLaw],
        .numberBase: [.modbusAddress, .signalScaling, .unitConverter],
        .batteryBank: [.power, .solarDesign, .ohmsLaw, .eBikePackDesigner, .eBikeRange],
        .solarDesign: [.batteryBank, .power, .bubbleLevel, .magnetometer],
        .eBikeTorqueRPM: [.eBikeSprocket, .motorSpeed, .power],
        .eBikeSprocket: [.eBikeTorqueRPM, .eBikeRange, .motorSpeed],
        .eBikeRange: [.eBikePackDesigner, .batteryBank, .eBikeTorqueRPM],
        .eBikePackDesigner: [.batteryBank, .nickelStrip, .eBikeRange],
        .nickelStrip: [.eBikePackDesigner, .batteryBank, .circularMils],
        .referenceLibrary: [.wireAmpacity, .conduitFill, .receptacleSelector, .spanishTranslator],
        .spanishTranslator: [.referenceLibrary, .noiseMeter, .lookCheck],
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
        .lookCheck: [.motorNameplateOCR, .panelDirectory],
        .heaterDesign: [.ohmsLaw, .wireAmpacity, .power],
        .empEmc: [.rfLink, .magneticCircuit, .reactance],
        .necCircuit: [.equipmentGround, .wireAmpacity, .voltageDrop],
        .loadWorksheet: [.loadFactors, .panelDirectory, .necCircuit],
        .cableSchedule: [.ul508aPanelLab, .cableLadder, .flexibleCable, .equipmentGround, .conduitFill, .panelDirectory],
        .solenoidDesign: [.magneticCircuit, .reactance, .heaterDesign],
        .analogWorkbench: [.electronicsLab, .voltageDivider, .frequencyWave, .instrumentationAmp, .controlSystems],
        .noiseSNR: [.statistics, .analogWorkbench, .rfLink, .ohmsLaw],
        .linearRegulator: [.voltageDivider, .power, .ledRC],
        .instrumentationAmp: [.analogWorkbench, .voltageDivider, .signalScaling],
        .adcDac: [.signalScaling, .numberBase, .analogWorkbench],
        .controlSystems: [.controlStrategies, .electronicsLab, .ul508aPanelLab, .signalScaling, .plcTimer, .analogWorkbench],
        .controlStrategies: [.controlSystems, .electronicsLab, .ul508aPanelLab, .signalScaling, .plcTimer, .analogWorkbench],
        .electronicsLab: [.phasorImpedance, .controlSystems, .analogWorkbench, .timer555, .voltageDivider],
        .phasorImpedance: [.electronicsLab, .reactance, .frequencyWave, .threePhasePower],
        .ul508aPanelLab: [.motorFLA, .equipmentGround, .conduitFill, .wireAmpacity, .panelDirectory, .cableSchedule, .transformer],
        .magneticsLab: [.emFields, .transformer, .solenoidDesign, .magneticCircuit],
        .emFields: [.magneticsLab, .magnetometer, .solenoidDesign],
        .statistics: [.noiseSNR, .unitConverter, .harmonicsTHD],
    ]
}
