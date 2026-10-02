import XCTest
@testable import BeckifyMath

final class AcousticSpectrumTests: XCTestCase {

    func testFoldPlacesEnergyInTheMatchingAudibleBand() {
        let sampleRate = 48_000.0
        let fftLength = 1024
        var magnitudes = [Double](repeating: 0, count: fftLength / 2 + 1)
        let targetHz = 1_000.0
        let bin = Int((targetHz * Double(fftLength) / sampleRate).rounded())
        // Amplitude-normalized full-scale tone in its bin.
        magnitudes[bin] = 1.0

        let bands = AcousticSpectrum.fold(
            linearMagnitudes: magnitudes,
            sampleRate: sampleRate,
            fftLength: fftLength,
            bandCount: 24
        )
        XCTAssertEqual(bands.count, 24)
        let peak = AcousticSpectrum.peakBand(bands)
        XCTAssertNotNil(peak)
        XCTAssertTrue(peak?.isAvailable == true)
        XCTAssertGreaterThan(peak?.dbFS ?? -200, -3)
        XCTAssertLessThan(peak?.lowHz ?? 0, targetHz)
        XCTAssertGreaterThan(peak?.highHz ?? 0, targetHz)

        let quiet = bands.filter { $0.centerHz < 200 || $0.centerHz > 4_000 }
        XCTAssertTrue(quiet.allSatisfy { !$0.isAvailable })
    }

    func testKnownSinePeaksNearZeroDBFSAfterCoherentGain() {
        let n = 1024
        let sampleRate = 48_000.0
        // Exact FFT bin — off-bin tones (e.g. 1 kHz → bin 21.333) leak under Hann
        // and peak ~0.93 (−0.63 dBFS), which is window scallop, not a scale bug.
        let bin = 32
        let hz = Double(bin) * sampleRate / Double(n) // 1_500 Hz
        let amplitude = 1.0
        let samples = (0..<n).map { index in
            amplitude * sin(2 * Double.pi * hz * Double(index) / sampleRate)
        }
        // CoupledVibrationMath already applies coherent gain + one-sided ×2.
        let magnitudes = CoupledVibrationMath.magnitudeSpectrum(samples: samples, window: .hann)
        XCTAssertGreaterThan(magnitudes.count, bin)
        let peak = magnitudes[bin]
        XCTAssertEqual(peak, amplitude, accuracy: 0.05)
        let db = AcousticSpectrum.dbFS(amplitude: peak)
        XCTAssertEqual(db, 0, accuracy: 0.5)

        let gain = AcousticSpectrum.coherentGain(count: n, kind: .hann)
        XCTAssertEqual(gain, 0.5, accuracy: 0.02)

        // Raw-style magnitude (pre-normalization) of a Hann-windowed sine ≈ A·N·gain/2.
        let raw = amplitude * Double(n) * gain / 2
        let restored = AcousticSpectrum.amplitudeFromRawVDSP(
            rawMagnitude: raw,
            fftLength: n,
            coherentGain: gain,
            isNyquistOrDC: false
        )
        XCTAssertEqual(restored, amplitude, accuracy: 1e-9)
    }

    func testEmptyBandsAreUnavailableNotFakeFloor() {
        let magnitudes = [Double](repeating: 0, count: 513)
        let bands = AcousticSpectrum.fold(
            linearMagnitudes: magnitudes,
            sampleRate: 48_000,
            fftLength: 1024,
            bandCount: 12
        )
        XCTAssertTrue(bands.allSatisfy { !$0.isAvailable })
        XCTAssertTrue(bands.allSatisfy { $0.dbFS <= SoundLevel.silenceFloorDBFS + 1e-6 })
        XCTAssertNil(AcousticSpectrum.peakBand(bands))
        XCTAssertEqual(AcousticSpectrum.heat(dbFS: SoundLevel.silenceFloorDBFS, isAvailable: false), 0, accuracy: 1e-9)
    }

    func testDisplayStopsAtAudibleCeilingNotUltrasonic() {
        let edges = AcousticSpectrum.bandEdges(count: 12, sampleRate: 48_000)
        XCTAssertLessThanOrEqual(edges.last?.high ?? 0, AcousticSpectrum.audibleCeilingHz + 1e-6)
        XCTAssertGreaterThan(edges.first?.low ?? 0, 30)
        XCTAssertLessThan(edges.first?.high ?? 0, edges.last?.low ?? 0)
    }

    func testChannelBalanceIsNotABearing() {
        XCTAssertNil(AcousticSpectrum.channelBalance(leftRMS: 0, rightRMS: 0))
        XCTAssertNil(AcousticSpectrum.channelBalance(leftRMS: .nan, rightRMS: 0.2))
        XCTAssertEqual(AcousticSpectrum.channelBalance(leftRMS: 0.2, rightRMS: 0.2) ?? -2, 0, accuracy: 1e-9)
        XCTAssertEqual(AcousticSpectrum.channelBalance(leftRMS: 0, rightRMS: 0.4) ?? 0, 1, accuracy: 1e-9)
        XCTAssertEqual(AcousticSpectrum.channelBalance(leftRMS: 0.4, rightRMS: 0) ?? 0, -1, accuracy: 1e-9)
    }

    func testHeatClampsToDisplayRange() {
        XCTAssertEqual(AcousticSpectrum.heat(dbFS: -80), 0, accuracy: 1e-9)
        XCTAssertEqual(AcousticSpectrum.heat(dbFS: -3), 1, accuracy: 1e-9)
        XCTAssertEqual(AcousticSpectrum.heat(dbFS: 6), 1, accuracy: 1e-9)
        XCTAssertEqual(AcousticSpectrum.heat(dbFS: .nan), 0, accuracy: 1e-9)
        let mid = AcousticSpectrum.heat(dbFS: -41.5)
        XCTAssertGreaterThan(mid, 0.4)
        XCTAssertLessThan(mid, 0.6)
    }
}
