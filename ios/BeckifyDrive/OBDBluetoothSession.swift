import BeckifyMath
import CoreBluetooth
import Foundation

protocol OBDSessionObserving: AnyObject {
    func obdSessionDidUpdate()
}

struct DriveAdapter: Identifiable, Equatable {
    let id: UUID
    var name: String
    var rssi: Int
    var likely: Bool
}

/// BLE central for ELM327-class adapters. Bytes stay in this process.
final class OBDBluetoothSession: NSObject, ObservableObject {
    static let shared = OBDBluetoothSession()

    @Published private(set) var adapters: [DriveAdapter] = []
    @Published private(set) var linkTitle = "No adapter"
    @Published private(set) var linkDetail = "Scan for an ELM327-class Bluetooth LE adapter. Nothing is uploaded."
    @Published private(set) var carPlayLink = "No adapter"
    @Published private(set) var isScanning = false
    @Published private(set) var bluetoothDenied = false
    @Published private(set) var book = OBDReadingBook()
    @Published private(set) var trip = OBDTripTrack()
    @Published var profile: VehicleProfile {
        didSet {
            guard profile != oldValue else { return }
            book = OBDReadingBook()
            trip = OBDTripTrack()
            live = []
            persist()
            notify()
        }
    }
    @Published var packKWhText: String {
        didSet {
            guard packKWhText != oldValue else { return }
            persist()
            notify()
        }
    }
    @Published var whPerMileText: String {
        didSet {
            guard whPerMileText != oldValue else { return }
            persist()
            notify()
        }
    }

    private let defaults = UserDefaults.standard
    private var central: CBCentralManager?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var connected: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var writeType: CBCharacteristicWriteType = .withResponse
    private var pendingServices = 0
    private var buffer = ""
    private var inflight: String?
    private var queue: [String] = []
    private var live: [String] = []
    private var liveIndex = 0
    private var support = OBDSupportMap()
    private var timeout: DispatchWorkItem?
    private var missedReplies = 0
    private var retryConnect = false
    private let observers = NSHashTable<AnyObject>.weakObjects()

    private enum Key {
        static let profile = "beckify.drive.profile"
        static let pack = "beckify.drive.packKWh"
        static let wh = "beckify.drive.whPerMile"
        static let adapter = "beckify.drive.adapter"
    }

    var planning: PlanningInputs {
        PlanningInputs(usableKWh: parse(packKWhText), whPerMile: parse(whPerMileText))
    }

    var presentation: DrivePresentation {
        DrivePresentationBuilder.make(
            profile: profile,
            book: book,
            now: Date(),
            planning: planning,
            trip: trip,
            link: carPlayLink
        )
    }

    override init() {
        let stored = defaults.string(forKey: Key.profile) ?? VehicleProfile.boltEUV.rawValue
        let storedPack = defaults.string(forKey: Key.pack)
        profile = VehicleProfile(rawValue: stored) ?? .boltEUV
        packKWhText = storedPack ?? ""
        whPerMileText = defaults.string(forKey: Key.wh) ?? ""
        super.init()
        if storedPack == nil, profile == .boltEUV {
            packKWhText = "65"
        }
    }

    func activate() {
        guard central == nil else { return }
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func addObserver(_ observer: OBDSessionObserving) {
        observers.add(observer)
    }

    func removeObserver(_ observer: OBDSessionObserving) {
        observers.remove(observer)
    }

    func startScan() {
        activate()
        bluetoothDenied = false
        guard let central else { return }
        guard central.state == .poweredOn else {
            describe(central.state)
            return
        }
        isScanning = true
        if connected == nil {
            linkTitle = "Scanning"
            linkDetail = "Looking for a nearby ELM327-class adapter. Pairing happens here, not in Settings → Bluetooth."
            carPlayLink = "No adapter"
        }
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        notify()
    }

    func stopScan() {
        central?.stopScan()
        isScanning = false
        notify()
    }

    func connect(id: UUID) {
        guard let central, let peripheral = peripherals[id] else { return }
        stopScan()
        retryConnect = false
        connected = peripheral
        peripheral.delegate = self
        linkTitle = "Connecting"
        linkDetail = peripheral.name ?? "Adapter"
        carPlayLink = "Connecting"
        central.connect(peripheral, options: nil)
        notify()
    }

    func disconnect() {
        retryConnect = true
        if let connected, let central {
            central.cancelPeripheralConnection(connected)
        }
        tearDownIO(message: "Disconnected.", carPlay: "No adapter")
    }

    func select(profile next: VehicleProfile) {
        profile = next
        if packKWhText.isEmpty, let only = next.nominalPackChoicesKWh.first, next.nominalPackChoicesKWh.count == 1 {
            packKWhText = String(Int(only))
        }
    }

    private func parse(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Double(cleaned), value.isFinite else { return nil }
        return value
    }

    private func persist() {
        defaults.set(profile.rawValue, forKey: Key.profile)
        defaults.set(packKWhText, forKey: Key.pack)
        defaults.set(whPerMileText, forKey: Key.wh)
    }

    private func notify() {
        for case let observer as OBDSessionObserving in observers.allObjects {
            observer.obdSessionDidUpdate()
        }
    }

    private func describe(_ state: CBManagerState) {
        switch state {
        case .unauthorized:
            bluetoothDenied = true
            linkTitle = "Bluetooth not allowed"
            linkDetail = "Beckify Drive needs Bluetooth to talk to the adapter you choose. Readings stay on this phone."
            carPlayLink = "Not allowed"
        case .poweredOff:
            bluetoothDenied = false
            linkTitle = "Bluetooth is off"
            linkDetail = "Turn Bluetooth on to scan for an adapter."
            carPlayLink = "Bluetooth off"
        case .unsupported:
            linkTitle = "No Bluetooth LE"
            linkDetail = "This device cannot open a BLE adapter session."
            carPlayLink = "No adapter"
        default:
            linkTitle = "Waiting for Bluetooth"
            linkDetail = "Bluetooth is starting."
            carPlayLink = "No adapter"
        }
        notify()
    }

    private func beginCommands() {
        support = OBDSupportMap()
        buffer = ""
        inflight = nil
        missedReplies = 0
        queue = OBDCommandPlan.initialization + OBDCommandPlan.supportQueries
        live = []
        liveIndex = 0
        linkTitle = "Starting adapter"
        linkDetail = "ELM327 setup, then Mode 01. Bolt profiles add the published enhanced requests after that."
        carPlayLink = "Connecting"
        pump()
    }

    private func pump() {
        guard inflight == nil, writeCharacteristic != nil else { return }
        let command: String
        if !queue.isEmpty {
            command = queue.removeFirst()
        } else {
            if live.isEmpty {
                live = OBDCommandPlan.liveCycle(profile: profile, support: support)
                liveIndex = 0
            }
            guard !live.isEmpty else { return }
            command = live[liveIndex % live.count]
            liveIndex += 1
            if linkTitle == "Starting adapter" {
                linkTitle = "Polling"
                linkDetail = "Waiting for the first PID reply. Blank gauges stay blank."
                carPlayLink = "Connecting"
            }
        }
        inflight = command
        write(command + "\r")
        let work = DispatchWorkItem { [weak self] in
            self?.timedOut()
        }
        timeout?.cancel()
        timeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (command == "ATZ" ? 6 : 2.5), execute: work)
    }

    private func write(_ line: String) {
        guard let connected, let writeCharacteristic else { return }
        let payload = Data(line.utf8)
        let limit = max(connected.maximumWriteValueLength(for: writeType), 20)
        var offset = 0
        while offset < payload.count {
            let end = min(offset + limit, payload.count)
            connected.writeValue(payload.subdata(in: offset..<end), for: writeCharacteristic, type: writeType)
            offset = end
        }
    }

    private func timedOut() {
        guard inflight != nil else { return }
        inflight = nil
        missedReplies += 1
        if missedReplies >= 4 {
            linkTitle = "No data"
            linkDetail = "The adapter answered too slowly or the ignition is off. Readings already shown stay until they expire."
            carPlayLink = "No data"
        }
        pump()
        notify()
    }

    private func handle(command: String, reply: String) {
        switch OBDDecode.interpret(command: command, reply: reply) {
        case .adapter:
            missedReplies = 0
        case .fault:
            break
        case .support(let block, let data):
            missedReplies = 0
            support.record(block: block, data: data)
        case .readings(let values):
            missedReplies = 0
            if !carPlayLink.hasPrefix("Live") {
                linkTitle = "Live"
                linkDetail = "On-device. A blank gauge was not read from the car."
                carPlayLink = "Live · \(profile.title)"
                retryConnect = false
            }
            let stamp = Date()
            for (key, value) in values {
                book.write(key, value: value, at: stamp)
                if key == .speedKph {
                    trip.add(speedKph: value, at: stamp)
                }
            }
        case .ignored:
            break
        }
        notify()
    }

    private func finishDiscovery() {
        guard let connected else { return }
        let all = connected.services?.flatMap { $0.characteristics ?? [] } ?? []
        let chosen = Self.chooseChannels(all)
        writeCharacteristic = chosen.write
        notifyCharacteristic = chosen.notify
        writeType = chosen.writeType
        guard let notifyCharacteristic, writeCharacteristic != nil else {
            linkTitle = "Not a serial adapter"
            linkDetail = "Connected, but no write and notify characteristic was found. Try another ELM327 BLE dongle."
            carPlayLink = "No adapter"
            notify()
            return
        }
        connected.setNotifyValue(true, for: notifyCharacteristic)
    }

    static func chooseChannels(_ characteristics: [CBCharacteristic]) -> (write: CBCharacteristic?, notify: CBCharacteristic?, writeType: CBCharacteristicWriteType) {
        let ranked = characteristics.sorted { lhs, rhs in
            score(lhs) > score(rhs)
        }
        let both = ranked.first { channel in
            let props = channel.properties
            let canWrite = props.contains(.write) || props.contains(.writeWithoutResponse)
            let canNotify = props.contains(.notify) || props.contains(.indicate)
            return canWrite && canNotify
        }
        if let both {
            let writeType: CBCharacteristicWriteType = both.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
            return (both, both, writeType)
        }
        let write = ranked.first { $0.properties.contains(.write) || $0.properties.contains(.writeWithoutResponse) }
        let notify = ranked.first { $0.properties.contains(.notify) || $0.properties.contains(.indicate) }
        let writeType: CBCharacteristicWriteType = write?.properties.contains(.writeWithoutResponse) == true ? .withoutResponse : .withResponse
        return (write, notify, writeType)
    }

    private static func score(_ characteristic: CBCharacteristic) -> Int {
        let uuid = characteristic.uuid.uuidString.uppercased()
        var score = 0
        if uuid.contains("FFE1") || uuid.contains("FFF1") || uuid.hasSuffix("6E400003") || uuid.hasSuffix("6E400002") {
            score += 5
        }
        if characteristic.properties.contains(.notify) { score += 2 }
        if characteristic.properties.contains(.writeWithoutResponse) { score += 2 }
        if characteristic.properties.contains(.write) { score += 1 }
        return score
    }

    private func tearDownIO(message: String, carPlay: String) {
        timeout?.cancel()
        inflight = nil
        queue = []
        live = []
        buffer = ""
        writeCharacteristic = nil
        notifyCharacteristic = nil
        connected = nil
        linkTitle = "No adapter"
        linkDetail = message
        carPlayLink = carPlay
        notify()
    }

    private func rememberAdapter(_ id: UUID) {
        defaults.set(id.uuidString, forKey: Key.adapter)
    }

    private func restoreAdapterIfNeeded() {
        guard connected == nil, let central, central.state == .poweredOn else { return }
        guard let raw = defaults.string(forKey: Key.adapter), let id = UUID(uuidString: raw) else { return }
        let found = central.retrievePeripherals(withIdentifiers: [id])
        guard let peripheral = found.first else { return }
        peripherals[peripheral.identifier] = peripheral
        connect(id: peripheral.identifier)
    }
}

extension OBDBluetoothSession: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            bluetoothDenied = false
            if connected == nil && !isScanning {
                linkTitle = "No adapter"
                linkDetail = "Scan for an ELM327-class Bluetooth LE adapter. Nothing is uploaded."
                carPlayLink = "No adapter"
            }
            restoreAdapterIfNeeded()
        default:
            stopScan()
            describe(central.state)
        }
        notify()
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        peripherals[peripheral.identifier] = peripheral
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.map(\.uuidString) ?? []
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let displayName = (name?.isEmpty == false) ? (name ?? "Unnamed") : "Unnamed"
        let row = DriveAdapter(
            id: peripheral.identifier,
            name: displayName,
            rssi: RSSI.intValue,
            likely: OBDAdapterHint.looksLikeOBD(name: name, serviceUUIDs: services)
        )
        var next = adapters.filter { $0.id != row.id }
        next.append(row)
        next.sort { lhs, rhs in
            if lhs.likely != rhs.likely { return lhs.likely && !rhs.likely }
            return lhs.rssi > rhs.rssi
        }
        adapters = next
        notify()
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        rememberAdapter(peripheral.identifier)
        connected = peripheral
        peripheral.delegate = self
        linkTitle = "Connected"
        linkDetail = "Discovering the serial characteristic."
        carPlayLink = "Connecting"
        peripheral.discoverServices(nil)
        notify()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        tearDownIO(message: "Could not connect\(error.map { ": \($0.localizedDescription)" } ?? ".").", carPlay: "No adapter")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let shouldRetry = !retryConnect && error != nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        inflight = nil
        queue = []
        live = []
        if shouldRetry {
            retryConnect = true
            linkTitle = "Reconnecting"
            carPlayLink = "Connecting"
            central.connect(peripheral, options: nil)
            notify()
        } else {
            tearDownIO(message: "Adapter disconnected.", carPlay: "No adapter")
        }
    }
}

extension OBDBluetoothSession: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let services = peripheral.services ?? []
        guard error == nil, !services.isEmpty else {
            linkTitle = "No services"
            linkDetail = "The peripheral did not publish a GATT service."
            carPlayLink = "No adapter"
            notify()
            return
        }
        pendingServices = services.count
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        pendingServices = max(0, pendingServices - 1)
        if pendingServices == 0 {
            finishDiscovery()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == notifyCharacteristic?.uuid else { return }
        if error != nil || !characteristic.isNotifying {
            linkTitle = "Notify failed"
            linkDetail = "The adapter refused notifications, so replies cannot be read."
            carPlayLink = "No data"
            notify()
            return
        }
        beginCommands()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        let chunk = String(decoding: data, as: UTF8.self)
        let replies = ELMReassembler.replies(in: &buffer, appending: chunk)
        guard !replies.isEmpty else { return }
        timeout?.cancel()
        let command = inflight ?? ""
        inflight = nil
        for reply in replies {
            handle(command: command, reply: reply)
        }
        pump()
    }
}
