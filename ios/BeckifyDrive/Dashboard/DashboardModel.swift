import BeckifyMath
import Foundation

/// View state for the dashboard. Reads `OBDBluetoothSession` through its
/// observer protocol and never changes how the session polls.
final class DashboardModel: ObservableObject, OBDSessionObserving {
    @Published private(set) var profile: VehicleProfile
    @Published private(set) var book: OBDReadingBook
    @Published private(set) var linkTitle: String
    @Published private(set) var linkDetail: String
    @Published private(set) var carPlayLink: String
    @Published private(set) var isScanning: Bool
    @Published private(set) var planning: PlanningInputs
    @Published private(set) var now: Date
    @Published private(set) var trip = DriveTripStats()
    @Published private(set) var tripSource: SpeedSource?
    @Published private(set) var histories: [OBDReading: SparklineBuffer] = [:]
    #if DEBUG
    @Published private(set) var rawReplies: [String: OBDBluetoothSession.RawReply] = [:]
    #endif

    enum SpeedSource: String {
        case obd = "OBD"
        case gps = "GPS"
    }

    /// Nil in previews: nothing is scanned or polled.
    let session: OBDBluetoothSession?
    let sensors: PhoneSensorStore
    private var timer: Timer?
    private var lastStamp: [OBDReading: Date] = [:]
    private var observing = false

    init(session: OBDBluetoothSession = .shared, sensors: PhoneSensorStore = PhoneSensorStore()) {
        self.session = session
        self.sensors = sensors
        profile = session.profile
        book = session.book
        linkTitle = session.linkTitle
        linkDetail = session.linkDetail
        carPlayLink = session.carPlayLink
        isScanning = session.isScanning
        planning = session.planning
        now = Date()
    }

    /// Preview / fixture model. `now` is frozen so freshness ages stay put.
    init(
        preview profile: VehicleProfile,
        book: OBDReadingBook,
        histories: [OBDReading: SparklineBuffer],
        linkTitle: String,
        linkDetail: String,
        carPlayLink: String,
        planning: PlanningInputs,
        trip: DriveTripStats,
        tripSource: SpeedSource?,
        sensors: PhoneSensorStore,
        now: Date
    ) {
        session = nil
        self.sensors = sensors
        self.profile = profile
        self.book = book
        self.histories = histories
        self.linkTitle = linkTitle
        self.linkDetail = linkDetail
        self.carPlayLink = carPlayLink
        isScanning = false
        self.planning = planning
        self.trip = trip
        self.tripSource = tripSource
        self.now = now
    }

    // MARK: Lifecycle

    func start() {
        guard let session else { return }
        if !observing {
            session.addObserver(self)
            observing = true
        }
        session.activate()
        pull()
        sensors.start()
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        sensors.stop()
    }

    func obdSessionDidUpdate() {
        pull()
    }

    func resetTrip() {
        trip.reset()
        tripSource = nil
        sensors.gForce.clear()
    }

    // MARK: Reads

    var layout: DriveLayout {
        profile.usesBoltPIDs ? .ev : .powertrain
    }

    var isLive: Bool {
        carPlayLink.hasPrefix("Live")
    }

    var isConnecting: Bool {
        isScanning || ["Connecting", "Connected", "Starting adapter", "Polling", "Reconnecting", "Scanning"].contains(linkTitle)
    }

    func value(_ reading: OBDReading) -> DriveValue {
        DriveValue.read(reading, from: book, now: now)
    }

    func history(_ reading: OBDReading) -> [SparklineBuffer.Point] {
        histories[reading]?.points(now: now) ?? []
    }

    /// Planning range in miles. Needs displayed charge actually read plus both typed inputs.
    var planningRangeMiles: Double? {
        DrivePlanning.rangeMiles(
            socPercent: value(.displayedSocPercent).value,
            usableKWh: planning.usableKWh,
            whPerMile: planning.whPerMile
        )
    }

    /// The speed the hero shows: OBD when live or stale, GPS otherwise.
    var heroSpeed: (kph: Double, source: SpeedSource, freshness: DriveFreshness)? {
        let obd = value(.speedKph)
        if let kph = obd.value {
            return (kph, .obd, obd.freshness)
        }
        if let gps = gpsSpeed, let kph = gps.value {
            return (kph, .gps, gps.freshness)
        }
        return nil
    }

    var gpsSpeed: DriveValue? {
        guard let kph = sensors.gpsSpeedKph, let at = sensors.lastLocationAt else { return nil }
        let freshness = DriveFreshness.evaluate(sample: OBDSample(value: kph, at: at), now: now, validRange: 0...400)
        return DriveValue(value: kph, freshness: freshness)
    }

    // MARK: Private

    private func pull() {
        guard let session else { return }
        if session.profile != profile {
            histories = [:]
            lastStamp = [:]
            trip.reset()
            tripSource = nil
        }
        profile = session.profile
        book = session.book
        linkTitle = session.linkTitle
        linkDetail = session.linkDetail
        carPlayLink = session.carPlayLink
        isScanning = session.isScanning
        planning = session.planning
        #if DEBUG
        rawReplies = session.rawReplies
        #endif
        var next = histories
        for reading in OBDReading.allCases {
            guard let sample = book.sample(reading), sample.at != lastStamp[reading] else { continue }
            lastStamp[reading] = sample.at
            var buffer = next[reading] ?? SparklineBuffer()
            buffer.append(sample.value, at: sample.at)
            next[reading] = buffer
        }
        histories = next
    }

    private func tick() {
        now = Date()
        let obd = value(.speedKph)
        if obd.freshness == .live, let kph = obd.value {
            trip.add(speedKph: kph, at: now)
            tripSource = .obd
        } else if let gps = gpsSpeed, gps.freshness == .live, let kph = gps.value {
            trip.add(speedKph: kph, at: now)
            tripSource = .gps
        } else {
            trip.add(speedKph: nil, at: now)
        }
    }
}
