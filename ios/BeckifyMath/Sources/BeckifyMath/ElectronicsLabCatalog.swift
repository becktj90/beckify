import Foundation

enum LabCatalog {
    static var infos: [ElectronicsCircuitInfo] { specs.map(\.info) }

    static func info(_ circuit: ElectronicsCircuit) -> ElectronicsCircuitInfo {
        spec(circuit).info
    }

    static func fields(for circuit: ElectronicsCircuit, unknown: String) -> [LabField] {
        let item = spec(circuit)
        let ids = item.visible[unknown] ?? item.visible[item.defaultUnknown] ?? []
        return ids.compactMap { id in item.fields.first { $0.id == id } }
    }

    static func spec(_ circuit: ElectronicsCircuit) -> Spec {
        guard let found = specs.first(where: { $0.circuit == circuit }) else {
            preconditionFailure("Missing electronics lab spec for \(circuit.rawValue)")
        }
        return found
    }

    struct Spec {
        var circuit: ElectronicsCircuit
        var family: ElectronicsFamily
        var title: String
        var blurb: String
        var defaultUnknown: String
        var unknowns: [LabUnknown]
        var fields: [LabField]
        var visible: [String: [String]]
        var defaults: [String: String]

        var info: ElectronicsCircuitInfo {
            ElectronicsCircuitInfo(
                id: circuit,
                family: family,
                title: title,
                blurb: blurb,
                unknowns: unknowns,
                defaultUnknown: defaultUnknown,
                defaults: defaults
            )
        }
    }

    private static func n(_ id: String, _ title: String, _ unit: String, _ help: String = "") -> LabField {
        LabField(id: id, title: title, unit: unit, help: help)
    }

    private static func opt(_ id: String, _ title: String, _ unit: String, _ help: String) -> LabField {
        LabField(id: id, title: title, unit: unit, help: help, optional: true)
    }

    private static func ch(_ id: String, _ title: String, _ pairs: [(String, String)], _ help: String = "") -> LabField {
        LabField(id: id, title: title, unit: "", help: help, choices: pairs.map { LabChoice(id: $0.0, title: $0.1) })
    }

    private static func u(_ id: String, _ title: String) -> LabUnknown {
        LabUnknown(id: id, title: title)
    }

    static let specs: [Spec] = [
        Spec(
            circuit: .seriesResistors, family: .passive,
            title: "Series resistors",
            blurb: "One loop. Current is shared. Drops add to the source.",
            defaultUnknown: "current",
            unknowns: [u("current", "Current"), u("vs", "Source"), u("r1", "R1"), u("r2", "R2")],
            fields: [n("vs", "Vs", "V"), n("r1", "R1", "Ω"), n("r2", "R2", "Ω"), n("i", "I", "A")],
            visible: [
                "current": ["vs", "r1", "r2"],
                "vs": ["i", "r1", "r2"],
                "r1": ["vs", "i", "r2"],
                "r2": ["vs", "i", "r1"],
            ],
            defaults: ["vs": "12", "r1": "1000", "r2": "2000", "i": "0.004"]
        ),
        Spec(
            circuit: .parallelResistors, family: .passive,
            title: "Parallel resistors",
            blurb: "Same voltage on each branch. Currents add at the source.",
            defaultUnknown: "sourceCurrent",
            unknowns: [u("sourceCurrent", "Source current"), u("vs", "Source"), u("r1", "R1"), u("r2", "R2")],
            fields: [n("vs", "Vs", "V"), n("r1", "R1", "Ω"), n("r2", "R2", "Ω"), n("it", "It", "A"), n("i1", "I1", "A"), n("i2", "I2", "A")],
            visible: [
                "sourceCurrent": ["vs", "r1", "r2"],
                "vs": ["it", "r1", "r2"],
                "r1": ["vs", "i1", "r2"],
                "r2": ["vs", "i2", "r1"],
            ],
            defaults: ["vs": "12", "r1": "1000", "r2": "2000", "it": "0.018", "i1": "0.012", "i2": "0.006"]
        ),
        Spec(
            circuit: .voltageDivider, family: .passive,
            title: "Voltage divider",
            blurb: "Unloaded divider. R1 is the top resistor. R2 goes to ground.",
            defaultUnknown: "vout",
            unknowns: [u("vout", "Vout"), u("vin", "Vin"), u("r1", "R1"), u("r2", "R2")],
            fields: [n("vin", "Vin", "V"), n("vout", "Vout", "V"), n("r1", "R1 (top)", "Ω"), n("r2", "R2 (to GND)", "Ω")],
            visible: [
                "vout": ["vin", "r1", "r2"],
                "vin": ["vout", "r1", "r2"],
                "r1": ["vin", "vout", "r2"],
                "r2": ["vin", "vout", "r1"],
            ],
            defaults: ["vin": "12", "vout": "6", "r1": "10000", "r2": "10000"]
        ),
        Spec(
            circuit: .kirchhoffLoop, family: .passive,
            title: "Kirchhoff loop",
            blurb: "Three series resistors. KVL: the drops sum to the source.",
            defaultUnknown: "current",
            unknowns: [u("current", "Current"), u("vs", "Source"), u("r1", "R1"), u("r2", "R2"), u("r3", "R3")],
            fields: [n("vs", "Vs", "V"), n("r1", "R1", "Ω"), n("r2", "R2", "Ω"), n("r3", "R3", "Ω"), n("i", "I", "A")],
            visible: [
                "current": ["vs", "r1", "r2", "r3"],
                "vs": ["i", "r1", "r2", "r3"],
                "r1": ["vs", "i", "r2", "r3"],
                "r2": ["vs", "i", "r1", "r3"],
                "r3": ["vs", "i", "r1", "r2"],
            ],
            defaults: ["vs": "12", "r1": "100", "r2": "200", "r3": "300", "i": "0.02"]
        ),
        Spec(
            circuit: .theveninNorton, family: .passive,
            title: "Thevenin and Norton",
            blurb: "Divider seen from the load: Vth, Rth, and the Norton current.",
            defaultUnknown: "load",
            unknowns: [u("load", "Loaded output"), u("rl", "Load R"), u("r2", "R2 for Vth")],
            fields: [
                n("vs", "Vs", "V"), n("r1", "R1 (series)", "Ω"), n("r2", "R2 (shunt)", "Ω"),
                n("rl", "RL", "Ω"), n("vl", "Target VL", "V"), n("vth", "Target Vth", "V"),
            ],
            visible: [
                "load": ["vs", "r1", "r2", "rl"],
                "rl": ["vs", "r1", "r2", "vl"],
                "r2": ["vs", "r1", "vth"],
            ],
            defaults: ["vs": "12", "r1": "1000", "r2": "1000", "rl": "1000", "vl": "4", "vth": "6"]
        ),
        Spec(
            circuit: .rcStep, family: .transient,
            title: "RC step",
            blurb: "Capacitor voltage on a first-order step. τ = RC.",
            defaultUnknown: "voltage",
            unknowns: [u("voltage", "v(t)"), u("time", "Time"), u("r", "R"), u("c", "C")],
            fields: [
                n("r", "R", "Ω"), n("c", "C", "F"), n("v0", "v(0)", "V"), n("vinf", "v(∞)", "V"),
                n("t", "t", "s"), n("vt", "v(t) target", "V"),
            ],
            visible: [
                "voltage": ["r", "c", "v0", "vinf", "t"],
                "time": ["r", "c", "v0", "vinf", "vt"],
                "r": ["c", "v0", "vinf", "t", "vt"],
                "c": ["r", "v0", "vinf", "t", "vt"],
            ],
            defaults: ["r": "10000", "c": "0.000001", "v0": "0", "vinf": "5", "t": "0.01", "vt": "3.1606"]
        ),
        Spec(
            circuit: .rlStep, family: .transient,
            title: "RL step",
            blurb: "Inductor current on a step. τ = L/R.",
            defaultUnknown: "current",
            unknowns: [u("current", "i(t)"), u("time", "Time"), u("l", "L")],
            fields: [
                n("vs", "Vs", "V"), n("r", "R", "Ω"), n("l", "L", "H"),
                n("i0", "i(0)", "A"), n("t", "t", "s"), n("it", "i(t) target", "A"),
            ],
            visible: [
                "current": ["vs", "r", "l", "i0", "t"],
                "time": ["vs", "r", "l", "i0", "it"],
                "l": ["vs", "r", "i0", "t", "it"],
            ],
            defaults: ["vs": "10", "r": "100", "l": "0.1", "i0": "0", "t": "0.001", "it": "0.0632"]
        ),
        Spec(
            circuit: .firstOrderFilter, family: .transient,
            title: "First-order filter",
            blurb: "RC low-pass or high-pass. Cutoff, magnitude, and phase at one frequency.",
            defaultUnknown: "cutoff",
            unknowns: [u("cutoff", "Cutoff"), u("r", "R"), u("c", "C")],
            fields: [
                ch("kind", "Response", [("lowpass", "Low-pass"), ("highpass", "High-pass")]),
                n("r", "R", "Ω"), n("c", "C", "F"), n("f", "f", "Hz"), n("fc", "fc", "Hz"),
            ],
            visible: [
                "cutoff": ["kind", "r", "c", "f"],
                "r": ["kind", "c", "fc", "f"],
                "c": ["kind", "r", "fc", "f"],
            ],
            defaults: ["kind": "lowpass", "r": "10000", "c": "0.00000001", "f": "1000", "fc": "1591.5"]
        ),
        Spec(
            circuit: .seriesRLC, family: .transient,
            title: "Series RLC",
            blurb: "Resonance, Q, bandwidth, and the phasor impedance at one drive frequency.",
            defaultUnknown: "response",
            unknowns: [u("response", "At this f"), u("l", "L from f0"), u("c", "C from f0"), u("r", "R from Q")],
            fields: [
                n("r", "R", "Ω"), n("l", "L", "H"), n("c", "C", "F"),
                n("f", "Drive f", "Hz"), n("f0", "f0", "Hz"), n("q", "Q", ""),
            ],
            visible: [
                "response": ["r", "l", "c", "f"],
                "l": ["r", "c", "f0", "f"],
                "c": ["r", "l", "f0", "f"],
                "r": ["l", "c", "q", "f"],
            ],
            defaults: ["r": "10", "l": "0.001", "c": "0.0000001", "f": "15915", "f0": "15915", "q": "10"]
        ),
        Spec(
            circuit: .halfWave, family: .diode,
            title: "Half-wave rectifier",
            blurb: "One diode. Average of a sine, plus a capacitor-input ripple estimate.",
            defaultUnknown: "report",
            unknowns: [u("report", "Readings"), u("c", "C for ripple")],
            fields: [
                n("vrms", "Vrms", "V"), n("vf", "Vf", "V"), n("f", "f", "Hz"),
                n("c", "C", "F"), n("rload", "Rload", "Ω"), n("ripple", "Ripple target", "V"),
            ],
            visible: [
                "report": ["vrms", "vf", "f", "c", "rload"],
                "c": ["vrms", "vf", "f", "rload", "ripple"],
            ],
            defaults: ["vrms": "12", "vf": "0.7", "f": "60", "c": "0.0001", "rload": "100", "ripple": "1"]
        ),
        Spec(
            circuit: .fullBridge, family: .diode,
            title: "Full-wave bridge",
            blurb: "Four diodes, two drops. Average uses 2/π. Ripple uses 2f.",
            defaultUnknown: "report",
            unknowns: [u("report", "Readings"), u("c", "C for ripple")],
            fields: [
                n("vrms", "Vrms", "V"), n("vf", "Vf each", "V"), n("f", "Line f", "Hz"),
                n("c", "C", "F"), n("rload", "Rload", "Ω"), n("ripple", "Ripple target", "V"),
            ],
            visible: [
                "report": ["vrms", "vf", "f", "c", "rload"],
                "c": ["vrms", "vf", "f", "rload", "ripple"],
            ],
            defaults: ["vrms": "12", "vf": "0.7", "f": "60", "c": "0.0001", "rload": "100", "ripple": "0.5"]
        ),
        Spec(
            circuit: .shuntClipper, family: .diode,
            title: "Shunt clipper",
            blurb: "Series resistor, diode shunt. The peak sticks near the clip level.",
            defaultUnknown: "report",
            unknowns: [u("report", "Clipped peak"), u("r", "R for Ipeak")],
            fields: [
                n("vp", "Source peak", "V"), n("r", "R series", "Ω"), n("vf", "Vf", "V"),
                n("vbias", "Bias under diode", "V", "0 V clips near Vf above ground."),
                n("ipeak", "Ipeak limit", "A"),
            ],
            visible: [
                "report": ["vp", "r", "vf", "vbias"],
                "r": ["vp", "vf", "vbias", "ipeak"],
            ],
            defaults: ["vp": "10", "r": "1000", "vf": "0.7", "vbias": "0", "ipeak": "0.01"]
        ),
        Spec(
            circuit: .clamper, family: .diode,
            title: "Diode clamper",
            blurb: "Series capacitor and a diode to ground. The sine shifts; the swing stays.",
            defaultUnknown: "report",
            unknowns: [u("report", "Shifted peaks")],
            fields: [n("vp", "Source peak", "V"), n("vf", "Vf", "V")],
            visible: ["report": ["vp", "vf"]],
            defaults: ["vp": "10", "vf": "0.7"]
        ),
        Spec(
            circuit: .ledSeries, family: .diode,
            title: "LED and series R",
            blurb: "One LED, one resistor. R = (Vs − Vf) / If.",
            defaultUnknown: "resistance",
            unknowns: [u("resistance", "R"), u("current", "If"), u("supply", "Vs")],
            fields: [n("vs", "Vs", "V"), n("vf", "Vf", "V"), n("if", "If", "A"), n("r", "R", "Ω")],
            visible: [
                "resistance": ["vs", "vf", "if"],
                "current": ["vs", "vf", "r"],
                "supply": ["vf", "if", "r"],
            ],
            defaults: ["vs": "5", "vf": "2", "if": "0.02", "r": "150"]
        ),
        Spec(
            circuit: .bjtBias, family: .bjt,
            title: "Divider bias",
            blurb: "Four-resistor NPN bias. Vbe is 0.7 V. β is constant.",
            defaultUnknown: "point",
            unknowns: [u("point", "Q point"), u("re", "Re for Ic"), u("rc", "Rc for Vc")],
            fields: [
                n("vcc", "Vcc", "V"), n("r1", "R1 (base top)", "Ω"), n("r2", "R2 (base bottom)", "Ω"),
                n("rc", "Rc", "Ω"), n("re", "Re", "Ω"), n("beta", "β", ""),
                n("ic", "Target Ic", "A"), n("vc", "Target Vc", "V"),
            ],
            visible: [
                "point": ["vcc", "r1", "r2", "rc", "re", "beta"],
                "re": ["vcc", "r1", "r2", "rc", "beta", "ic"],
                "rc": ["vcc", "r1", "r2", "re", "beta", "vc"],
            ],
            defaults: ["vcc": "12", "r1": "47000", "r2": "10000", "rc": "2200", "re": "1000", "beta": "100", "ic": "0.001", "vc": "9"]
        ),
        Spec(
            circuit: .ceAmp, family: .bjt,
            title: "Common-emitter amp",
            blurb: "Same bias, plus a midband gain estimate. Vt = 26 mV.",
            defaultUnknown: "gain",
            unknowns: [u("gain", "Gain"), u("rc", "Rc for |Av|")],
            fields: [
                n("vcc", "Vcc", "V"), n("r1", "R1", "Ω"), n("r2", "R2", "Ω"),
                n("rc", "Rc", "Ω"), n("re", "Re", "Ω"), n("beta", "β", ""),
                n("rl", "RL (AC)", "Ω"),
                ch("bypass", "Emitter", [("bypassed", "Bypassed"), ("open", "Unbypassed")]),
                n("av", "Target |Av|", ""),
            ],
            visible: [
                "gain": ["vcc", "r1", "r2", "rc", "re", "beta", "rl", "bypass"],
                "rc": ["vcc", "r1", "r2", "re", "beta", "rl", "bypass", "av"],
            ],
            defaults: [
                "vcc": "12", "r1": "47000", "r2": "10000", "rc": "2200", "re": "1000",
                "beta": "100", "rl": "10000", "bypass": "bypassed", "av": "10",
            ]
        ),
        Spec(
            circuit: .bjtSwitch, family: .bjt,
            title: "BJT switch",
            blurb: "Low-side NPN. Saturated when forced β is under the device β.",
            defaultUnknown: "state",
            unknowns: [u("state", "On or off"), u("rb", "Rb to saturate")],
            fields: [
                n("vcc", "Vcc", "V"), n("rc", "Rc (load)", "Ω"), n("rb", "Rb", "Ω"),
                n("beta", "β", ""), n("vin", "Vin high", "V"),
            ],
            visible: [
                "state": ["vcc", "rc", "rb", "beta", "vin"],
                "rb": ["vcc", "rc", "beta", "vin"],
            ],
            defaults: ["vcc": "12", "rc": "1000", "rb": "10000", "beta": "100", "vin": "5"]
        ),
        Spec(
            circuit: .csAmp, family: .mosfet,
            title: "Common-source amp",
            blurb: "NMOS square law. kn is µCox·W/L in A/V². Rs = 0 is a pure CS stage.",
            defaultUnknown: "point",
            unknowns: [u("point", "Q point"), u("rd", "Rd for |Av|")],
            fields: [
                n("vdd", "Vdd", "V"), n("vg", "Vg", "V"), n("rd", "Rd", "Ω"), n("rs", "Rs", "Ω"),
                n("kn", "kn", "A/V²", "Square-law parameter, not a SPICE model card."),
                n("vt", "Vt", "V"), n("av", "Target |Av|", ""),
            ],
            visible: [
                "point": ["vdd", "vg", "rd", "rs", "kn", "vt"],
                "rd": ["vdd", "vg", "rs", "kn", "vt", "av"],
            ],
            defaults: ["vdd": "12", "vg": "2", "rd": "200", "rs": "0", "kn": "0.02", "vt": "1", "av": "4"]
        ),
        Spec(
            circuit: .mosSwitch, family: .mosfet,
            title: "MOSFET switch",
            blurb: "Low-side NMOS. On-state uses the Rds(on) you enter, not the square law.",
            defaultUnknown: "state",
            unknowns: [u("state", "On or off"), u("rdson", "Rds(on) max")],
            fields: [
                n("vdd", "Vdd", "V"), n("rd", "Rd (load)", "Ω"), n("vgs", "Vgs", "V"),
                n("vt", "Vt", "V"), n("rdson", "Rds(on)", "Ω"), n("vdslimit", "Vds limit", "V"),
            ],
            visible: [
                "state": ["vdd", "rd", "vgs", "vt", "rdson"],
                "rdson": ["vdd", "rd", "vgs", "vt", "vdslimit"],
            ],
            defaults: ["vdd": "12", "rd": "100", "vgs": "5", "vt": "2", "rdson": "0.05", "vdslimit": "0.1"]
        ),
        Spec(
            circuit: .cmosInverter, family: .mosfet,
            title: "CMOS inverter",
            blurb: "Matched-strength threshold and an ideal rail-to-rail logic level.",
            defaultUnknown: "threshold",
            unknowns: [u("threshold", "Threshold"), u("vout", "Logic level")],
            fields: [
                n("vdd", "Vdd", "V"), n("vtn", "Vtn", "V"), n("vtp", "|Vtp|", "V"), n("vin", "Vin", "V"),
            ],
            visible: [
                "threshold": ["vdd", "vtn", "vtp"],
                "vout": ["vdd", "vtn", "vtp", "vin"],
            ],
            defaults: ["vdd": "5", "vtn": "0.7", "vtp": "0.7", "vin": "1"]
        ),
        Spec(
            circuit: .invertingAmp, family: .opamp,
            title: "Inverting amp",
            blurb: "Ideal op-amp. The inverting input sits at 0 V.",
            defaultUnknown: "gain",
            unknowns: [u("gain", "Vout"), u("rf", "Rf"), u("vin", "Vin")],
            fields: [
                n("vin", "Vin", "V"), n("rin", "Rin", "Ω"), n("rf", "Rf", "Ω"),
                n("vsat", "Swing limit", "V", "Magnitude of the largest |Vout| you will accept."),
                n("av", "Target |Av|", ""), n("voutmag", "Target |Vout|", "V"),
            ],
            visible: [
                "gain": ["vin", "rin", "rf", "vsat"],
                "rf": ["vin", "rin", "vsat", "av"],
                "vin": ["rin", "rf", "vsat", "voutmag"],
            ],
            defaults: ["vin": "0.2", "rin": "10000", "rf": "100000", "vsat": "12", "av": "10", "voutmag": "2"]
        ),
        Spec(
            circuit: .nonInvertingAmp, family: .opamp,
            title: "Non-inverting amp",
            blurb: "Gain is 1 + Rf/Rg. Both inputs sit at Vin.",
            defaultUnknown: "gain",
            unknowns: [u("gain", "Vout"), u("rf", "Rf"), u("rg", "Rg")],
            fields: [
                n("vin", "Vin", "V"), n("rg", "Rg", "Ω"), n("rf", "Rf", "Ω"), n("vsat", "Swing limit", "V"),
                n("av", "Target Av", ""),
            ],
            visible: [
                "gain": ["vin", "rg", "rf", "vsat"],
                "rf": ["vin", "rg", "vsat", "av"],
                "rg": ["vin", "rf", "vsat", "av"],
            ],
            defaults: ["vin": "0.2", "rg": "10000", "rf": "90000", "vsat": "12", "av": "10"]
        ),
        Spec(
            circuit: .summingAmp, family: .opamp,
            title: "Summing amp",
            blurb: "Two-input inverting summer. The summing node is a virtual ground.",
            defaultUnknown: "output",
            unknowns: [u("output", "Vout"), u("rf", "Rf")],
            fields: [
                n("v1", "V1", "V"), n("r1", "R1", "Ω"), n("v2", "V2", "V"), n("r2", "R2", "Ω"),
                n("rf", "Rf", "Ω"), n("vsat", "Swing limit", "V"), n("vout", "Target |Vout|", "V"),
            ],
            visible: [
                "output": ["v1", "r1", "v2", "r2", "rf", "vsat"],
                "rf": ["v1", "r1", "v2", "r2", "vsat", "vout"],
            ],
            defaults: ["v1": "1", "r1": "10000", "v2": "1", "r2": "10000", "rf": "10000", "vsat": "12", "vout": "2"]
        ),
        Spec(
            circuit: .diffAmp, family: .opamp,
            title: "Difference amp",
            blurb: "Matched pairs. Vout = (Rf/R1)·(V2 − V1).",
            defaultUnknown: "output",
            unknowns: [u("output", "Vout"), u("rf", "Rf")],
            fields: [
                n("v1", "V1", "V"), n("v2", "V2", "V"), n("r1", "Rin", "Ω"), n("rf", "Rf", "Ω"),
                n("vsat", "Swing limit", "V"), n("gain", "Target gain", ""),
            ],
            visible: [
                "output": ["v1", "v2", "r1", "rf", "vsat"],
                "rf": ["v1", "v2", "r1", "vsat", "gain"],
            ],
            defaults: ["v1": "1", "v2": "1.2", "r1": "10000", "rf": "10000", "vsat": "12", "gain": "1"]
        ),
        Spec(
            circuit: .integrator, family: .opamp,
            title: "Integrator",
            blurb: "Constant input makes a ramp. Ideal, no practical reset resistor.",
            defaultUnknown: "ramp",
            unknowns: [u("ramp", "v(t)"), u("time", "Time"), u("c", "C")],
            fields: [
                n("r", "R", "Ω"), n("c", "C", "F"), n("vin", "Vin", "V"), n("t", "t", "s"),
                n("v0", "v(0)", "V"), n("vt", "Target v", "V"), n("vsat", "Swing limit", "V"),
            ],
            visible: [
                "ramp": ["r", "c", "vin", "t", "v0", "vsat"],
                "time": ["r", "c", "vin", "v0", "vt", "vsat"],
                "c": ["r", "vin", "t", "v0", "vt", "vsat"],
            ],
            defaults: ["r": "100000", "c": "0.000001", "vin": "1", "t": "0.1", "v0": "0", "vt": "-1", "vsat": "12"]
        ),
        Spec(
            circuit: .differentiator, family: .opamp,
            title: "Differentiator",
            blurb: "A constant slope in gives a constant voltage out. Ideal, no high-frequency roll-off.",
            defaultUnknown: "output",
            unknowns: [u("output", "Vout"), u("r", "R"), u("c", "C")],
            fields: [
                n("r", "R", "Ω"), n("c", "C", "F"), n("slope", "Slope", "V/s"),
                n("vout", "Target Vout", "V"), n("vsat", "Swing limit", "V"),
            ],
            visible: [
                "output": ["r", "c", "slope", "vsat"],
                "r": ["c", "slope", "vout", "vsat"],
                "c": ["r", "slope", "vout", "vsat"],
            ],
            defaults: ["r": "10000", "c": "0.000001", "slope": "100", "vout": "-1", "vsat": "12"]
        ),
        Spec(
            circuit: .comparator, family: .opamp,
            title: "Comparator",
            blurb: "Open loop. Output sits on one rail or the other. No linear gain.",
            defaultUnknown: "output",
            unknowns: [u("output", "Rail")],
            fields: [n("vin", "Vin", "V"), n("vref", "Vref", "V"), n("voh", "High rail", "V"), n("vol", "Low rail", "V")],
            visible: ["output": ["vin", "vref", "voh", "vol"]],
            defaults: ["vin": "2", "vref": "1.5", "voh": "5", "vol": "0"]
        ),
        Spec(
            circuit: .astable555, family: .timer,
            title: "555 astable",
            blurb: "Free-running timer. Duty of a plain astable stays above 50%.",
            defaultUnknown: "frequency",
            unknowns: [u("frequency", "Frequency"), u("c", "C"), u("r1", "R1"), u("r2", "R2"), u("resistors", "R1 and R2")],
            fields: [
                n("vcc", "Vcc", "V"), n("r1", "R1 (Vcc side)", "Ω"), n("r2", "R2 (cap side)", "Ω"),
                n("c", "C", "F"), n("frequency", "f", "Hz"), n("duty", "Duty", "%"),
            ],
            visible: [
                "frequency": ["vcc", "r1", "r2", "c"],
                "c": ["vcc", "r1", "r2", "frequency"],
                "r1": ["vcc", "r2", "c", "frequency"],
                "r2": ["vcc", "r1", "c", "frequency"],
                "resistors": ["vcc", "c", "frequency", "duty"],
            ],
            defaults: ["vcc": "5", "r1": "1000", "r2": "1000", "c": "0.000001", "frequency": "481", "duty": "67"]
        ),
        Spec(
            circuit: .monostable555, family: .timer,
            title: "555 monostable",
            blurb: "One-shot. Pulse width is ln(3)·R·C.",
            defaultUnknown: "width",
            unknowns: [u("width", "Pulse width"), u("r", "R"), u("c", "C")],
            fields: [n("vcc", "Vcc", "V"), n("r", "R", "Ω"), n("c", "C", "F"), n("width", "t", "s")],
            visible: [
                "width": ["vcc", "r", "c"],
                "r": ["vcc", "c", "width"],
                "c": ["vcc", "r", "width"],
            ],
            defaults: ["vcc": "5", "r": "10000", "c": "0.000001", "width": "0.011"]
        ),
        Spec(
            circuit: .ledFlasher, family: .digital,
            title: "LED flasher",
            blurb: "555 astable with an LED and its resistor on the output.",
            defaultUnknown: "rate",
            unknowns: [u("rate", "Flash rate"), u("c", "C"), u("rled", "LED resistor")],
            fields: [
                n("vcc", "Vcc", "V"), n("r1", "R1", "Ω"), n("r2", "R2", "Ω"), n("c", "C", "F"),
                n("vf", "LED Vf", "V"), n("rled", "Rled", "Ω"), n("frequency", "f", "Hz"),
                n("iled", "LED current", "A"),
            ],
            visible: [
                "rate": ["vcc", "r1", "r2", "c", "vf", "rled"],
                "c": ["vcc", "r1", "r2", "frequency", "vf", "rled"],
                "rled": ["vcc", "r1", "r2", "c", "vf", "iled"],
            ],
            defaults: [
                "vcc": "5", "r1": "10000", "r2": "100000", "c": "0.000001",
                "vf": "2", "rled": "330", "frequency": "6.86", "iled": "0.009",
            ]
        ),
        Spec(
            circuit: .sevenSegment, family: .digital,
            title: "7-segment drive",
            blurb: "Common-cathode digit. One resistor per lit segment. BCD pattern is the usual map.",
            defaultUnknown: "map",
            unknowns: [u("map", "Segments and current"), u("r", "R per segment")],
            fields: [
                ch("digit", "Digit", (0...9).map { ("\($0)", "\($0)") }),
                n("vcc", "Vcc", "V"), n("vf", "Vf", "V"), n("r", "R each", "Ω"), n("iseg", "I per segment", "A"),
            ],
            visible: [
                "map": ["digit", "vcc", "vf", "r"],
                "r": ["digit", "vcc", "vf", "iseg"],
            ],
            defaults: ["digit": "8", "vcc": "5", "vf": "2", "r": "330", "iseg": "0.009"]
        ),
        Spec(
            circuit: .classOverview, family: .amplifier,
            title: "Class overview",
            blurb: "Ideal class efficiencies used as a planning sketch, not a measured amplifier.",
            defaultUnknown: "dissipation",
            unknowns: [u("dissipation", "Supply and heat")],
            fields: [
                ch("ampClass", "Class", [("A", "A"), ("B", "B"), ("AB", "AB"), ("D", "D")]),
                n("pout", "Pout", "W"), n("vsupply", "Supply", "V"),
                opt("eta", "Efficiency override", "%", "Leave blank to use the ideal class figure."),
            ],
            visible: ["dissipation": ["ampClass", "pout", "vsupply", "eta"]],
            defaults: ["ampClass": "B", "pout": "10", "vsupply": "24", "eta": ""]
        ),
        Spec(
            circuit: .discretePower, family: .amplifier,
            title: "Discrete teaching amp",
            blurb: "Class-A CE stage. Quiescent transistor power and resistor power from the bias point.",
            defaultUnknown: "power",
            unknowns: [u("power", "Quiescent power")],
            fields: [
                n("vcc", "Vcc", "V"), n("r1", "R1", "Ω"), n("r2", "R2", "Ω"),
                n("rc", "Rc", "Ω"), n("re", "Re", "Ω"), n("beta", "β", ""),
            ],
            visible: ["power": ["vcc", "r1", "r2", "rc", "re", "beta"]],
            defaults: ["vcc": "12", "r1": "47000", "r2": "10000", "rc": "2200", "re": "1000", "beta": "100"]
        ),
        Spec(
            circuit: .opAmpPower, family: .amplifier,
            title: "Op-amp load amp",
            blurb: "Non-inverting stage into a resistive load. Ideal output current.",
            defaultUnknown: "load",
            unknowns: [u("load", "Load power"), u("rf", "Rf")],
            fields: [
                n("vin", "Vin", "V"), n("rg", "Rg", "Ω"), n("rf", "Rf", "Ω"),
                n("rl", "RL", "Ω"), n("vsat", "Swing limit", "V"), n("av", "Target Av", ""),
            ],
            visible: [
                "load": ["vin", "rg", "rf", "rl", "vsat"],
                "rf": ["vin", "rg", "rl", "vsat", "av"],
            ],
            defaults: ["vin": "0.5", "rg": "10000", "rf": "10000", "rl": "8", "vsat": "12", "av": "2"]
        ),
        Spec(
            circuit: .linearDrop, family: .power,
            title: "Linear regulator drop",
            blurb: "Pass element drops Vin − Vout. Heat is that drop times load current.",
            defaultUnknown: "drop",
            unknowns: [u("drop", "Drop and heat"), u("iload", "Max current"), u("vin", "Min Vin")],
            fields: [
                n("vin", "Vin", "V"), n("vout", "Vout", "V"), n("iload", "Iload", "A"),
                n("pdmax", "Pd max", "W"), n("dropout", "Dropout", "V"),
            ],
            visible: [
                "drop": ["vin", "vout", "iload"],
                "iload": ["vin", "vout", "pdmax"],
                "vin": ["vout", "iload", "dropout"],
            ],
            defaults: ["vin": "12", "vout": "5", "iload": "0.5", "pdmax": "2", "dropout": "2"]
        ),
        Spec(
            circuit: .idealBuck, family: .power,
            title: "Ideal buck",
            blurb: "Lossless step-down. Duty is Vout/Vin. Input current follows power balance.",
            defaultUnknown: "duty",
            unknowns: [u("duty", "Duty and Iin"), u("vout", "Vout"), u("iin", "Iin")],
            fields: [
                n("vin", "Vin", "V"), n("vout", "Vout", "V"), n("iout", "Iout", "A"), n("duty", "Duty", ""),
            ],
            visible: [
                "duty": ["vin", "vout", "iout"],
                "vout": ["vin", "duty", "iout"],
                "iin": ["vin", "vout", "iout"],
            ],
            defaults: ["vin": "12", "vout": "5", "iout": "2", "duty": "0.4167"]
        ),
        Spec(
            circuit: .complexConvert, family: .mathTools,
            title: "Complex convert",
            blurb: "Rectangular, polar, and exponential forms of one complex value.",
            defaultUnknown: "polar",
            unknowns: [u("polar", "To polar"), u("rect", "To rectangular")],
            fields: [
                n("x", "Real", ""), n("y", "Imag", ""), n("magnitude", "Magnitude", ""), n("angleDeg", "Angle", "°"),
            ],
            visible: [
                "polar": ["x", "y"],
                "rect": ["magnitude", "angleDeg"],
            ],
            defaults: ["x": "3", "y": "4", "magnitude": "5", "angleDeg": "53.1301"]
        ),
        Spec(
            circuit: .impedanceCombo, family: .mathTools,
            title: "Series / parallel Z",
            blurb: "Two impedances, each R + jX, combined in series or in parallel.",
            defaultUnknown: "result",
            unknowns: [u("result", "Combined Z")],
            fields: [
                ch("combo", "Connection", [("series", "Series"), ("parallel", "Parallel")]),
                n("r1", "R1", "Ω"), n("x1", "X1", "Ω"), n("r2", "R2", "Ω"), n("x2", "X2", "Ω"),
            ],
            visible: ["result": ["combo", "r1", "x1", "r2", "x2"]],
            defaults: ["combo": "series", "r1": "50", "x1": "20", "r2": "10", "x2": "-5"]
        ),
        Spec(
            circuit: .lMatch, family: .mathTools,
            title: "L-section match",
            blurb: "Lossless L-network between two real resistances at one frequency.",
            defaultUnknown: "parts",
            unknowns: [u("parts", "L and C")],
            fields: [
                n("rs", "Rs", "Ω"), n("rl", "RL", "Ω"), n("f", "f", "Hz"),
                ch("topology", "Shape", [("lowpass", "Low-pass"), ("highpass", "High-pass")]),
            ],
            visible: ["parts": ["rs", "rl", "f", "topology"]],
            defaults: ["rs": "50", "rl": "200", "f": "1000000", "topology": "lowpass"]
        ),
        Spec(
            circuit: .quarterWave, family: .mathTools,
            title: "Quarter-wave match",
            blurb: "Real Z0 = √(Zin·Zload). Length is λ/4 on an ideal line.",
            defaultUnknown: "z0",
            unknowns: [u("z0", "Line Z0"), u("zload", "Load")],
            fields: [
                n("zLoad", "Zload", "Ω"), n("zIn", "Zin wanted", "Ω"), n("z0", "Z0", "Ω"),
                n("f", "f", "Hz"), n("vf", "Velocity factor", ""),
            ],
            visible: [
                "z0": ["zLoad", "zIn", "f", "vf"],
                "zload": ["z0", "zIn", "f", "vf"],
            ],
            defaults: ["zLoad": "200", "zIn": "50", "z0": "100", "f": "100000000", "vf": "1"]
        ),
        Spec(
            circuit: .stubCancel, family: .mathTools,
            title: "Stub length",
            blurb: "Shorted or open ideal stub that presents a reactance, or cancels one.",
            defaultUnknown: "length",
            unknowns: [u("length", "Length")],
            fields: [
                n("x", "Reactance", "Ω", "Ohms of X. Cancel mode builds the stub for the opposite sign."),
                n("z0", "Z0", "Ω"), n("f", "f", "Hz"), n("vf", "Velocity factor", ""),
                ch("kind", "Stub", [("shorted", "Shorted"), ("open", "Open")]),
                ch("goal", "Goal", [("present", "Present this X"), ("cancel", "Cancel this X")]),
            ],
            visible: ["length": ["x", "z0", "f", "vf", "kind", "goal"]],
            defaults: ["x": "50", "z0": "50", "f": "300000000", "vf": "1", "kind": "shorted", "goal": "present"]
        ),
    ]
}
