import XCTest
@testable import BeckifyMath

final class AcousticSpectrumTests: XCTestCase {

    func testFoldPlacesEnergyInTheMatchingAudibleBand() {
        let sampleRate = 48_000.0
        let fftLength = 1024
        var magnitudes = [Double](repeating: 0, count: fftLength / 2)
        let targetHz = 1_000.0
        let bin = Int((targetHz * Double(fftLength) / sampleRate).rounded())
        magnitudes[bin] = Double(fftLength) / 2

        let bands = AcousticSpectrum.fold(
            linearMagnitudes: magnitudes,
            sampleRate: sampleRate,
            fftLength: fftLength,
            bandCount: 24
        )
        XCTAssertEqual(bands.count, 24)
        let peak = AcousticSpectrum.peakBand(bands)
        XCTAssertNotNil(peak)
        XCTAssertGreaterThan(peak?.dbFS ?? -200, -3)
        XCTAssertLessThan(peak?.lowHz ?? 0, targetHz)
        XCTAssertGreaterThan(peak?.highHz ?? 0, targetHz)

        let quiet = bands.filter { $0.centerHz < 200 || $0.centerHz > 4_000 }
        XCTAssertTrue(quiet.allSatisfy { $0.dbFS <= SoundLevel.silenceFloorDBFS + 1e-6 })
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
