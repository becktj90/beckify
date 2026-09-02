import Combine
import CoreLocation
import SwiftUI
import BeckifyMath

struct GeoPoint: Equatable {
    var lat: Double
    var lon: Double
}

@MainActor
final class FieldPositionModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var altitude: Double?
    @Published var speed: Double?
    @Published var accuracy: Double?
    @Published var status = "Location is requested only in this tool, not at launch."
    @Published var denied = false
    @Published var pointA: GeoPoint?
    @Published var pointB: GeoPoint?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    private var didRequest = false

    func start() {
        denied = false
        switch manager.authorizationStatus {
        case .notDetermined:
            status = "Asking for When In Use location so this tool can show coordinates."
            if !didRequest {
                didRequest = true
                manager.requestWhenInUseAuthorization()
            }
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            status = "Updating (When In Use)"
        default:
            denied = true
            status = "Location permission denied. Coordinates stay hidden."
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    func markA() {
        if let lat = latitude, let lon = longitude { pointA = GeoPoint(lat: lat, lon: lon) }
    }

    func markB() {
        if let lat = latitude, let lon = longitude { pointB = GeoPoint(lat: lat, lon: lon) }
    }

    var distanceMeters: Double? {
        guard let a = pointA, let b = pointB else { return nil }
        return GeoMath.haversineMeters(lat1: a.lat, lon1: a.lon, lat2: b.lat, lon2: b.lon)
    }

    var bearingDegrees: Double? {
        guard let a = pointA, let b = pointB else { return nil }
        return GeoMath.initialBearingDegrees(lat1: a.lat, lon1: a.lon, lat2: b.lat, lon2: b.lon)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            start()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, loc.horizontalAccuracy >= 0 else { return }
        Task { @MainActor in
            latitude = loc.coordinate.latitude
            longitude = loc.coordinate.longitude
            altitude = loc.verticalAccuracy >= 0 ? loc.altitude : nil
            speed = loc.speed >= 0 ? loc.speed : nil
            accuracy = loc.horizontalAccuracy
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            status = error.localizedDescription
        }
    }
}

struct FieldPositionView: View {
    @EnvironmentObject private var jobs: JobStore
    @StateObject private var model = FieldPositionModel()
    @StoredInput(.fieldPosition, "jobName", default: "Position snapshot") private var jobName
    @State private var notes = ""

    var body: some View {
        ToolScaffold(
            toolID: .fieldPosition,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .sensor(extra: "Saving stores the numbers you see, not a track log.")
        ) {
            ShowWorkCard(
                toolID: .fieldPosition,
                symbolic: "d = 2R atan2(sqrt(a), sqrt(1-a))    haversine, R = 6371 km",
                substituted: distanceWork,
                meaning: "Location is requested when this tool opens, not at app launch. Homework distance uses two saved points on this device."
            )
            if model.denied {
                ToolEmptyState(
                    title: "Location is off",
                    detail: "Coordinates stay hidden until When In Use location is allowed. Nothing is uploaded.",
                    systemImage: "location.slash",
                    showsSettings: true
                )
            }
            ResultCard(title: "Fix", copyText: copyText) {
                ResultRow(label: "Latitude", value: model.latitude.map { formatCoordinate($0) } ?? "—", emphasis: true)
                ResultRow(label: "Longitude", value: model.longitude.map { formatCoordinate($0) } ?? "—", emphasis: true)
                ResultRow(label: "Altitude", value: model.altitude.map { Format.meters($0) } ?? "—")
                ResultRow(label: "Speed", value: speedText)
                ResultRow(label: "H. accuracy", value: model.accuracy.map { Format.meters($0) } ?? "—")
                ResultRow(label: "Status", value: model.status)
            }
            ThumbButtonRow {
                Button("Mark A") { model.markA() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .frame(minHeight: Theme.touchTarget)
                    .accessibilityLabel("Mark point A")
                Button("Mark B") { model.markB() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent2)
                    .frame(minHeight: Theme.touchTarget)
                    .accessibilityLabel("Mark point B")
            }
            ResultCard(title: "A → B") {
                ResultRow(label: "Point A", value: pointText(model.pointA))
                ResultRow(label: "Point B", value: pointText(model.pointB))
                ResultRow(label: "Distance", value: model.distanceMeters.map { Format.meters($0) } ?? "—", emphasis: true, tone: Theme.good)
                ResultRow(label: "Bearing", value: model.bearingDegrees.map { Format.degrees($0) } ?? "—")
            }
            SaveJobBar(jobName: $jobName, notes: $notes, canSave: model.latitude != nil) { save() }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var sticky: String? {
        guard let lat = model.latitude, let lon = model.longitude else { return nil }
        return "\(formatCoordinate(lat)), \(formatCoordinate(lon))"
    }

    private var copyText: String? { sticky }

    private var distanceWork: String? {
        guard let d = model.distanceMeters else {
            return "Mark A and B to plug two points into the haversine."
        }
        return "A → B = \(Format.meters(d))"
    }

    private var speedText: String {
        guard let s = model.speed else { return "—" }
        return "\(Format.number(s, digits: 2)) m/s  (\(Format.number(s * 2.236936, digits: 2)) mph)"
    }

    private func pointText(_ p: GeoPoint?) -> String {
        guard let p else { return "—" }
        return "\(formatCoordinate(p.lat)), \(formatCoordinate(p.lon))"
    }

    private func save() {
        var outputs: [String: String] = [
            "lat": model.latitude.map { formatCoordinate($0) } ?? "—",
            "lon": model.longitude.map { formatCoordinate($0) } ?? "—",
            "alt": model.altitude.map { Format.meters($0) } ?? "—",
            "speed": speedText,
        ]
        if let d = model.distanceMeters {
            outputs["A-B m"] = Format.meters(d)
        }
        jobs.save(SavedJob(
            name: jobName,
            toolID: .fieldPosition,
            notes: notes,
            inputs: [
                "A": pointText(model.pointA),
                "B": pointText(model.pointB),
            ],
            outputs: outputs
        ))
    }
}
