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
        XCTAssertTrue(blob.localizedCaseInsensitiveContains("RigScope"))
        XCTAssertTrue(blob.localizedCaseInsensitiveContains("relative"))
        XCTAssertTrue(blob.localizedCaseInsensitiveContains("calibrat"))
        XCTAssertTrue(blob.localizedCaseInsensitiveContains("Music") || blob.localizedCaseInsensitiveContains("Gaming"))
        XCTAssertFalse(blob.localizedCaseInsensitiveContains("THX certification"))
        XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: "setupCheck"), .field)
        XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: "setupCheck"), .instruments)
        XCTAssertEqual(ToolCalculationPolicy.mode(forToolID: "setupCheck"), .sensor)
        XCTAssertTrue(RoomRigMath.honestLimit.localizedCaseInsensitiveContains("not a calibrated"))
        XCTAssertTrue(RoomRigMath.honestLimit.localizedCaseInsensitiveContains("dB SPL"))
        XCTAssertEqual(RoomRigDisplayName.title, "RigScope")
    }

    func testListeningPurposeTargetNotes() {
        XCTAssertEqual(RoomRigListeningPurpose.parse("movies"), .movies)
        XCTAssertEqual(RoomRigListeningPurpose.parse("nope"), .music)
        for purpose in RoomRigListeningPurpose.allCases {
            XCTAssertFalse(purpose.targetCurveNote.isEmpty)
            XCTAssertTrue(purpose.targetCurveNote.localizedCaseInsensitiveContains("not scored yet"))
            XCTAssertTrue(purpose.scoreTargetLabel.localizedCaseInsensitiveContains("future score"))
            XCTAssertLessThanOrEqual(purpose.targetCurveNote.count, 180)
        }
        XCTAssertTrue(RoomRigTestCopy.purposeHelp.localizedCaseInsensitiveContains("future score"))
    }

    func testListenTestCentroidBalanceAndSnapshot() {
        let flat = [
            AcousticDisplayBand(lowHz: 80, highHz: 120, centerHz: 100, dbFS: 0),
            AcousticDisplayBand(lowHz: 800, highHz: 1200, centerHz: 1_000, dbFS: 0),
        ]
        XCTAssertEqual(RoomRigTestMath.centroidHz(bands: flat) ?? 0, 550, accuracy: 1e-6)
        XCTAssertNil(RoomRigTestMath.centroidHz(bands: []))

        let grouped = [
            AcousticDisplayBand(lowHz: 80, highHz: 120, centerHz: 100, dbFS: 0),
            AcousticDisplayBand(lowHz: 800, highHz: 1200, centerHz: 1_000, dbFS: -10),
            AcousticDisplayBand(lowHz: 3_000, highHz: 5_000, centerHz: 4_000, dbFS: -10),
        ]
        let balance = RoomRigTestMath.bandBalance(bands: grouped)
        XCTAssertEqual(balance?.lowVsLoudestDB ?? 99, 0, accuracy: 1e-6)
        XCTAssertEqual(balance?.midVsLoudestDB ?? 0, -10, accuracy: 1e-6)
        XCTAssertEqual(balance?.highVsLoudestDB ?? 0, -10, accuracy: 1e-6)
        XCTAssertNil(RoomRigTestMath.bandBalance(bands: flat))

        // Lower median (even count → lower central sample), max peak, mean clip.
        XCTAssertEqual(RoomRigTestMath.lowerMedian([-20, -10]) ?? 0, -20, accuracy: 1e-9)
        XCTAssertEqual(RoomRigTestMath.lowerMedian([8, 4]) ?? 0, 4, accuracy: 1e-9)
        XCTAssertEqual(RoomRigTestMath.lowerMedian([1_000, 1_200]) ?? 0, 1_000, accuracy: 1e-9)
        XCTAssertEqual(RoomRigTestMath.lowerMedian([-15, -20, -10]) ?? 0, -15, accuracy: 1e-9)
        XCTAssertNil(RoomRigTestMath.lowerMedian([.nan]))

        var capture = RoomRigTestCapture()
        XCTAssertNil(capture.snapshot(stimulus: "Pink", durationSeconds: 1, floorDBFS: nil))
        capture.append(levelDBFS: -20, peakDBFS: -12, crestDB: 8, clipFraction: 0, peakHz: 1_000, bands: grouped)
        capture.append(levelDBFS: -10, peakDBFS: -6, crestDB: 4, clipFraction: 0.02, peakHz: 1_200, bands: grouped)
        capture.append(levelDBFS: .nan, peakDBFS: -4, crestDB: nil, clipFraction: .nan, peakHz: nil, bands: [])
        let snap = capture.snapshot(stimulus: "Pink", durationSeconds: 8, floorDBFS: -40)
        XCTAssertEqual(snap?.levelDBFS ?? 0, -20, accuracy: 1e-9)
        XCTAssertEqual(snap?.peakDBFS ?? 0, -4, accuracy: 1e-9)
        XCTAssertEqual(snap?.crestDB ?? 0, 4, accuracy: 1e-9)
        XCTAssertEqual(snap?.clipFraction ?? 0, 0.01, accuracy: 1e-9)
        XCTAssertEqual(snap?.aboveFloorDB ?? 0, 20, accuracy: 1e-9)
        XCTAssertEqual(snap?.peakHz ?? 0, 1_000, accuracy: 1e-6)
        XCTAssertNotNil(snap?.centroidHz)
        XCTAssertEqual(snap?.balance?.lowVsLoudestDB ?? 99, 0, accuracy: 0.2)
        XCTAssertTrue(RoomRigTestCopy.level.localizedCaseInsensitiveContains("not db spl"))
        XCTAssertTrue(RoomRigTestCopy.balance.localizedCaseInsensitiveContains("not a lab rta"))
        XCTAssertTrue(RoomRigTestCopy.versusA.localizedCaseInsensitiveContains("not a calibrated"))
        XCTAssertEqual(RoomRigTestMath.windowSeconds, 8, accuracy: 1e-9)
    }


    func testQuietBaselineAndSignalAboveBackground() {
        let fingerprint = RoomRigRouteFingerprint(
            sampleRateHz: 48_000,
            channelCount: 1,
            routeUID: "Receiver",
            inputGain: 0.5
        )
        let baseline = RoomRigBaselineMath.baseline(
            levels: [-50, -48, -52, -49, -51],
            bandRows: [[-60, -55], [-58, -54], [-62, -56]],
            fingerprint: fingerprint,
            sampleCount: 9_600,
            capturedAt: 100
        )
        XCTAssertNotNil(baseline)
        XCTAssertTrue(baseline!.isValid(for: fingerprint))
        let other = RoomRigRouteFingerprint(
            sampleRateHz: 48_000,
            channelCount: 1,
            routeUID: "Speaker",
            inputGain: 0.5
        )
        XCTAssertFalse(baseline!.isValid(for: other))
        let above = RoomRigBaselineMath.signalAboveBackgroundDB(levelDBFS: -20, baseline: baseline)
        XCTAssertEqual(above ?? 0, -20 - baseline!.floorDBFS, accuracy: 1e-9)
        XCTAssertTrue(RoomRigTestCopy.signalAboveBackground.localizedCaseInsensitiveContains("not snr"))
        XCTAssertTrue(RoomRigTestCopy.baselineHelp.localizedCaseInsensitiveContains("invalidat"))
    }

    func testCaptureProtocolLocksAndCancels() {
        let fingerprint = RoomRigRouteFingerprint(
            sampleRateHz: 48_000,
            channelCount: 1,
            routeUID: "Mic",
            inputGain: 0.4
        )
        let metadata = RoomRigPassMetadata(
            stimulus: .pink,
            fingerprint: fingerprint,
            windowKind: "Hann",
            isPhoneSpeakerDemo: true
        )
        var proto = RoomRigCaptureProtocol(
            metadata: metadata,
            startedSampleCount: 0,
            startedHostTime: 0
        )
        let good = RoomRigMeasurementFrame(
            frameID: 1,
            sampleCount: 1024,
            hostTimeSeconds: 0.1,
            rmsDBFS: -20,
            peakDBFS: -12,
            crestDB: 8,
            clipFraction: 0,
            peakHz: 1_000,
            bands: [],
            rtaBands: [
                AcousticDisplayBand(lowHz: 80, highHz: 120, centerHz: 100, dbFS: -18, isAvailable: true),
                AcousticDisplayBand(lowHz: 800, highHz: 1_200, centerHz: 1_000, dbFS: -20, isAvailable: true),
                AcousticDisplayBand(lowHz: 3_000, highHz: 5_000, centerHz: 4_000, dbFS: -22, isAvailable: true),
            ],
            fingerprint: fingerprint,
            headroomDB: 12
        )
        XCTAssertNil(proto.append(good))
        let snap = proto.finish(durationSeconds: 8, floorDBFS: -50)
        XCTAssertEqual(snap?.stimulus, "Pink · demo")
        XCTAssertEqual(snap?.aboveFloorDB ?? 0, 30, accuracy: 1e-9)

        var clipped = proto
        clipped = RoomRigCaptureProtocol(metadata: metadata, startedSampleCount: 0, startedHostTime: 0)
        var hot = good
        hot.clipFraction = 0.05
        XCTAssertEqual(clipped.append(hot), .clipping)
        XCTAssertNil(clipped.finish(durationSeconds: 1, floorDBFS: -50))

        var route = RoomRigCaptureProtocol(metadata: metadata, startedSampleCount: 0, startedHostTime: 0)
        var moved = good
        moved.fingerprint = RoomRigRouteFingerprint(
            sampleRateHz: 48_000,
            channelCount: 1,
            routeUID: "BT",
            inputGain: 0.4
        )
        XCTAssertEqual(route.append(moved), .routeOrGainChanged)

        let listenMeta = RoomRigPassMetadata(
            stimulus: .listen,
            fingerprint: fingerprint,
            windowKind: "Hann",
            isPhoneSpeakerDemo: false
        )
        XCTAssertFalse(RoomRigABMath.canCompare(a: metadata, b: listenMeta))
        XCTAssertTrue(RoomRigABMath.canCompare(a: metadata, b: metadata))
        let gamingMeta = RoomRigPassMetadata(
            stimulus: .pink,
            fingerprint: fingerprint,
            windowKind: "Hann",
            listeningPurpose: .gaming,
            isPhoneSpeakerDemo: true
        )
        XCTAssertFalse(RoomRigABMath.canCompare(a: metadata, b: gamingMeta))
        XCTAssertEqual(RoomRigMath.liveFFTLength, 1_024)
        XCTAssertEqual(RoomRigMath.bassFFTLengthPreferred, 16_384)
        XCTAssertEqual(RoomRigMath.bassFFTLengthLong, 32_768)
        XCTAssertEqual(
            RoomRigMeasurementFrame.headroomDB(peakDBFS: -6) ?? 0,
            6,
            accuracy: 1e-9
        )
    }

    func testThirdOctaveEmptyBandUnavailable() {
        let bands = RoomRigMath.thirdOctaveBands(
            linearMagnitudes: [Double](repeating: 0, count: 512),
            sampleRate: 48_000,
            fftLength: 1024
        )
        XCTAssertFalse(bands.isEmpty)
        XCTAssertTrue(bands.allSatisfy { !$0.isAvailable })
    }
}

