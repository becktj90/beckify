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
            disclaimer: .sensor(extra: "Charge is not Apple Battery Health (Maximum Capacity). Thermal is a throttle band, not °C. Storage is FileManager volume capacity. The hardware identifier is not the product name. Not a charger tester.")
        ) {
            ShowWorkCard(
                toolID: .deviceHealth,
                symbolic: "UIDevice.batteryLevel + batteryState + ProcessInfo.thermalState + isLowPowerModeEnabled + FileManager volume + utsname + kern.boottime",
                substituted: snap.copyText,
                meaning: "Public snapshot for field notes. Charge is not pack health. Thermal is Apple’s throttle band, not a thermometer. utsname.machine is an internal identifier, not the marketing name. Unavailable values stay blank — this tool will not invent them."
            )
            ResultCard(title: "Battery", copyText: snap.copyText) {
                batteryHero
                if let fraction = snap.batteryFraction {
                    DeviceHealthFillBar(
                        fraction: fraction,
                        fill: tone(snap.batteryTone),
                        accessibilityLabel: "Charge \(snap.battery)"
                    )
                    .padding(.vertical, 6)
                }
                ResultRow(label: "State", value: snap.charge, tone: tone(snap.chargeTone))
                ResultRow(label: "Low Power Mode", value: snap.lowPower, tone: tone(snap.lowPowerTone))
                ResultRow(
                    label: "Battery Health",
                    value: DeviceHealthMath.batteryHealthUnavailableValue,
                    tone: Theme.muted
                )
                Text("\(DeviceHealthMath.batteryHealthUnavailableNote).")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
                Text(DeviceHealthMath.publicBatterySignalsNote)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                Text(snap.chargeNote)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                Text(snap.lowPowerNote)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
            }
            ResultCard(title: "Thermal") {
                ResultRow(label: "State", value: snap.thermal, emphasis: true, tone: tone(snap.thermalTone))
                Text(snap.thermalMeaning)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
            }
            ResultCard(title: "Storage") {
                if let used = snap.storageUsedFraction {
                    DeviceHealthStorageBar(usedFraction: used)
                        .padding(.bottom, 8)
                    HStack {
                        Text("Used \(snap.usedStorage)")
                        Spacer(minLength: 8)
                        Text("Available \(snap.freeImportant)")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .padding(.bottom, 4)
                    .accessibilityElement(children: .combine)
                }
                ResultRow(label: "Capacity (volume)", value: snap.volumeTotal, emphasis: true)
                ResultRow(label: "Available (user files)", value: snap.freeImportant)
                ResultRow(label: "Free (caches)", value: snap.freeOpportunistic)
                Text(DeviceHealthMath.storageCaption)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
            }
            ResultCard(title: "Phone") {
                ResultRow(label: "Model", value: snap.model, emphasis: true)
                ResultRow(label: "Identifier", value: snap.identifier)
                if !snap.identifierCaption.isEmpty {
                    Text(snap.identifierCaption)
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                        .padding(.bottom, 4)
                }
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

    private var batteryHero: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.md) {
            Text(snap.battery)
                .font(Theme.TypeRole.numericHero)
                .foregroundStyle(tone(snap.batteryTone))
                .accessibilityLabel("Charge \(snap.battery)")
            VStack(alignment: .leading, spacing: 2) {
                Text(snap.charge)
                    .font(Theme.TypeRole.lead)
                    .foregroundStyle(tone(snap.chargeTone))
                Text("Charge level — not pack health")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

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

private struct DeviceHealthFillBar: View {
    var fraction: Double
    var fill: Color
    var accessibilityLabel: String

    var body: some View {
        let clamped = min(1, max(0, fraction))
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.surfaceRaised)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(fill)
                    .frame(width: max(clamped > 0 ? 4 : 0, geo.size.width * CGFloat(clamped)))
            }
        }
        .frame(height: 10)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct DeviceHealthStorageBar: View {
    var usedFraction: Double

    var body: some View {
        let used = min(1, max(0, usedFraction))
        GeometryReader { geo in
            let gap: CGFloat = (used > 0 && used < 1) ? 2 : 0
            let usedWidth = max(used > 0 ? 4 : 0, (geo.size.width - gap) * CGFloat(used))
            HStack(spacing: gap) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.accent)
                    .frame(width: usedWidth)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.good.opacity(0.45))
            }
        }
        .frame(height: 12)
        .accessibilityElement()
        .accessibilityLabel("Storage used \(Int((used * 100).rounded())) percent")
    }
}
