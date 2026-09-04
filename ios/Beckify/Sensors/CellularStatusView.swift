import Combine
import CoreTelephony
import Network
import SwiftUI
import BeckifyMath

enum CellularRTTTarget: String, CaseIterable, Identifiable {
    case cloudflare = "1.1.1.1"
    case beckify = "beckify.com"
    case custom = "Custom"
    var id: String { rawValue }
}

struct CellularServiceSnapshot: Identifiable, Equatable {
    var id: String
    var isDataService: Bool
    var ratRaw: String?
    var rat: CellularRATIdentity
    var carrierName: String?
    var mcc: String?
    var mnc: String?
    var iso: String?
    var allowsVOIP: Bool?
}

struct CellularRTTHistoryRow: Identifiable, Equatable {
    var id: UUID
    var at: Date
    var host: String
    var port: Int
    var ms: Double?
}

/// Isolates deprecated subscriber-provider APIs (iOS 16+, no public replacement).
/// Access stays dynamic so deprecated `CTCarrier` symbols do not leak into typed call sites.
private enum CTCarrierLegacy {
    static func providers(from info: CTTelephonyNetworkInfo) -> [String: AnyObject] {
        (info.value(forKey: "serviceSubscriberCellularProviders") as? [String: AnyObject]) ?? [:]
    }

    static func setProvidersUpdateHandler(
        on info: CTTelephonyNetworkInfo,
        _ handler: ((String) -> Void)?
    ) {
        info.setValue(handler, forKey: "serviceSubscriberCellularProvidersDidUpdateNotifier")
    }

    static func snapshot(_ carrier: AnyObject?) -> (
        name: String?, mcc: String?, mnc: String?, iso: String?, voip: Bool?
    ) {
        guard let carrier else { return (nil, nil, nil, nil, nil) }
        return (
            CellularRadioIdentity.cleaned(stringValue("carrierName", from: carrier)),
            CellularRadioIdentity.cleaned(stringValue("mobileCountryCode", from: carrier)),
            CellularRadioIdentity.cleaned(stringValue("mobileNetworkCode", from: carrier)),
            CellularRadioIdentity.displayISO(stringValue("isoCountryCode", from: carrier)),
            boolValue("allowsVOIP", from: carrier)
        )
    }

    private static func stringValue(_ key: String, from object: AnyObject) -> String? {
        (object.value(forKey: key) as? String)
    }

    private static func boolValue(_ key: String, from object: AnyObject) -> Bool? {
        if let value = object.value(forKey: key) as? Bool {
            return value
        }
        return (object.value(forKey: key) as? NSNumber)?.boolValue
    }
}

/// Data-service identity changes go through `CTTelephonyNetworkInfoDelegate`,
/// not a `Notification.Name`. File-level `NSObject` so CoreTelephony can call
/// off the main actor; hops back to `CellularPathModel` via `Task`.
private final class CellularTelephonyDelegate: NSObject, CTTelephonyNetworkInfoDelegate {
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        super.init()
    }

    func dataServiceIdentifierDidChange(_ identifier: String) {
        onChange()
    }
}

@MainActor
final class CellularPathModel: ObservableObject {
    @Published var defaultStatus = "Starting…"
    @Published var defaultUsesCellular = false
    @Published var defaultUsesWiFi = false
    @Published var defaultUsesWired = false
    @Published var defaultIsExpensive = false
    @Published var defaultIsConstrained = false
    @Published var defaultSupportsIPv4 = false
    @Published var defaultSupportsIPv6 = false
    @Published var defaultSupportsDNS = false
    @Published var defaultUnsatisfiedReason = "—"
    @Published var defaultInterfaces: [String] = []
    @Published var defaultGateways: [String] = []

    @Published var cellularStatus = "Starting…"
    @Published var cellularAvailable = false
    @Published var cellularIsExpensive = false
    @Published var cellularIsConstrained = false
    @Published var cellularUnsatisfiedReason = "—"
    @Published var cellularInterfaces: [String] = []

    @Published var restriction = "—"
    @Published var dataServiceIdentifier: String?
    @Published var services: [CellularServiceSnapshot] = []
    @Published var radioMessage = "CoreTelephony reports carrier and radio-access technology. It does not report RSRP, RSRQ, SINR, RSSI, or dBm."

    @Published var rttMeasuring = false
    @Published var rttProgress = 0
    @Published var rttGoal = 8
    @Published var rttSummary: WiFiRTTSummary?
    @Published var rttHost = ""
    @Published var rttPort = 443
    @Published var rttLocalEndpoint: String?
    @Published var rttRemoteEndpoint: String?
    @Published var rttMessage = "TCP connect time while the default path uses cellular — latency, not RSRP and not dBm. App Store apps cannot send ICMP ping."
    @Published var rttHistory: [CellularRTTHistoryRow] = []

    private var defaultMonitor: NWPathMonitor?
    private var cellularMonitor: NWPathMonitor?
    private var pathGeneration = 0
    private var rttTask: Task<Void, Never>?
    private var rttGeneration = 0
    private var rttSamples: [Double?] = []
    private let telephony = CTTelephonyNetworkInfo()
    private let cellularData = CTCellularData()
    private var telephonyDelegate: CellularTelephonyDelegate?
    private var observers: [NSObjectProtocol] = []
    private let historyCap = 12

    func start() {
        // Tear down prior observers first. SwiftUI can call onAppear again
        // without onDisappear (split view, tab reuse), and stopMonitors()
        // alone would leave NotificationCenter tokens stacked.
        removeRadioObservers()
        stopMonitors()
        pathGeneration += 1
        let generation = pathGeneration

        let defaultMonitor = NWPathMonitor()
        self.defaultMonitor = defaultMonitor
        defaultMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self, self.pathGeneration == generation else { return }
                self.applyDefault(path)
            }
        }
        defaultMonitor.start(queue: DispatchQueue(label: "com.beckify.toolbox.cellular.default"))

        let cellularMonitor = NWPathMonitor(requiredInterfaceType: .cellular)
        self.cellularMonitor = cellularMonitor
        cellularMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self, self.pathGeneration == generation else { return }
                self.applyCellular(path)
            }
        }
        cellularMonitor.start(queue: DispatchQueue(label: "com.beckify.toolbox.cellular.radio"))

        cellularData.cellularDataRestrictionDidUpdateNotifier = { [weak self] state in
            Task { @MainActor in
                self?.restriction = Self.restrictionLabel(state)
            }
        }
        restriction = Self.restrictionLabel(cellularData.restrictedState)

        CTCarrierLegacy.setProvidersUpdateHandler(on: telephony) { [weak self] _ in
            Task { @MainActor in
                self?.refreshRadio()
            }
        }
        let delegate = CellularTelephonyDelegate { [weak self] in
            Task { @MainActor in
                self?.refreshRadio()
            }
        }
        telephonyDelegate = delegate
        telephony.delegate = delegate
        refreshRadio()

        let center = NotificationCenter.default
        for name in Self.radioChangeNotifications {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refreshRadio() }
            })
        }
    }

    func stop() {
        stopMonitors()
        cancelRTT()
        removeRadioObservers()
    }

    /// RAT changes still post this public name. Data-service identity uses
    /// `CTTelephonyNetworkInfoDelegate` — the typed notification member is missing
    /// on some Cloud SDKs and is not how Apple delivers that event.
    private static let radioChangeNotifications: [Notification.Name] = [
        .CTServiceRadioAccessTechnologyDidChange,
    ]

    private func removeRadioObservers() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        telephony.delegate = nil
        telephonyDelegate = nil
        CTCarrierLegacy.setProvidersUpdateHandler(on: telephony, nil)
        cellularData.cellularDataRestrictionDidUpdateNotifier = nil
    }

    func cancelRTT() {
        rttGeneration += 1
        rttTask?.cancel()
        rttTask = nil
        rttMeasuring = false
    }

    func clearHistory() {
        resetDisplayedRTT(
            clearHistory: true,
            message: "Samples cleared. TCP RTT is not RSRP."
        )
    }

    /// Drop a completed (or in-flight) result when the operator changes host.
    /// Keeps history; the numbers on screen must match the current target.
    func invalidateDisplayedRTT(message: String) {
        resetDisplayedRTT(clearHistory: false, message: message)
    }

    /// Shared RTT field reset. History is optional so Clear and target-change stay in lockstep.
    private func resetDisplayedRTT(clearHistory: Bool, message: String) {
        cancelRTT()
        if clearHistory {
            rttHistory = []
        }
        rttSummary = nil
        rttSamples = []
        rttProgress = 0
        rttLocalEndpoint = nil
        rttRemoteEndpoint = nil
        rttHost = ""
        rttMessage = message
    }

    func resolvedRTTEndpoint(target: CellularRTTTarget, custom: String) -> (host: String, port: Int)? {
        switch target {
        case .cloudflare:
            return ("1.1.1.1", 443)
        case .beckify:
            return ("beckify.com", 443)
        case .custom:
            let fallback = WiFiLinkQuality.defaultPort(
                forHost: custom.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            guard let parsed = WiFiLinkQuality.parseHostPort(custom, defaultPort: fallback) else { return nil }
            return (parsed.host, parsed.port)
        }
    }

    func startRTT(target: CellularRTTTarget, custom: String) {
        cancelRTT()
        rttSummary = nil
        rttSamples = []
        rttProgress = 0
        rttLocalEndpoint = nil
        rttRemoteEndpoint = nil
        guard defaultStatus == "Satisfied" else {
            rttHost = ""
            rttMessage = "No satisfied network path. Link quality (RTT) cannot be measured while offline."
            return
        }
        guard defaultUsesCellular else {
            rttHost = ""
            rttMessage = "Default path is not cellular. RTT here is only meaningful on a cellular path — not a substitute for RSRP."
            return
        }
        guard let endpoint = resolvedRTTEndpoint(target: target, custom: custom) else {
            rttHost = ""
            rttMessage = target == .custom
                ? "Enter a host such as 1.1.1.1, beckify.com, or a carrier test host:443."
                : "Could not resolve that host."
            return
        }
        let needsLocal = WiFiLinkQuality.needsLocalNetworkPrompt(host: endpoint.host)
        rttHost = endpoint.host
        rttPort = endpoint.port
        rttMeasuring = true
        rttGoal = 8
        let generation = rttGeneration
        rttMessage = needsLocal
            ? "Measuring TCP RTT to \(endpoint.host):\(endpoint.port) bound to the cellular interface. A LAN target may prompt for Local Network. Not RSRP."
            : "Measuring TCP RTT to \(endpoint.host):\(endpoint.port) bound to the cellular interface. This is latency, not signal strength."
        let host = endpoint.host
        let port = endpoint.port
        rttTask = Task { [weak self] in
            var samples: [Double?] = []
            for i in 0..<8 {
                guard !Task.isCancelled else { return }
                let probe = await WiFiRTTClient.probeDetail(
                    host: host,
                    port: UInt16(clamping: port),
                    timeout: 3,
                    requiredInterface: .cellular
                )
                samples.append(probe.rttMS)
                let summary = WiFiLinkQuality.summarize(samplesMS: samples)
                await MainActor.run {
                    guard let self, self.rttGeneration == generation else { return }
                    self.rttSamples = samples
                    self.rttProgress = samples.count
                    self.rttSummary = summary
                    if self.rttLocalEndpoint == nil { self.rttLocalEndpoint = probe.localEndpoint }
                    self.rttRemoteEndpoint = probe.remoteEndpoint
                    self.appendHistory(host: host, port: port, ms: probe.rttMS)
                }
                if i + 1 < 8 {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                }
            }
            await MainActor.run {
                guard let self, self.rttGeneration == generation else { return }
                self.rttMeasuring = false
                self.rttTask = nil
                self.finishRTTMessage(needsLocalNetwork: needsLocal)
            }
        }
    }

    private func appendHistory(host: String, port: Int, ms: Double?) {
        rttHistory.insert(
            CellularRTTHistoryRow(id: UUID(), at: Date(), host: host, port: port, ms: ms),
            at: 0
        )
        if rttHistory.count > historyCap {
            rttHistory = Array(rttHistory.prefix(historyCap))
        }
    }

    private func finishRTTMessage(needsLocalNetwork: Bool) {
        guard let summary = rttSummary else {
            rttMessage = "Link quality (RTT) is unavailable."
            return
        }
        if summary.successCount == 0 {
            if needsLocalNetwork {
                rttMessage = "No TCP response from \(rttHost):\(rttPort). Local Network may be off, or nothing is listening. App Store apps cannot ICMP ping. This is not RSRP or dBm."
            } else {
                rttMessage = "No TCP response from \(rttHost):\(rttPort) on the cellular interface. The host may be unreachable, or cellular is down. This is not RSRP or dBm."
            }
            return
        }
        rttMessage = "TCP connect time to \(rttHost):\(rttPort) bound to cellular — link quality (RTT), not RSRP and not dBm. Refused connections still count when the host answers with a RST."
    }

    private func stopMonitors() {
        pathGeneration += 1
        defaultMonitor?.cancel()
        defaultMonitor = nil
        cellularMonitor?.cancel()
        cellularMonitor = nil
    }

    private func applyDefault(_ path: Network.NWPath) {
        defaultStatus = Self.statusLabel(path.status)
        defaultUsesCellular = path.usesInterfaceType(.cellular)
        defaultUsesWiFi = path.usesInterfaceType(.wifi)
        defaultUsesWired = path.usesInterfaceType(.wiredEthernet)
        defaultIsExpensive = path.isExpensive
        defaultIsConstrained = path.isConstrained
        defaultSupportsIPv4 = path.supportsIPv4
        defaultSupportsIPv6 = path.supportsIPv6
        defaultSupportsDNS = path.supportsDNS
        defaultUnsatisfiedReason = Self.unsatisfiedLabel(path)
        defaultInterfaces = Self.interfaceLines(path.availableInterfaces)
        defaultGateways = Self.gatewayHosts(from: path)
        if !defaultUsesCellular, rttMeasuring {
            cancelRTT()
            rttMessage = "Default path left cellular. RTT stopped — the probe is only meaningful on a cellular path."
        }
    }

    private func applyCellular(_ path: Network.NWPath) {
        cellularStatus = Self.statusLabel(path.status)
        cellularAvailable = path.status == .satisfied && path.usesInterfaceType(.cellular)
        cellularIsExpensive = path.isExpensive
        cellularIsConstrained = path.isConstrained
        cellularUnsatisfiedReason = Self.unsatisfiedLabel(path)
        cellularInterfaces = Self.interfaceLines(path.availableInterfaces)
    }

    func refreshRadio() {
        dataServiceIdentifier = CellularRadioIdentity.cleaned(telephony.dataServiceIdentifier)
        let rats = telephony.serviceCurrentRadioAccessTechnology ?? [:]
        let carriers = CTCarrierLegacy.providers(from: telephony)
        let ids = CellularRadioIdentity.serviceIDs(
            ratKeys: Array(rats.keys),
            carrierKeys: Array(carriers.keys)
        )
        services = ids.map { id in
            let fields = CTCarrierLegacy.snapshot(carriers[id])
            let ratRaw = CellularRadioIdentity.cleaned(rats[id])
            return CellularServiceSnapshot(
                id: id,
                isDataService: dataServiceIdentifier == id,
                ratRaw: ratRaw,
                rat: CellularRadioIdentity.identify(ratRaw),
                carrierName: fields.name,
                mcc: fields.mcc,
                mnc: fields.mnc,
                iso: fields.iso,
                allowsVOIP: fields.voip
            )
        }
        if services.isEmpty {
            radioMessage = "No cellular service keys from CoreTelephony. Common on Simulator, airplane mode, or when Apple withholds subscriber fields. Still no RSRP/dBm — the tool will not invent one."
        } else {
            radioMessage = "Radio access and subscriber fields from CTTelephonyNetworkInfo. CTCarrier is deprecated as of iOS 16 with no public replacement — empty MCC/MNC/name means Apple withheld them. None of these are RSRP, RSRQ, SINR, or dBm."
        }
    }

    /// Only the service CoreTelephony names as `dataServiceIdentifier`.
    /// Do not fall back to an arbitrary dictionary-first SIM on dual-SIM.
    var dataService: CellularServiceSnapshot? {
        services.first(where: \.isDataService)
    }

    private static func statusLabel(_ status: Network.NWPath.Status) -> String {
        switch status {
        case .satisfied: return "Satisfied"
        case .unsatisfied: return "Unsatisfied"
        case .requiresConnection: return "Requires connection"
        @unknown default: return "Unknown"
        }
    }

    private static func unsatisfiedLabel(_ path: Network.NWPath) -> String {
        guard path.status != .satisfied else { return "—" }
        switch path.unsatisfiedReason {
        case .notAvailable: return "Not available"
        case .cellularDenied: return "Cellular denied"
        case .wifiDenied: return "Wi-Fi denied"
        case .localNetworkDenied: return "Local network denied"
        case .vpnInactive: return "VPN inactive"
        @unknown default: return "Unknown"
        }
    }

    private static func restrictionLabel(_ state: CTCellularDataRestrictedState) -> String {
        switch state {
        case .restricted: return "Restricted"
        case .notRestricted: return "Not restricted"
        case .restrictedStateUnknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }

    private static func interfaceLines(_ interfaces: [NWInterface]) -> [String] {
        interfaces.map { iface in
            "\(iface.name) (\(interfaceTypeLabel(iface.type)))"
        }
    }

    private static func interfaceTypeLabel(_ type: NWInterface.InterfaceType) -> String {
        switch type {
        case .cellular: return "cellular"
        case .wifi: return "wifi"
        case .wiredEthernet: return "ethernet"
        case .loopback: return "loopback"
        case .other: return "other"
        @unknown default: return "unknown"
        }
    }

    private static func gatewayHosts(from path: Network.NWPath) -> [String] {
        var seen = Set<String>()
        var hosts: [String] = []
        for endpoint in path.gateways {
            guard let host = hostOnly(endpoint) else { continue }
            if seen.insert(host).inserted {
                hosts.append(host)
            }
        }
        return hosts
    }

    private static func hostOnly(_ endpoint: Network.NWEndpoint) -> String? {
        switch endpoint {
        case .hostPort(let host, _):
            switch host {
            case .name(let name, _):
                return name.isEmpty ? nil : name
            case .ipv4, .ipv6:
                return "\(host)"
            @unknown default:
                let raw = "\(host)"
                return raw.isEmpty ? nil : raw
            }
        default:
            return nil
        }
    }
}

struct CellularStatusView: View {
    @EnvironmentObject private var jobs: JobStore
    @StateObject private var model = CellularPathModel()
    @StoredInput(.cellularStatus, "jobName", default: "Cellular path") private var jobName
    @StoredChoice(.cellularStatus, "rttTarget", default: CellularRTTTarget.cloudflare) private var rttTarget
    @StoredInput(.cellularStatus, "rttHost", default: "1.1.1.1") private var customRTTHost
    @State private var notes = ""
    @State private var referenceOpen = false

    var body: some View {
        ToolScaffold(
            toolID: .cellularStatus,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .sensor(extra: "On-device CoreTelephony + Network path status. RTT is a user-started TCP probe. iOS does not give third-party apps cellular RSRP, RSRQ, SINR, RSSI, or dBm.")
        ) {
            ShowWorkCard(
                toolID: .cellularStatus,
                symbolic: "RAT = serviceCurrentRadioAccessTechnology    path = NWPath.usesCellular    RTT = TCP connect time",
                substituted: substituted,
                meaning: "Gauges show radio generation (2G…5G from RAT) and measured TCP RTT. They are not RSRP, RSRQ, SINR, or dBm. Use Field Test Mode on the phone if you need those RF numbers."
            )
            RFHonestyBanner(
                title: "No cellular dBm on iOS",
                detail: "App Store apps cannot read RSRP, RSRQ, SINR, RSSI, or bar-count from public CoreTelephony or Network APIs. Private status-bar scraping is a reject risk. This instrument reports radio identity and a measured TCP RTT proxy only."
            )
            CellularNetworkGauges(
                rat: model.dataService?.rat,
                hasServices: !model.services.isEmpty,
                onCellular: model.defaultUsesCellular,
                rttMedianMS: model.rttSummary?.medianMS,
                rttBand: model.rttSummary?.band,
                rttMeasuring: model.rttMeasuring
            )
            cellNetworkBoard
            ResultCard(title: "Default path") {
                ResultRow(label: "Status", value: model.defaultStatus, emphasis: true)
                ResultRow(
                    label: "Uses cellular",
                    value: model.defaultUsesCellular ? "yes" : "no",
                    tone: model.defaultUsesCellular ? Theme.good : Theme.muted
                )
                ResultRow(label: "Wi-Fi / wired", value: "\(model.defaultUsesWiFi ? "yes" : "no") / \(model.defaultUsesWired ? "yes" : "no")")
                ResultRow(label: "Expensive / constrained", value: "\(model.defaultIsExpensive ? "yes" : "no") / \(model.defaultIsConstrained ? "yes" : "no")")
                ResultRow(label: "IPv4 / IPv6 / DNS", value: "\(flag(model.defaultSupportsIPv4)) / \(flag(model.defaultSupportsIPv6)) / \(flag(model.defaultSupportsDNS))")
                ResultRow(label: "Unsatisfied reason", value: model.defaultUnsatisfiedReason)
                ResultRow(label: "Interfaces", value: model.defaultInterfaces.isEmpty ? "—" : model.defaultInterfaces.joined(separator: ", "))
                ResultRow(label: "Gateways", value: model.defaultGateways.isEmpty ? "not published" : model.defaultGateways.joined(separator: ", "))
            }
            ResultCard(title: "Cellular path") {
                ResultRow(
                    label: "Cellular monitor",
                    value: model.cellularStatus,
                    emphasis: true,
                    tone: model.cellularAvailable ? Theme.good : Theme.muted
                )
                ResultRow(label: "Cellular available", value: model.cellularAvailable ? "yes" : "no")
                ResultRow(label: "Expensive / constrained", value: "\(model.cellularIsExpensive ? "yes" : "no") / \(model.cellularIsConstrained ? "yes" : "no")")
                ResultRow(label: "Unsatisfied reason", value: model.cellularUnsatisfiedReason)
                ResultRow(label: "Interfaces", value: model.cellularInterfaces.isEmpty ? "—" : model.cellularInterfaces.joined(separator: ", "))
                ResultRow(label: "App cellular data", value: model.restriction)
                Text("The cellular monitor requires a cellular interface even when Wi-Fi is the default route. App cellular data uses CTCellularData.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
            }
            ResultCard(title: "Radio / SIM", copyText: copyText) {
                ResultRow(label: "Services", value: CellularRadioIdentity.serviceCountLabel(model.services.count), emphasis: true)
                ResultRow(label: "Data service", value: dataServiceLabel)
                if model.services.isEmpty {
                    ToolEmptyState(
                        title: "No cellular service reported",
                        detail: "CoreTelephony returned no serviceCurrentRadioAccessTechnology or subscriber keys. Simulator, airplane mode, or withheld CTCarrier fields look like this. Strength stays unavailable — the tool will not invent RSRP or dBm.",
                        systemImage: "antenna.radiowaves.left.and.right.slash"
                    )
                } else {
                    ForEach(model.services) { service in
                        serviceBlock(service)
                    }
                }
                Text(model.radioMessage)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 6)
            }
            linkQualitySection
            referenceSection
            SaveJobBar(jobName: $jobName, notes: $notes, canSave: true) { save() }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .onChange(of: rttTarget) { _, _ in
            model.invalidateDisplayedRTT(message: "Target changed. Prior RTT was for a different host — Start again. Not RSRP.")
        }
        .onChange(of: customRTTHost) { _, _ in
            guard rttTarget == .custom else { return }
            model.invalidateDisplayedRTT(message: "Custom host changed. Prior RTT was for a different host — Start again. Not RSRP.")
        }
    }

    @ViewBuilder
    private var cellNetworkBoard: some View {
        let service = model.dataService
        let rat = service?.rat
        ResultCard(title: "Cell network") {
            Text(service == nil && !model.services.isEmpty
                 ? "Data service not identified — chips stay blank rather than assuming a SIM."
                 : "Type and subscriber fields from CoreTelephony. Color follows generation, not signal strength.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                CellularParamChip(label: "Type", value: rat?.technologyDetail ?? "—", tone: ratTone(rat))
                CellularParamChip(label: "Generation", value: rat?.generationLabel ?? "—", tone: ratTone(rat))
                CellularParamChip(label: "RAT", value: rat?.label ?? "—", tone: ratTone(rat))
                CellularParamChip(label: "RAT constant", value: CellularRadioIdentity.displayField(service?.ratRaw))
                CellularParamChip(label: "Carrier", value: CellularRadioIdentity.displayField(service?.carrierName))
                CellularParamChip(label: "PLMN", value: CellularRadioIdentity.plmn(mcc: service?.mcc, mnc: service?.mnc) ?? "—")
                CellularParamChip(label: "MCC", value: CellularRadioIdentity.displayField(service?.mcc))
                CellularParamChip(label: "MNC", value: CellularRadioIdentity.displayField(service?.mnc))
                CellularParamChip(label: "ISO country", value: CellularRadioIdentity.displayField(service?.iso))
                CellularParamChip(
                    label: "VoIP",
                    value: service?.allowsVOIP.map { $0 ? "yes" : "no" } ?? "—",
                    tone: service?.allowsVOIP == true ? Theme.good : Theme.muted
                )
                CellularParamChip(label: "Data service", value: dataServiceLabel, tone: service == nil ? Theme.muted : Theme.good)
                CellularParamChip(label: "SIM / services", value: CellularRadioIdentity.serviceCountLabel(model.services.count))
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func serviceBlock(_ service: CellularServiceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ResultRow(
                label: service.isDataService ? "Service (data)" : "Service",
                value: CellularRadioIdentity.shortServiceID(service.id),
                emphasis: service.isDataService
            )
            ResultRow(label: "Carrier", value: CellularRadioIdentity.displayField(service.carrierName))
            ResultRow(label: "MCC / MNC", value: CellularRadioIdentity.plmn(mcc: service.mcc, mnc: service.mnc) ?? "—")
            ResultRow(label: "ISO country", value: CellularRadioIdentity.displayField(service.iso))
            ResultRow(label: "Type", value: service.rat.technologyDetail, tone: ratTone(service.rat))
            ResultRow(label: "RAT", value: service.rat.compact, tone: ratTone(service.rat))
            ResultRow(label: "RAT constant", value: CellularRadioIdentity.displayField(service.ratRaw))
            ResultRow(label: "Allows VoIP", value: service.allowsVOIP.map { $0 ? "yes" : "no" } ?? "—")
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var linkQualitySection: some View {
        ResultCard(title: "Link quality (RTT)") {
            ResultRow(label: "Target", value: rttTargetLabel)
            ResultRow(
                label: "Progress",
                value: model.rttMeasuring || model.rttProgress > 0
                    ? "\(model.rttProgress) of \(model.rttGoal)"
                    : "—",
                tone: model.rttMeasuring ? Theme.accent : Theme.muted
            )
            ResultRow(
                label: "Median",
                value: rttMedianText ?? (model.rttMeasuring ? "measuring…" : "—"),
                emphasis: true,
                tone: rttTone
            )
            ResultRow(label: "Min / max", value: rttRangeText)
            ResultRow(label: "Loss", value: rttLossText)
            ResultRow(label: "Band", value: model.rttSummary?.band.rawValue ?? "—", tone: rttTone)
            ResultRow(label: "Local endpoint", value: model.rttLocalEndpoint ?? "—")
            ResultRow(label: "Remote endpoint", value: model.rttRemoteEndpoint ?? "—")
            Picker("RTT host", selection: $rttTarget) {
                ForEach(CellularRTTTarget.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(model.rttMeasuring)
            .padding(.top, 6)
            if rttTarget == .custom {
                TextInputField(
                    title: "Host",
                    text: $customRTTHost,
                    placeholder: "1.1.1.1, beckify.com, or carrier.example:443",
                    fieldID: "rttHost",
                    onSubmit: startOrStopRTT
                )
            }
            Text(model.rttMessage)
                .font(.caption)
                .foregroundStyle(Theme.muted)
            if model.defaultStatus != "Satisfied" {
                ToolEmptyState(
                    title: "RTT unavailable offline",
                    detail: "Link quality needs a satisfied network path. This is TCP latency, not RSRP and not a dBm reading.",
                    systemImage: "antenna.radiowaves.left.and.right.slash"
                )
            } else if !model.defaultUsesCellular {
                ToolEmptyState(
                    title: "Not on cellular",
                    detail: "The default path is Wi-Fi or wired. Cellular Path only times RTT while usesCellular is true so the number is a cellular-path proxy, not a Wi-Fi measurement.",
                    systemImage: "antenna.radiowaves.left.and.right.slash"
                )
            }
            ThumbButtonRow {
                Button(model.rttMeasuring ? "Stop" : "Start") {
                    startOrStopRTT()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .frame(minHeight: Theme.touchTarget)
                .disabled(!model.rttMeasuring && (model.defaultStatus != "Satisfied" || !model.defaultUsesCellular))
                .accessibilityLabel(model.rttMeasuring ? "Stop cellular RTT" : "Start cellular RTT")
                .accessibilityHint("Times TCP connects to the chosen host while on cellular. Not ICMP ping and not RSRP.")
                Button("Clear samples") { model.clearHistory() }
                    .buttonStyle(.bordered)
                    .frame(minHeight: Theme.touchTarget)
                    .disabled(model.rttMeasuring || model.rttHistory.isEmpty)
            }
            .padding(.top, 6)
            if !model.rttHistory.isEmpty {
                Text("RECENT SAMPLES")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 8)
                ForEach(model.rttHistory) { row in
                    ResultRow(
                        label: row.at.formatted(date: .omitted, time: .standard),
                        value: row.ms.map { "\(Format.number($0, digits: 0)) ms" } ?? "loss",
                        tone: row.ms == nil ? Theme.bad : Theme.foreground
                    )
                }
            }
        }
    }

    private var referenceSection: some View {
        DisclosureGroup(isExpanded: $referenceOpen) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Typical bands used in LTE/NR planning discussions. These are not live readings from this phone.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                ForEach(CellularRadioIdentity.typicalMetrics) { metric in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(metric.symbol)  ·  \(metric.unit)")
                            .font(.subheadline.weight(.semibold))
                        Text(metric.name)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                        Text(metric.meaning)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                        ResultRow(label: "Excellent", value: metric.excellent)
                        ResultRow(label: "Good", value: metric.good)
                        ResultRow(label: "Fair", value: metric.fair)
                        ResultRow(label: "Poor", value: metric.poor)
                    }
                }
                Text("RAT STRINGS")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
                ForEach(CellularRadioIdentity.catalog) { rat in
                    ResultRow(label: rat.generationLabel, value: rat.label)
                }
            }
            .padding(.top, 8)
        } label: {
            Text("Typical cellular metrics (reference, not measured)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .frame(minHeight: Theme.touchTarget, alignment: .leading)
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .accessibilityHint("Educational RSRP, RSRQ, SINR, and RSSI bands. Not read from this device.")
    }

    private var substituted: String? {
        var parts: [String] = []
        if let service = model.dataService {
            parts.append("RAT = \(service.rat.compact)")
            if let plmn = CellularRadioIdentity.plmn(mcc: service.mcc, mnc: service.mnc) {
                parts.append("PLMN = \(plmn)")
            }
        } else if model.services.isEmpty {
            parts.append("No CoreTelephony service keys yet.")
        } else {
            parts.append("Data service not identified — not assuming a SIM.")
        }
        if let rtt = rttMedianText {
            parts.append("RTT median = \(rtt) to \(model.rttHost):\(model.rttPort)")
        }
        return parts.joined(separator: "    ")
    }

    private var sticky: String? {
        var parts: [String] = []
        if let rat = model.dataService?.rat, rat.generation != .unknown || model.dataService?.ratRaw != nil {
            parts.append(rat.compact)
        }
        if model.defaultUsesCellular {
            parts.append("on cellular")
        } else if model.cellularAvailable {
            parts.append("cell available")
        }
        if let rtt = rttMedianText {
            parts.append("\(rtt) RTT")
        }
        if parts.isEmpty {
            return model.defaultUsesCellular ? "Cellular path, no RAT yet" : nil
        }
        return parts.joined(separator: "  ·  ")
    }

    private var copyText: String? {
        var parts: [String] = []
        if let service = model.dataService {
            parts.append("\(service.carrierName ?? "Carrier —"), \(service.rat.compact) (data service)")
            if let plmn = CellularRadioIdentity.plmn(mcc: service.mcc, mnc: service.mnc) {
                parts.append("PLMN \(plmn)")
            }
        } else if !model.services.isEmpty {
            parts.append("Data service not identified")
        }
        parts.append("usesCellular \(model.defaultUsesCellular ? "yes" : "no")")
        if let rtt = rttMedianText {
            parts.append("Link quality (RTT) \(rtt) median to \(model.rttHost):\(model.rttPort)")
        }
        parts.append("No public RSRP/dBm")
        return parts.joined(separator: ". ")
    }

    private var dataServiceLabel: String {
        guard let id = model.dataServiceIdentifier else { return "—" }
        return CellularRadioIdentity.shortServiceID(id)
    }

    private var rttTargetLabel: String {
        guard let endpoint = model.resolvedRTTEndpoint(target: rttTarget, custom: customRTTHost) else {
            return rttTarget.rawValue
        }
        return "\(endpoint.host):\(endpoint.port)"
    }

    private var rttMedianText: String? {
        guard let ms = model.rttSummary?.medianMS else { return nil }
        return "\(Format.number(ms, digits: 0)) ms"
    }

    private var rttRangeText: String {
        guard let summary = model.rttSummary, let minMS = summary.minMS, let maxMS = summary.maxMS else { return "—" }
        return "\(Format.number(minMS, digits: 0))–\(Format.number(maxMS, digits: 0)) ms"
    }

    private var rttLossText: String {
        guard let summary = model.rttSummary else { return "—" }
        return "\(Format.number(summary.lossPercent, digits: 0)) %  (\(summary.failureCount)/\(summary.attempts))"
    }

    private var rttTone: Color {
        switch model.rttSummary?.band {
        case .excellent, .good: return Theme.good
        case .fair: return Theme.warn
        case .slow, .poor: return Theme.bad
        default: return Theme.muted
        }
    }

    private func ratTone(_ rat: CellularRATIdentity?) -> Color {
        switch rat?.generation {
        case .fiveG, .fourG: return Theme.good
        case .threeG: return Theme.warn
        case .twoG: return Theme.bad
        default: return Theme.muted
        }
    }

    private func flag(_ value: Bool) -> String { value ? "yes" : "no" }

    private func startOrStopRTT() {
        if model.rttMeasuring {
            model.cancelRTT()
            model.rttMessage = "Stopped. \(model.rttProgress) of \(model.rttGoal) probes kept. TCP RTT is not RSRP."
        } else {
            model.startRTT(target: rttTarget, custom: customRTTHost)
        }
    }

    private func save() {
        var outputs: [String: String] = [
            "default status": model.defaultStatus,
            "uses cellular": model.defaultUsesCellular ? "yes" : "no",
            "cellular available": model.cellularAvailable ? "yes" : "no",
            "app cellular data": model.restriction,
            "services": CellularRadioIdentity.serviceCountLabel(model.services.count),
            "data service": model.dataServiceIdentifier ?? "—",
        ]
        if let service = model.dataService {
            outputs["carrier"] = service.carrierName ?? "—"
            outputs["mcc"] = service.mcc ?? "—"
            outputs["mnc"] = service.mnc ?? "—"
            outputs["iso"] = service.iso ?? "—"
            outputs["rat"] = service.rat.compact
            outputs["rat constant"] = service.ratRaw ?? "—"
            outputs["voip"] = service.allowsVOIP.map { $0 ? "yes" : "no" } ?? "—"
        }
        if let summary = model.rttSummary {
            outputs["rtt host"] = model.rttHost.isEmpty ? "—" : "\(model.rttHost):\(model.rttPort)"
            outputs["rtt median ms"] = summary.medianMS.map { Format.number($0, digits: 0) } ?? "—"
            outputs["rtt loss %"] = Format.number(summary.lossPercent, digits: 0)
            outputs["rtt band"] = summary.band.rawValue
        }
        jobs.save(SavedJob(
            name: jobName,
            toolID: .cellularStatus,
            notes: notes,
            inputs: [
                "API": "CTTelephonyNetworkInfo + NWPathMonitor + TCP RTT",
                "rttTarget": rttTarget.rawValue,
                "rttHost": customRTTHost,
            ],
            outputs: outputs
        ))
    }
}

struct CellularNetworkGauges: View {
    var rat: CellularRATIdentity?
    var hasServices: Bool
    var onCellular: Bool
    var rttMedianMS: Double?
    var rttBand: WiFiRTTBand?
    var rttMeasuring: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
                generationGauge
                rttGauge
            }
            VStack(spacing: 22) {
                generationGauge
                rttGauge
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var generationGauge: some View {
        let generation = rat?.generation ?? .unknown
        let fill = CellularRadioIdentity.generationFill(generation)
        let step = CellularRadioIdentity.generationStep(generation)
        return CellularArcGauge(
            fill: fill,
            colors: [Theme.bad, Theme.warn, Theme.accent, Theme.good],
            value: rat?.generationLabel ?? "—",
            unit: rat?.label ?? (hasServices ? "data SIM unknown" : "no RAT"),
            caption: onCellular ? "Generation  ·  not RSRP" : "Not on cellular  ·  not RSRP",
            accessibility: generationAccessibility
        ) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(CellularRadioIdentity.generationOrder.enumerated()), id: \.element) { index, gen in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(index + 1 <= step ? generationColor(gen) : Theme.border)
                            .frame(width: 22, height: CGFloat(18 + (index + 1) * 10))
                        Text(gen.rawValue)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(index + 1 == step ? generationColor(gen) : Theme.muted)
                    }
                    .accessibilityHidden(true)
                }
            }
        }
    }

    private var rttGauge: some View {
        let fill = CellularRadioIdentity.rttFill(medianMS: rttMedianMS)
        let value: String = {
            if let rttMedianMS { return Format.number(rttMedianMS, digits: 0) }
            return rttMeasuring ? "…" : "—"
        }()
        let unit = rttMedianMS == nil ? (rttMeasuring ? "measuring RTT" : "ms RTT") : "ms median"
        return CellularArcGauge(
            fill: fill,
            colors: [Theme.bad, Theme.warn, Theme.good],
            value: value,
            unit: unit,
            caption: rttBand.map { "\($0.rawValue)  ·  TCP, not dBm" } ?? "TCP RTT  ·  not dBm",
            accessibility: rttAccessibility
        ) {
            HStack(spacing: 6) {
                ForEach(CellularRadioIdentity.rttGaugeLegendLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)
            LinearGradient(colors: [Theme.good, Theme.warn, Theme.bad], startPoint: .leading, endPoint: .trailing)
                .frame(height: 8)
                .clipShape(Capsule())
            Text("Excellent → poor  ·  milliseconds")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
        }
    }

    private var generationAccessibility: String {
        if let rat {
            return "Cell generation \(rat.generationLabel), \(rat.technologyDetail). Gauge is radio type, not RSRP."
        }
        if hasServices {
            return "Data service not identified. Generation gauge empty."
        }
        return "No radio access technology reported."
    }

    private var rttAccessibility: String {
        if let rttMedianMS, let rttBand {
            return "Cellular TCP RTT \(Format.number(rttMedianMS, digits: 0)) milliseconds, \(rttBand.rawValue). Not dBm."
        }
        if rttMeasuring { return "Measuring cellular TCP RTT." }
        return "No cellular RTT yet."
    }

    private func generationColor(_ generation: CellularGeneration) -> Color {
        switch generation {
        case .fiveG, .fourG: return Theme.good
        case .threeG: return Theme.warn
        case .twoG: return Theme.bad
        case .unknown: return Theme.muted
        }
    }
}

struct CellularArcGauge<Footer: View>: View {
    var fill: Double
    var colors: [Color]
    var value: String
    var unit: String
    var caption: String
    var accessibility: String
    @ViewBuilder var footer: Footer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let clamped = min(1, max(0, fill))
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Theme.border, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: CGFloat(clamped) * 0.75)
                    .stroke(
                        AngularGradient(colors: colors, center: .center),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(225))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: clamped)
                VStack(spacing: 3) {
                    Text(value)
                        .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.foreground)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(unit)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 22)
            }
            .frame(width: 176, height: 176)
            .accessibilityElement()
            .accessibilityLabel(accessibility)
            footer
            Text(caption)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CellularParamChip: View {
    var label: String
    var value: String
    var tone: Color = Theme.foreground

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(tone)
                .minimumScaleFactor(0.7)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: Theme.touchTarget, alignment: .leading)
        .padding(12)
        .background(tone.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tone.opacity(0.28), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }
}
