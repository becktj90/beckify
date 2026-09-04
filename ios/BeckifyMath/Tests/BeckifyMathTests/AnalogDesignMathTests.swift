import XCTest
@testable import BeckifyMath

final class PreferredSeriesTests: XCTestCase {
    func testE24NearestMatchesLEDHelper() {
        XCTAssertEqual(PreferredSeries.nearest(310), LEDResistor.nearestE24(310), accuracy: 1e-9)
        XCTAssertEqual(PreferredSeries.nearest(960), 1000, accuracy: 1e-9)
    }

    func testE96Nearest() {
        XCTAssertEqual(PreferredSeries.nearest(1000, series: .e96), 1000, accuracy: 1e-9)
        XCTAssertEqual(PreferredSeries.nearest(1024, series: .e96), 1020, accuracy: 1e-9)
    }
}

final class OpAmpGoldenTests: XCTestCase {
    func testInvertingGain() throws {
        let r = try OpAmpGolden.inverting(vin: 1, rin: 10_000, rf: 47_000, nearestE24: true)
        XCTAssertEqual(r.gainVV, -4.7, accuracy: 1e-9)
        XCTAssertEqual(r.outputVolts, -4.7, accuracy: 1e-9)
        XCTAssertEqual(r.resistorPicks.count, 2)
    }

    func testNoninvertingAndFollower() throws {
        let n = try OpAmpGolden.noninverting(vin: 2, rg: 10_000, rf: 10_000, nearestE24: false)
        XCTAssertEqual(n.gainVV, 2, accuracy: 1e-9)
        XCTAssertEqual(n.outputVolts, 4, accuracy: 1e-9)

        let f = try OpAmpGolden.follower(vin: 3.3)
        XCTAssertEqual(f.gainVV, 1, accuracy: 1e-12)
        XCTAssertEqual(f.outputVolts, 3.3, accuracy: 1e-12)
    }

    func testIntegratorUnityGainFrequency() throws {
        let r = try OpAmpGolden.integrator(vin: 1, rin: 10_000, capacitance: 100e-9, nearestE24: false)
        XCTAssertEqual(r.timeConstantSeconds ?? 0, 0.001, accuracy: 1e-12)
        XCTAssertEqual(r.slopeVoltsPerSecond ?? 0, -1000, accuracy: 1e-6)
        let expectedF = 1 / (2 * Double.pi * 0.001)
        XCTAssertEqual(r.unityGainHz ?? 0, expectedF, accuracy: 1e-6)
    }
}

final class AnalogFilterTests: XCTestCase {
    func testRCCorner() throws {
        let fc = try AnalogFilter.cornerHz(resistance: 10_000, capacitance: 15.915494309189533e-9)
        XCTAssertEqual(fc, 1000, accuracy: 0.01)
    }

    func testSallenKeyButterworthKAndFc() throws {
        XCTAssertEqual(AnalogFilter.butterworthQ, 1 / sqrt(2), accuracy: 1e-12)
        XCTAssertEqual(AnalogFilter.butterworthSallenKeyK, 3 - sqrt(2), accuracy: 1e-12)
        XCTAssertEqual(try AnalogFilter.sallenKeyK(q: AnalogFilter.butterworthQ), AnalogFilter.butterworthSallenKeyK, accuracy: 1e-12)
        XCTAssertEqual(try AnalogFilter.sallenKeyQ(k: AnalogFilter.butterworthSallenKeyK), AnalogFilter.butterworthQ, accuracy: 1e-12)

        let c = try AnalogFilter.capacitanceForCorner(resistance: 10_000, frequency: 1_000)
        let result = try AnalogFilter.solve(
            family: .sallenKeyLowpass,
            designFrequency: 1_000,
            resistance: 10_000,
            capacitance: c,
            passbandGain: 1,
            quality: AnalogFilter.butterworthQ
        )
        XCTAssertEqual(result.cornerHz, 1000, accuracy: 1e-6)
        XCTAssertEqual(result.qualityFactor, AnalogFilter.butterworthQ, accuracy: 1e-9)
        XCTAssertEqual(result.sallenKeyK ?? 0, AnalogFilter.butterworthSallenKeyK, accuracy: 1e-9)

        let magAtFc = AnalogFilter.magnitude(
            family: .sallenKeyLowpass,
            frequency: 1_000,
            cornerHz: result.cornerHz,
            q: result.qualityFactor,
            gain: 1
        )
        // 2nd-order Butterworth |H(f0)| = 1/√2 (−3 dB).
        XCTAssertEqual(magAtFc, AnalogFilter.butterworthQ, accuracy: 1e-6)
        XCTAssertFalse(result.bode.isEmpty)
        XCTAssertGreaterThan(result.bode.last?.x ?? 0, result.bode.first?.x ?? 1)
    }

    func testRCLowpassMinus3dB() {
        let mag = AnalogFilter.magnitude(family: .rcLowpass, frequency: 1000, cornerHz: 1000, q: 0.5, gain: 1)
        XCTAssertEqual(mag, AnalogFilter.butterworthQ, accuracy: 1e-9)
    }

    func testAllpassIsFlat() {
        let low = AnalogFilter.magnitude(family: .firstOrderAllpass, frequency: 10, cornerHz: 1000, q: 0.5, gain: 2)
        let high = AnalogFilter.magnitude(family: .firstOrderAllpass, frequency: 100_000, cornerHz: 1000, q: 0.5, gain: 2)
        XCTAssertEqual(low, 2, accuracy: 1e-12)
        XCTAssertEqual(high, 2, accuracy: 1e-12)
    }

    func testUnstableSallenKeyKThrows() {
        XCTAssertThrowsError(try AnalogFilter.sallenKeyQ(k: 3))
        XCTAssertThrowsError(try AnalogFilter.sallenKeyQ(k: 3.2))
    }

    func testFirstOrderSolveIgnoresMissingQ() throws {
        let rc = try AnalogFilter.solve(
            family: .rcLowpass,
            designFrequency: 1_000,
            resistance: 10_000,
            capacitance: 15.915494309189533e-9,
            passbandGain: 1,
            quality: .nan
        )
        XCTAssertEqual(rc.qualityFactor, 0.5, accuracy: 1e-12)
        XCTAssertEqual(rc.cornerHz, 1000, accuracy: 0.01)

        let allpass = try AnalogFilter.solve(
            family: .firstOrderAllpass,
            designFrequency: 1_000,
            resistance: 10_000,
            capacitance: 15.915494309189533e-9,
            passbandGain: 2,
            quality: .nan
        )
        XCTAssertEqual(allpass.qualityFactor, 0.5, accuracy: 1e-12)
        XCTAssertEqual(allpass.passbandGainVV, 2, accuracy: 1e-12)
    }

    func testSecondOrderStillRequiresQ() {
        XCTAssertThrowsError(try AnalogFilter.solve(
            family: .sallenKeyLowpass,
            designFrequency: 1_000,
            resistance: 10_000,
            capacitance: 15.9e-9,
            passbandGain: 1,
            quality: .nan
        ))
        XCTAssertThrowsError(try AnalogFilter.solve(
            family: .twinTNotch,
            designFrequency: 1_000,
            resistance: 10_000,
            capacitance: 15.9e-9,
            passbandGain: 1,
            quality: .nan
        ))
    }
}

final class NoiseSNRTests: XCTestCase {
    func testJohnson10kAt290KAnd10kHz() throws {
        let vn = try NoiseSNR.johnsonVrms(resistance: 10_000, temperatureKelvin: 290, bandwidthHz: 10_000)
        let expected = sqrt(4 * NoiseSNR.boltzmann * 290 * 10_000 * 10_000)
        XCTAssertEqual(vn, expected, accuracy: 1e-18)
        XCTAssertEqual(vn, 1.265525e-6, accuracy: 1e-12)
    }

    func testShotAndTotal() throws {
        let result = try NoiseSNR.solve(
            resistance: 10_000,
            temperatureKelvin: 290,
            bandwidthHz: 10_000,
            ampEn: 5e-9,
            ampIn: 1e-12,
            shotCurrent: 1e-3,
            signalVrms: 1e-3
        )
        XCTAssertGreaterThan(result.totalReferredVrms, result.johnsonVrms)
        XCTAssertGreaterThan(result.shotIrms, 0)
        XCTAssertNotNil(result.snrDB)
        XCTAssertNotNil(result.noiseFigureDB)
        XCTAssertEqual(result.noiseBandwidthHz, 10_000, accuracy: 1e-12)
    }

    func testFirstOrderNoiseBandwidthFactor() throws {
        let b = try NoiseSNR.noiseBandwidth(hz3dB: 1000, factor: NoiseSNR.firstOrderNoiseBandwidthFactor)
        XCTAssertEqual(b, 1000 * .pi / 2, accuracy: 1e-9)
    }

    func testZeroResistanceLeavesNFUndefined() throws {
        let result = try NoiseSNR.solve(
            resistance: 0,
            temperatureKelvin: 290,
            bandwidthHz: 1000,
            ampEn: 1e-9,
            ampIn: 0,
            shotCurrent: nil,
            signalVrms: nil
        )
        XCTAssertNil(result.noiseFigureDB)
        XCTAssertEqual(result.ampVoltageVrms, 1e-9 * sqrt(1000), accuracy: 1e-18)
    }
}

final class LinearRegulatorTests: XCTestCase {
    func testLM317FiveVoltsFrom240And720() throws {
        let vo = try LinearRegulator.vout(vref: 1.25, r1: 240, r2: 720, iadj: 0)
        XCTAssertEqual(vo, 5, accuracy: 1e-12)
    }

    func testSolveR2ForTarget() throws {
        let r2 = try LinearRegulator.r2(forVout: 5, vref: 1.25, r1: 240, iadj: 0)
        XCTAssertEqual(r2, 720, accuracy: 1e-12)
    }

    func testThermalAndDropout() throws {
        let r = try LinearRegulator.solve(
            vin: 12,
            voutOrTarget: 5,
            r1: 240,
            r2: nil,
            vref: 1.25,
            iadj: 0,
            dropout: 2,
            loadCurrent: 0.5,
            ambientC: 25,
            thetaJA: 50,
            thetaJC: nil,
            thetaSA: nil,
            solveResistors: true
        )
        XCTAssertEqual(r.vout, 5, accuracy: 1e-9)
        XCTAssertEqual(r.r2, 720, accuracy: 1e-9)
        XCTAssertEqual(r.headroom, 7, accuracy: 1e-9)
        XCTAssertEqual(r.dropoutMargin, 5, accuracy: 1e-9)
        XCTAssertEqual(r.powerDissipation, 3.5, accuracy: 1e-9)
        XCTAssertEqual(r.junctionC, 25 + 3.5 * 50, accuracy: 1e-9)
        XCTAssertTrue(r.junctionHigh)
        XCTAssertEqual(r.r2NearestE24, 750, accuracy: 1e-9)
    }

    func testHeatsinkReplacesFreeAirTheta() throws {
        let r = try LinearRegulator.solve(
            vin: 12,
            voutOrTarget: 5,
            r1: 240,
            r2: 720,
            vref: 1.25,
            iadj: 0,
            dropout: 2,
            loadCurrent: 0.5,
            ambientC: 25,
            thetaJA: 50,
            thetaJC: 4,
            thetaSA: 6,
            solveResistors: false
        )
        XCTAssertEqual(r.thetaJAUsed, 10, accuracy: 1e-12)
        XCTAssertEqual(r.junctionC, 60, accuracy: 1e-9)
        XCTAssertFalse(r.junctionHigh)
    }

    func testInvalidHeatsinkThetaSAThrows() {
        XCTAssertThrowsError(try LinearRegulator.solve(
            vin: 12, voutOrTarget: 5, r1: 240, r2: 720, vref: 1.25, iadj: 0,
            dropout: 2, loadCurrent: 0.5, ambientC: 25, thetaJA: 50,
            thetaJC: 5, thetaSA: .nan, solveResistors: false
        ))
        XCTAssertThrowsError(try LinearRegulator.solve(
            vin: 12, voutOrTarget: 5, r1: 240, r2: 720, vref: 1.25, iadj: 0,
            dropout: 2, loadCurrent: 0.5, ambientC: 25, thetaJA: 50,
            thetaJC: 5, thetaSA: 0, solveResistors: false
        ))
    }

    func testInvalidThetaJCWithHeatsinkThrows() {
        XCTAssertThrowsError(try LinearRegulator.solve(
            vin: 12, voutOrTarget: 5, r1: 240, r2: 720, vref: 1.25, iadj: 0,
            dropout: 2, loadCurrent: 0.5, ambientC: 25, thetaJA: 50,
            thetaJC: .nan, thetaSA: 6, solveResistors: false
        ))
    }

    func testOmittedThetaJCUsesDefaultWhenHeatsinkPresent() throws {
        let r = try LinearRegulator.solve(
            vin: 12, voutOrTarget: 5, r1: 240, r2: 720, vref: 1.25, iadj: 0,
            dropout: 2, loadCurrent: 0.5, ambientC: 25, thetaJA: 50,
            thetaJC: nil, thetaSA: 6, solveResistors: false
        )
        XCTAssertEqual(r.thetaJAUsed, 11, accuracy: 1e-12)
    }
}

final class InstrumentationAmpTests: XCTestCase {
    func testClassicThreeOpAmpGain() throws {
        XCTAssertEqual(try InstrumentationAmp.threeOpAmpGain(r: 25_000, rg: 1_000), 51, accuracy: 1e-12)
        XCTAssertEqual(try InstrumentationAmp.threeOpAmpGain(r: 25_000, rg: 500), 101, accuracy: 1e-12)
    }

    func testDifferenceGainAndSwing() throws {
        let r = try InstrumentationAmp.solve(
            mode: .difference,
            v2: 2.1,
            v1: 2.0,
            r: 10_000,
            rg: 1_000,
            vref: 0,
            railPos: 5,
            railNeg: 0,
            cmMin: 0,
            cmMax: 4
        )
        XCTAssertEqual(r.gain, 10, accuracy: 1e-12)
        XCTAssertEqual(r.vout, 1.0, accuracy: 1e-12)
        XCTAssertEqual(r.differentialIn, 0.1, accuracy: 1e-12)
        XCTAssertEqual(r.commonMode, 2.05, accuracy: 1e-12)
        XCTAssertTrue(r.outputInSwing)
        XCTAssertTrue(r.inputCMInRange)
    }

    func testOutputClipFlag() throws {
        let r = try InstrumentationAmp.solve(
            mode: .threeOpAmp,
            v2: 1,
            v1: 0,
            r: 25_000,
            rg: 1_000,
            vref: 0,
            railPos: 5,
            railNeg: 0,
            cmMin: -10,
            cmMax: 10
        )
        XCTAssertEqual(r.vout, 51, accuracy: 1e-9)
        XCTAssertFalse(r.outputInSwing)
    }
}

final class SamplingConverterTests: XCTestCase {
    func testTwelveBitLSBAndIdealSNR() throws {
        XCTAssertEqual(try SamplingConverter.lsb(fullScale: 5, bits: 12), 5 / 4096, accuracy: 1e-15)
        XCTAssertEqual(try SamplingConverter.idealQuantizationSNR(bits: 12), 6.02 * 12 + 1.76, accuracy: 1e-12)
        XCTAssertEqual(try SamplingConverter.idealQuantizationSNR(bits: 16), 98.08, accuracy: 1e-12)
    }

    func testNyquistAndDAC() throws {
        let r = try SamplingConverter.solve(bits: 12, fullScale: 5, sampleRate: 1000, dacCode: 2048)
        XCTAssertEqual(r.codeCount, 4096)
        XCTAssertEqual(r.nyquistHz, 500, accuracy: 1e-12)
        XCTAssertEqual(r.suggestedAntiAliasHz, 400, accuracy: 1e-12)
        XCTAssertEqual(r.dacVoltage ?? 0, 2048 * (5 / 4096), accuracy: 1e-12)
    }

    func testCodeOutOfRangeThrows() {
        XCTAssertThrowsError(try SamplingConverter.dacVoltage(code: 4096, fullScale: 5, bits: 12))
        XCTAssertThrowsError(try SamplingConverter.solve(bits: 0, fullScale: 5, sampleRate: 1000, dacCode: nil))
    }
}
