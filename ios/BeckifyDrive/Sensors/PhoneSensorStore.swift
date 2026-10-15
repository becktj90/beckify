import BeckifyMath
import CoreLocation
import CoreMotion
import UIKit

/// Permission state for one phone sensor family.
enum SensorAccess: Equatable {
    /// Not asked yet. The card shows a button; nothing is requested until tapped.
    case notAsked
    case allowed
    case denied
    case unavailable
}

struct GeoPoint: Equatable {
    var latitude: Double
    var longitude: Double
}

/// Smoothed G readout. Its own object so 15 Hz updates redraw only the G card.
final class GForceFeed: ObservableObject {
    @Published private(set) var tracker = GForceTracker()
    /// True while GPS course is good enough to turn phone axes into car axes.
    @Published private(set) var aligned = false

    func add(_ vector: GVector) {
        tracker.add(vector)
        if !aligned { aligned = true }
    }

    func markUnaligned() {
        if aligned { aligned = false }
    }

    func resetPeak() {
        tracker.resetPeak()
    }

    func clear() {
        tracker.clear()
        aligned = false
    }

    static func preview(trail: [GVector], aligned: Bool = true) -> GForceFeed {
        let feed = GForceFeed()
        for vector in trail { feed.tracker.add(vector) }
        feed.aligned = aligned
        return feed
    }
}

/// Core Location, Core Motion, altimeter, and battery for the phone cards.
/// Everything stays on the device. Location and Motion & Fitness are asked
/// for only when the user taps a card that needs them.
final class PhoneSensorStore: NSObject, ObservableObject {
    @Published private(set) var locationAccess: SensorAccess = .notAsked
    @Published private(set) var motionAccess: SensorAccess = .notAsked

    @Published private(set) var gpsSpeedKph: Double?
    @Published private(set) var altitudeMeters: Double?
    @Published private(set) var lastLocationAt: Date?
    /// Last fix, for the weather lookup (rounded to 0.01° before it leaves the phone).
    @Published private(set) var coordinate: GeoPoint?
    /// GPS course, degrees from true north, while moving fast enough to trust it.
    @Published private(set) var courseDegrees: Double?
    @Published private(set) var headingDegrees: Double?
    @Published private(set) var pressureKPa: Double?
    @Published private(set) var relativeAltitudeMeters: Double?
    @Published private(set) var lastAltimeterAt: Date?
    @Published private(set) var batteryLevel: Double?
    @Published private(set) var batteryCharging = false

    let gForce: GForceFeed

    /// GPS course is noisy below walking pace, so G alignment waits for this.
    private static let minimumCourseSpeed: CLLocationSpeed = 2.5
    /// A course older than this no longer aligns the G plot.
    private static let courseMaxAge: TimeInterval = 4
    /// Publish every other 30 Hz motion sample.
    private static let motionHz = 30.0

    private let isPreview: Bool
    private var locationManager: CLLocationManager?
    private let motionManager = CMMotionManager()
    private let altimeter = CMAltimeter()
    private var running = false
    private var motionFrame: CMAttitudeReferenceFrame?
    private var lastCourse: (degrees: Double, at: Date)?
    private var motionTick = 0

    override init() {
        isPreview = false
        gForce = GForceFeed()
        super.init()
        let manager = CLLocationManager()
        manager.delegate = self
        manager.activityType = .automotiveNavigation
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.headingFilter = 2
        locationManager = manager
        locationAccess = Self.access(for: manager.authorizationStatus)
        motionAccess = Self.altimeterAccess()
    }

    private init(preview gForce: GForceFeed) {
        isPreview = true
        self.gForce = gForce
        super.init()
    }

    // MARK: Lifecycle

    /// Starts every sensor the user has already allowed. Asks for nothing.
    func start() {
        guard !isPreview, !running else { return }
        running = true
        startBattery()
        startMotion()
        if locationAccess == .allowed { startLocation() }
        if motionAccess == .allowed { startAltimeter() }
    }

    func stop() {
        guard !isPreview, running else { return }
        running = false
        locationManager?.stopUpdatingLocation()
        locationManager?.stopUpdatingHeading()
        motionManager.stopDeviceMotionUpdates()
        motionFrame = nil
        altimeter.stopRelativeAltitudeUpdates()
        UIDevice.current.isBatteryMonitoringEnabled = false
        NotificationCenter.default.removeObserver(self, name: UIDevice.batteryLevelDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIDevice.batteryStateDidChangeNotification, object: nil)
    }

    // MARK: Permission requests (from a card tap)

    func requestLocation() {
        guard !isPreview, let locationManager else { return }
        if locationAccess == .notAsked {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    /// The altimeter has no separate request call; starting updates shows the
    /// Motion & Fitness prompt the first time.
    func requestMotion() {
        guard !isPreview, motionAccess == .notAsked else { return }
        startAltimeter()
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: Location

    private func startLocation() {
        guard running, let locationManager else { return }
        locationManager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
        // True north needs location. Restart motion so the G plot can use it.
        if motionFrame != .xTrueNorthZVertical {
            motionManager.stopDeviceMotionUpdates()
            motionFrame = nil
            startMotion()
        }
    }

    private static func access(for status: CLAuthorizationStatus) -> SensorAccess {
        switch status {
        case .notDetermined: return .notAsked
        case .authorizedWhenInUse, .authorizedAlways: return .allowed
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    // MARK: Motion (G-force)

    private func startMotion() {
        guard running, motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else { return }
        let frames = CMMotionManager.availableAttitudeReferenceFrames()
        let frame: CMAttitudeReferenceFrame
        if locationAccess == .allowed, frames.contains(.xTrueNorthZVertical) {
            frame = .xTrueNorthZVertical
        } else {
            frame = .xArbitraryCorrectedZVertical
        }
        motionFrame = frame
        motionManager.deviceMotionUpdateInterval = 1.0 / Self.motionHz
        motionManager.startDeviceMotionUpdates(using: frame, to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.handle(motion)
        }
    }

    private func handle(_ motion: CMDeviceMotion) {
        motionTick += 1
        guard motionTick % 2 == 0 else { return }
        guard motionFrame == .xTrueNorthZVertical, let course = freshCourse() else {
            gForce.markUnaligned()
            return
        }
        let r = motion.attitude.rotationMatrix
        let matrix = [r.m11, r.m12, r.m13, r.m21, r.m22, r.m23, r.m31, r.m32, r.m33]
        let a = motion.userAcceleration
        guard let world = GForceMath.toReference(device: (a.x, a.y, a.z), matrix: matrix),
              let vector = GForceMath.vehicleFrame(northG: world.x, westG: world.y, courseDegrees: course)
        else { return }
        gForce.add(vector)
    }

    private func freshCourse() -> Double? {
        guard let lastCourse, Date().timeIntervalSince(lastCourse.at) <= Self.courseMaxAge else { return nil }
        return lastCourse.degrees
    }

    // MARK: Altimeter

    private func startAltimeter() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            motionAccess = .unavailable
            return
        }
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self else { return }
            if let error = error as NSError?, error.domain == CMErrorDomain,
               error.code == Int(CMErrorMotionActivityNotAuthorized.rawValue) {
                self.motionAccess = .denied
                self.altimeter.stopRelativeAltitudeUpdates()
                return
            }
            guard let data else { return }
            self.motionAccess = .allowed
            self.pressureKPa = data.pressure.doubleValue
            self.relativeAltitudeMeters = data.relativeAltitude.doubleValue
            self.lastAltimeterAt = Date()
        }
    }

    private static func altimeterAccess() -> SensorAccess {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return .unavailable }
        switch CMAltimeter.authorizationStatus() {
        case .notDetermined: return .notAsked
        case .authorized: return .allowed
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    // MARK: Battery

    private func startBattery() {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        readBattery()
        NotificationCenter.default.addObserver(self, selector: #selector(batteryChanged), name: UIDevice.batteryLevelDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(batteryChanged), name: UIDevice.batteryStateDidChangeNotification, object: nil)
    }

    @objc private func batteryChanged() {
        readBattery()
    }

    private func readBattery() {
        let device = UIDevice.current
        // −1 means unknown (Simulator, or monitoring off). Unknown stays blank.
        batteryLevel = device.batteryLevel >= 0 ? Double(device.batteryLevel) : nil
        batteryCharging = device.batteryState == .charging || device.batteryState == .full
    }
}

extension PhoneSensorStore: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationAccess = Self.access(for: manager.authorizationStatus)
        if locationAccess == .allowed {
            startLocation()
        } else {
            manager.stopUpdatingLocation()
            manager.stopUpdatingHeading()
            gpsSpeedKph = nil
            headingDegrees = nil
            coordinate = nil
            courseDegrees = nil
        }
    }

    /// Last fix saved across launches, for weather only.
    private enum LastFixKey {
        static let lat = "beckify.drive.lastFix.lat"
        static let lon = "beckify.drive.lastFix.lon"
        static let at = "beckify.drive.lastFix.at"
    }

    /// Where to fetch weather: the live fix, else the last saved fix if it is
    /// under two hours old. Weather changes slowly, so a recent point is close enough.
    func weatherPoint(now: Date) -> GeoPoint? {
        if let coordinate { return coordinate }
        let defaults = UserDefaults.standard
        let savedAt = defaults.double(forKey: LastFixKey.at)
        guard savedAt > 0, now.timeIntervalSince1970 - savedAt < 7_200 else { return nil }
        return GeoPoint(latitude: defaults.double(forKey: LastFixKey.lat), longitude: defaults.double(forKey: LastFixKey.lon))
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        lastLocationAt = location.timestamp
        // Negative speed or accuracy means the fix has no valid speed.
        if location.speed >= 0, location.speedAccuracy >= 0 {
            gpsSpeedKph = location.speed * 3.6
        } else {
            gpsSpeedKph = nil
        }
        altitudeMeters = location.verticalAccuracy > 0 ? location.altitude : nil
        coordinate = GeoPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let defaults = UserDefaults.standard
        defaults.set(location.coordinate.latitude, forKey: LastFixKey.lat)
        defaults.set(location.coordinate.longitude, forKey: LastFixKey.lon)
        defaults.set(location.timestamp.timeIntervalSince1970, forKey: LastFixKey.at)
        if location.course >= 0, location.courseAccuracy >= 0, location.speed >= Self.minimumCourseSpeed {
            lastCourse = (location.course, location.timestamp)
            courseDegrees = location.course
        } else {
            courseDegrees = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else {
            headingDegrees = nil
            return
        }
        headingDegrees = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .denied {
            locationAccess = .denied
        }
    }
}

// MARK: - Previews

extension PhoneSensorStore {
    struct PreviewValues {
        var locationAccess: SensorAccess = .allowed
        var motionAccess: SensorAccess = .allowed
        var gpsSpeedKph: Double?
        var altitudeMeters: Double?
        var headingDegrees: Double?
        var courseDegrees: Double?
        var coordinate: GeoPoint? = GeoPoint(latitude: 42.33, longitude: -83.05)
        var pressureKPa: Double?
        var relativeAltitudeMeters: Double?
        var batteryLevel: Double?
        var batteryCharging = false
        var gTrail: [GVector] = []
        var gAligned = true
    }

    static func preview(_ values: PreviewValues, now: Date) -> PhoneSensorStore {
        let store = PhoneSensorStore(preview: GForceFeed.preview(trail: values.gTrail, aligned: values.gAligned))
        store.locationAccess = values.locationAccess
        store.motionAccess = values.motionAccess
        store.gpsSpeedKph = values.gpsSpeedKph
        store.altitudeMeters = values.altitudeMeters
        store.lastLocationAt = values.gpsSpeedKph == nil && values.altitudeMeters == nil ? nil : now
        store.headingDegrees = values.headingDegrees
        store.courseDegrees = values.courseDegrees
        store.coordinate = values.coordinate
        store.pressureKPa = values.pressureKPa
        store.relativeAltitudeMeters = values.relativeAltitudeMeters
        store.lastAltimeterAt = values.pressureKPa == nil ? nil : now
        store.batteryLevel = values.batteryLevel
        store.batteryCharging = values.batteryCharging
        return store
    }
}
