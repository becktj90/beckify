import Combine
import CoreMotion
import SwiftUI

@MainActor
final class BarometerModel: ObservableObject {
    @Published var kPa: Double?
    @Published var relativeMeters: Double?
    @Published var available = false
    @Published var permissionDenied = false
    @Published var status = "Waiting for altimeter…"

    /// Created only after hardware + authorization checks pass. Never instantiate
    /// CMAltimeter just to call stop — that can trip TCC on recent iOS.
    private var altimeter: CMAltimeter?
    private var isUpdating = false
    private let updateQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Beckify.Barometer"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    func start() {
        if isUpdating { return }

        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            markUnavailable(
                "This device does not have a barometer. Pressure and relative altitude are unavailable."
            )
            return
        }

        switch CMAltimeter.authorizationStatus() {
        case .denied:
            permissionDenied = true
            markUnavailable("Motion & Fitness permission is off. Pressure and relative altitude stay unavailable.")
            return
        case .restricted:
            permissionDenied = true
            markUnavailable("Motion & Fitness access is restricted on this device. Pressure and relative altitude are unavailable.")
            return
        case .authorized, .notDetermined:
            break
        @unknown default:
            break
        }

        available = true
        permissionDenied = false
        status = "Waiting for altimeter…"

        let sensor = altimeter ?? CMAltimeter()
        altimeter = sensor
        isUpdating = true
        sensor.startRelativeAltitudeUpdates(to: updateQueue) { [weak self] data, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.applyUpdateError(error)
                    return
                }
                guard let data else { return }
                self.relativeMeters = data.relativeAltitude.doubleValue
                self.kPa = data.pressure.doubleValue
                self.available = true
                self.permissionDenied = false
                self.status = "CMAltimeter relative to session start"
            }
        }
    }

    func stop() {
        guard isUpdating else { return }
        isUpdating = false
        altimeter?.stopRelativeAltitudeUpdates()
    }

    private func markUnavailable(_ message: String) {
        available = false
        kPa = nil
        relativeMeters = nil
        status = message
    }

    private func applyUpdateError(_ error: Error) {
        stop()
        switch CMAltimeter.authorizationStatus() {
        case .denied, .restricted:
            permissionDenied = true
            markUnavailable("Motion & Fitness permission is off. Pressure and relative altitude stay unavailable.")
        default:
            if !CMAltimeter.isRelativeAltitudeAvailable() {
                permissionDenied = false
                markUnavailable("This device does not have a barometer. Pressure and relative altitude are unavailable.")
            } else {
                markUnavailable(error.localizedDescription)
            }
        }
    }
}

struct BarometerView: View {
    @EnvironmentObject private var jobs: JobStore
    @StateObject private var model = BarometerModel()
    @StoredInput(.barometer, "jobName", default: "Barometer") private var jobName
    @State private var notes = ""

    var body: some View {
        ToolScaffold(
            toolID: .barometer,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .sensor(extra: nil)
        ) {
            ShowWorkCard(
                toolID: .barometer,
                symbolic: "CMAltimeter pressure (kPa) and relative altitude (m)",
                substituted: sticky,
                meaning: "Relative altitude is from the start of this session, not sea-level elevation."
            )
            if !model.available {
                ToolEmptyState(
                    title: model.permissionDenied ? "Motion access is off" : "No barometer",
                    detail: model.status,
                    systemImage: "barometer",
                    showsSettings: model.permissionDenied
                )
            }
            ResultCard(title: "Atmosphere", copyText: copyText) {
                ResultRow(
                    label: "Pressure",
                    value: model.kPa.map { "\(Format.number($0, digits: 3)) kPa" } ?? "—",
                    emphasis: true
                )
                ResultRow(
                    label: "Relative Δh",
                    value: model.relativeMeters.map { Format.meters($0) } ?? "—",
                    emphasis: true,
                    tone: Theme.good
                )
                ResultRow(label: "Source", value: model.status)
            }
            SaveJobBar(jobName: $jobName, notes: $notes, canSave: model.kPa != nil) { save() }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var sticky: String? {
        model.kPa.map { "\(Format.number($0, digits: 3)) kPa" }
    }
    private var copyText: String? {
        guard let kPa = model.kPa else { return nil }
        let height = model.relativeMeters.map { Format.meters($0) } ?? "—"
        return "\(Format.number(kPa, digits: 3)) kPa, Δh \(height)"
    }

    private func save() {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .barometer,
            notes: notes,
            inputs: ["sensor": "CMAltimeter"],
            outputs: [
                "kPa": model.kPa.map { Format.number($0, digits: 3) } ?? "—",
                "relative m": model.relativeMeters.map { Format.meters($0) } ?? "—",
            ]
        ))
    }
}
