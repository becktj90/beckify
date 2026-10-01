import XCTest
@testable import BeckifyMath

final class PlotSamplingTests: XCTestCase {
    func testRCChargeReaches63PercentAtOneTau() {
        let points = PlotSampling.rcCharge(tau: 1, finalValue: 10, throughMultiplesOfTau: 5, samples: 51)
        XCTAssertFalse(points.isEmpty)
        // Find sample nearest t = τ
        let nearest = points.min(by: { abs($0.x - 1) < abs($1.x - 1) })!
        XCTAssertEqual(nearest.y, 10 * (1 - exp(-1)), accuracy: 0.05)
        XCTAssertEqual(points.first?.y ?? -1, 0, accuracy: 1e-9)
        XCTAssertGreaterThan(points.last?.y ?? 0, 9.9)
    }

    func testRCDischargeMirrorsChargeComplement() {
        let charge = PlotSampling.rcCharge(tau: 0.2, finalValue: 5, samples: 21)
        let discharge = PlotSampling.rcDischarge(tau: 0.2, initialValue: 5, samples: 21)
        XCTAssertEqual(charge.count, discharge.count)
        for (c, d) in zip(charge, discharge) {
            XCTAssertEqual(c.x, d.x, accuracy: 1e-12)
            XCTAssertEqual(c.y + d.y, 5, accuracy: 1e-9)
        }
    }

    func testSineWaveZeroCrossings() {
        let points = PlotSampling.sineWave(frequencyHz: 50, cycles: 1, amplitude: 1, samples: 101)
        XCTAssertEqual(points.first?.y ?? 1, 0, accuracy: 1e-9)
        XCTAssertEqual(points.last?.x ?? 0, 0.02, accuracy: 1e-9)
    }

    func testSeriesImpedanceMinimumNearResonance() {
        let L = 0.1
        let C = 100e-6
        let f0 = 1 / (2 * Double.pi * (L * C).squareRoot())
        let points = PlotSampling.seriesImpedanceMagnitude(
            resistance: 10,
            inductance: L,
            capacitance: C,
            fMin: f0 / 10,
            fMax: f0 * 10,
            samples: 97
        )
        let minZ = points.min(by: { $0.y < $1.y })!
        XCTAssertEqual(minZ.x, f0, accuracy: f0 * 0.08)
        XCTAssertEqual(minZ.y, 10, accuracy: 0.5)
    }

    func testMonostableTripsNearTwoThirdsVcc() {
        let pw = 0.001
        let points = PlotSampling.monostableCapVoltage(pulseWidth: pw, vcc: 5, samples: 81)
        let atTrip = points.min(by: { abs($0.x - pw) < abs($1.x - pw) })!
        XCTAssertEqual(atTrip.y, 5 * 2 / 3, accuracy: 0.05)
    }

    func testInvalidInputsYieldEmpty() {
        XCTAssertTrue(PlotSampling.rcCharge(tau: 0).isEmpty)
        XCTAssertTrue(PlotSampling.rcCharge(tau: 1, throughMultiplesOfTau: .nan).isEmpty)
        XCTAssertTrue(PlotSampling.rcCharge(tau: 1, throughMultiplesOfTau: .infinity).isEmpty)
        XCTAssertTrue(PlotSampling.rcDischarge(tau: 1, throughMultiplesOfTau: .nan).isEmpty)
        XCTAssertTrue(PlotSampling.sineWave(frequencyHz: -1).isEmpty)
        XCTAssertTrue(PlotSampling.sineWave(frequencyHz: 60, cycles: .infinity).isEmpty)
        XCTAssertTrue(PlotSampling.sineWave(frequencyHz: 60, cycles: .nan).isEmpty)
        XCTAssertTrue(PlotSampling.ohmsLoadLine(voltage: .nan, current: 1).isEmpty)
        XCTAssertTrue(PlotSampling.seriesImpedanceMagnitude(
            resistance: 10, inductance: 0.1, capacitance: 1e-6,
            fMin: 1, fMax: .infinity
        ).isEmpty)
        let reactance = PlotSampling.reactanceVsFrequency(
            inductance: 0.1, capacitance: 1e-6, fMin: .nan, fMax: 1e3
        )
        XCTAssertTrue(reactance.xl.isEmpty)
        XCTAssertTrue(reactance.xc.isEmpty)
        XCTAssertNil(PlotSampling.seriesHalfPowerBand(resonantFrequency: 50, bandwidth: .nan))
        XCTAssertNil(PlotSampling.seriesHalfPowerBand(resonantFrequency: 0, bandwidth: 10))
    }

    func testReactanceSweepDrawsThePartThatExists() {
        let both = PlotSampling.reactanceVsFrequency(
            inductance: 0.1, capacitance: 100e-6, fMin: 10, fMax: 1000, samples: 41
        )
        XCTAssertEqual(both.xl.count, 41)
        XCTAssertEqual(both.xc.count, 41)
        XCTAssertLessThan(both.xl.first?.y ?? 1, both.xl.last?.y ?? 0)
        XCTAssertGreaterThan(both.xc.first?.y ?? 0, both.xc.last?.y ?? 1)

        let inductorOnly = PlotSampling.reactanceVsFrequency(
            inductance: 0.1, capacitance: 0, fMin: 10, fMax: 1000, samples: 21
        )
        XCTAssertEqual(inductorOnly.xl.count, 21)
        XCTAssertTrue(inductorOnly.xc.isEmpty)
        XCTAssertEqual(inductorOnly.xl.first?.y ?? 0, 2 * .pi * 10 * 0.1, accuracy: 1e-9)

        let capacitorOnly = PlotSampling.reactanceVsFrequency(
            inductance: 0, capacitance: 100e-6, fMin: 10, fMax: 1000, samples: 21
        )
        XCTAssertTrue(capacitorOnly.xl.isEmpty)
        XCTAssertEqual(capacitorOnly.xc.count, 21)
        XCTAssertEqual(capacitorOnly.xc.last?.y ?? 0, 1 / (2 * .pi * 1000 * 100e-6), accuracy: 1e-6)

        let neither = PlotSampling.reactanceVsFrequency(
            inductance: 0, capacitance: 0, fMin: 10, fMax: 1000
        )
        XCTAssertTrue(neither.xl.isEmpty)
        XCTAssertTrue(neither.xc.isEmpty)
    }

    func testSeriesMarkerFollowsEnteredFrequency() {
        let at60 = ReactancePlotReadout.seriesMarker(hertz: 60, inductance: 0.1, capacitance: 100e-6)
        XCTAssertEqual(at60?.hertz ?? 0, 60, accuracy: 1e-12)
        XCTAssertEqual(at60?.inductiveOhms ?? 0, 2 * .pi * 60 * 0.1, accuracy: 1e-9)
        XCTAssertEqual(at60?.capacitiveOhms ?? 0, 1 / (2 * .pi * 60 * 100e-6), accuracy: 1e-9)

        let at120 = ReactancePlotReadout.seriesMarker(hertz: 120, inductance: 0.1, capacitance: 100e-6)
        XCTAssertEqual(at120?.hertz ?? 0, 120, accuracy: 1e-12)
        XCTAssertNotEqual(at60?.inductiveOhms ?? 0, at120?.inductiveOhms ?? 0)
        XCTAssertGreaterThan(at120?.inductiveOhms ?? 0, at60?.inductiveOhms ?? 0)
        XCTAssertLessThan(at120?.capacitiveOhms ?? 1, at60?.capacitiveOhms ?? 0)

        let inductorOnly = ReactancePlotReadout.seriesMarker(hertz: 60, inductance: 0.1, capacitance: 0)
        XCTAssertNotNil(inductorOnly?.inductiveOhms)
        XCTAssertNil(inductorOnly?.capacitiveOhms)
        let capacitorOnly = ReactancePlotReadout.seriesMarker(hertz: 60, inductance: 0, capacitance: 100e-6)
        XCTAssertNil(capacitorOnly?.inductiveOhms)
        XCTAssertNotNil(capacitorOnly?.capacitiveOhms)
        XCTAssertNil(ReactancePlotReadout.seriesMarker(hertz: 0, inductance: 0.1, capacitance: 100e-6))
        XCTAssertNil(ReactancePlotReadout.seriesMarker(hertz: 60, inductance: 0, capacitance: 0))
    }

    func testSeriesAnnouncementLeadsWithFrequencyAndOhms() {
        let both = ReactancePlotReadout.seriesMarker(hertz: 60, inductance: 0.1, capacitance: 100e-6)!
        let spoken = ReactancePlotReadout.seriesAnnouncement(both)
        XCTAssertEqual(spoken, "60 Hz, 37.699 Ω XL, 26.526 Ω XC. Ideal lumped parts.")
        XCTAssertTrue(spoken.first?.isNumber == true)

        let inductorOnly = ReactancePlotReadout.seriesMarker(hertz: 60, inductance: 0.1, capacitance: 0)!
        XCTAssertEqual(
            ReactancePlotReadout.seriesAnnouncement(inductorOnly),
            "60 Hz, 37.699 Ω XL. Ideal lumped parts."
        )
        let capacitorOnly = ReactancePlotReadout.seriesMarker(hertz: 60, inductance: 0, capacitance: 100e-6)!
        XCTAssertEqual(
            ReactancePlotReadout.seriesAnnouncement(capacitorOnly),
            "60 Hz, 26.526 Ω XC. Ideal lumped parts."
        )
    }

    func testResonanceMarksF0AndBandwidthOnlyWhenRIsPresent() {
        let f0 = 1 / (2 * .pi * (0.1 * 100e-6).squareRoot())
        let q = (1 / 10) * (0.1 / 100e-6).squareRoot()
        let bandwidth = f0 / q
        let band = PlotSampling.seriesHalfPowerBand(resonantFrequency: f0, bandwidth: bandwidth)
        XCTAssertEqual((band?.high ?? 0) - (band?.low ?? 0), bandwidth, accuracy: 1e-9)
        XCTAssertLessThan(band?.low ?? 0, f0)
        XCTAssertGreaterThan(band?.high ?? 0, f0)

        let marked = ReactancePlotReadout.resonanceMarker(
            resonantHertz: f0,
            resistance: 10,
            bandwidth: bandwidth
        )
        XCTAssertEqual(marked?.impedanceOhms ?? 0, 10, accuracy: 1e-12)
        XCTAssertEqual(marked?.bandwidthHertz ?? 0, bandwidth, accuracy: 1e-9)
        XCTAssertEqual(marked?.lowHertz ?? 0, band?.low ?? -1, accuracy: 1e-9)
        let spoken = ReactancePlotReadout.resonanceAnnouncement(marked!)
        XCTAssertTrue(spoken.hasPrefix("50.3292 Hz, 10 Ω |Z|"))
        XCTAssertTrue(spoken.contains("bandwidth"))
        XCTAssertTrue(spoken.hasSuffix("Ideal lumped parts."))
        XCTAssertTrue(spoken.first?.isNumber == true)

        let openR = ReactancePlotReadout.resonanceMarker(
            resonantHertz: f0,
            resistance: 0,
            bandwidth: .nan
        )
        XCTAssertEqual(openR?.impedanceOhms ?? -1, 0, accuracy: 1e-12)
        XCTAssertNil(openR?.bandwidthHertz)
        XCTAssertNil(openR?.lowHertz)
        XCTAssertEqual(
            ReactancePlotReadout.resonanceAnnouncement(openR!),
            "50.3292 Hz, 0 Ω |Z|. Ideal lumped parts."
        )
    }
}
