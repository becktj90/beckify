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
    }
}
