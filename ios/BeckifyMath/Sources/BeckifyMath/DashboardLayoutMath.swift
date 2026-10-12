import Foundation

/// Card groups on the Drive dashboard, in screen order.
public enum DashboardSection: String, CaseIterable, Sendable {
    case vehicle
    case battery
    case motor
    case powerElectronics
    case phone

    public var title: String {
        switch self {
        case .vehicle: return "Vehicle"
        case .battery: return "Battery"
        case .motor: return "Motor"
        case .powerElectronics: return "Power electronics"
        case .phone: return "Phone sensors"
        }
    }

    /// SF Symbol for the section header.
    public var symbol: String {
        switch self {
        case .vehicle: return "car.fill"
        case .battery: return "battery.100"
        case .motor: return "bolt.fill"
        case .powerElectronics: return "cpu"
        case .phone: return "iphone"
        }
    }

    public static func sections(for layout: DriveLayout) -> [DashboardSection] {
        switch layout {
        case .powertrain: return [.vehicle, .phone]
        case .ev: return [.battery, .motor, .powerElectronics, .phone]
        }
    }
}

/// Every card the dashboard can draw. The hero (speed / charge) is not a card.
public enum DashboardCardID: String, CaseIterable, Sendable, Codable {
    // Combustion and hybrid
    case coolant
    case engineLoad
    case throttle
    case fuel
    case ambient
    case moduleVolts
    // EV battery
    case hvCurrent
    case packTemp
    case capacity
    case remainingLifeHD
    case planningRange
    // EV motor
    case motorTemp
    case driveState
    // EV power electronics (moduleVolts also lives here on an EV)
    case inverterTemp
    case dcdcOutput
    case charger
    // Phone
    case gpsSpeed
    case altitude
    case compass
    case gForce
    case barometer
    case phoneBattery
    case trip

    public var title: String {
        switch self {
        case .coolant: return "Coolant"
        case .engineLoad: return "Engine load"
        case .throttle: return "Throttle"
        case .fuel: return "Fuel level"
        case .ambient: return "Ambient"
        case .moduleVolts: return "12 V bus"
        case .hvCurrent: return "HV current"
        case .packTemp: return "Pack temp"
        case .capacity: return "Capacity"
        case .remainingLifeHD: return "Remaining life (HD)"
        case .planningRange: return "Planning range"
        case .motorTemp: return "Motor temp"
        case .driveState: return "Drive / regen"
        case .inverterTemp: return "Inverter temp"
        case .dcdcOutput: return "DC-DC output"
        case .charger: return "Onboard charger"
        case .gpsSpeed: return "GPS speed"
        case .altitude: return "Altitude"
        case .compass: return "Heading"
        case .gForce: return "G-force"
        case .barometer: return "Barometer"
        case .phoneBattery: return "Phone battery"
        case .trip: return "Trip"
        }
    }

    /// The section this card sits in for a given layout, or nil when it is not shown there.
    public func section(for layout: DriveLayout) -> DashboardSection? {
        switch self {
        case .coolant, .engineLoad, .throttle, .fuel, .ambient:
            return layout == .powertrain ? .vehicle : nil
        case .moduleVolts:
            return layout == .powertrain ? .vehicle : .powerElectronics
        case .hvCurrent, .packTemp, .capacity, .remainingLifeHD, .planningRange:
            return layout == .ev ? .battery : nil
        case .motorTemp, .driveState:
            return layout == .ev ? .motor : nil
        case .inverterTemp, .dcdcOutput, .charger:
            return layout == .ev ? .powerElectronics : nil
        case .gpsSpeed, .altitude, .compass, .gForce, .barometer, .phoneBattery, .trip:
            return .phone
        }
    }

    /// Wide cards take a full row in the grid.
    public var isWide: Bool {
        switch self {
        case .hvCurrent, .gForce, .trip: return true
        default: return false
        }
    }
}

/// The user's card order and hidden set. Persisted as JSON; unknown ids from an
/// older or newer build are dropped and new cards are appended.
public struct DashboardLayout: Equatable, Sendable, Codable {
    public private(set) var order: [DashboardCardID]
    public private(set) var hidden: Set<DashboardCardID>

    public init(order: [DashboardCardID] = DashboardCardID.allCases, hidden: Set<DashboardCardID> = []) {
        self.order = order
        self.hidden = hidden
        normalize()
    }

    public static let standard = DashboardLayout()

    public func cards(in section: DashboardSection, for layout: DriveLayout, includeHidden: Bool = false) -> [DashboardCardID] {
        order.filter { card in
            card.section(for: layout) == section && (includeHidden || !hidden.contains(card))
        }
    }

    public func isHidden(_ card: DashboardCardID) -> Bool {
        hidden.contains(card)
    }

    public mutating func setHidden(_ card: DashboardCardID, _ isHidden: Bool) {
        if isHidden { hidden.insert(card) } else { hidden.remove(card) }
    }

    /// Reorders within one section (hidden cards included, as the edit list shows them).
    /// `offsets` and `destination` follow SwiftUI's `onMove`.
    public mutating func move(in section: DashboardSection, for layout: DriveLayout, from offsets: IndexSet, to destination: Int) {
        var local = cards(in: section, for: layout, includeHidden: true)
        guard !offsets.isEmpty, offsets.allSatisfy({ $0 >= 0 && $0 < local.count }) else { return }
        let clamped = min(max(destination, 0), local.count)
        let moving = offsets.map { local[$0] }
        let before = offsets.filter { $0 < clamped }.count
        for index in offsets.sorted(by: >) {
            local.remove(at: index)
        }
        local.insert(contentsOf: moving, at: clamped - before)
        // Write the section back into the slots it already occupies in the global order.
        let slots = order.indices.filter { order[$0].section(for: layout) == section }
        guard slots.count == local.count else { return }
        for (slot, card) in zip(slots, local) {
            order[slot] = card
        }
    }

    public mutating func reset() {
        self = .standard
    }

    private mutating func normalize() {
        var seen = Set<DashboardCardID>()
        order = order.filter { seen.insert($0).inserted }
        for card in DashboardCardID.allCases where !seen.contains(card) {
            order.append(card)
        }
    }

    // MARK: Codable — tolerant of ids this build does not know

    private enum CodingKeys: String, CodingKey {
        case order
        case hidden
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawOrder = try container.decodeIfPresent([String].self, forKey: .order) ?? []
        let rawHidden = try container.decodeIfPresent([String].self, forKey: .hidden) ?? []
        self.init(
            order: rawOrder.compactMap(DashboardCardID.init(rawValue:)),
            hidden: Set(rawHidden.compactMap(DashboardCardID.init(rawValue:)))
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(order.map(\.rawValue), forKey: .order)
        try container.encode(hidden.map(\.rawValue).sorted(), forKey: .hidden)
    }

    public func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    public static func decoded(from data: Data?) -> DashboardLayout {
        guard let data, let layout = try? JSONDecoder().decode(DashboardLayout.self, from: data) else {
            return .standard
        }
        return layout
    }
}
