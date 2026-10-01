import XCTest
@testable import BeckifyMath

final class FieldInstrumentMathTests: XCTestCase {

    private let baseline = StillnessBaseline(
        magneticMicrotesla: 48,
        pressureKilopascals: 101.3,
        noiseFloorDBFS: -52,
        advertisers: [
            StillnessAdvertiser(id: "a", rssi: -60),
            StillnessAdvertiser(id: "b", rssi: -70),
        ]
    )

    func testMagneticPressureAndMicTripOnTheirOwnThresholds() {
        let quiet = StillnessWatchMath.evaluate(
            sample: StillnessSample(
                magneticMicrotesla: 50,
                pressureKilopascals: 101.31,
                micDBFS: -48,
                advertisers: baseline.advertisers,
                userAccelerationG: 0.02
            ),
            baseline: baseline,
            nowSeconds: 1,
            lastBumpSeconds: nil
        ).verdict
        XCTAssertFalse(quiet.phoneMoved)
        XCTAssertTrue(quiet.anomalies.isEmpty)
        XCTAssertEqual(quiet.pressureDeltaPascals ?? 0, 10, accuracy: 1e-6)

        let loud = StillnessWatchMath.evaluate(
            sample: StillnessSample(
                magneticMicrotesla: 57,
                pressureKilopascals: 101.32,
                micDBFS: -39,
                advertisers: baseline.advertisers,
                userAccelerationG: 0.05
            ),
            baseline: baseline,
            nowSeconds: 2,
            lastBumpSeconds: nil
        ).verdict
        XCTAssertEqual(loud.anomalies, [.magnetic, .pressure, .micImpulse])
        XCTAssertEqual(loud.magneticDeltaMicrotesla ?? 0, 9, accuracy: 1e-9)
        XCTAssertEqual(loud.pressureDeltaPascals ?? 0, 20, accuracy: 1e-6)
        XCTAssertEqual(loud.micAboveFloorDB ?? 0, 13, accuracy: 1e-9)
    }

    func testPhoneMovedSuppressesAnomaliesAndHolds() {
        let bump = StillnessWatchMath.evaluate(
            sample: StillnessSample(
                magneticMicrotesla: 90,
                pressureKilopascals: 102,
                micDBFS: -10,
                advertisers: [StillnessAdvertiser(id: "z", rssi: -40)],
                userAccelerationG: 0.30
            ),
            baseline: baseline,
            nowSeconds: 3,
            lastBumpSeconds: nil
        )
        XCTAssertTrue(bump.verdict.phoneMoved)
        XCTAssertTrue(bump.verdict.anomalies.isEmpty)
        XCTAssertEqual(bump.verdict.activeChannels, [.phoneMoved])
        XCTAssertEqual(bump.lastBumpSeconds, 3)

        let held = StillnessWatchMath.evaluate(
            sample: StillnessSample(userAccelerationG: 0.01),
            baseline: baseline,
            nowSeconds: 3.39,
            lastBumpSeconds: bump.lastBumpSeconds
        ).verdict
        XCTAssertTrue(held.phoneMoved)
        XCTAssertTrue(held.anomalies.isEmpty)

        let released = StillnessWatchMath.evaluate(
            sample: StillnessSample(
                magneticMicrotesla: 48,
                pressureKilopascals: 101.3,
                micDBFS: -52,
                advertisers: baseline.advertisers,
                userAccelerationG: 0.01
            ),
            baseline: baseline,
            nowSeconds: 3.40,
            lastBumpSeconds: bump.lastBumpSeconds
        ).verdict
        XCTAssertFalse(released.phoneMoved)
        XCTAssertTrue(released.anomalies.isEmpty)
    }

    func testHysteresisHoldsAChannelUntilItFallsFurther() {
        let held = StillnessWatchMath.evaluate(
            sample: StillnessSample(magneticMicrotesla: 48 + 8 * StillnessWatchMath.releaseFactor, userAccelerationG: 0),
            baseline: baseline,
            nowSeconds: 1,
            lastBumpSeconds: nil,
            previousAnomalies: [.magnetic]
        ).verdict
        XCTAssertEqual(held.anomalies, [.magnetic])

        let dropped = StillnessWatchMath.evaluate(
            sample: StillnessSample(magneticMicrotesla: 48 + 8 * StillnessWatchMath.releaseFactor - 0.1, userAccelerationG: 0),
            baseline: baseline,
            nowSeconds: 1,
            lastBumpSeconds: nil,
            previousAnomalies: [.magnetic]
        ).verdict
        XCTAssertTrue(dropped.anomalies.isEmpty)

        let notYet = StillnessWatchMath.evaluate(
            sample: StillnessSample(magneticMicrotesla: 55, userAccelerationG: 0),
            baseline: baseline,
            nowSeconds: 1,
            lastBumpSeconds: nil
        ).verdict
        XCTAssertTrue(notYet.anomalies.isEmpty)
    }

    func testNoBaselineMeansNoSensorAnomaly() {
        let verdict = StillnessWatchMath.evaluate(
            sample: StillnessSample(
                magneticMicrotesla: 80,
                pressureKilopascals: 90,
                micDBFS: -5,
                advertisers: [StillnessAdvertiser(id: "a", rssi: -40)],
                userAccelerationG: 0.02
            ),
            baseline: nil,
            nowSeconds: 0,
            lastBumpSeconds: nil
        ).verdict
        XCTAssertTrue(verdict.anomalies.isEmpty)
        XCTAssertNil(verdict.magneticDeltaMicrotesla)
        XCTAssertEqual(verdict.advertiserCount, 1)
    }

    func testBLEChurnIsAdvertisersNotPeople() {
        let same = StillnessWatchMath.bleChurn(
            live: baseline.advertisers,
            baseline: baseline.advertisers,
            rssiJumpDB: 12
        )
        XCTAssertFalse(same.changed)
        XCTAssertEqual(same.added, 0)
        XCTAssertEqual(same.lost, 0)

        let swapped = StillnessWatchMath.bleChurn(
            live: [
                StillnessAdvertiser(id: "a", rssi: -60),
                StillnessAdvertiser(id: "c", rssi: -55),
            ],
            baseline: baseline.advertisers,
            rssiJumpDB: 12
        )
        XCTAssertTrue(swapped.changed)
        XCTAssertEqual(swapped.added, 1)
        XCTAssertEqual(swapped.lost, 1)

        let jump = StillnessWatchMath.bleChurn(
            live: [
                StillnessAdvertiser(id: "a", rssi: -40),
                StillnessAdvertiser(id: "b", rssi: -70),
                StillnessAdvertiser(id: "a", rssi: -62),
            ],
            baseline: baseline.advertisers,
            rssiJumpDB: 12
        )
        XCTAssertTrue(jump.changed)
        XCTAssertEqual(jump.added, 0)
        XCTAssertEqual(jump.maxAbsRSSIJumpDB ?? 0, 20, accuracy: 1e-9)

        let ignored = StillnessWatchMath.indexedAdvertisers([
            StillnessAdvertiser(id: "  ", rssi: -20),
            StillnessAdvertiser(id: "a", rssi: .nan),
        ])
        XCTAssertTrue(ignored.isEmpty)

        let verdict = StillnessWatchMath.evaluate(
            sample: StillnessSample(advertisers: [StillnessAdvertiser(id: "c", rssi: -50)], userAccelerationG: 0),
            baseline: baseline,
            nowSeconds: 1,
            lastBumpSeconds: nil
        ).verdict
        let detail = StillnessWatchMath.detail(channel: .bleAdvertisers, verdict: verdict)
        XCTAssertTrue(detail.contains("advertisers"))
        for banned in ["person", "people", "entity", "occupancy", "ghost", "spirit", "EVP"] {
            XCTAssertFalse(detail.localizedCaseInsensitiveContains(banned), detail)
        }
        XCTAssertTrue(StillnessWatchMath.honestLimit.localizedCaseInsensitiveContains("not a ghost detector"))
        XCTAssertTrue(StillnessWatchMath.honestLimit.localizedCaseInsensitiveContains("not a presence meter"))
        XCTAssertTrue(StillnessWatchMath.honestLimit.localizedCaseInsensitiveContains("dc field only"))
        XCTAssertTrue(StillnessWatchMath.honestLimit.localizedCaseInsensitiveContains("not occupancy"))
        XCTAssertFalse(StillnessWatchMath.honestLimit.localizedCaseInsensitiveContains("entity detected"))
    }

    func testTimelineIsRisingEdgeOnly() {
        let crossed = StillnessWatchMath.evaluate(
            sample: StillnessSample(magneticMicrotesla: 70, userAccelerationG: 0.01),
            baseline: baseline,
            nowSeconds: 4,
            lastBumpSeconds: nil
        ).verdict
        let first = StillnessWatchMath.risingMarks(previous: [], verdict: crossed, timeSeconds: 4)
        XCTAssertEqual(first.marks.map(\.channel), [.magnetic])
        let second = StillnessWatchMath.risingMarks(previous: first.active, verdict: crossed, timeSeconds: 4.2)
        XCTAssertTrue(second.marks.isEmpty)

        let bumped = StillnessWatchMath.evaluate(
            sample: StillnessSample(magneticMicrotesla: 70, userAccelerationG: 0.8),
            baseline: baseline,
            nowSeconds: 5,
            lastBumpSeconds: nil
        ).verdict
        let gate = StillnessWatchMath.risingMarks(previous: first.active, verdict: bumped, timeSeconds: 5)
        XCTAssertEqual(gate.marks.map(\.channel), [.phoneMoved])
        XCTAssertEqual(gate.marks.first?.detail, "phone moved")
    }

    func testMagSweepDeltaPeakAndTrace() {
        XCTAssertEqual(MagSweepMath.deltaMicrotesla(magnitude: 62, baseline: 48) ?? 0, 14, accuracy: 1e-9)
        XCTAssertNil(MagSweepMath.deltaMicrotesla(magnitude: .nan, baseline: 48))
        XCTAssertEqual(MagSweepMath.peakHold(delta: 14, peak: 0), 14, accuracy: 1e-9)
        XCTAssertEqual(MagSweepMath.peakHold(delta: -3, peak: 14), 14, accuracy: 1e-9)
        XCTAssertEqual(MagSweepMath.peakHold(delta: -20, peak: 14), 20, accuracy: 1e-9)
        XCTAssertEqual(MagSweepMath.peakHold(delta: .nan, peak: 14), 14, accuracy: 1e-9)
        let trace = MagSweepMath.appendTrace([1, 2], sample: 3, limit: 2)
        XCTAssertEqual(trace, [2, 3])
        XCTAssertEqual(MagSweepMath.appendTrace([1], sample: .nan, limit: 4), [1])
        XCTAssertTrue(MagSweepMath.honestLimit.localizedCaseInsensitiveContains("not a stud finder"))
        XCTAssertTrue(MagSweepMath.honestLimit.localizedCaseInsensitiveContains("not a 60 hz emf"))
        XCTAssertTrue(MagSweepMath.honestLimit.localizedCaseInsensitiveContains("dc"))
    }

    func testBreathFluteGatePitchAndSine() {
        // Legacy RMS/peak gate shares marginDB (now 24).
        XCTAssertFalse(BreathFluteMath.gateOpen(rmsDBFS: -40, peakDBFS: -36, noiseFloorDBFS: -48))
        XCTAssertTrue(BreathFluteMath.gateOpen(rmsDBFS: -24, peakDBFS: -22, noiseFloorDBFS: -48))
        XCTAssertTrue(BreathFluteMath.gateOpen(rmsDBFS: -40, peakDBFS: -24, noiseFloorDBFS: -48))
        XCTAssertFalse(BreathFluteMath.gateOpen(rmsDBFS: .nan, peakDBFS: 0, noiseFloorDBFS: -48))

        XCTAssertEqual(BreathFluteMath.frequencyHz(touchY: 0), BreathFluteMath.lowHz, accuracy: 1e-9)
        XCTAssertEqual(BreathFluteMath.frequencyHz(touchY: 1), BreathFluteMath.highHz, accuracy: 1e-6)
        XCTAssertEqual(BreathFluteMath.frequencyHz(touchY: -2), BreathFluteMath.lowHz, accuracy: 1e-9)
        let mid = BreathFluteMath.frequencyHz(touchY: 0.5)
        XCTAssertEqual(mid, sqrt(BreathFluteMath.lowHz * BreathFluteMath.highHz), accuracy: 1e-6)

        XCTAssertEqual(BreathFluteMath.fretFrequencyHz(fret: 0), BreathFluteMath.rootHz, accuracy: 1e-9)
        XCTAssertEqual(BreathFluteMath.fretFrequencyHz(fret: 12), BreathFluteMath.rootHz * 2, accuracy: 1e-6)

        let margin = BreathFluteMath.marginDB
        XCTAssertEqual(BreathFluteMath.amplitude(aboveFloorDB: 0), 0, accuracy: 1e-9)
        XCTAssertEqual(BreathFluteMath.amplitude(aboveFloorDB: margin - 0.1), 0, accuracy: 1e-9)
        XCTAssertEqual(BreathFluteMath.amplitude(aboveFloorDB: margin), BreathFluteMath.quietAmplitude, accuracy: 1e-9)
        XCTAssertEqual(
            BreathFluteMath.amplitude(aboveFloorDB: margin + BreathFluteMath.loudSpanDB),
            BreathFluteMath.loudAmplitude,
            accuracy: 1e-9
        )
        XCTAssertEqual(BreathFluteMath.amplitude(aboveFloorDB: 80), BreathFluteMath.loudAmplitude, accuracy: 1e-9)
        let soft = BreathFluteMath.amplitude(aboveFloorDB: margin + 6)
        let hard = BreathFluteMath.amplitude(aboveFloorDB: margin + 18)
        XCTAssertGreaterThan(hard, soft)
        XCTAssertGreaterThan(soft, BreathFluteMath.quietAmplitude)
        XCTAssertEqual(BreathFluteMath.coveredFromEmbouchure(holesCovered: [false, true, true]), 0)
        XCTAssertEqual(BreathFluteMath.coveredFromEmbouchure(holesCovered: [true, true, false, true]), 2)
        // Phone depth: a single far hole still retunes (not stuck on open C5).
        XCTAssertEqual(BreathFluteMath.coveredDepth(holesCovered: [false, false, true]), 3)
        XCTAssertEqual(BreathFluteMath.coveredDepth(holesCovered: [true, false, true]), 3)
        XCTAssertEqual(BreathFluteMath.coveredDepth(holesCovered: [false, false, false]), 0)
        XCTAssertEqual(BreathFluteMath.coversForDepth(3), [true, true, true, false, false, false, false])
        XCTAssertNotEqual(
            BreathFluteMath.frequencyHz(coveredFromEmbouchure: 0),
            BreathFluteMath.frequencyHz(coveredFromEmbouchure: 3),
            accuracy: 1e-6
        )
        XCTAssertEqual(
            BreathFluteMath.frequencyHz(coveredFromEmbouchure: 0),
            BreathFluteMath.fretFrequencyHz(fret: 12),
            accuracy: 1e-6
        )
        XCTAssertEqual(BreathFluteMath.frequencyHz(coveredFromEmbouchure: 7), BreathFluteMath.rootHz, accuracy: 1e-6)
        XCTAssertEqual(BreathFluteMath.noteName(coveredFromEmbouchure: 0), "C5")
        XCTAssertEqual(BreathFluteMath.noteName(coveredFromEmbouchure: 7), "C4")
        XCTAssertEqual(BreathFluteMath.noteName(coveredFromEmbouchure: 99), "C4")

        let seeded = BreathFluteMath.updateNoiseFloor(currentDBFS: -40, floor: nil)
        XCTAssertEqual(seeded, -40, accuracy: 1e-9)
        let refuseSilence = BreathFluteMath.updateNoiseFloor(
            currentDBFS: SoundLevel.silenceFloorDBFS,
            floor: nil
        )
        XCTAssertEqual(refuseSilence, SoundLevel.silenceFloorDBFS, accuracy: 1e-9)
        XCTAssertFalse(BreathFluteMath.isUsableBreathLevel(SoundLevel.silenceFloorDBFS))
        XCTAssertTrue(BreathFluteMath.isUsableBreathLevel(-55))
        let held = BreathFluteMath.updateNoiseFloor(currentDBFS: -10, floor: -40)
        XCTAssertEqual(held, -40, accuracy: 1e-9)
        let eased = BreathFluteMath.updateNoiseFloor(currentDBFS: -46, floor: -40)
        XCTAssertLessThan(eased, -40)
        XCTAssertGreaterThan(eased, -46)

        var cal: [Double] = []
        for sample in [-58.0, -56.0, -57.0, -55.0, -59.0, -56.5, -57.5, -56.0, -58.0, -57.0] {
            BreathFluteMath.appendCalibrationSample(sample, into: &cal)
        }
        XCTAssertEqual(cal.count, BreathFluteMath.calibrationSampleCount)
        let calFloor = BreathFluteMath.calibrationFloor(samples: cal)
        XCTAssertNotNil(calFloor)
        XCTAssertEqual(calFloor!, -57.0, accuracy: 1.5)
        let before = cal.count
        BreathFluteMath.appendCalibrationSample(-20, into: &cal)
        XCTAssertEqual(cal.count, before)

        let fluteToneBand = AcousticDisplayBand(lowHz: 400, highHz: 600, centerHz: 490, dbFS: -18)
        let breathBand = AcousticDisplayBand(lowHz: 3_000, highHz: 4_000, centerHz: 3_400, dbFS: -28)
        let quietHF = AcousticDisplayBand(lowHz: 3_000, highHz: 4_000, centerHz: 3_400, dbFS: -55)
        let midPartial = AcousticDisplayBand(lowHz: 2_000, highHz: 2_600, centerHz: 2_300, dbFS: -20)
        XCTAssertEqual(
            BreathFluteMath.breathLevelDBFS(bands: [fluteToneBand, quietHF]),
            -55,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            BreathFluteMath.breathLevelDBFS(bands: [fluteToneBand, breathBand]),
            -28,
            accuracy: 1e-9
        )
        // Partials below breathBandMinHz must not count as breath.
        XCTAssertEqual(
            BreathFluteMath.breathLevelDBFS(bands: [fluteToneBand, midPartial]),
            SoundLevel.silenceFloorDBFS,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            BreathFluteMath.breathLevelDBFS(bands: [fluteToneBand]),
            SoundLevel.silenceFloorDBFS,
            accuracy: 1e-9
        )
        // Open needs marginDB (24) above floor and absolute minOpenBreathDBFS (−50).
        XCTAssertFalse(BreathFluteMath.breathGateOpen(breathDBFS: -40, noiseFloorDBFS: -48))
        XCTAssertFalse(BreathFluteMath.breathGateOpen(breathDBFS: -24.1, noiseFloorDBFS: -48))
        XCTAssertTrue(BreathFluteMath.breathGateOpen(breathDBFS: -24, noiseFloorDBFS: -48))
        XCTAssertFalse(
            BreathFluteMath.breathGateOpen(
                breathDBFS: -55,
                noiseFloorDBFS: SoundLevel.silenceFloorDBFS
            )
        )
        // Absolute quiet HF never opens even with a very low floor.
        XCTAssertFalse(BreathFluteMath.breathGateOpen(breathDBFS: -55, noiseFloorDBFS: -80))
        XCTAssertTrue(
            BreathFluteMath.breathGateOpen(breathDBFS: -34, noiseFloorDBFS: -48, wasOpen: true)
        )
        XCTAssertFalse(
            BreathFluteMath.breathGateOpen(breathDBFS: -34.1, noiseFloorDBFS: -48, wasOpen: true)
        )

        let levels = BreathFluteMath.levelDBFS(samples: [Float](repeating: 0.1, count: 4))
        XCTAssertEqual(levels.rms, SoundLevel.dbfs(rms: 0.1), accuracy: 1e-6)
        XCTAssertEqual(levels.peak, SoundLevel.dbfs(rms: 0.1), accuracy: 1e-6)
        let silent = BreathFluteMath.levelDBFS(samples: [])
        XCTAssertEqual(silent.rms, SoundLevel.silenceFloorDBFS, accuracy: 1e-9)

        let step = BreathFluteMath.sineSample(phase: .pi / 2, frequencyHz: 0, sampleRate: 48_000, amplitude: 0.5)
        XCTAssertEqual(step.sample, 0.5, accuracy: 1e-9)
        let wrap = BreathFluteMath.sineSample(phase: 0, frequencyHz: 48_000, sampleRate: 48_000, amplitude: 1)
        XCTAssertEqual(wrap.nextPhase, 0, accuracy: 1e-6)

        // Soft attack: light blow rises slower than a firm blow; closed gate falls fast.
        let attackLight = BreathFluteMath.envelopeStep(current: 0, target: 1, sampleRate: 48_000, lightBlow: true)
        let attackFirm = BreathFluteMath.envelopeStep(current: 0, target: 1, sampleRate: 48_000, lightBlow: false)
        XCTAssertGreaterThan(attackFirm, attackLight)
        XCTAssertGreaterThan(attackLight, 0)
        let release = BreathFluteMath.envelopeStep(current: 1, target: 0, sampleRate: 48_000, lightBlow: false)
        XCTAssertLessThan(release, 1)
        XCTAssertGreaterThan(release, 0)

        // Angelic tone is silent when amplitude or envelope is zero (touch-only).
        let silentTone = BreathFluteMath.angelicSample(
            phase: 0, phase2: 0, phase3: 0, phase4: 0, phase5: 0,
            noise: 0, noiseSeed: 1,
            frequencyHz: BreathFluteMath.rootHz, sampleRate: 48_000,
            amplitude: 0, envelope: 1
        )
        XCTAssertEqual(silentTone.sample, 0, accuracy: 1e-12)
        let gatedOff = BreathFluteMath.angelicSample(
            phase: 0.4, phase2: 0.8, phase3: 1.2, phase4: 1.6, phase5: 2.0,
            noise: 0.1, noiseSeed: 42,
            frequencyHz: BreathFluteMath.rootHz, sampleRate: 48_000,
            amplitude: 0.4, envelope: 0
        )
        XCTAssertEqual(gatedOff.sample, 0, accuracy: 1e-12)
        let voiced = BreathFluteMath.angelicSample(
            phase: .pi / 2, phase2: 0, phase3: 0, phase4: 0, phase5: 0,
            noise: 0, noiseSeed: 7,
            frequencyHz: BreathFluteMath.rootHz, sampleRate: 48_000,
            amplitude: 0.4, envelope: 1
        )
        XCTAssertNotEqual(voiced.sample, 0, accuracy: 1e-9)
        XCTAssertLessThan(abs(voiced.sample), 1.0)

        XCTAssertTrue(BreathFluteMath.honestLimit.localizedCaseInsensitiveContains("play tool"))
        XCTAssertTrue(BreathFluteMath.honestLimit.localizedCaseInsensitiveContains("not a meter"))
        XCTAssertTrue(BreathFluteMath.honestLimit.localizedCaseInsensitiveContains("silence"))
        XCTAssertTrue(BreathFluteMath.honestLimit.localizedCaseInsensitiveContains("not a calibrated wind instrument"))
        XCTAssertFalse(BreathFluteMath.honestLimit.localizedCaseInsensitiveContains("recorded or uploaded") == false)
    }

    func testCoupledVibrationRMSSpectrumAndCompare() {
        XCTAssertEqual(CoupledVibrationMath.rms([0.5, 0.5, 0.5]), 0.5, accuracy: 1e-9)
        XCTAssertTrue(CoupledVibrationMath.rms([.nan, .nan]).isNaN)
        XCTAssertEqual(CoupledVibrationMath.sampleRateHz(count: 5, durationSeconds: 0.4) ?? 0, 10, accuracy: 1e-9)
        XCTAssertNil(CoupledVibrationMath.sampleRateHz(count: 1, durationSeconds: 1))

        let n = 64
        let sampleRate = 32.0
        let amplitude = 0.2
        let samples = (0..<n).map { index in
            amplitude * sin(2 * Double.pi * 4 * Double(index) / sampleRate)
        }
        let peak = CoupledVibrationMath.peakBin(samples: samples, sampleRateHz: sampleRate)
        XCTAssertEqual(peak?.hz ?? 0, 4, accuracy: 0.51)
        XCTAssertGreaterThan(peak?.magnitude ?? 0, 0.1)
        XCTAssertLessThan(peak?.magnitude ?? 1, amplitude + 0.02)

        let signature = CoupledVibrationMath.signature(samples: samples, sampleRateHz: sampleRate, bandCount: 8)
        XCTAssertEqual(signature?.bands.count, 8)
        XCTAssertGreaterThan(signature?.rmsG ?? 0, 0.1)
        XCTAssertNil(CoupledVibrationMath.signature(samples: [0, 1, 2], sampleRateHz: 50))

        let louder = samples.map { $0 * 2 }
        let other = CoupledVibrationMath.signature(samples: louder, sampleRateHz: sampleRate, bandCount: 8)!
        let comparison = CoupledVibrationMath.compare(signature!, other)
        XCTAssertGreaterThan(comparison?.rmsDelta ?? 0, 0)
        XCTAssertEqual(comparison?.bandDeltas.count, 8)
        XCTAssertTrue(comparison?.bandDeltas.contains { $0 > 0 } == true)
        XCTAssertTrue(CoupledVibrationMath.honestLimit.localizedCaseInsensitiveContains("not iso 10816"))
        XCTAssertTrue(CoupledVibrationMath.honestLimit.localizedCaseInsensitiveContains("not a calibrated pickup"))
        XCTAssertEqual(CoupledVibrationMath.nyquistHz(sampleRateHz: 80) ?? 0, 40, accuracy: 1e-9)
        XCTAssertNil(CoupledVibrationMath.nyquistHz(sampleRateHz: 0))
        XCTAssertEqual(CoupledVibrationMath.relativeRPM(frequencyHz: 30) ?? 0, 1_800, accuracy: 1e-9)
        XCTAssertNil(CoupledVibrationMath.relativeRPM(frequencyHz: .nan))
        XCTAssertTrue(CoupledVibrationMath.rpmDisclaimer.localizedCaseInsensitiveContains("not a tachometer"))
        XCTAssertFalse(CoupledVibrationMath.rpmDisclaimer.localizedCaseInsensitiveContains("bearing-fault diagnosis") == false)
    }

    func testWindowsAndRelativeHarmonicEnergyStayHonest() {
        for kind in SpectrumWindowKind.allCases {
            let weights = CoupledVibrationMath.window(count: 16, kind: kind)
            XCTAssertEqual(weights.count, 16, kind.rawValue)
            XCTAssertTrue(weights.allSatisfy { $0.isFinite && $0 >= 0 }, kind.rawValue)
        }
        let hann = CoupledVibrationMath.window(count: 32, kind: .hann)
        let hamming = CoupledVibrationMath.window(count: 32, kind: .hamming)
        XCTAssertNotEqual(hann, hamming)
        XCTAssertEqual(hann.first ?? -1, 0, accuracy: 1e-9)
        XCTAssertGreaterThan(hamming.first ?? 0, 0.05)

        var tone = [Double](repeating: 0, count: 32)
        tone[8] = 4
        XCTAssertEqual(RelativeHarmonicEnergy.ratio(linearMagnitudes: tone) ?? -1, 0, accuracy: 1e-9)
        let flat = [Double](repeating: 1, count: 16)
        let spread = RelativeHarmonicEnergy.ratio(linearMagnitudes: flat) ?? 0
        XCTAssertGreaterThan(spread, 0.5)
        XCTAssertNil(RelativeHarmonicEnergy.ratio(linearMagnitudes: [0, .nan]))
        XCTAssertTrue(RelativeHarmonicEnergy.honestLimit.localizedCaseInsensitiveContains("not thd"))
        XCTAssertTrue(RelativeHarmonicEnergy.honestLimit.localizedCaseInsensitiveContains("not db spl"))
        XCTAssertTrue(MagSweepMath.variationSpectrumLabel.localizedCaseInsensitiveContains("not ac emf"))
        XCTAssertTrue(MagSweepMath.variationSpectrumLabel.localizedCaseInsensitiveContains("not a 50–60 hz"))
        XCTAssertFalse(MagSweepMath.variationSpectrumLabel.localizedCaseInsensitiveContains("isolate"))
    }

    func testNewInstrumentsStayOffDefaultPinnedSeeds() {
        for id in ["stillnessWatch", "coupledVibration"] {
            XCTAssertEqual(ToolHomeAreaPolicy.area(forToolID: id), .field, id)
            XCTAssertEqual(ToolHomeAreaPolicy.shelf(forToolID: id), .instruments, id)
            XCTAssertEqual(ToolCalculationPolicy.mode(forToolID: id), .sensor, id)
            XCTAssertFalse(ToolHomeAreaPolicy.fieldQuickIDs.contains(id), id)
            let copy = ToolHowItWorksCatalog.copy(forToolID: id)
            XCTAssertNotNil(copy, id)
        }
        // Breath Flute removed from catalog / navigation (build 232). Math stays for unit tests.
        XCTAssertNil(ToolHowItWorksCatalog.copy(forToolID: "breathFlute"))
        XCTAssertFalse(ToolCalculationPolicy.knownToolIDs.contains("breathFlute"))
        let watch = ToolHowItWorksCatalog.copy(forToolID: "stillnessWatch")
        XCTAssertTrue(watch?.bullets.contains { $0.localizedCaseInsensitiveContains("ghost") } == true)
        XCTAssertTrue(watch?.bullets.contains { $0.localizedCaseInsensitiveContains("not occupancy") || $0.localizedCaseInsensitiveContains("not people") } == true)
        let vibe = ToolHowItWorksCatalog.copy(forToolID: "coupledVibration")
        XCTAssertTrue(vibe?.bullets.contains { $0.localizedCaseInsensitiveContains("ISO 10816") } == true)
        XCTAssertTrue(vibe?.bullets.contains { $0.localizedCaseInsensitiveContains("g-Force") } == true)
        let mag = ToolHowItWorksCatalog.copy(forToolID: "magnetometer")
        XCTAssertTrue(mag?.summary.localizedCaseInsensitiveContains("Mag Sweep") == true)
        XCTAssertTrue(mag?.bullets.contains { $0.localizedCaseInsensitiveContains("60 Hz") } == true)
        let noise = ToolHowItWorksCatalog.copy(forToolID: "noiseMeter")
        XCTAssertTrue(noise?.summary.localizedCaseInsensitiveContains("FFT") == true)
        XCTAssertTrue(noise?.bullets.contains { $0.localizedCaseInsensitiveContains("not sound pressure") || $0.localizedCaseInsensitiveContains("not SPL") || $0.localizedCaseInsensitiveContains("dB(A)") } == true)
    }
}
