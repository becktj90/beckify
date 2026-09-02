import Combine
import CoreMotion
import SwiftUI
import BeckifyMath

@MainActor
final class MotionSnapshotModel: ObservableObject {
    @Published var gravityG = 0.0
    @Published var userG = 0.0
    @Published var totalG = 0.0
    @Published var gx = 0.0
    @Published var gy = 0.0
    @Published var gz = 0.0
    @Published var ux = 0.0
    @Published var uy = 0.0
    @Published var uz = 0.0
    @Published var peakUserG = 0.0
    @Published var available = CMMotionManager().isDeviceMotionAvailable
    @Published var status = "Waiting for device motion…"

    private let motion = CMMotionManager()

    func start() {
        guard motion.isDeviceMotionAvailable else {
            available = false
            status = "Device motion is not available."
            return
        }
        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let g = data.gravity
            let u = data.userAcceleration
            self.gx = g.x
            self.gy = g.y
            self.gz = g.z
            self.ux = u.x
            self.uy = u.y
            self.uz = u.z
            self.gravityG = MotionMath.magnitudeG(x: g.x, y: g.y, z: g.z)
            self.userG = MotionMath.magnitudeG(x: u.x, y: u.y, z: u.z)
            self.totalG = MotionMath.magnitudeG(x: g.x + u.x, y: g.y + u.y, z: g.z + u.z)
            self.peakUserG = max(self.peakUserG, self.userG)
            self.status = "CoreMotion device motion"
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
    }

    func resetPeak() {
        peakUserG = 0
    }
}

struct MotionSnapshotView: View {
    @EnvironmentObject private var jobs: JobStore
    @StateObject private var model = MotionSnapshotModel()
    @State private var jobName = "g-force snapshot"
    @State private var notes = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FormulaCard(
                    text: "|a| = √(x² + y² + z²)    1 g = 9.80665 m/s²",
                    citation: "User acceleration is motion with gravity removed. Peak hold is a snapshot, not a vibration logger."
                )
                ResultCard(title: "Acceleration") {
                    ResultRow(label: "|gravity|", value: "\(Format.number(model.gravityG, digits: 3)) g", emphasis: true)
                    ResultRow(label: "|user|", value: "\(Format.number(model.userG, digits: 3)) g", emphasis: true, tone: Theme.warn)
                    ResultRow(label: "|total|", value: "\(Format.number(model.totalG, digits: 3)) g")
                    ResultRow(label: "Peak |user|", value: "\(Format.number(model.peakUserG, digits: 3)) g")
                    ResultRow(label: "|user| m/s²", value: "\(Format.number(MotionMath.metersPerSecondSquared(fromG: model.userG), digits: 2)) m/s²")
                    ResultRow(label: "Source", value: model.status)
                }
                Button("Reset peak") { model.resetPeak() }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                SaveJobBar(jobName: $jobName, notes: $notes, canSave: model.available) { save() }
                SensorDisclaimer()
            }
            .padding(20)
        }
        .navigationTitle("g-Force Snapshot")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private func save() {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .motionSnapshot,
            notes: notes,
            inputs: ["frame": "xArbitraryZVertical"],
            outputs: [
                "gravity g": Format.number(model.gravityG, digits: 3),
                "user g": Format.number(model.userG, digits: 3),
                "peak user g": Format.number(model.peakUserG, digits: 3),
                "user m/s2": Format.number(MotionMath.metersPerSecondSquared(fromG: model.userG), digits: 2),
            ]
        ))
    }
}
