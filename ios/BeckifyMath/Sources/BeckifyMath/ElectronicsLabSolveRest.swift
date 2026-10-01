import Foundation

extension LabSolve {
    static func rcStep(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let v0 = try LabKit.finite(inputs, "v0", "v(0)")
        let vinf = try LabKit.finite(inputs, "vinf", "v(∞)")
        var r = 0.0, c = 0.0, t = 0.0, vt = 0.0
        switch unknown {
        case "voltage":
            r = try pos(inputs, "r", "R"); c = try pos(inputs, "c", "C"); t = try pos(inputs, "t", "t")
            let tau = r * c
            vt = vinf + (v0 - vinf) * exp(-t / tau)
        case "time":
            r = try pos(inputs, "r", "R"); c = try pos(inputs, "c", "C")
            vt = try LabKit.finite(inputs, "vt", "v(t)")
            t = try exponentialTime(v0: v0, vinf: vinf, vt: vt, tau: r * c)
        case "r":
            c = try pos(inputs, "c", "C"); t = try pos(inputs, "t", "t")
            vt = try LabKit.finite(inputs, "vt", "v(t)")
            let tau = try tauFromSample(v0: v0, vinf: vinf, vt: vt, t: t)
            r = tau / c
        case "c":
            r = try pos(inputs, "r", "R"); t = try pos(inputs, "t", "t")
            vt = try LabKit.finite(inputs, "vt", "v(t)")
            let tau = try tauFromSample(v0: v0, vinf: vinf, vt: vt, t: t)
            c = tau / r
        default: throw badUnknown
        }
        let tau = r * c
        let current = (vinf - vt) / r
        return pack(
            .rcStep, headline: "v(\(eng(t)) s) = \(eng(vt)) V",
            elements: [
                src("vs", "v∞", eng(vinf) + " V", 18, 68, 18, 18),
                wire("a", 18, 18, 42, 18),
                res("r", "R", eng(r) + " Ω", 42, 18, 68, 18),
                wire("b", 68, 18, 68, 36),
                cap("c", "C", eng(c) + " F", 68, 36, 68, 68),
                wire("g", 18, 68, 68, 68),
                gnd("gnd", 68, 68),
            ],
            nodes: [
                node("src", "v∞", vinf, "V", 18, 18),
                node("cap", "vC", vt, "V", 68, 36),
                node("gnd", "GND", 0, "V", 68, 68),
            ],
            branches: [branch("i", "i(t)", current, "A", 46, 18, 64, 18)],
            quantities: [
                q("vt", "v(t)", vt, "V", unknown == "voltage"),
                q("time", "t", t, "s", unknown == "time"),
                q("r", "R", r, "Ω", unknown == "r"),
                q("c", "C", c, "F", unknown == "c"),
                q("tau", "τ", tau, "s"),
                q("current", "i(t)", current, "A"),
                q("v0", "v(0)", v0, "V"),
                q("vinf", "v(∞)", vinf, "V"),
            ],
            steps: [
                "τ = RC = \(eng(tau)) s",
                "v(t) = v∞ + (v0 − v∞) e^(−t/τ)",
                "i(t) = (v∞ − vC) / R = \(eng(current)) A",
            ],
            notes: [
                "First-order step. The capacitor voltage moves from v(0) toward v(∞).",
                "Current is set by the resistor drop at that instant.",
                "No ESR, no leakage, and the source is ideal.",
            ]
        )
    }

    static func rlStep(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let vs = try pos(inputs, "vs", "Vs")
        let r = try pos(inputs, "r", "R")
        let i0 = try LabKit.finite(inputs, "i0", "i(0)")
        let iInf = vs / r
        var l = 0.0, t = 0.0, it = 0.0
        switch unknown {
        case "current":
            l = try pos(inputs, "l", "L"); t = try pos(inputs, "t", "t")
            it = iInf + (i0 - iInf) * exp(-t * r / l)
        case "time":
            l = try pos(inputs, "l", "L")
            it = try LabKit.finite(inputs, "it", "i(t)")
            t = try exponentialTime(v0: i0, vinf: iInf, vt: it, tau: l / r)
        case "l":
            t = try pos(inputs, "t", "t")
            it = try LabKit.finite(inputs, "it", "i(t)")
            let tau = try tauFromSample(v0: i0, vinf: iInf, vt: it, t: t)
            l = tau * r
        default: throw badUnknown
        }
        let tau = l / r
        let vL = vs - it * r
        return pack(
            .rlStep, headline: "i(\(eng(t)) s) = \(eng(it)) A",
            elements: [
                src("vs", "Vs", eng(vs) + " V", 18, 68, 18, 18),
                wire("a", 18, 18, 40, 18),
                res("r", "R", eng(r) + " Ω", 40, 18, 62, 18),
                ind("l", "L", eng(l) + " H", 62, 18, 86, 18),
                wire("b", 86, 18, 86, 68),
                wire("c", 18, 68, 86, 68),
                gnd("g", 86, 68),
            ],
            nodes: [
                node("src", "Vs", vs, "V", 18, 18),
                node("l", "vL", vL, "V", 74, 18),
                node("gnd", "GND", 0, "V", 86, 68),
            ],
            branches: [branch("i", "i(t)", it, "A", 22, 18, 80, 18)],
            quantities: [
                q("current", "i(t)", it, "A", unknown == "current"),
                q("time", "t", t, "s", unknown == "time"),
                q("l", "L", l, "H", unknown == "l"),
                q("tau", "τ", tau, "s"),
                q("vL", "vL", vL, "V"),
                q("iInf", "i(∞)", iInf, "A"),
                q("vs", "Vs", vs, "V"),
                q("i0", "i(0)", i0, "A"),
                q("r", "R", r, "Ω"),
            ],
            steps: [
                "τ = L/R = \(eng(tau)) s,  i(∞) = Vs/R = \(eng(iInf)) A",
                "i(t) = i∞ + (i0 − i∞) e^(−t/τ)",
                "vL = Vs − iR = \(eng(vL)) V",
            ],
            notes: [
                "The inductor current cannot step. It moves from i(0) toward Vs/R.",
                "vL is the voltage left after the resistor drop.",
                "Ideal L and R. No core saturation.",
            ]
        )
    }

    static func filter(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let kind = try LabKit.choice(inputs, "kind", ["lowpass", "highpass"], fallback: "lowpass", name: "Response")
        let f = try pos(inputs, "f", "f")
        var r = 0.0, c = 0.0, fc = 0.0
        switch unknown {
        case "cutoff":
            r = try pos(inputs, "r", "R"); c = try pos(inputs, "c", "C")
            fc = 1 / (2 * .pi * r * c)
        case "r":
            c = try pos(inputs, "c", "C"); fc = try pos(inputs, "fc", "fc")
            r = 1 / (2 * .pi * fc * c)
        case "c":
            r = try pos(inputs, "r", "R"); fc = try pos(inputs, "fc", "fc")
            c = 1 / (2 * .pi * fc * r)
        default: throw badUnknown
        }
        let ratio = f / fc
        let h: LabKit.CX
        if kind == "lowpass" {
            h = LabKit.CX(r: 1, i: 0) / LabKit.CX(r: 1, i: ratio)
        } else {
            h = LabKit.CX(r: 0, i: ratio) / LabKit.CX(r: 1, i: ratio)
        }
        let low = kind == "lowpass"
        return pack(
            .firstOrderFilter, headline: "fc = \(eng(fc)) Hz",
            elements: [
                src("in", "Vin", "1 V", 16, 58, 16, 22),
                wire("a", 16, 22, 40, 22),
                low ? res("r", "R", eng(r) + " Ω", 40, 22, 64, 22) : cap("c", "C", eng(c) + " F", 40, 22, 64, 22),
                wire("b", 64, 22, 64, 40),
                wire("out", 64, 40, 86, 40),
                low ? cap("c", "C", eng(c) + " F", 64, 40, 64, 68) : res("r", "R", eng(r) + " Ω", 64, 40, 64, 68),
                wire("g", 16, 68, 64, 68),
                gnd("gnd", 64, 68),
            ],
            nodes: [
                node("in", "Vin", 1, "V", 16, 22),
                node("out", "|Vout|", h.mag, "V", 86, 40),
                node("gnd", "GND", 0, "V", 64, 68),
            ],
            branches: [branch("i", "I at f", h.mag / (low ? (1 / (2 * .pi * f * c)) : r), "A", 44, 22, 60, 22)],
            quantities: [
                q("fc", "fc", fc, "Hz", unknown == "cutoff"),
                q("r", "R", r, "Ω", unknown == "r"),
                q("c", "C", c, "F", unknown == "c"),
                q("mag", "|H|", h.mag, ""),
                q("phase", "Phase", h.deg, "°"),
                q("f", "f", f, "Hz"),
                q("lowpass", "Low-pass", low ? 1 : 0, ""),
            ],
            steps: [
                "fc = 1 / (2πRC) = \(eng(fc)) Hz",
                low ? "H = 1 / (1 + j f/fc)" : "H = j(f/fc) / (1 + j f/fc)",
                "|H| = \(String(format: "%.4f", h.mag)),  ∠ \(String(format: "%.2f", h.deg))°",
            ],
            notes: [
                low ? "Low-pass: the capacitor shunts highs to ground." : "High-pass: the capacitor blocks DC and passes highs.",
                "Magnitude and phase are for a 1 V phasor at the drive frequency.",
                "First-order only. No source resistance and no load.",
            ]
        )
    }

    static func rlc(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let f = try pos(inputs, "f", "Drive f")
        var r = 0.0, l = 0.0, c = 0.0
        switch unknown {
        case "response":
            r = try pos(inputs, "r", "R"); l = try pos(inputs, "l", "L"); c = try pos(inputs, "c", "C")
        case "l":
            r = try pos(inputs, "r", "R"); c = try pos(inputs, "c", "C")
            let f0in = try pos(inputs, "f0", "f0")
            l = 1 / (pow(2 * .pi * f0in, 2) * c)
        case "c":
            r = try pos(inputs, "r", "R"); l = try pos(inputs, "l", "L")
            let f0in = try pos(inputs, "f0", "f0")
            c = 1 / (pow(2 * .pi * f0in, 2) * l)
        case "r":
            l = try pos(inputs, "l", "L"); c = try pos(inputs, "c", "C")
            let qIn = try pos(inputs, "q", "Q")
            let w0 = 1 / sqrt(l * c)
            r = w0 * l / qIn
        default: throw badUnknown
        }
        let f0 = 1 / (2 * .pi * sqrt(l * c))
        let qFactor = (2 * .pi * f0 * l) / r
        let bw = f0 / qFactor
        let omega = 2 * .pi * f
        let x = omega * l - 1 / (omega * c)
        let z = LabKit.CX(r: r, i: x)
        let iMag = 1 / z.mag
        return pack(
            .seriesRLC, headline: "f0 = \(eng(f0)) Hz",
            elements: [
                src("vs", "Vs", "1 V ∠0", 14, 58, 14, 22),
                wire("a", 14, 22, 30, 22),
                res("r", "R", eng(r) + " Ω", 30, 22, 48, 22),
                ind("l", "L", eng(l) + " H", 48, 22, 68, 22),
                cap("c", "C", eng(c) + " F", 68, 22, 88, 22),
                wire("b", 88, 22, 88, 68),
                wire("g", 14, 68, 88, 68),
                gnd("gnd", 88, 68),
            ],
            nodes: [
                node("src", "Vs", 1, "V", 14, 22),
                node("z", "|Z|", z.mag, "Ω", 48, 22),
                node("gnd", "GND", 0, "V", 88, 68),
            ],
            branches: [branch("i", "|I|", iMag, "A", 20, 22, 80, 22)],
            quantities: [
                q("f0", "f0", f0, "Hz"),
                q("q", "Q", qFactor, "", unknown == "r"),
                q("bw", "Bandwidth", bw, "Hz"),
                q("r", "R", r, "Ω", unknown == "r"),
                q("l", "L", l, "H", unknown == "l"),
                q("c", "C", c, "F", unknown == "c"),
                q("zMag", "|Z|", z.mag, "Ω"),
                q("zAng", "∠Z", z.deg, "°"),
                q("x", "X", x, "Ω"),
                q("f", "Drive", f, "Hz"),
            ],
            steps: [
                "f0 = 1 / (2π √(LC)) = \(eng(f0)) Hz",
                "Q = ω0 L / R = \(String(format: "%.3f", qFactor)),  BW = f0/Q",
                "Z = R + j(ωL − 1/ωC) = \(eng(z.r)) + j\(eng(z.i)) Ω",
            ],
            notes: [
                "Series resonance is where XL and XC cancel and |Z| = R.",
                "The current arrow is the phasor magnitude for a 1 V drive.",
                "Ideal L and C. This is not a loaded tank or a crystal model.",
            ]
        )
    }

    static func rectifier(_ unknown: String, _ inputs: [String: String], bridge: Bool) throws -> LabSolution {
        let vrms = try pos(inputs, "vrms", "Vrms")
        let vf = try LabKit.nonNeg(inputs, "vf", "Vf")
        let f = try pos(inputs, "f", "f")
        let rload = try pos(inputs, "rload", "Rload")
        let drops = bridge ? 2.0 : 1.0
        let vpk = vrms * sqrt(2) - drops * vf
        guard vpk > 0 else { throw CalcError.outOfRange("The peak never clears the diode drop. Raise Vrms or lower Vf.") }
        let vdcAvg = (bridge ? 2 : 1) * vpk / .pi
        let vdcCap = vpk
        let iCap = vdcCap / rload
        let c: Double
        if unknown == "c" {
            let ripple = try pos(inputs, "ripple", "Ripple")
            c = iCap / ((bridge ? 2 : 1) * f * ripple)
        } else if unknown == "report" {
            c = try pos(inputs, "c", "C")
        } else {
            throw badUnknown
        }
        let ripple = iCap / ((bridge ? 2 : 1) * f * c)
        let circuit: ElectronicsCircuit = bridge ? .fullBridge : .halfWave
        var elements: [LabElement] = [
            src("ac", "Vac", eng(vrms) + " Vrms", 14, 58, 14, 24),
        ]
        if bridge {
            elements += [
                wire("a", 14, 24, 36, 24),
                dio("d1", "D1", eng(vf) + " V", 36, 24, 52, 16),
                dio("d2", "D2", eng(vf) + " V", 52, 16, 68, 24),
                dio("d3", "D3", eng(vf) + " V", 36, 48, 52, 36),
                dio("d4", "D4", eng(vf) + " V", 52, 36, 68, 48),
                wire("m1", 36, 24, 36, 48),
                wire("m2", 68, 24, 68, 48),
                wire("out", 52, 16, 84, 16),
                cap("c", "C", eng(c) + " F", 84, 16, 84, 62),
                res("rl", "RL", eng(rload) + " Ω", 72, 16, 72, 62),
                wire("bot", 14, 62, 84, 62),
                gnd("g", 84, 62),
            ]
        } else {
            elements += [
                wire("a", 14, 24, 36, 24),
                dio("d", "D", eng(vf) + " V", 36, 24, 58, 24),
                wire("b", 58, 24, 78, 24),
                cap("c", "C", eng(c) + " F", 78, 24, 78, 64),
                res("rl", "RL", eng(rload) + " Ω", 64, 24, 64, 64),
                wire("bot", 14, 64, 78, 64),
                gnd("g", 78, 64),
            ]
        }
        return pack(
            circuit, headline: "Vpeak out = \(eng(vpk)) V",
            elements: elements,
            nodes: [
                node("ac", "Vrms", vrms, "V", 14, 24),
                node("out", "Vpeak", vpk, "V", bridge ? 84 : 78, bridge ? 16 : 24),
                node("gnd", "GND", 0, "V", bridge ? 84 : 78, bridge ? 62 : 64),
            ],
            branches: [branch("i", "Iload (cap)", iCap, "A", bridge ? 72 : 64, 28, bridge ? 72 : 64, 56)],
            quantities: [
                q("vpk", "Vpeak out", vpk, "V"),
                q("vdcAvg", "Vdc average", vdcAvg, "V"),
                q("vdcCap", "Vdc with C", vdcCap, "V"),
                q("ripple", "Ripple", ripple, "V", unknown == "c"),
                q("c", "C", c, "F", unknown == "c"),
                q("iload", "Iload", iCap, "A"),
                q("f", "f", f, "Hz"),
                q("vf", "Vf", vf, "V"),
                q("vsrcpk", "Source peak", vrms * sqrt(2), "V"),
                q("bridge", "Bridge", bridge ? 1 : 0, ""),
            ],
            steps: [
                "Vp = Vrms·√2 − \(bridge ? "2" : "1")·Vf = \(eng(vpk)) V",
                bridge ? "No-cap average = 2·Vp/π" : "No-cap average = Vp/π",
                "Cap-input ripple ≈ I / (\(bridge ? "2f" : "f")·C) = \(eng(ripple)) V",
            ],
            notes: [
                bridge ? "Bridge: two diodes conduct each half cycle." : "Half-wave: the diode conducts on one half cycle.",
                "The capacitor estimate assumes light load and a peak near Vp minus the drops.",
                "Ripple is the ideal I/(fC) sketch, not a simulated waveform.",
            ]
        )
    }

    static func clipper(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let vp = try pos(inputs, "vp", "Source peak")
        let vf = try LabKit.nonNeg(inputs, "vf", "Vf")
        let vbias = try LabKit.finite(inputs, "vbias", "Bias")
        let vclip = vbias + vf
        let r: Double
        let ipeak: Double
        if unknown == "r" {
            ipeak = try pos(inputs, "ipeak", "Ipeak")
            guard vp > vclip else { throw CalcError.outOfRange("The source peak never reaches the clip level, so R is not set by that current.") }
            r = (vp - vclip) / ipeak
        } else if unknown == "report" {
            r = try pos(inputs, "r", "R")
            ipeak = vp > vclip ? (vp - vclip) / r : 0
        } else {
            throw badUnknown
        }
        let vout = min(vp, vclip)
        return pack(
            .shuntClipper, headline: "Vout peak = \(eng(vout)) V",
            elements: [
                src("vs", "Vp", eng(vp) + " V", 16, 60, 16, 22),
                wire("a", 16, 22, 40, 22),
                res("r", "R", eng(r) + " Ω", 40, 22, 64, 22),
                wire("b", 64, 22, 82, 22),
                dio("d", "D", eng(vf) + " V", 70, 22, 70, 64),
                src("vb", "Vb", eng(vbias) + " V", 70, 64, 70, 72),
                wire("g", 16, 72, 70, 72),
                gnd("gnd", 82, 72),
            ],
            nodes: [
                node("in", "Vp", vp, "V", 16, 22),
                node("out", "Vout", vout, "V", 82, 22),
                node("gnd", "GND", 0, "V", 82, 72),
            ],
            branches: [branch("i", "Ipeak", ipeak, "A", 44, 22, 60, 22)],
            quantities: [
                q("vout", "Vout peak", vout, "V"),
                q("vclip", "Clip level", vclip, "V"),
                q("ipeak", "Ipeak", ipeak, "A"),
                q("r", "R", r, "Ω", unknown == "r"),
                q("vp", "Vp", vp, "V"),
            ],
            steps: [
                "Clip level = Vbias + Vf = \(eng(vclip)) V",
                vp > vclip ? "Ipeak = (Vp − Vclip) / R" : "Peak stays under the clip. Diode current is 0.",
            ],
            notes: [
                "Shunt clipper. The diode conducts only after the output tries to pass the clip level.",
                "Below the clip, this ideal model ignores the diode and passes the peak.",
                "A real diode is not a perfect threshold. Softness is not modeled.",
            ]
        )
    }

    static func clamper(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        guard unknown == "report" else { throw badUnknown }
        let vp = try pos(inputs, "vp", "Source peak")
        let vf = try LabKit.nonNeg(inputs, "vf", "Vf")
        let vmin = -vf
        let vmax = 2 * vp - vf
        return pack(
            .clamper, headline: "Vmax = \(eng(vmax)) V",
            elements: [
                src("vs", "Vp", eng(vp) + " Vpk", 16, 58, 16, 28),
                wire("a", 16, 28, 36, 28),
                cap("c", "C", "DC block", 36, 28, 58, 28),
                wire("b", 58, 28, 84, 28),
                dio("d", "D", eng(vf) + " V", 68, 28, 68, 64),
                gnd("g", 68, 64),
            ],
            nodes: [
                node("in", "Vp", vp, "V", 16, 28),
                node("hi", "Vmax", vmax, "V", 84, 28),
                node("lo", "Vmin", vmin, "V", 84, 48),
                node("gnd", "GND", 0, "V", 68, 64),
            ],
            branches: [branch("i", "Steady current", 0, "A", 40, 28, 54, 28)],
            quantities: [
                q("vmax", "Vmax", vmax, "V"),
                q("vmin", "Vmin", vmin, "V"),
                q("swing", "Swing", vmax - vmin, "V"),
            ],
            steps: [
                "Negative peak clamps near −Vf.",
                "Positive peak ≈ 2·Vp − Vf.",
                "Peak-to-peak swing stays about 2·Vp.",
            ],
            notes: [
                "Series capacitor, diode cathode toward the output, anode at ground.",
                "After a few cycles the capacitor holds a DC shift. This is that steady picture.",
                "Ideal diode and a stiff source. Load bleed is not included.",
            ]
        )
    }

    static func led(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        var vs = 0.0, vf = 0.0, current = 0.0, r = 0.0
        switch unknown {
        case "resistance":
            vs = try pos(inputs, "vs", "Vs"); vf = try LabKit.nonNeg(inputs, "vf", "Vf"); current = try pos(inputs, "if", "If")
            guard vs > vf else { throw CalcError.outOfRange("Vs must be above Vf or the LED current is not positive.") }
            r = (vs - vf) / current
        case "current":
            vs = try pos(inputs, "vs", "Vs"); vf = try LabKit.nonNeg(inputs, "vf", "Vf"); r = try pos(inputs, "r", "R")
            guard vs > vf else { throw CalcError.outOfRange("Vs must be above Vf.") }
            current = (vs - vf) / r
        case "supply":
            vf = try LabKit.nonNeg(inputs, "vf", "Vf"); current = try pos(inputs, "if", "If"); r = try pos(inputs, "r", "R")
            vs = vf + current * r
        default: throw badUnknown
        }
        let anode = vs
        return pack(
            .ledSeries, headline: "R = \(eng(r)) Ω",
            elements: [
                src("vs", "Vs", eng(vs) + " V", 20, 66, 20, 22),
                wire("a", 20, 22, 42, 22),
                res("r", "R", eng(r) + " Ω", 42, 22, 66, 22),
                ledPart("led", "LED", eng(vf) + " V", 66, 22, 66, 58),
                wire("b", 20, 66, 66, 66),
                gnd("g", 66, 66),
            ],
            nodes: [
                node("src", "Vs", vs, "V", 20, 22),
                node("led", "Anode", anode - current * r, "V", 66, 22),
                node("gnd", "GND", 0, "V", 66, 66),
            ],
            branches: [branch("i", "If", current, "A", 46, 22, 62, 22)],
            quantities: [
                q("r", "R", r, "Ω", unknown == "resistance"),
                q("current", "If", current, "A", unknown == "current"),
                q("vs", "Vs", vs, "V", unknown == "supply"),
                q("pr", "P in R", current * current * r, "W"),
                q("pled", "P in LED", current * vf, "W"),
            ],
            steps: [
                "R = (Vs − Vf) / If",
                "If = \(eng(current)) A,  resistor power = I²R",
            ],
            notes: [
                "Vf is the drop you entered. It is not solved from a diode equation.",
                "The LED is forward. Reverse voltage is not checked.",
                "One LED, one resistor. Parallel strings need their own resistors.",
            ]
        )
    }

    private static func exponentialTime(v0: Double, vinf: Double, vt: Double, tau: Double) throws -> Double {
        let span = v0 - vinf
        guard abs(span) > 1e-15 else { throw CalcError.outOfRange("Start and final values are the same, so time is not defined.") }
        let ratio = (vt - vinf) / span
        guard ratio > 0, ratio < 1 else {
            throw CalcError.outOfRange("The target has to sit strictly between the start value and the final value.")
        }
        return -tau * log(ratio)
    }

    private static func tauFromSample(v0: Double, vinf: Double, vt: Double, t: Double) throws -> Double {
        let span = v0 - vinf
        guard abs(span) > 1e-15 else { throw CalcError.outOfRange("Start and final values are the same.") }
        let ratio = (vt - vinf) / span
        guard ratio > 0, ratio < 1 else {
            throw CalcError.outOfRange("The sample has to sit strictly between the start value and the final value.")
        }
        return -t / log(ratio)
    }
}
