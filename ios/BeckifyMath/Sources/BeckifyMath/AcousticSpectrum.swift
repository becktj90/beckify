import Foundation

/// One display band of a microphone spectrum. Relative dBFS, not SPL.
public struct AcousticDisplayBand: Equatable, Sendable {
    public var lowHz: Double
    public var highHz: Double
    public var centerHz: Double
    public var dbFS: Double

    public init(lowHz: Double, highHz: Double, centerHz: Double, dbFS: Double) {
        self.lowHz = lowHz
        self.highHz = highHz
        self.centerHz = centerHz
        self.dbFS = dbFS
    }
}

/// Fold a real-FFT magnitude vector into log-spaced audible bands and a
/// left/right energy balance. This is a field visualization aid.
///
/// It is not ultrasonic beamforming, not a bearing, and not a calibrated
/// sound level meter. The phone microphone and the sample rate set the band.
public enum AcousticSpectrum {
    /// Display ceiling. Energy above this is not claimed, even if the FFT has bins there.
    public static let audibleCeilingHz: Double = 8_000
    public static let displayFloorDBFS: Double = -80

    public static func bandEdges(
        count: Int,
        sampleRate: Double,
        ceilingHz: Double = audibleCeilingHz
    ) -> [(low: Double, high: Double)] {
        let n = max(1, count)
        let nyquist = sampleRate > 0 ? sampleRate / 2 : 0
        let hi = min(ceilingHz, nyquist)
        let lo = 40.0
        guard hi > lo + 1 else {
            return [(low: lo, high: max(hi, lo + 1))]
        }
        let logLo = log(lo)
        let logHi = log(hi)
        return (0..<n).map { index in
            let a = logLo + (logHi - logLo) * Double(index) / Double(n)
            let b = logLo + (logHi - logLo) * Double(index + 1) / Double(n)
            return (low: exp(a), high: exp(b))
        }
    }

    /// `linearMagnitudes[k]` is FFT bin k at `k * sampleRate / fftLength`.
    /// Each band keeps the peak bin inside it, then converts to dBFS with
    /// `20·log10(2·mag / N)` so a full-scale tone sits near 0 dBFS.
    public static func fold(
        linearMagnitudes: [Double],
        sampleRate: Double,
        fftLength: Int,
        bandCount: Int = 24
    ) -> [AcousticDisplayBand] {
        guard sampleRate > 0, fftLength > 1, !linearMagnitudes.isEmpty else { return [] }
        let edges = bandEdges(count: bandCount, sampleRate: sampleRate)
        return edges.map { edge in
            var peak = 0.0
            for (index, magnitude) in linearMagnitudes.enumerated() {
                let hz = Double(index) * sampleRate / Double(fftLength)
                guard hz >= edge.low, hz < edge.high else { continue }
                if magnitude.isFinite, magnitude > peak { peak = magnitude }
            }
            let center = sqrt(edge.low * edge.high)
            return AcousticDisplayBand(
                lowHz: edge.low,
                highHz: edge.high,
                centerHz: center,
                dbFS: dbFS(linearMagnitude: peak, fftLength: fftLength)
            )
        }
    }

    public static func dbFS(linearMagnitude: Double, fftLength: Int) -> Double {
        guard linearMagnitude.isFinite, linearMagnitude > 0, fftLength > 0 else {
            return SoundLevel.silenceFloorDBFS
        }
        let normalized = 2 * linearMagnitude / Double(fftLength)
        return SoundLevel.dbfs(rms: normalized)
    }

    public static func peakBand(_ bands: [AcousticDisplayBand]) -> AcousticDisplayBand? {
        bands.max { $0.dbFS < $1.dbFS }
    }

    /// Right-minus-left energy, −1…+1. `nil` when either channel is missing or both are silent.
    /// This is channel balance, not a bearing and not angle-of-arrival.
    public static func channelBalance(leftRMS: Double, rightRMS: Double) -> Double? {
        guard leftRMS.isFinite, rightRMS.isFinite, leftRMS >= 0, rightRMS >= 0 else { return nil }
        let sum = leftRMS + rightRMS
        guard sum > 1e-6 else { return nil }
        return max(-1, min(1, (rightRMS - leftRMS) / sum))
    }

    /// 0…1 heat for a level map. Floor and ceiling are display stops, not SPL limits.
    public static func heat(
        dbFS: Double,
        floor: Double = displayFloorDBFS,
        ceiling: Double = -3
    ) -> Double {
        guard dbFS.isFinite, ceiling > floor else { return 0 }
        return max(0, min(1, (dbFS - floor) / (ceiling - floor)))
    }
}
