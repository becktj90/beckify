import Combine
import CoreBluetooth
import CoreMotion
import SwiftUI
import BeckifyMath

@MainActor
final class StillnessWatchModel: ObservableObject {
    @Published var magneticMicrotesla: Double?
    @Published var pressureKilopascals: Double?
    @Published var micDBFS: Double?
    @Published var advertisers: [StillnessAdvertiser] = []
    @Published var userG = 0.0
    @Published var magneticAvailable = false
    @Published var pressureAvailable = false
    @Published var pressureDenied = false
    @Published var pressureStatus = "Waiting for barometer…"
    @Published var bleStatus = "Bluetooth starting…"
    @Published var bleDenied = false
    @Published var baseline: StillnessBaseline?
    @Published var verdict = StillnessVerdict(
        phoneMoved: false,
        anomalies: [],
        magneticDeltaMicrotesla: nil,
        pressureDeltaPascals: nil,
        micAboveFloorDB: nil,
        advertisersAdded: 0,
        advertisersLost: 0,
        maxAbsRSSIJumpDB: nil,
        advertiserCount: 0
    )
    @Published var marks: [StillnessMark] = []

    private let motion = CMMotionManager()
    private var motionStarted = false
    private var magneticFrame = false
    private var active: Set<StillnessChannel> = []
    private var lastBump: Double?
    private let started = Date()
    private var session: StillnessAltimeterSession?
    private var generation: UInt64 = 0
    private var wantsPressure = false
    private let updateQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Beckify.StillnessWatch"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()
    private let ble = StillnessAdvertiserScan()

    func start() {
        startMotion()
        startPressure()
        ble.onChange = { [weak self] advertisers, status, denied in
            self?.advertisers = advertisers
            self?.bleStatus = status
            self?.bleDenied = denied
            self?.evaluate()
        }
        ble.start()
    }

    func stop() {
        if motionStarted {
            motion.stopDeviceMotionUpdates()
            motionStarted = false
        }
        wantsPressure = false
        session?.stop()
        session = nil
        ble.stop()
    }

    func noteMic(_ dbfs: Double) {
        micDBFS = dbfs
        evaluate()
    }

    func captureBaseline() {
        baseline = StillnessBaseline(
            magneticMicrotesla: magneticMicrotesla ?? .nan,
            pressureKilopascals: pressureKilopascals ?? .nan,
            noiseFloorDBFS: micDBFS ?? .nan,
            advertisers: advertisers
        )
        marks = []
        active = []
        lastBump = nil
        evaluate()
    }

    func resetBaseline() {
        baseline = nil
        marks = []
        active = []
        lastBump = nil
        evaluate()
    }

    private func startMotion() {
        guard motion.isDeviceMotionAvailable else { return }
        if motionStarted { return }
        let frames = CMMotionManager.availableAttitudeReferenceFrames()
        let frame: CMAttitudeReferenceFrame
        if frames.contains(.xMagneticNorthZVertical) {
            frame = .xMagneticNorthZVertical
            magneticFrame = true
            magneticAvailable = true
        } else if frames.contains(.xArbitraryZVertical) {
            frame = .xArbitraryZVertical
            magneticFrame = false
            magneticAvailable = false
        } else {
            return
        }
        motionStarted = true
        motion.deviceMotionUpdateInterval = 1.0 / 20.0
        motion.startDeviceMotionUpdates(using: frame, to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            if self.magneticFrame {
                let field = data.magneticField.field
                self.magneticMicrotesla = MagneticMath.magnitudeMicrotesla(x: field.x, y: field.y, z: field.z)
                self.magneticAvailable = true
            }
            let user = data.userAcceleration
            self.userG = MotionMath.magnitudeG(x: user.x, y: user.y, z: user.z)
            self.evaluate()
        }
    }

    private func startPressure() {
        wantsPressure = true
        guard session?.isUpdating != true else { return }
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            pressureAvailable = false
            pressureStatus = "This device does not have a barometer."
            return
        }
        switch CMAltimeter.authorizationStatus() {
        case .denied, .restricted:
            pressureDenied = true
            pressureAvailable = false
            pressureStatus = "Motion & Fitness permission is off."
            return
        default:
            break
        }
        generation += 1
        let token = generation
        let next = StillnessAltimeterSession()
        session = next
        next.start(queue: updateQueue) { [weak self] data, error in
            Task { @MainActor in
                guard let self, self.wantsPressure, self.generation == token else { return }
                if error != nil {
                    if CMAltimeter.authorizationStatus() == .denied || CMAltimeter.authorizationStatus() == .restricted {
                        self.pressureDenied = true
                        self.pressureStatus = "Motion & Fitness permission is off."
                    }
                    return
                }
                guard let data else { return }
                let pressure = data.pressure.doubleValue
                guard pressure.isFinite else { return }
                self.pressureKilopascals = pressure
                self.pressureAvailable = true
                self.pressureDenied = false
                self.pressureStatus = "CMAltimeter pressure"
                self.evaluate()
            }
        }
    }

    private func evaluate() {
        let sample = StillnessSample(
            magneticMicrotesla: magneticMicrotesla,
            pressureKilopascals: pressureKilopascals,
            micDBFS: micDBFS,
            advertisers: advertisers,
            userAccelerationG: userG
        )
        let now = Date().timeIntervalSince(started)
        let result = StillnessWatchMath.evaluate(
            sample: sample,
            baseline: baseline,
            nowSeconds: now,
            lastBumpSeconds: lastBump,
            previousAnomalies: Set(verdict.anomalies)
        )
        lastBump = result.lastBumpSeconds
        verdict = result.verdict
        let edge = StillnessWatchMath.risingMarks(previous: active, verdict: result.verdict, timeSeconds: now)
        active = edge.active
        if !edge.marks.isEmpty {
            marks.append(contentsOf: edge.marks)
            if marks.count > 40 { marks.removeFirst(marks.count - 40) }
        }
    }
}

private final class StillnessAltimeterSession {
    private let altimeter = CMAltimeter()
    private(set) var isUpdating = false

    func start(queue: OperationQueue, handler: @escaping CMAltitudeHandler) {
        guard !isUpdating else { return }
        isUpdating = true
        altimeter.startRelativeAltitudeUpdates(to: queue, withHandler: handler)
    }

    func stop() {
        guard isUpdating else { return }
        isUpdating = false
        altimeter.stopRelativeAltitudeUpdates()
    }

    deinit {
        if isUpdating { altimeter.stopRelativeAltitudeUpdates() }
    }
}

private final class StillnessAdvertiserScan: NSObject, CBCentralManagerDelegate {
    var onChange: (([StillnessAdvertiser], String, Bool) -> Void)?
    private var central: CBCentralManager?
    private var seen: [String: (rssi: Double, at: Date)] = [:]
    private let retention: TimeInterval = 6

    func start() {
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        } else {
            apply(central?.state ?? .unknown)
        }
    }

    func stop() {
        central?.stopScan()
    }

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            apply(central.state)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let id = peripheral.identifier.uuidString
        let rssi = RSSI.doubleValue
        Task { @MainActor in
            guard rssi.isFinite, rssi < 0 else { return }
            seen[id] = (rssi, Date())
            publish(status: "Scanning advertisers", denied: false)
        }
    }

    private func apply(_ state: CBManagerState) {
        switch state {
        case .poweredOn:
            central?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            publish(status: "Scanning advertisers", denied: false)
        case .unauthorized:
            publish(status: "Bluetooth permission is off", denied: true)
        case .poweredOff:
            publish(status: "Bluetooth is off", denied: false)
        default:
            publish(status: "Bluetooth starting…", denied: false)
        }
    }

    private func publish(status: String, denied: Bool) {
        let cutoff = Date().addingTimeInterval(-retention)
        seen = seen.filter { $0.value.at >= cutoff }
        let advertisers = seen.map { StillnessAdvertiser(id: $0.key, rssi: $0.value.rssi) }
            .sorted { $0.id < $1.id }
        onChange?(advertisers, status, denied)
    }
}

struct StillnessWatchView: View {
    @EnvironmentObject private var jobs: JobStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = StillnessWatchModel()
    @ObservedObject private var spectrum = MicrophoneSpectrumCenter.shared
    @State private var micToken = UUID()
    @StoredInput(.stillnessWatch, "jobName", default: "Stillness watch") private var jobName
    @State private var notes = ""

    var body: some View {
        ToolScaffold(
            toolID: .stillnessWatch,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .sensor(extra: StillnessWatchMath.honestLimit + " Mic impulses and the small spectrum are not a recording.")
        ) {
            ShowWorkCard(
                toolID: .stillnessWatch,
                symbolic: "tick when |Δ| crosses the session baseline    bump gate → phone moved",
                substituted: sticky,
                meaning: StillnessWatchMath.honestLimit
            )
            Text(StillnessWatchMath.honestLimit)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
            if model.verdict.phoneMoved {
                Text("Phone moved — this sample is not an anomaly.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.warn)
            }
            ResultCard(title: "Channels", copyText: copyText) {
                ForEach(StillnessChannel.anomalyChannels) { channel in
                    channelRow(channel)
                }
                ResultRow(label: "User accel", value: "\(Format.number(model.userG, digits: 2)) g")
                ResultRow(label: "Advertisers now", value: "\(model.verdict.advertiserCount)")
                ResultRow(label: "Barometer", value: model.pressureStatus)
                ResultRow(label: "Bluetooth", value: model.bleStatus)
                Text("Relative mic spectrum. Impulse marks only — nothing is recorded.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
                SpectrumPlot(
                    bands: spectrum.bands,
                    plotHeight: 64,
                    accessibilityLabel: "Small relative microphone spectrum",
                    footnote: stillnessSpectrumNote
                )
            }
            ResultCard(title: "Timeline") {
                if model.baseline == nil {
                    Text("Capture a baseline while the phone is still. Later crossings land here, one row per rising edge.")
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                } else if model.marks.isEmpty {
                    Text("Baseline is set. No channel has crossed yet.")
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                } else {
                    ForEach(model.marks.indices.reversed(), id: \.self) { index in
                        let mark = model.marks[index]
                        ResultRow(
                            label: String(format: "%.1f s · %@", mark.timeSeconds, mark.channel.title),
                            value: mark.detail,
                            tone: mark.channel == .phoneMoved ? Theme.warn : Theme.good
                        )
                    }
                }
            }
            HStack {
                Button("Capture baseline") { model.captureBaseline() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                Button("Reset") { model.resetBaseline() }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
            }
            .frame(minHeight: Theme.touchTarget)
            if spectrum.permissionDenied || model.pressureDenied || model.bleDenied {
                ToolEmptyState(
                    title: "A sensor permission is off",
                    detail: "The watch keeps the channels it can read. Microphone, Motion, and Bluetooth are the same prompts as Noise Meter, Barometer, and BLE Scanner. Nothing is recorded or uploaded.",
                    systemImage: "waveform",
                    showsSettings: true
                )
            }
            SaveJobBar(jobName: $jobName, notes: $notes, canSave: model.baseline != nil) { save() }
        }
        .onAppear {
            model.start()
            spectrum.retain(micToken, role: "Stillness")
        }
        .onDisappear {
            model.stop()
            spectrum.release(micToken)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                model.start()
                spectrum.retain(micToken, role: "Stillness")
            case .background:
                model.stop()
                spectrum.release(micToken)
            default:
                break
            }
        }
        .onChange(of: spectrum.rmsDBFS) { _, db in
            if spectrum.hasReading { model.noteMic(db) }
        }
    }

    private func channelRow(_ channel: StillnessChannel) -> some View {
        let crossed = model.verdict.anomalies.contains(channel)
        return ResultRow(
            label: channel.title,
            value: channelValue(channel, crossed: crossed),
            emphasis: crossed,
            tone: crossed ? Theme.warn : Theme.foreground
        )
    }

    private func channelValue(_ channel: StillnessChannel, crossed: Bool) -> String {
        if model.baseline == nil { return "No baseline" }
        if model.verdict.phoneMoved { return "Gated" }
        switch channel {
        case .magnetic:
            guard model.magneticAvailable, let delta = model.verdict.magneticDeltaMicrotesla, delta.isFinite else { return "—" }
            return StillnessWatchMath.detail(channel: .magnetic, verdict: model.verdict)
        case .pressure:
            guard model.pressureAvailable, let delta = model.verdict.pressureDeltaPascals, delta.isFinite else { return "—" }
            return StillnessWatchMath.detail(channel: .pressure, verdict: model.verdict)
        case .micImpulse:
            guard spectrum.hasReading, let delta = model.verdict.micAboveFloorDB, delta.isFinite else { return "—" }
            return StillnessWatchMath.detail(channel: .micImpulse, verdict: model.verdict)
        case .bleAdvertisers:
            return StillnessWatchMath.detail(channel: .bleAdvertisers, verdict: model.verdict)
        case .phoneMoved:
            return model.verdict.phoneMoved ? "Phone moved" : "Still"
        }
    }

    private var stillnessSpectrumNote: String {
        let rate = spectrum.sampleRateHz
        let nyquist = CoupledVibrationMath.nyquistHz(sampleRateHz: rate)
        let fs = rate > 0 ? "fs \(Format.number(rate, digits: 0)) Hz" : "fs —"
        let nq = nyquist.map { "Nyquist \(Format.number($0, digits: 0)) Hz" } ?? "Nyquist —"
        return "\(fs) · \(nq). Relative dBFS. The timeline is the record. Audio is not saved."
    }

    private var sticky: String? {
        if model.verdict.phoneMoved { return "Phone moved" }
        if model.verdict.anomalies.isEmpty { return model.baseline == nil ? nil : "Still" }
        return model.verdict.anomalies.map(\.title).joined(separator: " · ")
    }

    private var copyText: String? {
        guard model.baseline != nil else { return nil }
        let channels = model.verdict.activeChannels.map(\.title).joined(separator: ", ")
        return "Stillness: \(channels.isEmpty ? "no crossing" : channels). \(StillnessWatchMath.honestLimit)"
    }

    private func save() {
        jobs.save(SavedJob(
            name: jobName,
            toolID: .stillnessWatch,
            notes: notes,
            inputs: ["baseline": model.baseline == nil ? "no" : "yes"],
            outputs: [
                "channels": model.verdict.activeChannels.map(\.title).joined(separator: ", "),
                "advertisers": "\(model.verdict.advertiserCount)",
                "audio": "not recorded",
            ]
        ))
    }
}
