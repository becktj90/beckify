import Foundation

/// Peak phasors and ideal impedance at one sinusoidal frequency.
///
/// Cosine reference: `Vm cos(ωt + φ)` is the phasor `Vm ∠ φ`.
/// A sine `Vm sin(ωt + φ)` is that cosine delayed by 90°, so its phasor is
/// `Vm ∠ (φ − 90°)`. The instantaneous value is the real part of the phasor
/// after it rotates by `e^{jωt}`.
///
/// Ideal lumped parts only. An omitted L or C is absent from a series string,
/// not an open circuit sitting in series.
public enum PhasorImpedance {

    public enum WaveBasis: String, Codable, CaseIterable, Sendable, Hashable {
        case sine
        case cosine
    }

    public enum ElementKind: String, Codable, CaseIterable, Sendable, Hashable {
        case resistor
        case inductor
        case capacitor

        public var valueName: String {
            switch self {
            case .resistor: return "Resistance"
            case .inductor: return "Inductance"
            case .capacitor: return "Capacitance"
            }
        }

        /// What this ideal part does as frequency approaches zero.
        public var atDC: FrequencyEnd {
            switch self {
            case .resistor: return .unchanged
            case .inductor: return .short
            case .capacitor: return .open
            }
        }

        /// What this ideal part does as frequency grows without bound.
        public var atHighFrequency: FrequencyEnd {
            switch self {
            case .resistor: return .unchanged
            case .inductor: return .open
            case .capacitor: return .short
            }
        }
    }

    public enum FrequencyEnd: String, Sendable, Hashable {
        /// Impedance approaches 0.
        case short
        /// Impedance has no finite limit in this model.
        case open
        /// Resistance is taken as constant.
        case unchanged
    }

    /// Sign of net reactance, and what that does to current relative to voltage.
    public enum ReactanceSign: String, Sendable, Hashable {
        /// X ≈ 0. Voltage and current share an angle.
        case resistive
        /// X > 0. Current lags voltage.
        case lagging
        /// X < 0. Current leads voltage.
        case leading
    }

    public struct ComplexAmplitude: Equatable, Sendable {
        public var real: Double
        public var imaginary: Double

        public init(real: Double, imaginary: Double) {
            self.real = real
            self.imaginary = imaginary
        }

        public init(magnitude: Double, angleDegrees: Double) {
            let radians = angleDegrees * .pi / 180
            self.real = magnitude * cos(radians)
            self.imaginary = magnitude * sin(radians)
        }

        public var magnitude: Double { hypot(real, imaginary) }

        /// Angle in (−180, 180]. Zero magnitude reports 0°.
        public var angleDegrees: Double {
            guard magnitude > 0 else { return 0 }
            return PhasorImpedance.wrapDegrees(atan2(imaginary, real) * 180 / .pi)
        }

        public var conjugate: ComplexAmplitude {
            ComplexAmplitude(real: real, imaginary: -imaginary)
        }

        public static func + (lhs: ComplexAmplitude, rhs: ComplexAmplitude) -> ComplexAmplitude {
            ComplexAmplitude(real: lhs.real + rhs.real, imaginary: lhs.imaginary + rhs.imaginary)
        }

        public static func - (lhs: ComplexAmplitude, rhs: ComplexAmplitude) -> ComplexAmplitude {
            ComplexAmplitude(real: lhs.real - rhs.real, imaginary: lhs.imaginary - rhs.imaginary)
        }

        public static func * (lhs: ComplexAmplitude, rhs: ComplexAmplitude) -> ComplexAmplitude {
            ComplexAmplitude(
                real: lhs.real * rhs.real - lhs.imaginary * rhs.imaginary,
                imaginary: lhs.real * rhs.imaginary + lhs.imaginary * rhs.real
            )
        }

        /// Nil when the divisor magnitude is 0.
        public static func / (lhs: ComplexAmplitude, rhs: ComplexAmplitude) -> ComplexAmplitude? {
            let den = rhs.real * rhs.real + rhs.imaginary * rhs.imaginary
            guard den > 0, den.isFinite else { return nil }
            return ComplexAmplitude(
                real: (lhs.real * rhs.real + lhs.imaginary * rhs.imaginary) / den,
                imaginary: (lhs.imaginary * rhs.real - lhs.real * rhs.imaginary) / den
            )
        }

        public func scaled(by factor: Double) -> ComplexAmplitude {
            ComplexAmplitude(real: real * factor, imaginary: imaginary * factor)
        }
    }

    public struct Sinusoid: Equatable, Sendable {
        public var peak: Double
        public var hertz: Double
        public var phaseDegrees: Double
        public var basis: WaveBasis

        public init(peak: Double, hertz: Double, phaseDegrees: Double, basis: WaveBasis) {
            self.peak = peak
            self.hertz = hertz
            self.phaseDegrees = phaseDegrees
            self.basis = basis
        }

        public var omega: Double { PhasorImpedance.omega(hertz: hertz) }
        public var period: Double { 1 / hertz }

        public func value(at time: Double) -> Double {
            let theta = omega * time + phaseDegrees * .pi / 180
            switch basis {
            case .sine: return peak * sin(theta)
            case .cosine: return peak * cos(theta)
            }
        }

        /// Peak phasor on the cosine reference.
        public var peakPhasor: ComplexAmplitude {
            let shift: Double = basis == .sine ? -90 : 0
            return ComplexAmplitude(magnitude: peak, angleDegrees: phaseDegrees + shift)
        }

        /// Same angle as the peak phasor. Magnitude is peak / √2.
        public var rmsPhasor: ComplexAmplitude {
            peakPhasor.scaled(by: 1 / sqrt(2))
        }
    }

    public struct LeadLag: Equatable, Sendable {
        public enum Relation: String, Sendable {
            case inPhase
            case leads
            case lags
        }

        public var relation: Relation
        /// First minus second, in (−180, 180]. Positive means the first signal peaks earlier.
        public var deltaDegrees: Double
        /// Seconds by which the first positive peak arrives before the second.
        public var earlierBySeconds: Double
        public var firstName: String
        public var secondName: String
    }

    public struct ElementLaw: Equatable, Sendable {
        public var kind: ElementKind
        public var impedance: ComplexAmplitude
        public var voltage: ComplexAmplitude
        public var current: ComplexAmplitude
        /// Degrees by which voltage leads current, in (−180, 180].
        public var voltageLeadsCurrentDegrees: Double
        public var atDC: FrequencyEnd
        public var atHighFrequency: FrequencyEnd
    }

    public struct ImpedanceResult: Equatable, Sendable {
        public var resistance: Double
        public var inductiveReactance: Double
        public var capacitiveReactance: Double
        public var netReactance: Double
        public var impedance: ComplexAmplitude
        public var admittance: ComplexAmplitude
        public var conductance: Double
        public var susceptance: Double
        public var character: ReactanceSign
        public var voltage: ComplexAmplitude
        public var current: ComplexAmplitude
    }

    public struct SweepPoint: Equatable, Sendable {
        public var hertz: Double
        public var inductiveReactance: Double
        public var capacitiveReactance: Double
        public var netReactance: Double
        public var impedanceMagnitude: Double
    }

    public struct TimeSample: Equatable, Sendable {
        public var time: Double
        public var value: Double
    }

    public struct TimeTrace: Equatable, Sendable {
        public var name: String
        /// Engineering unit of `samples`, such as "V" or "A".
        /// A volt axis must not carry an amp trace.
        public var unit: String
        public var samples: [TimeSample]
        /// Time of the positive peak inside [0, period).
        public var positivePeakTime: Double
        public var positivePeak: Double

        /// Linear value at `time`. Samples are ordered by time.
        public func value(at time: Double) -> Double {
            let samples = self.samples.filter { $0.time.isFinite && $0.value.isFinite }
            guard let first = samples.first else { return 0 }
            if !time.isFinite || time <= first.time { return first.value }
            guard let last = samples.last else { return first.value }
            if time >= last.time { return last.value }
            var low = 0
            var high = samples.count - 1
            while low + 1 < high {
                let mid = (low + high) / 2
                if samples[mid].time <= time { low = mid } else { high = mid }
            }
            let left = samples[low]
            let right = samples[high]
            let span = right.time - left.time
            guard span > 0 else { return left.value }
            let fraction = (time - left.time) / span
            return left.value + (right.value - left.value) * fraction
        }
    }

    /// Closed window for one waveform axis.
    /// `start` is the left or bottom tick, `end` is the far tick, `mid` is the center tick.
    public struct SampleWindow: Equatable, Sendable {
        public var start: Double
        public var mid: Double
        public var end: Double

        /// 0 at `start`, 1 at `end`. Values outside the window sit on the nearer edge.
        public func fraction(_ value: Double) -> Double {
            let span = end - start
            guard span > 0, value.isFinite else { return 0 }
            return min(1, max(0, (value - start) / span))
        }

        public func value(atFraction fraction: Double) -> Double {
            let clamped = min(1, max(0, fraction))
            guard clamped.isFinite else { return start }
            return start + (end - start) * clamped
        }
    }

    /// Fold degrees into (−180, 180].
    public static func wrapDegrees(_ degrees: Double) -> Double {
        guard degrees.isFinite else { return 0 }
        var wrapped = degrees.truncatingRemainder(dividingBy: 360)
        if wrapped <= -180 { wrapped += 360 }
        if wrapped > 180 { wrapped -= 360 }
        return wrapped
    }

    public static func omega(hertz: Double) -> Double {
        2 * .pi * hertz
    }

    public static func makeSinusoid(
        peak: Double,
        hertz: Double,
        phaseDegrees: Double,
        basis: WaveBasis
    ) throws -> Sinusoid {
        guard peak.isFinite, peak >= 0 else {
            throw CalcError.outOfRange("Peak amplitude must be zero or positive.")
        }
        guard hertz.isFinite, hertz > 0 else { throw CalcError.nonPositive("Frequency") }
        guard phaseDegrees.isFinite else { throw CalcError.missing("a finite phase") }
        return Sinusoid(peak: peak, hertz: hertz, phaseDegrees: phaseDegrees, basis: basis)
    }

    public static func leadLag(
        first: Sinusoid,
        firstName: String,
        second: Sinusoid,
        secondName: String
    ) throws -> LeadLag {
        guard first.hertz > 0, second.hertz > 0 else { throw CalcError.nonPositive("Frequency") }
        let relative = abs(first.hertz - second.hertz) / max(first.hertz, second.hertz)
        guard relative < 1e-9 else {
            throw CalcError.outOfRange("Lead and lag need both signals at the same frequency.")
        }
        let delta = wrapDegrees(first.peakPhasor.angleDegrees - second.peakPhasor.angleDegrees)
        let relation: LeadLag.Relation
        if abs(delta) < 0.05 {
            relation = .inPhase
        } else if delta > 0 {
            relation = .leads
        } else {
            relation = .lags
        }
        let earlier = relation == .inPhase ? 0 : delta / 360 / first.hertz
        return LeadLag(
            relation: relation,
            deltaDegrees: relation == .inPhase ? 0 : delta,
            earlierBySeconds: earlier,
            firstName: firstName,
            secondName: secondName
        )
    }

    /// Rebuild a sinusoid whose cosine-reference peak phasor matches `phasor`.
    public static func sinusoid(
        from phasor: ComplexAmplitude,
        hertz: Double,
        basis: WaveBasis
    ) throws -> Sinusoid {
        guard hertz.isFinite, hertz > 0 else { throw CalcError.nonPositive("Frequency") }
        guard phasor.real.isFinite, phasor.imaginary.isFinite else {
            throw CalcError.missing("a finite phasor")
        }
        let shift: Double = basis == .sine ? 90 : 0
        return Sinusoid(
            peak: phasor.magnitude,
            hertz: hertz,
            phaseDegrees: wrapDegrees(phasor.angleDegrees + shift),
            basis: basis
        )
    }

    public static func element(
        kind: ElementKind,
        value: Double,
        hertz: Double,
        voltage: ComplexAmplitude
    ) throws -> ElementLaw {
        let z = try impedance(kind: kind, value: value, hertz: hertz)
        guard voltage.real.isFinite, voltage.imaginary.isFinite else {
            throw CalcError.missing("a finite voltage phasor")
        }
        guard let current = voltage / z else {
            throw CalcError.outOfRange("This part looks like a short here. Current is not finite.")
        }
        return ElementLaw(
            kind: kind,
            impedance: z,
            voltage: voltage,
            current: current,
            voltageLeadsCurrentDegrees: wrapDegrees(voltage.angleDegrees - current.angleDegrees),
            atDC: kind.atDC,
            atHighFrequency: kind.atHighFrequency
        )
    }

    public static func impedance(kind: ElementKind, value: Double, hertz: Double) throws -> ComplexAmplitude {
        guard hertz.isFinite, hertz > 0 else { throw CalcError.nonPositive("Frequency") }
        guard value.isFinite, value > 0 else { throw CalcError.nonPositive(kind.valueName) }
        switch kind {
        case .resistor:
            return ComplexAmplitude(real: value, imaginary: 0)
        case .inductor:
            return ComplexAmplitude(real: 0, imaginary: omega(hertz: hertz) * value)
        case .capacitor:
            return ComplexAmplitude(real: 0, imaginary: -1 / (omega(hertz: hertz) * value))
        }
    }

    /// Series R with optional L and optional C. A nil part is left out of the string.
    public static func series(
        resistance: Double,
        inductanceHenries: Double?,
        capacitanceFarads: Double?,
        hertz: Double,
        voltage: ComplexAmplitude
    ) throws -> ImpedanceResult {
        guard hertz.isFinite, hertz > 0 else { throw CalcError.nonPositive("Frequency") }
        guard resistance.isFinite, resistance >= 0 else {
            throw CalcError.outOfRange("Resistance must be zero or positive.")
        }
        guard voltage.real.isFinite, voltage.imaginary.isFinite else {
            throw CalcError.missing("a finite voltage phasor")
        }
        let w = omega(hertz: hertz)
        var inductive = 0.0
        if let inductanceHenries {
            guard inductanceHenries.isFinite, inductanceHenries > 0 else {
                throw CalcError.nonPositive("Inductance")
            }
            inductive = w * inductanceHenries
        }
        var capacitive = 0.0
        if let capacitanceFarads {
            guard capacitanceFarads.isFinite, capacitanceFarads > 0 else {
                throw CalcError.nonPositive("Capacitance")
            }
            capacitive = -1 / (w * capacitanceFarads)
        }
        let reactance = inductive + capacitive
        let impedance = ComplexAmplitude(real: resistance, imaginary: reactance)
        guard impedance.magnitude > 1e-12 else {
            throw CalcError.outOfRange("Impedance is a short. Admittance and current are not finite.")
        }
        guard let admittance = ComplexAmplitude(real: 1, imaginary: 0) / impedance,
              let current = voltage / impedance
        else {
            throw CalcError.outOfRange("Admittance is not finite.")
        }
        return ImpedanceResult(
            resistance: resistance,
            inductiveReactance: inductive,
            capacitiveReactance: capacitive,
            netReactance: reactance,
            impedance: impedance,
            admittance: admittance,
            conductance: admittance.real,
            susceptance: admittance.imaginary,
            character: character(ofReactance: reactance, beside: resistance),
            voltage: voltage,
            current: current
        )
    }

    public static func character(ofReactance reactance: Double, beside resistance: Double) -> ReactanceSign {
        let scale = max(1, hypot(resistance, reactance))
        if abs(reactance) <= 1e-9 * scale { return .resistive }
        return reactance > 0 ? .lagging : .leading
    }

    public static func admittance(of impedance: ComplexAmplitude) -> ComplexAmplitude? {
        ComplexAmplitude(real: 1, imaginary: 0) / impedance
    }

    /// Log-spaced reactance around one operating frequency.
    /// A nil L or C contributes 0. It is not drawn as an open series element.
    public static func sweep(
        resistance: Double,
        inductanceHenries: Double?,
        capacitanceFarads: Double?,
        aroundHertz: Double,
        factor: Double = 8,
        samples: Int = 81
    ) -> [SweepPoint] {
        guard resistance.isFinite, resistance >= 0,
              aroundHertz.isFinite, aroundHertz > 0,
              factor > 1, samples >= 2
        else { return [] }
        if let inductanceHenries, !inductanceHenries.isFinite || inductanceHenries <= 0 { return [] }
        if let capacitanceFarads, !capacitanceFarads.isFinite || capacitanceFarads <= 0 { return [] }
        let start = log(aroundHertz / factor)
        let end = log(aroundHertz * factor)
        return (0..<samples).compactMap { index in
            let fraction = Double(index) / Double(samples - 1)
            let hertz = exp(start + (end - start) * fraction)
            let w = omega(hertz: hertz)
            let inductive = inductanceHenries.map { w * $0 } ?? 0
            let capacitive = capacitanceFarads.map { -1 / (w * $0) } ?? 0
            let reactance = inductive + capacitive
            let magnitude = hypot(resistance, reactance)
            guard [hertz, inductive, capacitive, magnitude].allSatisfy(\.isFinite) else { return nil }
            return SweepPoint(
                hertz: hertz,
                inductiveReactance: inductive,
                capacitiveReactance: capacitive,
                netReactance: reactance,
                impedanceMagnitude: magnitude
            )
        }
    }

    public static func traces(
        _ signals: [(name: String, sinusoid: Sinusoid, unit: String)],
        cycles: Double = 2,
        samples sampleCount: Int = 241
    ) throws -> [TimeTrace] {
        guard let first = signals.first else { throw CalcError.missing("a sinusoid") }
        guard cycles > 0, sampleCount >= 8 else {
            throw CalcError.outOfRange("Need at least a few samples.")
        }
        for item in signals {
            let relative = abs(item.sinusoid.hertz - first.sinusoid.hertz) / first.sinusoid.hertz
            guard relative < 1e-9 else {
                throw CalcError.outOfRange("Waveforms on one chart need the same frequency.")
            }
        }
        let period = first.sinusoid.period
        let span = period * cycles
        return signals.map { item in
            let samples = (0..<sampleCount).map { index -> TimeSample in
                let time = span * Double(index) / Double(sampleCount - 1)
                return TimeSample(time: time, value: item.sinusoid.value(at: time))
            }
            return TimeTrace(
                name: item.name,
                unit: item.unit,
                samples: samples,
                positivePeakTime: positivePeakTime(item.sinusoid),
                positivePeak: item.sinusoid.peak
            )
        }
    }

    /// Time ticks for every sample on the traces. Empty input is a tiny window at 0.
    public static func timeWindow(of traces: [TimeTrace]) -> SampleWindow {
        let times = traces.flatMap(\.samples).map(\.time).filter(\.isFinite)
        let start = times.min() ?? 0
        var end = times.max() ?? start
        if !(end > start) { end = start + 1e-9 }
        return SampleWindow(start: start, mid: (start + end) / 2, end: end)
    }

    /// Symmetric volt or amp window. The largest |sample| lands on an end tick, and 0 is the center tick.
    public static func symmetricAmplitudeWindow(of traces: [TimeTrace]) -> SampleWindow {
        let peak = traces.flatMap(\.samples).map(\.value).filter(\.isFinite).reduce(0.0) { max($0, abs($1)) }
        let extent = max(peak, 1e-9)
        return SampleWindow(start: -extent, mid: 0, end: extent)
    }

    /// First positive peak inside [0, period).
    public static func positivePeakTime(_ sinusoid: Sinusoid) -> Double {
        let phase = sinusoid.phaseDegrees * .pi / 180
        let target: Double = sinusoid.basis == .sine ? .pi / 2 : 0
        var time = (target - phase) / sinusoid.omega
        let period = sinusoid.period
        time = time.truncatingRemainder(dividingBy: period)
        if time < 0 { time += period }
        return time
    }

    /// Multiply a cosine-reference peak phasor by `e^{jωt}`.
    public static func rotate(_ phasor: ComplexAmplitude, hertz: Double, time: Double) -> ComplexAmplitude {
        let degrees = phasor.angleDegrees + omega(hertz: hertz) * time * 180 / .pi
        return ComplexAmplitude(magnitude: phasor.magnitude, angleDegrees: degrees)
    }

    /// Real-axis projection of the rotating peak phasor.
    public static func instantaneous(_ phasor: ComplexAmplitude, hertz: Double, time: Double) -> Double {
        rotate(phasor, hertz: hertz, time: time).real
    }
}
