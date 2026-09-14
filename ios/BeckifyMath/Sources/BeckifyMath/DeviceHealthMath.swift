import Foundation

/// Public UIDevice / ProcessInfo thermal band. Not a thermometer reading.
public enum DeviceHealthThermal: String, Equatable, Sendable {
    case nominal
    case fair
    case serious
    case critical
    case unknown
}

/// Public UIDevice charge state. Not pack cycle health.
public enum DeviceHealthCharge: String, Equatable, Sendable {
    case charging
    case full
    case unplugged
    case unknown
}

/// Result-row tone the iOS view maps onto Theme colors.
public enum DeviceHealthTone: String, Equatable, Sendable {
    case good
    case warn
    case bad
    case muted
}

/// Formatted Device Health snapshot for sticky / copy / saved jobs.
public struct DeviceHealthSnapshot: Equatable, Sendable {
    public var battery: String
    public var charge: String
    public var chargeNote: String
    public var lowPower: String
    public var lowPowerNote: String
    public var thermal: String
    public var thermalMeaning: String
    public var freeImportant: String
    public var freeOpportunistic: String
    public var volumeTotal: String
    public var model: String
    public var identifier: String
    public var system: String
    public var uptime: String
    public var uptimeLabel: String
    public var booted: String
    public var brightness: String
    public var ram: String
    public var appHeadroom: String
    public var processors: String

    public var batteryTone: DeviceHealthTone
    public var chargeTone: DeviceHealthTone
    public var lowPowerTone: DeviceHealthTone
    public var thermalTone: DeviceHealthTone

    public init(
        battery: String,
        charge: String,
        chargeNote: String,
        lowPower: String,
        lowPowerNote: String,
        thermal: String,
        thermalMeaning: String,
        freeImportant: String,
        freeOpportunistic: String,
        volumeTotal: String,
        model: String,
        identifier: String,
        system: String,
        uptime: String,
        uptimeLabel: String,
        booted: String,
        brightness: String,
        ram: String,
        appHeadroom: String,
        processors: String,
        batteryTone: DeviceHealthTone,
        chargeTone: DeviceHealthTone,
        lowPowerTone: DeviceHealthTone,
        thermalTone: DeviceHealthTone
    ) {
        self.battery = battery
        self.charge = charge
        self.chargeNote = chargeNote
        self.lowPower = lowPower
        self.lowPowerNote = lowPowerNote
        self.thermal = thermal
        self.thermalMeaning = thermalMeaning
        self.freeImportant = freeImportant
        self.freeOpportunistic = freeOpportunistic
        self.volumeTotal = volumeTotal
        self.model = model
        self.identifier = identifier
        self.system = system
        self.uptime = uptime
        self.uptimeLabel = uptimeLabel
        self.booted = booted
        self.brightness = brightness
        self.ram = ram
        self.appHeadroom = appHeadroom
        self.processors = processors
        self.batteryTone = batteryTone
        self.chargeTone = chargeTone
        self.lowPowerTone = lowPowerTone
        self.thermalTone = thermalTone
    }

    /// Bottom sticky strip: the few numbers a gloved thumb needs.
    public var sticky: String {
        var parts: [String] = []
        if battery != "—" { parts.append(battery) }
        parts.append(thermal)
        if lowPower == "On" { parts.append("LPM on") }
        if freeImportant != "—" { parts.append("\(freeImportant) free") }
        if parts.isEmpty { return thermal }
        return parts.joined(separator: "  ·  ")
    }

    /// Clipboard / toolbar copy — honest field note, not a health score.
    public var copyText: String {
        var parts: [String] = []
        parts.append("\(model), \(system)")
        parts.append("Battery \(battery), \(charge), Low Power \(lowPower)")
        parts.append("Thermal \(thermal) — \(thermalMeaning)")
        parts.append("Free \(freeImportant) of \(volumeTotal)")
        parts.append("Up \(uptime)")
        if brightness != "—" {
            parts.append("Brightness \(brightness)")
        }
        return parts.joined(separator: ". ")
    }

    public var saveOutputs: [String: String] {
        [
            "battery": battery,
            "charge": charge,
            "low power": lowPower,
            "thermal": thermal,
            "thermal meaning": thermalMeaning,
            "free important": freeImportant,
            "free caches": freeOpportunistic,
            "volume": volumeTotal,
            "model": model,
            "identifier": identifier,
            "system": system,
            "uptime": uptime,
            "uptime kind": uptimeLabel,
            "booted": booted,
            "brightness": brightness,
            "ram": ram,
            "app headroom": appHeadroom,
            "processors": processors,
        ]
    }
}

/// Formatting for Device Health. Reads no hardware — the iOS view supplies public API values.
public enum DeviceHealthMath {
    /// `UIDevice.batteryLevel` is 0…1, or −1 when unknown (Simulator).
    public static func batteryPercentText(level: Double) -> String {
        guard level.isFinite, level >= 0 else { return "—" }
        let percent = min(100, max(0, level * 100))
        return "\(intString(percent)) %"
    }

    public static func batteryTone(level: Double, charge: DeviceHealthCharge) -> DeviceHealthTone {
        guard level.isFinite, level >= 0 else { return .muted }
        if charge == .charging || charge == .full { return .good }
        if level <= 0.15 { return .bad }
        if level <= 0.20 { return .warn }
        return .good
    }

    public static func chargeLabel(_ charge: DeviceHealthCharge) -> String {
        switch charge {
        case .charging: return "Charging"
        case .full: return "Full"
        case .unplugged: return "Unplugged"
        case .unknown: return "Unknown"
        }
    }

    public static func chargeNote(_ charge: DeviceHealthCharge, level: Double) -> String {
        switch charge {
        case .charging:
            return "On power, filling. Charge level, not pack health."
        case .full:
            return "On power and charged. iOS may hold at 100 %."
        case .unplugged:
            if level.isFinite, level >= 0, level <= 0.20 {
                return "On battery — below 20 %. Charge soon."
            }
            return "Running on battery."
        case .unknown:
            return "State unavailable. Simulator often reports this with battery −1."
        }
    }

    public static func chargeTone(_ charge: DeviceHealthCharge, level: Double) -> DeviceHealthTone {
        switch charge {
        case .charging, .full: return .good
        case .unplugged:
            if level.isFinite, level >= 0, level <= 0.20 { return .warn }
            return .muted
        case .unknown: return .muted
        }
    }

    public static func thermalLabel(_ thermal: DeviceHealthThermal) -> String {
        switch thermal {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        case .unknown: return "Unknown"
        }
    }

    /// One-line field meaning. Not a temperature in °C.
    public static func thermalMeaning(_ thermal: DeviceHealthThermal) -> String {
        switch thermal {
        case .nominal:
            return "Cool enough — no thermal throttling expected."
        case .fair:
            return "Warm — iOS may start cutting CPU / GPU performance."
        case .serious:
            return "Hot — expect throttling, dimming, or radio limits. Shade it."
        case .critical:
            return "Very hot — performance is severely reduced. Stop and let it cool."
        case .unknown:
            return "Thermal band unavailable."
        }
    }

    public static func thermalTone(_ thermal: DeviceHealthThermal) -> DeviceHealthTone {
        switch thermal {
        case .nominal: return .good
        case .fair: return .warn
        case .serious, .critical: return .bad
        case .unknown: return .muted
        }
    }

    public static func lowPowerLabel(enabled: Bool) -> String {
        enabled ? "On" : "Off"
    }

    public static func lowPowerNote(enabled: Bool) -> String {
        enabled
            ? "iOS is reducing background work and may limit performance."
            : "Full performance budget — Low Power Mode is off."
    }

    public static func lowPowerTone(enabled: Bool) -> DeviceHealthTone {
        enabled ? .warn : .muted
    }

    public static func brightnessPercentText(_ brightness: Double) -> String {
        guard brightness.isFinite, brightness >= 0 else { return "—" }
        let percent = min(100, max(0, brightness * 100))
        return "\(intString(percent)) %"
    }

    public static func formatStorageBytes(_ bytes: Int64?) -> String {
        guard let bytes, bytes >= 0 else { return "—" }
        return byteString(bytes, style: .file)
    }

    public static func formatMemoryBytes(_ bytes: UInt64?) -> String {
        guard let bytes else { return "—" }
        return byteString(Int64(clamping: bytes), style: .memory)
    }

    /// Wall-clock time since boot, or awake time if that is all the caller has.
    public static func formatUptime(seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        let total = Int(seconds.rounded(.down))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes) min" }
        return "under 1 min"
    }

    public static func formatBooted(_ date: Date?, now: Date = Date()) -> String {
        guard let date, date <= now.addingTimeInterval(60) else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    public static func processorText(active: Int, installed: Int) -> String {
        let activeN = max(0, active)
        let installedN = max(0, installed)
        if activeN == 0, installedN == 0 { return "—" }
        if activeN == installedN || installedN == 0 {
            return "\(max(activeN, installedN)) active"
        }
        return "\(activeN) active / \(installedN)"
    }

    /// Marketing name when the identifier is in the table; otherwise nil (do not guess).
    public static func marketingName(identifier: String) -> String? {
        let id = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if id.isEmpty { return nil }
        if simulatorIdentifiers.contains(id) { return "Simulator" }
        return marketingNames[id]
    }

    /// Field label: "iPhone 14 Pro (iPhone15,2)" or "iPhone (iPhone15,2)".
    public static func modelDisplay(identifier: String, udiModel: String) -> String {
        let id = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let udi = udiModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if id.isEmpty { return udi.isEmpty ? "—" : udi }
        if let name = marketingName(identifier: id) {
            if simulatorIdentifiers.contains(id) { return name }
            return "\(name) (\(id))"
        }
        if udi.isEmpty { return id }
        if udi == id { return id }
        return "\(udi) (\(id))"
    }

    public static func snapshot(
        batteryLevel: Double,
        charge: DeviceHealthCharge,
        lowPower: Bool,
        thermal: DeviceHealthThermal,
        freeImportantBytes: Int64?,
        freeOpportunisticBytes: Int64?,
        volumeTotalBytes: Int64?,
        identifier: String,
        udiModel: String,
        systemName: String,
        systemVersion: String,
        uptimeSeconds: TimeInterval,
        bootDate: Date?,
        now: Date = Date(),
        brightness: Double,
        physicalMemoryBytes: UInt64?,
        appHeadroomBytes: UInt64?,
        activeProcessors: Int,
        installedProcessors: Int
    ) -> DeviceHealthSnapshot {
        let system = systemLine(name: systemName, version: systemVersion)
        return DeviceHealthSnapshot(
            battery: batteryPercentText(level: batteryLevel),
            charge: chargeLabel(charge),
            chargeNote: chargeNote(charge, level: batteryLevel),
            lowPower: lowPowerLabel(enabled: lowPower),
            lowPowerNote: lowPowerNote(enabled: lowPower),
            thermal: thermalLabel(thermal),
            thermalMeaning: thermalMeaning(thermal),
            freeImportant: formatStorageBytes(freeImportantBytes),
            freeOpportunistic: formatStorageBytes(freeOpportunisticBytes),
            volumeTotal: formatStorageBytes(volumeTotalBytes),
            model: modelDisplay(identifier: identifier, udiModel: udiModel),
            identifier: identifier.isEmpty ? "—" : identifier,
            system: system,
            uptime: formatUptime(seconds: uptimeSeconds),
            uptimeLabel: bootDate == nil ? "Awake" : "Since boot",
            booted: formatBooted(bootDate, now: now),
            brightness: brightnessPercentText(brightness),
            ram: formatMemoryBytes(physicalMemoryBytes),
            appHeadroom: formatMemoryBytes(appHeadroomBytes),
            processors: processorText(active: activeProcessors, installed: installedProcessors),
            batteryTone: batteryTone(level: batteryLevel, charge: charge),
            chargeTone: chargeTone(charge, level: batteryLevel),
            lowPowerTone: lowPowerTone(enabled: lowPower),
            thermalTone: thermalTone(thermal)
        )
    }

    // MARK: - Internals

    private static func systemLine(name: String, version: String) -> String {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let v = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if n.isEmpty, v.isEmpty { return "—" }
        if v.isEmpty { return n }
        if n.isEmpty { return v }
        return "\(n) \(v)"
    }

    private static func intString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value.rounded())) ?? "—"
    }

    private static func byteString(_ bytes: Int64, style: ByteCountFormatter.CountStyle) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = style
        formatter.includesUnit = true
        formatter.isAdaptive = true
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return formatter.string(fromByteCount: bytes)
    }

    private static let simulatorIdentifiers: Set<String> = [
        "i386", "x86_64", "arm64",
    ]

    /// Known public `utsname.machine` identifiers. Unknown ids stay as the raw string.
    private static let marketingNames: [String: String] = [
        "iPhone10,1": "iPhone 8",
        "iPhone10,4": "iPhone 8",
        "iPhone10,2": "iPhone 8 Plus",
        "iPhone10,5": "iPhone 8 Plus",
        "iPhone10,3": "iPhone X",
        "iPhone10,6": "iPhone X",
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max",
        "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd gen)",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,6": "iPhone SE (3rd gen)",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,5": "iPhone 16e",
        "iPad13,18": "iPad (10th gen)",
        "iPad13,19": "iPad (10th gen)",
        "iPad14,8": "iPad Air 11-inch (M2)",
        "iPad14,9": "iPad Air 11-inch (M2)",
        "iPad14,10": "iPad Air 13-inch (M2)",
        "iPad14,11": "iPad Air 13-inch (M2)",
        "iPad16,1": "iPad mini (A17 Pro)",
        "iPad16,2": "iPad mini (A17 Pro)",
        "iPad16,3": "iPad Pro 11-inch (M4)",
        "iPad16,4": "iPad Pro 11-inch (M4)",
        "iPad16,5": "iPad Pro 13-inch (M4)",
        "iPad16,6": "iPad Pro 13-inch (M4)",
    ]
}
