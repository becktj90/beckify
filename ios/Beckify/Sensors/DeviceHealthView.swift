import Combine
import Darwin
import os
import SwiftUI
import UIKit
import BeckifyMath

@MainActor
final class DeviceHealthModel: ObservableObject {
    @Published private(set) var snapshot = DeviceHealthMath.snapshot(
        batteryLevel: -1,
        charge: .unknown,
        lowPower: false,
        thermal: .unknown,
        freeImportantBytes: nil,
        freeOpportunisticBytes: nil,
        volumeTotalBytes: nil,
        identifier: "",
        udiModel: "",
        systemName: "",
        systemVersion: "",
        uptimeSeconds: 0,
        bootDate: nil,
        brightness: -1,
        physicalMemoryBytes: nil,
        appHeadroomBytes: nil,
        activeProcessors: 0,
        installedProcessors: 0
    )
    private var tick: AnyCancellable?

    func start() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh()
        tick?.cancel()
        tick = Timer.publish(every: 15, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    func stop() {
        tick?.cancel()
        tick = nil
        UIDevice.current.isBatteryMonitoringEnabled = false
    }

    func refresh() {
        let device = UIDevice.current
        let info = ProcessInfo.processInfo
        let volume = Self.volumeCapacity()
        let boot = Self.bootDate()
        let now = Date()
        let wallUptime: TimeInterval
        if let boot {
            wallUptime = max(0, now.timeIntervalSince(boot))
        } else {
            wallUptime = info.systemUptime
        }
        snapshot = DeviceHealthMath.snapshot(
            batteryLevel: Double(device.batteryLevel),
            charge: Self.charge(device.batteryState),
            lowPower: info.isLowPowerModeEnabled,
            thermal: Self.thermal(info.thermalState),
            freeImportantBytes: volume.important,
            freeOpportunisticBytes: volume.opportunistic,
            volumeTotalBytes: volume.total,
            identifier: Self.machineIdentifier(),
            udiModel: device.model,
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            uptimeSeconds: wallUptime,
            bootDate: boot,
            now: now,
            brightness: Double(UIScreen.main.brightness),
            physicalMemoryBytes: info.physicalMemory,
            appHeadroomBytes: Self.appHeadroomBytes(),
            activeProcessors: info.activeProcessorCount,
            installedProcessors: info.processorCount
        )
    }

    private static func charge(_ state: UIDevice.BatteryState) -> DeviceHealthCharge {
        switch state {
        case .charging: return .charging
        case .full: return .full
        case .unplugged: return .unplugged
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }

    private static func thermal(_ state: ProcessInfo.ThermalState) -> DeviceHealthThermal {
        switch state {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .unknown
        }
    }

    private static func machineIdentifier() -> String {
        var system = utsname()
        uname(&system)
        return withUnsafePointer(to: &system.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }

    private static func bootDate() -> Date? {
        var boot = timeval()
        var size = MemoryLayout<timeval>.size
        let status = sysctlbyname("kern.boottime", &boot, &size, nil, 0)
        guard status == 0, boot.tv_sec > 0 else { return nil }
        let seconds = TimeInterval(boot.tv_sec) + TimeInterval(boot.tv_usec) / 1_000_000
        return Date(timeIntervalSince1970: seconds)
    }

    private static func volumeCapacity() -> (important: Int64?, opportunistic: Int64?, total: Int64?) {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityForOpportunisticUsageKey,
            .volumeTotalCapacityKey,
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else {
            return (nil, nil, nil)
        }
        return (
            values.volumeAvailableCapacityForImportantUsage,
            values.volumeAvailableCapacityForOpportunisticUsage,
            values.volumeTotalCapacity.map { Int64($0) }
        )
    }

    /// Remaining bytes this process can allocate before jetsam. 0 means unsupported — not “no RAM”.
    private static func appHeadroomBytes() -> UInt64? {
        let bytes = os_proc_available_memory()
        guard bytes > 0 else { return nil }
        return UInt64(bytes)
    }
}

struct DeviceHealthView: View {
    @EnvironmentObject private var jobs: JobStore
    @Environment(\.scenePhase) private var scenePhase
    @StoredInput(.deviceHealth, "jobName", default: "Device health") private var jobName
    @StateObject private var model = DeviceHealthModel()
    @State private var notes = ""

    var body: some View {
        ToolScaffold(
            toolID: .deviceHealth,
            stickyAnswer: snap.sticky,
            copyText: snap.copyText,
            disclaimer: .sensor(extra: "Charge is not Apple Battery Health (Maximum Capacity). Thermal is a throttle band, not °C. Storage is FileManager volume capacity. Not a charger tester.")
        ) {
            ShowWorkCard(
                toolID: .deviceHealth,
                symbolic: "UIDevice.batteryLevel + batteryState + ProcessInfo.thermalState + isLowPowerModeEnabled + FileManager volume + utsname + kern.boottime",
                substituted: snap.copyText,
                meaning: "Public snapshot for field notes. Charge is not pack health. Thermal is Apple’s throttle band, not a thermometer. Unavailable values stay blank — this tool will not invent them."
            )
            ResultCard(title: "Battery", copyText: snap.copyText) {
                ResultRow(label: "Charge", value: snap.battery, emphasis: true, tone: tone(snap.batteryTone))
                ResultRow(label: "State", value: snap.charge, tone: tone(snap.chargeTone))
                ResultRow(label: "Low Power Mode", value: snap.lowPower, tone: tone(snap.lowPowerTone))
                Text(snap.chargeNote)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
                Text(snap.lowPowerNote)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            ResultCard(title: "Thermal") {
                ResultRow(label: "State", value: snap.thermal, emphasis: true, tone: tone(snap.thermalTone))
                Text(snap.thermalMeaning)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
            }
            ResultCard(title: "Storage") {
                ResultRow(label: "Free (user files)", value: snap.freeImportant, emphasis: true)
                ResultRow(label: "Free (caches)", value: snap.freeOpportunistic)
                ResultRow(label: "Volume", value: snap.volumeTotal)
                Text("FileManager volume capacity. User-files free can include space iOS would purge. Not a SMART disk test.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
            }
            ResultCard(title: "Phone") {
                ResultRow(label: "Model", value: snap.model, emphasis: true)
                ResultRow(label: "Identifier", value: snap.identifier)
                ResultRow(label: "System", value: snap.system)
                ResultRow(label: snap.uptimeLabel, value: snap.uptime)
                ResultRow(label: "Booted", value: snap.booted)
            }
            ResultCard(title: "Runtime") {
                ResultRow(label: "Brightness", value: snap.brightness)
                ResultRow(label: "Installed RAM", value: snap.ram)
                ResultRow(label: "App headroom", value: snap.appHeadroom)
                ResultRow(label: "CPUs", value: snap.processors)
                Text("App headroom is remaining allocation for this process before jetsam — not system-wide free RAM. Brightness is the system slider, read-only.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
            }
            SaveJobBar(jobName: $jobName, notes: $notes, canSave: true) { save() }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)) { _ in
            model.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)) { _ in
            model.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
            model.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            model.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.brightnessDidChangeNotification)) { _ in
            model.refresh()
        }
    }

    private var snap: DeviceHealthSnapshot { model.snapshot }

    private func tone(_ value: DeviceHealthTone) -> Color {
        switch value {
        case .good: return Theme.good
        case .warn: return Theme.warn
        case .bad: return Theme.bad
        case .muted: return Theme.muted
        }
    }

    private func save() {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .deviceHealth,
            notes: notes,
            inputs: [
                "source": "UIDevice / ProcessInfo / FileManager / utsname / kern.boottime",
            ],
            outputs: snap.saveOutputs
        ))
    }
}
