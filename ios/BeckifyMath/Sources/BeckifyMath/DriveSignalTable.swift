import Foundation

/// Where a signal sits on the Drive dashboard.
public enum DriveSignalGroup: String, CaseIterable, Sendable {
    case vehicle
    case powertrain
    case battery
    case motor
    case powerElectronics
}

/// One row per signal the Drive dashboard can show.
///
/// A row with `reading`, `header`, `request`, and `decode` is read from the
/// car. A row without them is a slot the dashboard draws as "Not reported by
/// this vehicle" — the request and scale are not published, so nothing is sent.
///
/// Adding a verified Mode 22 PID: add an `OBDReading` case, then one row here
/// with header, request, decode, unit, valid range, and the source. The Bolt
/// live cycle requests it and `OBDDecode` decodes it through this table.
public struct DriveSignalDefinition: Sendable, Identifiable {
    public typealias Decode = @Sendable ([UInt8]) -> Double?

    public let id: String
    public let reading: OBDReading?
    public let group: DriveSignalGroup
    public let name: String
    /// CAN request header for `ATSH`, e.g. `7E4`. Mode 01 uses the functional `7DF`.
    public let header: String?
    /// Request bytes as hex text, e.g. `228334` or `0142`.
    public let request: String?
    /// Canonical unit of the decoded value: `%`, `°C`, `A`, `Ah`, `V`, `km/h`, `rpm`.
    public let unit: String
    /// Plausibility bound for a decoded value. Outside it the dashboard shows a
    /// dash and a warning glyph, never the number. Not a vehicle limit.
    public let validRange: ClosedRange<Double>?
    public let source: String
    public let decode: Decode?

    public init(
        id: String,
        reading: OBDReading?,
        group: DriveSignalGroup,
        name: String,
        header: String?,
        request: String?,
        unit: String,
        validRange: ClosedRange<Double>?,
        source: String,
        decode: Decode?
    ) {
        self.id = id
        self.reading = reading
        self.group = group
        self.name = name
        self.header = header
        self.request = request
        self.unit = unit
        self.validRange = validRange
        self.source = source
        self.decode = decode
    }

    public var isReported: Bool {
        reading != nil && header != nil && request != nil && decode != nil
    }

    /// Mode 22 data identifier, when this is a Mode 22 request.
    public var mode22DID: UInt16? {
        guard let request, request.count == 6, request.hasPrefix("22") else { return nil }
        return UInt16(request.dropFirst(2), radix: 16)
    }

    public func accepts(_ value: Double) -> Bool {
        guard value.isFinite else { return false }
        guard let validRange else { return true }
        return validRange.contains(value)
    }
}

public enum DriveSignalTable {
    public static let all: [DriveSignalDefinition] = vehicle + powertrain + battery + motor + powerElectronics

    public static func definition(for reading: OBDReading) -> DriveSignalDefinition? {
        all.first { $0.reading == reading }
    }

    public static func definition(id: String) -> DriveSignalDefinition? {
        all.first { $0.id == id }
    }

    public static func signals(in group: DriveSignalGroup) -> [DriveSignalDefinition] {
        all.filter { $0.group == group }
    }

    /// EV rows: battery, motor, and power electronics, reported or not.
    public static var ev: [DriveSignalDefinition] {
        all.filter { [.battery, .motor, .powerElectronics].contains($0.group) }
    }

    // MARK: - Vehicle (Mode 01, any car)

    static let vehicle: [DriveSignalDefinition] = [
        DriveSignalDefinition(
            id: "speed", reading: .speedKph, group: .vehicle, name: "Speed",
            header: "7DF", request: "010D", unit: "km/h", validRange: 0...255,
            source: "SAE J1979 Mode 01 PID 0D · A km/h",
            decode: { byte($0).map { Double($0) } }
        ),
        DriveSignalDefinition(
            id: "ambient", reading: .ambientC, group: .vehicle, name: "Ambient",
            header: "7DF", request: "0146", unit: "°C", validRange: -40...80,
            source: "SAE J1979 Mode 01 PID 46 · A−40",
            decode: { byte($0).map { Double(Int($0) - 40) } }
        ),
        DriveSignalDefinition(
            id: "accelerator", reading: .acceleratorPercent, group: .vehicle, name: "Accelerator",
            header: "7DF", request: "0149", unit: "%", validRange: 0...100,
            source: "SAE J1979 Mode 01 PID 49 · A×100/255",
            decode: { byte($0).map { Double($0) * 100.0 / 255.0 } }
        ),
    ]

    // MARK: - Powertrain (Mode 01, combustion and hybrid)

    static let powertrain: [DriveSignalDefinition] = [
        DriveSignalDefinition(
            id: "rpm", reading: .rpm, group: .powertrain, name: "RPM",
            header: "7DF", request: "010C", unit: "rpm", validRange: 0...16_383.75,
            source: "SAE J1979 Mode 01 PID 0C · ((A×256)+B)/4",
            decode: { unsigned16($0).map { Double($0) / 4.0 } }
        ),
        DriveSignalDefinition(
            id: "coolant", reading: .coolantC, group: .powertrain, name: "Coolant",
            header: "7DF", request: "0105", unit: "°C", validRange: -40...150,
            source: "SAE J1979 Mode 01 PID 05 · A−40",
            decode: { byte($0).map { Double(Int($0) - 40) } }
        ),
        DriveSignalDefinition(
            id: "load", reading: .engineLoadPercent, group: .powertrain, name: "Engine load",
            header: "7DF", request: "0104", unit: "%", validRange: 0...100,
            source: "SAE J1979 Mode 01 PID 04 · A×100/255 · calculated load, not torque",
            decode: { byte($0).map { Double($0) * 100.0 / 255.0 } }
        ),
        DriveSignalDefinition(
            id: "throttle", reading: .throttlePercent, group: .powertrain, name: "Throttle",
            header: "7DF", request: "0111", unit: "%", validRange: 0...100,
            source: "SAE J1979 Mode 01 PID 11 · A×100/255",
            decode: { byte($0).map { Double($0) * 100.0 / 255.0 } }
        ),
        DriveSignalDefinition(
            id: "fuel", reading: .fuelLevelPercent, group: .powertrain, name: "Fuel level",
            header: "7DF", request: "012F", unit: "%", validRange: 0...100,
            source: "SAE J1979 Mode 01 PID 2F · A×100/255 · fuel, not battery charge",
            decode: { byte($0).map { Double($0) * 100.0 / 255.0 } }
        ),
        DriveSignalDefinition(
            id: "oil", reading: .oilTempC, group: .powertrain, name: "Oil temp",
            header: "7DF", request: "015C", unit: "°C", validRange: -40...160,
            source: "SAE J1979 Mode 01 PID 5C · A−40",
            decode: { byte($0).map { Double(Int($0) - 40) } }
        ),
        DriveSignalDefinition(
            id: "intake", reading: .intakeC, group: .powertrain, name: "Intake air",
            header: "7DF", request: "010F", unit: "°C", validRange: -40...120,
            source: "SAE J1979 Mode 01 PID 0F · A−40",
            decode: { byte($0).map { Double(Int($0) - 40) } }
        ),
        DriveSignalDefinition(
            id: "life", reading: .hybridRemainingLifePercent, group: .powertrain, name: "Remaining life",
            header: "7DF", request: "015B", unit: "%", validRange: 0...100,
            source: "SAE J1979 Mode 01 PID 5B · hybrid battery remaining life · not state of charge",
            decode: { byte($0).map { Double($0) * 100.0 / 255.0 } }
        ),
    ]

    // MARK: - EV battery

    static let battery: [DriveSignalDefinition] = [
        DriveSignalDefinition(
            id: "soc", reading: .displayedSocPercent, group: .battery, name: "Displayed charge",
            header: "7E4", request: "228334", unit: "%", validRange: 0...100,
            source: "Wesley's Tool-Box, Sep 2020 · A×100/255",
            decode: { byte($0).map { Double($0) * 100.0 / 255.0 } }
        ),
        DriveSignalDefinition(
            id: "packTemp", reading: .packTempC, group: .battery, name: "Pack temp",
            header: "7E4", request: "22434F", unit: "°C", validRange: -40...100,
            source: "Wesley's Tool-Box, Sep 2020 · A−40",
            decode: { byte($0).map { Double(Int($0) - 40) } }
        ),
        DriveSignalDefinition(
            id: "hvCurrent", reading: .hvCurrentAmps, group: .battery, name: "HV current",
            header: "7E1", request: "222414", unit: "A", validRange: -1_638.4...1_638.35,
            source: "chevybolt.org PID thread · signed 16-bit / 20",
            decode: { signed16($0).map { Double($0) / 20.0 } }
        ),
        DriveSignalDefinition(
            id: "capacity", reading: .capacityAh, group: .battery, name: "Capacity",
            header: "7E4", request: "2241A3", unit: "Ah", validRange: 0...300,
            source: "chevybolt.org, Dec 2020 · ((A×256)+B)/10 · revised Ah scale",
            decode: { unsigned16($0).map { Double($0) / 10.0 } }
        ),
        DriveSignalDefinition(
            id: "lifeHD", reading: .hybridRemainingLifeHDPercent, group: .battery, name: "Remaining life (HD)",
            header: "7E4", request: "2243AF", unit: "%", validRange: 0...105,
            source: "python-OBD issue 287 · ((A×256)+B)×100/65535 · not a warranty state of health",
            decode: { unsigned16($0).map { Double($0) * 100.0 / 65_535.0 } }
        ),
    ]

    // MARK: - EV motor / drive unit

    static let motor: [DriveSignalDefinition] = [
        DriveSignalDefinition(
            id: "motorTemp", reading: .motorTempC, group: .motor, name: "Motor temp",
            header: "7E1", request: "2228CB", unit: "°C", validRange: -40...200,
            source: "python-OBD issue 287 · A−40",
            decode: { byte($0).map { Double(Int($0) - 40) } }
        ),
    ]

    // MARK: - EV power electronics

    static let powerElectronics: [DriveSignalDefinition] = [
        DriveSignalDefinition(
            id: "moduleVolts", reading: .moduleVolts, group: .powerElectronics, name: "12 V bus",
            header: "7DF", request: "0142", unit: "V", validRange: 0...20,
            source: "SAE J1979 Mode 01 PID 42 · ((A×256)+B)/1000 · control module voltage, not the pack",
            decode: { unsigned16($0).map { Double($0) / 1000.0 } }
        ),
        DriveSignalDefinition(
            id: "inverterTemp", reading: nil, group: .powerElectronics, name: "Inverter temp",
            header: nil, request: nil, unit: "°C", validRange: nil,
            source: "No published, verified request and scale for this vehicle.",
            decode: nil
        ),
        DriveSignalDefinition(
            id: "dcdcOutput", reading: nil, group: .powerElectronics, name: "DC-DC output",
            header: nil, request: nil, unit: "A", validRange: nil,
            source: "No published, verified request and scale for this vehicle.",
            decode: nil
        ),
        DriveSignalDefinition(
            id: "charger", reading: nil, group: .powerElectronics, name: "Onboard charger",
            header: nil, request: nil, unit: "", validRange: nil,
            source: "Public one-byte charger scales top out below a real pack, so they are not sent.",
            decode: nil
        ),
    ]

    // MARK: - Hooks used by OBDSessionMath

    /// Reported table rows the hand-written Bolt cycle does not already send,
    /// grouped under an `ATSH` per header. Empty today.
    static func additionalBoltCommands(after base: [String]) -> [String] {
        let sent = Set(base)
        var commands: [String] = []
        var header: String?
        for row in all where row.isReported && row.mode22DID != nil {
            guard let request = row.request, let rowHeader = row.header, !sent.contains(request) else { continue }
            if rowHeader != header {
                commands.append("ATSH \(rowHeader)")
                header = rowHeader
            }
            commands.append(request)
        }
        return commands
    }

    /// Decode for a Mode 22 data identifier that `OBDDecode` does not handle by
    /// hand. Values outside the row's valid range are kept so the dashboard can
    /// flag them instead of hiding a bad scale.
    static func decodeAdditionalMode22(did: UInt16, data: [UInt8]) -> [OBDReading: Double] {
        guard let row = all.first(where: { $0.isReported && $0.mode22DID == did }),
              let reading = row.reading,
              let decode = row.decode,
              let value = decode(data),
              value.isFinite
        else { return [:] }
        return [reading: value]
    }

    // MARK: - Byte helpers

    static func byte(_ data: [UInt8]) -> UInt8? {
        data.first
    }

    static func unsigned16(_ data: [UInt8]) -> Int? {
        guard data.count >= 2 else { return nil }
        return (Int(data[0]) << 8) | Int(data[1])
    }

    static func signed16(_ data: [UInt8]) -> Int? {
        guard let word = unsigned16(data) else { return nil }
        return word >= 0x8000 ? word - 0x10000 : word
    }
}
