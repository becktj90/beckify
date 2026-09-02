import SwiftUI
import UIKit

struct DeviceHealthView: View {
    @EnvironmentObject private var jobs: JobStore
    @State private var jobName = "Device health"
    @State private var notes = ""
    @State private var batteryLevel: Float = UIDevice.current.batteryLevel
    @State private var batteryState = UIDevice.current.batteryState
    @State private var thermal = ProcessInfo.processInfo.thermalState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FormulaCard(
                    text: "UIDevice battery + ProcessInfo.thermalState",
                    citation: "Diagnostics row for field notes. Not a game, charger tester, or health claim."
                )
                ResultCard(title: "Phone") {
                    ResultRow(label: "Battery", value: batteryText, emphasis: true)
                    ResultRow(label: "Charge state", value: chargeText)
                    ResultRow(label: "Thermal", value: thermalText, tone: thermalTone)
                }
                SaveJobBar(jobName: $jobName, notes: $notes, canSave: true) { save() }
                SensorDisclaimer()
            }
            .padding(20)
        }
        .navigationTitle("Device Health")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in refresh() }
    }

    private var batteryText: String {
        batteryLevel < 0 ? "—" : Format.percent(Double(batteryLevel) * 100)
    }

    private var chargeText: String {
        switch batteryState {
        case .charging: return "Charging"
        case .full: return "Full"
        case .unplugged: return "Unplugged"
        default: return "Unknown"
        }
    }

    private var thermalText: String {
        switch thermal {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    private var thermalTone: Color {
        switch thermal {
        case .nominal: return Theme.good
        case .fair: return Theme.warn
        default: return Theme.bad
        }
    }

    private func refresh() {
        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
        thermal = ProcessInfo.processInfo.thermalState
    }

    private func save() {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .deviceHealth,
            notes: notes,
            inputs: ["source": "UIDevice / ProcessInfo"],
            outputs: [
                "battery": batteryText,
                "state": chargeText,
                "thermal": thermalText,
            ]
        ))
    }
}
