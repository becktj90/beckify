import Foundation

extension LabSolve {
    static func bjtBias(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let vcc = try pos(inputs, "vcc", "Vcc")
        let r1 = try pos(inputs, "r1", "R1")
        let r2 = try pos(inputs, "r2", "R2")
        let beta = try pos(inputs, "beta", "β")
        var rc = 0.0
        var re = 0.0
        switch unknown {
        case "point":
            rc = try pos(inputs, "rc", "Rc")
            re = try pos(inputs, "re", "Re")
        case "re":
            rc = try pos(inputs, "rc", "Rc")
            let icTarget = try pos(inputs, "ic", "Ic")
            let vbb = vcc * r2 / (r1 + r2)
            let rb = 1 / (1 / r1 + 1 / r2)
            guard vbb > LabKit.vbe else { throw CalcError.outOfRange("The base divider sits at or below 0.7 V, so this β model is cut off.") }
            let ie = icTarget * (beta + 1) / beta
            re = (vbb - LabKit.vbe) / ie - rb / (beta + 1)
            guard re > 0 else { throw CalcError.outOfRange("That Ic is too high for the base divider. Re would not be positive.") }
        case "rc":
            re = try pos(inputs, "re", "Re")
            let vcTarget = try LabKit.finite(inputs, "vc", "Vc")
            let preview = LabKit.bjtBias(vcc: vcc, r1: r1, r2: r2, rc: 1, re: re, beta: beta)
            guard !preview.cutoff, preview.ic > 0 else { throw CalcError.outOfRange("The transistor is cut off, so Rc does not set Vc.") }
            guard vcTarget < vcc else { throw CalcError.outOfRange("Vc has to be below Vcc.") }
            rc = (vcc - vcTarget) / preview.ic
            guard rc > 0 else { throw CalcError.outOfRange("Rc would not be positive.") }
        default: throw badUnknown
        }
        let bias = LabKit.bjtBias(vcc: vcc, r1: r1, r2: r2, rc: rc, re: re, beta: beta)
        var warning: String?
        if bias.cutoff { warning = "Vbb is below 0.7 V. This model says the transistor is cut off." }
        if bias.saturated { warning = "Active-region β put Vce under 0.2 V. Nodes use a saturation sketch with Vce fixed at 0.2 V." }
        return pack(
            .bjtBias, headline: "Ic = \(eng(bias.ic)) A",
            elements: LabKit.bjtElements(bias, vcc: vcc, r1: r1, r2: r2, rc: rc, re: re),
            nodes: LabKit.bjtNodes(bias, vcc: vcc),
            branches: LabKit.bjtBranches(bias),
            quantities: [
                q("ic", "Ic", bias.ic, "A", unknown == "re"),
                q("ib", "Ib", bias.ib, "A"),
                q("ie", "Ie", bias.ie, "A"),
                q("vb", "Vb", bias.vb, "V"),
                q("vc", "Vc", bias.vc, "V", unknown == "rc"),
                q("ve", "Ve", bias.ve, "V"),
                q("vce", "Vce", bias.vce, "V"),
                q("re", "Re", re, "Ω", unknown == "re"),
                q("rc", "Rc", rc, "Ω", unknown == "rc"),
                q("r1", "R1", r1, "Ω"),
                q("r2", "R2", r2, "Ω"),
                q("vcc", "Vcc", vcc, "V"),
            ],
            steps: [
                "Vbb = Vcc·R2/(R1+R2) = \(eng(bias.vbb)) V",
                "Ie = (Vbb − 0.7) / (Re + Rb/(β+1))",
                "Vc = Vcc − Ic·Rc,  Vce = Vc − Ve",
            ],
            notes: [
                "Vbe is fixed at 0.7 V. β does not change with current.",
                "Base loading is in the Thevenin term Rb/(β+1).",
                "Not a Gummel–Poon model. Early effect is ignored.",
            ],
            warning: warning
        )
    }

    static func ceAmp(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let vcc = try pos(inputs, "vcc", "Vcc")
        let r1 = try pos(inputs, "r1", "R1")
        let r2 = try pos(inputs, "r2", "R2")
        let re = try pos(inputs, "re", "Re")
        let beta = try pos(inputs, "beta", "β")
        let rl = try pos(inputs, "rl", "RL")
        let bypass = try LabKit.choice(inputs, "bypass", ["bypassed", "open"], fallback: "bypassed", name: "Emitter")
        let seed = LabKit.bjtBias(vcc: vcc, r1: r1, r2: r2, rc: 1, re: re, beta: beta)
        guard !seed.cutoff, seed.ic > 0 else { throw CalcError.outOfRange("Cut off. There is no small-signal gm.") }
        let gm = seed.ic / LabKit.vt
        let denom = bypass == "bypassed" ? 1.0 : (1 + gm * re)
        var rc = 0.0
        if unknown == "rc" {
            let av = try pos(inputs, "av", "|Av|")
            let k = av * denom / gm
            guard rl > k else { throw CalcError.outOfRange("RL is too small to reach that gain with Rc || RL.") }
            rc = k * rl / (rl - k)
        } else if unknown == "gain" {
            rc = try pos(inputs, "rc", "Rc")
        } else {
            throw badUnknown
        }
        let bias = LabKit.bjtBias(vcc: vcc, r1: r1, r2: r2, rc: rc, re: re, beta: beta)
        let gmUsed = bias.ic / LabKit.vt
        let denomUsed = bypass == "bypassed" ? 1.0 : (1 + gmUsed * re)
        let rac = 1 / (1 / rc + 1 / rl)
        let av = bias.saturated || bias.cutoff ? 0 : -gmUsed * rac / denomUsed
        let rpi = beta / gmUsed
        let rinBase = bypass == "bypassed" ? rpi : (rpi + (beta + 1) * re)
        let rin = 1 / (1 / r1 + 1 / r2 + 1 / rinBase)
        var warning: String?
        if bias.saturated { warning = "The DC point is saturated, so the gain number is not meaningful. It is reported as 0." }
        return pack(
            .ceAmp, headline: "Av = \(String(format: "%.2f", av))",
            elements: LabKit.bjtElements(bias, vcc: vcc, r1: r1, r2: r2, rc: rc, re: re) + [
                cap("cc", "Cc", "AC", 70, 32, 86, 32),
                res("rl", "RL", eng(rl) + " Ω", 86, 32, 86, 70),
            ],
            nodes: LabKit.bjtNodes(bias, vcc: vcc),
            branches: LabKit.bjtBranches(bias),
            quantities: [
                q("av", "Av", av, "", unknown == "gain" || unknown == "rc"),
                q("gm", "gm", gmUsed, "S"),
                q("rin", "Rin", rin, "Ω"),
                q("rout", "Rout", rc, "Ω"),
                q("rc", "Rc", rc, "Ω", unknown == "rc"),
                q("ic", "Ic", bias.ic, "A"),
                q("vce", "Vce", bias.vce, "V"),
                q("vc", "Vc", bias.vc, "V"),
                q("vb", "Vb", bias.vb, "V"),
                q("vcc", "Vcc", vcc, "V"),
                q("r1", "R1", r1, "Ω"),
                q("r2", "R2", r2, "Ω"),
                q("re", "Re", re, "Ω"),
                q("rl", "RL", rl, "Ω"),
            ],
            steps: [
                "gm = Ic / 26 mV = \(eng(gmUsed)) S",
                bypass == "bypassed" ? "Av ≈ −gm · (Rc || RL)" : "Av ≈ −gm · (Rc || RL) / (1 + gm·Re)",
                "Rin ≈ R1 || R2 || rπ (plus (β+1)Re if Re is unbypassed)",
            ],
            notes: [
                "Midband estimate. Coupling and bypass capacitors are shorts for the signal.",
                "Vt is 26 mV, a room-temperature value.",
                "Rout is about Rc. The load is AC-coupled and does not move the DC point.",
            ],
            warning: warning
        )
    }

    static func bjtSwitch(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let vcc = try pos(inputs, "vcc", "Vcc")
        let rc = try pos(inputs, "rc", "Rc")
        let beta = try pos(inputs, "beta", "β")
        let vin = try pos(inputs, "vin", "Vin")
        guard vin > LabKit.vbe else { throw CalcError.outOfRange("Vin has to be above 0.7 V to forward-bias the base.") }
        let icSat = (vcc - LabKit.vceSat) / rc
        let ibNeed = icSat / beta
        let rb: Double
        if unknown == "rb" {
            rb = (vin - LabKit.vbe) / ibNeed
        } else if unknown == "state" {
            rb = try pos(inputs, "rb", "Rb")
        } else {
            throw badUnknown
        }
        let ib = (vin - LabKit.vbe) / rb
        let saturated = ib >= ibNeed
        let ic = saturated ? icSat : min(beta * ib, icSat)
        let vc = saturated ? LabKit.vceSat : (vcc - ic * rc)
        let forced = ic / ib
        return pack(
            .bjtSwitch, headline: saturated ? "Saturated" : "Not saturated",
            elements: [
                src("vin", "Vin", eng(vin) + " V", 16, 62, 16, 36),
                res("rb", "Rb", eng(rb) + " Ω", 16, 36, 40, 36),
                part("q", .npn, "Q", "", 50, 40, 50, 40),
                wire("crail", 62, 14, 62, 28),
                res("rc", "Rc", eng(rc) + " Ω", 62, 14, 78, 14),
                src("vcc", "Vcc", eng(vcc) + " V", 86, 62, 86, 14),
                wire("top", 78, 14, 86, 14),
                wire("base", 40, 36, 34, 40),
                wire("ecol", 62, 28, 60, 24),
                wire("emitter", 60, 56, 60, 62),
                wire("bot", 16, 62, 86, 62),
                gnd("g", 50, 62),
            ],
            nodes: [
                node("in", "Vin", vin, "V", 16, 36),
                node("b", "Vb", LabKit.vbe, "V", 40, 36),
                node("c", "Vc", vc, "V", 62, 28),
                node("e", "Ve", 0, "V", 60, 56),
                node("vcc", "Vcc", vcc, "V", 86, 14),
            ],
            branches: [
                branch("ib", "Ib", ib, "A", 22, 36, 38, 36),
                branch("ic", "Ic", ic, "A", 64, 14, 76, 14),
            ],
            quantities: [
                q("rb", "Rb", rb, "Ω", unknown == "rb"),
                q("rc", "Rc", rc, "Ω"),
                q("vin", "Vin", vin, "V"),
                q("ib", "Ib", ib, "A"),
                q("ic", "Ic", ic, "A"),
                q("vc", "Vc", vc, "V"),
                q("forced", "β forced", forced, ""),
                q("state", saturated ? "Saturated" : "Active", saturated ? 1 : 0, ""),
                q("vcc", "Vcc", vcc, "V"),
            ],
            steps: [
                "Ic(sat) = (Vcc − 0.2) / Rc = \(eng(icSat)) A",
                "Ib = (Vin − 0.7) / Rb = \(eng(ib)) A",
                saturated ? "Ib is enough. Vc sits near 0.2 V." : "Ib is short of Ic(sat)/β. The device stays active.",
            ],
            notes: [
                "Saturation test: forced β = Ic/Ib is below the device β.",
                "Vce(sat) is taken as 0.2 V. Vbe is 0.7 V.",
                "The emitter is at ground. This is a low-side switch, not a level shifter.",
            ]
        )
    }

    static func csAmp(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let vdd = try pos(inputs, "vdd", "Vdd")
        let vg = try LabKit.finite(inputs, "vg", "Vg")
        let rs = try LabKit.nonNeg(inputs, "rs", "Rs")
        let kn = try pos(inputs, "kn", "kn")
        let vt = try LabKit.finite(inputs, "vt", "Vt")
        let over = try mosOverdrive(vg: vg, rs: rs, kn: kn, vt: vt)
        var rd = 0.0
        if unknown == "rd" {
            let av = try pos(inputs, "av", "|Av|")
            guard let drive = over, drive > 0 else { throw CalcError.outOfRange("The MOSFET is off, so Rd does not set gain.") }
            let gm = kn * drive
            rd = av * (1 + gm * rs) / gm
        } else if unknown == "point" {
            rd = try pos(inputs, "rd", "Rd")
        } else {
            throw badUnknown
        }
        let id: Double
        let vgs: Double
        let vs: Double
        if let drive = over, drive > 0 {
            id = 0.5 * kn * drive * drive
            vgs = vt + drive
            vs = id * rs
        } else {
            id = 0
            vgs = vg
            vs = 0
        }
        let vd = vdd - id * rd
        let vds = vd - vs
        let vov = max(0, vgs - vt)
        var note: String?
        if id == 0 { note = "Vgs is not above Vt. Id = 0 in this square-law model." }
        else if vds < vov { note = "Vds is below Vov, so the device is not in saturation. The square law overstates Id." }
        let gm = id > 0 ? kn * vov : 0
        let av = (id > 0 && gm > 0) ? -gm * rd / (1 + gm * rs) : 0
        return pack(
            .csAmp, headline: "Id = \(eng(id)) A",
            elements: [
                src("vdd", "Vdd", eng(vdd) + " V", 78, 68, 78, 14),
                wire("rail", 40, 14, 78, 14),
                res("rd", "Rd", eng(rd) + " Ω", 62, 14, 62, 34),
                part("m", .nmos, "M", "", 50, 44, 50, 44),
                wire("d", 62, 34, 62, 26),
                res("rs", "Rs", eng(rs) + " Ω", 58, 62, 58, 68),
                src("vg", "Vg", eng(vg) + " V", 18, 68, 18, 44),
                wire("g", 18, 44, 32, 44),
                wire("bot", 18, 68, 78, 68),
                gnd("gnd", 50, 68),
            ],
            nodes: [
                node("g", "Vg", vg, "V", 18, 44),
                node("d", "Vd", vd, "V", 62, 34),
                node("s", "Vs", vs, "V", 58, 62),
                node("vdd", "Vdd", vdd, "V", 78, 14),
                node("gnd", "GND", 0, "V", 50, 68),
            ],
            branches: [
                branch("id", "Id", id, "A", 62, 18, 62, 32),
            ],
            quantities: [
                q("id", "Id", id, "A"),
                q("vgs", "Vgs", vgs, "V"),
                q("vd", "Vd", vd, "V"),
                q("vs", "Vs", vs, "V"),
                q("vds", "Vds", vds, "V"),
                q("gm", "gm", gm, "S"),
                q("av", "Av", av, "", true),
                q("rd", "Rd", rd, "Ω", unknown == "rd"),
                q("vdd", "Vdd", vdd, "V"),
                q("vg", "Vg", vg, "V"),
                q("rs", "Rs", rs, "Ω"),
            ],
            steps: [
                "Id = (kn/2)·(Vgs − Vt)²",
                "gm = kn·(Vgs − Vt)",
                "Av = −gm·Rd / (1 + gm·Rs)",
            ],
            notes: [
                "Square law, long-channel, no channel-length modulation.",
                "kn is µCox·W/L in A/V². Rs = 0 is an undegenerated CS stage.",
                "Gain assumes the MOSFET is saturated (Vds > Vov).",
            ],
            warning: note
        )
    }

    static func mosSwitch(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let vdd = try pos(inputs, "vdd", "Vdd")
        let rd = try pos(inputs, "rd", "Rd")
        let vgs = try LabKit.finite(inputs, "vgs", "Vgs")
        let vt = try LabKit.finite(inputs, "vt", "Vt")
        let on = vgs > vt
        let rdson: Double
        if unknown == "rdson" {
            guard on else { throw CalcError.outOfRange("Vgs is not above Vt, so the switch stays off and Rds(on) does not set Vds.") }
            let limit = try pos(inputs, "vdslimit", "Vds limit")
            guard limit < vdd else { throw CalcError.outOfRange("The Vds limit has to be below Vdd.") }
            rdson = rd * limit / (vdd - limit)
        } else if unknown == "state" {
            rdson = try LabKit.nonNeg(inputs, "rdson", "Rds(on)")
        } else {
            throw badUnknown
        }
        let id = on ? vdd / (rd + rdson) : 0
        let vds = on ? id * rdson : vdd
        return pack(
            .mosSwitch, headline: on ? "On, Vds = \(eng(vds)) V" : "Off",
            elements: [
                src("vdd", "Vdd", eng(vdd) + " V", 76, 68, 76, 16),
                wire("t", 40, 16, 76, 16),
                res("rd", "Rd", eng(rd) + " Ω", 58, 16, 58, 36),
                part("m", .nmos, "M", "", 48, 46, 48, 46),
                wire("d", 58, 36, 60, 28),
                wire("s", 56, 64, 56, 68),
                src("vg", "Vgs", eng(vgs) + " V", 16, 68, 16, 46),
                wire("g", 16, 46, 30, 46),
                wire("b", 16, 68, 76, 68),
                gnd("gnd", 48, 68),
            ],
            nodes: [
                node("g", "Vgs", vgs, "V", 16, 46),
                node("d", "Vds", vds, "V", 58, 36),
                node("s", "Vs", 0, "V", 56, 64),
                node("vdd", "Vdd", vdd, "V", 76, 16),
            ],
            branches: [branch("id", "Id", id, "A", 58, 20, 58, 34)],
            quantities: [
                q("id", "Id", id, "A"),
                q("vds", "Vds", vds, "V"),
                q("rdson", "Rds(on)", rdson, "Ω", unknown == "rdson"),
                q("rd", "Rd", rd, "Ω"),
                q("vgs", "Vgs", vgs, "V"),
                q("state", on ? "On" : "Off", on ? 1 : 0, ""),
                q("vdd", "Vdd", vdd, "V"),
            ],
            steps: [
                on ? "Id = Vdd / (Rd + Rds(on))" : "Vgs ≤ Vt, so Id = 0 and the drain sits at Vdd.",
                "Vds = Id · Rds(on)",
            ],
            notes: [
                "The on-state uses the Rds(on) you type. The square law is not used here.",
                "Off means Vgs is not above Vt. Leakage is taken as zero.",
                "A logic FET still needs a rated Vgs. This screen does not check the absolute maximum.",
            ]
        )
    }

    static func cmos(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let vdd = try pos(inputs, "vdd", "Vdd")
        let vtn = try LabKit.nonNeg(inputs, "vtn", "Vtn")
        let vtp = try LabKit.nonNeg(inputs, "vtp", "|Vtp|")
        let vm = (vdd - vtp + vtn) / 2
        let vin: Double
        let vout: Double
        if unknown == "vout" {
            vin = try LabKit.finite(inputs, "vin", "Vin")
            if vin < vm { vout = vdd } else if vin > vm { vout = 0 } else { vout = vm }
        } else if unknown == "threshold" {
            vin = vm
            vout = vm
        } else {
            throw badUnknown
        }
        return pack(
            .cmosInverter, headline: "Vm = \(eng(vm)) V",
            elements: [
                src("vdd", "Vdd", eng(vdd) + " V", 70, 70, 70, 12),
                part("p", .pmos, "P", "", 48, 28, 48, 28),
                part("n", .nmos, "N", "", 48, 52, 48, 52),
                wire("mid", 54, 40, 84, 40),
                wire("in", 16, 40, 38, 40),
                src("vin", "Vin", eng(vin) + " V", 16, 70, 16, 40),
                wire("bot", 16, 70, 70, 70),
                gnd("g", 48, 70),
            ],
            nodes: [
                node("in", "Vin", vin, "V", 16, 40),
                node("out", "Vout", vout, "V", 84, 40),
                node("vm", "Vm", vm, "V", 48, 40),
                node("vdd", "Vdd", vdd, "V", 70, 12),
                node("gnd", "GND", 0, "V", 48, 70),
            ],
            branches: [branch("i", "Istatic", 0, "A", 48, 32, 48, 48)],
            quantities: [
                q("vm", "Vm", vm, "V", unknown == "threshold"),
                q("vout", "Vout", vout, "V", unknown == "vout"),
                q("vin", "Vin", vin, "V"),
                q("nml", "NM sketch", max(0, vm - vtn), "V"),
                q("vdd", "Vdd", vdd, "V"),
            ],
            steps: [
                "Vm = (Vdd − |Vtp| + Vtn) / 2 = \(eng(vm)) V",
                "Ideal rails: Vin below Vm drives Vout to Vdd.",
            ],
            notes: [
                "Matched kn = kp. The threshold is the usual long-channel estimate.",
                "The logic level is an ideal step. A real transfer curve is not vertical.",
                "Static current is taken as zero. Shoot-through during the edge is not modeled.",
            ]
        )
    }

    private static func mosOverdrive(vg: Double, rs: Double, kn: Double, vt: Double) throws -> Double? {
        if rs == 0 {
            let x = vg - vt
            return x > 0 ? x : nil
        }
        let a = 0.5 * kn * rs
        let c = vt - vg
        let disc = 1 - 4 * a * c
        guard disc >= 0 else { return nil }
        let x = (-1 + sqrt(disc)) / (2 * a)
        return x > 0 ? x : nil
    }
}
