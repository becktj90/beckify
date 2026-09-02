import Combine
import CoreMotion
import SwiftUI

@MainActor
final class BarometerModel: ObservableObject {
    @Published var kPa: Double?
    @Published var relativeMeters: Double?
    @Published var available = CMAltimeter.isRelativeAltitudeAvailable()
    @Published var status = "Waiting for altimeter…"

    private let altimeter = CMAltimeter()

    func start() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            available = false
            status = "Relative altitude is not available on this hardware."
            return
        }
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self else { return }
            if let error {
                self.status = error.localizedDescription
                return
            }
            guard let data else { return }
            self.relativeMeters = data.relativeAltitude.doubleValue
            self.kPa = data.pressure.doubleValue
            self.status = "CMAltimeter relative to session start"
        }
    }

    func stop() {
        altimeter.stopRelativeAltitudeUpdates()
    }
}

struct BarometerView: View {
    @EnvironmentObject private var jobs: JobStore
    @StateObject private var model = BarometerModel()
    @State private var jobName = "Barometer"
    @State private var notes = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FormulaCard(
                    text: "CMAltimeter pressure (kPa) and relative altitude (m)",
                    citation: "Relative altitude is from the start of this session, not sea-level elevation."
                )
                ResultCard(title: "Atmosphere") {
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
                SaveJobBar(jobName: $jobName, notes: $notes, canSave: model.available) { save() }
                SensorDisclaimer()
            }
            .padding(20)
        }
        .navigationTitle("Barometer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
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
