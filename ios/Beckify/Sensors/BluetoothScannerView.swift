import Combine
import CoreBluetooth
import SwiftUI
import BeckifyMath

struct BLESighting: Identifiable, Equatable {
    var id: UUID
    var name: String
    var rssi: Int
    var serviceIDs: [String]
    var lastSeen: Date

    var band: BLERadarBand { BLERadarMath.band(rssi: rssi) }
    var estimateCaption: String { BLERadarMath.estimatedMetersCaption(rssi: rssi) }

    var detailAccessibilityLabel: String {
        var parts = [
            name,
            "\(rssi) dBm",
            "\(band.rawValue) band, \(estimateCaption)",
            "identifier \(id.uuidString)",
        ]
        if !serviceIDs.isEmpty {
            parts.append("services \(serviceIDs.joined(separator: ", "))")
        }
        return parts.joined(separator: ", ")
    }
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
                self?.flushSightings()
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
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = BLEScannerModel()
    @StoredInput(.bluetoothScan, "jobName", default: "BLE scan") private var jobName
    @State private var notes = ""
    @State private var selectedID: UUID?

    var body: some View {
        ToolScaffold(
            toolID: .bluetoothScan,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .sensor(extra: "Radar meters are a log-distance estimate from advertisement RSSI, not a rangefinder. Angle is a layout slot from the identifier — not a compass bearing or angle-of-arrival.")
        ) {
            ShowWorkCard(
                toolID: .bluetoothScan,
                symbolic: "d ≈ 10^((P₀ − RSSI) / (10 n))    angle = hash(identifier)",
                substituted: sticky,
                meaning: "Public BLE only. No classic-Bluetooth sniffing. Radar radius is an uncalibrated RSSI estimate. Angle is layout, not direction-finding. RSSI is advertisement RSSI, not Wi-Fi."
            )
            RFHonestyBanner(
                title: "RSSI radar is a layout, not a bearing",
                detail: "Radius is a rough near / mid / far band from advertisement RSSI — not calibrated ranging. Angle is a stable slot from the identifier. iOS does not give third-party apps BLE angle-of-arrival."
            )
            ResultCard(title: "Radio", copyText: copyText) {
                ResultRow(label: "State", value: model.stateText, emphasis: true)
                ResultRow(label: "Devices", value: "\(model.sightings.count)")
                ResultRow(label: "Near / mid / far", value: bandCounts)
            }
            if model.unauthorized {
                ToolEmptyState(
                    title: "Bluetooth permission denied",
                    detail: "The scanner needs Bluetooth permission to list nearby BLE advertisements. Names, identifiers, and RSSI stay on this device.",
                    systemImage: "antenna.radiowaves.left.and.right.slash",
                    showsSettings: true
                )
            }
            ResultCard(title: "Radar") {
                Text("Live RSSI layout. Stronger advertisements sit closer to the phone. Angle is a stable slot — not direction.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                BLERadarMap(
                    sightings: Array(model.sightings.prefix(40)),
                    selectedID: selectedID,
                    scanning: model.scanning,
                    onSelect: { selectedID = $0.id }
                )
                .frame(height: radarHeight)
                BLERadarLegend()
            }
            ResultCard(title: "Peripherals") {
                if model.sightings.isEmpty {
                    Text(model.scanning ? "Listening for advertisements…" : "No scan running. Turn Bluetooth on, or allow the permission, then come back.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                } else {
                    ForEach(model.sightings.prefix(40)) { item in
                        Button {
                            selectedID = item.id
                        } label: {
                            BLEPeripheralRow(item: item, isSelected: item.id == selectedID)
                        }
                        .buttonStyle(.plain)
                        .frame(minHeight: Theme.touchTarget)
                        .accessibilityLabel(item.detailAccessibilityLabel)
                        .accessibilityHint("Shows device detail. Radar angle is a layout slot, not a bearing.")
                    }
                }
            }
            Button("Clear list") {
                selectedID = nil
                model.clear()
            }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .frame(minHeight: Theme.touchTarget)
            SaveJobBar(jobName: $jobName, notes: $notes, canSave: true) { save() }
        }
        .sheet(isPresented: Binding(
            get: { selectedID != nil },
            set: { if !$0 { selectedID = nil } }
        )) {
            BLEDeviceDetailSheet(item: selectedSighting, scanning: model.scanning)
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var selectedSighting: BLESighting? {
        guard let selectedID else { return nil }
        return model.sightings.first { $0.id == selectedID }
    }

    private var radarHeight: CGFloat {
        if dynamicTypeSize.isAccessibilitySize { return 260 }
        return sizeClass == .regular ? 360 : 300
    }

    private var bandCounts: String {
        let rows = model.sightings
        let near = rows.filter { $0.band == .near }.count
        let mid = rows.filter { $0.band == .mid }.count
        let far = rows.filter { $0.band == .far }.count
        return "\(near) / \(mid) / \(far)"
    }

    private var sticky: String {
        "\(model.sightings.count) device" + (model.sightings.count == 1 ? "" : "s")
    }
    private var copyText: String {
        if let top = model.sightings.first {
            return "\(top.name) \(top.rssi) dBm  \(top.band.rawValue)  \(top.estimateCaption)"
        }
        return model.stateText
    }

    private func save() {
        let top = model.sightings.prefix(8)
        var outputs: [String: String] = ["count": "\(model.sightings.count)"]
        for (i, item) in top.enumerated() {
            outputs["\(i + 1)"] = "\(item.name)  \(item.rssi) dBm  \(item.band.rawValue)  \(item.estimateCaption)  \(item.id.uuidString)"
        }
        jobs.save(SavedJob(
            name: jobName,
            toolID: .bluetoothScan,
            notes: notes,
            inputs: [
                "mode": "BLE central scan",
                "radar": "RSSI estimate layout, not AoA",
            ],
            outputs: outputs
        ))
    }
}

private struct BLEPeripheralRow: View {
    let item: BLESighting
    var isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.sm) {
            Circle()
                .fill(BLERadarStyle.color(for: item.band))
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                ResultRow(label: item.name, value: "\(item.rssi) dBm", emphasis: true)
                HStack(spacing: Theme.Space.xs) {
                    Text(item.band.rawValue)
                        .foregroundStyle(BLERadarStyle.color(for: item.band))
                    Text(item.estimateCaption)
                        .foregroundStyle(Theme.muted)
                }
                .font(Theme.TypeRole.help)
                Text(item.id.uuidString)
                    .font(.caption2.monospaced())
                    .foregroundStyle(Theme.muted)
                    .textSelection(.enabled)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            isSelected ? Theme.accent.opacity(0.10) : Color.clear,
            in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
        )
    }
}

private struct BLERadarLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: Theme.Space.sm) {
                legendSwatch(.near, title: "Near")
                legendSwatch(.mid, title: "Mid")
                legendSwatch(.far, title: "Far")
            }
            Text("Meter labels are estimates from RSSI. Angle is layout, not a compass.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func legendSwatch(_ band: BLERadarBand, title: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(BLERadarStyle.color(for: band))
                .frame(width: 8, height: 8)
            Text(title)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
        }
    }
}

private enum BLERadarStyle {
    static func color(for band: BLERadarBand) -> Color {
        switch band {
        case .near: return Theme.good
        case .mid: return Theme.warn
        case .far: return Theme.accent
        case .unknown: return Theme.muted
        }
    }
}

struct BLERadarMap: View {
    let sightings: [BLESighting]
    var selectedID: UUID?
    var scanning: Bool
    var onSelect: (BLESighting) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var placements: [BLERadarPlacement] {
        BLERadarMath.placements(from: sightings.map { (id: $0.id, rssi: $0.rssi) })
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let plotR = side * 0.42
            ZStack {
                BLERadarRings(center: center, plotR: plotR)
                if scanning {
                    Circle()
                        .stroke(Theme.accent.opacity(pulse ? 0.45 : 0.18), lineWidth: 2)
                        .frame(width: 22, height: 22)
                        .position(center)
                }
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 10, height: 10)
                    .position(center)
                    .accessibilityHidden(true)
                Text("You")
                    .font(Theme.TypeRole.hud)
                    .foregroundStyle(Theme.muted)
                    .position(x: center.x, y: center.y + 18)
                    .accessibilityHidden(true)
                ForEach(placements) { placement in
                    if let item = sightings.first(where: { $0.id == placement.id }) {
                        BLERadarDot(
                            item: item,
                            placement: placement,
                            selected: placement.id == selectedID,
                            center: center,
                            plotR: plotR,
                            onSelect: { onSelect(item) }
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.background, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.accent.opacity(0.35), lineWidth: Theme.Stroke.hairline)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(radarAccessibilitySummary)
        .onAppear { startPulse() }
        .onChange(of: scanning) { _, isOn in
            if isOn { startPulse() } else { pulse = false }
        }
    }

    private var radarAccessibilitySummary: String {
        let count = sightings.count
        return "Radar layout of \(count) peripheral" + (count == 1 ? "" : "s")
            + ". Radius is an RSSI distance estimate, not calibrated ranging. Angle is a stable layout slot, not direction."
    }

    private func startPulse() {
        guard scanning, !reduceMotion else {
            pulse = scanning
            return
        }
        pulse = false
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}

private struct BLERadarRings: View {
    var center: CGPoint
    var plotR: CGFloat

    var body: some View {
        Canvas { context, _ in
            let rings: [(CGFloat, String)] = [
                (0.38, "Near"),
                (0.64, "Mid"),
                (1.00, "Far"),
            ]
            for (scale, _) in rings {
                let r = plotR * scale
                let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                context.stroke(Path(ellipseIn: rect), with: .color(Theme.chartGrid), lineWidth: 1)
            }
            var cross = Path()
            cross.move(to: CGPoint(x: center.x - plotR, y: center.y))
            cross.addLine(to: CGPoint(x: center.x + plotR, y: center.y))
            cross.move(to: CGPoint(x: center.x, y: center.y - plotR))
            cross.addLine(to: CGPoint(x: center.x, y: center.y + plotR))
            context.stroke(cross, with: .color(Theme.hairline), lineWidth: 1)
            for (scale, title) in rings {
                let r = plotR * scale
                let text = Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Theme.muted)
                context.draw(text, at: CGPoint(x: center.x + r + 2, y: center.y - 10), anchor: .topLeading)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct BLERadarDot: View {
    let item: BLESighting
    let placement: BLERadarPlacement
    var selected: Bool
    var center: CGPoint
    var plotR: CGFloat
    var onSelect: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let point = Self.point(placement: placement, center: center, plotR: plotR)
        Button(action: onSelect) {
            ZStack {
                if selected {
                    Circle()
                        .stroke(Theme.foreground, lineWidth: 2)
                        .frame(width: 22, height: 22)
                }
                Circle()
                    .fill(BLERadarStyle.color(for: placement.band))
                    .frame(width: selected ? 14 : 12, height: selected ? 14 : 12)
                    .overlay(
                        Circle()
                            .stroke(Theme.surface, lineWidth: 1)
                    )
            }
            .frame(width: Theme.touchTarget, height: Theme.touchTarget)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .position(point)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: placement.normalizedRadius)
        .accessibilityLabel(item.detailAccessibilityLabel)
        .accessibilityHint("Shows device detail. Angle is a layout slot, not a bearing.")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private static func point(placement: BLERadarPlacement, center: CGPoint, plotR: CGFloat) -> CGPoint {
        let rad = placement.angleDegrees * .pi / 180
        let r = plotR * CGFloat(placement.normalizedRadius)
        return CGPoint(
            x: center.x + CGFloat(sin(rad)) * r,
            y: center.y - CGFloat(cos(rad)) * r
        )
    }
}

private struct BLEDeviceDetailSheet: View {
    let item: BLESighting?
    var scanning: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.md) {
                    if let item {
                        ResultCard(title: "Device") {
                            ResultRow(label: "Name", value: item.name, emphasis: true)
                            ResultRow(label: "RSSI", value: "\(item.rssi) dBm", emphasis: true, tone: BLERadarStyle.color(for: item.band))
                            ResultRow(label: "Band", value: item.band.rawValue, tone: BLERadarStyle.color(for: item.band))
                            ResultRow(label: "Estimate", value: item.estimateCaption)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Identifier")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.muted)
                                Text(item.id.uuidString)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(Theme.foreground)
                                    .textSelection(.enabled)
                            }
                            if item.serviceIDs.isEmpty {
                                ResultRow(label: "Services", value: "None advertised")
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Advertised services")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.muted)
                                    Text(item.serviceIDs.joined(separator: "\n"))
                                        .font(.caption.monospaced())
                                        .foregroundStyle(Theme.accent)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        Text("Estimate is a rough RSSI→distance band, not calibrated ranging. Radar angle is a stable layout slot from this identifier — not a compass bearing or angle-of-arrival.")
                            .font(Theme.TypeRole.help)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ToolEmptyState(
                            title: scanning ? "No longer heard" : "Scan stopped",
                            detail: "That advertisement dropped off the 30-second list, or the scan is no longer running.",
                            systemImage: "dot.radiowaves.left.and.right"
                        )
                    }
                }
                .padding(Theme.Space.lg)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(item?.name ?? "Peripheral")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .frame(minHeight: Theme.touchTarget)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
