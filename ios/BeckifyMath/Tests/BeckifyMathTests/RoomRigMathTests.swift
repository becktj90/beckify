import XCTest
@testable import BeckifyMath

final class RoomRigMathTests: XCTestCase {
    func testSweepIsGeometric() {
        XCTAssertEqual(RoomRigMath.sweepHz(elapsed: 0), RoomRigMath.sweepStartHz, accuracy: 0.01)
        XCTAssertEqual(
            RoomRigMath.sweepHz(elapsed: RoomRigMath.sweepDuration),
            RoomRigMath.sweepStartHz,
            accuracy: 0.01
        )
        let mid = RoomRigMath.sweepHz(elapsed: RoomRigMath.sweepDuration / 2)
        XCTAssertEqual(mid, sqrt(RoomRigMath.sweepStartHz * RoomRigMath.sweepEndHz), accuracy: 0.5)
        XCTAssertTrue(RoomRigMath.sweepHz(elapsed: -1).isFinite)
    }

    func testBurstEnvelopeIsARaisedCosine() {
        XCTAssertEqual(RoomRigMath.burstEnvelope(index: 0, length: 65), 0, accuracy: 1e-9)
        XCTAssertEqual(RoomRigMath.burstEnvelope(index: 64, length: 65), 0, accuracy: 1e-9)
        XCTAssertEqual(RoomRigMath.burstEnvelope(index: 32, length: 65), 1, accuracy: 1e-9)
        XCTAssertEqual(RoomRigMath.burstEnvelope(index: -1, length: 65), 0)
        XCTAssertEqual(RoomRigMath.burstEnvelope(index: 10, length: 1), 0)
    }

    func testSineCrestIsAboutThreeDecibels() {
        let samples = (0..<2000).map { index in
            sin(2 * Double.pi * Double(index) / 1000)
        }
        let crest = RoomRigMath.crestFactorDB(samples: samples)
        XCTAssertEqual(crest ?? .nan, 20 * log10(sqrt(2)), accuracy: 0.05)
    }

    func testSilentFrameHasNoCrest() {
        let stats = RoomRigMath.frameStats(samples: [0, 0, 0, .nan])
        XCTAssertNil(stats.crestDB)
        XCTAssertEqual(stats.clipFraction, 0)
        XCTAssertEqual(stats.rmsDBFS, SoundLevel.silenceFloorDBFS)
    }

    func testClipFractionCountsFullScaleSamples() {
        let samples = [1.0, -1.0, 0.2, 0.0]
        XCTAssertEqual(RoomRigMath.clipFraction(samples: samples), 0.5, accuracy: 1e-9)
        XCTAssertEqual(RoomRigMath.clipFraction(samples: []), 0)
    }

    func testFrameStatsMatchBreathFluteLevels() {
        let floats: [Float] = [0.1, -0.2, 0.05, 0.0, -0.15]
        let flute = BreathFluteMath.levelDBFS(samples: floats)
        let stats = RoomRigMath.frameStats(samples: floats.map(Double.init))
        XCTAssertEqual(stats.rmsDBFS, flute.rms, accuracy: 1e-6)
        XCTAssertEqual(stats.peakDBFS, flute.peak, accuracy: 1e-6)
    }

    func testPercentileAndRelativeRange() {
        let levels = Array(1...10).map(Double.init)
        XCTAssertEqual(RoomRigMath.percentile(levels, p: 0) ?? .nan, 1, accuracy: 1e-9)
        XCTAssertEqual(RoomRigMath.percentile(levels, p: 1) ?? .nan, 10, accuracy: 1e-9)
        XCTAssertNil(RoomRigMath.percentile([], p: 0.1))
        XCTAssertEqual(RoomRigMath.signalAboveFloorDB(levelDBFS: -20, floorDBFS: -50) ?? .nan, 30, accuracy: 1e-9)
        XCTAssertEqual(RoomRigMath.relativeDynamicRangeDB(peakDBFS: -6, floorDBFS: -60) ?? .nan, 54, accuracy: 1e-9)
        XCTAssertNil(RoomRigMath.signalAboveFloorDB(levelDBFS: .nan, floorDBFS: -40))
    }

    func testLatencyRejectsEarlyAndLateGaps() {
        XCTAssertEqual(RoomRigMath.latencySeconds(playedAt: 10, heardAt: 10.04) ?? .nan, 0.04, accuracy: 1e-9)
        XCTAssertEqual(RoomRigMath.latencySeconds(playedAt: 10, heardAt: 10) ?? .nan, 0, accuracy: 1e-9)
        XCTAssertNil(RoomRigMath.latencySeconds(playedAt: 10, heardAt: 9.9))
        XCTAssertNil(RoomRigMath.latencySeconds(playedAt: 0, heardAt: 2))
        XCTAssertNil(RoomRigMath.latencySeconds(playedAt: .nan, heardAt: 1))
    }

    func testOnsetIndex() {
        XCTAssertEqual(RoomRigMath.onsetIndex(samples: [0, 0.01, -0.2], threshold: 0.1), 2)
        XCTAssertNil(RoomRigMath.onsetIndex(samples: [0, 0.01], threshold: 0.1))
    }

    func testThirdOctavePeaksOnTheToneBin() {
        let fftLength = 1024
        let sampleRate = 48_000.0
        var magnitudes = Array(repeating: 0.0, count: fftLength / 2)
        let bin = Int((1_000 / (sampleRate / Double(fftLength))).rounded())
        magnitudes[bin] = 40
        let bands = RoomRigMath.thirdOctaveBands(
            linearMagnitudes: magnitudes,
            sampleRate: sampleRate,
            fftLength: fftLength
        )
        let peak = bands.max { $0.dbFS < $1.dbFS }
        XCTAssertEqual(peak?.centerHz, 1_000)
        XCTAssertFalse(bands.contains { $0.centerHz > sampleRate / 2 })
    }

    func testHarmonicOrdersArePowerRatios() {
        let fftLength = 1024
        let sampleRate = 48_000.0
        let fundamental = 1_000.0
        var magnitudes = Array(repeating: 0.0, count: fftLength / 2)
        let binHz = sampleRate / Double(fftLength)
        magnitudes[Int((fundamental / binHz).rounded())] = 4
        magnitudes[Int((2 * fundamental / binHz).rounded())] = 2
        let orders = RoomRigMath.harmonicOrders(
            linearMagnitudes: magnitudes,
            fundamentalHz: fundamental,
            sampleRate: sampleRate,
            fftLength: fftLength
        )
        XCTAssertEqual(orders?.first?.order, 2)
        XCTAssertEqual(orders?.first?.relativeEnergy ?? .nan, 0.25, accuracy: 1e-6)
        XCTAssertNil(RoomRigMath.harmonicOrders(
            linearMagnitudes: magnitudes,
            fundamentalHz: 0,
            sampleRate: sampleRate,
            fftLength: fftLength
        ))
    }

    func testResponseBucketsNormalizeAndSmooth() {
        var curve: [RoomRigPoint] = []
        curve = RoomRigMath.updateResponse(curve, hz: 1_000, db: -12)
        curve = RoomRigMath.updateResponse(curve, hz: 1_040, db: -6)
        curve = RoomRigMath.updateResponse(curve, hz: 250, db: -18)
        XCTAssertEqual(curve.count, 2)
        XCTAssertEqual(curve.first { $0.hz == 1_000 }?.db ?? .nan, -6, accuracy: 1e-9)
        let shape = RoomRigMath.normalizeToPeak(curve)
        XCTAssertEqual(shape.map(\.db).max() ?? .nan, 0, accuracy: 1e-9)
        let smoothed = RoomRigMath.smoothOneThirdOctave([
            RoomRigPoint(hz: 190, db: 0),
            RoomRigPoint(hz: 200, db: 12),
            RoomRigPoint(hz: 210, db: 0),
        ])
        let middle = smoothed.first { $0.hz == 200 }?.db ?? .nan
        XCTAssertEqual(middle, 4, accuracy: 0.01)
        XCTAssertTrue(RoomRigMath.updateResponse(curve, hz: .nan, db: 0).count == curve.count)
    }

    func testPinkNoiseTiltsTowardLowFrequencies() {
        var generator = PinkNoiseGenerator(seed: 0x51_7A_BE)
        let count = 4_096
        let samples = (0..<count).map { _ in generator.next(amplitude: 1) }
        XCTAssertTrue(samples.allSatisfy(\.isFinite))
        XCTAssertLessThan(samples.map(abs).max() ?? 2, 1.01)
        let magnitudes = CoupledVibrationMath.magnitudeSpectrum(samples: samples)
        let rate = 48_000.0
        func meanMagnitude(from low: Double, to high: Double) -> Double {
            var sum = 0.0
            var bins = 0
            for (index, magnitude) in magnitudes.enumerated() where index > 0 {
                let hz = Double(index) * rate / Double(count)
                guard hz >= low, hz < high else { continue }
                sum += magnitude
                bins += 1
            }
            return bins > 0 ? sum / Double(bins) : 0
        }
        XCTAssertGreaterThan(meanMagnitude(from: 100, to: 200), meanMagnitude(from: 2_000, to: 4_000))
    }

    func testSpectrogramCapsRows() {
        var rows: [[Double]] = []
        rows = RoomRigMath.appendSpectrogram(rows, row: [1, 2], limit: 2)
        rows = RoomRigMath.appendSpectrogram(rows, row: [3, 4], limit: 2)
        rows = RoomRigMath.appendSpectrogram(rows, row: [5, 6], limit: 2)
        XCTAssertEqual(rows, [[3, 4], [5, 6]])
        XCTAssertEqual(RoomRigMath.appendSpectrogram(rows, row: [], limit: 2), rows)
    }

    func testSetupCheckCopyStatesTheLimit() {
        let copy = ToolHowItWorksCatalog.copy(forToolID: "setupCheck")
        XCTAssertNotNil(copy)
        let blob = ([copy?.summary, copy?.context].compactMap { $0 } + (copy?.bullets ?? [])).joined(separator: " ")
        XCTAssertTrue(blob.localizedCaseInsensitiveContains("relative"))
        XCTAssertTrue(blob.localizedCaseInsensitiveContains("calibrat"))
        XCTAssertTrue(blob.localizedCaseInsensitiveContains("FFT") || blob.localizedCaseInsensitiveContains("RTA"))
        XCTAssertFalse(blob.localizedCaseInsensitiveContains("THX certification"))
        XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: "setupCheck"), .field)
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "setupCheck"), .instruments)
        XCTAssertEqual(ToolCalculationPolicy.mode(forToolID: "setupCheck"), .sensor)
        XCTAssertTrue(RoomRigMath.honestLimit.localizedCaseInsensitiveContains("not a calibrated"))
        XCTAssertTrue(RoomRigMath.honestLimit.localizedCaseInsensitiveContains("dB SPL"))
    }
}
