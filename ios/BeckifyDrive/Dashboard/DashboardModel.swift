import BeckifyMath
import Foundation

/// Trip-scoped estimators, fed once a second from measured values.
struct DriveInsights {
    var efficiency = EfficiencyTracker()
    /// GPS-only distance: the "true efficiency" denominator and the grade baseline.
    var gpsTrip = DriveTripStats()
    var regen = RegenScoreTracker()
    var energy = TripEnergyLedger()

    init(spec: VehicleSpec? = .bolt) {
        let spec = spec ?? .bolt
        regen = RegenScoreTracker(massKg: spec.massKg, packVolts: spec.nominalPackVolts)
        energy = TripEnergyLedger(massKg: spec.massKg, packVolts: spec.nominalPackVolts)
    }
    var grade = GradeEstimator()
    var gradeSource: AltitudeSource?
    /// Session peaks, for steady gauge scales.
    var peakPowerKW = 0.0
    var peakTorqueNm = 0.0
}

enum AltitudeSource: String {
    case barometer = "barometer"
    case gps = "GPS altitude"
}

/// View state for the dashboard and the CarPlay screen. Reads
/// `OBDBluetoothSession` through its observer protocol and never changes how
/// the session polls.
///
/// One shared instance runs while the phone screen or CarPlay is showing, so
/// the trip and every estimator keep going with the phone locked in a mount.
final class DashboardModel: ObservableObject, OBDSessionObserving {
    static let shared = DashboardModel()

    /// Who is showing the dashboard's data right now.
    enum Client: Hashable {
        case phone
        case carPlay
    }

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
    @Published private(set) var insights = DriveInsights()
    @Published private(set) var capacityLog: CapacityLog
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
    let weather: WeatherService
    private let defaults: UserDefaults?
    private var timer: Timer?
    private var lastStamp: [OBDReading: Date] = [:]
    private var observing = false
    private var clients = Set<Client>()

    private static let capacityKey = "beckify.drive.capacityLog"

    init(
        session: OBDBluetoothSession = .shared,
        sensors: PhoneSensorStore = PhoneSensorStore(),
        weather: WeatherService = WeatherService(),
        defaults: UserDefaults = .standard
    ) {
        self.session = session
        self.sensors = sensors
        self.weather = weather
        self.defaults = defaults
        // Samples are stamped when they arrive; keep `now` current so a fresh
        // reply never reads as a future timestamp (which freshness rejects).
        now = Date()
        profile = session.profile
        book = session.book
        linkTitle = session.linkTitle
        linkDetail = session.linkDetail
        carPlayLink = session.carPlayLink
        isScanning = session.isScanning
        planning = session.planning
        capacityLog = CapacityLog.decoded(from: defaults.data(forKey: Self.capacityKey))
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
        insights: DriveInsights = DriveInsights(),
        capacityLog: CapacityLog = CapacityLog(),
        sensors: PhoneSensorStore,
        weather: WeatherService = WeatherService(preview: nil),
        now: Date
    ) {
        session = nil
        defaults = nil
        self.sensors = sensors
        self.weather = weather
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
        self.insights = insights
        self.capacityLog = capacityLog
        self.now = now
    }

    // MARK: Lifecycle

    /// Starts sensors and the 1 s tick on the first client; stops on the last.
    func attach(_ client: Client) {
        clients.insert(client)
        start()
    }

    func detach(_ client: Client) {
        clients.remove(client)
        if clients.isEmpty {
            stop()
        }
    }

    private func start() {
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

    private func stop() {
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
        insights = DriveInsights(spec: profile.spec)
        sensors.gForce.clear()
    }

    // MARK: Measured reads

    var layout: DriveLayout {
        profile.dashboardLayout
    }

    /// Constants behind the estimates. Nil for profiles without a published PID set.
    var spec: VehicleSpec? {
        profile.spec
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

    // MARK: CarPlay

    /// Regen, efficiency, and weather range rows for CarPlay.
    func carPlayExtras(units: DriveUnitPreference) -> DriveCarPlayExtras {
        guard layout == .ev else { return .unknown }
        return DriveCarPlayExtras.make(
            flow: flow,
            powerKW: powerKW,
            whPerMile: insights.efficiency.whPerMile(packKWh: planning.usableKWh),
            weatherRangeMiles: weatherAdjustment?.adjustedMiles,
            units: units
        )
    }

    // MARK: Estimates (Bolt profiles only: they need HV current and the 350 V assumption)

    /// Pack power, kW. + drive, − regen. Nil on generic profiles.
    var powerKW: Double? {
        guard layout == .ev else { return nil }
        guard let spec else { return nil }
        return DriveEstimates.packPowerKW(amps: value(.hvCurrentAmps).value, volts: spec.nominalPackVolts)
    }

    var flow: HVFlowState? {
        guard layout == .ev else { return nil }
        return HVFlowState.from(amps: value(.hvCurrentAmps).value)
    }

    /// Wheel torque, N·m, from pack power and OBD speed.
    var torqueNm: Double? {
        DriveEstimates.wheelTorqueNm(
            powerKW: powerKW,
            speedKph: value(.speedKph).value,
            radiusMeters: spec?.wheelRadiusMeters ?? DriveEstimates.boltWheelRadiusMeters
        )
    }

    /// Planning range in miles. Needs displayed charge actually read plus both typed inputs.
    var planningRangeMiles: Double? {
        DrivePlanning.rangeMiles(
            socPercent: value(.displayedSocPercent).value,
            usableKWh: planning.usableKWh,
            whPerMile: planning.whPerMile
        )
    }

    /// Weather used for range, only while fresh enough.
    var usableWeather: OpenMeteoCurrent? {
        guard let current = weather.current, current.isUsable(now: now) else { return nil }
        return current
    }

    var weatherAdjustment: RangeWeatherModel.Adjustment? {
        guard let weather = usableWeather else { return nil }
        let headwind = RangeWeatherModel.headwindMps(
            windSpeedMps: weather.windSpeedMps,
            windFromDegrees: weather.windFromDegrees,
            courseDegrees: sensors.courseDegrees
        )
        return RangeWeatherModel.adjust(
            baseMiles: planningRangeMiles,
            celsius: weather.temperatureC,
            speedKph: heroSpeed?.kph,
            headwindMps: headwind,
            spec: spec ?? .bolt
        )
    }

    var preconditionAdvice: PreconditionCoach.Advice {
        PreconditionCoach.advice(
            packC: value(.packTempC).value,
            trendPerMinute: TrendMath.slopePerMinute(history(.packTempC))
        )
    }

    // MARK: Private

    private func pull() {
        guard let session else { return }
        if session.profile != profile {
            histories = [:]
            lastStamp = [:]
            trip.reset()
            tripSource = nil
            insights = DriveInsights(spec: session.profile.spec)
        }
        // Samples are stamped when they arrive; keep `now` current so a fresh
        // reply never reads as a future timestamp (which freshness rejects).
        now = Date()
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
        // Peaks follow PID replies so the hero gauges rescale as soon as a value lands.
        var updated = insights
        if let powerKW { updated.peakPowerKW = max(updated.peakPowerKW, abs(powerKW)) }
        if let torqueNm { updated.peakTorqueNm = max(updated.peakTorqueNm, abs(torqueNm)) }
        if updated.peakPowerKW != insights.peakPowerKW || updated.peakTorqueNm != insights.peakTorqueNm {
            insights = updated
        }
    }

    private func tick() {
        now = Date()
        let obd = value(.speedKph)
        let gps = gpsSpeed
        if obd.freshness == .live, let kph = obd.value {
            trip.add(speedKph: kph, at: now)
            tripSource = .obd
        } else if let gps, gps.freshness == .live, let kph = gps.value {
            trip.add(speedKph: kph, at: now)
            tripSource = .gps
        } else {
            trip.add(speedKph: nil, at: now)
        }

        var next = insights
        next.gpsTrip.add(speedKph: gps?.freshness == .live ? gps?.value : nil, at: now)
        let gpsMiles = next.gpsTrip.distanceKilometers / DriveUnitPreference.kmPerMile

        let liveSoc = liveValue(.displayedSocPercent)
        let liveAmps = liveValue(.hvCurrentAmps)
        let liveSpeed = obd.freshness == .live ? obd.value : nil
        if layout == .ev {
            next.efficiency.update(socPercent: liveSoc, gpsMiles: gpsMiles)
            next.regen.add(speedKph: liveSpeed, amps: liveAmps, at: now)
        }

        // Barometric relative altitude is steadier than GPS; never mix the two in one window.
        let source: AltitudeSource?
        let altitude: Double?
        if let relative = sensors.relativeAltitudeMeters {
            source = .barometer
            altitude = relative
        } else if let gpsAltitude = sensors.altitudeMeters {
            source = .gps
            altitude = gpsAltitude
        } else {
            source = nil
            altitude = nil
        }
        if source != next.gradeSource {
            next.grade.reset()
            next.gradeSource = source
        }
        next.grade.add(distanceMeters: next.gpsTrip.distanceKilometers * 1_000, altitudeMeters: altitude)
        if layout == .ev {
            next.energy.add(amps: liveAmps, speedKph: liveSpeed ?? (gps?.freshness == .live ? gps?.value : nil), altitudeMeters: altitude, at: now)
        }
        insights = next

        if layout == .ev, let ah = liveValue(.capacityAh) {
            var log = capacityLog
            log.record(ampHours: ah, at: now)
            if log != capacityLog {
                capacityLog = log
                defaults?.set(log.encoded(), forKey: Self.capacityKey)
            }
        }

        if layout == .ev, let point = sensors.coordinate {
            weather.refreshIfNeeded(at: point, now: now)
        }
    }

    private func liveValue(_ reading: OBDReading) -> Double? {
        let current = value(reading)
        return current.freshness == .live ? current.value : nil
    }
}
