import XCTest
@testable import BeckifyMath

final class DriveCarPlayTileMathTests: XCTestCase {
    private let us = DriveUnitPreference.systemDefault(measurementSystem: "us")
    private let metric = DriveUnitPreference.systemDefault(measurementSystem: "metric")

    private func boltDriving() -> DriveCarPlayTileInputs {
        DriveCarPlayTileInputs(
            layout: .ev,
            socPercent: 64.7,
            powerKW: 11.2,
            peakPowerKW: 42,
            flow: .drive,
            speedKph: 96.56,
            speedSource: "OBD",
            rangeMiles: 167,
            weatherRangeMiles: 140,
            whPerMile: 290,
            packTempC: 29
        )
    }

    func testBoltLayoutHasEightTilesInOrder() {
        let tiles = DriveCarPlayTiles.make(boltDriving(), units: us)
        XCTAssertEqual(tiles.map(\.kind), [.charge, .power, .flow, .speed, .range, .weatherRange, .efficiency, .packTemp])
    }

    func testRegenRingUsesRegenScore() {
        var input = boltDriving()
        input.regenScore = 0.62
        let ring = DriveCarPlayTiles.regenRing(input)
        XCTAssertEqual(ring.value, "62")
        XCTAssertEqual(ring.unit, "%")
        XCTAssertEqual(ring.gauge, .ring(fraction: 0.62))
        XCTAssertTrue(ring.isEstimate)
        input.regenScore = nil
        XCTAssertNil(DriveCarPlayTiles.regenRing(input).gauge)
    }

    func testRangeBandShowsOnTileAndDetail() {
        var input = boltDriving()
        input.rangeMiles = 214
        input.rangeLowMiles = 180
        input.rangeHighMiles = 214
        let range = DriveCarPlayTiles.range(input, units: us)
        XCTAssertEqual(range.note, "180–214 mi")
        XCTAssertTrue(DriveCarPlayTiles.readouts(.range, input, units: us).contains { $0.label == "BAND" })
    }

    func testRangeBandMathUsesBothEfficiencies() {
        let band = DrivePlanning.rangeBandMiles(socPercent: 50, usableKWh: 65, planningWh: 263, measuredWh: 300)
        XCTAssertNotNil(band)
        XCTAssertLessThan(band?.low ?? 0, band?.high ?? 0)
        XCTAssertNil(DrivePlanning.rangeBandMiles(socPercent: 50, usableKWh: 65, planningWh: 263, measuredWh: nil))
        XCTAssertNil(DrivePlanning.rangeBandMiles(socPercent: 50, usableKWh: 65, planningWh: 263, measuredWh: 263))
    }

    func testBoltDrivingValuesInUSUnits() {
        let tiles = Dictionary(uniqueKeysWithValues: DriveCarPlayTiles.make(boltDriving(), units: us).map { ($0.kind, $0) })
        XCTAssertEqual(tiles[.charge]?.value, "65")
        XCTAssertEqual(tiles[.charge]?.unit, "%")
        XCTAssertEqual(tiles[.charge]?.gauge, .ring(fraction: 0.647))
        // 11.2 kW = 15.0 hp.
        XCTAssertEqual(tiles[.power]?.value, "15")
        XCTAssertEqual(tiles[.power]?.unit, "hp")
        XCTAssertEqual(tiles[.power]?.note, "est.")
        XCTAssertTrue(tiles[.power]?.isEstimate ?? false)
        XCTAssertEqual(tiles[.power]?.tone, .estimated)
        XCTAssertEqual(tiles[.flow]?.title, "Regen")
        XCTAssertEqual(tiles[.speed]?.value, "60")
        XCTAssertEqual(tiles[.speed]?.unit, "mph")
        XCTAssertEqual(tiles[.speed]?.note, "OBD")
        XCTAssertEqual(tiles[.range]?.value, "167")
        XCTAssertEqual(tiles[.range]?.unit, "mi")
        XCTAssertEqual(tiles[.weatherRange]?.value, "140")
        XCTAssertEqual(tiles[.efficiency]?.value, "290")
        XCTAssertEqual(tiles[.efficiency]?.unit, "Wh/mi")
        // 29 °C = 84 °F, nominal band.
        XCTAssertEqual(tiles[.packTemp]?.value, "84")
        XCTAssertEqual(tiles[.packTemp]?.unit, "°F")
        XCTAssertEqual(tiles[.packTemp]?.note, "Nominal")
        XCTAssertEqual(tiles[.packTemp]?.tone, .accent)
    }

    func testMetricUnits() {
        let tiles = Dictionary(uniqueKeysWithValues: DriveCarPlayTiles.make(boltDriving(), units: metric).map { ($0.kind, $0) })
        XCTAssertEqual(tiles[.power]?.value, "11")
        XCTAssertEqual(tiles[.power]?.unit, "kW")
        XCTAssertEqual(tiles[.speed]?.value, "97")
        XCTAssertEqual(tiles[.speed]?.unit, "km/h")
        XCTAssertEqual(tiles[.range]?.value, "269")
        XCTAssertEqual(tiles[.range]?.unit, "km")
        XCTAssertEqual(tiles[.efficiency]?.value, "180")
        XCTAssertEqual(tiles[.efficiency]?.unit, "Wh/km")
        XCTAssertEqual(tiles[.packTemp]?.value, "29")
        XCTAssertEqual(tiles[.packTemp]?.unit, "°C")
    }

    func testPowerArcIsBipolarAndScalesFromPeak() {
        // Peak 42 kW rounds the scale up to 50 kW.
        var input = boltDriving()
        input.powerKW = 25
        let drive = DriveCarPlayTiles.power(input, units: us)
        XCTAssertEqual(drive.gauge, .bipolar(fraction: 0.5))

        input.powerKW = -20
        input.flow = .regen
        let regen = DriveCarPlayTiles.power(input, units: us)
        XCTAssertEqual(regen.gauge, .bipolar(fraction: -0.4))
        XCTAssertEqual(regen.tone, .regen)
        // Value is the magnitude; direction is the arc side and tone.
        XCTAssertEqual(regen.value, "27")

        input.powerKW = 130
        input.peakPowerKW = 0
        let bigger = DriveCarPlayTiles.power(input, units: us)
        // A reading above the peak widens the scale to 150 kW instead of pinning.
        if case let .bipolar(fraction)? = bigger.gauge {
            XCTAssertEqual(fraction, 130.0 / 150.0, accuracy: 1e-9)
        } else {
            XCTFail("power gauge should be bipolar")
        }
    }

    func testPowerScaleMatchesPhoneHero() {
        XCTAssertEqual(DriveCarPlayTiles.powerScaleKW(peak: 0), 50)
        XCTAssertEqual(DriveCarPlayTiles.powerScaleKW(peak: 50), 50)
        XCTAssertEqual(DriveCarPlayTiles.powerScaleKW(peak: 51), 100)
        XCTAssertEqual(DriveCarPlayTiles.powerScaleKW(peak: -10), 50)
    }

    func testRegenFlowTile() {
        var input = boltDriving()
        input.flow = .regen
        let tile = DriveCarPlayTiles.flow(input)
        XCTAssertEqual(tile.value, "REGEN")
        XCTAssertEqual(tile.tone, .regen)
        XCTAssertEqual(tile.symbol, "arrow.triangle.2.circlepath")
        input.flow = .idle
        XCTAssertEqual(DriveCarPlayTiles.flow(input).value, "IDLE")
        XCTAssertEqual(DriveCarPlayTiles.flow(input).tone, .muted)
    }

    func testMissingReadingsShowDashAndNoGauge() {
        let tiles = DriveCarPlayTiles.make(DriveCarPlayTileInputs(layout: .ev), units: us)
        XCTAssertEqual(tiles.count, 8)
        for tile in tiles {
            XCTAssertEqual(tile.value, "—", "\(tile.kind)")
            XCTAssertNil(tile.gauge, "\(tile.kind)")
            XCTAssertEqual(tile.tone, .muted, "\(tile.kind)")
            XCTAssertTrue(tile.unit.isEmpty, "\(tile.kind)")
        }
        let range = tiles.first { $0.kind == .range }
        XCTAssertEqual(range?.note, "Set pack and Wh/mi")
        XCTAssertEqual(tiles.first { $0.kind == .speed }?.spoken, "Speed, not read")
    }

    func testNonFiniteReadingsAreTreatedAsMissing() {
        var input = boltDriving()
        input.socPercent = .nan
        input.powerKW = .infinity
        input.speedKph = -5
        XCTAssertNil(DriveCarPlayTiles.charge(input).gauge)
        XCTAssertNil(DriveCarPlayTiles.power(input, units: us).gauge)
        XCTAssertNil(DriveCarPlayTiles.speed(input, units: us).gauge)
    }

    func testLowChargeIsCaution() {
        var input = boltDriving()
        input.socPercent = 9
        XCTAssertEqual(DriveCarPlayTiles.charge(input).tone, .caution)
        input.socPercent = 140
        XCTAssertEqual(DriveCarPlayTiles.charge(input).gauge, .ring(fraction: 1))
    }

    func testPackBandsFollowBU410() {
        var input = boltDriving()
        input.packTempC = -5
        XCTAssertEqual(DriveCarPlayTiles.packTemp(input, units: us).tone, .cold)
        input.packTempC = 50
        XCTAssertEqual(DriveCarPlayTiles.packTemp(input, units: us).tone, .caution)
        input.packTempC = 65
        let hot = DriveCarPlayTiles.packTemp(input, units: us)
        XCTAssertEqual(hot.tone, .critical)
        XCTAssertEqual(hot.gauge, .bar(fraction: 1))
        input.packTempC = 20
        XCTAssertEqual(DriveCarPlayTiles.packTemp(input, units: us).gauge, .bar(fraction: 0.5))
    }

    func testPowertrainLayout() {
        let input = DriveCarPlayTileInputs(
            layout: .powertrain, speedKph: 88.5, speedSource: "GPS", rpm: 2_430,
            coolantC: 91, fuelPercent: 63, moduleVolts: 14.3, ambientC: 9
        )
        let tiles = DriveCarPlayTiles.make(input, units: us)
        XCTAssertEqual(tiles.map(\.kind), [.speed, .rpm, .coolant, .fuel, .moduleVolts, .ambient])
        XCTAssertEqual(tiles[0].note, "GPS")
        XCTAssertEqual(tiles[1].value, "2430")
        XCTAssertEqual(tiles[1].gauge, .arc(fraction: 2_430.0 / 8_000.0))
        // Coolant has no cited limit: icon and number, accent only.
        XCTAssertEqual(tiles[2].gauge, .symbol)
        XCTAssertEqual(tiles[2].value, "196")
        XCTAssertEqual(tiles[3].gauge, .bar(fraction: 0.63))
        XCTAssertEqual(tiles[4].value, "14.3")
        XCTAssertEqual(tiles[4].tone, .accent)
        XCTAssertEqual(tiles[5].value, "48")
    }

    func testStandardEVLayout() {
        let input = DriveCarPlayTileInputs(layout: .evStandard, speedKph: 50, moduleVolts: 11.8, ambientC: 9)
        let tiles = DriveCarPlayTiles.make(input, units: us)
        XCTAssertEqual(tiles.map(\.kind), [.speed, .moduleVolts, .ambient])
        XCTAssertEqual(tiles[1].tone, .critical)
        if case let .bar(fraction)? = tiles[1].gauge {
            XCTAssertEqual(fraction, 0.2, accuracy: 1e-9)
        } else {
            XCTFail("12 V gauge should be a bar")
        }
    }

    func testSpokenText() {
        let tiles = DriveCarPlayTiles.make(boltDriving(), units: us)
        XCTAssertEqual(tiles[0].spoken, "Charge 65 %")
        XCTAssertEqual(tiles[1].spoken, "Power 15 hp est.")
        XCTAssertEqual(tiles[2].spoken, "Regen DRIVE")
    }

    func testHeadline() {
        XCTAssertEqual(DriveCarPlayTiles.headline(flow: .regen, link: "Live · Bolt EUV"), "REGEN · Live · Bolt EUV")
        XCTAssertEqual(DriveCarPlayTiles.headline(flow: nil, link: "Not connected"), "Not connected")
    }

    func testDetailReadoutsForBoltInUSUnits() {
        var input = boltDriving()
        input.hvCurrentAmps = 32
        input.torqueNm = 271.16
        input.tripKm = 16.0934
        input.avgSpeedKph = 48.28
        input.maxSpeedKph = 112.65
        input.regenKWh = 0.84
        input.netKWh = 3.26
        input.regenScore = 0.62
        input.motorTempC = 41
        input.ambientC = 9
        let tiles = Dictionary(uniqueKeysWithValues: DriveCarPlayTiles.make(input, units: us).map { ($0.kind, $0) })
        func lines(_ kind: DriveCarPlayTile.Kind) -> [String] {
            tiles[kind]?.readouts.map { "\($0.label) \($0.value)" } ?? []
        }
        // 42 kW peak = 56 hp; 271 N·m = 200 lb-ft.
        XCTAssertEqual(lines(.power), ["PEAK 56 hp", "TORQUE 200 lb-ft", "HV AMPS 32 A"])
        XCTAssertEqual(lines(.charge), ["RANGE 167 mi", "PACK 84 °F", "NET USED 3.3 kWh"])
        XCTAssertEqual(lines(.flow), ["REGEN SCORE 62 %", "RECOVERED 0.8 kWh", "HV AMPS 32 A"])
        XCTAssertEqual(lines(.speed), ["AVG 30 mph", "TOP 70 mph", "TRIP 10.0 mi"])
        XCTAssertEqual(lines(.range), ["CHARGE 65 %", "WEATHER 140 mi", "EFFICIENCY 290 Wh/mi"])
        XCTAssertEqual(lines(.packTemp), ["MOTOR 106 °F", "OUTSIDE 48 °F", "CHARGE 65 %"])
    }

    func testDetailReadoutsShowDashWhenNotRead() {
        let tiles = DriveCarPlayTiles.make(DriveCarPlayTileInputs(layout: .ev), units: us)
        for tile in tiles {
            XCTAssertEqual(tile.readouts.count, 3, "\(tile.kind)")
            for readout in tile.readouts {
                XCTAssertEqual(readout.value, "—", "\(tile.kind) \(readout.label)")
            }
            // No gauge, no end labels.
            XCTAssertNil(tile.scaleLabels, "\(tile.kind)")
        }
    }

    func testDetailReadoutsMetric() {
        var input = boltDriving()
        input.tripKm = 16.0934
        input.torqueNm = 271.16
        let tiles = Dictionary(uniqueKeysWithValues: DriveCarPlayTiles.make(input, units: metric).map { ($0.kind, $0) })
        XCTAssertEqual(tiles[.speed]?.readouts.last?.value, "16.1 km")
        XCTAssertEqual(tiles[.power]?.readouts[1].value, "271 Nm")
        XCTAssertEqual(tiles[.range]?.readouts.last?.value, "180 Wh/km")
    }

    func testScaleLabels() {
        let tiles = Dictionary(uniqueKeysWithValues: DriveCarPlayTiles.make(boltDriving(), units: us).map { ($0.kind, $0) })
        XCTAssertEqual(tiles[.charge]?.scaleLabels, .init(low: "E", high: "F"))
        XCTAssertEqual(tiles[.power]?.scaleLabels, .init(low: "REGEN", high: "DRIVE"))
        // 160 km/h scale = 99 mph.
        XCTAssertEqual(tiles[.speed]?.scaleLabels, .init(low: "0", high: "99"))
        XCTAssertEqual(tiles[.packTemp]?.scaleLabels, .init(low: "COLD", high: "HOT"))
        // Symbol tiles have no scale.
        XCTAssertNil(tiles[.range]?.scaleLabels)
        XCTAssertNil(tiles[.flow]?.scaleLabels)
    }

    func testPlanningDefaultsFillRangeForBolt() {
        let none = PlanningInputs(usableKWh: nil, whPerMile: nil)
        let euv = DrivePlanning.effective(typed: none, profile: .boltEUV, measuredWhPerMile: nil)
        XCTAssertEqual(euv.inputs, PlanningInputs(usableKWh: 65, whPerMile: 263))
        XCTAssertTrue(euv.usesDefaults)
        // 87.8 % of 65 kWh at 263 Wh/mi ≈ 217 mi.
        let miles = DrivePlanning.rangeMiles(socPercent: 87.8, usableKWh: 65, whPerMile: 263)
        XCTAssertEqual(miles ?? 0, 217, accuracy: 0.5)

        // A measured Wh/mi replaces the EPA figure; the pack size is still a default.
        let measured = DrivePlanning.effective(typed: none, profile: .boltEUV, measuredWhPerMile: 300)
        XCTAssertEqual(measured.inputs.whPerMile, 300)
        XCTAssertTrue(measured.usesDefaults)

        // Typed values win and are not defaults.
        let typed = DrivePlanning.effective(typed: PlanningInputs(usableKWh: 60, whPerMile: 280), profile: .boltEV, measuredWhPerMile: 300)
        XCTAssertEqual(typed.inputs, PlanningInputs(usableKWh: 60, whPerMile: 280))
        XCTAssertFalse(typed.usesDefaults)

        // No published figures for generic profiles; nonsense measurements are ignored.
        let generic = DrivePlanning.effective(typed: none, profile: .generic, measuredWhPerMile: .nan)
        XCTAssertNil(generic.inputs.usableKWh)
        XCTAssertNil(generic.inputs.whPerMile)
        XCTAssertFalse(generic.usesDefaults)
    }

    func testDefaultRangeIsMarkedEstimate() {
        var input = boltDriving()
        input.planningUsesDefaults = true
        let range = DriveCarPlayTiles.range(input, units: us)
        XCTAssertEqual(range.note, "EPA default")
        XCTAssertTrue(range.isEstimate)
        XCTAssertEqual(range.tone, .estimated)
    }

    func testReadingsListCoversEverything() {
        var input = boltDriving()
        input.hvCurrentAmps = 32
        input.tripKm = 16.0934
        let sections = DriveCarPlayReadings.make(input, units: us, link: "Live · Bolt EUV")
        XCTAssertEqual(sections.map(\.header), ["Battery", "Range and energy", "Drive", "Outside and link"])
        let rows = sections.flatMap(\.rows)
        XCTAssertEqual(rows.count, 21)
        let byTitle = Dictionary(rows.map { ($0.title, $0) }, uniquingKeysWith: { first, _ in first })
        XCTAssertEqual(byTitle["Charge"]?.value, "65 %")
        XCTAssertEqual(byTitle["Power"]?.value, "15 hp")
        XCTAssertEqual(byTitle["Power"]?.detail, "est.")
        XCTAssertEqual(byTitle["HV current"]?.value, "32 A")
        XCTAssertEqual(byTitle["Trip"]?.value, "10.0 mi")
        XCTAssertEqual(byTitle["Link"]?.value, "Live · Bolt EUV")
        // Not read rows keep their place with a dash.
        XCTAssertEqual(byTitle["Motor temp"]?.value, "—")
        XCTAssertEqual(byTitle["Motor temp"]?.detail, "Not read")

        let gas = DriveCarPlayReadings.make(
            DriveCarPlayTileInputs(layout: .powertrain, speedKph: 50, rpm: 2_000),
            units: us, link: "Live · Generic OBD"
        )
        XCTAssertEqual(gas.map(\.header), ["Car", "Trip", "Link"])
        XCTAssertEqual(gas[0].rows.map(\.title), ["Speed", "RPM", "Coolant", "Fuel", "12 V", "Outside"])
    }

    func testTilesAreEquatableForChangeDetection() {
        let a = DriveCarPlayTiles.make(boltDriving(), units: us)
        let b = DriveCarPlayTiles.make(boltDriving(), units: us)
        XCTAssertEqual(a, b)
        var input = boltDriving()
        input.speedKph = 100
        XCTAssertNotEqual(a, DriveCarPlayTiles.make(input, units: us))
    }
}
