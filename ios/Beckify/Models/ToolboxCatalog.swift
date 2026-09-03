import Foundation

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

    var id: String { rawValue }
}

/// Grid sections on the toolbox home screen.
enum ToolCategory: String, CaseIterable, Identifiable {
    case field = "Field"
    case power = "Power & AC"
    case controls = "Controls"
    case homework = "Homework"
    case sensors = "Sensors"

    var id: String { rawValue }
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
    var symbol: String
    var synonyms: [String]

    var searchBlob: String {
        ([title, subtitle] + synonyms).joined(separator: " ").lowercased()
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
            subtitle: "K-factor VD with 3% / 5% notes and ampacity check.",
            symbol: "arrow.down.right.and.arrow.up.left",
            synonyms: ["voltage drop", "vd", "feeder", "branch", "ampacity", "awg", "circular mils", "k-factor"]
        ),
        ToolDefinition(
            id: .conduitFill,
            kind: .calculator,
            title: "Conduit Fill",
            subtitle: "THHN in EMT per Chapter 9 Table 1.",
            symbol: "circle.hexagongrid.fill",
            synonyms: ["conduit", "fill", "emt", "thhn", "raceway", "chapter 9", "40 percent", "annex c"]
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
            subtitle: "NEC Table 310.16, 75 °C column.",
            symbol: "cable.connector.horizontal",
            synonyms: ["wire size", "ampacity", "awg", "310.16", "75c", "kcmil", "copper", "aluminum", "conductor"]
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
            symbol: "bolt.trianglebadge.exclamationmark",
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
    ]

    /// Grid grouping for the home screen. Order inside a section is the order
    /// tools appear in the grid.
    static let categories: [ToolCategory: [ToolID]] = [
        .field: [
            .wireAmpacity, .voltageDrop, .conduitFill, .motorFLA,
            .receptacleSelector, .shortCircuit, .circularMils, .loadFactors,
        ],
        .power: [
            .ohmsLaw, .power, .transformer, .reactance, .powerFactor,
        ],
        .controls: [
            .signalScaling, .modbusAddress, .plcTimer, .timer555,
        ],
        .homework: [
            .voltageDivider, .seriesParallel, .resistorColor,
            .frequencyWave, .ledRC, .unitConverter,
        ],
        .sensors: [
            .wifiStatus, .bluetoothScan, .noiseMeter, .bubbleLevel,
            .magnetometer, .barometer, .motionSnapshot, .fieldPosition, .deviceHealth,
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
        .power: [.ohmsLaw, .transformer, .motorFLA],
        .powerWizard: [.power, .motorFLA, .transformer],
        .voltageDrop: [.wireAmpacity, .conduitFill, .power],
        .conduitFill: [.wireAmpacity, .voltageDrop],
        .transformer: [.power, .wireAmpacity, .motorFLA],
        .timer555: [.ledRC, .frequencyWave],
        .motorFLA: [.wireAmpacity, .power, .transformer],
        .wireAmpacity: [.voltageDrop, .conduitFill, .motorFLA],
        .receptacleSelector: [.wireAmpacity, .motorFLA, .voltageDrop],
        .voltageDivider: [.ohmsLaw, .seriesParallel, .ledRC],
        .seriesParallel: [.voltageDivider, .resistorColor, .ohmsLaw],
        .resistorColor: [.seriesParallel, .ledRC, .unitConverter],
        .unitConverter: [.frequencyWave, .voltageDrop, .wireAmpacity],
        .frequencyWave: [.timer555, .ledRC, .unitConverter],
        .ledRC: [.ohmsLaw, .timer555, .resistorColor],
        .wifiStatus: [.bluetoothScan, .fieldPosition, .deviceHealth],
        .bluetoothScan: [.wifiStatus, .deviceHealth],
        .noiseMeter: [.deviceHealth],
        .bubbleLevel: [.motionSnapshot, .magnetometer, .fieldPosition],
        .magnetometer: [.bubbleLevel, .fieldPosition, .motionSnapshot],
        .barometer: [.fieldPosition, .deviceHealth],
        .motionSnapshot: [.bubbleLevel, .magnetometer],
        .fieldPosition: [.magnetometer, .wifiStatus, .barometer],
        .deviceHealth: [.wifiStatus, .noiseMeter],
    ]
}
