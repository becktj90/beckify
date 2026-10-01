import Foundation

/// One relative spectrum sample. Decibels are dBFS or dB versus the curve peak — never dB SPL.
public struct RoomRigPoint: Equatable, Sendable {
    public var hz: Double
    public var db: Double

    public init(hz: Double, db: Double) {
        self.hz = hz
        self.db = db
    }
}

/// Relative energy at an integer multiple of a known tone. Not lab THD.
public struct RoomRigHarmonic: Equatable, Sendable {
    public var order: Int
    public var hz: Double
    /// Power in the nearest bin divided by power at the fundamental. 1 is equal energy.
    public var relativeEnergy: Double

    public init(order: Int, hz: Double, relativeEnergy: Double) {
        self.order = order
        self.hz = hz
        self.relativeEnergy = relativeEnergy
    }
}

/// One microphone frame, reduced to honest relative numbers.
public struct RoomRigFrameStats: Equatable, Sendable {
    public var rmsDBFS: Double
    public var peakDBFS: Double
    /// 20·log10(peak / RMS). Nil when the frame is silent.
    public var crestDB: Double?
    /// Fraction of samples at or beyond the full-scale threshold.
    public var clipFraction: Double
    public var linearRMS: Double
    public var linearPeak: Double

    public init(
        rmsDBFS: Double,
        peakDBFS: Double,
        crestDB: Double?,
        clipFraction: Double,
        linearRMS: Double,
        linearPeak: Double
    ) {
        self.rmsDBFS = rmsDBFS
        self.peakDBFS = peakDBFS
        self.crestDB = crestDB
        self.clipFraction = clipFraction
        self.linearRMS = linearRMS
        self.linearPeak = linearPeak
    }
}

/// What Room & Rig Check may play from the phone speaker while the shared mic tap listens.
public enum RoomRigStimulusKind: String, CaseIterable, Sendable {
    case listen
    case pink
    case sweep
    case burst

    public var title: String {
        switch self {
        case .listen: return "Listen"
        case .pink: return "Pink"
        case .sweep: return "Sweep"
        case .burst: return "Burst"
        }
    }
}

/// Room and rig helpers for Room & Rig Check.
///
/// Every number here is relative to this phone’s speaker and microphone.
/// It is not a calibrated measurement microphone, not REW, and not a THX certificate.
/// Do not turn these into absolute dB SPL.
public enum RoomRigMath {
    public static let honestLimit =
        "Phone speaker and mic, relative A/B and trends only. Not a calibrated measurement mic, not REW, not THX, and not absolute dB SPL."

    public static let sweepStartHz = 80.0
    public static let sweepEndHz = 8_000.0
    public static let sweepDuration = 8.0
    public static let burstHz = 1_000.0
    public static let burstLength = 2_048
    public static let playbackAmplitude = 0.12
    public static let clipThreshold = 0.98
    public static let latencyMaxSeconds = 0.75
    /// Live plot FFT. Short enough for responsive UI.
    public static let liveFFTLength = 1_024
    /// Optional overlapping bass analysis windows. Prefer 16384; 32768 when the ring allows.
    public static let bassFFTLengthPreferred = 16_384
    public static let bassFFTLengthLong = 32_768
    /// Headroom barrier: peak above this aborts an in-flight capture.
    public static let headroomAbortDBFS = -0.5
    public static let clipAbortFraction = 0.01

    /// Nominal 1/3-octave centers from 50 Hz through 8 kHz. Display bands, not IEC 61260 class.
    public static let thirdOctaveCenters: [Double] = [
        50, 63, 80, 100, 125, 160, 200, 250, 315, 400,
        500, 630, 800, 1_000, 1_250, 1_600, 2_000, 2_500,
        3_150, 4_000, 5_000, 6_300, 8_000,
    ]

    public static func thirdOctaveEdges(centerHz: Double) -> (low: Double, high: Double)? {
        guard centerHz.isFinite, centerHz > 0 else { return nil }
        let half = pow(2, 1.0 / 6.0)
        return (centerHz / half, centerHz * half)
    }

    /// Log sweep frequency. `elapsed` outside the duration wraps so a looping player stays in range.
    public static func sweepHz(
        elapsed: Double,
        duration: Double = sweepDuration,
        startHz: Double = sweepStartHz,
        endHz: Double = sweepEndHz
    ) -> Double {
        guard startHz.isFinite, endHz.isFinite, startHz > 0, endHz > startHz else { return .nan }
        let span = duration.isFinite && duration > 0 ? duration : sweepDuration
        let time = elapsed.isFinite ? elapsed : 0
        let wrapped = time.truncatingRemainder(dividingBy: span)
        let t = (wrapped < 0 ? wrapped + span : wrapped) / span
        return exp(log(startHz) + (log(endHz) - log(startHz)) * t)
    }

    /// Raised-cosine gate. Index 0 and the last sample are 0; the middle is 1.
    public static func burstEnvelope(index: Int, length: Int) -> Double {
        guard length > 1, index >= 0, index < length else { return 0 }
        let phase = 2 * Double.pi * Double(index) / Double(length - 1)
        return 0.5 - 0.5 * cos(phase)
    }

    public static func frameStats(samples: [Double], clipThreshold: Double = clipThreshold) -> RoomRigFrameStats {
        var sum = 0.0
        var peak = 0.0
        var clipped = 0
        var count = 0
        let limit = clipThreshold.isFinite ? min(1, max(0, clipThreshold)) : Self.clipThreshold
        for sample in samples where sample.isFinite {
            let magnitude = abs(sample)
            sum += sample * sample
            peak = max(peak, magnitude)
            if magnitude >= limit { clipped += 1 }
            count += 1
        }
        guard count > 0 else {
            return RoomRigFrameStats(
                rmsDBFS: SoundLevel.silenceFloorDBFS,
                peakDBFS: SoundLevel.silenceFloorDBFS,
                crestDB: nil,
                clipFraction: 0,
                linearRMS: 0,
                linearPeak: 0
            )
        }
        let rms = sqrt(sum / Double(count))
        return RoomRigFrameStats(
            rmsDBFS: SoundLevel.dbfs(rms: rms),
            peakDBFS: SoundLevel.dbfs(rms: peak),
            crestDB: crestFactorDB(peakLinear: peak, rmsLinear: rms),
            clipFraction: Double(clipped) / Double(count),
            linearRMS: rms,
            linearPeak: peak
        )
    }

    public static func crestFactorDB(samples: [Double]) -> Double? {
        let stats = frameStats(samples: samples)
        return stats.crestDB
    }

    /// 20·log10(peak / RMS). A full-scale sine is about 3.01 dB. Nil when either value is unusable.
    public static func crestFactorDB(peakLinear: Double, rmsLinear: Double) -> Double? {
        guard peakLinear.isFinite, rmsLinear.isFinite, peakLinear > 0, rmsLinear > 0 else { return nil }
        return 20 * log10(peakLinear / rmsLinear)
    }

    public static func clipFraction(samples: [Double], threshold: Double = clipThreshold) -> Double {
        frameStats(samples: samples, clipThreshold: threshold).clipFraction
    }

    /// Sorted percentile in 0…1. Empty or non-finite input is nil.
    public static func percentile(_ values: [Double], p: Double) -> Double? {
        let finite = values.filter(\.isFinite).sorted()
        guard !finite.isEmpty, p.isFinite else { return nil }
        let clamped = min(1, max(0, p))
        let index = Int((Double(finite.count - 1) * clamped).rounded())
        return finite[min(finite.count - 1, max(0, index))]
    }

    /// Level minus a quiet-window floor, in dB. Nil when either side is unusable.
    public static func signalAboveFloorDB(levelDBFS: Double, floorDBFS: Double) -> Double? {
        guard levelDBFS.isFinite, floorDBFS.isFinite else { return nil }
        return levelDBFS - floorDBFS
    }

    /// Peak hold minus the quiet floor. Relative dynamic range on this phone, not a spec sheet.
    public static func relativeDynamicRangeDB(peakDBFS: Double, floorDBFS: Double) -> Double? {
        signalAboveFloorDB(levelDBFS: peakDBFS, floorDBFS: floorDBFS)
    }

    /// Speaker-to-mic delay. Nil when the capture leads the playhead or the gap is too long to trust.
    public static func latencySeconds(playedAt: Double, heardAt: Double, maxSeconds: Double = latencyMaxSeconds) -> Double? {
        guard playedAt.isFinite, heardAt.isFinite, maxSeconds.isFinite, maxSeconds > 0 else { return nil }
        let delta = heardAt - playedAt
        guard delta >= 0, delta <= maxSeconds else { return nil }
        return delta
    }

    /// First sample at or above `threshold`. Nil when the frame stays quiet.
    public static func onsetIndex(samples: [Double], threshold: Double) -> Int? {
        guard threshold.isFinite else { return nil }
        for (index, sample) in samples.enumerated() where sample.isFinite && abs(sample) >= threshold {
            return index
        }
        return nil
    }

    /// Approximate 1/3-octave energy bands. Not an IEC class filter bank.
    public static func thirdOctaveBands(
        linearMagnitudes: [Double],
        sampleRate: Double,
        fftLength: Int
    ) -> [AcousticDisplayBand] {
        guard sampleRate.isFinite, sampleRate > 0, fftLength > 1, !linearMagnitudes.isEmpty else { return [] }
        let nyquist = sampleRate / 2
        return thirdOctaveCenters.compactMap { center in
            guard let edges = thirdOctaveEdges(centerHz: center), edges.low < nyquist else { return nil }
            var energy = 0.0
            var bins = 0
            for (index, magnitude) in linearMagnitudes.enumerated() {
                let hz = Double(index) * sampleRate / Double(fftLength)
                guard hz >= edges.low, hz < edges.high, magnitude.isFinite, magnitude > 0 else { continue }
                energy += magnitude * magnitude
                bins += 1
            }
            let magnitude = bins > 0 ? sqrt(energy) : 0
            let available = bins > 0 && magnitude > 0 && magnitude.isFinite
            return AcousticDisplayBand(
                lowHz: edges.low,
                highHz: min(edges.high, nyquist),
                centerHz: center,
                dbFS: available
                    ? AcousticSpectrum.dbFS(amplitude: magnitude)
                    : SoundLevel.silenceFloorDBFS,
                isAvailable: available
            )
        }
    }

    /// Power at 2f, 3f, … versus power at f. Nil when the fundamental bin is empty.
    /// Same honesty as `RelativeHarmonicEnergy`: microphone FFT leftover, not THD.
    public static func harmonicOrders(
        linearMagnitudes: [Double],
        fundamentalHz: Double,
        sampleRate: Double,
        fftLength: Int,
        maxOrder: Int = 5
    ) -> [RoomRigHarmonic]? {
        guard fundamentalHz.isFinite, fundamentalHz > 0,
              sampleRate.isFinite, sampleRate > 0,
              fftLength > 1, linearMagnitudes.count > 2,
              maxOrder >= 2
        else { return nil }
        let binHz = sampleRate / Double(fftLength)
        func power(at hz: Double) -> Double {
            let bin = Int((hz / binHz).rounded())
            guard bin > 0, bin < linearMagnitudes.count else { return 0 }
            let magnitude = linearMagnitudes[bin]
            guard magnitude.isFinite, magnitude > 0 else { return 0 }
            return magnitude * magnitude
        }
        let fundamental = power(at: fundamentalHz)
        guard fundamental > 0 else { return nil }
        return (2...maxOrder).compactMap { order in
            let hz = fundamentalHz * Double(order)
            guard hz < sampleRate / 2 else { return nil }
            return RoomRigHarmonic(
                order: order,
                hz: hz,
                relativeEnergy: power(at: hz) / fundamental
            )
        }
    }

    /// Keep the latest level in the 1/3-octave bin that contains `hz`.
    public static func updateResponse(_ points: [RoomRigPoint], hz: Double, db: Double) -> [RoomRigPoint] {
        guard hz.isFinite, hz > 0, db.isFinite else { return points }
        guard let center = thirdOctaveCenters.min(by: { abs(log($0) - log(hz)) < abs(log($1) - log(hz)) }) else {
            return points
        }
        guard let edges = thirdOctaveEdges(centerHz: center), hz >= edges.low, hz < edges.high else {
            return points
        }
        var next = points.filter { abs($0.hz - center) > 0.5 }
        next.append(RoomRigPoint(hz: center, db: db))
        next.sort { $0.hz < $1.hz }
        return next
    }

    /// Shift the loudest point to 0 dB so the curve is a shape, not a level.
    public static func normalizeToPeak(_ points: [RoomRigPoint]) -> [RoomRigPoint] {
        let finite = points.filter { $0.hz.isFinite && $0.db.isFinite && $0.hz > 0 }
        guard let peak = finite.map(\.db).max() else { return [] }
        return finite.map { RoomRigPoint(hz: $0.hz, db: $0.db - peak) }
    }

    /// Average each point with neighbors inside ±1/6 octave (a 1/3-octave smooth).
    public static func smoothOneThirdOctave(_ points: [RoomRigPoint]) -> [RoomRigPoint] {
        let finite = points.filter { $0.hz.isFinite && $0.db.isFinite && $0.hz > 0 }.sorted { $0.hz < $1.hz }
        guard !finite.isEmpty else { return [] }
        let half = pow(2, 1.0 / 6.0)
        return finite.map { point in
            let low = point.hz / half
            let high = point.hz * half
            let neighbors = finite.filter { $0.hz >= low && $0.hz < high }
            let mean = neighbors.reduce(0.0) { $0 + $1.db } / Double(neighbors.count)
            return RoomRigPoint(hz: point.hz, db: mean)
        }
    }

    public static func appendSpectrogram(_ rows: [[Double]], row: [Double], limit: Int) -> [[Double]] {
        guard limit > 0, !row.isEmpty else { return rows }
        var next = rows
        next.append(row)
        if next.count > limit {
            next.removeFirst(next.count - limit)
        }
        return next
    }
}

// MARK: - Listen-and-test snapshot

/// Low / mid / high energy from an approximate RTA. Decibels are relative dBFS, not SPL.
public struct RoomRigBandBalance: Equatable, Sendable {
    public var lowDBFS: Double
    public var midDBFS: Double
    public var highDBFS: Double
    /// Each group minus the loudest group. Zero is the strongest group on this pass.
    public var lowVsLoudestDB: Double
    public var midVsLoudestDB: Double
    public var highVsLoudestDB: Double

    public init(
        lowDBFS: Double,
        midDBFS: Double,
        highDBFS: Double,
        lowVsLoudestDB: Double,
        midVsLoudestDB: Double,
        highVsLoudestDB: Double
    ) {
        self.lowDBFS = lowDBFS
        self.midDBFS = midDBFS
        self.highDBFS = highDBFS
        self.lowVsLoudestDB = lowVsLoudestDB
        self.midVsLoudestDB = midVsLoudestDB
        self.highVsLoudestDB = highVsLoudestDB
    }
}

/// One finished listen-and-test pass. Every number is relative to this phone.
public struct RoomRigTestSnapshot: Equatable, Sendable {
    public var stimulus: String
    public var durationSeconds: Double
    public var levelDBFS: Double
    public var peakDBFS: Double
    public var crestDB: Double?
    public var clipFraction: Double
    public var aboveFloorDB: Double?
    public var peakHz: Double?
    public var centroidHz: Double?
    public var balance: RoomRigBandBalance?

    public init(
        stimulus: String,
        durationSeconds: Double,
        levelDBFS: Double,
        peakDBFS: Double,
        crestDB: Double?,
        clipFraction: Double,
        aboveFloorDB: Double?,
        peakHz: Double?,
        centroidHz: Double?,
        balance: RoomRigBandBalance?
    ) {
        self.stimulus = stimulus
        self.durationSeconds = durationSeconds
        self.levelDBFS = levelDBFS
        self.peakDBFS = peakDBFS
        self.crestDB = crestDB
        self.clipFraction = clipFraction
        self.aboveFloorDB = aboveFloorDB
        self.peakHz = peakHz
        self.centroidHz = centroidHz
        self.balance = balance
    }
}

/// Samples gathered while a test is running. The live meters keep updating beside this.
public struct RoomRigTestCapture: Equatable, Sendable {
    public var levels: [Double]
    public var peaks: [Double]
    public var crests: [Double]
    public var clips: [Double]
    public var peakHz: [Double]
    public var bands: [AcousticDisplayBand]

    public init(
        levels: [Double] = [],
        peaks: [Double] = [],
        crests: [Double] = [],
        clips: [Double] = [],
        peakHz: [Double] = [],
        bands: [AcousticDisplayBand] = []
    ) {
        self.levels = levels
        self.peaks = peaks
        self.crests = crests
        self.clips = clips
        self.peakHz = peakHz
        self.bands = bands
    }

    public mutating func append(
        levelDBFS: Double,
        peakDBFS: Double,
        crestDB: Double?,
        clipFraction: Double,
        peakHz: Double?,
        bands: [AcousticDisplayBand]
    ) {
        if levelDBFS.isFinite { levels.append(levelDBFS) }
        if peakDBFS.isFinite { peaks.append(peakDBFS) }
        if let crestDB, crestDB.isFinite { crests.append(crestDB) }
        if clipFraction.isFinite { clips.append(min(1, max(0, clipFraction))) }
        if let peakHz, peakHz.isFinite, peakHz > 0 { self.peakHz.append(peakHz) }
        for band in bands where band.isAvailable && band.centerHz.isFinite && band.centerHz > 0 && band.dbFS.isFinite {
            self.bands.append(band)
        }
    }

    /// Nil until at least one level has arrived.
    public func snapshot(
        stimulus: String,
        durationSeconds: Double,
        floorDBFS: Double?
    ) -> RoomRigTestSnapshot? {
        guard let level = RoomRigTestMath.lowerMedian(levels) else { return nil }
        let peak = peaks.max() ?? level
        let crest = RoomRigTestMath.lowerMedian(crests)
        let clip = clips.isEmpty ? 0 : clips.reduce(0, +) / Double(clips.count)
        let above = floorDBFS.flatMap { RoomRigMath.signalAboveFloorDB(levelDBFS: level, floorDBFS: $0) }
        let averaged = RoomRigTestMath.averageBands(bands)
        return RoomRigTestSnapshot(
            stimulus: stimulus,
            durationSeconds: durationSeconds.isFinite ? max(0, durationSeconds) : 0,
            levelDBFS: level,
            peakDBFS: peak,
            crestDB: crest,
            clipFraction: clip,
            aboveFloorDB: above,
            peakHz: RoomRigTestMath.lowerMedian(self.peakHz),
            centroidHz: RoomRigTestMath.centroidHz(bands: averaged),
            balance: RoomRigTestMath.bandBalance(bands: averaged)
        )
    }
}

/// Plain-language notes for the listen-and-test numbers. Relative A/B only.
public enum RoomRigTestCopy {
    public static let level =
        "How loud this pass was on this phone, in relative dBFS. Use the same signal in two spots and compare. Not dB SPL."
    public static let peak =
        "The loudest moment in the window. If it sits near 0 dBFS, this mic overloaded and the A/B is not fair."
    public static let crest =
        "How much the peaks stick up above the typical level. Music is usually higher crest than pink noise. A big change between seats can mean the room, or that the song changed."
    public static let clip =
        "Share of the window at full scale. Any clip means it was too hot — turn it down and run the test again."
    public static let aboveFloor =
        "Signal above background: how far this pass sat above the captured quiet-room baseline. Not SNR. A small gap means the signal is barely out of the room noise on this mic."
    public static let signalAboveBackground = aboveFloor
    public static let baselineHelp =
        "Capture a quiet-room baseline explicitly. It invalidates if the audio route or input gain changes. Phone-speaker stimuli stay labeled demo."
    public static let peakHz =
        "The strongest band during the pass. On pink noise, a peak that moves between seats is a relative tilt, not a certified room mode."
    public static let centroid =
        "Where the spectrum balances. Higher means this pass was brighter on this mic. Compare seats. It is not a target curve."
    public static let balance =
        "Low, mid, and high from the approximate RTA. 0 dB is the strongest group on this pass. A seat that loses highs versus spot A is darker on this phone — not a lab RTA."
    public static let versusA =
        "This pass minus spot A, on this phone. Positive level means louder here. Not a calibrated difference."
}

public enum RoomRigTestMath {
    /// Long enough for one log sweep, short enough to hold the phone still.
    public static let windowSeconds = 8.0

    /// Lower median. An even count takes the lower of the two central samples.
    /// The index is integer division, so a two-sample window does not depend on
    /// whether `rounded()` sends 0.5 up or to even.
    public static func lowerMedian(_ values: [Double]) -> Double? {
        let finite = values.filter(\.isFinite).sorted()
        guard !finite.isEmpty else { return nil }
        return finite[(finite.count - 1) / 2]
    }

    /// Power-weighted center of the bands. Nil when there is no energy.
    public static func centroidHz(bands: [AcousticDisplayBand]) -> Double? {
        var weight = 0.0
        var moment = 0.0
        for band in bands where band.isAvailable && band.centerHz.isFinite && band.centerHz > 0 && band.dbFS.isFinite {
            let power = pow(10, band.dbFS / 10)
            guard power.isFinite, power > 0 else { continue }
            weight += power
            moment += band.centerHz * power
        }
        guard weight > 0 else { return nil }
        return moment / weight
    }

    /// Groups the approximate RTA into low (<250 Hz), mid, and high (≥2 kHz).
    public static func bandBalance(bands: [AcousticDisplayBand]) -> RoomRigBandBalance? {
        func energy(_ include: (Double) -> Bool) -> Double? {
            var sum = 0.0
            var hits = 0
            for band in bands where band.isAvailable && band.centerHz.isFinite && band.dbFS.isFinite && include(band.centerHz) {
                let power = pow(10, band.dbFS / 10)
                guard power.isFinite, power > 0 else { continue }
                sum += power
                hits += 1
            }
            guard hits > 0, sum > 0 else { return nil }
            return 10 * log10(sum / Double(hits))
        }
        guard let low = energy({ $0 < 250 }),
              let mid = energy({ $0 >= 250 && $0 < 2_000 }),
              let high = energy({ $0 >= 2_000 })
        else { return nil }
        let loudest = max(low, mid, high)
        return RoomRigBandBalance(
            lowDBFS: low,
            midDBFS: mid,
            highDBFS: high,
            lowVsLoudestDB: low - loudest,
            midVsLoudestDB: mid - loudest,
            highVsLoudestDB: high - loudest
        )
    }

    /// Mean power in each third-octave center, written back as dBFS.
    public static func averageBands(_ bands: [AcousticDisplayBand]) -> [AcousticDisplayBand] {
        var power: [Double: Double] = [:]
        var hits: [Double: Int] = [:]
        for band in bands where band.isAvailable && band.centerHz.isFinite && band.centerHz > 0 && band.dbFS.isFinite {
            let linear = pow(10, band.dbFS / 10)
            guard linear.isFinite, linear > 0 else { continue }
            power[band.centerHz, default: 0] += linear
            hits[band.centerHz, default: 0] += 1
        }
        return power.keys.sorted().compactMap { hz in
            guard let sum = power[hz], let count = hits[hz], count > 0, sum > 0 else { return nil }
            return AcousticDisplayBand(
                lowHz: hz,
                highHz: hz,
                centerHz: hz,
                dbFS: 10 * log10(sum / Double(count)),
                isAvailable: true
            )
        }
    }
}

// MARK: - Measurement foundation (PR1)

/// Audio route / gain fingerprint. A quiet baseline or A/B pass is invalid when this changes.
public struct RoomRigRouteFingerprint: Equatable, Sendable, Hashable {
    public var sampleRateHz: Double
    public var channelCount: Int
    /// AVAudioSession port / route name when known.
    public var routeUID: String
    /// Input gain when the session exposes it; otherwise 0.
    public var inputGain: Double

    public init(sampleRateHz: Double, channelCount: Int, routeUID: String, inputGain: Double) {
        self.sampleRateHz = sampleRateHz
        self.channelCount = channelCount
        self.routeUID = routeUID
        self.inputGain = inputGain
    }

    /// Coarse equality for protocol matching (gain rounded to 0.01).
    public func matches(_ other: RoomRigRouteFingerprint, gainTolerance: Double = 0.01) -> Bool {
        abs(sampleRateHz - other.sampleRateHz) < 0.5
            && channelCount == other.channelCount
            && routeUID == other.routeUID
            && abs(inputGain - other.inputGain) <= gainTolerance
    }
}

/// Explicit quiet-room baseline. Not SNR — signal-above-background uses this floor.
public struct RoomRigQuietBaseline: Equatable, Sendable {
    public var floorDBFS: Double
    public var bandFloorsDBFS: [Double]
    public var fingerprint: RoomRigRouteFingerprint
    public var sampleCount: UInt64
    public var capturedAt: Double

    public init(
        floorDBFS: Double,
        bandFloorsDBFS: [Double] = [],
        fingerprint: RoomRigRouteFingerprint,
        sampleCount: UInt64,
        capturedAt: Double
    ) {
        self.floorDBFS = floorDBFS
        self.bandFloorsDBFS = bandFloorsDBFS
        self.fingerprint = fingerprint
        self.sampleCount = sampleCount
        self.capturedAt = capturedAt
    }

    public func isValid(for fingerprint: RoomRigRouteFingerprint) -> Bool {
        self.fingerprint.matches(fingerprint) && floorDBFS.isFinite
    }
}

/// Locked for one capture pass. A/B requires matching metadata.
public struct RoomRigPassMetadata: Equatable, Sendable {
    public var stimulus: RoomRigStimulusKind
    public var fingerprint: RoomRigRouteFingerprint
    public var liveFFTLength: Int
    public var bassFFTLength: Int?
    public var windowKind: String
    /// Phone speaker stimuli are demos, not calibrated generators.
    public var isPhoneSpeakerDemo: Bool

    public init(
        stimulus: RoomRigStimulusKind,
        fingerprint: RoomRigRouteFingerprint,
        liveFFTLength: Int = RoomRigMath.liveFFTLength,
        bassFFTLength: Int? = nil,
        windowKind: String,
        isPhoneSpeakerDemo: Bool
    ) {
        self.stimulus = stimulus
        self.fingerprint = fingerprint
        self.liveFFTLength = liveFFTLength
        self.bassFFTLength = bassFFTLength
        self.windowKind = windowKind
        self.isPhoneSpeakerDemo = isPhoneSpeakerDemo
    }

    public func matchesForAB(_ other: RoomRigPassMetadata) -> Bool {
        stimulus == other.stimulus
            && fingerprint.matches(other.fingerprint)
            && liveFFTLength == other.liveFFTLength
            && bassFFTLength == other.bassFFTLength
            && windowKind == other.windowKind
            && isPhoneSpeakerDemo == other.isPhoneSpeakerDemo
    }
}

/// One DSP-worker spectrum frame. Timestamped and sample-counted — not a SwiftUI publish clock.
public struct RoomRigMeasurementFrame: Equatable, Sendable {
    public var frameID: UInt64
    public var sampleCount: UInt64
    public var hostTimeSeconds: Double
    public var rmsDBFS: Double
    public var peakDBFS: Double
    public var crestDB: Double?
    public var clipFraction: Double
    public var peakHz: Double?
    public var bands: [AcousticDisplayBand]
    public var rtaBands: [AcousticDisplayBand]
    public var fingerprint: RoomRigRouteFingerprint
    public var headroomDB: Double?

    public init(
        frameID: UInt64,
        sampleCount: UInt64,
        hostTimeSeconds: Double,
        rmsDBFS: Double,
        peakDBFS: Double,
        crestDB: Double?,
        clipFraction: Double,
        peakHz: Double?,
        bands: [AcousticDisplayBand],
        rtaBands: [AcousticDisplayBand],
        fingerprint: RoomRigRouteFingerprint,
        headroomDB: Double?
    ) {
        self.frameID = frameID
        self.sampleCount = sampleCount
        self.hostTimeSeconds = hostTimeSeconds
        self.rmsDBFS = rmsDBFS
        self.peakDBFS = peakDBFS
        self.crestDB = crestDB
        self.clipFraction = clipFraction
        self.peakHz = peakHz
        self.bands = bands
        self.rtaBands = rtaBands
        self.fingerprint = fingerprint
        self.headroomDB = headroomDB
    }

    /// dB below full scale from the peak reading. Nil when peak is unusable.
    public static func headroomDB(peakDBFS: Double) -> Double? {
        guard peakDBFS.isFinite else { return nil }
        return 0 - peakDBFS
    }
}

public enum RoomRigCaptureCancelReason: String, Equatable, Sendable {
    case userStop
    case incompleteWindow
    case routeOrGainChanged
    case clipping
    case lowHeadroom
    case leftScreen
    case backgrounded
}

/// Protocol-locked capture. Aggregate frames from the DSP worker only.
public struct RoomRigCaptureProtocol: Equatable, Sendable {
    public var metadata: RoomRigPassMetadata
    public var capture: RoomRigTestCapture
    public var startedSampleCount: UInt64
    public var startedHostTime: Double
    public var locked: Bool
    public var cancelReason: RoomRigCaptureCancelReason?

    public init(
        metadata: RoomRigPassMetadata,
        capture: RoomRigTestCapture = RoomRigTestCapture(),
        startedSampleCount: UInt64,
        startedHostTime: Double,
        locked: Bool = true,
        cancelReason: RoomRigCaptureCancelReason? = nil
    ) {
        self.metadata = metadata
        self.capture = capture
        self.startedSampleCount = startedSampleCount
        self.startedHostTime = startedHostTime
        self.locked = locked
        self.cancelReason = cancelReason
    }

    public mutating func append(_ frame: RoomRigMeasurementFrame) -> RoomRigCaptureCancelReason? {
        guard locked, cancelReason == nil else { return cancelReason }
        if !metadata.fingerprint.matches(frame.fingerprint) {
            cancelReason = .routeOrGainChanged
            locked = false
            return cancelReason
        }
        if frame.clipFraction >= RoomRigMath.clipAbortFraction {
            cancelReason = .clipping
            locked = false
            return cancelReason
        }
        if frame.peakDBFS.isFinite, frame.peakDBFS >= RoomRigMath.headroomAbortDBFS {
            cancelReason = .lowHeadroom
            locked = false
            return cancelReason
        }
        capture.append(
            levelDBFS: frame.rmsDBFS,
            peakDBFS: frame.peakDBFS,
            crestDB: frame.crestDB,
            clipFraction: frame.clipFraction,
            peakHz: frame.peakHz,
            bands: frame.rtaBands
        )
        return nil
    }

    public mutating func cancel(_ reason: RoomRigCaptureCancelReason) {
        cancelReason = reason
        locked = false
    }

    /// Finished snapshot only when the protocol stayed locked and enough energy arrived.
    public func finish(
        durationSeconds: Double,
        floorDBFS: Double?
    ) -> RoomRigTestSnapshot? {
        guard locked, cancelReason == nil else { return nil }
        let label: String
        if metadata.isPhoneSpeakerDemo && metadata.stimulus != .listen {
            label = "\(metadata.stimulus.title) · demo"
        } else {
            label = metadata.stimulus.title
        }
        return capture.snapshot(
            stimulus: label,
            durationSeconds: durationSeconds,
            floorDBFS: floorDBFS
        )
    }
}

public enum RoomRigBaselineMath {
    /// Build a quiet-room baseline from worker frames gathered during an explicit capture.
    public static func baseline(
        levels: [Double],
        bandRows: [[Double]] = [],
        fingerprint: RoomRigRouteFingerprint,
        sampleCount: UInt64,
        capturedAt: Double
    ) -> RoomRigQuietBaseline? {
        guard let floor = RoomRigMath.percentile(levels, p: 0.2), floor.isFinite else { return nil }
        var bandFloors: [Double] = []
        if let width = bandRows.map(\.count).max(), width > 0 {
            for column in 0..<width {
                let columnLevels = bandRows.compactMap { row -> Double? in
                    guard row.indices.contains(column), row[column].isFinite else { return nil }
                    return row[column]
                }
                if let p = RoomRigMath.percentile(columnLevels, p: 0.2) {
                    bandFloors.append(p)
                } else {
                    bandFloors.append(SoundLevel.silenceFloorDBFS)
                }
            }
        }
        return RoomRigQuietBaseline(
            floorDBFS: floor,
            bandFloorsDBFS: bandFloors,
            fingerprint: fingerprint,
            sampleCount: sampleCount,
            capturedAt: capturedAt
        )
    }

    /// Signal above background. Not SNR.
    public static func signalAboveBackgroundDB(levelDBFS: Double, baseline: RoomRigQuietBaseline?) -> Double? {
        guard let baseline, baseline.floorDBFS.isFinite else { return nil }
        return RoomRigMath.signalAboveFloorDB(levelDBFS: levelDBFS, floorDBFS: baseline.floorDBFS)
    }
}

public enum RoomRigABMath {
    /// A/B is only honest when both passes share protocol metadata.
    public static func canCompare(a: RoomRigPassMetadata, b: RoomRigPassMetadata) -> Bool {
        a.matchesForAB(b)
    }

    public static func levelDeltaDB(current: RoomRigTestSnapshot, spotA: RoomRigTestSnapshot) -> Double? {
        guard current.levelDBFS.isFinite, spotA.levelDBFS.isFinite else { return nil }
        return current.levelDBFS - spotA.levelDBFS
    }
}

/// Paul Kellet pink filter driven by a deterministic xorshift. Playback scale stays under full scale.
public struct PinkNoiseGenerator: Sendable {
    public var b0 = 0.0
    public var b1 = 0.0
    public var b2 = 0.0
    public var b3 = 0.0
    public var b4 = 0.0
    public var b5 = 0.0
    public var b6 = 0.0
    public var seed: UInt64

    public init(seed: UInt64) {
        self.seed = seed == 0 ? 0xBEC5_F00D : seed
    }

    public mutating func nextWhite() -> Double {
        var state = seed == 0 ? 0xBEC5_F00D : seed
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        seed = state
        let unit = Double(state % 20_000) / 10_000 - 1
        return unit
    }

    public mutating func next(amplitude: Double) -> Double {
        let white = nextWhite()
        b0 = 0.99886 * b0 + white * 0.0555179
        b1 = 0.99332 * b1 + white * 0.0750759
        b2 = 0.96900 * b2 + white * 0.1538520
        b3 = 0.86650 * b3 + white * 0.3104856
        b4 = 0.55000 * b4 + white * 0.5329522
        b5 = -0.7616 * b5 - white * 0.0168980
        let pink = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362
        b6 = white * 0.115926
        let gain = amplitude.isFinite ? min(1, max(0, amplitude)) : 0
        return max(-1, min(1, pink * 0.11 * gain))
    }
}
