#if DEBUG
import BeckifyMath
import SwiftUI

/// Fixture models for previews. Nothing scans, polls, or asks for permission.
enum DashboardFixtures {
    static let now = Date(timeIntervalSince1970: 1_790_000_000)
    static let usUnits = DriveUnitPreference(speed: .mph, temperature: .fahrenheit)

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
            sensors: PhoneSensorStore.preview(sensors, now: now),
            now: now
        )
    }

    static var drivingSensors: PhoneSensorStore.PreviewValues {
        var values = PhoneSensorStore.PreviewValues()
        values.gpsSpeedKph = 95
        values.altitudeMeters = 241
        values.headingDegrees = 312
        values.pressureKPa = 98.62
        values.relativeAltitudeMeters = 18
        values.batteryLevel = 0.82
        values.batteryCharging = true
        values.gTrail = cornerTrail
        return values
    }
}

#Preview("No adapter") {
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

#Preview("Partial data · generic") {
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

#Preview("Full Bolt EV · parked") {
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
            planning: PlanningInputs(usableKWh: 65, whPerMile: 280)
        ),
        preferences: DashboardPreferences(preview: DashboardFixtures.usUnits)
    )
}

#Preview("Bolt EV · driving") {
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
            sensors: DashboardFixtures.drivingSensors
        ),
        preferences: DashboardPreferences(preview: DashboardFixtures.usUnits)
    )
}

#Preview("Bolt EV · regen") {
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
            trip: DashboardFixtures.trip(minutes: 35, kph: 80),
            tripSource: .obd,
            sensors: DashboardFixtures.drivingSensors
        ),
        preferences: DashboardPreferences(preview: DriveUnitPreference(speed: .kmh, temperature: .celsius))
    )
}

#Preview("Bolt EV · partial replies") {
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

#Preview("Bolt EV · light") {
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
#endif
