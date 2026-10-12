import BeckifyMath
import Foundation

enum DriveAppearance: String, CaseIterable, Identifiable {
    case dark
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: return "Dark"
        case .system: return "Match System"
        }
    }
}

/// Card order, hidden cards, units, and appearance. On-device UserDefaults only.
final class DashboardPreferences: ObservableObject {
    @Published var layout: DashboardLayout {
        didSet { defaults?.set(layout.encoded(), forKey: Key.layout) }
    }
    /// Saved only once the user picks a unit, so the region keeps deciding until then.
    @Published var units: DriveUnitPreference {
        didSet {
            defaults?.set(units.speed.rawValue, forKey: Key.speed)
            defaults?.set(units.temperature.rawValue, forKey: Key.temperature)
            defaults?.set(units.power.rawValue, forKey: Key.power)
            defaults?.set(units.torque.rawValue, forKey: Key.torque)
        }
    }
    @Published var appearance: DriveAppearance {
        didSet { defaults?.set(appearance.rawValue, forKey: Key.appearance) }
    }

    private let defaults: UserDefaults?

    private enum Key {
        static let layout = "beckify.drive.dashboard.layout"
        static let speed = "beckify.drive.units.speed"
        static let temperature = "beckify.drive.units.temperature"
        static let power = "beckify.drive.units.power"
        static let torque = "beckify.drive.units.torque"
        static let appearance = "beckify.drive.appearance"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        layout = DashboardLayout.decoded(from: defaults.data(forKey: Key.layout))
        let system = Self.regionUnits()
        units = DriveUnitPreference(
            speed: defaults.string(forKey: Key.speed).flatMap(DriveSpeedUnit.init(rawValue:)) ?? system.speed,
            temperature: defaults.string(forKey: Key.temperature).flatMap(DriveTemperatureUnit.init(rawValue:)) ?? system.temperature,
            power: defaults.string(forKey: Key.power).flatMap(DrivePowerUnit.init(rawValue:)) ?? system.power,
            torque: defaults.string(forKey: Key.torque).flatMap(DriveTorqueUnit.init(rawValue:)) ?? system.torque
        )
        appearance = defaults.string(forKey: Key.appearance).flatMap(DriveAppearance.init(rawValue:)) ?? .dark
    }

    /// In-memory preferences for previews.
    init(preview units: DriveUnitPreference, layout: DashboardLayout = .standard, appearance: DriveAppearance = .dark) {
        defaults = nil
        self.layout = layout
        self.units = units
        self.appearance = appearance
    }

    func useSystemUnits() {
        units = Self.regionUnits()
        defaults?.removeObject(forKey: Key.speed)
        defaults?.removeObject(forKey: Key.temperature)
        defaults?.removeObject(forKey: Key.power)
        defaults?.removeObject(forKey: Key.torque)
    }

    private static func regionUnits() -> DriveUnitPreference {
        let system = Locale.current.measurementSystem
        let identifier = system == .us ? "us" : (system == .uk ? "uk" : "metric")
        return DriveUnitPreference.systemDefault(measurementSystem: identifier)
    }
}
