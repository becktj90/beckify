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

    /// Owned session so deinit can stop only if start actually ran. Creating
    /// CMAltimeter just to call stop trips TCC on iPadOS 26.
    private var session: AltimeterSession?
    private var generation: UInt64 = 0
    private var wantsRunning = false
    private let updateQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Beckify.Barometer"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    func start() {
        wantsRunning = true
        beginIfPossible()
    }

    func stop() {
        wantsRunning = false
        session?.stop()
        session = nil
    }

    /// Relative altitude / pressure only. Do not call
    /// `isAbsoluteAltitudeAvailable()` or `startAbsoluteAltitudeUpdates`.
    private func beginIfPossible() {
        guard wantsRunning else { return }
        if session?.isUpdating == true { return }

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

        generation += 1
        let token = generation
        let next = AltimeterSession()
        session = next
        next.start(queue: updateQueue) { [weak self] data, error in
            Task { @MainActor in
                guard let self, self.wantsRunning, self.generation == token else { return }
                if let error {
                    self.applyUpdateError(error)
                    return
                }
                guard let data else { return }
                let pressure = data.pressure.doubleValue
                let delta = data.relativeAltitude.doubleValue
                guard pressure.isFinite, delta.isFinite else { return }
                self.relativeMeters = delta
                self.kPa = pressure
                self.available = true
                self.permissionDenied = false
                self.status = "CMAltimeter relative to session start"
            }
        }
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

/// Starts relative updates only after hardware/auth checks. Stop is a no-op
/// unless start ran — required on iPadOS 26 TCC.
private final class AltimeterSession {
    private let altimeter = CMAltimeter()
    private(set) var isUpdating = false

    func start(queue: OperationQueue, handler: @escaping CMAltitudeHandler) {
        guard !isUpdating else { return }
        isUpdating = true
        altimeter.startRelativeAltitudeUpdates(to: queue, withHandler: handler)
    }

    func stop() {
        guard isUpdating else { return }
        isUpdating = false
        altimeter.stopRelativeAltitudeUpdates()
    }

    deinit {
        if isUpdating {
            altimeter.stopRelativeAltitudeUpdates()
        }
    }
}

struct BarometerView: View {
    @EnvironmentObject private var jobs: JobStore
    @Environment(\.scenePhase) private var scenePhase
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
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                model.start()
            case .background:
                model.stop()
            default:
                break
            }
        }
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
