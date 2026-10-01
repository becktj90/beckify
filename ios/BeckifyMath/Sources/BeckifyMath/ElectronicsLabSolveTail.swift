import Foundation

extension LabSolve {
    static func astable(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let vcc = try pos(inputs, "vcc", "Vcc")
        var r1 = 0.0, r2 = 0.0, c = 0.0
        switch unknown {
        case "frequency":
            r1 = try pos(inputs, "r1", "R1"); r2 = try pos(inputs, "r2", "R2"); c = try pos(inputs, "c", "C")
        case "c":
            r1 = try pos(inputs, "r1", "R1"); r2 = try pos(inputs, "r2", "R2")
            let f = try pos(inputs, "frequency", "f")
            c = 1 / (f * Timer555.ln2 * (r1 + 2 * r2))
        case "r1":
            r2 = try pos(inputs, "r2", "R2"); c = try pos(inputs, "c", "C")
            let f = try pos(inputs, "frequency", "f")
            r1 = 1 / (f * Timer555.ln2 * c) - 2 * r2
            guard r1 > 0 else { throw CalcError.outOfRange("R1 would not be positive. Frequency is too low for R2 and C.") }
        case "r2":
            r1 = try pos(inputs, "r1", "R1"); c = try pos(inputs, "c", "C")
            let f = try pos(inputs, "frequency", "f")
            r2 = (1 / (f * Timer555.ln2 * c) - r1) / 2
            guard r2 > 0 else { throw CalcError.outOfRange("R2 would not be positive. Frequency is too low for R1 and C.") }
        case "resistors":
            c = try pos(inputs, "c", "C")
            let f = try pos(inputs, "frequency", "f")
            let duty = try pos(inputs, "duty", "Duty") / 100
            guard duty > 0.5, duty < 1 else {
                throw CalcError.outOfRange("A plain 555 astable duty is above 50% and below 100%. A steering diode is a different circuit.")
            }
            let k = (1 - duty) / (2 * duty - 1)
            let sum = 1 / (f * Timer555.ln2 * c)
            r1 = sum / (1 + 2 * k)
            r2 = k * r1
        default: throw badUnknown
        }
        let timed = try Timer555.astable(r1: r1, r2: r2, capacitance: c, diodeSteering: false)
        let iCharge = (vcc - vcc / 3) / (r1 + r2)
        let iDis = (2 * vcc / 3) / r2
        return pack(
            .astable555, headline: "f = \(eng(timed.frequency)) Hz",
            elements: timerBox(vcc: vcc, r1: r1, r2: r2, c: c),
            nodes: [
                node("vcc", "Vcc", vcc, "V", 70, 14),
                node("ctrl", "CTRL", 2 * vcc / 3, "V", 78, 36),
                node("cap", "C trip", vcc / 3, "V", 48, 62),
                node("out", "OUT high", vcc, "V", 88, 40),
                node("gnd", "GND", 0, "V", 48, 74),
            ],
            branches: [
                branch("chg", "Charge @ 1/3", iCharge, "A", 62, 18, 62, 34),
                branch("dis", "Discharge @ 2/3", iDis, "A", 48, 40, 48, 56),
            ],
            quantities: [
                q("frequency", "f", timed.frequency, "Hz", unknown == "frequency"),
                q("duty", "Duty", timed.dutyPercent, "%", unknown == "resistors"),
                q("thigh", "t high", timed.timeHigh, "s"),
                q("tlow", "t low", timed.timeLow, "s"),
                q("r1", "R1", r1, "Ω", unknown == "r1" || unknown == "resistors"),
                q("r2", "R2", r2, "Ω", unknown == "r2" || unknown == "resistors"),
                q("c", "C", c, "F", unknown == "c"),
                q("vcc", "Vcc", vcc, "V"),
            ],
            steps: [
                "tH = ln(2)·(R1+R2)·C,  tL = ln(2)·R2·C",
                "f = 1 / (ln(2)·(R1+2·R2)·C) = \(eng(timed.frequency)) Hz",
                "Duty = (R1+R2)/(R1+2·R2) = \(String(format: "%.2f", timed.dutyPercent))%",
            ],
            notes: [
                "Plain astable: output high while C charges through R1+R2, low while it discharges through R2.",
                "CTRL is the internal 2/3 Vcc tap. Threshold trips are 1/3 and 2/3 Vcc.",
                "Ideal pins. A real 555 output high is about 1.5 V under Vcc and is not modeled.",
                "OUT is drawn at the high rail. It spends the low time near ground.",
            ]
        )
    }

    static func monostable(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let vcc = try pos(inputs, "vcc", "Vcc")
        var r = 0.0, c = 0.0
        switch unknown {
        case "width":
            r = try pos(inputs, "r", "R"); c = try pos(inputs, "c", "C")
        case "r":
            c = try pos(inputs, "c", "C")
            let width = try pos(inputs, "width", "t")
            r = width / (Timer555.ln3 * c)
        case "c":
            r = try pos(inputs, "r", "R")
            let width = try pos(inputs, "width", "t")
            c = width / (Timer555.ln3 * r)
        default: throw badUnknown
        }
        let timed = try Timer555.monostable(resistance: r, capacitance: c)
        return pack(
            .monostable555, headline: "t = \(eng(timed.pulseWidth)) s",
            elements: [
                part("u", .timer555, "555", "", 58, 40, 58, 40),
                res("r", "R", eng(r) + " Ω", 36, 16, 36, 36),
                cap("c", "C", eng(c) + " F", 36, 36, 36, 68),
                src("vcc", "Vcc", eng(vcc) + " V", 78, 68, 78, 14),
                wire("t", 36, 16, 78, 16),
                gnd("g", 36, 68),
            ],
            nodes: [
                node("vcc", "Vcc", vcc, "V", 78, 14),
                node("out", "OUT", vcc, "V", 86, 40),
                node("cap", "C end", 2 * vcc / 3, "V", 36, 36),
                node("gnd", "GND", 0, "V", 36, 68),
            ],
            branches: [branch("i", "I at start", vcc / r, "A", 36, 20, 36, 32)],
            quantities: [
                q("width", "t", timed.pulseWidth, "s", unknown == "width"),
                q("r", "R", r, "Ω", unknown == "r"),
                q("c", "C", c, "F", unknown == "c"),
                q("retrigger", "Max rate", timed.maxRetriggerHz, "Hz"),
                q("vcc", "Vcc", vcc, "V"),
            ],
            steps: [
                "t = ln(3)·R·C ≈ 1.1·R·C",
                "The cap charges from 0 toward Vcc and the pulse ends at 2/3 Vcc.",
            ],
            notes: [
                "One-shot. Trigger is a brief low. Retriggering during the pulse is not modeled.",
                "Initial timing current is about Vcc/R, then it falls.",
                "Ideal 555. Output high during the pulse is drawn at Vcc.",
            ]
        )
    }

    static func flasher(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let vcc = try pos(inputs, "vcc", "Vcc")
        let r1 = try pos(inputs, "r1", "R1")
        let r2 = try pos(inputs, "r2", "R2")
        let vf = try LabKit.nonNeg(inputs, "vf", "Vf")
        guard vcc > vf else { throw CalcError.outOfRange("Vcc must be above the LED Vf.") }
        var c = 0.0
        var rled = 0.0
        switch unknown {
        case "rate":
            c = try pos(inputs, "c", "C"); rled = try pos(inputs, "rled", "Rled")
        case "c":
            rled = try pos(inputs, "rled", "Rled")
            let f = try pos(inputs, "frequency", "f")
            c = 1 / (f * Timer555.ln2 * (r1 + 2 * r2))
        case "rled":
            c = try pos(inputs, "c", "C")
            let iled = try pos(inputs, "iled", "LED current")
            rled = (vcc - vf) / iled
        default: throw badUnknown
        }
        let timed = try Timer555.astable(r1: r1, r2: r2, capacitance: c, diodeSteering: false)
        let iled = (vcc - vf) / rled
        return pack(
            .ledFlasher, headline: "f = \(eng(timed.frequency)) Hz",
            elements: timerBox(vcc: vcc, r1: r1, r2: r2, c: c) + [
                res("rled", "Rled", eng(rled) + " Ω", 88, 40, 88, 56),
                ledPart("led", "LED", eng(vf) + " V", 88, 56, 88, 70),
            ],
            nodes: [
                node("vcc", "Vcc", vcc, "V", 70, 14),
                node("out", "OUT high", vcc, "V", 88, 40),
                node("led", "LED", vf, "V", 88, 56),
                node("gnd", "GND", 0, "V", 48, 74),
            ],
            branches: [branch("led", "ILED high", iled, "A", 88, 44, 88, 66)],
            quantities: [
                q("frequency", "f", timed.frequency, "Hz", unknown == "rate"),
                q("duty", "Duty", timed.dutyPercent, "%"),
                q("c", "C", c, "F", unknown == "c"),
                q("rled", "Rled", rled, "Ω", unknown == "rled"),
                q("r1", "R1", r1, "Ω"),
                q("r2", "R2", r2, "Ω"),
                q("vcc", "Vcc", vcc, "V"),
                q("iled", "ILED high", iled, "A"),
                q("iavg", "ILED average", iled * timed.dutyPercent / 100, "A"),
            ],
            steps: [
                "Flash rate uses the same astable identity as the 555 screen.",
                "While OUT is high, ILED = (Vcc − Vf) / Rled.",
            ],
            notes: [
                "The LED is on during the output-high time. Average current is duty times that.",
                "Ideal rail-to-rail output. A real 555 high is lower, so the LED current is a bit less.",
                "R1 and R2 set the rate. Rled sets the brightness, not the rate.",
            ]
        )
    }

    static func sevenSeg(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let digitRaw = try LabKit.choice(
            inputs, "digit",
            Set((0...9).map(String.init)),
            fallback: "8",
            name: "Digit"
        )
        let digit = Int(digitRaw) ?? 0
        let vcc = try pos(inputs, "vcc", "Vcc")
        let vf = try LabKit.nonNeg(inputs, "vf", "Vf")
        guard vcc > vf else { throw CalcError.outOfRange("Vcc must be above the segment Vf.") }
        let mask = LabKit.segmentMask(digit: digit)
        let count = (0..<7).reduce(0) { $0 + ((mask & (1 << $1)) != 0 ? 1 : 0) }
        let r: Double
        let iseg: Double
        if unknown == "r" {
            iseg = try pos(inputs, "iseg", "I per segment")
            r = (vcc - vf) / iseg
        } else if unknown == "map" {
            r = try pos(inputs, "r", "R")
            iseg = (vcc - vf) / r
        } else {
            throw badUnknown
        }
        let total = Double(count) * iseg
        return pack(
            .sevenSegment, headline: "Digit \(digit): \(LabKit.segmentNames(mask))",
            elements: [
                src("vcc", "Vcc", eng(vcc) + " V", 16, 64, 16, 18),
                res("r", "R×\(count)", eng(r) + " Ω", 16, 18, 40, 18),
                part("seg", .sevenSegment, "\(digit)", LabKit.segmentNames(mask), 62, 40, 62, 40, flags: mask),
                gnd("g", 62, 70),
            ],
            nodes: [
                node("vcc", "Vcc", vcc, "V", 16, 18),
                node("seg", "Segment", vf, "V", 46, 40),
                node("gnd", "Cathode", 0, "V", 62, 70),
            ],
            branches: [branch("it", "Itotal", total, "A", 20, 18, 36, 18)],
            quantities: [
                q("count", "Segments on", Double(count), ""),
                q("iseg", "I each", iseg, "A"),
                q("itotal", "I total", total, "A"),
                q("r", "R each", r, "Ω", unknown == "r"),
                q("digit", "Digit", Double(digit), ""),
                q("vcc", "Vcc", vcc, "V"),
            ],
            steps: [
                "Common cathode. Each lit segment has its own resistor.",
                "I = (Vcc − Vf) / R,  total = (segments on) · I",
            ],
            notes: [
                "Segment map is the usual common-cathode pattern: 0 lights a–f, 1 lights b and c, 8 lights all.",
                "Blank segments draw no current in this model.",
                "A decoder chip is not simulated. You pick the digit and the map is shown.",
            ]
        )
    }

    static func classOverview(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        guard unknown == "dissipation" else { throw badUnknown }
        let kind = try LabKit.choice(inputs, "ampClass", ["A", "B", "AB", "D"], fallback: "B", name: "Class")
        let pout = try pos(inputs, "pout", "Pout")
        let vsupply = try pos(inputs, "vsupply", "Supply")
        let ideal: Double
        let idealNote: String
        switch kind {
        case "A":
            ideal = 0.25
            idealNote = "Class A into a resistor, ideal maximum 25%."
        case "B":
            ideal = .pi / 4
            idealNote = "Class B push-pull, ideal maximum π/4."
        case "AB":
            ideal = 0.60
            idealNote = "Class AB planning figure 60%, between A and B. Not a measurement."
        default:
            ideal = 0.90
            idealNote = "Class D planning figure 90% for an ideal switch. Not a measurement."
        }
        let eta = try LabKit.optionalPercent(inputs, "eta") ?? ideal
        let pdc = pout / eta
        let pd = pdc - pout
        let isupply = pdc / vsupply
        return pack(
            .classOverview, headline: "Pd = \(eng(pd)) W",
            elements: [
                src("vs", "Vs", eng(vsupply) + " V", 18, 64, 18, 24),
                part("dev", .zBlock, "Class \(kind)", "\(Int((eta * 100).rounded()))%", 40, 24, 68, 24),
                res("rl", "Load", eng(pout) + " W", 68, 24, 86, 50),
                gnd("g", 86, 64),
                wire("b", 18, 64, 86, 64),
            ],
            nodes: [
                node("s", "Supply", vsupply, "V", 18, 24),
                node("o", "Pout", pout, "W", 86, 50),
                node("gnd", "GND", 0, "V", 86, 64),
            ],
            branches: [branch("is", "Isupply", isupply, "A", 18, 50, 18, 30)],
            quantities: [
                q("eta", "η", eta * 100, "%", true),
                q("pdc", "From supply", pdc, "W"),
                q("pd", "Heat", pd, "W"),
                q("is", "Isupply", isupply, "A"),
                q("pout", "Pout", pout, "W"),
            ],
            steps: [
                idealNote,
                "Psupply = Pout / η,  heat = Psupply − Pout",
            ],
            notes: [
                "Efficiencies are ideal class figures, or the override you typed.",
                "Class A here is the resistively loaded 25% case, not a transformer-coupled 50% case.",
                "Not a heatsink design and not a measured amplifier.",
            ]
        )
    }

    static func discretePower(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        guard unknown == "power" else { throw badUnknown }
        let vcc = try pos(inputs, "vcc", "Vcc")
        let r1 = try pos(inputs, "r1", "R1")
        let r2 = try pos(inputs, "r2", "R2")
        let rc = try pos(inputs, "rc", "Rc")
        let re = try pos(inputs, "re", "Re")
        let beta = try pos(inputs, "beta", "β")
        let bias = LabKit.bjtBias(vcc: vcc, r1: r1, r2: r2, rc: rc, re: re, beta: beta)
        let pq = bias.ic * bias.vce
        let prc = bias.ic * bias.ic * rc
        let pre = bias.ie * bias.ie * re
        let psup = vcc * (bias.ic + bias.iR1)
        return pack(
            .discretePower, headline: "Pq = \(eng(pq)) W",
            elements: LabKit.bjtElements(bias, vcc: vcc, r1: r1, r2: r2, rc: rc, re: re),
            nodes: LabKit.bjtNodes(bias, vcc: vcc),
            branches: LabKit.bjtBranches(bias),
            quantities: [
                q("pq", "P in Q", pq, "W", true),
                q("prc", "P in Rc", prc, "W"),
                q("pre", "P in Re", pre, "W"),
                q("psup", "From Vcc", psup, "W"),
                q("ic", "Ic", bias.ic, "A"),
                q("vce", "Vce", bias.vce, "V"),
                q("vc", "Vc", bias.vc, "V"),
                q("vb", "Vb", bias.vb, "V"),
                q("vcc", "Vcc", vcc, "V"),
                q("rc", "Rc", rc, "Ω"),
            ],
            steps: [
                "Same divider-bias point as the BJT screen.",
                "Pq ≈ Ic·Vce. Resistor power is I²R.",
            ],
            notes: [
                "Quiescent class-A sketch. Signal swing would move the instantaneous power.",
                "Supply power counts collector current plus the base-divider current.",
                "Vbe = 0.7 V, constant β. Not a thermal design.",
            ],
            warning: bias.saturated ? "The point is saturated, so this is not a linear class-A bias." : (bias.cutoff ? "The transistor is cut off, so quiescent power in Q is about zero." : nil)
        )
    }

    static func opAmpPower(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let vin = try LabKit.finite(inputs, "vin", "Vin")
        let rg = try pos(inputs, "rg", "Rg")
        let rl = try pos(inputs, "rl", "RL")
        let vsat = try pos(inputs, "vsat", "Swing limit")
        let rf: Double
        if unknown == "rf" {
            let av = try pos(inputs, "av", "Av")
            guard av > 1 else { throw CalcError.outOfRange("This non-inverting stage needs Av > 1.") }
            rf = rg * (av - 1)
        } else if unknown == "load" {
            rf = try pos(inputs, "rf", "Rf")
        } else {
            throw badUnknown
        }
        let av = 1 + rf / rg
        let ideal = av * vin
        let swing = LabKit.clampSwing(ideal, limit: vsat)
        let iout = swing.shown / rl
        let pload = swing.shown * iout
        return pack(
            .opAmpPower, headline: "Pload = \(eng(pload)) W",
            elements: [
                src("vin", "Vin", eng(vin) + " V", 14, 66, 14, 32),
                wire("p", 14, 32, 40, 32),
                part("oa", .opAmp, "", "", 52, 40, 52, 40),
                wire("o", 64, 40, 86, 40),
                res("rf", "Rf", eng(rf) + " Ω", 72, 40, 72, 24),
                wire("fb", 72, 24, 46, 24),
                wire("m", 46, 24, 46, 48),
                res("rg", "Rg", eng(rg) + " Ω", 46, 48, 46, 66),
                res("rl", "RL", eng(rl) + " Ω", 86, 40, 86, 66),
                gnd("g", 46, 66),
            ],
            nodes: [
                node("in", "Vin", vin, "V", 14, 32),
                node("out", "Vout", swing.shown, "V", 86, 40),
                node("gnd", "GND", 0, "V", 86, 66),
            ],
            branches: [branch("iout", "Iout", iout, "A", 86, 44, 86, 62)],
            quantities: [
                q("vout", "Vout", swing.shown, "V"),
                q("iout", "Iout", iout, "A"),
                q("pload", "Pload", pload, "W", true),
                q("av", "Av", av, ""),
                q("rf", "Rf", rf, "Ω", unknown == "rf"),
            ],
            steps: [
                "Av = 1 + Rf/Rg",
                "Iout = Vout / RL,  Pload = Vout · Iout",
            ],
            notes: [
                "Teaching power stage: an ideal op-amp into a resistor.",
                "Supply current is about the load current. Quiescent current is omitted.",
                "A real op-amp has a short-circuit current limit this screen does not apply.",
            ],
            warning: swing.clipped ? "The ideal output is past the swing limit, so load power uses the clipped voltage." : nil
        )
    }

    static func linearDrop(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        var vin = 0.0, vout = 0.0, iload = 0.0
        switch unknown {
        case "drop":
            vin = try pos(inputs, "vin", "Vin")
            vout = try pos(inputs, "vout", "Vout")
            iload = try pos(inputs, "iload", "Iload")
            guard vin > vout else { throw CalcError.outOfRange("Vin has to be above Vout. A linear pass element cannot boost.") }
        case "iload":
            vin = try pos(inputs, "vin", "Vin")
            vout = try pos(inputs, "vout", "Vout")
            let pd = try pos(inputs, "pdmax", "Pd max")
            guard vin > vout else { throw CalcError.outOfRange("Vin has to be above Vout.") }
            iload = pd / (vin - vout)
        case "vin":
            vout = try pos(inputs, "vout", "Vout")
            iload = try pos(inputs, "iload", "Iload")
            let dropout = try pos(inputs, "dropout", "Dropout")
            vin = vout + dropout
        default: throw badUnknown
        }
        let drop = vin - vout
        let pd = drop * iload
        let eta = vout / vin
        return pack(
            .linearDrop, headline: "Pd = \(eng(pd)) W",
            elements: [
                src("vin", "Vin", eng(vin) + " V", 16, 64, 16, 22),
                part("pass", .zBlock, "Pass", eng(drop) + " V", 36, 22, 62, 22),
                res("rl", "Load", eng(vout) + " V", 74, 22, 74, 64),
                wire("a", 16, 22, 36, 22),
                wire("b", 62, 22, 74, 22),
                wire("g", 16, 64, 74, 64),
                gnd("gnd", 74, 64),
            ],
            nodes: [
                node("in", "Vin", vin, "V", 16, 22),
                node("out", "Vout", vout, "V", 74, 22),
                node("gnd", "GND", 0, "V", 74, 64),
            ],
            branches: [branch("i", "Iload", iload, "A", 40, 22, 58, 22)],
            quantities: [
                q("drop", "Vdrop", drop, "V", unknown == "drop"),
                q("pd", "Pd", pd, "W"),
                q("eta", "η", eta * 100, "%"),
                q("iload", "Iload", iload, "A", unknown == "iload"),
                q("vin", "Vin", vin, "V", unknown == "vin"),
                q("vout", "Vout", vout, "V"),
                q("pload", "Pload", vout * iload, "W"),
            ],
            steps: [
                "Vdrop = Vin − Vout",
                "Pd = Vdrop · Iload,  η = Vout / Vin",
            ],
            notes: [
                "Linear drop only. The pass element burns the difference.",
                "No quiescent current, no ripple rejection, no adjust pin.",
                "Min Vin is Vout plus the dropout you enter.",
            ]
        )
    }

    static func buck(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let vin = try pos(inputs, "vin", "Vin")
        let iout = try pos(inputs, "iout", "Iout")
        var vout = 0.0
        var duty = 0.0
        switch unknown {
        case "duty", "iin":
            vout = try pos(inputs, "vout", "Vout")
            guard vout < vin else { throw CalcError.outOfRange("An ideal buck only steps down. Vout must be below Vin.") }
            duty = vout / vin
        case "vout":
            duty = try pos(inputs, "duty", "Duty")
            guard duty < 1 else { throw CalcError.outOfRange("Duty for a buck is below 1.") }
            vout = duty * vin
        default: throw badUnknown
        }
        let iin = iout * duty
        let pout = vout * iout
        return pack(
            .idealBuck, headline: "D = \(String(format: "%.3f", duty))",
            elements: [
                src("vin", "Vin", eng(vin) + " V", 14, 64, 14, 20),
                part("sw", .zBlock, "Switch", "D=\(String(format: "%.2f", duty))", 32, 20, 52, 20),
                ind("l", "L", "ideal", 52, 20, 74, 20),
                cap("c", "C", "ideal", 80, 20, 80, 64),
                res("rl", "Load", eng(iout) + " A", 68, 36, 68, 64),
                wire("g", 14, 64, 80, 64),
                gnd("gnd", 80, 64),
            ],
            nodes: [
                node("in", "Vin", vin, "V", 14, 20),
                node("sw", "Switch avg", vout, "V", 52, 20),
                node("out", "Vout", vout, "V", 80, 20),
                node("gnd", "GND", 0, "V", 80, 64),
            ],
            branches: [
                branch("iin", "Iin", iin, "A", 18, 48, 18, 26),
                branch("il", "IL", iout, "A", 56, 20, 70, 20),
            ],
            quantities: [
                q("duty", "Duty", duty, "", unknown == "duty"),
                q("vout", "Vout", vout, "V", unknown == "vout"),
                q("iin", "Iin", iin, "A", unknown == "iin"),
                q("pout", "Pout", pout, "W"),
            ],
            steps: [
                "D = Vout / Vin",
                "Iin = Iout · D  (lossless power balance)",
            ],
            notes: [
                "Ideal continuous buck. Efficiency is 100% in this sketch.",
                "Switch-node average equals Vout. Ripple current is not computed.",
                "Not a controller design. No diode drop, no MOSFET, no compensation.",
            ]
        )
    }

    static func complexConvert(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let x: Double
        let y: Double
        if unknown == "polar" {
            x = try LabKit.finite(inputs, "x", "Real")
            y = try LabKit.finite(inputs, "y", "Imag")
        } else if unknown == "rect" {
            let mag = try LabKit.nonNeg(inputs, "magnitude", "Magnitude")
            let deg = try LabKit.finite(inputs, "angleDeg", "Angle")
            let rad = deg * .pi / 180
            x = mag * cos(rad)
            y = mag * sin(rad)
        } else {
            throw badUnknown
        }
        let z = LabKit.CX(r: x, i: y)
        let tip = phasorTip(x: x, y: y)
        return pack(
            .complexConvert, headline: "\(eng(z.mag)) ∠ \(String(format: "%.2f", z.deg))°",
            elements: [
                wire("re", 18, 58, 86, 58),
                wire("im", 52, 70, 52, 16),
                wire("ph", 52, 58, tip.x, tip.y),
            ],
            nodes: [
                node("origin", "0", 0, "", 52, 58),
                node("tip", "Tip", z.mag, "∠", tip.x, tip.y),
            ],
            branches: [branch("phasor", "Phasor", z.mag, "", 52, 58, tip.x, tip.y)],
            quantities: [
                q("x", "Real", z.r, "", unknown == "rect"),
                q("y", "Imag", z.i, "", unknown == "rect"),
                q("magnitude", "Magnitude", z.mag, "", unknown == "polar"),
                q("angleDeg", "Angle", z.deg, "°", unknown == "polar"),
                q("angleRad", "Radians", z.rad, "rad"),
            ],
            steps: [
                "r = √(x² + y²),  θ = atan2(y, x)",
                "x = r cos θ,  y = r sin θ",
                "Exponential: \(eng(z.mag)) e^(j \(String(format: "%.4f", z.rad)) rad)",
            ],
            notes: [
                "Angle is measured from the positive real axis, counter-clockwise.",
                "Polar, rectangular, and exponential forms are the same value.",
                "A magnitude of zero has angle 0 by convention.",
            ]
        )
    }

    static func impedance(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        guard unknown == "result" else { throw badUnknown }
        let combo = try LabKit.choice(inputs, "combo", ["series", "parallel"], fallback: "series", name: "Connection")
        let z1 = LabKit.CX(r: try LabKit.finite(inputs, "r1", "R1"), i: try LabKit.finite(inputs, "x1", "X1"))
        let z2 = LabKit.CX(r: try LabKit.finite(inputs, "r2", "R2"), i: try LabKit.finite(inputs, "x2", "X2"))
        let z: LabKit.CX
        if combo == "series" {
            z = z1 + z2
        } else {
            let den = z1 + z2
            guard den.mag > 1e-12 else { throw CalcError.outOfRange("The two impedances cancel. Parallel combination is not finite.") }
            z = (z1 * z2) / den
        }
        return pack(
            .impedanceCombo, headline: "\(eng(z.r)) + j\(eng(z.i)) Ω",
            elements: [
                part("z1", .zBlock, "Z1", "\(eng(z1.r))+j\(eng(z1.i))", 22, 28, 46, 28),
                part("z2", .zBlock, "Z2", "\(eng(z2.r))+j\(eng(z2.i))", 58, 28, 82, 28),
                wire("join", 46, 28, 58, 28),
            ],
            nodes: [
                node("a", "Zin", z.mag, "Ω", 22, 28),
                node("b", "Right", 0, "Ω", 82, 28),
            ],
            branches: [branch("i", "|I| for 1 V", 1 / max(z.mag, 1e-12), "A", 30, 28, 74, 28)],
            quantities: [
                q("r", "R", z.r, "Ω", true),
                q("x", "X", z.i, "Ω", true),
                q("mag", "|Z|", z.mag, "Ω"),
                q("ang", "∠Z", z.deg, "°"),
            ],
            steps: [
                combo == "series" ? "Z = Z1 + Z2" : "Z = Z1·Z2 / (Z1 + Z2)",
                "Rectangular \(eng(z.r)) + j\(eng(z.i)),  polar \(eng(z.mag)) ∠ \(String(format: "%.2f", z.deg))°",
            ],
            notes: [
                "Each block is R + jX. Positive X is inductive, negative X is capacitive.",
                "Series adds. Parallel uses the product over the sum.",
                "The current arrow is |1 V / Z|.",
            ]
        )
    }

    static func lMatch(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        guard unknown == "parts" else { throw badUnknown }
        let rs = try pos(inputs, "rs", "Rs")
        let rl = try pos(inputs, "rl", "RL")
        let f = try pos(inputs, "f", "f")
        let topology = try LabKit.choice(inputs, "topology", ["lowpass", "highpass"], fallback: "lowpass", name: "Shape")
        guard abs(rs - rl) / max(rs, rl) > 0.01 else {
            throw CalcError.outOfRange("The two resistances already match within 1%. An L-section is not required.")
        }
        let rHi = max(rs, rl)
        let rLo = min(rs, rl)
        let qFactor = sqrt(rHi / rLo - 1)
        let xs = qFactor * rLo
        let xp = rHi / qFactor
        let omega = 2 * .pi * f
        let l = (topology == "lowpass" ? xs : xp) / omega
        let c = 1 / (omega * (topology == "lowpass" ? xp : xs))
        let seriesOnSource = rs < rl
        return pack(
            .lMatch, headline: "Q = \(String(format: "%.3f", qFactor))",
            elements: [
                res("rs", "Rs", eng(rs) + " Ω", 12, 36, 28, 36),
                topology == "lowpass"
                    ? ind("xs", "L", eng(l) + " H", seriesOnSource ? 36 : 58, 36, seriesOnSource ? 54 : 76, 36)
                    : cap("xs", "C", eng(c) + " F", seriesOnSource ? 36 : 58, 36, seriesOnSource ? 54 : 76, 36),
                topology == "lowpass"
                    ? cap("xp", "C", eng(c) + " F", seriesOnSource ? 70 : 40, 36, seriesOnSource ? 70 : 40, 64)
                    : ind("xp", "L", eng(l) + " H", seriesOnSource ? 70 : 40, 36, seriesOnSource ? 70 : 40, 64),
                res("rl", "RL", eng(rl) + " Ω", 78, 36, 92, 36),
                gnd("g", seriesOnSource ? 70 : 40, 64),
            ],
            nodes: [
                node("s", "Rs", rs, "Ω", 12, 36),
                node("l", "RL", rl, "Ω", 92, 36),
                node("mid", "Q node", qFactor, "", 54, 36),
            ],
            branches: [branch("i", "Match", 1, "A", 16, 36, 84, 36)],
            quantities: [
                q("q", "Q", qFactor, "", true),
                q("xs", "Series |X|", xs, "Ω"),
                q("xp", "Shunt |X|", xp, "Ω"),
                q("l", "L", l, "H"),
                q("c", "C", c, "F"),
                q("f", "f", f, "Hz"),
                q("lowpass", "Low-pass", topology == "lowpass" ? 1 : 0, ""),
            ],
            steps: [
                "Q = √(Rhi/Rlo − 1) = \(String(format: "%.4f", qFactor))",
                "Series |X| = Q·Rlo,  shunt |X| = Rhi/Q",
                topology == "lowpass" ? "Low-pass: series L, shunt C." : "High-pass: series C, shunt L.",
            ],
            notes: [
                "Lossless L-section between two real resistances.",
                "The series arm sits with the smaller resistance. The shunt arm sits across the larger one.",
                "One frequency. A different f needs different L and C.",
            ]
        )
    }

    static func quarterWave(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let f = try pos(inputs, "f", "f")
        let vf = try pos(inputs, "vf", "Velocity factor")
        guard vf <= 1 else { throw CalcError.outOfRange("Velocity factor is from just above 0 to 1.") }
        let zIn = try pos(inputs, "zIn", "Zin")
        let z0: Double
        let zLoad: Double
        if unknown == "z0" {
            zLoad = try pos(inputs, "zLoad", "Zload")
            z0 = sqrt(zIn * zLoad)
        } else if unknown == "zload" {
            z0 = try pos(inputs, "z0", "Z0")
            zLoad = z0 * z0 / zIn
        } else {
            throw badUnknown
        }
        let length = vf * LabKit.cLight / (4 * f)
        return pack(
            .quarterWave, headline: "Z0 = \(eng(z0)) Ω",
            elements: [
                res("zin", "Zin", eng(zIn) + " Ω", 10, 36, 28, 36),
                part("line", .line, "λ/4", eng(z0) + " Ω", 32, 36, 72, 36),
                res("zl", "ZL", eng(zLoad) + " Ω", 76, 36, 92, 36),
            ],
            nodes: [
                node("in", "Zin", zIn, "Ω", 10, 36),
                node("load", "Zload", zLoad, "Ω", 92, 36),
            ],
            branches: [branch("i", "Forward", 1, "A", 36, 36, 68, 36)],
            quantities: [
                q("z0", "Z0", z0, "Ω", unknown == "z0"),
                q("zload", "Zload", zLoad, "Ω", unknown == "zload"),
                q("lengthM", "Length", length, "m"),
                q("lengthMm", "Length", length * 1000, "mm"),
                q("f", "f", f, "Hz"),
                q("vf", "vf", vf, ""),
            ],
            steps: [
                "Z0 = √(Zin · Zload)",
                "Length = vf · c / (4f) = \(eng(length)) m",
            ],
            notes: [
                "Both ends are real resistances. A reactive load is a different problem.",
                "The line is ideal and exactly 90° long at this frequency.",
                "Velocity factor scales the physical length. 1 is free space.",
            ]
        )
    }

    static func stub(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        guard unknown == "length" else { throw badUnknown }
        let xIn = try LabKit.finite(inputs, "x", "Reactance")
        let z0 = try pos(inputs, "z0", "Z0")
        let f = try pos(inputs, "f", "f")
        let vf = try pos(inputs, "vf", "Velocity factor")
        guard vf <= 1 else { throw CalcError.outOfRange("Velocity factor is from just above 0 to 1.") }
        let kind = try LabKit.choice(inputs, "kind", ["shorted", "open"], fallback: "shorted", name: "Stub")
        let goal = try LabKit.choice(inputs, "goal", ["present", "cancel"], fallback: "present", name: "Goal")
        let xStub = goal == "cancel" ? -xIn : xIn
        let fraction = try LabKit.stubFraction(reactance: xStub, z0: z0, shorted: kind == "shorted")
        let lambda = vf * LabKit.cLight / f
        let length = fraction * lambda
        let degrees = fraction * 360
        return pack(
            .stubCancel, headline: "l = \(eng(length)) m",
            elements: [
                part("line", .line, "Z0", eng(z0) + " Ω", 16, 28, 78, 28),
                wire("tee", 52, 28, 52, 46),
                part("stub", .line, kind == "shorted" ? "Short" : "Open", "\(String(format: "%.2f", degrees))°", 52, 46, 52, 68),
                kind == "shorted" ? wire("end", 44, 68, 60, 68) : wire("end", 48, 68, 56, 68),
            ],
            nodes: [
                node("tee", "Stub X", xStub, "Ω", 52, 28),
                node("end", kind == "shorted" ? "Short" : "Open", 0, "Ω", 52, 68),
            ],
            branches: [branch("i", "On the stub", 1, "A", 52, 32, 52, 60)],
            quantities: [
                q("lengthM", "Length", length, "m", true),
                q("fraction", "l/λ", fraction, ""),
                q("degrees", "Electrical", degrees, "°"),
                q("xStub", "Stub X", xStub, "Ω"),
                q("lambda", "λ", lambda, "m"),
                q("f", "f", f, "Hz"),
                q("z0", "Z0", z0, "Ω"),
                q("vf", "vf", vf, ""),
                q("shorted", "Shorted", kind == "shorted" ? 1 : 0, ""),
            ],
            steps: [
                kind == "shorted" ? "Shorted: jX = j Z0 tan(βl)" : "Open: jX = −j Z0 cot(βl)",
                "Shortest positive length is \(String(format: "%.4f", fraction)) λ",
                "Physical length = (l/λ) · vf · c / f",
            ],
            notes: [
                "Ideal lossless line. The length is the shortest positive stub.",
                "Cancel mode asks the stub for the opposite reactance.",
                "This does not place the stub along a mismatched line. It only builds the X.",
            ]
        )
    }

    private static func timerBox(vcc: Double, r1: Double, r2: Double, c: Double) -> [LabElement] {
        [
            part("u", .timer555, "555", "", 70, 42, 70, 42),
            src("vcc", "Vcc", eng(vcc) + " V", 48, 74, 48, 14),
            wire("rail", 48, 14, 78, 14),
            res("r1", "R1", eng(r1) + " Ω", 62, 14, 62, 32),
            res("r2", "R2", eng(r2) + " Ω", 62, 32, 62, 50),
            cap("c", "C", eng(c) + " F", 48, 50, 48, 74),
            wire("th", 62, 50, 48, 50),
            gnd("g", 48, 74),
        ]
    }

    private static func phasorTip(x: Double, y: Double) -> LabPoint {
        let mag = hypot(x, y)
        if mag < 1e-15 { return LabPoint(x: 52, y: 58) }
        let scale = 24 / mag
        return LabPoint(x: 52 + x * scale, y: 58 - y * scale)
    }
}
