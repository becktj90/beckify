import Foundation

/// A single (x, y) sample for engineer plots. Pure math — no UI.
public struct PlotPoint: Equatable, Sendable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Sampled curves for field / homework plots. All functions reject non-finite
/// or non-positive spans and return an empty array instead of inventing data.
public enum PlotSampling {
    /// Capacitor charging toward `finalValue`: v(t) = V(1 − e^(−t/τ)).
    public static func rcCharge(
        tau: Double,
        finalValue: Double = 1.0,
        throughMultiplesOfTau: Double = 5,
        samples: Int = 81
    ) -> [PlotPoint] {
        guard tau.isFinite, tau > 0,
              finalValue.isFinite,
              throughMultiplesOfTau.isFinite, throughMultiplesOfTau > 0,
              samples >= 2
        else { return [] }
        let span = tau * throughMultiplesOfTau
        guard span.isFinite, span > 0 else { return [] }
        return (0..<samples).map { i in
            let t = span * Double(i) / Double(samples - 1)
            let y = finalValue * (1 - exp(-t / tau))
            return PlotPoint(x: t, y: y)
        }
    }

    /// Capacitor discharging from `initialValue`: v(t) = V₀ e^(−t/τ).
    public static func rcDischarge(
        tau: Double,
        initialValue: Double = 1.0,
        throughMultiplesOfTau: Double = 5,
        samples: Int = 81
    ) -> [PlotPoint] {
        guard tau.isFinite, tau > 0,
              initialValue.isFinite,
              throughMultiplesOfTau.isFinite, throughMultiplesOfTau > 0,
              samples >= 2
        else { return [] }
        let span = tau * throughMultiplesOfTau
        guard span.isFinite, span > 0 else { return [] }
        return (0..<samples).map { i in
            let t = span * Double(i) / Double(samples - 1)
            let y = initialValue * exp(-t / tau)
            return PlotPoint(x: t, y: y)
        }
    }

    /// One or more cycles of a sine wave starting at t = 0.
    public static func sineWave(
        frequencyHz: Double,
        cycles: Double = 2,
        amplitude: Double = 1,
        samples: Int = 161
    ) -> [PlotPoint] {
        guard frequencyHz.isFinite, frequencyHz > 0,
              cycles.isFinite, cycles > 0,
              amplitude.isFinite, samples >= 2
        else {
            return []
        }
        let period = 1 / frequencyHz
        let span = period * cycles
        guard span.isFinite, span > 0 else { return [] }
        return (0..<samples).map { i in
            let t = span * Double(i) / Double(samples - 1)
            return PlotPoint(x: t, y: amplitude * sin(2 * .pi * frequencyHz * t))
        }
    }

    /// Ohm's-law load line from (0, 0) through the operating point (V, I).
    public static func ohmsLoadLine(voltage: Double, current: Double, samples: Int = 25) -> [PlotPoint] {
        guard voltage.isFinite, current.isFinite, voltage >= 0, current >= 0, samples >= 2 else { return [] }
        return (0..<samples).map { i in
            let frac = Double(i) / Double(samples - 1)
            return PlotPoint(x: voltage * frac, y: current * frac)
        }
    }

    /// |Z| for a series RLC across a log-spaced frequency sweep.
    public static func seriesImpedanceMagnitude(
        resistance: Double,
        inductance: Double,
        capacitance: Double,
        fMin: Double,
        fMax: Double,
        samples: Int = 96
    ) -> [PlotPoint] {
        guard resistance.isFinite, resistance >= 0,
              inductance.isFinite, inductance > 0,
              capacitance.isFinite, capacitance > 0,
              fMin.isFinite, fMax.isFinite, fMin > 0, fMax > fMin,
              samples >= 2
        else { return [] }

        let logMin = log10(fMin)
        let logMax = log10(fMax)
        return (0..<samples).map { i in
            let f = pow(10, logMin + (logMax - logMin) * Double(i) / Double(samples - 1))
            let xl = 2 * .pi * f * inductance
            let xc = 1 / (2 * .pi * f * capacitance)
            let xNet = xl - xc
            let z = (resistance * resistance + xNet * xNet).squareRoot()
            return PlotPoint(x: f, y: z)
        }
    }

    /// Ideal 555 monostable timing capacitor: charges from 0 toward Vcc and
    /// trips at 2/3 Vcc when t = pulseWidth (ln 3 · RC).
    public static func monostableCapVoltage(
        pulseWidth: Double,
        vcc: Double = 5,
        samples: Int = 81
    ) -> [PlotPoint] {
        guard pulseWidth.isFinite, pulseWidth > 0, vcc.isFinite, vcc > 0, samples >= 2 else { return [] }
        // v(t) = Vcc (1 − e^(−t/RC)); trip at 2/3 Vcc ⇒ t = ln(3)·RC = pulseWidth
        let rc = pulseWidth / log(3.0)
        let span = pulseWidth * 1.15
        return (0..<samples).map { i in
            let t = span * Double(i) / Double(samples - 1)
            let y = vcc * (1 - exp(-t / rc))
            return PlotPoint(x: t, y: min(y, vcc))
        }
    }

    /// Inductive and capacitive reactance vs frequency (two companion series).
    public static func reactanceVsFrequency(
        inductance: Double,
        capacitance: Double,
        fMin: Double,
        fMax: Double,
        samples: Int = 80
    ) -> (xl: [PlotPoint], xc: [PlotPoint]) {
        guard inductance.isFinite, inductance > 0,
              capacitance.isFinite, capacitance > 0,
              fMin.isFinite, fMax.isFinite, fMin > 0, fMax > fMin, samples >= 2
        else { return ([], []) }

        let logMin = log10(fMin)
        let logMax = log10(fMax)
        var xl: [PlotPoint] = []
        var xc: [PlotPoint] = []
        xl.reserveCapacity(samples)
        xc.reserveCapacity(samples)
        for i in 0..<samples {
            let f = pow(10, logMin + (logMax - logMin) * Double(i) / Double(samples - 1))
            xl.append(PlotPoint(x: f, y: 2 * .pi * f * inductance))
            xc.append(PlotPoint(x: f, y: 1 / (2 * .pi * f * capacitance)))
        }
        return (xl, xc)
    }
}
