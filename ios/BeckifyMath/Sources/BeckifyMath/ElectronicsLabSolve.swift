import Foundation

enum LabSolve {
    static func run(
        _ circuit: ElectronicsCircuit,
        unknown: String,
        inputs: [String: String]
    ) throws -> LabSolution {
        let known = Set(LabCatalog.spec(circuit).unknowns.map(\.id))
        guard known.contains(unknown) else {
            throw CalcError.outOfRange("That unknown is not on this circuit.")
        }
        switch circuit {
        case .seriesResistors: return try seriesResistors(unknown, inputs)
        case .parallelResistors: return try parallelResistors(unknown, inputs)
        case .voltageDivider: return try voltageDivider(unknown, inputs)
        case .kirchhoffLoop: return try kirchhoff(unknown, inputs)
        case .theveninNorton: return try thevenin(unknown, inputs)
        case .rcStep: return try rcStep(unknown, inputs)
        case .rlStep: return try rlStep(unknown, inputs)
        case .firstOrderFilter: return try filter(unknown, inputs)
        case .seriesRLC: return try rlc(unknown, inputs)
        case .halfWave: return try rectifier(unknown, inputs, bridge: false)
        case .fullBridge: return try rectifier(unknown, inputs, bridge: true)
        case .shuntClipper: return try clipper(unknown, inputs)
        case .clamper: return try clamper(unknown, inputs)
        case .ledSeries: return try led(unknown, inputs)
        case .bjtBias: return try bjtBias(unknown, inputs)
        case .ceAmp: return try ceAmp(unknown, inputs)
        case .bjtSwitch: return try bjtSwitch(unknown, inputs)
        case .csAmp: return try csAmp(unknown, inputs)
        case .mosSwitch: return try mosSwitch(unknown, inputs)
        case .cmosInverter: return try cmos(unknown, inputs)
        case .invertingAmp: return try inverting(unknown, inputs)
        case .nonInvertingAmp: return try nonInverting(unknown, inputs)
        case .summingAmp: return try summing(unknown, inputs)
        case .diffAmp: return try difference(unknown, inputs)
        case .integrator: return try integrator(unknown, inputs)
        case .differentiator: return try differentiator(unknown, inputs)
        case .comparator: return try comparator(unknown, inputs)
        case .astable555: return try astable(unknown, inputs)
        case .monostable555: return try monostable(unknown, inputs)
        case .ledFlasher: return try flasher(unknown, inputs)
        case .sevenSegment: return try sevenSeg(unknown, inputs)
        case .classOverview: return try classOverview(unknown, inputs)
        case .discretePower: return try discretePower(unknown, inputs)
        case .opAmpPower: return try opAmpPower(unknown, inputs)
        case .linearDrop: return try linearDrop(unknown, inputs)
        case .idealBuck: return try buck(unknown, inputs)
        case .complexConvert: return try complexConvert(unknown, inputs)
        case .impedanceCombo: return try impedance(unknown, inputs)
        case .lMatch: return try lMatch(unknown, inputs)
        case .quarterWave: return try quarterWave(unknown, inputs)
        case .stubCancel: return try stub(unknown, inputs)
        }
    }

    // MARK: Passive

    private static func seriesResistors(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let r1: Double
        let r2: Double
        let vs: Double
        let i: Double
        switch unknown {
        case "current":
            vs = try pos(inputs, "vs", "Vs")
            r1 = try pos(inputs, "r1", "R1")
            r2 = try pos(inputs, "r2", "R2")
            i = vs / (r1 + r2)
        case "vs":
            i = try pos(inputs, "i", "I")
            r1 = try pos(inputs, "r1", "R1")
            r2 = try pos(inputs, "r2", "R2")
            vs = i * (r1 + r2)
        case "r1":
            vs = try pos(inputs, "vs", "Vs")
            i = try pos(inputs, "i", "I")
            r2 = try pos(inputs, "r2", "R2")
            r1 = vs / i - r2
            guard r1 > 0 else { throw CalcError.outOfRange("R1 would not be positive. I is too large for Vs and R2.") }
        case "r2":
            vs = try pos(inputs, "vs", "Vs")
            i = try pos(inputs, "i", "I")
            r1 = try pos(inputs, "r1", "R1")
            r2 = vs / i - r1
            guard r2 > 0 else { throw CalcError.outOfRange("R2 would not be positive. I is too large for Vs and R1.") }
        default: throw badUnknown
        }
        let v1 = i * r1
        let v2 = i * r2
        return pack(
            .seriesResistors,
            headline: "I = \(eng(i)) A",
            elements: [
                src("vs", "Vs", eng(vs) + " V", 16, 68, 16, 18),
                wire("w1", 16, 18, 34, 18),
                res("r1", "R1", eng(r1) + " Ω", 34, 18, 62, 18),
                res("r2", "R2", eng(r2) + " Ω", 62, 18, 86, 18),
                wire("w2", 86, 18, 86, 68),
                gnd("g", 86, 68),
                wire("w3", 16, 68, 86, 68),
            ],
            nodes: [
                node("src", "Vs", vs, "V", 16, 18),
                node("mid", "V1", v2, "V", 62, 18),
                node("gnd", "GND", 0, "V", 86, 68),
            ],
            branches: [
                branch("loop", "I", i, "A", 20, 18, 80, 18),
            ],
            quantities: [
                q("vs", "Vs", vs, "V", unknown == "vs"),
                q("r1", "R1", r1, "Ω", unknown == "r1"),
                q("r2", "R2", r2, "Ω", unknown == "r2"),
                q("current", "I", i, "A", unknown == "current"),
                q("v1", "Drop R1", v1, "V"),
                q("v2", "Drop R2", v2, "V"),
            ],
            steps: [
                "Req = R1 + R2 = \(eng(r1 + r2)) Ω",
                "I = Vs / Req = \(eng(i)) A",
                "V1 = I·R1 = \(eng(v1)) V,  V2 = I·R2 = \(eng(v2)) V",
            ],
            notes: [
                "One series loop. The same current passes through both resistors.",
                "KVL: Vs = V1 + V2. The mid node sits at V2 above ground.",
                "Ideal resistors. No source resistance and no meter loading.",
            ]
        )
    }

    private static func parallelResistors(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let vs: Double
        let r1: Double
        let r2: Double
        switch unknown {
        case "sourceCurrent":
            vs = try pos(inputs, "vs", "Vs")
            r1 = try pos(inputs, "r1", "R1")
            r2 = try pos(inputs, "r2", "R2")
        case "vs":
            let it = try pos(inputs, "it", "It")
            r1 = try pos(inputs, "r1", "R1")
            r2 = try pos(inputs, "r2", "R2")
            let req = 1 / (1 / r1 + 1 / r2)
            vs = it * req
        case "r1":
            vs = try pos(inputs, "vs", "Vs")
            let i1 = try pos(inputs, "i1", "I1")
            r2 = try pos(inputs, "r2", "R2")
            r1 = vs / i1
        case "r2":
            vs = try pos(inputs, "vs", "Vs")
            r1 = try pos(inputs, "r1", "R1")
            let i2 = try pos(inputs, "i2", "I2")
            r2 = vs / i2
        default: throw badUnknown
        }
        let i1 = vs / r1
        let i2 = vs / r2
        let it = i1 + i2
        let req = vs / it
        return pack(
            .parallelResistors,
            headline: "It = \(eng(it)) A",
            elements: [
                src("vs", "Vs", eng(vs) + " V", 18, 68, 18, 16),
                wire("top", 18, 16, 78, 16),
                res("r1", "R1", eng(r1) + " Ω", 40, 16, 40, 68),
                res("r2", "R2", eng(r2) + " Ω", 66, 16, 66, 68),
                wire("bot", 18, 68, 78, 68),
                gnd("g", 78, 68),
            ],
            nodes: [
                node("top", "Vs", vs, "V", 18, 16),
                node("gnd", "GND", 0, "V", 78, 68),
            ],
            branches: [
                branch("i1", "I1", i1, "A", 40, 20, 40, 60),
                branch("i2", "I2", i2, "A", 66, 20, 66, 60),
                branch("it", "It", it, "A", 18, 60, 18, 24),
            ],
            quantities: [
                q("vs", "Vs", vs, "V", unknown == "vs"),
                q("r1", "R1", r1, "Ω", unknown == "r1"),
                q("r2", "R2", r2, "Ω", unknown == "r2"),
                q("sourceCurrent", "It", it, "A", unknown == "sourceCurrent"),
                q("i1", "I1", i1, "A"),
                q("i2", "I2", i2, "A"),
                q("req", "Req", req, "Ω"),
            ],
            steps: [
                "I1 = Vs / R1 = \(eng(i1)) A",
                "I2 = Vs / R2 = \(eng(i2)) A",
                "It = I1 + I2 = \(eng(it)) A,  Req = \(eng(req)) Ω",
            ],
            notes: [
                "Both resistors see the full source voltage.",
                "Branch currents add. Req is the parallel combination.",
                "Ideal sources and resistors. No wiring resistance.",
            ]
        )
    }

    private static func voltageDivider(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let solved: VoltageDividerResult
        switch unknown {
        case "vout":
            solved = try VoltageDivider.fromResistors(
                vin: try pos(inputs, "vin", "Vin"),
                r1: try pos(inputs, "r1", "R1"),
                r2: try pos(inputs, "r2", "R2")
            )
        case "r1":
            solved = try VoltageDivider.solveR1(
                vin: try pos(inputs, "vin", "Vin"),
                vout: try pos(inputs, "vout", "Vout"),
                r2: try pos(inputs, "r2", "R2")
            )
        case "r2":
            solved = try VoltageDivider.solveR2(
                vin: try pos(inputs, "vin", "Vin"),
                vout: try pos(inputs, "vout", "Vout"),
                r1: try pos(inputs, "r1", "R1")
            )
        case "vin":
            let vout = try pos(inputs, "vout", "Vout")
            let r1 = try pos(inputs, "r1", "R1")
            let r2 = try pos(inputs, "r2", "R2")
            let vin = vout * (r1 + r2) / r2
            solved = try VoltageDivider.fromResistors(vin: vin, r1: r1, r2: r2)
        default: throw badUnknown
        }
        return pack(
            .voltageDivider,
            headline: "Vout = \(eng(solved.vout)) V",
            elements: [
                src("vin", "Vin", eng(solved.vin) + " V", 18, 68, 18, 16),
                wire("w1", 18, 16, 40, 16),
                res("r1", "R1", eng(solved.r1) + " Ω", 40, 16, 40, 40),
                res("r2", "R2", eng(solved.r2) + " Ω", 40, 40, 40, 68),
                wire("wout", 40, 40, 78, 40),
                wire("bot", 18, 68, 40, 68),
                gnd("g", 40, 68),
            ],
            nodes: [
                node("in", "Vin", solved.vin, "V", 18, 16),
                node("out", "Vout", solved.vout, "V", 78, 40),
                node("gnd", "GND", 0, "V", 40, 68),
            ],
            branches: [
                branch("series", "I", solved.current, "A", 40, 22, 40, 60),
            ],
            quantities: [
                q("vin", "Vin", solved.vin, "V", unknown == "vin"),
                q("vout", "Vout", solved.vout, "V", unknown == "vout"),
                q("r1", "R1", solved.r1, "Ω", unknown == "r1"),
                q("r2", "R2", solved.r2, "Ω", unknown == "r2"),
                q("current", "I", solved.current, "A"),
            ],
            steps: [
                solved.formula,
                "I = Vin / (R1 + R2) = \(eng(solved.current)) A",
            ],
            notes: [
                "Unloaded divider. A load on Vout changes both the voltage and the current.",
                "R1 is from Vin to the tap. R2 is from the tap to ground.",
                "Ideal DC. Source resistance is not included.",
            ]
        )
    }

    private static func kirchhoff(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        var r1 = 0.0, r2 = 0.0, r3 = 0.0, vs = 0.0, i = 0.0
        switch unknown {
        case "current":
            vs = try pos(inputs, "vs", "Vs"); r1 = try pos(inputs, "r1", "R1")
            r2 = try pos(inputs, "r2", "R2"); r3 = try pos(inputs, "r3", "R3")
            i = vs / (r1 + r2 + r3)
        case "vs":
            i = try pos(inputs, "i", "I"); r1 = try pos(inputs, "r1", "R1")
            r2 = try pos(inputs, "r2", "R2"); r3 = try pos(inputs, "r3", "R3")
            vs = i * (r1 + r2 + r3)
        case "r1", "r2", "r3":
            vs = try pos(inputs, "vs", "Vs"); i = try pos(inputs, "i", "I")
            if unknown != "r1" { r1 = try pos(inputs, "r1", "R1") }
            if unknown != "r2" { r2 = try pos(inputs, "r2", "R2") }
            if unknown != "r3" { r3 = try pos(inputs, "r3", "R3") }
            let known = (unknown == "r1" ? 0 : r1) + (unknown == "r2" ? 0 : r2) + (unknown == "r3" ? 0 : r3)
            let missing = vs / i - known
            guard missing > 0 else { throw CalcError.outOfRange("The missing resistor would not be positive.") }
            if unknown == "r1" { r1 = missing }
            if unknown == "r2" { r2 = missing }
            if unknown == "r3" { r3 = missing }
        default: throw badUnknown
        }
        let d1 = i * r1, d2 = i * r2, d3 = i * r3
        return pack(
            .kirchhoffLoop,
            headline: "ΣV = \(eng(d1 + d2 + d3)) V",
            elements: [
                src("vs", "Vs", eng(vs) + " V", 14, 68, 14, 16),
                wire("a", 14, 16, 30, 16),
                res("r1", "R1", eng(r1) + " Ω", 30, 16, 50, 16),
                res("r2", "R2", eng(r2) + " Ω", 50, 16, 70, 16),
                res("r3", "R3", eng(r3) + " Ω", 70, 16, 88, 16),
                wire("b", 88, 16, 88, 68),
                wire("c", 14, 68, 88, 68),
                gnd("g", 88, 68),
            ],
            nodes: [
                node("src", "Vs", vs, "V", 14, 16),
                node("n1", "After R1", vs - d1, "V", 50, 16),
                node("n2", "After R2", d3, "V", 70, 16),
                node("gnd", "GND", 0, "V", 88, 68),
            ],
            branches: [branch("loop", "I", i, "A", 18, 16, 84, 16)],
            quantities: [
                q("vs", "Vs", vs, "V", unknown == "vs"),
                q("current", "I", i, "A", unknown == "current"),
                q("r1", "R1", r1, "Ω", unknown == "r1"),
                q("r2", "R2", r2, "Ω", unknown == "r2"),
                q("r3", "R3", r3, "Ω", unknown == "r3"),
                q("d1", "V on R1", d1, "V"),
                q("d2", "V on R2", d2, "V"),
                q("d3", "V on R3", d3, "V"),
            ],
            steps: [
                "KVL: Vs = I·(R1 + R2 + R3)",
                "Drops \(eng(d1)) + \(eng(d2)) + \(eng(d3)) = \(eng(vs)) V",
            ],
            notes: [
                "Walk the loop: leave the source and the resistor drops bring you back to zero.",
                "Node voltages are measured to the bottom rail.",
                "One independent current. A second source would need another equation.",
            ]
        )
    }

    private static func thevenin(_ unknown: String, _ inputs: [String: String]) throws -> LabSolution {
        let vs = try pos(inputs, "vs", "Vs")
        let r1 = try pos(inputs, "r1", "R1")
        var r2 = 0.0
        var rl = 0.0
        switch unknown {
        case "load":
            r2 = try pos(inputs, "r2", "R2")
            rl = try pos(inputs, "rl", "RL")
        case "rl":
            r2 = try pos(inputs, "r2", "R2")
            let vl = try pos(inputs, "vl", "VL")
            let vth = vs * r2 / (r1 + r2)
            guard vl < vth else { throw CalcError.outOfRange("VL must sit below Vth. A passive load cannot raise it.") }
            let rth = 1 / (1 / r1 + 1 / r2)
            rl = rth * vl / (vth - vl)
        case "r2":
            let vthTarget = try pos(inputs, "vth", "Vth")
            guard vthTarget < vs else { throw CalcError.outOfRange("Vth is a fraction of Vs for this divider.") }
            r2 = vthTarget * r1 / (vs - vthTarget)
            rl = r2
        default: throw badUnknown
        }
        let vth = vs * r2 / (r1 + r2)
        let rth = 1 / (1 / r1 + 1 / r2)
        let norton = vth / rth
        let vl = unknown == "r2" ? vth : vth * rl / (rth + rl)
        let il = unknown == "r2" ? 0 : vl / rl
        let shownRL = unknown == "r2" ? rth : rl
        return pack(
            .theveninNorton,
            headline: "Vth = \(eng(vth)) V",
            elements: [
                src("vs", "Vs", eng(vs) + " V", 16, 68, 16, 16),
                wire("a", 16, 16, 36, 16),
                res("r1", "R1", eng(r1) + " Ω", 36, 16, 58, 16),
                res("r2", "R2", eng(r2) + " Ω", 58, 16, 58, 68),
                wire("b", 58, 40, 78, 40),
                res("rl", unknown == "r2" ? "Rth" : "RL", eng(shownRL) + " Ω", 78, 40, 78, 68),
                wire("c", 16, 68, 78, 68),
                gnd("g", 58, 68),
            ],
            nodes: [
                node("src", "Vs", vs, "V", 16, 16),
                node("th", "Vth node", vth, "V", 58, 16),
                node("load", unknown == "r2" ? "Open" : "VL", vl, "V", 78, 40),
                node("gnd", "GND", 0, "V", 58, 68),
            ],
            branches: [
                branch("i1", "Through R1", (vs - (unknown == "r2" ? vth : vl)) / r1, "A", 40, 16, 54, 16),
                branch("il", "Load", il, "A", 78, 44, 78, 64),
            ],
            quantities: [
                q("vth", "Vth", vth, "V", unknown == "r2"),
                q("rth", "Rth", rth, "Ω"),
                q("norton", "In", norton, "A"),
                q("rl", "RL", unknown == "r2" ? 0 : rl, "Ω", unknown == "rl"),
                q("vl", "VL", vl, "V"),
                q("il", "IL", il, "A"),
            ],
            steps: [
                "Vth = Vs · R2 / (R1 + R2) = \(eng(vth)) V",
                "Rth = R1 || R2 = \(eng(rth)) Ω",
                "In = Vth / Rth = \(eng(norton)) A",
            ],
            notes: [
                "Thevenin is the open-circuit voltage with R1 || R2 behind it.",
                "Norton is that same Rth fed by In = Vth / Rth.",
                "The R2-only solve leaves the port open. Load current is then zero.",
                "Linear resistors only. A diode in this network needs a different model.",
            ]
        )
    }
}
