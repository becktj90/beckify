import Combine
import CoreLocation
import Network
import NetworkExtension
import SwiftUI
import BeckifyMath

enum WiFiSurveyMode: String, CaseIterable, Identifiable {
    case gps = "GPS walk"
    case tap = "Tap floor"
    var id: String { rawValue }
}

enum WiFiRTTTarget: String, CaseIterable, Identifiable {
    case gateway = "Gateway"
    case cloudflare = "1.1.1.1"
    case beckify = "beckify.com"
    case custom = "Custom"
    var id: String { rawValue }
}

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
    @Published var signalStrength: Double?
    @Published var ssidMessage = "Location is needed to read the current SSID and Apple’s 0…1 signal scale."
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var accuracy: Double?
    @Published var surveying = false
    @Published var surveyMode: WiFiSurveyMode = .gps
    @Published var samples: [WiFiAmplitudeSample] = []
    @Published var denied = false
    @Published var gatewayHosts: [String] = []
    @Published var rttMeasuring = false
    @Published var rttSummary: WiFiRTTSummary?
    @Published var rttHost = ""
    @Published var rttPort = 443
    @Published var rttMessage = "TCP connect time to a host — latency, not RSSI and not dBm. App Store apps cannot send ICMP ping."

    var roomWidth: Double = 12
    var roomDepth: Double = 8

    private var monitor: NWPathMonitor?
    private var pathGeneration = 0
    private let location = CLLocationManager()
    private var waitingForAuth = false
    private var pollTask: Task<Void, Never>?
    private var rttTask: Task<Void, Never>?
    private var rttGeneration = 0
    private var originLat: Double?
    private var originLon: Double?
    private var lastSampleEast: Double?
    private var lastSampleNorth: Double?

    override init() {
        super.init()
        location.delegate = self
        location.desiredAccuracy = kCLLocationAccuracyBest
    }

    func start() {
        monitor?.cancel()
        pathGeneration += 1
        let generation = pathGeneration
        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self, self.pathGeneration == generation else { return }
                self.apply(path)
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.beckify.toolbox.nwpath"))
    }

    func stop() {
        pathGeneration += 1
        monitor?.cancel()
        monitor = nil
        stopSurvey()
        cancelRTT()
        location.stopUpdatingLocation()
    }

    func cancelRTT() {
        rttGeneration += 1
        rttTask?.cancel()
        rttTask = nil
        rttMeasuring = false
    }

    func resolvedRTTEndpoint(target: WiFiRTTTarget, custom: String) -> (host: String, port: Int, needsLocalNetwork: Bool)? {
        switch target {
        case .gateway:
            guard let host = gatewayHosts.first else { return nil }
            let port = WiFiLinkQuality.defaultPort(forHost: host)
            return (host, port, WiFiLinkQuality.needsLocalNetworkPrompt(host: host))
        case .cloudflare:
            return ("1.1.1.1", 443, false)
        case .beckify:
            return ("beckify.com", 443, false)
        case .custom:
            let fallback = WiFiLinkQuality.defaultPort(
                forHost: custom.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            guard let parsed = WiFiLinkQuality.parseHostPort(custom, defaultPort: fallback) else { return nil }
            return (parsed.host, parsed.port, WiFiLinkQuality.needsLocalNetworkPrompt(host: parsed.host))
        }
    }

    func measureLinkQuality(target: WiFiRTTTarget, custom: String) {
        cancelRTT()
        rttSummary = nil
        guard status == "Satisfied" else {
            rttHost = ""
            rttMessage = "No satisfied network path. Link quality (RTT) cannot be measured while offline."
            return
        }
        guard let endpoint = resolvedRTTEndpoint(target: target, custom: custom) else {
            rttHost = ""
            if target == .gateway {
                rttMessage = "No default gateway on this path. iOS does not always publish one. Enter a LAN IP or use 1.1.1.1 / beckify.com."
            } else if target == .custom {
                rttMessage = "Enter a host such as 1.1.1.1, beckify.com, or 192.168.1.1:80."
            } else {
                rttMessage = "Could not resolve that host."
            }
            return
        }
        rttHost = endpoint.host
        rttPort = endpoint.port
        rttMeasuring = true
        let generation = rttGeneration
        rttMessage = endpoint.needsLocalNetwork
            ? "Measuring TCP RTT to \(endpoint.host):\(endpoint.port). A LAN / gateway target may prompt for Local Network. ICMP ping is not available."
            : "Measuring TCP RTT to \(endpoint.host):\(endpoint.port). This is latency, not signal strength. ICMP ping is not available."
        let host = endpoint.host
        let port = endpoint.port
        rttTask = Task { [weak self] in
            var samples: [Double?] = []
            for i in 0..<5 {
                guard !Task.isCancelled else { return }
                let ms = await WiFiRTTClient.probe(host: host, port: UInt16(clamping: port), timeout: 3)
                samples.append(ms)
                let summary = WiFiLinkQuality.summarize(samplesMS: samples)
                await MainActor.run {
                    guard let self, self.rttGeneration == generation else { return }
                    self.rttSummary = summary
                }
                if i + 1 < 5 {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
            }
            await MainActor.run {
                guard let self, self.rttGeneration == generation else { return }
                self.rttMeasuring = false
                self.rttTask = nil
                self.finishRTTMessage(needsLocalNetwork: endpoint.needsLocalNetwork)
            }
        }
    }

    private func finishRTTMessage(needsLocalNetwork: Bool) {
        guard let summary = rttSummary else {
            rttMessage = "Link quality (RTT) is unavailable."
            return
        }
        if summary.successCount == 0 {
            if needsLocalNetwork {
                rttMessage = "No TCP response from \(rttHost):\(rttPort). Local Network may be off, or nothing is listening on that port. App Store apps cannot ICMP ping. This is not RSSI or dBm."
            } else {
                rttMessage = "No TCP response from \(rttHost):\(rttPort). The host may be unreachable, or the path is down. App Store apps cannot ICMP ping. This is not RSSI or dBm."
            }
            return
        }
        rttMessage = "TCP connect time to \(rttHost):\(rttPort) — link quality (RTT), not RSSI and not dBm. Refused connections still count when the host answers with a RST."
    }

    func requestNetworkInfo() {
        waitingForAuth = true
        ssidMessage = "Location is required by iOS to read SSID / BSSID / signalStrength. Nothing is uploaded."
        ensureLocationThen {
            self.fetchNetwork()
            self.startPolling()
        }
    }

    func startSurvey() {
        if surveyMode == .gps {
            switch location.authorizationStatus {
            case .denied, .restricted:
                denied = true
                ssidMessage = "Location permission is off. Turn it on to see SSID and Apple’s 0…1 signal scale."
                return
            default:
                break
            }
            surveying = true
            ensureLocationThen {
                self.location.startUpdatingLocation()
                self.fetchNetwork()
                self.startPolling()
            }
        } else {
            surveying = true
            requestNetworkInfo()
        }
    }

    func stopSurvey() {
        surveying = false
        pollTask?.cancel()
        pollTask = nil
        if surveyMode == .gps {
            location.stopUpdatingLocation()
        }
    }

    func clearSamples() {
        samples = []
        originLat = nil
        originLon = nil
        lastSampleEast = nil
        lastSampleNorth = nil
    }

    func dropGPSSample() {
        guard let lat = latitude, let lon = longitude, let strength = signalStrength else { return }
        if originLat == nil {
            originLat = lat
            originLon = lon
        }
        guard let oLat = originLat, let oLon = originLon else { return }
        let en = GeoMath.eastNorthMeters(originLat: oLat, originLon: oLon, lat: lat, lon: lon)
        appendSample(east: en.east, north: en.north, strength: strength)
    }

    func dropTapSample(east: Double, north: Double) {
        guard let strength = signalStrength else { return }
        appendSample(east: east, north: north, strength: strength)
    }

    private func appendSample(east: Double, north: Double, strength: Double) {
        let s = WiFiAmplitudeSample(east: east, north: north, strength: WiFiCoverageMath.clampStrength(strength))
        samples.append(s)
        lastSampleEast = east
        lastSampleNorth = north
    }

    private func ensureLocationThen(_ body: @escaping () -> Void) {
        denied = false
        switch location.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            waitingForAuth = false
            body()
        case .notDetermined:
            location.requestWhenInUseAuthorization()
        default:
            waitingForAuth = false
            denied = true
            surveying = false
            ssidMessage = "Location permission is off. Turn it on to see SSID and Apple’s 0…1 signal scale."
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard waitingForAuth || surveying else { return }
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                waitingForAuth = false
                denied = false
                if surveying, surveyMode == .gps {
                    location.startUpdatingLocation()
                }
                fetchNetwork()
                startPolling()
            case .denied, .restricted:
                waitingForAuth = false
                denied = true
                surveying = false
                location.stopUpdatingLocation()
                ssidMessage = "Location permission was denied. Path status still works. Strength and SSID stay hidden."
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, loc.horizontalAccuracy >= 0 else { return }
        Task { @MainActor in
            latitude = loc.coordinate.latitude
            longitude = loc.coordinate.longitude
            accuracy = loc.horizontalAccuracy
            if surveying, surveyMode == .gps, signalStrength != nil {
                maybeAutoSample()
            }
        }
    }

    private func maybeAutoSample() {
        guard let lat = latitude, let lon = longitude, let strength = signalStrength else { return }
        if originLat == nil {
            originLat = lat
            originLon = lon
        }
        guard let oLat = originLat, let oLon = originLon else { return }
        let en = GeoMath.eastNorthMeters(originLat: oLat, originLon: oLon, lat: lat, lon: lon)
        if let le = lastSampleEast, let ln = lastSampleNorth {
            let moved = hypot(en.east - le, en.north - ln)
            if moved < 1.5 { return }
        }
        appendSample(east: en.east, north: en.north, strength: strength)
    }

    private func apply(_ path: Network.NWPath) {
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
        gatewayHosts = Self.gatewayHosts(from: path)
    }

    private static func gatewayHosts(from path: Network.NWPath) -> [String] {
        var seen = Set<String>()
        var hosts: [String] = []
        for endpoint in path.gateways {
            guard let host = hostString(endpoint) else { continue }
            if seen.insert(host).inserted {
                hosts.append(host)
            }
        }
        return hosts
    }

    private static func hostString(_ endpoint: Network.NWEndpoint) -> String? {
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

    private func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { break }
                self?.fetchNetwork()
            }
        }
    }

    private func fetchNetwork() {
        NEHotspotNetwork.fetchCurrent { [weak self] network in
            Task { @MainActor in
                guard let self else { return }
                if let network {
                    self.ssid = network.ssid
                    self.bssid = network.bssid
                    let raw = network.signalStrength
                    let clamped = WiFiCoverageMath.clampStrength(raw)
                    self.signalStrength = clamped
                    if !raw.isFinite {
                        self.ssidMessage = "SSID from NEHotspotNetwork.fetchCurrent. signalStrength was non-finite, so strength is shown as 0 on Apple’s 0…1 scale."
                    } else if clamped <= 0 {
                        self.ssidMessage = "SSID from NEHotspotNetwork.fetchCurrent. signalStrength is \(Format.number(clamped, digits: 2)) on Apple’s 0…1 scale — often 0 even when Wi-Fi works."
                    } else {
                        self.ssidMessage = "Apple NEHotspotNetwork.signalStrength (0…1), shown as percent and bars. Not a calibrated RF power reading."
                    }
                } else {
                    self.ssid = nil
                    self.bssid = nil
                    self.signalStrength = nil
                    self.ssidMessage = "No current hotspot. Common causes: not on Wi-Fi, missing Access Wi-Fi Information, or location off. Strength stays unavailable — the tool will not invent a reading."
                }
            }
        }
    }
}

struct WiFiStatusView: View {
    @EnvironmentObject private var jobs: JobStore
    @StateObject private var model = WiFiPathModel()
    @StoredInput(.wifiStatus, "jobName", default: "Wi-Fi coverage") private var jobName
    @StoredChoice(.wifiStatus, "surveyMode", default: WiFiSurveyMode.gps) private var surveyMode
    @StoredChoice(.wifiStatus, "rttTarget", default: WiFiRTTTarget.cloudflare) private var rttTarget
    @StoredInput(.wifiStatus, "rttHost", default: "192.168.1.1") private var customRTTHost
    @State private var notes = ""

    var body: some View {
        ToolScaffold(
            toolID: .wifiStatus,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .sensor(extra: "Walk or tap to drop samples. GPS indoor accuracy is often several meters. Apple may return 0.0 for signalStrength even when Wi-Fi works. Link quality is TCP RTT, not ICMP ping.")
        ) {
            ShowWorkCard(
                toolID: .wifiStatus,
                symbolic: "A = NEHotspotNetwork.signalStrength ∈ [0, 1]    RTT = TCP connect time    heatmap = IDW(A, east, north)",
                substituted: substituted,
                meaning: "Primary public unit is Apple’s 0…1 strength, shown as percent and bars. Complementary metric is TCP round-trip time to a host (link quality). Neither is a calibrated RF power reading. This sketch is not a site survey."
            )
            WiFiStrengthGauge(strength: model.signalStrength, onWiFi: model.usesWiFi)
            ResultCard(title: "Path") {
                ResultRow(label: "Status", value: model.status, emphasis: true)
                ResultRow(label: "Wi-Fi interface", value: model.usesWiFi ? "yes" : "no", tone: model.usesWiFi ? Theme.good : Theme.muted)
                ResultRow(label: "Cellular", value: model.usesCellular ? "yes" : "no")
                ResultRow(label: "Expensive / constrained", value: "\(model.isExpensive ? "yes" : "no") / \(model.isConstrained ? "yes" : "no")")
                ResultRow(label: "Interfaces", value: model.interfaces.isEmpty ? "—" : model.interfaces.joined(separator: ", "))
            }
            ResultCard(title: "Associated network", copyText: copyText) {
                ResultRow(label: "SSID", value: model.ssid ?? "—", emphasis: true)
                ResultRow(label: "BSSID", value: model.bssid ?? "—")
                ResultRow(
                    label: "Strength",
                    value: strengthText,
                    emphasis: true,
                    tone: strengthTone
                )
                Text(model.ssidMessage)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                Button("Read SSID + strength") { model.requestNetworkInfo() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .frame(minHeight: Theme.touchTarget)
                    .padding(.top, 6)
                    .accessibilityLabel("Read SSID and Apple strength")
                    .accessibilityHint("Uses location in this tool only. Shows Apple’s 0 to 1 signalStrength as percent and bars.")
            }
            if model.denied {
                ToolEmptyState(
                    title: "Location is needed for SSID and strength",
                    detail: "iOS will not hand a third-party app the current SSID or Apple’s 0…1 signalStrength without When In Use location. Strength stays blank — the tool will not invent a reading.",
                    systemImage: "wifi.slash",
                    showsSettings: true
                )
            }
            linkQualitySection
            coverageSection
            SaveJobBar(jobName: $jobName, notes: $notes, canSave: true) { save() }
        }
        .onAppear {
            model.surveyMode = surveyMode
            model.start()
        }
        .onDisappear { model.stop() }
        .onChange(of: surveyMode) { _, new in
            model.surveyMode = new
        }
    }

    private var substituted: String? {
        var parts: [String] = []
        if let s = model.signalStrength {
            parts.append("A = \(Format.number(s, digits: 2))  →  \(Format.number(WiFiCoverageMath.percent(s), digits: 0)) %  ·  \(WiFiCoverageMath.bars(s))/4 bars")
        } else {
            parts.append("Read SSID + strength to plug Apple’s 0…1 value into the gauge.")
        }
        if let rtt = rttMedianText {
            parts.append("RTT median = \(rtt) to \(model.rttHost):\(model.rttPort)")
        }
        return parts.joined(separator: "    ")
    }

    private var sticky: String? {
        if model.signalStrength == nil, model.rttSummary?.medianMS == nil {
            return model.usesWiFi ? "Wi-Fi path, no strength yet" : nil
        }
        var parts: [String] = []
        if model.signalStrength != nil { parts.append(strengthText) }
        if let rtt = rttMedianText { parts.append("\(rtt) RTT") }
        return parts.isEmpty ? nil : parts.joined(separator: "  ·  ")
    }

    private var copyText: String? {
        var parts: [String] = []
        if model.signalStrength != nil {
            parts.append("\(model.ssid ?? "SSID —"), \(strengthText), Apple 0…1 strength")
        }
        if let rtt = rttMedianText {
            parts.append("Link quality (RTT) \(rtt) median to \(model.rttHost):\(model.rttPort)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: ". ")
    }

    private var strengthText: String {
        guard let s = model.signalStrength else { return "—" }
        return "\(Format.number(WiFiCoverageMath.percent(s), digits: 0)) %   (\(Format.number(s, digits: 2)) · \(WiFiCoverageMath.bars(s))/4)"
    }

    private var strengthTone: Color {
        guard let s = model.signalStrength else { return Theme.muted }
        if s >= 0.6 { return Theme.good }
        if s >= 0.3 { return Theme.warn }
        return Theme.bad
    }

    private var rttMedianText: String? {
        guard let ms = model.rttSummary?.medianMS else { return nil }
        return "\(Format.number(ms, digits: 0)) ms"
    }

    @ViewBuilder
    private var linkQualitySection: some View {
        ResultCard(title: "Link quality (RTT)") {
            ResultRow(label: "Target", value: rttTargetLabel)
            ResultRow(
                label: "Median",
                value: rttMedianText ?? (model.rttMeasuring ? "measuring…" : "—"),
                emphasis: true,
                tone: rttTone
            )
            ResultRow(label: "Min / max", value: rttRangeText)
            ResultRow(label: "Loss", value: rttLossText)
            ResultRow(label: "Band", value: model.rttSummary?.band.rawValue ?? "—", tone: rttTone)
            if let host = model.gatewayHosts.first {
                ResultRow(label: "Path gateway", value: host)
            } else {
                ResultRow(label: "Path gateway", value: "not published", tone: Theme.muted)
            }
            Picker("RTT host", selection: $rttTarget) {
                ForEach(WiFiRTTTarget.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(model.rttMeasuring)
            .padding(.top, 6)
            if rttTarget == .custom {
                TextInputField(
                    title: "Host",
                    text: $customRTTHost,
                    placeholder: "1.1.1.1, beckify.com, or 192.168.1.1:80",
                    fieldID: "rttHost",
                    onSubmit: { model.measureLinkQuality(target: rttTarget, custom: customRTTHost) }
                )
            }
            Text(model.rttMessage)
                .font(.caption)
                .foregroundStyle(Theme.muted)
            if model.status != "Satisfied" {
                ToolEmptyState(
                    title: "RTT unavailable offline",
                    detail: "Link quality needs a satisfied network path. This is TCP latency, not Apple strength and not a dBm reading.",
                    systemImage: "wifi.slash"
                )
            } else if rttTarget == .gateway, model.gatewayHosts.isEmpty {
                ToolEmptyState(
                    title: "No default gateway on this path",
                    detail: "iOS does not always publish a gateway. Enter a LAN IP (may prompt for Local Network) or measure 1.1.1.1 / beckify.com. ICMP ping is not available to App Store apps.",
                    systemImage: "point.3.connected.trianglepath.dotted"
                )
            }
            Button(model.rttMeasuring ? "Measuring…" : "Measure RTT") {
                model.measureLinkQuality(target: rttTarget, custom: customRTTHost)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .frame(minHeight: Theme.touchTarget)
            .padding(.top, 6)
            .disabled(model.rttMeasuring || model.status != "Satisfied")
            .accessibilityLabel("Measure link quality RTT")
            .accessibilityHint("Times a TCP connect to the chosen host. Not ICMP ping. A LAN host may ask for Local Network permission.")
        }
    }

    private var rttTargetLabel: String {
        guard let endpoint = model.resolvedRTTEndpoint(target: rttTarget, custom: customRTTHost) else {
            return rttTarget.rawValue
        }
        return "\(endpoint.host):\(endpoint.port)"
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

    @ViewBuilder
    private var coverageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COVERAGE SKETCH")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
            Picker("Survey", selection: $surveyMode) {
                ForEach(WiFiSurveyMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(model.surveying)
            Text(surveyMode == .gps
                 ? "Walk the space. Samples drop every ~1.5 m from GPS plus Apple’s 0…1 strength."
                 : "Tap the floor plan to drop a sample at that spot using the current Apple strength.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            WiFiHeatmapCanvas(
                samples: model.samples,
                mode: surveyMode,
                roomWidth: model.roomWidth,
                roomDepth: model.roomDepth,
                amplitudeReady: model.signalStrength != nil,
                onTap: { east, north in
                    guard surveyMode == .tap else { return }
                    if !model.surveying { model.startSurvey() }
                    model.dropTapSample(east: east, north: north)
                }
            )
            .frame(height: 280)
            WiFiHeatLegend()
            ThumbButtonRow {
                if model.surveying {
                    Button("Stop survey") { model.stopSurvey() }
                        .buttonStyle(.bordered)
                        .frame(minHeight: Theme.touchTarget)
                } else {
                    Button("Start survey") { model.startSurvey() }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .frame(minHeight: Theme.touchTarget)
                }
                if surveyMode == .gps {
                    Button("Drop here") { model.dropGPSSample() }
                        .buttonStyle(.bordered)
                        .frame(minHeight: Theme.touchTarget)
                        .disabled(model.signalStrength == nil || model.latitude == nil)
                }
                Button("Clear") { model.clearSamples() }
                    .buttonStyle(.bordered)
                    .frame(minHeight: Theme.touchTarget)
            }
            ResultRow(label: "Samples", value: "\(model.samples.count)")
            if let lat = model.latitude, let lon = model.longitude {
                ResultRow(label: "Fix", value: "\(formatCoordinate(lat)), \(formatCoordinate(lon))")
                ResultRow(label: "H. accuracy", value: model.accuracy.map { Format.meters($0) } ?? "—")
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private func save() {
        var outputs: [String: String] = [
            "status": model.status,
            "wifi": model.usesWiFi ? "yes" : "no",
            "ssid": model.ssid ?? "(not returned)",
            "strength 0-1": model.signalStrength.map { Format.number($0, digits: 2) } ?? "—",
            "strength %": model.signalStrength.map { Format.number(WiFiCoverageMath.percent($0), digits: 0) } ?? "—",
            "samples": "\(model.samples.count)",
        ]
        if let s = model.samples.max(by: { $0.strength < $1.strength }) {
            outputs["peak %"] = Format.number(WiFiCoverageMath.percent(s.strength), digits: 0)
        }
        if let summary = model.rttSummary {
            outputs["rtt host"] = model.rttHost.isEmpty ? "—" : "\(model.rttHost):\(model.rttPort)"
            outputs["rtt median ms"] = summary.medianMS.map { Format.number($0, digits: 0) } ?? "—"
            outputs["rtt loss %"] = Format.number(summary.lossPercent, digits: 0)
            outputs["rtt band"] = summary.band.rawValue
        }
        jobs.save(SavedJob(
            name: jobName,
            toolID: .wifiStatus,
            notes: notes,
            inputs: [
                "API": "NWPathMonitor + NEHotspotNetwork.signalStrength + TCP RTT",
                "mode": surveyMode.rawValue,
                "rttTarget": rttTarget.rawValue,
                "rttHost": customRTTHost,
            ],
            outputs: outputs
        ))
    }
}

struct WiFiStrengthGauge: View {
    var strength: Double?
    var onWiFi: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let s = strength ?? 0
        let bars = WiFiCoverageMath.bars(s)
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Theme.border, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: CGFloat(s) * 0.75)
                    .stroke(
                        AngularGradient(colors: [Theme.bad, Theme.warn, Theme.good], center: .center),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(225))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: s)
                VStack(spacing: 4) {
                    Text(strength == nil ? "—" : "\(Format.number(WiFiCoverageMath.percent(s), digits: 0))")
                        .font(.largeTitle.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.foreground)
                    Text(strength == nil ? "no strength" : "%  ·  Apple 0…1")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(width: 200, height: 200)
            .accessibilityElement()
            .accessibilityLabel(strength == nil ? "No Apple Wi-Fi strength" : "Apple strength \(Format.number(WiFiCoverageMath.percent(s), digits: 0)) percent, \(bars) of 4 bars.")
            HStack(alignment: .bottom, spacing: 7) {
                ForEach(1...4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(i <= bars ? barColor(i) : Theme.border)
                        .frame(width: 22, height: CGFloat(18 + i * 10))
                }
            }
            Text(onWiFi ? "Wi-Fi path up  ·  Apple’s 0…1 scale" : "Not on a Wi-Fi path  ·  Apple’s 0…1 scale")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func barColor(_ i: Int) -> Color {
        if i <= 1 { return Theme.bad }
        if i == 2 { return Theme.warn }
        return Theme.good
    }
}

struct WiFiHeatLegend: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("Low")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            LinearGradient(colors: [Theme.bad, Theme.warn, Theme.good], startPoint: .leading, endPoint: .trailing)
                .frame(height: 8)
                .clipShape(Capsule())
            Text("High")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            Text("Apple 0…1 strength")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
        }
    }
}

struct WiFiHeatmapCanvas: View {
    var samples: [WiFiAmplitudeSample]
    var mode: WiFiSurveyMode
    var roomWidth: Double
    var roomDepth: Double
    var amplitudeReady: Bool
    var onTap: (Double, Double) -> Void

    private typealias CoverageBox = (minE: Double, maxE: Double, minN: Double, maxN: Double)

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                drawHeat(context: &context, size: size)
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                let box = coverageBox()
                let (east, north) = world(from: location, size: geo.size, box: box)
                onTap(east, north)
            }
            .overlay(alignment: .topLeading) {
                Text(overlayCaption)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.foreground.opacity(0.8))
                    .padding(8)
            }
        }
        .background(Theme.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.accent.opacity(0.35), lineWidth: 1)
        )
    }

    private var overlayCaption: String {
        if mode == .tap, !amplitudeReady {
            return "Read SSID + strength first"
        }
        return mode == .tap ? "Tap to sample" : "GPS east / north"
    }

    private func coverageBox() -> CoverageBox? {
        mode == .tap ? nil : WiFiCoverageMath.bounds(samples, padding: 1.5)
    }

    private func drawHeat(context: inout GraphicsContext, size: CGSize) {
        let cols = 22
        let rows = 16
        let cw = size.width / CGFloat(cols)
        let rh = size.height / CGFloat(rows)
        let box = coverageBox()
        for r in 0..<rows {
            for c in 0..<cols {
                let x = (CGFloat(c) + 0.5) * cw
                let y = (CGFloat(r) + 0.5) * rh
                let (east, north) = world(from: CGPoint(x: x, y: y), size: size, box: box)
                let strength = samples.isEmpty ? 0 : WiFiCoverageMath.idw(east: east, north: north, samples: samples)
                let rect = CGRect(x: CGFloat(c) * cw, y: CGFloat(r) * rh, width: cw + 0.5, height: rh + 0.5)
                context.fill(Path(rect), with: .color(heatColor(strength).opacity(samples.isEmpty ? 0.12 : 0.85)))
            }
        }
        for sample in samples {
            let p = point(east: sample.east, north: sample.north, size: size, box: box)
            let rad: CGFloat = 6
            let dot = Path(ellipseIn: CGRect(x: p.x - rad, y: p.y - rad, width: rad * 2, height: rad * 2))
            context.fill(dot, with: .color(heatColor(sample.strength)))
            context.stroke(dot, with: .color(.white.opacity(0.85)), lineWidth: 1)
        }
        if samples.isEmpty {
            let text = Text("No samples yet").font(.caption).foregroundColor(Theme.muted)
            context.draw(text, at: CGPoint(x: size.width / 2, y: size.height / 2))
        }
    }

    private func heatColor(_ strength: Double) -> Color {
        let s = WiFiCoverageMath.clampStrength(strength)
        guard s.isFinite else { return Color.white.opacity(0.08) }
        if s < 0.5 {
            return rgbLerp(r1: 251, g1: 113, b1: 133, r2: 245, g2: 196, b2: 81, t: s / 0.5)
        }
        return rgbLerp(r1: 245, g1: 196, b1: 81, r2: 110, g2: 231, b2: 183, t: (s - 0.5) / 0.5)
    }

    private func rgbLerp(r1: Double, g1: Double, b1: Double, r2: Double, g2: Double, b2: Double, t: Double) -> Color {
        let t = min(1, max(0, t))
        return Color(
            red: ((r1 + (r2 - r1) * t) / 255),
            green: ((g1 + (g2 - g1) * t) / 255),
            blue: ((b1 + (b2 - b1) * t) / 255)
        )
    }

    private func world(from point: CGPoint, size: CGSize, box: CoverageBox?) -> (Double, Double) {
        let nx = size.width == 0 ? 0 : Double(point.x / size.width)
        let ny = size.height == 0 ? 0 : Double(1 - point.y / size.height)
        if mode == .tap {
            return (nx * roomWidth, ny * roomDepth)
        }
        guard let box else {
            return (nx * 10, ny * 10)
        }
        let east = box.minE + nx * (box.maxE - box.minE)
        let north = box.minN + ny * (box.maxN - box.minN)
        return (east, north)
    }

    private func point(east: Double, north: Double, size: CGSize, box: CoverageBox?) -> CGPoint {
        if mode == .tap {
            let x = roomWidth == 0 ? 0 : east / roomWidth
            let y = roomDepth == 0 ? 0 : north / roomDepth
            return CGPoint(x: x * size.width, y: (1 - y) * size.height)
        }
        guard let box else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
        let nx = (east - box.minE) / max(box.maxE - box.minE, 1e-9)
        let ny = (north - box.minN) / max(box.maxN - box.minN, 1e-9)
        return CGPoint(x: nx * size.width, y: (1 - ny) * size.height)
    }
}

/// App Store–safe TCP connect timing. Not ICMP ping, not RSSI, not dBm.
struct TCPConnectProbe: Equatable {
    var rttMS: Double?
    var localEndpoint: String?
    var remoteEndpoint: String?
}

enum WiFiRTTClient {
    static func probe(host: String, port: UInt16, timeout: TimeInterval) async -> Double? {
        await probeDetail(host: host, port: port, timeout: timeout).rttMS
    }

    static func probeDetail(
        host: String,
        port: UInt16,
        timeout: TimeInterval,
        requiredInterface: Network.NWInterface.InterfaceType? = nil
    ) async -> TCPConnectProbe {
        let remote = "\(host):\(port)"
        guard !host.isEmpty, port > 0 else {
            return TCPConnectProbe(rttMS: nil, localEndpoint: nil, remoteEndpoint: remote)
        }
        guard let nwPort = Network.NWEndpoint.Port(rawValue: port) else {
            return TCPConnectProbe(rttMS: nil, localEndpoint: nil, remoteEndpoint: remote)
        }
        let parameters = Network.NWParameters.tcp
        if let requiredInterface {
            parameters.requiredInterfaceType = requiredInterface
        }
        let connection = Network.NWConnection(
            host: Network.NWEndpoint.Host(host),
            port: nwPort,
            using: parameters
        )
        return await withCheckedContinuation { continuation in
            let lock = NSLock()
            var finished = false
            let start = CFAbsoluteTimeGetCurrent()
            @Sendable func finish(_ value: Double?) {
                lock.lock()
                defer { lock.unlock() }
                guard !finished else { return }
                finished = true
                let local = endpointSummary(connection.currentPath?.localEndpoint)
                connection.stateUpdateHandler = nil
                connection.cancel()
                continuation.resume(returning: TCPConnectProbe(
                    rttMS: value,
                    localEndpoint: local,
                    remoteEndpoint: remote
                ))
            }
            @Sendable func acceptTimed(_ ms: Double) {
                if let requiredInterface {
                    guard let path = connection.currentPath, path.usesInterfaceType(requiredInterface) else {
                        finish(nil)
                        return
                    }
                }
                finish(max(0, ms))
            }
            connection.stateUpdateHandler = { state in
                let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000
                switch state {
                case .ready:
                    acceptTimed(ms)
                case .failed(let error):
                    if isAnsweredFailure(error) {
                        acceptTimed(ms)
                    } else {
                        finish(nil)
                    }
                case .cancelled:
                    finish(nil)
                default:
                    break
                }
            }
            connection.start(queue: DispatchQueue.global(qos: .userInitiated))
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) {
                finish(nil)
            }
        }
    }

    static func endpointSummary(_ endpoint: Network.NWEndpoint?) -> String? {
        guard let endpoint else { return nil }
        switch endpoint {
        case .hostPort(let host, let port):
            let hostText: String
            switch host {
            case .name(let name, _):
                hostText = name
            case .ipv4, .ipv6:
                hostText = "\(host)"
            @unknown default:
                hostText = "\(host)"
            }
            guard !hostText.isEmpty else { return nil }
            return "\(hostText):\(port)"
        default:
            return nil
        }
    }

    /// RST / refused still traversed the path — count as an RTT sample.
    private static func isAnsweredFailure(_ error: Network.NWError) -> Bool {
        switch error {
        case .posix(let code):
            return code == .ECONNREFUSED || code == .ECONNRESET
        default:
            return false
        }
    }
}
