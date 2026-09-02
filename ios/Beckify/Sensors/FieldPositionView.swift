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
    @State private var jobName = "Position snapshot"
    @State private var notes = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FormulaCard(
                    text: "d = 2R atan2(sqrt(a), sqrt(1-a))    haversine, R = 6371 km",
                    citation: "Location is requested when this tool opens, not at app launch. Homework distance uses two saved points."
                )
                ResultCard(title: "Fix") {
                    ResultRow(label: "Latitude", value: model.latitude.map { formatCoordinate($0) } ?? "—", emphasis: true)
                    ResultRow(label: "Longitude", value: model.longitude.map { formatCoordinate($0) } ?? "—", emphasis: true)
                    ResultRow(label: "Altitude", value: model.altitude.map { Format.meters($0) } ?? "—")
                    ResultRow(label: "Speed", value: speedText)
                    ResultRow(label: "H. accuracy", value: model.accuracy.map { Format.meters($0) } ?? "—")
                    ResultRow(label: "Status", value: model.status)
                }
                if model.denied { SettingsLinkButton() }
                HStack {
                    Button("Mark A") { model.markA() }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                    Button("Mark B") { model.markB() }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent2)
                }
                ResultCard(title: "A → B") {
                    ResultRow(label: "Point A", value: pointText(model.pointA))
                    ResultRow(label: "Point B", value: pointText(model.pointB))
                    ResultRow(label: "Distance", value: model.distanceMeters.map { Format.meters($0) } ?? "—", emphasis: true, tone: Theme.good)
                    ResultRow(label: "Bearing", value: model.bearingDegrees.map { Format.degrees($0) } ?? "—")
                }
                SaveJobBar(jobName: $jobName, notes: $notes, canSave: model.latitude != nil) { save() }
                SensorDisclaimer(extra: "Saving stores the numbers you see, not a track log.")
            }
            .padding(20)
        }
        .navigationTitle("Position")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
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
