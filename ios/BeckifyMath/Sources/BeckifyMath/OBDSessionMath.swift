import Foundation

/// On-device OBD-II decode for an ELM327-class Bluetooth adapter.
///
/// Generic items are SAE J1979 Mode 01. Chevy Bolt / Bolt EUV items are only
/// the requests whose header and scale were published outside this app.
/// This is an enthusiast design aid. It is not a certified diagnostic, and it
/// does not invent state of health, pack voltage, or traction kilowatts.
///
/// Sources for the Bolt scales that are actually decoded:
/// - Wesley's Tool-Box, 23 Sep 2020: displayed SoC `228334` header `7E4`
///   (A×100/255) and pack temperature `22434F` header `7E4` (A−40).
///   https://tool-box.info/blog/archives/3096-Adding-data-display-to-Bolt-EV-with-UltraGauge-MX.html
/// - chevybolt.org, Dec 2020: capacity `2241A3` header `7E4` revised to
///   ((A×256)+B)/10 amp-hours. The older kWh scale was withdrawn in that thread.
/// - python-OBD issue 287: remaining-life HD `2243AF` header `7E4`
///   (((A×256)+B)×100/65535) and motor temperature `2228CB` header `7E1` (A−40).
/// - chevybolt.org PID thread: HV current `222414` header `7E1`
///   (signed 16-bit / 20 amps).
///
/// Not decoded, on purpose: UltraGauge one-byte scales for charger voltage
/// `22436B` (A/2), charger current `22436C` (A/20), last charge `22437D`
/// (A/100), and heater power `2241B6` (A/1000). Those ceilings sit below pack
/// voltage, DC fast-charge current, a full Bolt charge, or a multi-kilowatt
/// heater. Instant kW on enthusiast lists is volts × current / 1000, and the
/// public voltage scales disagree, so traction kW is left unread.
public enum VehicleProfile: String, CaseIterable, Sendable, Codable {
    case generic
    case boltEV
    case boltEUV

    public var title: String {
        switch self {
        case .generic: return "Generic OBD"
        case .boltEV: return "Bolt EV"
        case .boltEUV: return "Bolt EUV"
        }
    }

    public var usesBoltPIDs: Bool {
        switch self {
        case .generic: return false
        case .boltEV, .boltEUV: return true
        }
    }

    /// GM nominal pack energy for planning only. Not a measurement.
    /// 2017–2019 Bolt EV is 60 kWh; 2020–2023 Bolt EV and Bolt EUV are 65 kWh.
    public var nominalPackChoicesKWh: [Double] {
        switch self {
        case .generic: return []
        case .boltEV: return [60, 65]
        case .boltEUV: return [65]
        }
    }

    public var summary: String {
        switch self {
        case .generic:
            return "SAE J1979 Mode 01 for any ELM327-class car. Fuel level stays fuel level. PID 015B, when the ECU answers, is hybrid battery remaining life — not a state-of-charge gauge."
        case .boltEV:
            return "2017–2023 Bolt EV. Mode 01 speed and 12 V, plus published displayed SoC, pack temp, capacity, HV current, and motor temp. 60 kWh (2017–2019) or 65 kWh (2020–2023) is a planning assumption you type, not a reading."
        case .boltEUV:
            return "2022–2023 Bolt EUV uses the same public PID set as Bolt EV here. 65 kWh nominal is a planning assumption, not a measurement. This app does not invent a separate EUV battery-health PID."
        }
    }
}

public enum OBDReading: String, CaseIterable, Sendable, Equatable {
    case speedKph
    case rpm
    case coolantC
    case intakeC
    case engineLoadPercent
    case throttlePercent
    case acceleratorPercent
    case fuelLevelPercent
    case moduleVolts
    case ambientC
    case oilTempC
    case runtimeSeconds
    case distanceSinceClearKm
    case displayedSocPercent
    case packTempC
    case hvCurrentAmps
    case motorTempC
    case capacityAh
    case hybridRemainingLifePercent
    case hybridRemainingLifeHDPercent
}

public struct OBDSample: Equatable, Sendable {
    public var value: Double
    public var at: Date

    public init(value: Double, at: Date) {
        self.value = value
        self.at = at
    }
}

public struct OBDReadingBook: Equatable, Sendable {
    public static let staleAfter: TimeInterval = 20

    private var samples: [String: OBDSample]

    public init() {
        samples = [:]
    }

    public mutating func write(_ key: OBDReading, value: Double, at: Date) {
        samples[key.rawValue] = OBDSample(value: value, at: at)
    }

    public func read(_ key: OBDReading, now: Date, staleAfter: TimeInterval = OBDReadingBook.staleAfter) -> Double? {
        guard let sample = samples[key.rawValue] else { return nil }
        guard now.timeIntervalSince(sample.at) <= staleAfter else { return nil }
        guard now.timeIntervalSince(sample.at) >= 0 else { return nil }
        return sample.value
    }
}

public struct OBDSupportMap: Equatable, Sendable {
    public private(set) var supported: Set<UInt8>
    public private(set) var blocksSeen: Set<UInt8>

    public init() {
        supported = []
        blocksSeen = []
    }

    public var isKnown: Bool { !blocksSeen.isEmpty }

    /// `pid` is the support request (0x00, 0x20, 0x40, 0x60). `data` is the
    /// four mask bytes after that PID. Bit 7 of the first byte is the next PID.
    public mutating func record(block pid: UInt8, data: [UInt8]) {
        guard pid == 0x00 || pid == 0x20 || pid == 0x40 || pid == 0x60 else { return }
        guard data.count >= 4 else { return }
        blocksSeen.insert(pid)
        for index in 0..<32 {
            let byte = data[index / 8]
            let bit = 7 - (index % 8)
            let candidate = Int(pid) + index + 1
            guard candidate <= 0xFF else { continue }
            let id = UInt8(candidate)
            if (byte >> bit) & 0x01 == 1 {
                supported.insert(id)
            } else {
                supported.remove(id)
            }
        }
    }

    public func allows(_ pid: UInt8) -> Bool {
        if !isKnown { return true }
        return supported.contains(pid)
    }
}

public enum OBDCommandPlan {
    public static let initialization: [String] = [
        "ATZ", "ATE0", "ATL0", "ATS0", "ATH0", "ATAT1", "ATSP0",
    ]

    public static let supportQueries: [String] = ["0100", "0120", "0140"]

    public static func liveCycle(profile: VehicleProfile, support: OBDSupportMap) -> [String] {
        if profile.usesBoltPIDs {
            return [
                "ATSH 7DF",
                "010D", "010C", "0105", "0142", "0146", "0149", "015B",
                "ATSH 7E4",
                "228334", "22434F", "2241A3", "2243AF",
                "ATSH 7E1",
                "222414", "2228CB",
            ]
        }
        let candidates = ["010C", "0105", "0104", "0111", "0149", "012F", "0142", "0146", "015C", "011F", "015B", "0131"]
        var commands = candidates.filter { command in
            guard let pid = mode01PID(command) else { return false }
            return support.allows(pid)
        }
        commands.insert("010D", at: 0)
        return commands
    }

    private static func mode01PID(_ command: String) -> UInt8? {
        let trimmed = command.replacingOccurrences(of: " ", with: "")
        guard trimmed.count == 4, trimmed.hasPrefix("01") else { return nil }
        return UInt8(trimmed.dropFirst(2), radix: 16)
    }
}

public enum ELMReassembler {
    public static func replies(in buffer: inout String, appending chunk: String) -> [String] {
        buffer.append(chunk.replacingOccurrences(of: "\u{0}", with: ""))
        var done: [String] = []
        while let mark = buffer.firstIndex(of: ">") {
            let body = String(buffer[..<mark])
            buffer.removeSubrange(buffer.startIndex...mark)
            done.append(body)
        }
        return done
    }
}

public enum OBDDecode {
    public static func isFault(_ reply: String) -> Bool {
        let upper = reply.uppercased()
        let phrases = [
            "NO DATA", "UNABLE TO CONNECT", "CAN ERROR", "BUS BUSY",
            "BUS ERROR", "STOPPED", "DATA ERROR", "LV RESET", "ERROR",
        ]
        if phrases.contains(where: { upper.contains($0) }) { return true }
        let lines = upper.split(whereSeparator: { $0 == "\r" || $0 == "\n" })
        return lines.contains { $0.trimmingCharacters(in: .whitespaces) == "?" }
    }

    public enum Result: Equatable, Sendable {
        case adapter
        case fault
        case support(block: UInt8, data: [UInt8])
        case readings([OBDReading: Double])
        case ignored
    }

    public static func interpret(command: String, reply: String) -> Result {
        let compact = command.uppercased().replacingOccurrences(of: " ", with: "")
        if compact.hasPrefix("AT") { return .adapter }
        if isFault(reply) { return .fault }
        if compact.count == 4, compact.hasPrefix("01"), let pid = UInt8(compact.dropFirst(2), radix: 16) {
            guard let data = payload(reply: reply, prefix: String(format: "41%02X", pid)) else {
                return .ignored
            }
            if pid == 0x00 || pid == 0x20 || pid == 0x40 || pid == 0x60 {
                guard data.count >= 4 else { return .ignored }
                return .support(block: pid, data: Array(data.prefix(4)))
            }
            let values = mode01Values(pid: pid, data: data)
            return values.isEmpty ? .ignored : .readings(values)
        }
        if compact.count == 6, compact.hasPrefix("22"), let did = UInt16(compact.dropFirst(2), radix: 16) {
            guard let data = payload(reply: reply, prefix: String(format: "62%04X", did)) else {
                return .ignored
            }
            let values = mode22Values(did: did, data: data)
            return values.isEmpty ? .ignored : .readings(values)
        }
        return .ignored
    }

    static func payload(reply: String, prefix: String) -> [UInt8]? {
        if isFault(reply) { return nil }
        let hex = reply.uppercased().filter(\.isHexDigit)
        guard let range = hex.range(of: prefix) else { return nil }
        let rest = hex[range.upperBound...]
        var bytes: [UInt8] = []
        var index = rest.startIndex
        while index < rest.endIndex, bytes.count < 8 {
            let next = rest.index(index, offsetBy: 2, limitedBy: rest.endIndex) ?? rest.endIndex
            guard rest.distance(from: index, to: next) == 2 else { break }
            let pair = String(rest[index..<next])
            guard let byte = UInt8(pair, radix: 16) else { break }
            bytes.append(byte)
            index = next
        }
        return bytes
    }

    static func mode01Values(pid: UInt8, data: [UInt8]) -> [OBDReading: Double] {
        switch pid {
        case 0x04: return percentByte(data, as: .engineLoadPercent)
        case 0x05: return tempByte(data, as: .coolantC)
        case 0x0C:
            guard let word = unsigned16(data) else { return [:] }
            return [.rpm: Double(word) / 4.0]
        case 0x0D:
            guard let a = data.first else { return [:] }
            return [.speedKph: Double(a)]
        case 0x0F: return tempByte(data, as: .intakeC)
        case 0x11: return percentByte(data, as: .throttlePercent)
        case 0x1F:
            guard let word = unsigned16(data) else { return [:] }
            return [.runtimeSeconds: Double(word)]
        case 0x2F: return percentByte(data, as: .fuelLevelPercent)
        case 0x31:
            guard let word = unsigned16(data) else { return [:] }
            return [.distanceSinceClearKm: Double(word)]
        case 0x42:
            guard let word = unsigned16(data) else { return [:] }
            return [.moduleVolts: Double(word) / 1000.0]
        case 0x46: return tempByte(data, as: .ambientC)
        case 0x49: return percentByte(data, as: .acceleratorPercent)
        case 0x5B: return percentByte(data, as: .hybridRemainingLifePercent)
        case 0x5C: return tempByte(data, as: .oilTempC)
        default: return [:]
        }
    }

    static func mode22Values(did: UInt16, data: [UInt8]) -> [OBDReading: Double] {
        switch did {
        case 0x8334: return percentByte(data, as: .displayedSocPercent)
        case 0x434F: return tempByte(data, as: .packTempC)
        case 0x41A3:
            guard let word = unsigned16(data) else { return [:] }
            let ah = Double(word) / 10.0
            guard ah >= 0, ah <= 300 else { return [:] }
            return [.capacityAh: ah]
        case 0x43AF:
            guard let word = unsigned16(data) else { return [:] }
            let percent = Double(word) * 100.0 / 65535.0
            guard percent >= 0, percent <= 105 else { return [:] }
            return [.hybridRemainingLifeHDPercent: percent]
        case 0x2414:
            guard let word = signed16(data) else { return [:] }
            return [.hvCurrentAmps: Double(word) / 20.0]
        case 0x28CB: return tempByte(data, as: .motorTempC)
        default: return [:]
        }
    }

    private static func percentByte(_ data: [UInt8], as key: OBDReading) -> [OBDReading: Double] {
        guard let a = data.first else { return [:] }
        return [key: Double(a) * 100.0 / 255.0]
    }

    private static func tempByte(_ data: [UInt8], as key: OBDReading) -> [OBDReading: Double] {
        guard let a = data.first else { return [:] }
        return [key: Double(Int(a) - 40)]
    }

    private static func unsigned16(_ data: [UInt8]) -> Int? {
        guard data.count >= 2 else { return nil }
        return (Int(data[0]) << 8) | Int(data[1])
    }

    private static func signed16(_ data: [UInt8]) -> Int? {
        guard let word = unsigned16(data) else { return nil }
        return word >= 0x8000 ? word - 0x10000 : word
    }
}

public struct PlanningInputs: Equatable, Sendable {
    public var usableKWh: Double?
    public var whPerMile: Double?

    public init(usableKWh: Double?, whPerMile: Double?) {
        self.usableKWh = usableKWh
        self.whPerMile = whPerMile
    }
}

public enum DrivePlanning {
    /// Miles from a measured SoC, a typed pack size, and a typed Wh/mi.
    /// Nil unless every input is present. The pack size is never treated as measured.
    public static func rangeMiles(socPercent: Double?, usableKWh: Double?, whPerMile: Double?) -> Double? {
        guard let socPercent, let usableKWh, let whPerMile else { return nil }
        guard socPercent >= 0, socPercent <= 100 else { return nil }
        guard usableKWh > 0, usableKWh <= 200 else { return nil }
        guard whPerMile >= 50, whPerMile <= 2000 else { return nil }
        return (socPercent / 100.0) * usableKWh * 1000.0 / whPerMile
    }

    /// Reserved for a future measured volt × amp integral. Returns nil until
    /// both distance and energy are real numbers. Callers must not pass a guessed energy.
    public static func efficiencyWhPerMile(distanceMiles: Double, energyKWh: Double?) -> Double? {
        guard let energyKWh, distanceMiles > 0.05, energyKWh > 0 else { return nil }
        return energyKWh * 1000.0 / distanceMiles
    }
}

public struct OBDTripTrack: Equatable, Sendable {
    public private(set) var distanceKilometers: Double
    public private(set) var lastAt: Date?
    public private(set) var lastSpeedKph: Double?

    public init() {
        distanceKilometers = 0
        lastAt = nil
        lastSpeedKph = nil
    }

    public var distanceMiles: Double { distanceKilometers * 0.621371192 }

    /// Trapezoid distance. Gaps over 8 seconds are dropped so a stalled poll
    /// does not invent highway miles. Eight seconds covers one Bolt PID cycle.
    public mutating func add(speedKph: Double?, at: Date) {
        let previousAt = lastAt
        let previousSpeed = lastSpeedKph
        lastAt = at
        lastSpeedKph = speedKph
        guard let speedKph, let previousAt, let previousSpeed else { return }
        let dt = at.timeIntervalSince(previousAt)
        guard dt > 0, dt <= 8 else { return }
        guard speedKph >= 0, speedKph <= 300, previousSpeed >= 0, previousSpeed <= 300 else { return }
        let average = (speedKph + previousSpeed) / 2.0
        distanceKilometers += average * dt / 3600.0
    }
}

public enum CarPlayPublishPolicy {
    /// Apple's driving-task rule: do not refresh CarPlay data items more than once every 10 seconds.
    public static let minimumInterval: TimeInterval = 10

    public static func shouldPublish(since last: Date?, now: Date) -> Bool {
        guard let last else { return true }
        return now.timeIntervalSince(last) >= minimumInterval
    }
}

public enum OBDAdapterHint {
    public static func looksLikeOBD(name: String?, serviceUUIDs: [String]) -> Bool {
        let services = serviceUUIDs.map { $0.uppercased() }
        let known: Set<String> = [
            "FFE0", "FFF0",
            "6E400001-B5A3-F393-E0A9-E50E24DCCA9E",
            "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2",
        ]
        if services.contains(where: { known.contains($0) || $0.hasSuffix("FFE0") || $0.hasSuffix("FFF0") }) {
            return true
        }
        let folded = (name ?? "").uppercased()
        let tokens = ["OBD", "ELM", "VLINK", "VGATE", "VEEPEAK", "CARISTA", "LELINK", "OBDLINK", "VGATA", "IOS-VLINK"]
        return tokens.contains { folded.contains($0) }
    }
}

public enum DriveLayout: String, Sendable, Equatable {
    case ev
    case powertrain
}

public struct DriveTile: Equatable, Sendable, Identifiable {
    public var id: String
    public var label: String
    public var value: String
    public var caption: String

    public init(id: String, label: String, value: String, caption: String) {
        self.id = id
        self.label = label
        self.value = value
        self.caption = caption
    }
}

public struct DriveDetailRow: Equatable, Sendable, Identifiable {
    public var id: String
    public var label: String
    public var value: String
    public var note: String

    public init(id: String, label: String, value: String, note: String) {
        self.id = id
        self.label = label
        self.value = value
        self.note = note
    }
}

public struct DriveCarPlayCopy: Equatable, Sendable {
    public var charge: String
    public var power: String
    public var speed: String
    public var range: String
    public var temperature: String
    public var link: String

    public init(charge: String, power: String, speed: String, range: String, temperature: String, link: String) {
        self.charge = charge
        self.power = power
        self.speed = speed
        self.range = range
        self.temperature = temperature
        self.link = link
    }
}

public struct DrivePresentation: Equatable, Sendable {
    public var layout: DriveLayout
    public var heroPercent: Double?
    public var heroValue: String
    public var heroCaption: String
    public var tiles: [DriveTile]
    public var rows: [DriveDetailRow]
    public var carPlay: DriveCarPlayCopy
    public var designAid: String

    public init(
        layout: DriveLayout,
        heroPercent: Double?,
        heroValue: String,
        heroCaption: String,
        tiles: [DriveTile],
        rows: [DriveDetailRow],
        carPlay: DriveCarPlayCopy,
        designAid: String
    ) {
        self.layout = layout
        self.heroPercent = heroPercent
        self.heroValue = heroValue
        self.heroCaption = heroCaption
        self.tiles = tiles
        self.rows = rows
        self.carPlay = carPlay
        self.designAid = designAid
    }

    public static let designAid = "Design aid for enthusiasts. Not a certified diagnostic tool, not a battery-health certificate, and not the vehicle's own range estimate."
    public static let powerGap = "kW stays blank until volts and amps are both measured. Traction pack voltage is not invented."
}

public enum DrivePresentationBuilder {
    public static func make(
        profile: VehicleProfile,
        book: OBDReadingBook,
        now: Date,
        planning: PlanningInputs,
        trip: OBDTripTrack,
        link: String
    ) -> DrivePresentation {
        let soc = book.read(.displayedSocPercent, now: now)
        let range = DrivePlanning.rangeMiles(
            socPercent: soc,
            usableKWh: planning.usableKWh,
            whPerMile: planning.whPerMile
        )
        let speed = book.read(.speedKph, now: now)
        let layout: DriveLayout = profile.usesBoltPIDs ? .ev : .powertrain
        let temperature = temperatureCopy(book: book, now: now, preferPack: profile.usesBoltPIDs)
        let carPlay = DriveCarPlayCopy(
            charge: soc.map { percent($0, digits: 1) } ?? "Not read",
            power: "Not read",
            speed: speed.map { speedCopy($0) } ?? "Not read",
            range: range.map { "\(Int($0.rounded())) mi planning" } ?? "Not read",
            temperature: temperature.carPlay,
            link: link
        )
        if layout == .ev {
            return evPresentation(
                soc: soc,
                speed: speed,
                range: range,
                planning: planning,
                book: book,
                now: now,
                trip: trip,
                carPlay: carPlay
            )
        }
        return powertrainPresentation(
            speed: speed,
            book: book,
            now: now,
            trip: trip,
            carPlay: carPlay
        )
    }

    private static func evPresentation(
        soc: Double?,
        speed: Double?,
        range: Double?,
        planning: PlanningInputs,
        book: OBDReadingBook,
        now: Date,
        trip: OBDTripTrack,
        carPlay: DriveCarPlayCopy
    ) -> DrivePresentation {
        let amps = book.read(.hvCurrentAmps, now: now)
        let pack = book.read(.packTempC, now: now)
        let module = book.read(.moduleVolts, now: now)
        let tiles = [
            DriveTile(id: "speed", label: "Speed", value: speed.map { speedCopy($0) } ?? "—", caption: speed.map { kphCopy($0) } ?? "Mode 01 vehicle speed"),
            DriveTile(id: "amps", label: "HV current", value: amps.map { ampsCopy($0) } ?? "—", caption: "PID 222414 · header 7E1 · sign as published"),
            DriveTile(id: "power", label: "Power", value: "—", caption: DrivePresentation.powerGap),
            DriveTile(
                id: "range",
                label: "Range",
                value: range.map { "\(Int($0.rounded())) mi" } ?? "—",
                caption: rangeCaption(range: range, planning: planning)
            ),
            DriveTile(id: "temp", label: "Pack temp", value: pack.map { tempCopy($0) } ?? "—", caption: "PID 22434F · header 7E4 · A−40"),
            DriveTile(id: "12v", label: "12 V", value: module.map { voltsCopy($0) } ?? "—", caption: "Control module voltage · not the pack"),
        ]
        var rows: [DriveDetailRow] = []
        append(&rows, id: "motor", label: "Motor temp", value: book.read(.motorTempC, now: now).map { tempCopy($0) }, note: "PID 2228CB · header 7E1 · A−40")
        append(&rows, id: "ambient", label: "Ambient", value: book.read(.ambientC, now: now).map { tempCopy($0) }, note: "Mode 01 PID 46")
        append(&rows, id: "accel", label: "Accelerator", value: book.read(.acceleratorPercent, now: now).map { percent($0, digits: 0) }, note: "Mode 01 PID 49")
        append(&rows, id: "capacity", label: "Capacity", value: book.read(.capacityAh, now: now).map { String(format: "%.1f Ah", $0) }, note: "Enthusiast PID 2241A3 · revised Ah formula · not a GM certificate")
        append(&rows, id: "life", label: "Remaining life", value: book.read(.hybridRemainingLifePercent, now: now).map { percent($0, digits: 0) }, note: "SAE PID 015B. Bolt logs sometimes treat this as raw SoC. Not displayed state of charge, and not warranty SOH.")
        append(&rows, id: "lifehd", label: "Remaining life HD", value: book.read(.hybridRemainingLifeHDPercent, now: now).map { percent($0, digits: 1) }, note: "Enthusiast PID 2243AF. Not a battery-health certificate.")
        append(&rows, id: "coolant", label: "Coolant", value: book.read(.coolantC, now: now).map { tempCopy($0) }, note: "Mode 01 PID 05")
        rows.append(DriveDetailRow(
            id: "trip",
            label: "Session distance",
            value: String(format: "%.2f mi", trip.distanceMiles),
            note: "Integrated from Mode 01 speed on this phone. Not an odometer."
        ))
        rows.append(DriveDetailRow(
            id: "efficiency",
            label: "Efficiency",
            value: "—",
            note: "Wh/mi needs a measured energy integral. This app does not invent one from nominal pack voltage."
        ))
        return DrivePresentation(
            layout: .ev,
            heroPercent: soc,
            heroValue: soc.map { percent($0, digits: 1) } ?? "—",
            heroCaption: "Displayed state of charge",
            tiles: tiles,
            rows: rows,
            carPlay: carPlay,
            designAid: DrivePresentation.designAid
        )
    }

    private static func powertrainPresentation(
        speed: Double?,
        book: OBDReadingBook,
        now: Date,
        trip: OBDTripTrack,
        carPlay: DriveCarPlayCopy
    ) -> DrivePresentation {
        let rpm = book.read(.rpm, now: now)
        let coolant = book.read(.coolantC, now: now)
        let load = book.read(.engineLoadPercent, now: now)
        let fuel = book.read(.fuelLevelPercent, now: now)
        let module = book.read(.moduleVolts, now: now)
        let tiles = [
            DriveTile(id: "speed", label: "Speed", value: speed.map { speedCopy($0) } ?? "—", caption: speed.map { kphCopy($0) } ?? "Mode 01 PID 0D"),
            DriveTile(id: "rpm", label: "RPM", value: rpm.map { "\(Int($0.rounded()))" } ?? "—", caption: "Mode 01 PID 0C · often unsupported on an EV"),
            DriveTile(id: "coolant", label: "Coolant", value: coolant.map { tempCopy($0) } ?? "—", caption: "Mode 01 PID 05 · A−40"),
            DriveTile(id: "load", label: "Engine load", value: load.map { percent($0, digits: 0) } ?? "—", caption: "Calculated load · not torque"),
            DriveTile(id: "fuel", label: "Fuel level", value: fuel.map { percent($0, digits: 0) } ?? "—", caption: "PID 2F input. Not battery state of charge."),
            DriveTile(id: "12v", label: "12 V", value: module.map { voltsCopy($0) } ?? "—", caption: "Control module voltage"),
        ]
        var rows: [DriveDetailRow] = []
        append(&rows, id: "throttle", label: "Throttle", value: book.read(.throttlePercent, now: now).map { percent($0, digits: 0) }, note: "Mode 01 PID 11")
        append(&rows, id: "accel", label: "Accelerator", value: book.read(.acceleratorPercent, now: now).map { percent($0, digits: 0) }, note: "Mode 01 PID 49")
        append(&rows, id: "ambient", label: "Ambient", value: book.read(.ambientC, now: now).map { tempCopy($0) }, note: "Mode 01 PID 46")
        append(&rows, id: "oil", label: "Oil temp", value: book.read(.oilTempC, now: now).map { tempCopy($0) }, note: "Mode 01 PID 5C")
        append(&rows, id: "intake", label: "Intake air", value: book.read(.intakeC, now: now).map { tempCopy($0) }, note: "Mode 01 PID 0F")
        append(&rows, id: "runtime", label: "Run time", value: book.read(.runtimeSeconds, now: now).map { duration($0) }, note: "Since engine start · PID 1F")
        append(&rows, id: "cleared", label: "Since codes cleared", value: book.read(.distanceSinceClearKm, now: now).map { kmDistance($0) }, note: "Mode 01 PID 31")
        append(&rows, id: "life", label: "Remaining life", value: book.read(.hybridRemainingLifePercent, now: now).map { percent($0, digits: 0) }, note: "SAE PID 015B hybrid battery remaining life. Not state of charge and not a health certificate.")
        rows.append(DriveDetailRow(
            id: "trip",
            label: "Session distance",
            value: String(format: "%.2f mi", trip.distanceMiles),
            note: "Integrated from Mode 01 speed on this phone. Not an odometer."
        ))
        return DrivePresentation(
            layout: .powertrain,
            heroPercent: nil,
            heroValue: speed.map { speedCopy($0) } ?? "—",
            heroCaption: "Vehicle speed",
            tiles: tiles,
            rows: rows,
            carPlay: carPlay,
            designAid: DrivePresentation.designAid
        )
    }

    private static func append(_ rows: inout [DriveDetailRow], id: String, label: String, value: String?, note: String) {
        guard let value else { return }
        rows.append(DriveDetailRow(id: id, label: label, value: value, note: note))
    }

    private static func rangeCaption(range: Double?, planning: PlanningInputs) -> String {
        guard range != nil, let kWh = planning.usableKWh, let wh = planning.whPerMile else {
            return "Type pack kWh and Wh/mi. Nominal energy is not the car's estimate."
        }
        return String(format: "Planning only · %.0f kWh assumed · %.0f Wh/mi · not the vehicle estimate", kWh, wh)
    }

    private static func temperatureCopy(book: OBDReadingBook, now: Date, preferPack: Bool) -> (carPlay: String, label: String) {
        if preferPack, let pack = book.read(.packTempC, now: now) {
            return ("Pack \(shortTemp(pack))", "Pack")
        }
        if let coolant = book.read(.coolantC, now: now) {
            return ("Coolant \(shortTemp(coolant))", "Coolant")
        }
        if let ambient = book.read(.ambientC, now: now) {
            return ("Ambient \(shortTemp(ambient))", "Ambient")
        }
        if let motor = book.read(.motorTempC, now: now) {
            return ("Motor \(shortTemp(motor))", "Motor")
        }
        return ("Not read", "")
    }

    private static func percent(_ value: Double, digits: Int) -> String {
        String(format: "%.\(digits)f%%", value)
    }

    private static func speedCopy(_ kph: Double) -> String {
        "\(Int((kph * 0.621371192).rounded())) mph"
    }

    private static func kphCopy(_ kph: Double) -> String {
        "\(Int(kph.rounded())) km/h"
    }

    private static func ampsCopy(_ amps: Double) -> String {
        String(format: "%+.1f A", amps)
    }

    private static func voltsCopy(_ volts: Double) -> String {
        String(format: "%.2f V", volts)
    }

    private static func tempCopy(_ celsius: Double) -> String {
        let fahrenheit = celsius * 9.0 / 5.0 + 32.0
        return String(format: "%.0f°C · %.0f°F", celsius, fahrenheit)
    }

    private static func shortTemp(_ celsius: Double) -> String {
        let fahrenheit = celsius * 9.0 / 5.0 + 32.0
        return String(format: "%.0f°F", fahrenheit)
    }

    private static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private static func kmDistance(_ km: Double) -> String {
        let miles = km * 0.621371192
        return String(format: "%.0f mi", miles)
    }
}
