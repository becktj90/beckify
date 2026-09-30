import Foundation

public enum LabTransferKind: String, Equatable, Sendable {
    /// A closed-form H(s), H(jω), or voltage/current ratio.
    case closedForm
    /// A bias, clip, or DC relation. Not a linear H(s).
    case operatingPoint
    /// Switching, digital, or strongly nonlinear. The waveforms are the result.
    case none
}

public struct LabTrace: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var points: [PlotPoint]

    public init(id: String, name: String, points: [PlotPoint]) {
        self.id = id
        self.name = name
        self.points = points
    }
}

public struct LabPlot: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var xLabel: String
    public var yLabel: String
    public var logX: Bool
    public var smooth: Bool
    public var showZero: Bool
    public var xGuide: Double?
    public var xGuideLabel: String
    public var series: [LabTrace]

    public init(
        id: String,
        title: String,
        xLabel: String,
        yLabel: String,
        series: [LabTrace],
        logX: Bool = false,
        smooth: Bool = true,
        showZero: Bool = false,
        xGuide: Double? = nil,
        xGuideLabel: String = ""
    ) {
        self.id = id
        self.title = title
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.logX = logX
        self.smooth = smooth
        self.showZero = showZero
        self.xGuide = xGuide
        self.xGuideLabel = xGuideLabel
        self.series = series
    }
}

public struct LabIO: Equatable, Sendable {
    public var transferKind: LabTransferKind
    public var expression: String
    public var detail: String
    public var plots: [LabPlot]

    public init(transferKind: LabTransferKind, expression: String, detail: String, plots: [LabPlot]) {
        self.transferKind = transferKind
        self.expression = expression
        self.detail = detail
        self.plots = plots
    }

    public static let empty = LabIO(
        transferKind: .none,
        expression: "No linear transfer function — see the waveforms.",
        detail: "",
        plots: []
    )
}

/// Closed-form teaching responses and the samples drawn under each schematic.
/// Ideal models only — the same approximations as the node table, not a transient SPICE run.
public enum LabSignals {
    public static func dividerRatio(r1: Double, r2: Double) -> Double {
        guard r1 + r2 != 0 else { return .nan }
        return r2 / (r1 + r2)
    }

    /// First-order low-pass H(jω) = 1 / (1 + j f/fc).
    public static func lowpassPhasor(frequency: Double, cutoff: Double) -> (magnitude: Double, phaseDeg: Double) {
        let ratio = frequency / cutoff
        let magnitude = 1 / sqrt(1 + ratio * ratio)
        let phaseDeg = -atan(ratio) * 180 / .pi
        return (magnitude, phaseDeg)
    }

    /// First-order high-pass H(jω) = j(f/fc) / (1 + j f/fc).
    public static func highpassPhasor(frequency: Double, cutoff: Double) -> (magnitude: Double, phaseDeg: Double) {
        let ratio = frequency / cutoff
        let magnitude = ratio / sqrt(1 + ratio * ratio)
        let phaseDeg = 90 - atan(ratio) * 180 / .pi
        return (magnitude, phaseDeg)
    }

    /// |H| of an ideal integrator H(s) = −1/(sRC). Phase is −90°.
    public static func integratorMagnitude(frequency: Double, resistance: Double, capacitance: Double) -> Double {
        1 / (2 * .pi * frequency * resistance * capacitance)
    }

    /// |I/V| of a series RLC at one frequency.
    public static func seriesRLCCurrentGain(
        resistance: Double,
        inductance: Double,
        capacitance: Double,
        frequency: Double
    ) -> Double {
        let omega = 2 * .pi * frequency
        let reactance = omega * inductance - 1 / (omega * capacitance)
        let magnitude = sqrt(resistance * resistance + reactance * reactance)
        return 1 / magnitude
    }

    /// Ideal shorted-stub reactance X = Z0 tan(2π ℓ/λ).
    public static func shortedStubReactance(z0: Double, lengthOverLambda: Double) -> Double {
        z0 * tan(2 * .pi * lengthOverLambda)
    }

    public static func sineValue(frequency: Double, time: Double, amplitude: Double, phaseDeg: Double = 0) -> Double {
        let phase = phaseDeg * .pi / 180
        return amplitude * sin(2 * .pi * frequency * time + phase)
    }

    public static func make(circuit: ElectronicsCircuit, quantities: [LabQuantity]) -> LabIO {
        let bag = Bag(quantities)
        switch circuit {
        case .seriesResistors: return seriesPair(bag, bottomIsOutput: true)
        case .parallelResistors: return parallel(bag)
        case .voltageDivider: return divider(bag)
        case .kirchhoffLoop: return kirchhoff(bag)
        case .theveninNorton: return thevenin(bag)
        case .rcStep: return rcStep(bag)
        case .rlStep: return rlStep(bag)
        case .firstOrderFilter: return filter(bag)
        case .seriesRLC: return rlc(bag)
        case .halfWave: return rectifier(bag, bridge: false)
        case .fullBridge: return rectifier(bag, bridge: true)
        case .shuntClipper: return clipper(bag)
        case .clamper: return clamper(bag)
        case .ledSeries: return led(bag)
        case .bjtBias, .discretePower: return bjtLoadLine(bag, discrete: circuit == .discretePower)
        case .ceAmp: return midband(bag, name: "CE midband")
        case .bjtSwitch: return bjtSwitch(bag)
        case .csAmp: return midband(bag, name: "CS midband")
        case .mosSwitch: return mosSwitch(bag)
        case .cmosInverter: return cmos(bag)
        case .invertingAmp: return gainSine(bag, expression: "H = −Rf / Rin", signed: true)
        case .nonInvertingAmp: return gainSine(bag, expression: "H = 1 + Rf / Rg", signed: false)
        case .summingAmp: return summing(bag)
        case .diffAmp: return difference(bag)
        case .integrator: return integrator(bag)
        case .differentiator: return differentiator(bag)
        case .comparator: return comparator(bag)
        case .astable555: return astable(bag)
        case .monostable555: return monostable(bag)
        case .ledFlasher: return flasher(bag)
        case .sevenSegment: return segments(bag)
        case .classOverview: return classPower(bag)
        case .opAmpPower: return gainSine(bag, expression: "H = −Rf / Rin", signed: true)
        case .linearDrop: return linearDrop(bag)
        case .idealBuck: return buck(bag)
        case .complexConvert: return complexPlane(bag)
        case .impedanceCombo: return impedance(bag)
        case .lMatch: return lMatch(bag)
        case .quarterWave: return quarterWave(bag)
        case .stubCancel: return stub(bag)
        }
    }

    // MARK: - Passives

    private static func seriesPair(_ bag: Bag, bottomIsOutput: Bool) -> LabIO {
        guard let vs = bag["vs"], let r1 = bag["r1"], let r2 = bag["r2"], r1 + r2 > 0 else { return .empty }
        let gain = dividerRatio(r1: r1, r2: r2)
        let current = vs / (r1 + r2)
        let wave = resistiveSine(vinPeak: vs, gain: bottomIsOutput ? gain : 1, currentPeak: current)
        return LabIO(
            transferKind: .closedForm,
            expression: "V_R2 / Vs = R2 / (R1 + R2) = \(fmt(gain))",
            detail: "Resistive. The sine is a 1 kHz teaching drive; the ratio is the same at DC. I / Vs = 1 / (R1 + R2).",
            plots: wave
        )
    }

    private static func parallel(_ bag: Bag) -> LabIO {
        guard let vs = bag["vs"], let r1 = bag["r1"], let r2 = bag["r2"], r1 > 0, r2 > 0 else { return .empty }
        let i1 = vs / r1
        let i2 = vs / r2
        let times = sineTimes(frequency: 1_000, cycles: 2)
        return LabIO(
            transferKind: .closedForm,
            expression: "It / Vs = 1/R1 + 1/R2 = \(fmt(1 / r1 + 1 / r2)) S",
            detail: "Resistive. The 1 kHz sine is a teaching drive. Branch currents add.",
            plots: [
                volts("Source", times: times, samples: times.map { sineValue(frequency: 1_000, time: $0, amplitude: vs) }, name: "Vs"),
                amps("Branch currents", times: times, series: [
                    ("I1", times.map { sineValue(frequency: 1_000, time: $0, amplitude: i1) }),
                    ("I2", times.map { sineValue(frequency: 1_000, time: $0, amplitude: i2) }),
                    ("It", times.map { sineValue(frequency: 1_000, time: $0, amplitude: i1 + i2) }),
                ])
            ]
        )
    }

    private static func divider(_ bag: Bag) -> LabIO {
        guard let vin = bag["vin"], let r1 = bag["r1"], let r2 = bag["r2"], r1 + r2 > 0 else { return .empty }
        let gain = dividerRatio(r1: r1, r2: r2)
        let current = vin / (r1 + r2)
        return LabIO(
            transferKind: .closedForm,
            expression: "H = Vout / Vin = R2 / (R1 + R2) = \(fmt(gain))",
            detail: "Real and flat. The 1 kHz sine uses the solved Vin as its peak.",
            plots: resistiveSine(vinPeak: vin, gain: gain, currentPeak: current)
        )
    }

    private static func kirchhoff(_ bag: Bag) -> LabIO {
        guard let vs = bag["vs"], let r1 = bag["r1"], let r2 = bag["r2"], let r3 = bag["r3"] else { return .empty }
        let sum = r1 + r2 + r3
        guard sum > 0 else { return .empty }
        let times = sineTimes(frequency: 1_000, cycles: 2)
        func drop(_ r: Double) -> [Double] {
            times.map { sineValue(frequency: 1_000, time: $0, amplitude: vs * r / sum) }
        }
        return LabIO(
            transferKind: .closedForm,
            expression: "I / Vs = 1 / (R1 + R2 + R3) = \(fmt(1 / sum)) S",
            detail: "One loop. The drops are the same 1 kHz sine, scaled by each resistor.",
            plots: [
                LabPlot(
                    id: "drops",
                    title: "Loop drops",
                    xLabel: "Time (s)",
                    yLabel: "Voltage (V)",
                    series: [
                        trace("vs", "Vs", times, times.map { sineValue(frequency: 1_000, time: $0, amplitude: vs) }),
                        trace("d1", "R1", times, drop(r1)),
                        trace("d2", "R2", times, drop(r2)),
                        trace("d3", "R3", times, drop(r3)),
                    ],
                    showZero: true
                )
            ]
        )
    }

    private static func thevenin(_ bag: Bag) -> LabIO {
        guard let vth = bag["vth"], let rth = bag["rth"], let rl = bag["rl"] else { return .empty }
        let denom = rth + rl
        guard denom > 0 else { return .empty }
        let gain = rl / denom
        return LabIO(
            transferKind: .closedForm,
            expression: "VL / Vth = RL / (Rth + RL) = \(fmt(gain))",
            detail: "Norton current is Vth / Rth. The sine is Vth at 1 kHz.",
            plots: resistiveSine(vinPeak: vth, gain: gain, currentPeak: vth / denom, vinName: "Vth", voutName: "VL")
        )
    }

    private static func rcStep(_ bag: Bag) -> LabIO {
        guard let v0 = bag["v0"], let vinf = bag["vinf"], let tau = bag["tau"], let r = bag["r"], tau > 0, r > 0 else { return .empty }
        let span = max(5 * tau, (bag["time"] ?? tau) * 1.2)
        let times = linspace(span, samples: 121)
        let vc = times.map { vinf + (v0 - vinf) * exp(-$0 / tau) }
        let current = vc.map { (vinf - $0) / r }
        let vin = times.map { _ in vinf }
        return LabIO(
            transferKind: .closedForm,
            expression: "Vc(s) / Vs(s) = 1 / (1 + sRC)",
            detail: "Zero-state form. The trace starts at v(0) and settles toward v(∞). τ = RC.",
            plots: [
                LabPlot(id: "vc", title: "Step response", xLabel: "Time (s)", yLabel: "Voltage (V)", series: [
                    trace("vin", "v(∞)", times, vin),
                    trace("vc", "vC", times, vc),
                ], xGuide: tau, xGuideLabel: "τ"),
                LabPlot(id: "i", title: "Capacitor current", xLabel: "Time (s)", yLabel: "Current (A)", series: [
                    trace("i", "i(t)", times, current),
                ], showZero: true, xGuide: tau, xGuideLabel: "τ"),
            ]
        )
    }

    private static func rlStep(_ bag: Bag) -> LabIO {
        guard let vs = bag["vs"], let i0 = bag["i0"], let iInf = bag["iInf"], let tau = bag["tau"], let r = bag["r"], tau > 0 else { return .empty }
        let span = max(5 * tau, (bag["time"] ?? tau) * 1.2)
        let times = linspace(span, samples: 121)
        let current = times.map { iInf + (i0 - iInf) * exp(-$0 / tau) }
        let vL = current.map { vs - $0 * r }
        return LabIO(
            transferKind: .closedForm,
            expression: "I(s) / Vs(s) = 1 / (R + sL)",
            detail: "Current cannot step. vL is what is left after the resistor drop. τ = L/R.",
            plots: [
                LabPlot(id: "i", title: "Inductor current", xLabel: "Time (s)", yLabel: "Current (A)", series: [
                    trace("iinf", "i(∞)", times, times.map { _ in iInf }),
                    trace("i", "i(t)", times, current),
                ], xGuide: tau, xGuideLabel: "τ"),
                LabPlot(id: "vl", title: "Inductor voltage", xLabel: "Time (s)", yLabel: "Voltage (V)", series: [
                    trace("vl", "vL", times, vL),
                ], showZero: true, xGuide: tau, xGuideLabel: "τ"),
            ]
        )
    }

    private static func filter(_ bag: Bag) -> LabIO {
        guard let fc = bag["fc"], let r = bag["r"], let c = bag["c"], fc > 0, r > 0, c > 0 else { return .empty }
        let low = (bag["lowpass"] ?? 1) >= 0.5
        let drive = bag["f"] ?? fc
        let bode = bodeFirstOrder(fc: fc, lowpass: low)
        let h = low ? lowpassPhasor(frequency: drive, cutoff: fc) : highpassPhasor(frequency: drive, cutoff: fc)
        let times = sineTimes(frequency: drive, cycles: 2)
        let vin = times.map { sineValue(frequency: drive, time: $0, amplitude: 1) }
        let vout = times.map { sineValue(frequency: drive, time: $0, amplitude: h.magnitude, phaseDeg: h.phaseDeg) }
        let expression = low ? "H(s) = 1 / (1 + sRC)" : "H(s) = sRC / (1 + sRC)"
        return LabIO(
            transferKind: .closedForm,
            expression: expression,
            detail: "fc = 1/(2πRC). Bode is unloaded. The time trace is a 1 V sine at the drive frequency.",
            plots: bode + [
                LabPlot(id: "time", title: "Drive and output", xLabel: "Time (s)", yLabel: "Voltage (V)", series: [
                    trace("vin", "Vin", times, vin),
                    trace("vout", "Vout", times, vout),
                ], showZero: true, xGuide: 1 / drive, xGuideLabel: "T"),
            ]
        )
    }

    private static func rlc(_ bag: Bag) -> LabIO {
        guard let r = bag["r"], let l = bag["l"], let c = bag["c"], let f0 = bag["f0"], r > 0, l > 0, c > 0, f0 > 0 else { return .empty }
        let drive = bag["f"] ?? f0
        let freqs = logspace(f0 / 30, f0 * 30, samples: 81)
        let gain = freqs.map { seriesRLCCurrentGain(resistance: r, inductance: l, capacitance: c, frequency: $0) }
        let phase = freqs.map { frequency -> Double in
            let omega = 2 * .pi * frequency
            let x = omega * l - 1 / (omega * c)
            return -atan2(x, r) * 180 / .pi
        }
        let h = seriesRLCCurrentGain(resistance: r, inductance: l, capacitance: c, frequency: drive)
        let omega = 2 * .pi * drive
        let x = omega * l - 1 / (omega * c)
        let phaseDrive = -atan2(x, r) * 180 / .pi
        let times = sineTimes(frequency: drive, cycles: 2)
        return LabIO(
            transferKind: .closedForm,
            expression: "I/V = 1 / (R + sL + 1/(sC))",
            detail: "Series combination, 1 V drive. At f0 the reactances cancel and |I| = 1/R.",
            plots: [
                LabPlot(id: "mag", title: "|I/V|", xLabel: "Frequency (Hz)", yLabel: "|I/V| (S)", series: [
                    trace("h", "|I/V|", freqs, gain),
                ], logX: true, xGuide: f0, xGuideLabel: "f0"),
                LabPlot(id: "ang", title: "Phase of I", xLabel: "Frequency (Hz)", yLabel: "Phase (°)", series: [
                    trace("p", "∠I", freqs, phase),
                ], logX: true, smooth: true, showZero: true, xGuide: f0, xGuideLabel: "f0"),
                LabPlot(id: "time", title: "1 V drive and current", xLabel: "Time (s)", yLabel: "Vin (V), I (A)", series: [
                    trace("vin", "Vin", times, times.map { sineValue(frequency: drive, time: $0, amplitude: 1) }),
                    trace("i", "I", times, times.map { sineValue(frequency: drive, time: $0, amplitude: h, phaseDeg: phaseDrive) }),
                ], showZero: true),
            ]
        )
    }

    // MARK: - Diodes and transistors

    private static func rectifier(_ bag: Bag, bridge: Bool) -> LabIO {
        let isBridge = bridge || (bag["bridge"] ?? 0) >= 0.5
        guard let f = bag["f"], let vf = bag["vf"], f > 0 else { return .empty }
        let sourcePeak = bag["vsrcpk"] ?? 0
        guard sourcePeak > 0 else { return .empty }
        let drops = isBridge ? 2.0 : 1.0
        let times = sineTimes(frequency: f, cycles: 2, samples: 201)
        let vin = times.map { sineValue(frequency: f, time: $0, amplitude: sourcePeak) }
        let vout = vin.map { sample -> Double in
            if isBridge {
                return max(abs(sample) - drops * vf, 0)
            }
            return max(sample - vf, 0)
        }
        return LabIO(
            transferKind: .none,
            expression: "No linear transfer function — see the waveforms.",
            detail: isBridge
                ? "Ideal bridge. Two diode drops per half cycle. The capacitor is not on this trace."
                : "Ideal half-wave. One diode drop. The capacitor is not on this trace.",
            plots: [
                LabPlot(id: "rect", title: "Source and rectified output", xLabel: "Time (s)", yLabel: "Voltage (V)", series: [
                    trace("vin", "Vin", times, vin),
                    trace("vout", "Vout", times, vout),
                ], smooth: false, showZero: true),
            ]
        )
    }

    private static func clipper(_ bag: Bag) -> LabIO {
        guard let vp = bag["vp"], let vclip = bag["vclip"], vp > 0 else { return .empty }
        let f = 1_000.0
        let times = sineTimes(frequency: f, cycles: 2, samples: 201)
        let vin = times.map { sineValue(frequency: f, time: $0, amplitude: vp) }
        let vout = vin.map { min($0, vclip) }
        return LabIO(
            transferKind: .none,
            expression: "No linear transfer function — see the waveforms.",
            detail: "Shunt clipper. The output follows the source until it reaches Vbias + Vf, then it holds. A 1 kHz teaching sine.",
            plots: [
                LabPlot(id: "clip", title: "Clipper", xLabel: "Time (s)", yLabel: "Voltage (V)", series: [
                    trace("vin", "Vin", times, vin),
                    trace("vout", "Vout", times, vout),
                ], smooth: false, showZero: true, xGuide: nil, xGuideLabel: ""),
            ]
        )
    }

    private static func clamper(_ bag: Bag) -> LabIO {
        guard let vmax = bag["vmax"], let vmin = bag["vmin"] else { return .empty }
        let vp = (vmax - vmin) / 2
        guard vp > 0 else { return .empty }
        let shift = vp + vmin
        let f = 1_000.0
        let times = sineTimes(frequency: f, cycles: 2)
        let vin = times.map { sineValue(frequency: f, time: $0, amplitude: vp) }
        let vout = vin.map { $0 + shift }
        return LabIO(
            transferKind: .none,
            expression: "No linear transfer function — see the waveforms.",
            detail: "Steady clamp. The negative peak sits at −Vf and the sine is shifted up by Vp − Vf. A 1 kHz teaching sine.",
            plots: [
                LabPlot(id: "clamp", title: "Clamper", xLabel: "Time (s)", yLabel: "Voltage (V)", series: [
                    trace("vin", "Vin", times, vin),
                    trace("vout", "Vout", times, vout),
                ], showZero: true),
            ]
        )
    }

    private static func led(_ bag: Bag) -> LabIO {
        guard let vs = bag["vs"], let r = bag["r"], let current = bag["current"], r > 0 else { return .empty }
        let vf = vs - current * r
        let hi = max(vs, vf + 1)
        let xs = linspace(max(vf, 0), hi, samples: 41)
        let currents = xs.map { max(0, ($0 - vf) / r) }
        return LabIO(
            transferKind: .operatingPoint,
            expression: "If = (Vs − Vf) / R",
            detail: "DC sweep of the supply. The LED is a fixed drop. No H(s).",
            plots: [
                LabPlot(id: "led", title: "LED current vs supply", xLabel: "Vs (V)", yLabel: "If (A)", series: [
                    trace("if", "If", xs, currents),
                ], smooth: false),
            ]
        )
    }

    private static func bjtLoadLine(_ bag: Bag, discrete: Bool) -> LabIO {
        guard let ic = bag["ic"], let vce = bag["vce"], let rc = bag["rc"], rc > 0 else { return .empty }
        let vcc = bag["vcc"] ?? ((bag["vc"] ?? 0) + ic * rc)
        guard vcc > 0 else { return .empty }
        let xs = linspace(0, vcc, samples: 2)
        let load = xs.map { (vcc - $0) / rc }
        return LabIO(
            transferKind: .operatingPoint,
            expression: discrete ? "Pq = Ic · Vce" : "Ic ≈ (Vb − 0.7) / Re   while active",
            detail: "DC load line Ic = (Vcc − Vce) / Rc. The marker is the solved point. No linear H(s).",
            plots: [
                LabPlot(id: "ll", title: "Collector load line", xLabel: "Vce (V)", yLabel: "Ic (A)", series: [
                    trace("ll", "Load line", xs, load),
                    trace("q", "Q", [vce], [ic]),
                ], smooth: false),
            ]
        )
    }

    private static func midband(_ bag: Bag, name: String) -> LabIO {
        guard let av = bag["av"] else { return .empty }
        let peak = 0.010
        let f = 1_000.0
        let times = sineTimes(frequency: f, cycles: 2)
        let phase: Double = av < 0 ? 180 : 0
        return LabIO(
            transferKind: .closedForm,
            expression: "H ≈ Av = \(fmt(av))   (midband)",
            detail: "\(name). A 10 mV peak teaching sine. Coupling and bypass capacitors are shorts. Not a full hybrid-π with Cπ and Cμ.",
            plots: [
                LabPlot(id: "sine", title: "Midband sine", xLabel: "Time (s)", yLabel: "Voltage (V)", series: [
                    trace("vin", "vin", times, times.map { sineValue(frequency: f, time: $0, amplitude: peak) }),
                    trace("vout", "vout", times, times.map { sineValue(frequency: f, time: $0, amplitude: peak * abs(av), phaseDeg: phase) }),
                ], showZero: true),
            ]
        )
    }

    private static func bjtSwitch(_ bag: Bag) -> LabIO {
        guard let vc = bag["vc"] else { return .empty }
        let on = (bag["state"] ?? 0) >= 0.5
        let vcc = bag["vcc"] ?? max(vc, 5)
        let span = 0.002
        let times = linspace(span, samples: 81)
        let gate = times.map { $0 < span / 2 ? 0.0 : 1.0 }
        let collector = times.map { sample -> Double in
            let driven = sample >= span / 2
            if on { return driven ? vc : vcc }
            return vcc
        }
        return LabIO(
            transferKind: .none,
            expression: "No linear transfer function — see the waveforms.",
            detail: on
                ? "Solved point is saturated. The sketch drives the base on for the second half of 2 ms and puts Vc near Vce(sat)."
                : "Solved point is not saturated. The collector does not pull down to Vce(sat) in this sketch.",
            plots: [
                LabPlot(id: "sw", title: "Switch sketch", xLabel: "Time (s)", yLabel: "Voltage (V)", series: [
                    trace("drive", "Drive", times, gate),
                    trace("vc", "Vc", times, collector),
                ], smooth: false),
            ]
        )
    }

    private static func mosSwitch(_ bag: Bag) -> LabIO {
        guard let vds = bag["vds"], let vdd = bag["vdd"] else { return .empty }
        let on = (bag["state"] ?? 0) >= 0.5
        let span = 0.002
        let times = linspace(span, samples: 81)
        let drain = times.map { $0 < span / 2 ? vdd : (on ? vds : vdd) }
        return LabIO(
            transferKind: .none,
            expression: "No linear transfer function — see the waveforms.",
            detail: "Ideal switch. Off, the drain sits at Vdd. On, Vds = Id · Rds(on). Square-law charge is not drawn.",
            plots: [
                LabPlot(id: "sw", title: "Drain voltage", xLabel: "Time (s)", yLabel: "Voltage (V)", series: [
                    trace("vds", "Vds", times, drain),
                ], smooth: false),
            ]
        )
    }

    private static func cmos(_ bag: Bag) -> LabIO {
        guard let vdd = bag["vdd"], let vm = bag["vm"], vdd > 0 else { return .empty }
        let xs = linspace(0, vdd, samples: 81)
        let ys = xs.map { vin -> Double in
            if abs(vin - vm) < vdd * 1e-6 { return vm }
            return vin < vm ? vdd : 0
        }
        return LabIO(
            transferKind: .none,
            expression: "No linear transfer function — see the waveforms.",
            detail: "Ideal rail-to-rail step at Vm. A real inverter is not a vertical line.",
            plots: [
                LabPlot(id: "vtc", title: "Voltage transfer", xLabel: "Vin (V)", yLabel: "Vout (V)", series: [
                    trace("vtc", "Vout", xs, ys),
                ], smooth: false),
            ]
        )
    }

    // MARK: - Op-amps and timers

    private static func gainSine(_ bag: Bag, expression: String, signed: Bool) -> LabIO {
        guard let av = bag["av"] else { return .empty }
        let vinPeak = max(abs(bag["vin"] ?? 0.1), 1e-4)
        let f = 1_000.0
        let times = sineTimes(frequency: f, cycles: 2)
        let phase: Double = (signed && av < 0) ? 180 : 0
        let shown = abs(av)
        return LabIO(
            transferKind: .closedForm,
            expression: "\(expression) = \(fmt(av))",
            detail: "Ideal op-amp, 1 kHz teaching sine. A swing limit on the DC node is not folded into this trace.",
            plots: [
                LabPlot(id: "sine", title: "Input and output", xLabel: "Time (s)", yLabel: "Voltage (V)", series: [
                    trace("vin", "Vin", times, times.map { sineValue(frequency: f, time: $0, amplitude: vinPeak) }),
                    trace("vout", "Vout", times, times.map { sineValue(frequency: f, time: $0, amplitude: vinPeak * shown, phaseDeg: phase) }),
                ], showZero: true),
            ]
        )
    }

    private static func summing(_ bag: Bag) -> LabIO {
        guard let v1 = bag["v1"], let r1 = bag["r1"], let v2 = bag["v2"], let r2 = bag["r2"], let rf = bag["rf"] else { return .empty }
        let vout = -rf * (v1 / r1 + v2 / r2)
        let times = linspace(0.002, samples: 41)
        return LabIO(
            transferKind: .closedForm,
            expression: "Vout = −Rf (V1/R1 + V2/R2) = \(fmt(vout)) V",
            detail: "Two DC inputs. There is no single H(s). The lines are the solved voltages.",
            plots: [
                LabPlot(id: "sum", title: "Summing voltages", xLabel: "Time (s)", yLabel: "Voltage (V)", series: [
                    trace("v1", "V1", times, times.map { _ in v1 }),
                    trace("v2", "V2", times, times.map { _ in v2 }),
                    trace("vout", "Vout", times, times.map { _ in vout }),
                ], smooth: false, showZero: true),
            ]
        )
    }

    private static func difference(_ bag: Bag) -> LabIO {
        guard let v1 = bag["v1"], let v2 = bag["v2"], let gain = bag["gain"] else { return .empty }
        let f = 1_000.0
        let amp = max(abs(v2), 0.5)
        let times = sineTimes(frequency: f, cycles: 2)
        let v2t = times.map { v2 == 0 ? sineValue(frequency: f, time: $0, amplitude: amp) : sineValue(frequency: f, time: $0, amplitude: amp) }
        let vout = v2t.map { gain * ($0 - v1) }
        return LabIO(
            transferKind: .closedForm,
            expression: "Vout / (V2 − V1) = Rf / Rin = \(fmt(gain))",
            detail: "V1 is held at the solved value. V2 is a 1 kHz sine of peak \(fmt(amp)) V so the difference is visible.",
            plots: [
                LabPlot(id: "diff", title: "Difference", xLabel: "Time (s)", yLabel: "Voltage (V)", series: [
                    trace("v1", "V1", times, times.map { _ in v1 }),
                    trace("v2", "V2", times, v2t),
                    trace("vout", "Vout", times, vout),
                ], showZero: true),
            ]
        )
    }

    private static func integrator(_ bag: Bag) -> LabIO {
        guard let r = bag["r"], let c = bag["c"], let vin = bag["vin"], let v0 = bag["v0"], r > 0, c > 0 else { return .empty }
        let span = max(bag["time"] ?? 0, 1 / (2 * .pi / (r * c)))
        let times = linspace(max(span, r * c), samples: 81)
        let vout = times.map { v0 - (vin / (r * c)) * $0 }
        let unity = 1 / (2 * .pi * r * c)
        let freqs = logspace(unity / 30, unity * 30, samples: 61)
        let mag = freqs.map { 20 * log10(max(integratorMagnitude(frequency: $0, resistance: r, capacitance: c), 1e-12)) }
        return LabIO(
            transferKind: .closedForm,
            expression: "H(s) = −1 / (sRC)",
            detail: "Constant Vin makes a ramp. |H| = 1 at 1/(2πRC), and the phase of −1/(jωRC) is −90°.",
            plots: [
                LabPlot(id: "ramp", title: "Ramp", xLabel: "Time (s)", yLabel: "Voltage (V)", series: [
                    trace("vin", "Vin", times, times.map { _ in vin }),
                    trace("vout", "v(t)", times, vout),
                ], smooth: false, showZero: true),
                LabPlot(id: "bode", title: "Integrator |H|", xLabel: "Frequency (Hz)", yLabel: "|H| (dB)", series: [
                    trace("db", "|H|", freqs, mag),
                ], logX: true, xGuide: unity, xGuideLabel: "1"),
            ]
        )
    }

    private static func differentiator(_ bag: Bag) -> LabIO {
        guard let r = bag["r"], let c = bag["c"], let slope = bag["slope"], r > 0, c > 0 else { return .empty }
        let vout = -r * c * slope
        let span = 0.002
        let times = linspace(span, samples: 41)
        let vin = times.map { slope * $0 }
        let unity = 1 / (2 * .pi * r * c)
        let freqs = logspace(unity / 30, unity * 30, samples: 61)
        let mag = freqs.map { frequency -> Double in
            20 * log10(max(2 * .pi * frequency * r * c, 1e-12))
        }
        return LabIO(
            transferKind: .closedForm,
            expression: "H(s) = −sRC",
            detail: "A constant slope in gives a constant voltage out. |H| = ωRC and the phase of −jωRC is −90°.",
            plots: [
                LabPlot(id: "ramp", title: "Slope in, level out", xLabel: "Time (s)", yLabel: "Voltage (V)", series: [
                    trace("vin", "Vin", times, vin),
                    trace("vout", "Vout", times, times.map { _ in vout }),
                ], smooth: false, showZero: true),
                LabPlot(id: "bode", title: "Differentiator |H|", xLabel: "Frequency (Hz)", yLabel: "|H| (dB)", series: [
                    trace("db", "|H|", freqs, mag),
                ], logX: true, xGuide: unity, xGuideLabel: "1"),
            ]
        )
    }

    private static func comparator(_ bag: Bag) -> LabIO {
        guard let vref = bag["vref"], let voh = bag["voh"], let vol = bag["vol"] else { return .empty }
        let amp = max(abs((bag["vin"] ?? vref) - vref), 1)
        let f = 1_000.0
        let times = sineTimes(frequency: f, cycles: 2, samples: 201)
        let vin = times.map { vref + sineValue(frequency: f, time: $0, amplitude: amp) }
        let vout = vin.map { $0 >= vref ? voh : vol }
        return LabIO(
            transferKind: .none,
            expression: "No linear transfer function — see the waveforms.",
            detail: "Open loop. A teaching sine crosses Vref; the output sits on the high or low rail. No hysteresis.",
            plots: [
                LabPlot(id: "cmp", title: "Comparator", xLabel: "Time (s)", yLabel: "Voltage (V)", series: [
                    trace("vin", "Vin", times, vin),
                    trace("vout", "Vout", times, vout),
                    trace("ref", "Vref", times, times.map { _ in vref }),
                ], smooth: false, showZero: true),
            ]
        )
    }

    private static func astable(_ bag: Bag) -> LabIO {
        guard let vcc = bag["vcc"], let thigh = bag["thigh"], let tlow = bag["tlow"],
              let r1 = bag["r1"], let r2 = bag["r2"], let c = bag["c"],
              thigh > 0, tlow > 0, c > 0 else { return .empty }
        let period = thigh + tlow
        let times = linspace(period * 2, samples: 241)
        var cap: [Double] = []
        var out: [Double] = []
        cap.reserveCapacity(times.count)
        let tauCharge = (r1 + r2) * c
        let tauDis = r2 * c
        for time in times {
            let local = time.truncatingRemainder(dividingBy: period)
            if local <= thigh {
                let v = vcc * (1 - (2.0 / 3.0) * exp(-local / tauCharge))
                cap.append(v)
                out.append(vcc)
            } else {
                let v = (2 * vcc / 3) * exp(-(local - thigh) / tauDis)
                cap.append(v)
                out.append(0)
            }
        }
        return LabIO(
            transferKind: .none,
            expression: "No linear transfer function — see the waveforms.",
            detail: "Ideal 555. Output is high while C charges through R1+R2 and low while it discharges through R2. Trips are Vcc/3 and 2Vcc/3.",
            plots: [
                LabPlot(id: "555", title: "Astable", xLabel: "Time (s)", yLabel: "Voltage (V)", series: [
                    trace("c", "Capacitor", times, cap),
                    trace("o", "OUT", times, out),
                ], smooth: false),
            ]
        )
    }

    private static func monostable(_ bag: Bag) -> LabIO {
        guard let vcc = bag["vcc"], let width = bag["width"], let r = bag["r"], width > 0, r > 0 else { return .empty }
        let span = width * 1.6
        let times = linspace(span, samples: 161)
        let tau = width / log(3)
        let cap = times.map { time -> Double in
            if time > width { return 0 }
            return vcc * (1 - exp(-time / tau))
        }
        let out = times.map { $0 <= width ? vcc : 0 }
        return LabIO(
            transferKind: .none,
            expression: "No linear transfer function — see the waveforms.",
            detail: "One shot. C charges from 0 toward Vcc and the output falls when C reaches 2Vcc/3. t = ln(3)·RC.",
            plots: [
                LabPlot(id: "one", title: "Monostable", xLabel: "Time (s)", yLabel: "Voltage (V)", series: [
                    trace("c", "Capacitor", times, cap),
                    trace("o", "OUT", times, out),
                ], smooth: false, xGuide: width, xGuideLabel: "t"),
            ]
        )
    }

    private static func flasher(_ bag: Bag) -> LabIO {
        guard let f = bag["frequency"], let duty = bag["duty"], let iled = bag["iled"], f > 0 else { return .empty }
        let times = sineTimes(frequency: f, cycles: 2, samples: 161)
        let high = duty / 100
        let current = times.map { time -> Double in
            let phase = (time * f).truncatingRemainder(dividingBy: 1)
            return phase < high ? iled : 0
        }
        return LabIO(
            transferKind: .none,
            expression: "No linear transfer function — see the waveforms.",
            detail: "LED current is the high-state value while the 555 output is high, and zero while it is low.",
            plots: [
                LabPlot(id: "led", title: "LED current", xLabel: "Time (s)", yLabel: "Current (A)", series: [
                    trace("i", "ILED", times, current),
                ], smooth: false),
            ]
        )
    }

    private static func segments(_ bag: Bag) -> LabIO {
        let digit = Int((bag["digit"] ?? 0).rounded())
        let each = bag["iseg"] ?? 0
        let mask = LabKit.segmentMask(digit: digit)
        let xs = (0..<7).map { Double($0) }
        let ys = (0..<7).map { bit -> Double in
            mask & (1 << bit) != 0 ? each : 0
        }
        return LabIO(
            transferKind: .none,
            expression: "No linear transfer function — see the waveforms.",
            detail: "Common-cathode map. A lit segment draws (Vcc − Vf) / R. Unlit segments draw nothing in this model.",
            plots: [
                LabPlot(id: "seg", title: "Segment current", xLabel: "Segment a=0 … g=6", yLabel: "Current (A)", series: [
                    trace("i", "Iseg", xs, ys),
                ], smooth: false),
            ]
        )
    }

    private static func classPower(_ bag: Bag) -> LabIO {
        guard let pout = bag["pout"], let pdc = bag["pdc"], let pd = bag["pd"] else { return .empty }
        let eta = bag["eta"] ?? 0
        return LabIO(
            transferKind: .operatingPoint,
            expression: "η = Pout / Psupply = \(fmt(eta))%",
            detail: "Planning figure for the class, not a measured stage and not an H(s). The lines are supply power, load power, and heat.",
            plots: [
                LabPlot(id: "pwr", title: "Power split", xLabel: "Sketch", yLabel: "Power (W)", series: [
                    trace("pdc", "Supply", [0, 1], [pdc, pdc]),
                    trace("pout", "Load", [0, 1], [pout, pout]),
                    trace("pd", "Heat", [0, 1], [pd, pd]),
                ], smooth: false),
            ]
        )
    }

    private static func linearDrop(_ bag: Bag) -> LabIO {
        guard let vin = bag["vin"], let drop = bag["drop"] else { return .empty }
        let vout = vin - drop
        let times = linspace(0.001, samples: 21)
        return LabIO(
            transferKind: .operatingPoint,
            expression: "Vout = Vin − Vdrop",
            detail: "DC drop across the pass element. Not a control-loop transfer function and not ripple rejection.",
            plots: [
                LabPlot(id: "reg", title: "Regulator voltages", xLabel: "Time (s)", yLabel: "Voltage (V)", series: [
                    trace("vin", "Vin", times, times.map { _ in vin }),
                    trace("vout", "Vout", times, times.map { _ in vout }),
                ], smooth: false),
            ]
        )
    }

    private static func buck(_ bag: Bag) -> LabIO {
        guard let duty = bag["duty"], let vout = bag["vout"], duty > 0, duty < 1 else { return .empty }
        let vin = vout / duty
        let period = 50e-6
        let times = linspace(period * 3, samples: 181)
        let sw = times.map { time -> Double in
            let phase = (time / period).truncatingRemainder(dividingBy: 1)
            return phase < duty ? vin : 0
        }
        return LabIO(
            transferKind: .closedForm,
            expression: "Vout / Vin = D = \(fmt(duty))",
            detail: "Ideal continuous buck. The switch node is drawn at an arbitrary 20 kHz. Inductor ripple is not computed.",
            plots: [
                LabPlot(id: "buck", title: "Switch node and output", xLabel: "Time (s)", yLabel: "Voltage (V)", series: [
                    trace("sw", "Switch", times, sw),
                    trace("vout", "Vout", times, times.map { _ in vout }),
                ], smooth: false),
            ]
        )
    }

    // MARK: - Complex and lines

    private static func complexPlane(_ bag: Bag) -> LabIO {
        guard let x = bag["x"], let y = bag["y"], let mag = bag["magnitude"] else { return .empty }
        let deg = bag["angleDeg"] ?? 0
        let xs = linspace(0, 1, samples: 16).map { x * $0 }
        let ys = linspace(0, 1, samples: 16).map { y * $0 }
        return LabIO(
            transferKind: .closedForm,
            expression: "z = x + jy = |z| ∠ θ",
            detail: "\(fmt(mag)) ∠ \(fmt(deg))°. Same number in rectangular, polar, and exponential form.",
            plots: [
                LabPlot(id: "z", title: "Complex plane", xLabel: "Real", yLabel: "Imag", series: [
                    trace("z", "z", xs, ys),
                ], showZero: true),
            ]
        )
    }

    private static func impedance(_ bag: Bag) -> LabIO {
        guard let r = bag["r"], let x = bag["x"], let mag = bag["mag"] else { return .empty }
        let xs = linspace(0, 1, samples: 16).map { r * $0 }
        let ys = linspace(0, 1, samples: 16).map { x * $0 }
        return LabIO(
            transferKind: .closedForm,
            expression: "Z = R + jX    |Z| = \(fmt(mag)) Ω",
            detail: "One frequency. Positive X is inductive. The arrow is the voltage phasor for a 1 A current.",
            plots: [
                LabPlot(id: "z", title: "Impedance phasor", xLabel: "R (Ω)", yLabel: "X (Ω)", series: [
                    trace("z", "Z", xs, ys),
                ], showZero: true),
            ]
        )
    }

    private static func lMatch(_ bag: Bag) -> LabIO {
        guard let f0 = bag["f"], let xs = bag["xs"], let xp = bag["xp"], f0 > 0, xs > 0, xp > 0 else { return .empty }
        let low = (bag["lowpass"] ?? 1) >= 0.5
        let freqs = logspace(f0 / 5, f0 * 5, samples: 81)
        let seriesX = freqs.map { frequency -> Double in
            low ? xs * frequency / f0 : -xs * f0 / frequency
        }
        let shuntX = freqs.map { frequency -> Double in
            low ? -xp * f0 / frequency : xp * frequency / f0
        }
        let q = bag["q"] ?? 0
        return LabIO(
            transferKind: .closedForm,
            expression: "Q = √(Rhi/Rlo − 1) = \(fmt(q))",
            detail: low
                ? "Low-pass L-section at one frequency: series L, shunt C. |Xs| = Q·Rlo and |Xp| = Rhi/Q. Not a broadband H(s)."
                : "High-pass L-section at one frequency: series C, shunt L. Not a broadband H(s).",
            plots: [
                LabPlot(id: "x", title: "Arm reactance", xLabel: "Frequency (Hz)", yLabel: "X (Ω)", series: [
                    trace("xs", "Series X", freqs, seriesX),
                    trace("xp", "Shunt X", freqs, shuntX),
                ], logX: true, showZero: true, xGuide: f0, xGuideLabel: "f0"),
            ]
        )
    }

    private static func quarterWave(_ bag: Bag) -> LabIO {
        guard let f0 = bag["f"], let vf = bag["vf"], let z0 = bag["z0"], let zl = bag["zload"],
              let length = bag["lengthM"], f0 > 0, vf > 0, z0 > 0, zl > 0, length > 0 else { return .empty }
        let velocity = vf * LabKit.cLight
        let freqs = logspace(f0 * 0.25, f0 * 1.75, samples: 91)
        let zin = freqs.map { frequency -> Double in
            let theta = 2 * .pi * frequency * length / velocity
            let t = tan(theta)
            guard t.isFinite, abs(t) < 1e6 else { return z0 * z0 / zl }
            let numR = zl
            let numI = z0 * t
            let denR = z0
            let denI = zl * t
            let den = denR * denR + denI * denI
            let real = (numR * denR + numI * denI) / den
            let imag = (numI * denR - numR * denI) / den
            return sqrt(real * real + imag * imag)
        }
        return LabIO(
            transferKind: .closedForm,
            expression: "Zin(f0) = Z0² / Zload",
            detail: "Ideal lossless line, real load. The length is 90° only at f0. |Zin| repeats every odd quarter-wave.",
            plots: [
                LabPlot(id: "zin", title: "|Zin|", xLabel: "Frequency (Hz)", yLabel: "|Zin| (Ω)", series: [
                    trace("zin", "|Zin|", freqs, zin),
                ], logX: true, xGuide: f0, xGuideLabel: "f0"),
            ]
        )
    }

    private static func stub(_ bag: Bag) -> LabIO {
        guard let f0 = bag["f"], let vf = bag["vf"], let z0 = bag["z0"], let length = bag["lengthM"],
              f0 > 0, vf > 0, z0 > 0, length > 0 else { return .empty }
        let shorted = (bag["shorted"] ?? 1) >= 0.5
        let velocity = vf * LabKit.cLight
        let freqs = logspace(f0 * 0.2, f0 * 1.6, samples: 81)
        let reactance = freqs.map { frequency -> Double in
            let theta = 2 * .pi * frequency * length / velocity
            let raw = shorted ? z0 * tan(theta) : -z0 / tan(theta)
            guard raw.isFinite else { return raw >= 0 ? 8 * z0 : -8 * z0 }
            return min(max(raw, -8 * z0), 8 * z0)
        }
        let expression = shorted ? "jX = j Z0 tan(βℓ)" : "jX = −j Z0 cot(βℓ)"
        return LabIO(
            transferKind: .closedForm,
            expression: expression,
            detail: "Ideal lossless stub. The curve is clipped at ±8 Z0 so the poles stay on the chart. The marker is the design frequency.",
            plots: [
                LabPlot(id: "stub", title: "Stub reactance", xLabel: "Frequency (Hz)", yLabel: "X (Ω)", series: [
                    trace("x", "X", freqs, reactance),
                ], logX: true, showZero: true, xGuide: f0, xGuideLabel: "f"),
            ]
        )
    }

    // MARK: - Sampling

    private static func bodeFirstOrder(fc: Double, lowpass: Bool) -> [LabPlot] {
        let freqs = logspace(fc / 50, fc * 50, samples: 81)
        let mag = freqs.map { frequency -> Double in
            let h = lowpass
                ? lowpassPhasor(frequency: frequency, cutoff: fc).magnitude
                : highpassPhasor(frequency: frequency, cutoff: fc).magnitude
            return 20 * log10(max(h, 1e-8))
        }
        let phase = freqs.map { frequency -> Double in
            lowpass
                ? lowpassPhasor(frequency: frequency, cutoff: fc).phaseDeg
                : highpassPhasor(frequency: frequency, cutoff: fc).phaseDeg
        }
        return [
            LabPlot(id: "db", title: "|H|", xLabel: "Frequency (Hz)", yLabel: "|H| (dB)", series: [
                trace("db", "|H|", freqs, mag),
            ], logX: true, xGuide: fc, xGuideLabel: "fc"),
            LabPlot(id: "ph", title: "Phase", xLabel: "Frequency (Hz)", yLabel: "Phase (°)", series: [
                trace("ph", "∠H", freqs, phase),
            ], logX: true, showZero: true, xGuide: fc, xGuideLabel: "fc"),
        ]
    }

    private static func resistiveSine(
        vinPeak: Double,
        gain: Double,
        currentPeak: Double,
        vinName: String = "Vin",
        voutName: String = "Vout"
    ) -> [LabPlot] {
        let f = 1_000.0
        let times = sineTimes(frequency: f, cycles: 2)
        let vin = times.map { sineValue(frequency: f, time: $0, amplitude: vinPeak) }
        let vout = times.map { sineValue(frequency: f, time: $0, amplitude: vinPeak * gain) }
        let current = times.map { sineValue(frequency: f, time: $0, amplitude: currentPeak) }
        return [
            LabPlot(id: "v", title: "Input and output", xLabel: "Time (s)", yLabel: "Voltage (V)", series: [
                trace("vin", vinName, times, vin),
                trace("vout", voutName, times, vout),
            ], showZero: true),
            LabPlot(id: "i", title: "Current", xLabel: "Time (s)", yLabel: "Current (A)", series: [
                trace("i", "I", times, current),
            ], showZero: true),
        ]
    }

    private static func volts(_ title: String, times: [Double], samples: [Double], name: String) -> LabPlot {
        LabPlot(id: title, title: title, xLabel: "Time (s)", yLabel: "Voltage (V)", series: [
            trace(name, name, times, samples),
        ], showZero: true)
    }

    private static func amps(_ title: String, times: [Double], series: [(String, [Double])]) -> LabPlot {
        LabPlot(
            id: title,
            title: title,
            xLabel: "Time (s)",
            yLabel: "Current (A)",
            series: series.map { trace($0.0, $0.0, times, $0.1) },
            showZero: true
        )
    }

    private static func trace(_ id: String, _ name: String, _ xs: [Double], _ ys: [Double]) -> LabTrace {
        let count = min(xs.count, ys.count)
        let points = (0..<count).map { PlotPoint(x: xs[$0], y: ys[$0]) }
        return LabTrace(id: id, name: name, points: points)
    }

    private static func sineTimes(frequency: Double, cycles: Double, samples: Int = 161) -> [Double] {
        linspace(cycles / frequency, samples: samples)
    }

    private static func linspace(_ span: Double, samples: Int) -> [Double] {
        guard span.isFinite, span > 0, samples >= 2 else { return [] }
        return (0..<samples).map { span * Double($0) / Double(samples - 1) }
    }

    private static func linspace(_ start: Double, _ end: Double, samples: Int) -> [Double] {
        guard start.isFinite, end.isFinite, samples >= 2, end >= start else { return [] }
        return (0..<samples).map { start + (end - start) * Double($0) / Double(samples - 1) }
    }

    private static func logspace(_ start: Double, _ end: Double, samples: Int) -> [Double] {
        guard start > 0, end > start, samples >= 2 else { return [] }
        let logA = log10(start)
        let logB = log10(end)
        return (0..<samples).map { pow(10, logA + (logB - logA) * Double($0) / Double(samples - 1)) }
    }

    private static func fmt(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        let absValue = abs(value)
        if absValue != 0, absValue < 1e-2 || absValue >= 1e4 {
            return eng(value)
        }
        return String(format: "%.4g", value)
    }

    private struct Bag {
        var map: [String: Double]
        init(_ quantities: [LabQuantity]) {
            map = Dictionary(uniqueKeysWithValues: quantities.map { ($0.id, $0.value) })
        }
        subscript(_ id: String) -> Double? {
            guard let value = map[id], value.isFinite else { return nil }
            return value
        }
    }
}
