import Foundation

// MARK: - Pure-Swift FFT (radix-2)

/// Minimal iterative Cooley-Tukey FFT. Pure Swift so it runs in the Ubuntu
/// `swift test` CI for this package (no Accelerate / vDSP on Linux).
/// Every entry point requires a power-of-two length and returns the input
/// unchanged when that does not hold, rather than crashing.
public enum RoomRigFFT {
    public static func isPowerOfTwo(_ n: Int) -> Bool {
        n > 0 && (n & (n - 1)) == 0
    }

    /// Smallest power of two that is `>= n`. Returns 1 for `n <= 1`.
    public static func nextPowerOfTwo(atLeast n: Int) -> Int {
        guard n > 1 else { return 1 }
        var p = 1
        while p < n { p <<= 1 }
        return p
    }

    public static func forward(real: [Double], imag: [Double]) -> (real: [Double], imag: [Double]) {
        guard real.count == imag.count, isPowerOfTwo(real.count) else { return (real, imag) }
        var r = real
        var i = imag
        transform(real: &r, imag: &i, invert: false)
        return (r, i)
    }

    /// Normalized inverse (divides by N), so `inverse(forward(x)) == x`.
    public static func inverse(real: [Double], imag: [Double]) -> (real: [Double], imag: [Double]) {
        guard real.count == imag.count, isPowerOfTwo(real.count) else { return (real, imag) }
        var r = real
        var i = imag
        transform(real: &r, imag: &i, invert: true)
        return (r, i)
    }

    public static func magnitude(real: [Double], imag: [Double]) -> [Double] {
        guard real.count == imag.count else { return [] }
        return zip(real, imag).map { re, im in (re * re + im * im).squareRoot() }
    }

    /// In-place iterative radix-2 decimation-in-time transform.
    private static func transform(real: inout [Double], imag: inout [Double], invert: Bool) {
        let n = real.count
        guard n > 1 else { return }

        var j = 0
        for i in 1..<n {
            var bit = n >> 1
            while bit > 0, j & bit != 0 {
                j ^= bit
                bit >>= 1
            }
            j ^= bit
            if i < j {
                real.swapAt(i, j)
                imag.swapAt(i, j)
            }
        }

        var len = 2
        while len <= n {
            let angle = (invert ? 2 : -2) * Double.pi / Double(len)
            let wr = cos(angle)
            let wi = sin(angle)
            var i = 0
            while i < n {
                var curWr = 1.0
                var curWi = 0.0
                let half = len / 2
                for k in 0..<half {
                    let evenIndex = i + k
                    let oddIndex = evenIndex + half
                    let ur = real[evenIndex]
                    let ui = imag[evenIndex]
                    let vr = real[oddIndex] * curWr - imag[oddIndex] * curWi
                    let vi = real[oddIndex] * curWi + imag[oddIndex] * curWr
                    real[evenIndex] = ur + vr
                    imag[evenIndex] = ui + vi
                    real[oddIndex] = ur - vr
                    imag[oddIndex] = ui - vi
                    let nextWr = curWr * wr - curWi * wi
                    let nextWi = curWr * wi + curWi * wr
                    curWr = nextWr
                    curWi = nextWi
                }
                i += len
            }
            len <<= 1
        }

        if invert {
            for i in 0..<n {
                real[i] /= Double(n)
                imag[i] /= Double(n)
            }
        }
    }
}

/// FFT-based linear convolution, used to deconvolve a recorded sweep.
public enum RoomRigConvolution {
    /// Linear (not circular) convolution. Result length is `a.count + b.count - 1`.
    public static func convolve(_ a: [Double], _ b: [Double]) -> [Double] {
        guard !a.isEmpty, !b.isEmpty else { return [] }
        let resultLength = a.count + b.count - 1
        let n = max(2, RoomRigFFT.nextPowerOfTwo(atLeast: resultLength))
        let ar = a + [Double](repeating: 0, count: n - a.count)
        let br = b + [Double](repeating: 0, count: n - b.count)
        let zeros = [Double](repeating: 0, count: n)

        let A = RoomRigFFT.forward(real: ar, imag: zeros)
        let B = RoomRigFFT.forward(real: br, imag: zeros)

        var productReal = [Double](repeating: 0, count: n)
        var productImag = [Double](repeating: 0, count: n)
        for k in 0..<n {
            productReal[k] = A.real[k] * B.real[k] - A.imag[k] * B.imag[k]
            productImag[k] = A.real[k] * B.imag[k] + A.imag[k] * B.real[k]
        }

        let product = RoomRigFFT.inverse(real: productReal, imag: productImag)
        return Array(product.real.prefix(resultLength))
    }
}

// MARK: - Exponential sweep measurement (Farina method)

/// Deconvolved sweep measurement: an exponential ("log") sine sweep plus its
/// matched inverse filter recover a system impulse response from a single
/// recorded pass. This is the honest basis for a *measured* frequency
/// response — not the coarse pink-noise RTA bands used elsewhere in RigScope.
///
/// Still phone mic + phone (or external) speaker: not an anechoic chamber,
/// not a calibrated measurement mic. See `RoomRigSetupScore.honestLimit`.
public enum ExponentialSweepMeasurement {
    /// Exponential sine sweep from `startHz` to `endHz` over `duration` seconds.
    public static func sweep(startHz: Double, endHz: Double, duration: Double, sampleRate: Double) -> [Double] {
        guard startHz.isFinite, endHz.isFinite, duration.isFinite, sampleRate.isFinite,
              startHz > 0, endHz > startHz, duration > 0, sampleRate > 0
        else { return [] }
        let n = Int((duration * sampleRate).rounded())
        guard n > 1 else { return [] }
        let sweepRateK = duration / log(endHz / startHz)
        var samples = [Double](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let phase = 2 * Double.pi * startHz * sweepRateK * (exp(t / sweepRateK) - 1)
            samples[i] = sin(phase)
        }
        return samples
    }

    /// Time-reversed sweep with an amplitude envelope that cancels the
    /// sweep's own amplitude growth, so convolving a recorded response with
    /// this filter compresses the sweep back into an impulse (Farina 2000).
    public static func inverseFilter(startHz: Double, endHz: Double, duration: Double, sampleRate: Double) -> [Double] {
        let x = sweep(startHz: startHz, endHz: endHz, duration: duration, sampleRate: sampleRate)
        guard !x.isEmpty, endHz > startHz, startHz > 0, duration > 0 else { return [] }
        let n = x.count
        let ratio = log(endHz / startHz)
        var filt = [Double](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let envelope = exp(-t * ratio / duration)
            filt[n - 1 - i] = x[i] * envelope
        }
        let maxAbs = filt.map(abs).max() ?? 0
        guard maxAbs.isFinite, maxAbs > 1e-12 else { return filt }
        return filt.map { $0 / maxAbs }
    }

    /// Deconvolve a recorded sweep response into an impulse response.
    /// Normalized to a unit peak — a shape, not a level.
    public static func impulseResponse(recorded: [Double], inverseFilter: [Double]) -> [Double] {
        let raw = RoomRigConvolution.convolve(recorded, inverseFilter)
        guard !raw.isEmpty else { return raw }
        let peak = raw.map(abs).max() ?? 0
        guard peak.isFinite, peak > 1e-12 else { return raw }
        return raw.map { $0 / peak }
    }

    /// Index of the main (linear) impulse peak. The Farina method also
    /// produces earlier, smaller harmonic-distortion impulses; this reports
    /// only the dominant linear peak, not a harmonic breakdown.
    public static func peakIndex(impulseResponse: [Double]) -> Int? {
        guard !impulseResponse.isEmpty else { return nil }
        var bestIndex: Int?
        var bestMagnitude = -Double.infinity
        for (index, value) in impulseResponse.enumerated() where value.isFinite {
            let magnitude = abs(value)
            if magnitude > bestMagnitude {
                bestMagnitude = magnitude
                bestIndex = index
            }
        }
        return bestIndex
    }

    /// Frequency response (relative dB, peak-normalized) from a slice of the
    /// impulse response starting at its main peak.
    public static func frequencyResponse(
        impulseResponse: [Double],
        sampleRate: Double,
        windowSamples: Int = 8_192
    ) -> [RoomRigPoint] {
        guard sampleRate.isFinite, sampleRate > 0, !impulseResponse.isEmpty,
              let peak = peakIndex(impulseResponse: impulseResponse)
        else { return [] }
        let n = max(2, RoomRigFFT.nextPowerOfTwo(atLeast: windowSamples))
        // A *right-sided* taper: flat across the direct-sound onset at the
        // window's start (a symmetric Hann would zero out the very impulse
        // peak this window starts at), tapering to zero only at the far end
        // to limit truncation leakage.
        let taper = rightSidedTaper(count: n)
        var windowed = [Double](repeating: 0, count: n)
        for i in 0..<n {
            let sourceIndex = peak + i
            guard sourceIndex < impulseResponse.count else { break }
            windowed[i] = impulseResponse[sourceIndex] * taper[i]
        }
        let imag = [Double](repeating: 0, count: n)
        let transformed = RoomRigFFT.forward(real: windowed, imag: imag)
        let magnitudes = RoomRigFFT.magnitude(real: transformed.real, imag: transformed.imag)
        let bins = n / 2
        guard bins > 1 else { return [] }
        var points: [RoomRigPoint] = []
        points.reserveCapacity(bins)
        for k in 1..<bins {
            guard magnitudes[k].isFinite, magnitudes[k] > 0 else { continue }
            let hz = Double(k) * sampleRate / Double(n)
            points.append(RoomRigPoint(hz: hz, db: 20 * log10(magnitudes[k])))
        }
        return RoomRigMath.normalizeToPeak(points)
    }

    /// 1.0 for the first `flatFraction` of the window, raised-cosine down to
    /// 0.0 by the last sample. Unlike a symmetric Hann window, this never
    /// damages sample 0 — the direct-sound impulse this window is built to start on.
    private static func rightSidedTaper(count: Int, flatFraction: Double = 0.1) -> [Double] {
        guard count > 1 else { return count == 1 ? [1] : [] }
        let flatCount = max(1, min(count - 1, Int(Double(count) * flatFraction)))
        var taper = [Double](repeating: 1, count: count)
        let tailCount = count - flatCount
        guard tailCount > 1 else { return taper }
        for i in 0..<tailCount {
            let phase = Double.pi * Double(i) / Double(tailCount - 1)
            taper[flatCount + i] = 0.5 + 0.5 * cos(phase)
        }
        return taper
    }
}

// MARK: - Decay estimate

/// Schroeder-integration decay curve and an early-decay time estimate from a
/// deconvolved impulse response. This is a same-phone, single-position
/// estimate — not a certified ISO 3382 RT60 and highly sensitive to mic
/// placement and background noise.
public enum RoomRigDecayMath {
    /// Backward-integrated energy decay curve in dB, normalized to 0 dB at
    /// the impulse peak. Index 0 is the peak; the curve is non-increasing.
    public static func schroederDecayCurveDB(impulseResponse: [Double]) -> [Double] {
        guard let peak = ExponentialSweepMeasurement.peakIndex(impulseResponse: impulseResponse),
              peak < impulseResponse.count
        else { return [] }
        var energies = impulseResponse[peak...].map { $0 * $0 }
        guard !energies.isEmpty else { return [] }
        var runningTotal = 0.0
        for i in stride(from: energies.count - 1, through: 0, by: -1) {
            runningTotal += energies[i]
            energies[i] = runningTotal
        }
        guard let total = energies.first, total.isFinite, total > 1e-18 else { return [] }
        return energies.map { 10 * log10(max($0, 1e-18) / total) }
    }

    /// Time for the curve to fall from −5 dB to −15 dB, ×6 (an "early decay
    /// time"-style estimate). Not a certified RT60. `nil` when the curve
    /// never reaches both thresholds (too short a capture, or too noisy).
    public static func earlyDecayEstimateSeconds(decayCurveDB: [Double], sampleRate: Double) -> Double? {
        guard sampleRate.isFinite, sampleRate > 0, decayCurveDB.count > 2 else { return nil }
        guard let startIndex = decayCurveDB.firstIndex(where: { $0 <= -5 }),
              let endIndex = decayCurveDB.firstIndex(where: { $0 <= -15 }),
              endIndex > startIndex
        else { return nil }
        let seconds = Double(endIndex - startIndex) / sampleRate
        guard seconds.isFinite, seconds > 0 else { return nil }
        return seconds * 6
    }
}

// MARK: - Background / mains hum

/// Mains-hum indicator from an FFT magnitude vector. Not a calibrated hum
/// or buzz measurement — a same-phone relative indicator only.
public enum RoomRigHumMath {
    /// Energy at the mains frequency and its first `harmonics` multiples,
    /// relative to the total band energy, in dB. More negative is quieter.
    /// `nil` when none of the mains bins are resolvable at this FFT length.
    public static func mainsHumRelativeEnergyDB(
        linearMagnitudes: [Double],
        sampleRate: Double,
        fftLength: Int,
        mainsHz: Double = 60,
        harmonics: Int = 3
    ) -> Double? {
        guard sampleRate.isFinite, sampleRate > 0, fftLength > 1,
              !linearMagnitudes.isEmpty, mainsHz.isFinite, mainsHz > 0, harmonics >= 1
        else { return nil }
        let binHz = sampleRate / Double(fftLength)
        func power(at hz: Double) -> Double? {
            let bin = Int((hz / binHz).rounded())
            guard bin > 0, bin < linearMagnitudes.count,
                  linearMagnitudes[bin].isFinite, linearMagnitudes[bin] > 0
            else { return nil }
            return linearMagnitudes[bin] * linearMagnitudes[bin]
        }
        var humPower = 0.0
        var humHits = 0
        for order in 1...harmonics {
            if let p = power(at: mainsHz * Double(order)) {
                humPower += p
                humHits += 1
            }
        }
        guard humHits > 0 else { return nil }
        let totalPower = linearMagnitudes.reduce(0.0) { partial, magnitude in
            guard magnitude.isFinite, magnitude > 0 else { return partial }
            return partial + magnitude * magnitude
        }
        guard totalPower > 1e-18 else { return nil }
        return 10 * log10(humPower / totalPower)
    }
}

// MARK: - Setup Score

/// Nominal weights for the RigScope Setup Score. They sum to 1.0; when a
/// sub-score is unavailable its weight is excluded from the overall average
/// and reported via `RoomRigSetupScoreResult.coverage` instead of being
/// silently folded into the remaining metrics at full strength.
public enum RoomRigSetupScoreWeight {
    public static let tonalFit = 0.35
    public static let bassSeatConsistency = 0.25
    public static let leftRightMatch = 0.20
    public static let decay = 0.15
    public static let background = 0.05
}

/// One weighted component of the Setup Score, 0...100.
public struct RoomRigSubScore: Equatable, Sendable {
    public var label: String
    public var value: Double
    /// Nominal weight (0...1) this component contributes when present.
    public var weight: Double
    /// Honest one-line description of the raw measured number behind `value`.
    public var rawMetricLabel: String

    public init(label: String, value: Double, weight: Double, rawMetricLabel: String) {
        self.label = label
        self.value = max(0, min(100, value))
        self.weight = weight
        self.rawMetricLabel = rawMetricLabel
    }
}

/// Raw measurements feeding the Setup Score. Any field left `nil` is a
/// measurement that has not been taken yet — it lowers coverage, not the score.
public struct RoomRigSetupScoreInputs: Equatable, Sendable {
    /// RMS deviation (dB) of the measured response from the listening-purpose
    /// target shape, one-third-octave, after peak normalization.
    public var tonalDeviationDB: Double?
    /// Spread (dB) of low-band (<250 Hz) level across repeated passes at one seat.
    public var bassSeatSpreadDB: Double?
    /// Average |Left − Right| band deviation (dB) between two separately
    /// measured speaker passes.
    public var leftRightDeviationDB: Double?
    /// Early-decay estimate in seconds (`RoomRigDecayMath`).
    public var earlyDecaySeconds: Double?
    /// Mains-hum relative energy in dB (`RoomRigHumMath`).
    public var mainsHumRelativeDB: Double?

    public init(
        tonalDeviationDB: Double? = nil,
        bassSeatSpreadDB: Double? = nil,
        leftRightDeviationDB: Double? = nil,
        earlyDecaySeconds: Double? = nil,
        mainsHumRelativeDB: Double? = nil
    ) {
        self.tonalDeviationDB = tonalDeviationDB
        self.bassSeatSpreadDB = bassSeatSpreadDB
        self.leftRightDeviationDB = leftRightDeviationDB
        self.earlyDecaySeconds = earlyDecaySeconds
        self.mainsHumRelativeDB = mainsHumRelativeDB
    }
}

public struct RoomRigSetupScoreResult: Equatable, Sendable {
    /// 0...100, `nil` when no sub-score has a measurement yet.
    public var overall: Double?
    public var tonalFit: RoomRigSubScore?
    public var bassSeatConsistency: RoomRigSubScore?
    public var leftRightMatch: RoomRigSubScore?
    public var decay: RoomRigSubScore?
    public var background: RoomRigSubScore?
    /// Fraction (0...1) of the nominal weight actually backed by a
    /// measurement. Show this next to the score — never fold it in silently.
    public var coverage: Double

    public init(
        overall: Double? = nil,
        tonalFit: RoomRigSubScore? = nil,
        bassSeatConsistency: RoomRigSubScore? = nil,
        leftRightMatch: RoomRigSubScore? = nil,
        decay: RoomRigSubScore? = nil,
        background: RoomRigSubScore? = nil,
        coverage: Double = 0
    ) {
        self.overall = overall
        self.tonalFit = tonalFit
        self.bassSeatConsistency = bassSeatConsistency
        self.leftRightMatch = leftRightMatch
        self.decay = decay
        self.background = background
        self.coverage = coverage
    }

    public var subScores: [RoomRigSubScore] {
        [tonalFit, bassSeatConsistency, leftRightMatch, decay, background].compactMap { $0 }
    }
}

/// Weighted RigScope "Setup Score" — tonal fit 35%, bass/seat consistency
/// 25%, L/R matching 20%, decay 15%, background/hum 5%.
///
/// Every sub-score is a relative A/B heuristic on this phone's mic and
/// speaker. None of it is a certified acoustic standard: no ISO 3382 RT60,
/// no Harman or THX target curve, no calibrated SPL. A missing measurement
/// lowers `coverage`, never the score itself.
public enum RoomRigSetupScore {
    public static let honestLimit =
        "Setup Score is a relative A/B heuristic from this phone's mic and speaker — not a certified acoustic standard. Missing measurements lower coverage, not the score."

    /// Linear ramp: `metric` at or below `good` scores 100; at or beyond
    /// `bad` scores 0; linear between. `good` and `bad` may be in either order.
    private static func rampScore(metric: Double, good: Double, bad: Double) -> Double {
        guard metric.isFinite, good.isFinite, bad.isFinite, good != bad else { return 50 }
        let t = (metric - good) / (bad - good)
        return max(0, min(100, 100 * (1 - t)))
    }

    public static func tonalFitScore(deviationDB: Double) -> Double {
        rampScore(metric: abs(deviationDB), good: 0, bad: 10)
    }

    public static func bassSeatConsistencyScore(spreadDB: Double) -> Double {
        rampScore(metric: abs(spreadDB), good: 0, bad: 12)
    }

    public static func leftRightMatchScore(deviationDB: Double) -> Double {
        rampScore(metric: abs(deviationDB), good: 0, bad: 6)
    }

    /// Scored around a neutral ~0.3 s; strays either shorter (very dead) or
    /// longer (very live) both pull the score down.
    public static func decayScore(earlyDecaySeconds seconds: Double) -> Double {
        rampScore(metric: abs(seconds - 0.3), good: 0, bad: 0.6)
    }

    public static func backgroundScore(mainsHumRelativeDB value: Double) -> Double {
        rampScore(metric: value, good: -40, bad: -5)
    }

    public static func score(_ inputs: RoomRigSetupScoreInputs) -> RoomRigSetupScoreResult {
        var result = RoomRigSetupScoreResult()

        if let d = inputs.tonalDeviationDB {
            result.tonalFit = RoomRigSubScore(
                label: "Tonal fit",
                value: tonalFitScore(deviationDB: d),
                weight: RoomRigSetupScoreWeight.tonalFit,
                rawMetricLabel: String(format: "%.1f dB RMS deviation from the listening-purpose target shape", abs(d))
            )
        }
        if let s = inputs.bassSeatSpreadDB {
            result.bassSeatConsistency = RoomRigSubScore(
                label: "Bass / seat consistency",
                value: bassSeatConsistencyScore(spreadDB: s),
                weight: RoomRigSetupScoreWeight.bassSeatConsistency,
                rawMetricLabel: String(format: "%.1f dB spread in low-band level across passes at this seat", abs(s))
            )
        }
        if let l = inputs.leftRightDeviationDB {
            result.leftRightMatch = RoomRigSubScore(
                label: "L / R matching",
                value: leftRightMatchScore(deviationDB: l),
                weight: RoomRigSetupScoreWeight.leftRightMatch,
                rawMetricLabel: String(format: "%.1f dB average difference between the left and right speaker passes", abs(l))
            )
        }
        if let t = inputs.earlyDecaySeconds {
            result.decay = RoomRigSubScore(
                label: "Decay",
                value: decayScore(earlyDecaySeconds: t),
                weight: RoomRigSetupScoreWeight.decay,
                rawMetricLabel: String(format: "%.2f s early-decay estimate (not a certified RT60)", t)
            )
        }
        if let h = inputs.mainsHumRelativeDB {
            result.background = RoomRigSubScore(
                label: "Background / hum",
                value: backgroundScore(mainsHumRelativeDB: h),
                weight: RoomRigSetupScoreWeight.background,
                rawMetricLabel: String(format: "%.1f dB mains-hum energy relative to total band energy", h)
            )
        }

        let subScores = result.subScores
        let totalWeight = subScores.reduce(0.0) { $0 + $1.weight }
        guard totalWeight > 1e-9 else {
            result.overall = nil
            result.coverage = 0
            return result
        }
        let weightedSum = subScores.reduce(0.0) { $0 + $1.value * $1.weight }
        result.overall = weightedSum / totalWeight
        result.coverage = min(1, totalWeight)
        return result
    }
}
