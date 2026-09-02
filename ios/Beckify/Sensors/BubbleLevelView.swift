import Combine
import CoreMotion
import SwiftUI
import BeckifyMath

@MainActor
final class LevelModel: ObservableObject {
    @Published var roll = 0.0
    @Published var pitch = 0.0
    @Published var plumb = 0.0
    @Published var available = CMMotionManager().isDeviceMotionAvailable
    @Published var status = "Waiting for motion…"

    private let motion = CMMotionManager()

    func start() {
        guard motion.isDeviceMotionAvailable else {
            available = false
            status = "Device motion is not available on this hardware."
            return
        }
        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] data, _ in
            guard let self, let g = data?.gravity else { return }
            let tilt = LevelMath.faceUpTiltDegrees(gravityX: g.x, gravityY: g.y, gravityZ: g.z)
            self.roll = tilt.x
            self.pitch = tilt.y
            self.plumb = LevelMath.portraitPlumbDeviationDegrees(gravityX: g.x, gravityY: g.y, gravityZ: g.z)
            self.status = "CoreMotion gravity"
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
    }
}

struct BubbleLevelView: View {
    @EnvironmentObject private var jobs: JobStore
    @StateObject private var model = LevelModel()
    @State private var jobName = "Level snapshot"
    @State private var notes = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FormulaCard(
                    text: "roll = atan2(gx, −gz)    pitch = atan2(gy, −gz)",
                    citation: "Face-up bubble for a surface. Plumb is the angle from portrait −Y (panel / conduit)."
                )
                bubble
                ResultCard(title: "Angles") {
                    ResultRow(label: "Roll (face-up)", value: Format.degrees(model.roll), emphasis: true)
                    ResultRow(label: "Pitch (face-up)", value: Format.degrees(model.pitch), emphasis: true)
                    ResultRow(label: "Plumb deviation", value: Format.degrees(model.plumb), tone: Theme.warn)
                    ResultRow(label: "Source", value: model.status)
                }
                SaveJobBar(jobName: $jobName, notes: $notes, canSave: model.available) { save() }
                SensorDisclaimer(extra: "Homework: these angles are from the phone IMU, not a machinist level.")
            }
            .padding(20)
        }
        .navigationTitle("Bubble Level")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var bubble: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, 220)
            let limit = side * 0.38
            let dx = CGFloat(max(-45, min(45, model.roll)) / 45) * limit
            let dy = CGFloat(max(-45, min(45, model.pitch)) / 45) * limit
            ZStack {
                Circle()
                    .stroke(Theme.border, lineWidth: 2)
                    .frame(width: side, height: side)
                Circle()
                    .stroke(Theme.accent.opacity(0.35), lineWidth: 1)
                    .frame(width: side * 0.28, height: side * 0.28)
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 22, height: 22)
                    .offset(x: dx, y: dy)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 230)
    }

    private func save() {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .bubbleLevel,
            notes: notes,
            inputs: ["frame": "xArbitraryZVertical"],
            outputs: [
                "roll": Format.degrees(model.roll),
                "pitch": Format.degrees(model.pitch),
                "plumb": Format.degrees(model.plumb),
            ]
        ))
    }
}
