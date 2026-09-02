import Combine
import CoreBluetooth
import SwiftUI

struct BLESighting: Identifiable, Equatable {
    var id: UUID
    var name: String
    var rssi: Int
    var serviceIDs: [String]
    var lastSeen: Date
}

@MainActor
final class BLEScannerModel: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var stateText = "Bluetooth starting…"
    @Published var scanning = false
    @Published var sightings: [BLESighting] = []
    @Published var unauthorized = false

    private var central: CBCentralManager?
    private var seen: [UUID: BLESighting] = [:]
    private var publishTask: Task<Void, Never>?
    private let retention: TimeInterval = 30
    private let publishNanos: UInt64 = 250_000_000

    func start() {
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        } else {
            applyState(central?.state ?? .unknown)
        }
    }

    func stop() {
        scanning = false
        central?.stopScan()
        stopPublishLoop()
    }

    func clear() {
        seen.removeAll()
        sightings = []
    }

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            applyState(central.state)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? peripheral.name
            ?? "Unnamed"
        let services = ((advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? [])
            .map(\.uuidString)
        let id = peripheral.identifier
        let rssi = RSSI.intValue
        Task { @MainActor in
            seen[id] = BLESighting(
                id: id,
                name: name,
                rssi: rssi,
                serviceIDs: services,
                lastSeen: Date()
            )
        }
    }

    private func applyState(_ state: CBManagerState) {
        unauthorized = false
        switch state {
        case .poweredOn:
            stateText = "Scanning for BLE peripherals"
            scanning = true
            startPublishLoop()
            central?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        case .poweredOff:
            scanning = false
            stopPublishLoop()
            stateText = "Bluetooth is off"
        case .unauthorized:
            unauthorized = true
            scanning = false
            stopPublishLoop()
            stateText = "Bluetooth permission denied"
        case .unsupported:
            scanning = false
            stopPublishLoop()
            stateText = "This device does not support Bluetooth Low Energy"
        case .resetting:
            scanning = false
            stopPublishLoop()
            stateText = "Bluetooth resetting…"
        default:
            scanning = false
            stopPublishLoop()
            stateText = "Waiting for Bluetooth…"
        }
    }

    private func startPublishLoop() {
        guard publishTask == nil else { return }
        publishTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: self?.publishNanos ?? 250_000_000)
                guard !Task.isCancelled else { break }
                await self?.flushSightings()
            }
        }
    }

    private func stopPublishLoop() {
        publishTask?.cancel()
        publishTask = nil
    }

    private func flushSightings() {
        let cutoff = Date().addingTimeInterval(-retention)
        seen = seen.filter { $0.value.lastSeen >= cutoff }
        sightings = seen.values.sorted { $0.rssi > $1.rssi }
    }
}

struct BluetoothScannerView: View {
    @EnvironmentObject private var jobs: JobStore
    @StateObject private var model = BLEScannerModel()
    @State private var jobName = "BLE scan"
    @State private var notes = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FormulaCard(
                    text: "CoreBluetooth central scan",
                    citation: "Public BLE only. No classic-Bluetooth sniffing. RSSI here is the BLE advertisement RSSI, not Wi-Fi."
                )
                ResultCard(title: "Radio") {
                    ResultRow(label: "State", value: model.stateText, emphasis: true)
                    ResultRow(label: "Devices", value: "\(model.sightings.count)")
                }
                if model.unauthorized {
                    SettingsLinkButton()
                }
                ResultCard(title: "Peripherals") {
                    if model.sightings.isEmpty {
                        Text(model.scanning ? "Listening for advertisements…" : "No scan running.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    } else {
                        ForEach(model.sightings.prefix(40)) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                ResultRow(label: item.name, value: "\(item.rssi) dBm", emphasis: true)
                                Text(item.id.uuidString)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(Theme.muted)
                                if !item.serviceIDs.isEmpty {
                                    Text(item.serviceIDs.joined(separator: ", "))
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                Button("Clear list") { model.clear() }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                SaveJobBar(jobName: $jobName, notes: $notes, canSave: true) { save() }
                SensorDisclaimer()
            }
            .padding(20)
        }
        .navigationTitle("BLE Scanner")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private func save() {
        let top = model.sightings.prefix(8)
        var outputs: [String: String] = ["count": "\(model.sightings.count)"]
        for (i, item) in top.enumerated() {
            outputs["\(i + 1)"] = "\(item.name)  \(item.rssi) dBm  \(item.id.uuidString)"
        }
        jobs.save(SavedJob(
            name: jobName,
            toolID: .bluetoothScan,
            notes: notes,
            inputs: ["mode": "BLE central scan"],
            outputs: outputs
        ))
    }
}
