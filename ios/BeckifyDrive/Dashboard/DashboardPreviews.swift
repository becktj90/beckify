#if DEBUG
import BeckifyMath
import SwiftUI

/// Fixture models for previews. Nothing scans, polls, or asks for permission.
enum DashboardFixtures {
    static let now = Date(timeIntervalSince1970: 1_790_000_000)
    static let usUnits = DriveUnitPreference(speed: .mph, temperature: .fahrenheit, power: .kilowatts, torque: .poundFeet)

    /// `ages` defaults to half a second (live). Over 5 s is stale; over 20 s is not reported.
    static func book(_ values: [OBDReading: Double], ages: [OBDReading: TimeInterval] = [:]) -> OBDReadingBook {
        var book = OBDReadingBook()
        for (reading, value) in values {
            book.write(reading, value: value, at: now.addingTimeInterval(-(ages[reading] ?? 0.5)))
        }
        return book
    }

    /// 60 one-second samples ending with the live value.
    static func histories(_ shapes: [OBDReading: (Double) -> Double]) -> [OBDReading: SparklineBuffer] {
        var out: [OBDReading: SparklineBuffer] = [:]
        for (reading, shape) in shapes {
            var buffer = SparklineBuffer()
            for second in 0..<60 {
                let t = Double(second)
                buffer.append(shape(t), at: now.addingTimeInterval(t - 59.5))
            }
            out[reading] = buffer
        }
        return out
    }

    static func trip(minutes: Double, kph: Double) -> DriveTripStats {
        var trip = DriveTripStats()
        let start = now.addingTimeInterval(-minutes * 60)
        for second in stride(from: 0.0, through: minutes * 60, by: 1) {
            trip.add(speedKph: kph + 12 * sin(second / 40), at: start.addingTimeInterval(second))
        }
        return trip
    }

    /// A left-hand sweeper after a brake.
    static let cornerTrail: [GVector] = (0..<45).map { index in
        let t = Double(index) / 44
        return GVector(longitudinal: -0.35 * (1 - t) + 0.05 * t, lateral: -0.42 * sin(t * .pi))
    }

    static func model(
        profile: VehicleProfile,
        book: OBDReadingBook,
        histories: [OBDReading: SparklineBuffer] = [:],
        live: Bool,
        linkTitle: String? = nil,
        linkDetail: String? = nil,
        planning: PlanningInputs = PlanningInputs(usableKWh: nil, whPerMile: nil),
        trip: DriveTripStats = DriveTripStats(),
        tripSource: DashboardModel.SpeedSource? = nil,
        insights: DriveInsights = DriveInsights(),
        capacityLog: CapacityLog = CapacityLog(),
        weather: OpenMeteoCurrent? = nil,
        sensors: PhoneSensorStore.PreviewValues = PhoneSensorStore.PreviewValues()
    ) -> DashboardModel {
        DashboardModel(
            preview: profile,
            book: book,
            histories: histories,
            linkTitle: linkTitle ?? (live ? "Live" : "No adapter"),
            linkDetail: linkDetail ?? (live ? "On-device. A blank gauge was not read from the car." : "Scan for an ELM327-class Bluetooth LE adapter. Nothing is uploaded."),
            carPlayLink: live ? "Live · \(profile.title)" : "No adapter",
            planning: planning,
            trip: trip,
            tripSource: tripSource,
            insights: insights,
            capacityLog: capacityLog,
            sensors: PhoneSensorStore.preview(sensors, now: now),
            weather: WeatherService(preview: weather),
            now: now
        )
    }

    /// 34 minutes of synthetic driving fed through the real estimators.
    static func drivingInsights() -> DriveInsights {
        var insights = DriveInsights()
        let start = now.addingTimeInterval(-34 * 60)
        for second in 0...(34 * 60) {
            let t = Double(second)
            let at = start.addingTimeInterval(t)
            // A stop every 4 minutes: 20 s braking with regen, 10 s stopped, 20 s pulling away.
            let phase = second % 240
            let kph: Double
            let amps: Double
            switch phase {
            case 0..<20: kph = 90 - 4.5 * Double(phase); amps = -45
            case 20..<30: kph = 0; amps = 6
            case 30..<50: kph = 4.5 * Double(phase - 30); amps = 210
            default: kph = 90 + 4 * sin(t / 20); amps = 70 + 15 * sin(t / 9)
            }
            insights.gpsTrip.add(speedKph: kph, at: at)
            let altitude = insights.gpsTrip.distanceKilometers * 1_000 * 0.031
            insights.grade.add(distanceMeters: insights.gpsTrip.distanceKilometers * 1_000, altitudeMeters: altitude)
            insights.regen.add(speedKph: kph, amps: amps, at: at)
            insights.energy.add(amps: amps, speedKph: kph, altitudeMeters: altitude, at: at)
            insights.efficiency.update(
                socPercent: 80 - t / Double(34 * 60) * 5.9,
                gpsMiles: insights.gpsTrip.distanceKilometers / DriveUnitPreference.kmPerMile
            )
        }
        insights.gradeSource = .barometer
        insights.peakPowerKW = 74
        insights.peakTorqueNm = 1_880
        return insights
    }

    /// Fourteen months of daily-ish capacity readings drifting down.
    static var capacityLog: CapacityLog {
        var log = CapacityLog()
        for month in 0..<14 {
            let at = now.addingTimeInterval(-Double(13 - month) * 30.4 * 86_400)
            log.record(ampHours: 166.2 - Double(month) * 0.22 + (month % 3 == 0 ? 0.3 : -0.1), at: at)
        }
        return log
    }

    static var weather: OpenMeteoCurrent {
        OpenMeteoCurrent(
            temperatureC: 4.5,
            windSpeedMps: 7.5,
            windFromDegrees: 295,
            fetchedAt: now.addingTimeInterval(-8 * 60),
            latitude: 42.33,
            longitude: -83.05
        )
    }

    static var drivingSensors: PhoneSensorStore.PreviewValues {
        var values = PhoneSensorStore.PreviewValues()
        values.gpsSpeedKph = 95
        values.altitudeMeters = 241
        values.headingDegrees = 312
        values.courseDegrees = 290
        values.pressureKPa = 98.62
        values.relativeAltitudeMeters = 18
        values.batteryLevel = 0.82
        values.batteryCharging = true
        values.gTrail = cornerTrail
        return values
    }
}

/// Named fixture states. Xcode previews and the CI screenshot job
/// (`-BeckifyDriveFixture <name>`) render the same ones.
enum DashboardScenario: String, CaseIterable {
    case noAdapter
    case partialGeneric
    case fullBolt
    case boltDriving
    case boltRegen
    case boltPartial
    case iceGeneric
    case genericEV
    case boltLight

    var title: String {
        switch self {
        case .noAdapter: return "No adapter"
        case .partialGeneric: return "Partial data · generic"
        case .fullBolt: return "Full Bolt EV · parked"
        case .boltDriving: return "Bolt EV · driving"
        case .boltRegen: return "Bolt EV · regen"
        case .boltPartial: return "Bolt EV · partial replies"
        case .iceGeneric: return "ICE generic"
        case .genericEV: return "Generic EV · standard PIDs"
        case .boltLight: return "Bolt EV · light"
        }
    }

    var view: AnyView {
        switch self {
        case .noAdapter: return AnyView(DashboardScenarioViews.noAdapter())
        case .partialGeneric: return AnyView(DashboardScenarioViews.partialGeneric())
        case .fullBolt: return AnyView(DashboardScenarioViews.fullBolt())
        case .boltDriving: return AnyView(DashboardScenarioViews.boltDriving())
        case .boltRegen: return AnyView(DashboardScenarioViews.boltRegen())
        case .boltPartial: return AnyView(DashboardScenarioViews.boltPartial())
        case .iceGeneric: return AnyView(DashboardScenarioViews.iceGeneric())
        case .genericEV: return AnyView(DashboardScenarioViews.genericEV())
        case .boltLight: return AnyView(DashboardScenarioViews.boltLight())
        }
    }
}

enum DashboardScenarioViews {
    /// Any EV on standard Mode 01: no charge, current, or estimates.
    static func genericEV() -> some View {
        DashboardView(
            model: DashboardFixtures.model(
                profile: .genericEV,
                book: DashboardFixtures.book([
                    .speedKph: 88, .moduleVolts: 14.3, .ambientC: 9,
                    .hybridRemainingLifePercent: 94, .acceleratorPercent: 18,
                ]),
                histories: DashboardFixtures.histories([
                    .moduleVolts: { 14.3 + 0.03 * sin($0 / 3) },
                    .ambientC: { _ in 9 },
                    .hybridRemainingLifePercent: { _ in 94 },
                ]),
                live: true,
                trip: DashboardFixtures.trip(minutes: 18, kph: 84),
                tripSource: .obd,
                sensors: DashboardFixtures.drivingSensors
            ),
            preferences: DashboardPreferences(preview: DashboardFixtures.usUnits)
        )
    }

    static func noAdapter() -> some View {
    var sensors = PhoneSensorStore.PreviewValues()
    sensors.locationAccess = .denied
    sensors.motionAccess = .unavailable
    sensors.batteryLevel = 0.64
    sensors.gTrail = []
    sensors.gAligned = false
    return DashboardView(
        model: DashboardFixtures.model(profile: .boltEUV, book: OBDReadingBook(), live: false, sensors: sensors),
        preferences: DashboardPreferences(preview: DashboardFixtures.usUnits)
    )
    }

    static func partialGeneric() -> some View {
    DashboardView(
        model: DashboardFixtures.model(
            profile: .generic,
            book: DashboardFixtures.book(
                [.speedKph: 54, .rpm: 2_150, .coolantC: 88, .engineLoadPercent: 34, .throttlePercent: 18, .moduleVolts: 13.9],
                ages: [.throttlePercent: 12]
            ),
            histories: DashboardFixtures.histories([
                .coolantC: { 84 + $0 / 15 },
                .engineLoadPercent: { 30 + 12 * sin($0 / 6) },
                .moduleVolts: { 13.9 + 0.05 * sin($0 / 4) },
            ]),
            live: true,
            trip: DashboardFixtures.trip(minutes: 12, kph: 52),
            tripSource: .obd
        ),
        preferences: DashboardPreferences(preview: DashboardFixtures.usUnits)
    )
    }

    static func fullBolt() -> some View {
    DashboardView(
        model: DashboardFixtures.model(
            profile: .boltEV,
            book: DashboardFixtures.book([
                .speedKph: 0, .displayedSocPercent: 81, .packTempC: 24, .hvCurrentAmps: 3.2,
                .capacityAh: 165.4, .hybridRemainingLifeHDPercent: 92.4, .motorTempC: 31,
                .moduleVolts: 14.1, .ambientC: 19,
            ]),
            histories: DashboardFixtures.histories([
                .hvCurrentAmps: { _ in 3.2 },
                .packTempC: { 23 + $0 / 60 },
                .motorTempC: { 33 - $0 / 30 },
                .moduleVolts: { 14.1 + 0.02 * sin($0 / 5) },
            ]),
            live: true,
            planning: PlanningInputs(usableKWh: 65, whPerMile: 280),
            capacityLog: DashboardFixtures.capacityLog,
            weather: DashboardFixtures.weather
        ),
        preferences: DashboardPreferences(preview: DashboardFixtures.usUnits)
    )
    }

    static func boltDriving() -> some View {
    DashboardView(
        model: DashboardFixtures.model(
            profile: .boltEV,
            book: DashboardFixtures.book([
                .speedKph: 96, .displayedSocPercent: 72, .packTempC: 28, .hvCurrentAmps: 84.5,
                .capacityAh: 165.4, .hybridRemainingLifeHDPercent: 92.4, .motorTempC: 56,
                .moduleVolts: 14.0, .ambientC: 21,
            ]),
            histories: DashboardFixtures.histories([
                .hvCurrentAmps: { 90 + 55 * sin($0 / 5) },
                .packTempC: { 27 + $0 / 60 },
                .motorTempC: { 50 + $0 / 10 },
                .moduleVolts: { 14.0 + 0.04 * sin($0 / 3) },
                .speedKph: { 92 + 6 * sin($0 / 8) },
            ]),
            live: true,
            planning: PlanningInputs(usableKWh: 65, whPerMile: 280),
            trip: DashboardFixtures.trip(minutes: 34, kph: 88),
            tripSource: .obd,
            insights: DashboardFixtures.drivingInsights(),
            capacityLog: DashboardFixtures.capacityLog,
            weather: DashboardFixtures.weather,
            sensors: DashboardFixtures.drivingSensors
        ),
        preferences: DashboardPreferences(preview: DashboardFixtures.usUnits)
    )
    }

    static func boltRegen() -> some View {
    DashboardView(
        model: DashboardFixtures.model(
            profile: .boltEV,
            book: DashboardFixtures.book([
                .speedKph: 70, .displayedSocPercent: 72, .packTempC: 28, .hvCurrentAmps: -62,
                .motorTempC: 58, .moduleVolts: 14.0,
            ]),
            histories: DashboardFixtures.histories([
                .hvCurrentAmps: { 60 - 2.1 * $0 },
                .packTempC: { _ in 28 },
                .motorTempC: { 55 + $0 / 20 },
            ]),
            live: true,
            planning: PlanningInputs(usableKWh: 65, whPerMile: 280),
            trip: DashboardFixtures.trip(minutes: 35, kph: 80),
            tripSource: .obd,
            insights: DashboardFixtures.drivingInsights(),
            capacityLog: DashboardFixtures.capacityLog,
            weather: DashboardFixtures.weather,
            sensors: DashboardFixtures.drivingSensors
        ),
        preferences: DashboardPreferences(preview: DriveUnitPreference(speed: .kmh, temperature: .celsius))
    )
    }

    static func boltPartial() -> some View {
    var sensors = PhoneSensorStore.PreviewValues()
    sensors.locationAccess = .notAsked
    sensors.motionAccess = .notAsked
    sensors.batteryLevel = 0.18
    sensors.gAligned = false
    return DashboardView(
        model: DashboardFixtures.model(
            profile: .boltEUV,
            book: DashboardFixtures.book(
                // Motor temp 210 °C is outside the plausibility range: shown as a warning, not a number.
                [.displayedSocPercent: 64, .packTempC: 31, .motorTempC: 210, .moduleVolts: 11.7],
                ages: [.packTempC: 9]
            ),
            live: true,
            linkTitle: "Live",
            linkDetail: "Some enhanced PIDs have not answered yet. Blank gauges stay blank.",
            planning: PlanningInputs(usableKWh: 65, whPerMile: nil)
        ),
        preferences: DashboardPreferences(preview: DashboardFixtures.usUnits)
    )
    }

    static func iceGeneric() -> some View {
    var sensors = DashboardFixtures.drivingSensors
    sensors.gTrail = DashboardFixtures.cornerTrail
    return DashboardView(
        model: DashboardFixtures.model(
            profile: .generic,
            book: DashboardFixtures.book([
                .speedKph: 88, .rpm: 2_430, .coolantC: 91, .engineLoadPercent: 41, .throttlePercent: 22,
                .fuelLevelPercent: 63, .moduleVolts: 14.2, .ambientC: 12, .oilTempC: 98,
            ]),
            histories: DashboardFixtures.histories([
                .coolantC: { 90 + sin($0 / 10) },
                .engineLoadPercent: { 38 + 10 * sin($0 / 5) },
                .throttlePercent: { 20 + 6 * sin($0 / 4) },
                .fuelLevelPercent: { 63.3 - $0 / 200 },
                .moduleVolts: { 14.2 + 0.03 * sin($0 / 3) },
                .ambientC: { _ in 12 },
            ]),
            live: true,
            trip: DashboardFixtures.trip(minutes: 22, kph: 80),
            tripSource: .obd,
            sensors: sensors
        ),
        preferences: DashboardPreferences(preview: DashboardFixtures.usUnits)
    )
    }

    static func boltLight() -> some View {
    DashboardView(
        model: DashboardFixtures.model(
            profile: .boltEV,
            book: DashboardFixtures.book([.speedKph: 96, .displayedSocPercent: 12, .packTempC: 47, .hvCurrentAmps: 120, .motorTempC: 61, .moduleVolts: 14.0]),
            histories: DashboardFixtures.histories([.hvCurrentAmps: { 110 + 20 * sin($0 / 4) }]),
            live: true,
            sensors: DashboardFixtures.drivingSensors
        ),
        preferences: DashboardPreferences(preview: DashboardFixtures.usUnits, appearance: .system)
    )
    .preferredColorScheme(.light)
    }
}

#Preview("No adapter") {
    DashboardScenario.noAdapter.view
}

#Preview("Partial data · generic") {
    DashboardScenario.partialGeneric.view
}

#Preview("Full Bolt EV · parked") {
    DashboardScenario.fullBolt.view
}

#Preview("Bolt EV · driving") {
    DashboardScenario.boltDriving.view
}

#Preview("Bolt EV · regen") {
    DashboardScenario.boltRegen.view
}

#Preview("Bolt EV · partial replies") {
    DashboardScenario.boltPartial.view
}

#Preview("ICE generic") {
    DashboardScenario.iceGeneric.view
}

#Preview("Generic EV · standard PIDs") {
    DashboardScenario.genericEV.view
}

#Preview("Bolt EV · light") {
    DashboardScenario.boltLight.view
}
#endif
