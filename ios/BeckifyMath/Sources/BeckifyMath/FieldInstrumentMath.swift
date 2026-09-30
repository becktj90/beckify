import Foundation

// MARK: - Stillness Anomaly Watch

/// Channels on the stillness watch. `phoneMoved` is a gate, not an anomaly.
public enum StillnessChannel: String, CaseIterable, Sendable, Equatable, Hashable, Identifiable {
    case magnetic
    case pressure
    case micImpulse
    case bleAdvertisers
    case phoneMoved

    public var id: String { rawValue }

    /// Sensor channels that can be anomalies. The bump gate is separate.
    public static let anomalyChannels: [StillnessChannel] = [
        .magnetic, .pressure, .micImpulse, .bleAdvertisers,
    ]

    public var title: String {
        switch self {
        case .magnetic: return "Magnetometer"
        case .pressure: return "Barometer"
        case .micImpulse: return "Mic impulse"
        case .bleAdvertisers: return "BLE advertisers"
        case .phoneMoved: return "Phone moved"
        }
    }
}

/// One BLE advertiser. Identity is the peripheral id iOS already rotates.
/// This is not a person, a name, or an occupancy count.
public struct StillnessAdvertiser: Equatable, Sendable, Hashable {
    public var id: String
    public var rssi: Double

    public init(id: String, rssi: Double) {
        self.id = id
        self.rssi = rssi
    }
}

public struct StillnessBaseline: Equatable, Sendable {
    public var magneticMicrotesla: Double
    public var pressureKilopascals: Double
    public var noiseFloorDBFS: Double
    public var advertisers: [StillnessAdvertiser]

    public init(
        magneticMicrotesla: Double,
        pressureKilopascals: Double,
        noiseFloorDBFS: Double,
        advertisers: [StillnessAdvertiser]
    ) {
        self.magneticMicrotesla = magneticMicrotesla
        self.pressureKilopascals = pressureKilopascals
        self.noiseFloorDBFS = noiseFloorDBFS
        self.advertisers = advertisers
    }
}

public struct StillnessSample: Equatable, Sendable {
    public var magneticMicrotesla: Double?
    public var pressureKilopascals: Double?
    public var micDBFS: Double?
    /// Nil means this tick has no BLE scan. An empty list is a scan that saw no advertisers.
    public var advertisers: [StillnessAdvertiser]?
    public var userAccelerationG: Double?

    public init(
        magneticMicrotesla: Double? = nil,
        pressureKilopascals: Double? = nil,
        micDBFS: Double? = nil,
        advertisers: [StillnessAdvertiser]? = nil,
        userAccelerationG: Double? = nil
    ) {
        self.magneticMicrotesla = magneticMicrotesla
        self.pressureKilopascals = pressureKilopascals
        self.micDBFS = micDBFS
        self.advertisers = advertisers
        self.userAccelerationG = userAccelerationG
    }
}

public struct StillnessThresholds: Equatable, Sendable {
    public var magneticMicrotesla: Double
    public var pressurePascals: Double
    public var micImpulseDB: Double
    public var bleRSSIJumpDB: Double
    public var bumpG: Double
    public var bumpHoldSeconds: Double

    public init(
        magneticMicrotesla: Double,
        pressurePascals: Double,
        micImpulseDB: Double,
        bleRSSIJumpDB: Double,
        bumpG: Double,
        bumpHoldSeconds: Double
    ) {
        self.magneticMicrotesla = magneticMicrotesla
        self.pressurePascals = pressurePascals
        self.micImpulseDB = micImpulseDB
        self.bleRSSIJumpDB = bleRSSIJumpDB
        self.bumpG = bumpG
        self.bumpHoldSeconds = bumpHoldSeconds
    }

    /// Field defaults. DC |B| steps of several µT, HVAC-scale pascals,
    /// a clear mic rise, a BLE RSSI step, and a bump that is not hand tremor.
    public static let standard = StillnessThresholds(
        magneticMicrotesla: 8,
        pressurePascals: 15,
        micImpulseDB: 12,
        bleRSSIJumpDB: 12,
        bumpG: 0.30,
        bumpHoldSeconds: 0.40
    )
}

public struct StillnessVerdict: Equatable, Sendable {
    public var phoneMoved: Bool
    /// Anomaly channels only. Empty while the phone-moved gate is active.
    public var anomalies: [StillnessChannel]
    public var magneticDeltaMicrotesla: Double?
    public var pressureDeltaPascals: Double?
    public var micAboveFloorDB: Double?
    public var advertisersAdded: Int
    public var advertisersLost: Int
    public var maxAbsRSSIJumpDB: Double?
    public var advertiserCount: Int

    public init(
        phoneMoved: Bool,
        anomalies: [StillnessChannel],
        magneticDeltaMicrotesla: Double?,
        pressureDeltaPascals: Double?,
        micAboveFloorDB: Double?,
        advertisersAdded: Int,
        advertisersLost: Int,
        maxAbsRSSIJumpDB: Double?,
        advertiserCount: Int
    ) {
        self.phoneMoved = phoneMoved
        self.anomalies = anomalies
        self.magneticDeltaMicrotesla = magneticDeltaMicrotesla
        self.pressureDeltaPascals = pressureDeltaPascals
        self.micAboveFloorDB = micAboveFloorDB
        self.advertisersAdded = advertisersAdded
        self.advertisersLost = advertisersLost
        self.maxAbsRSSIJumpDB = maxAbsRSSIJumpDB
        self.advertiserCount = advertiserCount
    }

    /// Timeline channels. A bump replaces sensor crossings so the bump is not an anomaly.
    public var activeChannels: [StillnessChannel] {
        if phoneMoved { return [.phoneMoved] }
        return anomalies
    }
}

public struct StillnessMark: Equatable, Sendable {
    public var timeSeconds: Double
    public var channel: StillnessChannel
    public var detail: String

    public init(timeSeconds: Double, channel: StillnessChannel, detail: String) {
        self.timeSeconds = timeSeconds
        self.channel = channel
        self.detail = detail
    }
}

public struct StillnessBLEChurn: Equatable, Sendable {
    public var added: Int
    public var lost: Int
    public var maxAbsRSSIJumpDB: Double?
    public var changed: Bool

    public init(added: Int, lost: Int, maxAbsRSSIJumpDB: Double?, changed: Bool) {
        self.added = added
        self.lost = lost
        self.maxAbsRSSIJumpDB = maxAbsRSSIJumpDB
        self.changed = changed
    }
}

public enum StillnessWatchMath {
    /// Shown on the tool. Keep the denials. Do not soften them into a detector claim.
    public static let honestLimit =
        "Not a ghost detector. Not a presence meter. Not an EMF meter, Trifield, live-wire finder, or RF/5G meter. Magnetometer is DC field only. BLE marks mean advertisers changed, not occupancy."

    /// Stay crossed until the reading falls to this fraction of the trip threshold.
    public static let releaseFactor = 0.7

    public static func pressureDeltaPascals(liveKilopascals: Double, baselineKilopascals: Double) -> Double {
        (liveKilopascals - baselineKilopascals) * 1_000
    }

    /// Strongest finite RSSI per id. Empty ids are dropped. RSSI is a radio reading, not a person.
    public static func indexedAdvertisers(_ advertisers: [StillnessAdvertiser]) -> [String: Double] {
        var out: [String: Double] = [:]
        for advertiser in advertisers {
            let id = advertiser.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, advertiser.rssi.isFinite else { continue }
            if let existing = out[id] {
                out[id] = max(existing, advertiser.rssi)
            } else {
                out[id] = advertiser.rssi
            }
        }
        return out
    }

    public static func bleChurn(
        live: [StillnessAdvertiser],
        baseline: [StillnessAdvertiser],
        rssiJumpDB: Double
    ) -> StillnessBLEChurn {
        let now = indexedAdvertisers(live)
        let then = indexedAdvertisers(baseline)
        let added = now.keys.filter { then[$0] == nil }.count
        let lost = then.keys.filter { now[$0] == nil }.count
        var maxJump: Double?
        for (id, rssi) in now {
            guard let before = then[id] else { continue }
            let jump = abs(rssi - before)
            guard jump.isFinite else { continue }
            maxJump = max(maxJump ?? jump, jump)
        }
        let jumpCrossed = (maxJump ?? 0) >= rssiJumpDB && (maxJump?.isFinite == true)
        let changed = added > 0 || lost > 0 || jumpCrossed
        return StillnessBLEChurn(
            added: added,
            lost: lost,
            maxAbsRSSIJumpDB: maxJump,
            changed: changed
        )
    }

    public static func evaluate(
        sample: StillnessSample,
        baseline: StillnessBaseline?,
        thresholds: StillnessThresholds = .standard,
        nowSeconds: Double,
        lastBumpSeconds: Double?,
        previousAnomalies: Set<StillnessChannel> = []
    ) -> (verdict: StillnessVerdict, lastBumpSeconds: Double?) {
        var bumpTime = lastBumpSeconds
        var moved = false
        if let accel = sample.userAccelerationG, accel.isFinite, accel >= thresholds.bumpG {
            moved = true
            bumpTime = nowSeconds
        } else if let bumpTime, thresholds.bumpHoldSeconds > 0,
                  nowSeconds.isFinite, nowSeconds >= bumpTime {
            let elapsed = nowSeconds - bumpTime
            // 1 ms slack so a 0.40 s literal is not held by binary rounding.
            moved = elapsed >= 0 && elapsed + 0.001 < thresholds.bumpHoldSeconds
        }

        var magDelta: Double?
        var magCross = false
        if let baseline, let live = sample.magneticMicrotesla,
           live.isFinite, baseline.magneticMicrotesla.isFinite {
            let delta = live - baseline.magneticMicrotesla
            magDelta = delta
            magCross = sustained(
                magnitude: abs(delta),
                threshold: thresholds.magneticMicrotesla,
                wasCrossed: previousAnomalies.contains(.magnetic)
            )
        }

        var pressureDelta: Double?
        var pressureCross = false
        if let baseline, let live = sample.pressureKilopascals,
           live.isFinite, baseline.pressureKilopascals.isFinite {
            let delta = pressureDeltaPascals(liveKilopascals: live, baselineKilopascals: baseline.pressureKilopascals)
            pressureDelta = delta
            pressureCross = sustained(
                magnitude: abs(delta),
                threshold: thresholds.pressurePascals,
                wasCrossed: previousAnomalies.contains(.pressure)
            )
        }

        var micAbove: Double?
        var micCross = false
        if let baseline, let live = sample.micDBFS,
           live.isFinite, baseline.noiseFloorDBFS.isFinite {
            let delta = live - baseline.noiseFloorDBFS
            micAbove = delta
            micCross = sustained(
                magnitude: delta,
                threshold: thresholds.micImpulseDB,
                wasCrossed: previousAnomalies.contains(.micImpulse)
            )
        }

        var added = 0
        var lost = 0
        var jump: Double?
        var bleCross = false
        var advertiserCount = 0
        if let live = sample.advertisers {
            advertiserCount = indexedAdvertisers(live).count
            if let baseline {
                let churn = bleChurn(
                    live: live,
                    baseline: baseline.advertisers,
                    rssiJumpDB: thresholds.bleRSSIJumpDB
                )
                added = churn.added
                lost = churn.lost
                jump = churn.maxAbsRSSIJumpDB
                bleCross = churn.changed
            }
        }

        var anomalies: [StillnessChannel] = []
        if !moved {
            if magCross { anomalies.append(.magnetic) }
            if pressureCross { anomalies.append(.pressure) }
            if micCross { anomalies.append(.micImpulse) }
            if bleCross { anomalies.append(.bleAdvertisers) }
        }

        let verdict = StillnessVerdict(
            phoneMoved: moved,
            anomalies: anomalies,
            magneticDeltaMicrotesla: magDelta,
            pressureDeltaPascals: pressureDelta,
            micAboveFloorDB: micAbove,
            advertisersAdded: added,
            advertisersLost: lost,
            maxAbsRSSIJumpDB: jump,
            advertiserCount: advertiserCount
        )
        return (verdict, bumpTime)
    }

    /// Trip at `threshold`. Once crossed, release only below `releaseFactor * threshold`.
    static func sustained(magnitude: Double, threshold: Double, wasCrossed: Bool) -> Bool {
        guard magnitude.isFinite, threshold.isFinite else { return false }
        if wasCrossed { return magnitude >= threshold * releaseFactor }
        return magnitude >= threshold
    }

    public static func detail(channel: StillnessChannel, verdict: StillnessVerdict) -> String {
        switch channel {
        case .magnetic:
            guard let delta = verdict.magneticDeltaMicrotesla, delta.isFinite else { return "Δ|B|" }
            return String(format: "Δ|B| %+.1f µT", delta)
        case .pressure:
            guard let delta = verdict.pressureDeltaPascals, delta.isFinite else { return "ΔP" }
            return String(format: "ΔP %+.0f Pa", delta)
        case .micImpulse:
            guard let delta = verdict.micAboveFloorDB, delta.isFinite else { return "impulse" }
            return String(format: "impulse %+.1f dB", delta)
        case .bleAdvertisers:
            let jump: String
            if let value = verdict.maxAbsRSSIJumpDB, value.isFinite {
                jump = String(format: ", RSSI jump %.0f dB", value)
            } else {
                jump = ""
            }
            return "advertisers +\(verdict.advertisersAdded) / −\(verdict.advertisersLost)\(jump)"
        case .phoneMoved:
            return "phone moved"
        }
    }

    /// Rising edges only, so a channel that stays over threshold is one timeline row.
    public static func risingMarks(
        previous: Set<StillnessChannel>,
        verdict: StillnessVerdict,
        timeSeconds: Double
    ) -> (marks: [StillnessMark], active: Set<StillnessChannel>) {
        let active = Set(verdict.activeChannels)
        let marks = StillnessChannel.allCases.compactMap { channel -> StillnessMark? in
            guard active.contains(channel), !previous.contains(channel) else { return nil }
            return StillnessMark(
                timeSeconds: timeSeconds,
                channel: channel,
                detail: detail(channel: channel, verdict: verdict)
            )
        }
        return (marks, active)
    }
}

// MARK: - Mag Sweep

public enum MagSweepMath {
    public static let traceLimit = 80

    public static let honestLimit =
        "DC magnetometer only. The phone’s own magnets dominate |B|. Not a stud finder, not a live-wire detector, and not a 60 Hz EMF meter."

    /// Slow spectrum of |B| change. Not an AC mains or EMI meter.
    public static let variationSpectrumLabel =
        "Field variation spectrum (DC magnetometer, not AC EMF / not a 50–60 Hz power-line meter)."

    /// Signed |B| minus the captured baseline, in µT.
    public static func deltaMicrotesla(magnitude: Double, baseline: Double) -> Double? {
        guard magnitude.isFinite, baseline.isFinite else { return nil }
        return magnitude - baseline
    }

    /// Peak hold of the absolute deviation. Non-finite samples leave the peak unchanged.
    public static func peakHold(delta: Double, peak: Double) -> Double {
        guard delta.isFinite else { return peak.isFinite ? peak : 0 }
        let magnitude = abs(delta)
        guard peak.isFinite else { return magnitude }
        return max(peak, magnitude)
    }

    public static func appendTrace(_ trace: [Double], sample: Double, limit: Int = traceLimit) -> [Double] {
        guard sample.isFinite, limit > 0 else { return trace }
        var next = trace
        next.append(sample)
        if next.count > limit {
            next.removeFirst(next.count - limit)
        }
        return next
    }
}

// MARK: - Breath Flute

public enum BreathFluteMath {
    public static let marginDB = 12.0
    /// G3. Bottom of the touch pad.
    public static let lowHz = 196.0
    /// C6. Top of the touch pad.
    public static let highHz = 1_046.5
    /// C4. Fret 0.
    public static let rootHz = 261.625565

    public static let honestLimit =
        "Play tool. Blow gates a tone on this phone. Nothing is recorded or uploaded. Not a meter, tuner, or SLM."

    public static func gateOpen(
        rmsDBFS: Double,
        peakDBFS: Double,
        noiseFloorDBFS: Double,
        marginDB: Double = marginDB
    ) -> Bool {
        guard rmsDBFS.isFinite, peakDBFS.isFinite, noiseFloorDBFS.isFinite, marginDB.isFinite else {
            return false
        }
        return (rmsDBFS - noiseFloorDBFS) > marginDB || (peakDBFS - noiseFloorDBFS) > marginDB
    }

    /// 0 at the bottom of the pad, 1 at the top. Pitch is exponential so octaves stay even.
    public static func frequencyHz(touchY: Double, lowHz: Double = lowHz, highHz: Double = highHz) -> Double {
        guard lowHz.isFinite, highHz.isFinite, lowHz > 0, highHz > lowHz else { return .nan }
        let y = min(1, max(0, touchY.isFinite ? touchY : 0))
        let logLo = log(lowHz)
        let logHi = log(highHz)
        return exp(logLo + (logHi - logLo) * y)
    }

    /// Equal temperament from `rootHz`. Fret 12 is one octave up.
    public static func fretFrequencyHz(fret: Int, rootHz: Double = rootHz) -> Double {
        guard rootHz.isFinite, rootHz > 0 else { return .nan }
        return rootHz * pow(2, Double(fret) / 12)
    }

    public static func levelDBFS(samples: [Float]) -> (rms: Double, peak: Double) {
        var sum = 0.0
        var peak = 0.0
        var count = 0
        for sample in samples {
            let value = Double(sample)
            guard value.isFinite else { continue }
            sum += value * value
            peak = max(peak, abs(value))
            count += 1
        }
        guard count > 0 else {
            return (SoundLevel.silenceFloorDBFS, SoundLevel.silenceFloorDBFS)
        }
        return (SoundLevel.dbfs(rms: sqrt(sum / Double(count))), SoundLevel.dbfs(rms: peak))
    }

    /// Quiet air eases the floor. A blow does not raise it.
    public static func updateNoiseFloor(currentDBFS: Double, floor: Double?, marginDB: Double = marginDB) -> Double {
        guard currentDBFS.isFinite else { return floor ?? SoundLevel.silenceFloorDBFS }
        guard let floor, floor.isFinite else { return currentDBFS }
        if currentDBFS > floor + marginDB * 0.5 {
            return floor
        }
        let alpha = currentDBFS < floor ? 0.15 : 0.02
        return floor + (currentDBFS - floor) * alpha
    }

    /// Louder blows are a little louder. Below the gate margin the amplitude is silence.
    public static func amplitude(aboveFloorDB: Double, marginDB: Double = marginDB) -> Double {
        guard aboveFloorDB.isFinite, marginDB.isFinite, aboveFloorDB >= marginDB else { return 0 }
        let t = min(1, max(0, (aboveFloorDB - marginDB) / 24))
        return 0.08 + 0.18 * t
    }

    /// One sine sample. Phase is radians and wraps to `[0, 2π)`.
    public static func sineSample(
        phase: Double,
        frequencyHz: Double,
        sampleRate: Double,
        amplitude: Double
    ) -> (sample: Double, nextPhase: Double) {
        let rate = sampleRate.isFinite && sampleRate > 0 ? sampleRate : 44_100
        let hz = frequencyHz.isFinite && frequencyHz > 0 ? frequencyHz : 0
        let amp = amplitude.isFinite ? min(1, max(0, amplitude)) : 0
        let current = phase.isFinite ? phase : 0
        let sample = sin(current) * amp
        let twoPi = 2 * Double.pi
        var next = current + twoPi * hz / rate
        next = next.truncatingRemainder(dividingBy: twoPi)
        if next < 0 { next += twoPi }
        return (sample, next)
    }
}

// MARK: - Coupled Vibration

public struct VibrationBand: Equatable, Sendable {
    public var lowHz: Double
    public var highHz: Double
    public var centerHz: Double
    public var magnitudeG: Double

    public init(lowHz: Double, highHz: Double, centerHz: Double, magnitudeG: Double) {
        self.lowHz = lowHz
        self.highHz = highHz
        self.centerHz = centerHz
        self.magnitudeG = magnitudeG
    }
}

public struct VibrationSignature: Equatable, Sendable {
    public var rmsG: Double
    public var sampleRateHz: Double
    public var bands: [VibrationBand]
    public var peakHz: Double?
    public var peakMagnitudeG: Double?

    public init(
        rmsG: Double,
        sampleRateHz: Double,
        bands: [VibrationBand],
        peakHz: Double?,
        peakMagnitudeG: Double?
    ) {
        self.rmsG = rmsG
        self.sampleRateHz = sampleRateHz
        self.bands = bands
        self.peakHz = peakHz
        self.peakMagnitudeG = peakMagnitudeG
    }
}

public struct VibrationComparison: Equatable, Sendable {
    public var rmsA: Double
    public var rmsB: Double
    /// Session B minus session A.
    public var rmsDelta: Double
    public var bandDeltas: [Double]
    public var peakShiftHz: Double?

    public init(
        rmsA: Double,
        rmsB: Double,
        rmsDelta: Double,
        bandDeltas: [Double],
        peakShiftHz: Double?
    ) {
        self.rmsA = rmsA
        self.rmsB = rmsB
        self.rmsDelta = rmsDelta
        self.bandDeltas = bandDeltas
        self.peakShiftHz = peakShiftHz
    }
}

/// FFT window. Hann is the default. Hamming and Blackman are optional shapes, not calibrations.
public enum SpectrumWindowKind: String, CaseIterable, Sendable {
    case hann
    case hamming
    case blackman

    public var title: String {
        switch self {
        case .hann: return "Hann"
        case .hamming: return "Hamming"
        case .blackman: return "Blackman"
        }
    }
}

/// Rough leftover energy in a microphone magnitude spectrum.
/// Not THD, not dB SPL, and not a transformer nameplate figure.
public enum RelativeHarmonicEnergy {
    public static let honestLimit =
        "Rough relative harmonic energy from this microphone FFT. Not THD, not dB SPL, and not a transformer nameplate."

    /// 0…1. Energy outside the peak bin ±1, divided by total energy above DC.
    /// Nil when the spectrum has no usable peak.
    public static func ratio(linearMagnitudes: [Double]) -> Double? {
        guard linearMagnitudes.count >= 4 else { return nil }
        var peakIndex: Int?
        var peakValue = 0.0
        for (index, value) in linearMagnitudes.enumerated() where index > 0 {
            guard value.isFinite, value > peakValue else { continue }
            peakValue = value
            peakIndex = index
        }
        guard let peakIndex, peakValue > 0 else { return nil }
        var peakEnergy = 0.0
        var total = 0.0
        for (index, value) in linearMagnitudes.enumerated() where index > 0 && value.isFinite && value > 0 {
            let energy = value * value
            total += energy
            if abs(index - peakIndex) <= 1 { peakEnergy += energy }
        }
        guard total > 0, peakEnergy > 0 else { return nil }
        return max(0, min(1, (total - peakEnergy) / total))
    }
}

public enum CoupledVibrationMath {
    public static let honestLimit =
        "Relative signature of this phone’s user acceleration. Not ISO 10816 and not a calibrated pickup."

    public static let rpmDisclaimer =
        "Relative / phone-mounted helper (frequency × 60). Not a tachometer, not ISO 10816, and not a bearing-fault diagnosis."

    public static func nyquistHz(sampleRateHz: Double) -> Double? {
        guard sampleRateHz.isFinite, sampleRateHz > 0 else { return nil }
        return sampleRateHz / 2
    }

    /// Only for a peak you already measured on this mount. Nil when the frequency is unusable.
    public static func relativeRPM(frequencyHz: Double) -> Double? {
        guard frequencyHz.isFinite, frequencyHz > 0 else { return nil }
        return frequencyHz * 60
    }

    public static func rms(_ samples: [Double]) -> Double {
        let finite = samples.filter(\.isFinite)
        guard !finite.isEmpty else { return .nan }
        let meanSquare = finite.reduce(0) { $0 + $1 * $1 } / Double(finite.count)
        return sqrt(meanSquare)
    }

    /// `(count - 1) / duration` for a uniform series. Nil when the span is unusable.
    public static func sampleRateHz(count: Int, durationSeconds: Double) -> Double? {
        guard count >= 2, durationSeconds.isFinite, durationSeconds > 0 else { return nil }
        return Double(count - 1) / durationSeconds
    }

    public static func hannWindow(count: Int) -> [Double] {
        window(count: count, kind: .hann)
    }

    public static func window(count: Int, kind: SpectrumWindowKind = .hann) -> [Double] {
        guard count > 1 else { return count == 1 ? [1] : [] }
        let span = Double(count - 1)
        return (0..<count).map { index in
            let phase = 2 * Double.pi * Double(index) / span
            let raw: Double
            switch kind {
            case .hann:
                raw = 0.5 - 0.5 * cos(phase)
            case .hamming:
                raw = 0.54 - 0.46 * cos(phase)
            case .blackman:
                raw = 0.42 - 0.5 * cos(phase) + 0.08 * cos(2 * phase)
            }
            return raw > 0 ? raw : 0
        }
    }

    /// One-sided windowed DFT magnitudes, same units as `samples`.
    /// Index `k` is `k * sampleRate / N`. DC is bin 0. Hann unless another window is passed.
    /// This is not a calibrated spectrum.
    public static func magnitudeSpectrum(samples: [Double], window kind: SpectrumWindowKind = .hann) -> [Double] {
        let clean = samples.filter(\.isFinite)
        let n = clean.count
        guard n >= 4 else { return [] }
        let window = window(count: n, kind: kind)
        let windowSum = window.reduce(0, +)
        guard windowSum > 0 else { return [] }
        let binCount = n / 2 + 1
        var magnitudes = Array(repeating: 0.0, count: binCount)
        for k in 0..<binCount {
            var real = 0.0
            var imag = 0.0
            for index in 0..<n {
                let angle = -2 * Double.pi * Double(k * index) / Double(n)
                let weighted = window[index] * clean[index]
                real += weighted * cos(angle)
                imag += weighted * sin(angle)
            }
            let magnitude = sqrt(real * real + imag * imag)
            let nyquistBin = n % 2 == 0 && k == n / 2
            if k == 0 || nyquistBin {
                magnitudes[k] = magnitude / windowSum
            } else {
                magnitudes[k] = 2 * magnitude / windowSum
            }
        }
        return magnitudes
    }

    /// Bin with the largest magnitude above DC.
    public static func peakBin(samples: [Double], sampleRateHz: Double) -> (hz: Double, magnitude: Double)? {
        guard sampleRateHz.isFinite, sampleRateHz > 0 else { return nil }
        let magnitudes = magnitudeSpectrum(samples: samples)
        guard magnitudes.count > 1 else { return nil }
        var bestK = 1
        var best = magnitudes[1]
        for k in 2..<magnitudes.count where magnitudes[k] > best {
            best = magnitudes[k]
            bestK = k
        }
        guard best.isFinite, best > 0 else { return nil }
        let n = samples.filter(\.isFinite).count
        guard n > 0 else { return nil }
        return (Double(bestK) * sampleRateHz / Double(n), best)
    }

    public static func signature(
        samples: [Double],
        sampleRateHz: Double,
        bandCount: Int = 8
    ) -> VibrationSignature? {
        let clean = samples.filter(\.isFinite)
        guard clean.count >= 16, sampleRateHz.isFinite, sampleRateHz > 0 else { return nil }
        let magnitudes = magnitudeSpectrum(samples: clean)
        guard magnitudes.count > 1 else { return nil }
        let n = clean.count
        let nyquist = sampleRateHz / 2
        let count = max(1, bandCount)
        var bands: [VibrationBand] = []
        for index in 0..<count {
            let low = nyquist * Double(index) / Double(count)
            let high = nyquist * Double(index + 1) / Double(count)
            var peak = 0.0
            for k in 1..<magnitudes.count {
                let hz = Double(k) * sampleRateHz / Double(n)
                let inBand = hz >= low && (hz < high || (index == count - 1 && hz <= high + 1e-9))
                guard inBand else { continue }
                if magnitudes[k] > peak { peak = magnitudes[k] }
            }
            bands.append(VibrationBand(
                lowHz: low,
                highHz: high,
                centerHz: (low + high) / 2,
                magnitudeG: peak
            ))
        }
        let rmsValue = rms(clean)
        let peakBand = bands.max { $0.magnitudeG < $1.magnitudeG }
        let hasPeak = (peakBand?.magnitudeG ?? 0) > 0
        return VibrationSignature(
            rmsG: rmsValue,
            sampleRateHz: sampleRateHz,
            bands: bands,
            peakHz: hasPeak ? peakBand?.centerHz : nil,
            peakMagnitudeG: hasPeak ? peakBand?.magnitudeG : nil
        )
    }

    /// Session B relative to session A. Band deltas require the same band count.
    public static func compare(_ a: VibrationSignature, _ b: VibrationSignature) -> VibrationComparison? {
        guard a.rmsG.isFinite, b.rmsG.isFinite else { return nil }
        let shift: Double?
        if let peakA = a.peakHz, let peakB = b.peakHz, peakA.isFinite, peakB.isFinite {
            shift = peakB - peakA
        } else {
            shift = nil
        }
        let deltas: [Double]
        if a.bands.count == b.bands.count, !a.bands.isEmpty {
            deltas = zip(a.bands, b.bands).map { $1.magnitudeG - $0.magnitudeG }
        } else {
            deltas = []
        }
        return VibrationComparison(
            rmsA: a.rmsG,
            rmsB: b.rmsG,
            rmsDelta: b.rmsG - a.rmsG,
            bandDeltas: deltas,
            peakShiftHz: shift
        )
    }
}
