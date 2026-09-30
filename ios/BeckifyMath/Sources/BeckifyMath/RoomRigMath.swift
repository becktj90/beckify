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

/// What Setup Check may play from the phone speaker while the shared mic tap listens.
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

/// Room and rig helpers for Setup Check.
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
            return AcousticDisplayBand(
                lowHz: edges.low,
                highHz: min(edges.high, nyquist),
                centerHz: center,
                dbFS: AcousticSpectrum.dbFS(linearMagnitude: magnitude, fftLength: fftLength)
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
