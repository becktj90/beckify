import Foundation

extension LabSolve {
    static func inverting(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let rin = try pos(inputs, "rin", "Rin")
        let vsat = try pos(inputs, "vsat", "Swing limit")
        var vin = 0.0, rf = 0.0
        switch unknown {
        case "gain":
            vin = try LabKit.finite(inputs, "vin", "Vin")
            rf = try pos(inputs, "rf", "Rf")
        case "rf":
            vin = try LabKit.finite(inputs, "vin", "Vin")
            let av = try pos(inputs, "av", "|Av|")
            rf = av * rin
        case "vin":
            rf = try pos(inputs, "rf", "Rf")
            let mag = try pos(inputs, "voutmag", "|Vout|")
            vin = mag * rin / rf
        default: throw badUnknown
        }
        let ideal = -rf / rin * vin
        let swing = LabKit.clampSwing(ideal, limit: vsat)
        let i = vin / rin
        return pack(
            .invertingAmp, headline: "Vout = \(eng(swing.shown)) V",
            elements: opAmpSketch(inputLabel: "Vin", inputDetail: eng(vin) + " V", rin: eng(rin) + " Ω", rf: eng(rf) + " Ω"),
            nodes: [
                node("in", "Vin", vin, "V", 14, 28),
                node("sum", "V−", 0, "V", 40, 36),
                node("out", "Vout", swing.shown, "V", 86, 40),
                node("gnd", "GND", 0, "V", 48, 70),
            ],
            branches: [branch("i", "Iin", i, "A", 22, 28, 38, 36)],
            quantities: [
                q("vout", "Vout", swing.shown, "V", true),
                q("ideal", "Ideal Vout", ideal, "V"),
                q("av", "Av", -rf / rin, "", unknown == "rf"),
                q("rf", "Rf", rf, "Ω", unknown == "rf"),
                q("rin", "Rin", rin, "Ω"),
                q("vin", "Vin", vin, "V", unknown == "vin"),
                q("iin", "Iin", i, "A"),
            ],
            steps: [
                "Av = −Rf / Rin = \(String(format: "%.3f", -rf / rin))",
                "V− = 0 (virtual ground),  I = Vin / Rin",
            ],
            notes: [
                "Ideal op-amp. Input current is zero and the differential input is zero.",
                "The non-inverting input is grounded.",
                "Past the swing limit, the node shows the clip and the ideal value stays in the table.",
            ],
            warning: swing.clipped ? "Ideal gain exceeds the swing limit. The output node is clipped." : nil
        )
    }

    static func nonInverting(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let vin = try LabKit.finite(inputs, "vin", "Vin")
        let vsat = try pos(inputs, "vsat", "Swing limit")
        var rg = 0.0, rf = 0.0
        switch unknown {
        case "gain":
            rg = try pos(inputs, "rg", "Rg"); rf = try pos(inputs, "rf", "Rf")
        case "rf":
            rg = try pos(inputs, "rg", "Rg")
            let av = try pos(inputs, "av", "Av")
            guard av > 1 else { throw CalcError.outOfRange("A non-inverting gain with this divider is greater than 1.") }
            rf = rg * (av - 1)
        case "rg":
            rf = try pos(inputs, "rf", "Rf")
            let av = try pos(inputs, "av", "Av")
            guard av > 1 else { throw CalcError.outOfRange("A non-inverting gain with this divider is greater than 1.") }
            rg = rf / (av - 1)
        default: throw badUnknown
        }
        let av = 1 + rf / rg
        let ideal = av * vin
        let swing = LabKit.clampSwing(ideal, limit: vsat)
        return pack(
            .nonInvertingAmp, headline: "Vout = \(eng(swing.shown)) V",
            elements: [
                src("vin", "Vin", eng(vin) + " V", 16, 66, 16, 32),
                wire("p", 16, 32, 40, 32),
                part("oa", .opAmp, "", "", 52, 40, 52, 40),
                wire("o", 64, 40, 86, 40),
                res("rf", "Rf", eng(rf) + " Ω", 74, 40, 74, 22),
                wire("f", 74, 22, 46, 22),
                wire("m", 46, 22, 46, 48),
                res("rg", "Rg", eng(rg) + " Ω", 46, 48, 46, 66),
                gnd("g", 46, 66),
            ],
            nodes: [
                node("in", "V+", vin, "V", 16, 32),
                node("fb", "V−", vin, "V", 46, 48),
                node("out", "Vout", swing.shown, "V", 86, 40),
                node("gnd", "GND", 0, "V", 46, 66),
            ],
            branches: [branch("i", "If", (swing.shown - vin) / rf, "A", 74, 36, 74, 26)],
            quantities: [
                q("vout", "Vout", swing.shown, "V", true),
                q("av", "Av", av, "", unknown != "gain"),
                q("rf", "Rf", rf, "Ω", unknown == "rf"),
                q("rg", "Rg", rg, "Ω", unknown == "rg"),
                q("vin", "Vin", vin, "V"),
            ],
            steps: [
                "Av = 1 + Rf/Rg = \(String(format: "%.3f", av))",
                "V+ = V− = Vin",
            ],
            notes: [
                "Ideal non-inverting stage. Both inputs sit at Vin.",
                "Rg is from the inverting input to ground. Rf is the feedback.",
                "Output current into a load is not included on this screen.",
            ],
            warning: swing.clipped ? "Ideal gain exceeds the swing limit. The output node is clipped." : nil
        )
    }

    static func summing(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let v1 = try LabKit.finite(inputs, "v1", "V1")
        let r1 = try pos(inputs, "r1", "R1")
        let v2 = try LabKit.finite(inputs, "v2", "V2")
        let r2 = try pos(inputs, "r2", "R2")
        let vsat = try pos(inputs, "vsat", "Swing limit")
        let rf: Double
        if unknown == "rf" {
            let mag = try pos(inputs, "vout", "|Vout|")
            let sum = v1 / r1 + v2 / r2
            guard abs(sum) > 1e-15 else { throw CalcError.outOfRange("Both input currents are zero, so Rf is not determined.") }
            rf = mag / abs(sum)
        } else if unknown == "output" {
            rf = try pos(inputs, "rf", "Rf")
        } else {
            throw badUnknown
        }
        let ideal = -rf * (v1 / r1 + v2 / r2)
        let swing = LabKit.clampSwing(ideal, limit: vsat)
        return pack(
            .summingAmp, headline: "Vout = \(eng(swing.shown)) V",
            elements: opAmpSketch(inputLabel: "Σ", inputDetail: "", rin: "R1 R2", rf: eng(rf) + " Ω"),
            nodes: [
                node("v1", "V1", v1, "V", 12, 22),
                node("v2", "V2", v2, "V", 12, 48),
                node("sum", "V−", 0, "V", 40, 36),
                node("out", "Vout", swing.shown, "V", 86, 40),
            ],
            branches: [
                branch("i1", "I1", v1 / r1, "A", 16, 22, 36, 32),
                branch("i2", "I2", v2 / r2, "A", 16, 48, 36, 40),
            ],
            quantities: [
                q("vout", "Vout", swing.shown, "V", true),
                q("rf", "Rf", rf, "Ω", unknown == "rf"),
                q("i1", "I1", v1 / r1, "A"),
                q("i2", "I2", v2 / r2, "A"),
                q("v1", "V1", v1, "V"),
                q("r1", "R1", r1, "Ω"),
                q("v2", "V2", v2, "V"),
                q("r2", "R2", r2, "Ω"),
            ],
            steps: [
                "Vout = −Rf · (V1/R1 + V2/R2)",
                "The summing node is a virtual ground.",
            ],
            notes: [
                "Two-input inverting summer. More inputs add the same way.",
                "Each input current is V/R and does not depend on the other input.",
                "Ideal op-amp. The swing limit clips the drawn output.",
            ],
            warning: swing.clipped ? "Ideal sum exceeds the swing limit. The output node is clipped." : nil
        )
    }

    static func difference(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let v1 = try LabKit.finite(inputs, "v1", "V1")
        let v2 = try LabKit.finite(inputs, "v2", "V2")
        let r1 = try pos(inputs, "r1", "Rin")
        let vsat = try pos(inputs, "vsat", "Swing limit")
        let rf: Double
        if unknown == "rf" {
            let gain = try pos(inputs, "gain", "Gain")
            rf = gain * r1
        } else if unknown == "output" {
            rf = try pos(inputs, "rf", "Rf")
        } else {
            throw badUnknown
        }
        let ideal = (rf / r1) * (v2 - v1)
        let swing = LabKit.clampSwing(ideal, limit: vsat)
        let vp = v2 * rf / (r1 + rf)
        return pack(
            .diffAmp, headline: "Vout = \(eng(swing.shown)) V",
            elements: [
                part("oa", .opAmp, "", "", 56, 40, 56, 40),
                res("r1", "R1", eng(r1) + " Ω", 18, 48, 42, 48),
                res("rf", "Rf", eng(rf) + " Ω", 42, 48, 70, 40),
                res("r2", "R2", eng(r1) + " Ω", 18, 28, 42, 32),
                res("rg", "Rg", eng(rf) + " Ω", 42, 32, 42, 66),
                wire("o", 68, 40, 88, 40),
                gnd("g", 42, 66),
            ],
            nodes: [
                node("v1", "V1", v1, "V", 18, 48),
                node("v2", "V2", v2, "V", 18, 28),
                node("p", "V+", vp, "V", 42, 32),
                node("out", "Vout", swing.shown, "V", 88, 40),
                node("gnd", "GND", 0, "V", 42, 66),
            ],
            branches: [branch("i", "I through R1", (v1 - swing.shown) / (r1 + rf), "A", 22, 48, 40, 48)],
            quantities: [
                q("vout", "Vout", swing.shown, "V", true),
                q("gain", "Gain", rf / r1, "", unknown == "rf"),
                q("rf", "Rf", rf, "Ω", unknown == "rf"),
                q("vp", "V+", vp, "V"),
                q("v1", "V1", v1, "V"),
                q("v2", "V2", v2, "V"),
                q("r1", "Rin", r1, "Ω"),
            ],
            steps: [
                "Matched pairs: Vout = (Rf/Rin)·(V2 − V1)",
                "V+ = V2 · Rf / (Rin + Rf)",
            ],
            notes: [
                "All four resistors use two values: both inputs see Rin, both feedbacks are Rf.",
                "A mismatch would add a common-mode term. This screen assumes a match.",
                "Ideal op-amp. Not an instrumentation amplifier.",
            ],
            warning: swing.clipped ? "Ideal difference exceeds the swing limit. The output node is clipped." : nil
        )
    }

    static func integrator(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let r = try pos(inputs, "r", "R")
        let vin = try LabKit.finite(inputs, "vin", "Vin")
        let v0 = try LabKit.finite(inputs, "v0", "v(0)")
        let vsat = try pos(inputs, "vsat", "Swing limit")
        var c = 0.0, t = 0.0, vt = 0.0
        switch unknown {
        case "ramp":
            c = try pos(inputs, "c", "C"); t = try pos(inputs, "t", "t")
            vt = v0 - (vin / (r * c)) * t
        case "time":
            c = try pos(inputs, "c", "C")
            vt = try LabKit.finite(inputs, "vt", "v")
            guard abs(vin) > 1e-15 else { throw CalcError.outOfRange("Vin is zero, so the ramp never reaches a new voltage.") }
            t = (v0 - vt) * r * c / vin
            guard t > 0 else { throw CalcError.outOfRange("That target is behind the ramp direction. Time would not be positive.") }
        case "c":
            t = try pos(inputs, "t", "t")
            vt = try LabKit.finite(inputs, "vt", "v")
            let delta = v0 - vt
            guard abs(vin) > 1e-15, abs(delta) > 1e-15 else { throw CalcError.outOfRange("Need a nonzero Vin and a voltage change to solve C.") }
            c = vin * t / (r * delta)
            guard c > 0 else { throw CalcError.outOfRange("C would not be positive for that ramp direction.") }
        default: throw badUnknown
        }
        let swing = LabKit.clampSwing(vt, limit: vsat)
        return pack(
            .integrator, headline: "v(t) = \(eng(swing.shown)) V",
            elements: [
                src("vin", "Vin", eng(vin) + " V", 14, 62, 14, 36),
                res("r", "R", eng(r) + " Ω", 14, 36, 40, 36),
                part("oa", .opAmp, "", "", 54, 40, 54, 40),
                cap("c", "C", eng(c) + " F", 66, 28, 46, 28),
                wire("o", 66, 40, 88, 40),
                gnd("g", 54, 68),
            ],
            nodes: [
                node("in", "Vin", vin, "V", 14, 36),
                node("sum", "V−", 0, "V", 40, 36),
                node("out", "Vout", swing.shown, "V", 88, 40),
                node("gnd", "GND", 0, "V", 54, 68),
            ],
            branches: [branch("i", "I", vin / r, "A", 18, 36, 36, 36)],
            quantities: [
                q("vt", "v(t)", swing.shown, "V", unknown == "ramp"),
                q("ideal", "Ideal v(t)", vt, "V"),
                q("time", "t", t, "s", unknown == "time"),
                q("c", "C", c, "F", unknown == "c"),
                q("unity", "Unity f", 1 / (2 * .pi * r * c), "Hz"),
                q("vin", "Vin", vin, "V"),
                q("v0", "v(0)", v0, "V"),
                q("r", "R", r, "Ω"),
            ],
            steps: [
                "v(t) = v(0) − (Vin /(RC)) · t",
                "I = Vin / R is constant while Vin is constant.",
            ],
            notes: [
                "Ideal integrator. There is no reset resistor, so DC error integrates forever.",
                "The non-inverting input is grounded.",
                "Unity-gain frequency is 1/(2πRC), where |Av| = 1 for a sine.",
            ],
            warning: swing.clipped ? "The ramp passed the swing limit. The output node is clipped." : nil
        )
    }

    static func differentiator(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let slope = try LabKit.finite(inputs, "slope", "Slope")
        let vsat = try pos(inputs, "vsat", "Swing limit")
        var r = 0.0, c = 0.0
        switch unknown {
        case "output":
            r = try pos(inputs, "r", "R"); c = try pos(inputs, "c", "C")
        case "r":
            c = try pos(inputs, "c", "C")
            let target = try LabKit.finite(inputs, "vout", "Vout")
            guard abs(slope) > 1e-15, abs(c * slope) > 1e-18 else { throw CalcError.outOfRange("Slope is zero, so R is not set by Vout.") }
            r = -target / (c * slope)
            guard r > 0 else { throw CalcError.outOfRange("R would not be positive. Check the sign of Vout against the slope.") }
        case "c":
            r = try pos(inputs, "r", "R")
            let target = try LabKit.finite(inputs, "vout", "Vout")
            guard abs(slope) > 1e-15 else { throw CalcError.outOfRange("Slope is zero, so C is not set by Vout.") }
            c = -target / (r * slope)
            guard c > 0 else { throw CalcError.outOfRange("C would not be positive. Check the sign of Vout against the slope.") }
        default: throw badUnknown
        }
        let ideal = -r * c * slope
        let swing = LabKit.clampSwing(ideal, limit: vsat)
        return pack(
            .differentiator, headline: "Vout = \(eng(swing.shown)) V",
            elements: [
                cap("c", "C", eng(c) + " F", 16, 36, 40, 36),
                part("oa", .opAmp, "", "", 54, 40, 54, 40),
                res("r", "R", eng(r) + " Ω", 66, 28, 46, 28),
                wire("o", 66, 40, 88, 40),
                gnd("g", 54, 68),
            ],
            nodes: [
                node("in", "Slope", slope, "V/s", 16, 36),
                node("sum", "V−", 0, "V", 40, 36),
                node("out", "Vout", swing.shown, "V", 88, 40),
                node("gnd", "GND", 0, "V", 54, 68),
            ],
            branches: [branch("i", "I", c * slope, "A", 20, 36, 36, 36)],
            quantities: [
                q("vout", "Vout", swing.shown, "V", true),
                q("ideal", "Ideal Vout", ideal, "V"),
                q("r", "R", r, "Ω", unknown == "r"),
                q("c", "C", c, "F", unknown == "c"),
                q("slope", "Slope", slope, "V/s"),
            ],
            steps: [
                "Vout = −RC · (dv/dt)",
                "I = C · slope",
            ],
            notes: [
                "A constant slope in gives a constant voltage out.",
                "Ideal differentiator. Real ones add a series resistor so they do not gain noise forever.",
                "The non-inverting input is grounded.",
            ],
            warning: swing.clipped ? "Ideal output exceeds the swing limit. The node is clipped." : nil
        )
    }

    static func comparator(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        guard unknown == "output" else { throw badUnknown }
        let vin = try LabKit.finite(inputs, "vin", "Vin")
        let vref = try LabKit.finite(inputs, "vref", "Vref")
        let voh = try LabKit.finite(inputs, "voh", "High rail")
        let vol = try LabKit.finite(inputs, "vol", "Low rail")
        let high = vin >= vref
        let vout = high ? voh : vol
        return pack(
            .comparator, headline: high ? "Output high" : "Output low",
            elements: [
                src("vin", "Vin", eng(vin) + " V", 14, 66, 14, 30),
                src("vr", "Vref", eng(vref) + " V", 14, 66, 14, 50),
                wire("p", 14, 30, 40, 32),
                wire("m", 14, 50, 40, 48),
                part("oa", .opAmp, "", "", 54, 40, 54, 40),
                wire("o", 66, 40, 88, 40),
            ],
            nodes: [
                node("in", "Vin", vin, "V", 14, 30),
                node("ref", "Vref", vref, "V", 14, 50),
                node("out", "Vout", vout, "V", 88, 40),
            ],
            branches: [branch("i", "Iin", 0, "A", 20, 30, 36, 32)],
            quantities: [
                q("vout", "Vout", vout, "V", true),
                q("high", high ? "High" : "Low", high ? 1 : 0, ""),
                q("vin", "Vin", vin, "V"),
                q("vref", "Vref", vref, "V"),
                q("voh", "High rail", voh, "V"),
                q("vol", "Low rail", vol, "V"),
            ],
            steps: [
                "No feedback. If Vin ≥ Vref, Vout = high rail.",
                "Otherwise Vout = low rail.",
            ],
            notes: [
                "Open-loop comparator. There is no linear gain to solve.",
                "The threshold is the reference you enter. Hysteresis is not added.",
                "Input current is taken as zero.",
            ]
        )
    }

    private static func opAmpSketch(inputLabel: String, inputDetail: String, rin: String, rf: String) -> [LabElement] {
        [
            src("in", inputLabel, inputDetail, 14, 66, 14, 28),
            res("rin", "Rin", rin, 14, 28, 40, 36),
            part("oa", .opAmp, "", "", 54, 40, 54, 40),
            res("rf", "Rf", rf, 70, 28, 48, 36),
            wire("o", 66, 40, 88, 40),
            gnd("g", 54, 68),
            wire("pg", 54, 52, 54, 68),
        ]
    }
}
