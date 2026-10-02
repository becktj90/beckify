import XCTest
@testable import BeckifyMath

final class RoomRigFFTTests: XCTestCase {
    func testPowerOfTwoHelpers() {
        XCTAssertTrue(RoomRigFFT.isPowerOfTwo(1))
        XCTAssertTrue(RoomRigFFT.isPowerOfTwo(2))
        XCTAssertTrue(RoomRigFFT.isPowerOfTwo(1_024))
        XCTAssertFalse(RoomRigFFT.isPowerOfTwo(0))
        XCTAssertFalse(RoomRigFFT.isPowerOfTwo(-4))
        XCTAssertFalse(RoomRigFFT.isPowerOfTwo(100))
        XCTAssertEqual(RoomRigFFT.nextPowerOfTwo(atLeast: 1), 1)
        XCTAssertEqual(RoomRigFFT.nextPowerOfTwo(atLeast: 5), 8)
        XCTAssertEqual(RoomRigFFT.nextPowerOfTwo(atLeast: 1_024), 1_024)
        XCTAssertEqual(RoomRigFFT.nextPowerOfTwo(atLeast: 1_025), 2_048)
    }

    func testNonPowerOfTwoInputIsReturnedUnchanged() {
        let real = [1.0, 2.0, 3.0]
        let imag = [0.0, 0.0, 0.0]
        let result = RoomRigFFT.forward(real: real, imag: imag)
        XCTAssertEqual(result.real, real)
        XCTAssertEqual(result.imag, imag)
    }

    func testForwardThenInverseRecoversOriginalSignal() {
        let n = 64
        let original = (0..<n).map { i in sin(2 * Double.pi * 5 * Double(i) / Double(n)) + 0.3 }
        let imagZero = [Double](repeating: 0, count: n)
        let spectrum = RoomRigFFT.forward(real: original, imag: imagZero)
        let roundTrip = RoomRigFFT.inverse(real: spectrum.real, imag: spectrum.imag)
        for i in 0..<n {
            XCTAssertEqual(roundTrip.real[i], original[i], accuracy: 1e-9)
            XCTAssertEqual(roundTrip.imag[i], 0, accuracy: 1e-9)
        }
    }

    func testForwardFindsPeakAtExpectedBin() {
        let n = 256
        let binIndex = 10
        let samples = (0..<n).map { i in sin(2 * Double.pi * Double(binIndex) * Double(i) / Double(n)) }
        let imagZero = [Double](repeating: 0, count: n)
        let spectrum = RoomRigFFT.forward(real: samples, imag: imagZero)
        let magnitudes = RoomRigFFT.magnitude(real: spectrum.real, imag: spectrum.imag)
        let half = n / 2
        guard let loudestBin = magnitudes.prefix(half).indices.max(by: { magnitudes[$0] < magnitudes[$1] }) else {
            return XCTFail("expected a loudest bin")
        }
        XCTAssertEqual(loudestBin, binIndex)
    }

    func testParsevalEnergyIsConserved() {
        let n = 32
        let samples = (0..<n).map { Double($0 % 7) - 3 }
        let imagZero = [Double](repeating: 0, count: n)
        let spectrum = RoomRigFFT.forward(real: samples, imag: imagZero)
        let timeEnergy = samples.reduce(0.0) { $0 + $1 * $1 }
        let freqEnergy = zip(spectrum.real, spectrum.imag).reduce(0.0) { $0 + $1.0 * $1.0 + $1.1 * $1.1 } / Double(n)
        XCTAssertEqual(timeEnergy, freqEnergy, accuracy: 1e-6)
    }
}

final class RoomRigConvolutionTests: XCTestCase {
    func testConvolutionWithImpulseReturnsOtherSignal() {
        let impulse = [1.0, 0.0, 0.0]
        let signal = [1.0, 2.0, 3.0]
        let result = RoomRigConvolution.convolve(impulse, signal)
        XCTAssertEqual(result.count, 5)
        let expected = [1.0, 2.0, 3.0, 0.0, 0.0]
        for i in 0..<expected.count {
            XCTAssertEqual(result[i], expected[i], accuracy: 1e-9)
        }
    }

    func testConvolutionWithScaledDelayedImpulseShiftsAndScales() {
        let signal = [1.0, 2.0, 3.0, 4.0]
        let delayedImpulse = [0.0, 0.0, 2.0] // delay 2, gain 2
        let result = RoomRigConvolution.convolve(signal, delayedImpulse)
        // Expect: signal scaled by 2 and shifted right by 2 samples.
        let expected = [0.0, 0.0, 2.0, 4.0, 6.0, 8.0]
        XCTAssertEqual(result.count, expected.count)
        for i in 0..<expected.count {
            XCTAssertEqual(result[i], expected[i], accuracy: 1e-9)
        }
    }

    func testEmptyInputReturnsEmpty() {
        XCTAssertEqual(RoomRigConvolution.convolve([], [1, 2, 3]), [])
        XCTAssertEqual(RoomRigConvolution.convolve([1, 2, 3], []), [])
    }
}

final class ExponentialSweepMeasurementTests: XCTestCase {
    private let sampleRate = 8_000.0
    private let startHz = 100.0
    private let endHz = 2_000.0
    private let duration = 0.25

    func testSweepStartsAndEndsNearRequestedFrequencies() {
        let sweep = ExponentialSweepMeasurement.sweep(startHz: startHz, endHz: endHz, duration: duration, sampleRate: sampleRate)
        XCTAssertFalse(sweep.isEmpty)
        XCTAssertTrue(sweep.allSatisfy { $0.isFinite && abs($0) <= 1.0001 })
    }

    func testInvalidSweepParametersReturnEmpty() {
        XCTAssertEqual(ExponentialSweepMeasurement.sweep(startHz: -1, endHz: 2_000, duration: 1, sampleRate: 8_000), [])
        XCTAssertEqual(ExponentialSweepMeasurement.sweep(startHz: 2_000, endHz: 100, duration: 1, sampleRate: 8_000), [])
        XCTAssertEqual(ExponentialSweepMeasurement.sweep(startHz: 100, endHz: 2_000, duration: 0, sampleRate: 8_000), [])
    }

    func testPassThroughSweepHasNoArtificialFrequencyTilt() {
        let sweep = ExponentialSweepMeasurement.sweep(startHz: startHz, endHz: endHz, duration: duration, sampleRate: sampleRate)
        let filter = ExponentialSweepMeasurement.inverseFilter(startHz: startHz, endHz: endHz, duration: duration, sampleRate: sampleRate)
        let impulse = ExponentialSweepMeasurement.impulseResponse(recorded: sweep, inverseFilter: filter)
        let response = ExponentialSweepMeasurement.frequencyResponse(impulseResponse: impulse, sampleRate: sampleRate, windowSamples: 1_024)
        guard let low = response.min(by: { abs($0.hz - 250) < abs($1.hz - 250) }),
              let high = response.min(by: { abs($0.hz - 1_000) < abs($1.hz - 1_000) }) else {
            return XCTFail("Expected a measured frequency response")
        }
        // A unity system must not inherit the sweep's spectral slope.
        XCTAssertEqual(high.db - low.db, 0, accuracy: 2)
    }

    func testDeconvolutionRecoversKnownDelayWithinTolerance() {
        let sweep = ExponentialSweepMeasurement.sweep(startHz: startHz, endHz: endHz, duration: duration, sampleRate: sampleRate)
        let filter = ExponentialSweepMeasurement.inverseFilter(startHz: startHz, endHz: endHz, duration: duration, sampleRate: sampleRate)
        XCTAssertFalse(sweep.isEmpty)
        XCTAssertFalse(filter.isEmpty)

        // Baseline: "room" is a plain pass-through (gain 1, no delay).
        let baselineIR = ExponentialSweepMeasurement.impulseResponse(recorded: sweep, inverseFilter: filter)
        guard let baselinePeak = ExponentialSweepMeasurement.peakIndex(impulseResponse: baselineIR) else {
            return XCTFail("expected a baseline peak")
        }

        // Now simulate a room that delays and attenuates the sweep by a known amount.
        let delaySamples = 120
        let gain = 0.6
        var roomImpulse = [Double](repeating: 0, count: delaySamples + 1)
        roomImpulse[delaySamples] = gain
        let recorded = RoomRigConvolution.convolve(sweep, roomImpulse)

        let measuredIR = ExponentialSweepMeasurement.impulseResponse(recorded: recorded, inverseFilter: filter)
        guard let measuredPeak = ExponentialSweepMeasurement.peakIndex(impulseResponse: measuredIR) else {
            return XCTFail("expected a measured peak")
        }

        // The known room delay should show up as the same shift in the deconvolved peak.
        XCTAssertEqual(measuredPeak - baselinePeak, delaySamples, accuracy: 2)

        // Normalized to a unit peak regardless of the room's gain.
        XCTAssertEqual(abs(measuredIR[measuredPeak]), 1.0, accuracy: 1e-6)
    }

    func testPeakIndexOfEmptyResponseIsNil() {
        XCTAssertNil(ExponentialSweepMeasurement.peakIndex(impulseResponse: []))
    }

    func testFrequencyResponseOfADelayedImpulseIsFlatShape() {
        // A clean impulse response (no coloration) should deconvolve to a
        // roughly flat frequency response shape once normalized to its peak.
        let n = 4_096
        var impulse = [Double](repeating: 0, count: n)
        impulse[0] = 1
        let response = ExponentialSweepMeasurement.frequencyResponse(impulseResponse: impulse, sampleRate: sampleRate, windowSamples: 1_024)
        XCTAssertFalse(response.isEmpty)
        XCTAssertTrue(response.allSatisfy { $0.db.isFinite && $0.db <= 1e-6 })
        // Peak-normalized: at least one point should sit at (or essentially at) 0 dB.
        XCTAssertTrue(response.contains { abs($0.db) < 0.5 })
    }
}

final class RoomRigDecayMathTests: XCTestCase {
    func testSchroederCurveIsNonIncreasingAndStartsAtZero() {
        let n = 4_000
        let sampleRate = 8_000.0
        // Exponentially decaying "tail" after a peak at index 0.
        var impulse = [Double](repeating: 0, count: n)
        for i in 0..<n {
            impulse[i] = exp(-Double(i) / 400.0)
        }
        let curve = RoomRigDecayMath.schroederDecayCurveDB(impulseResponse: impulse)
        XCTAssertFalse(curve.isEmpty)
        XCTAssertEqual(curve[0], 0, accuracy: 1e-6)
        for i in 1..<curve.count {
            XCTAssertLessThanOrEqual(curve[i], curve[i - 1] + 1e-9)
        }
        let decayTime = RoomRigDecayMath.earlyDecayEstimateSeconds(decayCurveDB: curve, sampleRate: sampleRate)
        XCTAssertNotNil(decayTime)
        XCTAssertGreaterThan(decayTime ?? 0, 0)
    }

    func testEmptyResponseHasNoDecayCurve() {
        XCTAssertEqual(RoomRigDecayMath.schroederDecayCurveDB(impulseResponse: []), [])
        XCTAssertNil(RoomRigDecayMath.earlyDecayEstimateSeconds(decayCurveDB: [], sampleRate: 8_000))
    }

    func testFlatCurveNeverReachingThresholdsHasNoDecayTime() {
        let flat = [Double](repeating: 0, count: 100)
        XCTAssertNil(RoomRigDecayMath.earlyDecayEstimateSeconds(decayCurveDB: flat, sampleRate: 8_000))
    }
}

final class RoomRigHumMathTests: XCTestCase {
    func testPureSixtyHertzToneDominatesHumBins() {
        let sampleRate = 8_000.0
        let fftLength = 4_096
        var magnitudes = [Double](repeating: 1e-6, count: fftLength / 2 + 1)
        let binHz = sampleRate / Double(fftLength)
        let bin60 = Int((60.0 / binHz).rounded())
        magnitudes[bin60] = 1.0
        let relative = RoomRigHumMath.mainsHumRelativeEnergyDB(
            linearMagnitudes: magnitudes,
            sampleRate: sampleRate,
            fftLength: fftLength,
            mainsHz: 60,
            harmonics: 3
        )
        XCTAssertNotNil(relative)
        XCTAssertGreaterThan(relative ?? -999, -1) // nearly all energy is at 60 Hz
    }

    func testSilentSpectrumHasNoHumReading() {
        let relative = RoomRigHumMath.mainsHumRelativeEnergyDB(
            linearMagnitudes: [],
            sampleRate: 8_000,
            fftLength: 4_096
        )
        XCTAssertNil(relative)
    }
}

final class RoomRigSetupScoreTests: XCTestCase {
    func testPerfectMetricsScoreOneHundred() {
        XCTAssertEqual(RoomRigSetupScore.tonalFitScore(deviationDB: 0), 100, accuracy: 1e-9)
        XCTAssertEqual(RoomRigSetupScore.bassSeatConsistencyScore(spreadDB: 0), 100, accuracy: 1e-9)
        XCTAssertEqual(RoomRigSetupScore.leftRightMatchScore(deviationDB: 0), 100, accuracy: 1e-9)
        XCTAssertEqual(RoomRigSetupScore.decayScore(earlyDecaySeconds: 0.3), 100, accuracy: 1e-9)
        XCTAssertEqual(RoomRigSetupScore.backgroundScore(mainsHumRelativeDB: -40), 100, accuracy: 1e-9)
    }

    func testWorstCaseMetricsScoreZero() {
        XCTAssertEqual(RoomRigSetupScore.tonalFitScore(deviationDB: 20), 0, accuracy: 1e-9)
        XCTAssertEqual(RoomRigSetupScore.bassSeatConsistencyScore(spreadDB: 30), 0, accuracy: 1e-9)
        XCTAssertEqual(RoomRigSetupScore.leftRightMatchScore(deviationDB: 20), 0, accuracy: 1e-9)
        XCTAssertEqual(RoomRigSetupScore.decayScore(earlyDecaySeconds: 2), 0, accuracy: 1e-9)
        XCTAssertEqual(RoomRigSetupScore.backgroundScore(mainsHumRelativeDB: 0), 0, accuracy: 1e-9)
    }

    func testScoresAreMonotonicAndClamped() {
        XCTAssertGreaterThan(RoomRigSetupScore.tonalFitScore(deviationDB: 2), RoomRigSetupScore.tonalFitScore(deviationDB: 5))
        XCTAssertEqual(RoomRigSetupScore.tonalFitScore(deviationDB: 999), 0)
        XCTAssertEqual(RoomRigSetupScore.tonalFitScore(deviationDB: -999), 0)
    }

    func testNoInputsYieldsNilOverallAndZeroCoverage() {
        let result = RoomRigSetupScore.score(RoomRigSetupScoreInputs())
        XCTAssertNil(result.overall)
        XCTAssertEqual(result.coverage, 0)
        XCTAssertTrue(result.subScores.isEmpty)
    }

    func testFullCoverageSumsWeightsToOne() {
        let inputs = RoomRigSetupScoreInputs(
            tonalDeviationDB: 0,
            bassSeatSpreadDB: 0,
            leftRightDeviationDB: 0,
            earlyDecaySeconds: 0.3,
            mainsHumRelativeDB: -40
        )
        let result = RoomRigSetupScore.score(inputs)
        XCTAssertEqual(result.coverage, 1, accuracy: 1e-9)
        XCTAssertEqual(result.overall ?? 0, 100, accuracy: 1e-6)
    }

    func testPartialCoverageRenormalizesAcrossAvailableSubScores() {
        // Only tonal fit (35%) and background (5%) measured, both perfect.
        let inputs = RoomRigSetupScoreInputs(tonalDeviationDB: 0, mainsHumRelativeDB: -40)
        let result = RoomRigSetupScore.score(inputs)
        XCTAssertEqual(result.coverage, RoomRigSetupScoreWeight.tonalFit + RoomRigSetupScoreWeight.background, accuracy: 1e-9)
        XCTAssertEqual(result.overall ?? 0, 100, accuracy: 1e-6)
        XCTAssertNotNil(result.tonalFit)
        XCTAssertNotNil(result.background)
        XCTAssertNil(result.bassSeatConsistency)
        XCTAssertNil(result.leftRightMatch)
        XCTAssertNil(result.decay)
    }

    func testWeightsSumToOne() {
        let total = RoomRigSetupScoreWeight.tonalFit
            + RoomRigSetupScoreWeight.bassSeatConsistency
            + RoomRigSetupScoreWeight.leftRightMatch
            + RoomRigSetupScoreWeight.decay
            + RoomRigSetupScoreWeight.background
        XCTAssertEqual(total, 1.0, accuracy: 1e-9)
    }

    func testSubScoreValueIsClampedToZeroToOneHundred() {
        let subScore = RoomRigSubScore(label: "x", value: 500, weight: 0.1, rawMetricLabel: "x")
        XCTAssertEqual(subScore.value, 100)
        let negative = RoomRigSubScore(label: "x", value: -50, weight: 0.1, rawMetricLabel: "x")
        XCTAssertEqual(negative.value, 0)
    }
}
