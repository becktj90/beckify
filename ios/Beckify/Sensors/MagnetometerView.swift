import Combine
import CoreMotion
import SwiftUI
import BeckifyMath

@MainActor
final class MagnetometerModel: ObservableObject {
    @Published var x = 0.0
    @Published var y = 0.0
    @Published var z = 0.0
    @Published var magnitude = 0.0
    @Published var heading = 0.0
    @Published var available = false
    @Published var status = "Waiting for magnetometer…"

    private let motion = CMMotionManager()

    init() {
        available = motion.isDeviceMotionAvailable
            && CMMotionManager.availableAttitudeReferenceFrames.contains(.xMagneticNorthZVertical)
    }

    func start() {
        guard motion.isDeviceMotionAvailable,
              CMMotionManager.availableAttitudeReferenceFrames.contains(.xMagneticNorthZVertical) else {
            available = false
            status = "Magnetic-north device motion is not available on this hardware."
            return
        }
        motion.deviceMotionUpdateInterval = 1.0 / 20.0
        motion.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { [weak self] data, error in
            guard let self else { return }
            if let error {
                self.status = error.localizedDescription
                return
            }
            guard let data else { return }
            let f = data.magneticField.field
            self.x = f.x
            self.y = f.y
            self.z = f.z
            self.magnitude = MagneticMath.magnitudeMicrotesla(x: f.x, y: f.y, z: f.z)
            if data.heading >= 0 {
                self.heading = data.heading
            } else {
                self.heading = MagneticMath.headingDegrees(x: f.x, y: f.y)
            }
            self.status = "CMDeviceMotion magnetic field (µT), heading vs magnetic north"
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
    }
}

struct MagnetometerView: View {
    @EnvironmentObject private var jobs: JobStore
    @StateObject private var model = MagnetometerModel()
    @State private var jobName = "Magnetic field"
    @State private var notes = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FormulaCard(
                    text: "|B| = √(x² + y² + z²) µT    heading from xMagneticNorthZVertical",
                    citation: "Earth’s field is roughly 25–65 µT. This is not a survey compass or EMI probe."
                )
                ResultCard(title: "Field") {
                    ResultRow(label: "Magnitude", value: Format.microtesla(model.magnitude), emphasis: true, tone: Theme.good)
                    ResultRow(label: "Gauss", value: "\(Format.number(MagneticMath.gauss(fromMicrotesla: model.magnitude), digits: 3)) G")
                    ResultRow(label: "Heading", value: Format.degrees(model.heading), emphasis: true)
                    ResultRow(label: "Bx", value: Format.microtesla(model.x))
                    ResultRow(label: "By", value: Format.microtesla(model.y))
                    ResultRow(label: "Bz", value: Format.microtesla(model.z))
                    ResultRow(label: "Source", value: model.status)
                }
                SaveJobBar(jobName: $jobName, notes: $notes, canSave: model.available) { save() }
                SensorDisclaimer(extra: "Homework: compare |B| outdoors vs near a transformer, and note it is the phone’s magnetometer, not a lab probe.")
            }
            .padding(20)
        }
        .navigationTitle("Magnetometer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private func save() {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .magnetometer,
            notes: notes,
            inputs: ["units": "µT"],
            outputs: [
                "|B|": Format.microtesla(model.magnitude),
                "G": "\(Format.number(MagneticMath.gauss(fromMicrotesla: model.magnitude), digits: 3)) G",
                "heading": Format.degrees(model.heading),
                "Bx": Format.microtesla(model.x),
                "By": Format.microtesla(model.y),
                "Bz": Format.microtesla(model.z),
            ]
        ))
    }
}
