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
    @Published var ssidMessage = "Location is needed to read the current SSID and Apple’s 0…1 signalStrength. dBm is not available."
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var accuracy: Double?
    @Published var surveying = false
    @Published var surveyMode: WiFiSurveyMode = .gps
    @Published var samples: [WiFiAmplitudeSample] = []
    @Published var denied = false

    var roomWidth: Double = 12
    var roomDepth: Double = 8

    private var monitor: NWPathMonitor?
    private var pathGeneration = 0
    private let location = CLLocationManager()
    private var waitingForAuth = false
    private var pollTask: Task<Void, Never>?
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
        location.stopUpdatingLocation()
    }

    func requestNetworkInfo() {
        waitingForAuth = true
        ssidMessage = "Location is required by iOS to read SSID / BSSID / signalStrength. Nothing is uploaded. dBm is never provided."
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
                ssidMessage = "Location permission is off. iOS will not return SSID or signalStrength. dBm is never available."
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
            ssidMessage = "Location permission is off. iOS will not return SSID or signalStrength. dBm is never available."
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

    private func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { break }
                await self?.fetchNetwork()
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
                        self.ssidMessage = "SSID from NEHotspotNetwork.fetchCurrent. signalStrength was non-finite, so amplitude is shown as 0 on Apple’s 0…1 scale. This is not RSSI and not dBm."
                    } else if clamped <= 0 {
                        self.ssidMessage = "SSID from NEHotspotNetwork.fetchCurrent. signalStrength is \(Format.number(clamped, digits: 2)) on Apple’s 0…1 scale — often 0. This is not RSSI and not dBm."
                    } else {
                        self.ssidMessage = "Relative amplitude from NEHotspotNetwork.signalStrength (0…1). Public iOS APIs do not expose Wi-Fi dBm."
                    }
                } else {
                    self.ssid = nil
                    self.bssid = nil
                    self.signalStrength = nil
                    self.ssidMessage = "No current hotspot. Common causes: not on Wi-Fi, missing Access Wi-Fi Information, or location off. dBm is never available to third-party apps."
                }
            }
        }
    }
}

struct WiFiStatusView: View {
    @EnvironmentObject private var jobs: JobStore
    @StateObject private var model = WiFiPathModel()
    @StoredInput(.wifiStatus, "jobName", default: "Wi-Fi coverage") private var jobName
    @StoredChoice(.wifiStatus, "surveyMode", default: .gps) private var surveyMode
    @State private var notes = ""

    var body: some View {
        ToolScaffold(
            toolID: .wifiStatus,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .sensor(extra: "Walk or tap to drop samples. GPS indoor accuracy is often several meters. Apple may return 0.0 for signalStrength even when Wi-Fi works.")
        ) {
            ShowWorkCard(
                toolID: .wifiStatus,
                symbolic: "A = NEHotspotNetwork.signalStrength ∈ [0, 1]    heatmap = IDW(A, east, north)",
                substituted: substituted,
                meaning: "Suitable public unit is Apple’s 0…1 amplitude, shown as % and bars. Wi-Fi dBm / RSSI is not given to third-party iOS apps. This sketch is not a site survey."
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
                    label: "Amplitude",
                    value: amplitudeText,
                    emphasis: true,
                    tone: amplitudeTone
                )
                ResultRow(label: "dBm / RSSI", value: "not provided by iOS", tone: Theme.warn)
                Text(model.ssidMessage)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                Button("Read SSID + amplitude") { model.requestNetworkInfo() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .frame(minHeight: Theme.touchTarget)
                    .padding(.top, 6)
                    .accessibilityLabel("Read SSID and amplitude")
                    .accessibilityHint("Uses location in this tool only. Does not invent Wi-Fi dBm.")
            }
            if model.denied {
                ToolEmptyState(
                    title: "Location is needed for SSID",
                    detail: "iOS will not hand a third-party app the current SSID or Apple’s 0…1 amplitude without When In Use location. dBm is never available.",
                    systemImage: "wifi.slash",
                    showsSettings: true
                )
            }
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
        guard let s = model.signalStrength else {
            return "Read SSID + amplitude to plug Apple’s 0…1 value into the gauge. This will not become dBm."
        }
        return "A = \(Format.number(s, digits: 2))  →  \(Format.number(WiFiCoverageMath.percent(s), digits: 0)) %  ·  \(WiFiCoverageMath.bars(s))/4 bars"
    }

    private var sticky: String? {
        guard model.signalStrength != nil else { return model.usesWiFi ? "Wi-Fi path, no amplitude yet" : nil }
        return amplitudeText
    }

    private var copyText: String? {
        let ssid = model.ssid ?? "SSID —"
        if model.signalStrength != nil {
            return "\(ssid), \(amplitudeText), dBm not provided by iOS"
        }
        return nil
    }

    private var amplitudeText: String {
        guard let s = model.signalStrength else { return "—" }
        return "\(Format.number(WiFiCoverageMath.percent(s), digits: 0)) %   (\(Format.number(s, digits: 2)) · \(WiFiCoverageMath.bars(s))/4)"
    }

    private var amplitudeTone: Color {
        guard let s = model.signalStrength else { return Theme.muted }
        if s >= 0.6 { return Theme.good }
        if s >= 0.3 { return Theme.warn }
        return Theme.bad
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
                 ? "Walk the space. Samples drop every ~1.5 m from GPS plus Apple’s 0…1 amplitude."
                 : "Tap the floor plan to drop a sample at that spot using the current amplitude.")
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
            "amplitude 0-1": model.signalStrength.map { Format.number($0, digits: 2) } ?? "—",
            "dBm": "not provided by iOS",
            "samples": "\(model.samples.count)",
        ]
        if let s = model.samples.max(by: { $0.strength < $1.strength }) {
            outputs["peak %"] = Format.number(WiFiCoverageMath.percent(s.strength), digits: 0)
        }
        jobs.save(SavedJob(
            name: jobName,
            toolID: .wifiStatus,
            notes: notes,
            inputs: [
                "API": "NWPathMonitor + NEHotspotNetwork.signalStrength",
                "mode": surveyMode.rawValue,
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
                    Text(strength == nil ? "no amplitude" : "%  ·  Apple 0…1")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(width: 200, height: 200)
            .accessibilityElement()
            .accessibilityLabel(strength == nil ? "No Wi-Fi amplitude" : "Apple amplitude \(Format.number(WiFiCoverageMath.percent(s), digits: 0)) percent, \(bars) of 4 bars. Not dBm.")
            HStack(alignment: .bottom, spacing: 7) {
                ForEach(1...4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(i <= bars ? barColor(i) : Theme.border)
                        .frame(width: 22, height: CGFloat(18 + i * 10))
                }
            }
            Text(onWiFi ? "Wi-Fi path up  ·  dBm locked by iOS" : "Not on a Wi-Fi path  ·  dBm locked by iOS")
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
            Text("Apple 0…1, not dBm")
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
            return "Read SSID + amplitude first"
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
