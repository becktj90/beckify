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
    case wifiStatus
    case bluetoothScan
    case noiseMeter
    case bubbleLevel
    case magnetometer
    case barometer
    case motionSnapshot
    case fieldPosition
    case deviceHealth

    var id: String { rawValue }
}

enum ToolKind: String, Codable {
    case calculator
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
            title: "DC / AC Power",
            subtitle: "P = VI, 1Ø and 3Ø kVA / kW / kVAR.",
            symbol: "bolt.fill",
            synonyms: ["dc power", "ac power", "watts", "kvar", "apparent", "true power", "reactive"]
        ),
        ToolDefinition(
            id: .powerWizard,
            kind: .calculator,
            title: "Power Wizard",
            subtitle: "DC, 1Ø, and 3Ø — amps, kW, kVA, or HP.",
            symbol: "wand.and.stars",
            synonyms: ["power wizard", "kva", "kw", "horsepower", "three phase", "3 phase", "single phase", "fla estimate"]
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
            id: .wifiStatus,
            kind: .sensor,
            title: "Wi-Fi Path",
            subtitle: "Public Network path only — no invented RSSI.",
            symbol: "wifi",
            synonyms: ["wifi", "wi-fi", "wlan", "ssid", "rssi", "signal", "hotspot", "network path"]
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
    ]

    static func matching(_ query: String) -> [ToolDefinition] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return tools }
        return tools.filter { $0.searchBlob.contains(q) }
    }

    static func tool(_ id: ToolID) -> ToolDefinition {
        tools.first { $0.id == id } ?? tools[0]
    }
}
