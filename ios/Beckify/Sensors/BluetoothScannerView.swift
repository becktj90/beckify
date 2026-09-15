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
    var companyID: UInt16?
    var companyName: String?
    var manufacturerPayloadBytes: Int
    var looksLikeIBeacon: Bool
    var txPowerDBm: Int?
    var isConnectable: Bool?
    var serviceData: [BLEServiceDataSummary]
    var kindHint: BLEKindHint

    var band: BLERadarBand { BLERadarMath.band(rssi: rssi) }
    var estimateCaption: String { BLERadarMath.estimatedMetersCaption(rssi: rssi) }
    var rowChip: String? { BLEAdvertisementMath.rowChip(kind: kindHint, companyID: companyID) }
    var tallyRow: BLEScanTallyRow {
        BLEScanTallyRow(name: name, rssi: rssi, companyID: companyID)
    }

    var companyIDCaption: String {
        companyID.map(BLEAdvertisementMath.formatCompanyID) ?? "—"
    }

    var manufacturerCaption: String {
        companyName ?? "—"
    }

    var connectableCaption: String {
        guard let isConnectable else { return "—" }
        return isConnectable ? "Yes" : "No"
    }

    var txPowerCaption: String {
        guard let txPowerDBm else { return "Not advertised" }
        return "\(txPowerDBm) dBm"
    }

    var detailAccessibilityLabel: String {
        var parts = [
            name,
            "\(rssi) dBm",
            "\(band.rawValue) band, \(estimateCaption)",
            "identifier \(id.uuidString)",
        ]
        if let rowChip {
            parts.append(rowChip)
        }
        parts.append(kindHint.detailValue)
        if companyName != nil {
            parts.append("manufacturer \(manufacturerCaption) \(companyIDCaption)")
        }
        parts.append("connectable \(connectableCaption)")
        if txPowerDBm != nil {
            parts.append("TX \(txPowerCaption)")
        }
        if !serviceIDs.isEmpty {
            parts.append("services \(serviceIDs.joined(separator: ", "))")
        }
        if !serviceData.isEmpty {
            parts.append("service data \(BLEAdvertisementMath.serviceDataCaption(serviceData))")
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
        let name = BLEAdvertisementMath.displayName(
            (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
        )
        let services = ((advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? [])
            .map(\.uuidString)
        let manufacturer = (advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data)
            .flatMap(BLEAdvertisementMath.parseManufacturerData)
        let txPower = (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue
        let connectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue
        let serviceDataRaw = (advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data]) ?? [:]
        let serviceData = serviceDataRaw
            .map { entry in
                BLEAdvertisementMath.summarizeServiceData(uuid: entry.key.uuidString, bytes: Array(entry.value))
            }
            .sorted { $0.uuid < $1.uuid }
        let kind = BLEAdvertisementMath.kindHint(
            name: name,
            companyID: manufacturer?.companyID,
            serviceIDs: services,
            serviceDataUUIDs: serviceData.map(\.uuid),
            looksLikeIBeacon: manufacturer?.looksLikeIBeacon ?? false
        )
        let id = peripheral.identifier
        let rssi = RSSI.intValue
        Task { @MainActor in
            seen[id] = BLESighting(
                id: id,
                name: name,
                rssi: rssi,
                serviceIDs: services,
                lastSeen: Date(),
                companyID: manufacturer?.companyID,
                companyName: manufacturer?.companyName,
                manufacturerPayloadBytes: manufacturer?.payloadByteCount ?? 0,
                looksLikeIBeacon: manufacturer?.looksLikeIBeacon ?? false,
                txPowerDBm: txPower,
                isConnectable: connectable,
                serviceData: serviceData,
                kindHint: kind
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

    private var summary: BLEScanSummary {
        BLEAdvertisementMath.summarize(model.sightings.map(\.tallyRow))
    }

    var body: some View {
        ToolScaffold(
            toolID: .bluetoothScan,
            stickyAnswer: summary.stickyLine,
            copyText: copyText,
            disclaimer: .sensor(extra: "\(BLEAdvertisementMath.peopleCountDisclaimer) Radar meters are a log-distance estimate from advertisement RSSI, not a rangefinder. Angle is a layout slot from the identifier — not a compass bearing or angle-of-arrival.")
        ) {
            ShowWorkCard(
                toolID: .bluetoothScan,
                symbolic: "d ≈ 10^((P₀ − RSSI) / (10 n))    angle = hash(identifier)",
                substituted: summary.stickyLine,
                meaning: "Device count ≠ people — one person can carry many radios; cars, printers, and mesh inflate counts; Apple rotates identifiers. Public BLE only. Radar radius is an uncalibrated RSSI estimate. Angle is layout, not direction-finding. RSSI is advertisement RSSI, not Wi-Fi."
            )
            RFHonestyBanner(
                title: "RSSI radar is a layout, not a bearing",
                detail: "Radius is a rough near / mid / far band from advertisement RSSI — not calibrated ranging. Angle is a stable slot from the identifier. iOS does not give third-party apps BLE angle-of-arrival."
            )
            ResultCard(title: "Scan summary", copyText: copyText) {
                ResultRow(label: "State", value: model.stateText, emphasis: true)
                ResultRow(label: "Devices", value: summary.deviceCountCaption, emphasis: true)
                ResultRow(label: "Named / unnamed", value: summary.namedCaption)
                ResultRow(label: "Near / mid / far", value: summary.bandCaption)
                if summary.unknownBand > 0 {
                    ResultRow(label: "Unknown band", value: "\(summary.unknownBand)")
                }
                ResultRow(label: "Top manufacturers", value: summary.manufacturersCaption)
                Text(BLEAdvertisementMath.peopleCountDisclaimer)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.warn)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .accessibilityLabel(BLEAdvertisementMath.peopleCountDisclaimer)
            }
            if model.unauthorized {
                ToolEmptyState(
                    title: "Bluetooth permission denied",
                    detail: "The scanner needs Bluetooth permission to list nearby BLE advertisements. Names, identifiers, manufacturer IDs, and RSSI stay on this device.",
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
                        .accessibilityHint("Shows device detail. Radar angle is a layout slot, not a bearing. Device count is not people.")
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

    private var copyText: String {
        var text = summary.copyLine
        if let top = model.sightings.first {
            var line = "\(top.name) \(top.rssi) dBm  \(top.band.rawValue)  \(top.estimateCaption)"
            if let chip = top.rowChip {
                line += "  \(chip)"
            }
            text += "\n\(line)"
        } else {
            text += "\n\(model.stateText)"
        }
        return text
    }

    private func save() {
        let top = model.sightings.prefix(8)
        var outputs: [String: String] = [
            "count": "\(summary.total)",
            "named": "\(summary.named)",
            "unnamed": "\(summary.unnamed)",
            "bands": summary.bandCaption,
            "manufacturers": summary.manufacturersCaption,
            "disclaimer": BLEAdvertisementMath.peopleCountDisclaimer,
        ]
        for (i, item) in top.enumerated() {
            var line = "\(item.name)  \(item.rssi) dBm  \(item.band.rawValue)  \(item.estimateCaption)  \(item.kindHint.rawValue)"
            if let company = item.companyName {
                line += "  \(company) \(item.companyIDCaption)"
            }
            line += "  \(item.id.uuidString)"
            outputs["\(i + 1)"] = line
        }
        jobs.save(SavedJob(
            name: jobName,
            toolID: .bluetoothScan,
            notes: notes,
            inputs: [
                "mode": "BLE central scan",
                "radar": "RSSI estimate layout, not AoA",
                "people": BLEAdvertisementMath.peopleCountDisclaimer,
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
                    if let chip = item.rowChip {
                        BLEHintChip(text: chip)
                    }
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

private struct BLEHintChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Theme.accent.opacity(0.14), in: Capsule(style: .continuous))
            .accessibilityHidden(true)
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
            Text("Meter labels are estimates from RSSI. Angle is layout, not a compass. Device count ≠ people.")
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
            + ". Radius is an RSSI distance estimate, not calibrated ranging. Angle is a stable layout slot, not direction. Device count is not people."
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
        .accessibilityHint("Shows device detail. Angle is a layout slot, not a bearing. Device count is not people.")
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
                            ResultRow(label: "Manufacturer", value: item.manufacturerCaption)
                            ResultRow(label: "Company ID", value: item.companyIDCaption)
                            ResultRow(label: "Kind hint", value: item.kindHint.detailValue)
                            ResultRow(label: "TX (advertised)", value: item.txPowerCaption)
                            ResultRow(label: "Connectable", value: item.connectableCaption)
                            if item.looksLikeIBeacon {
                                ResultRow(label: "iBeacon prefix", value: "Yes — public AD type, UUID not decoded")
                            }
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
                            serviceDataSection(item)
                            if item.manufacturerPayloadBytes > 0 {
                                ResultRow(label: "Manufacturer payload", value: "\(item.manufacturerPayloadBytes) B — not decoded")
                            }
                        }
                        Text("Kind is a hint from company ID and well-known service UUIDs, not identity. Estimate and radar radius are RSSI-only — advertised TX is radio output, not a 1 m calibration. Radar angle is a stable layout slot from this identifier — not a compass bearing or angle-of-arrival. \(BLEAdvertisementMath.peopleCountDisclaimer)")
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

    @ViewBuilder
    private func serviceDataSection(_ item: BLESighting) -> some View {
        if item.serviceData.isEmpty {
            ResultRow(label: "Service data", value: "None advertised")
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Service data")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                Text(BLEAdvertisementMath.serviceDataCaption(item.serviceData))
                    .font(.caption.monospaced())
                    .foregroundStyle(Theme.foreground)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(item.serviceData.enumerated()), id: \.offset) { _, entry in
                    if let hex = entry.previewHex {
                        DisclosureGroup("\(entry.uuid) hex") {
                            Text(hex)
                                .font(.caption.monospaced())
                                .foregroundStyle(Theme.accent)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }
}
