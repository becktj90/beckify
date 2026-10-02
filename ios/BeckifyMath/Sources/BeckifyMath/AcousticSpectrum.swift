import Foundation

/// One display band of a microphone spectrum. Relative dBFS, not SPL.
///
/// `isAvailable` is false when the band has no usable bins or is noise-floor
/// dominated. Unavailable bands must not be drawn as a fake silence floor.
public struct AcousticDisplayBand: Equatable, Sendable {
    public var lowHz: Double
    public var highHz: Double
    public var centerHz: Double
    /// Relative peak amplitude in the band, as dBFS, when `isAvailable`.
    public var dbFS: Double
    /// False when empty or noise-dominated. Do not invent a floor for plots.
    public var isAvailable: Bool

    public init(
        lowHz: Double,
        highHz: Double,
        centerHz: Double,
        dbFS: Double,
        isAvailable: Bool = true
    ) {
        self.lowHz = lowHz
        self.highHz = highHz
        self.centerHz = centerHz
        self.dbFS = dbFS
        self.isAvailable = isAvailable
    }
}

/// Fold a real-FFT magnitude vector into log-spaced audible bands.
/// This is a field visualization of level, spectrum, and time activity.
///
/// It is not ultrasonic beamforming, not a leak position, and not a calibrated
/// sound level meter. The phone microphone and the sample rate set the band.
///
/// # Real-FFT magnitude contract
///
/// `linearMagnitudes[k]` is the **one-sided peak amplitude** of bin `k`
/// (same units as the time-domain samples). Index `k` is
/// `k * sampleRate / fftLength`. Bin 0 is DC; the last bin may be Nyquist
/// when `count == fftLength/2 + 1`.
///
/// Producers (Accelerate `vDSP_fft_zrip` or a reference DFT) must:
/// 1. Unpack Apple’s packed real format — after a forward `vDSP_fft_zrip`,
///    `realp[0]` is DC and `imagp[0]` is Nyquist (both real). Do **not** run
///    `vDSP_zvmags` on the packed split; that mixes DC with Nyquist in bin 0.
/// 2. Divide by `N * coherentGain` (mean of the analysis window). Hann’s
///    coherent gain is 0.5; a rectangular window is 1.0.
/// 3. Multiply non-DC / non-Nyquist bins by 2 so a full-scale sine of amplitude
///    `A` lands near amplitude `A` in its bin (one-sided spectrum).
///
/// `dbFS(amplitude:)` is then `20·log10(amplitude)`. A full-scale tone sits
/// near 0 dBFS. Band folding uses peak amplitude inside the band (display),
/// while RTA power helpers may sum `mag²` across bins.
public enum AcousticSpectrum {
    /// Display ceiling. Energy above this is not claimed, even if the FFT has bins there.
    public static let audibleCeilingHz: Double = 8_000
    public static let displayFloorDBFS: Double = -80
    /// Top of the spectrum heat scale. A display stop, not 0 dB SPL.
    public static let displayCeilingDBFS: Double = -3
    /// Bands quieter than this relative to the loudest band in the same fold
    /// are marked unavailable (noise-dominated), not drawn as a fake floor.
    public static let noiseDominatedMarginDB: Double = 48

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

    /// Mean of the analysis window. Divide FFT bins by `N * coherentGain`.
    public static func coherentGain(window: [Double]) -> Double {
        let finite = window.filter(\.isFinite)
        guard !finite.isEmpty else { return 1 }
        let mean = finite.reduce(0, +) / Double(finite.count)
        return mean > 1e-12 ? mean : 1
    }

    public static func coherentGain(count: Int, kind: SpectrumWindowKind) -> Double {
        coherentGain(window: CoupledVibrationMath.window(count: count, kind: kind))
    }

    /// Convert a **raw** packed-style bin magnitude (pre-normalization) into
    /// one-sided peak amplitude. `isNyquistOrDC` skips the ×2 factor.
    public static func amplitudeFromRawVDSP(
        rawMagnitude: Double,
        fftLength: Int,
        coherentGain: Double,
        isNyquistOrDC: Bool
    ) -> Double {
        guard rawMagnitude.isFinite, rawMagnitude > 0, fftLength > 0 else { return 0 }
        let gain = coherentGain.isFinite && coherentGain > 1e-12 ? coherentGain : 1
        let scale = Double(fftLength) * gain
        guard scale > 0 else { return 0 }
        let oneSided = isNyquistOrDC ? 1.0 : 2.0
        return oneSided * rawMagnitude / scale
    }

    /// `linearMagnitudes[k]` is peak amplitude at `k * sampleRate / fftLength`
    /// (see type doc). Empty / noise-dominated bands are `isAvailable == false`.
    public static func fold(
        linearMagnitudes: [Double],
        sampleRate: Double,
        fftLength: Int,
        bandCount: Int = 24
    ) -> [AcousticDisplayBand] {
        guard sampleRate > 0, fftLength > 1, !linearMagnitudes.isEmpty else { return [] }
        let edges = bandEdges(count: bandCount, sampleRate: sampleRate)
        var drafted: [(edge: (low: Double, high: Double), peak: Double, bins: Int)] = []
        drafted.reserveCapacity(edges.count)
        for edge in edges {
            var peak = 0.0
            var bins = 0
            for (index, magnitude) in linearMagnitudes.enumerated() {
                let hz = Double(index) * sampleRate / Double(fftLength)
                guard hz >= edge.low, hz < edge.high else { continue }
                bins += 1
                if magnitude.isFinite, magnitude > peak { peak = magnitude }
            }
            drafted.append((edge, peak, bins))
        }
        let loudest = drafted.map(\.peak).filter { $0.isFinite && $0 > 0 }.max() ?? 0
        let loudestDB = loudest > 0 ? dbFS(amplitude: loudest) : SoundLevel.silenceFloorDBFS
        return drafted.map { item in
            let center = sqrt(item.edge.low * item.edge.high)
            let empty = item.bins == 0 || item.peak <= 0 || !item.peak.isFinite
            let level = empty ? SoundLevel.silenceFloorDBFS : dbFS(amplitude: item.peak)
            let noiseDominated = !empty
                && loudest > 0
                && level.isFinite
                && (loudestDB - level) >= noiseDominatedMarginDB
            let available = !empty && !noiseDominated
            return AcousticDisplayBand(
                lowHz: item.edge.low,
                highHz: item.edge.high,
                centerHz: center,
                dbFS: available ? level : SoundLevel.silenceFloorDBFS,
                isAvailable: available
            )
        }
    }

    /// Peak-amplitude → dBFS. Full-scale tone ≈ 0 dBFS. Prefer this over the
    /// legacy `fftLength` overload once magnitudes are amplitude-normalized.
    public static func dbFS(amplitude: Double) -> Double {
        guard amplitude.isFinite, amplitude > 0 else { return SoundLevel.silenceFloorDBFS }
        return SoundLevel.dbfs(rms: amplitude)
    }

    /// Legacy helper for **already amplitude-normalized** magnitudes.
    /// `fftLength` is retained for call-site compatibility; it is not applied
    /// again (normalization belongs in the FFT producer — see type doc).
    public static func dbFS(linearMagnitude: Double, fftLength: Int) -> Double {
        _ = fftLength
        return dbFS(amplitude: linearMagnitude)
    }

    public static func peakBand(_ bands: [AcousticDisplayBand]) -> AcousticDisplayBand? {
        bands.filter(\.isAvailable).max { $0.dbFS < $1.dbFS }
    }

    /// Right-minus-left energy, −1…+1. `nil` when either channel is missing or both are silent.
    /// Stereo energy ratio only. Not a bearing, not a leak position, and not shown in the imager.
    public static func channelBalance(leftRMS: Double, rightRMS: Double) -> Double? {
        guard leftRMS.isFinite, rightRMS.isFinite, leftRMS >= 0, rightRMS >= 0 else { return nil }
        let sum = leftRMS + rightRMS
        guard sum > 1e-6 else { return nil }
        return max(-1, min(1, (rightRMS - leftRMS) / sum))
    }

    /// 0…1 heat for a level map. Floor and ceiling are display stops, not SPL limits.
    /// Unavailable / non-finite levels return 0 without claiming a measured floor.
    public static func heat(
        dbFS: Double,
        floor: Double = displayFloorDBFS,
        ceiling: Double = displayCeilingDBFS,
        isAvailable: Bool = true
    ) -> Double {
        guard isAvailable, dbFS.isFinite, ceiling > floor else { return 0 }
        return max(0, min(1, (dbFS - floor) / (ceiling - floor)))
    }
}
