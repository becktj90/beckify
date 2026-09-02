import Combine
import CoreLocation
import Network
import NetworkExtension
import SwiftUI

/// Public Network.framework path + optional SSID. Does not invent Wi-Fi RSSI.
@MainActor
final class WiFiPathModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var status = "Starting…"
    @Published var usesWiFi = false
    @Published var usesCellular = false
    @Published var usesWired = false
    @Published var isExpensive = false
    @Published var isConstrained = false
    @Published var interfaces: [String] = []
    @Published var ssid: String?
    @Published var bssid: String?
    @Published var ssidMessage = "SSID is not requested until you tap below."

    private var monitor: NWPathMonitor?
    private let location = CLLocationManager()
    private var waitingForSSID = false

    override init() {
        super.init()
        location.delegate = self
    }

    func start() {
        monitor?.cancel()
        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.apply(path)
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.beckify.toolbox.nwpath"))
    }

    func stop() {
        monitor?.cancel()
        monitor = nil
    }

    func requestSSID() {
        waitingForSSID = true
        ssidMessage = "Location is required by iOS to read the current SSID. Nothing is uploaded."
        switch location.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            fetchSSID()
        case .notDetermined:
            location.requestWhenInUseAuthorization()
        default:
            waitingForSSID = false
            ssid = nil
            ssidMessage = "Location permission is off, so iOS will not give this app the current SSID. Use Settings if you want the name. RSSI is never available."
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard waitingForSSID else { return }
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                fetchSSID()
            case .denied, .restricted:
                waitingForSSID = false
                ssidMessage = "Location permission was denied. SSID stays hidden. Path status above still works."
            default:
                break
            }
        }
    }

    private func apply(_ path: NWPath) {
        switch path.status {
        case .satisfied: status = "Satisfied"
        case .unsatisfied: status = "Unsatisfied"
        case .requiresConnection: status = "Requires connection"
        @unknown default: status = "Unknown"
        }
        usesWiFi = path.usesInterfaceType(.wifi)
        usesCellular = path.usesInterfaceType(.cellular)
        usesWired = path.usesInterfaceType(.wiredEthernet)
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        interfaces = path.availableInterfaces.map(\.name)
    }

    private func fetchSSID() {
        NEHotspotNetwork.fetchCurrent { [weak self] network in
            Task { @MainActor in
                guard let self else { return }
                self.waitingForSSID = false
                if let network {
                    self.ssid = network.ssid
                    self.bssid = network.bssid
                    self.ssidMessage = "Name from NEHotspotNetwork.fetchCurrent. This API does not provide RSSI. Access Wi-Fi Information on the Apple Developer team may be required for a non-empty name."
                } else {
                    self.ssid = nil
                    self.bssid = nil
                    self.ssidMessage = "No SSID returned. Common causes: not on Wi-Fi, missing Access Wi-Fi Information capability, or location not allowed. Public iOS APIs still do not expose Wi-Fi RSSI."
                }
            }
        }
    }
}

struct WiFiStatusView: View {
    @EnvironmentObject private var jobs: JobStore
    @StateObject private var model = WiFiPathModel()
    @State private var jobName = "Wi-Fi path"
    @State private var notes = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FormulaCard(
                    text: "NWPathMonitor + optional NEHotspotNetwork.fetchCurrent",
                    citation: "iOS does not give third-party apps Wi-Fi RSSI or a signal-bar number through public APIs. This tool will not invent one."
                )
                ResultCard(title: "Path") {
                    ResultRow(label: "Status", value: model.status, emphasis: true)
                    ResultRow(label: "Wi-Fi interface", value: model.usesWiFi ? "yes" : "no", tone: model.usesWiFi ? Theme.good : Theme.muted)
                    ResultRow(label: "Cellular", value: model.usesCellular ? "yes" : "no")
                    ResultRow(label: "Wired Ethernet", value: model.usesWired ? "yes" : "no")
                    ResultRow(label: "Expensive", value: model.isExpensive ? "yes" : "no")
                    ResultRow(label: "Constrained", value: model.isConstrained ? "yes" : "no")
                    ResultRow(label: "Interfaces", value: model.interfaces.isEmpty ? "—" : model.interfaces.joined(separator: ", "))
                }
                ResultCard(title: "Current network name") {
                    ResultRow(label: "SSID", value: model.ssid ?? "—", emphasis: true)
                    ResultRow(label: "BSSID", value: model.bssid ?? "—")
                    Text(model.ssidMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                    Button("Request SSID") { model.requestSSID() }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .padding(.top, 6)
                }
                SaveJobBar(jobName: $jobName, notes: $notes, canSave: true) { save() }
                SensorDisclaimer(extra: "Search synonym “rssi” opens this tool so the limitation is visible — it is not a hidden signal meter.")
            }
            .padding(20)
        }
        .navigationTitle("Wi-Fi Path")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private func save() {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .wifiStatus,
            notes: notes,
            inputs: ["API": "NWPathMonitor"],
            outputs: [
                "status": model.status,
                "wifi": model.usesWiFi ? "yes" : "no",
                "expensive": model.isExpensive ? "yes" : "no",
                "constrained": model.isConstrained ? "yes" : "no",
                "interfaces": model.interfaces.joined(separator: ","),
                "ssid": model.ssid ?? "(not returned)",
                "rssi": "not available via public API",
            ]
        ))
    }
}
