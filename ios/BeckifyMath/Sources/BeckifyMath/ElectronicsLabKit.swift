import Foundation

enum LabKit {
    static let vbe = 0.7
    static let vceSat = 0.2
    static let vt = 0.026
    static let cLight = 299_792_458.0

    static var badUnknown: CalcError {
        CalcError.outOfRange("That unknown is not on this circuit.")
    }

    static func num(_ inputs: [String: String], _ key: String, _ name: String) throws -> Double {
        let raw = inputs[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let value = NumericParse.parse(raw, locale: Locale(identifier: "en_US_POSIX")) ?? NumericParse.parse(raw) {
            return value
        }
        throw CalcError.missing(name)
    }

    static func pos(_ inputs: [String: String], _ key: String, _ name: String) throws -> Double {
        try Positive.require(num(inputs, key, name), name: name)
    }

    static func nonNeg(_ inputs: [String: String], _ key: String, _ name: String) throws -> Double {
        let value = try num(inputs, key, name)
        guard value >= 0 else { throw CalcError.outOfRange("\(name) cannot be negative.") }
        return value
    }

    static func finite(_ inputs: [String: String], _ key: String, _ name: String) throws -> Double {
        let value = try num(inputs, key, name)
        guard value.isFinite else { throw CalcError.missing(name) }
        return value
    }

    static func optionalPercent(_ inputs: [String: String], _ key: String) throws -> Double? {
        let raw = inputs[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return nil }
        let value = try num(inputs, key, "Efficiency")
        guard value > 0, value <= 100 else {
            throw CalcError.outOfRange("Efficiency is a percent above 0 and at most 100.")
        }
        return value / 100
    }

    static func choice(
        _ inputs: [String: String],
        _ key: String,
        _ allowed: Set<String>,
        fallback: String,
        name: String
    ) throws -> String {
        let raw = inputs[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let value = raw.isEmpty ? fallback : raw
        guard allowed.contains(value) else {
            throw CalcError.outOfRange("\(name) is not a choice this circuit knows.")
        }
        return value
    }

    static func eng(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        let sign = value < 0 ? "-" : ""
        let magnitude = abs(value)
        if magnitude == 0 { return "0" }
        let decade = (floor(log10(magnitude) / 3) * 3)
        let clamped = min(12, max(-12, decade))
        let scaled = magnitude / pow(10, clamped)
        let suffix: String
        switch Int(clamped) {
        case 12: suffix = "T"
        case 9: suffix = "G"
        case 6: suffix = "M"
        case 3: suffix = "k"
        case 0: suffix = ""
        case -3: suffix = "m"
        case -6: suffix = "µ"
        case -9: suffix = "n"
        case -12: suffix = "p"
        default: suffix = ""
        }
        let digits = scaled >= 100 ? 0 : (scaled >= 10 ? 1 : 2)
        return sign + String(format: "%.\(digits)f", scaled) + suffix
    }

    /// Student-friendly SI readout: `600 µA`, `12.0 V`, `4.70 kΩ`.
    static func si(_ value: Double, unit: String) -> String {
        guard value.isFinite else { return "—" }
        let trimmed = unit.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return eng(value) }
        switch trimmed {
        case "A", "V", "W", "Ω", "ohm", "Ohms", "F", "H", "s", "Hz":
            let base: String = {
                switch trimmed {
                case "ohm", "Ohms": return "Ω"
                default: return trimmed
                }
            }()
            let magnitude = abs(value)
            if magnitude == 0 { return "0 \(base)" }
            let decade = floor(log10(magnitude) / 3) * 3
            let clamped = min(12, max(-12, decade))
            let scaled = magnitude / pow(10, clamped)
            let prefix: String
            switch Int(clamped) {
            case 12: prefix = "T"
            case 9: prefix = "G"
            case 6: prefix = "M"
            case 3: prefix = "k"
            case 0: prefix = ""
            case -3: prefix = "m"
            case -6: prefix = "µ"
            case -9: prefix = "n"
            case -12: prefix = "p"
            default: prefix = ""
            }
            let digits = scaled >= 100 ? 0 : (scaled >= 10 ? 1 : 2)
            let number = String(format: "%.\(digits)f", scaled)
            let sign = value < 0 ? "-" : ""
            let spaced = prefix.isEmpty ? "\(number) \(base)" : "\(number) \(prefix)\(base)"
            return sign + spaced
        default:
            let number = eng(value)
            return "\(number) \(trimmed)"
        }
    }

    static func wire(_ id: String, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> LabElement {
        LabElement(id: id, part: .wire, label: "", detail: "", a: LabPoint(x: x1, y: y1), b: LabPoint(x: x2, y: y2))
    }

    static func res(_ id: String, _ label: String, _ detail: String, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> LabElement {
        part(id, .resistor, label, detail, x1, y1, x2, y2)
    }

    static func cap(_ id: String, _ label: String, _ detail: String, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> LabElement {
        part(id, .capacitor, label, detail, x1, y1, x2, y2)
    }

    static func ind(_ id: String, _ label: String, _ detail: String, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> LabElement {
        part(id, .inductor, label, detail, x1, y1, x2, y2)
    }

    static func src(_ id: String, _ label: String, _ detail: String, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> LabElement {
        part(id, .voltageSource, label, detail, x1, y1, x2, y2)
    }

    static func dio(_ id: String, _ label: String, _ detail: String, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> LabElement {
        part(id, .diode, label, detail, x1, y1, x2, y2)
    }

    static func ledPart(_ id: String, _ label: String, _ detail: String, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> LabElement {
        part(id, .led, label, detail, x1, y1, x2, y2)
    }

    static func gnd(_ id: String, _ x: Double, _ y: Double) -> LabElement {
        part(id, .ground, "", "", x, y, x, y)
    }

    static func part(
        _ id: String,
        _ kind: LabPart,
        _ label: String,
        _ detail: String,
        _ x1: Double,
        _ y1: Double,
        _ x2: Double,
        _ y2: Double,
        flags: Int = 0
    ) -> LabElement {
        LabElement(
            id: id, part: kind, label: label, detail: detail,
            a: LabPoint(x: x1, y: y1), b: LabPoint(x: x2, y: y2), flags: flags
        )
    }

    static func node(_ id: String, _ name: String, _ value: Double, _ unit: String, _ x: Double, _ y: Double) -> LabNode {
        LabNode(id: id, name: name, value: value, unit: unit, at: LabPoint(x: x, y: y))
    }

    static func branch(_ id: String, _ name: String, _ value: Double, _ unit: String, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> LabBranch {
        LabBranch(id: id, name: name, value: value, unit: unit, a: LabPoint(x: x1, y: y1), b: LabPoint(x: x2, y: y2))
    }

    static func q(_ id: String, _ name: String, _ value: Double, _ unit: String, _ emphasis: Bool = false) -> LabQuantity {
        LabQuantity(id: id, name: name, value: value, unit: unit, emphasis: emphasis)
    }

    static func pack(
        _ circuit: ElectronicsCircuit,
        headline: String,
        elements: [LabElement],
        nodes: [LabNode],
        branches: [LabBranch],
        quantities: [LabQuantity],
        steps: [String],
        notes: [String],
        warning: String? = nil
    ) -> LabSolution {
        LabSolution(
            circuit: circuit,
            headline: headline,
            elements: elements,
            nodes: nodes,
            branches: branches,
            quantities: quantities,
            steps: steps,
        notes: Array(notes.prefix(4)),
        warning: warning,
        io: LabSignals.make(circuit: circuit, quantities: quantities)
    )
    }

    static func clampSwing(_ ideal: Double, limit: Double) -> (shown: Double, clipped: Bool) {
        let cap = abs(limit)
        if ideal > cap { return (cap, true) }
        if ideal < -cap { return (-cap, true) }
        return (ideal, false)
    }

    struct CX: Equatable {
        var r: Double
        var i: Double
        var mag: Double { hypot(r, i) }
        var deg: Double { atan2(i, r) * 180 / .pi }
        var rad: Double { atan2(i, r) }

        static func + (a: CX, b: CX) -> CX { CX(r: a.r + b.r, i: a.i + b.i) }
        static func * (a: CX, b: CX) -> CX { CX(r: a.r * b.r - a.i * b.i, i: a.r * b.i + a.i * b.r) }
        static func / (a: CX, b: CX) -> CX {
            let d = b.r * b.r + b.i * b.i
            return CX(r: (a.r * b.r + a.i * b.i) / d, i: (a.i * b.r - a.r * b.i) / d)
        }
    }

    struct BJTBias {
        var vbb: Double
        var rb: Double
        var ib: Double
        var ic: Double
        var ie: Double
        var vb: Double
        var vc: Double
        var ve: Double
        var vce: Double
        var saturated: Bool
        var cutoff: Bool
        var iR1: Double
        var iR2: Double
    }

    static func bjtBias(vcc: Double, r1: Double, r2: Double, rc: Double, re: Double, beta: Double) -> BJTBias {
        let vbb = vcc * r2 / (r1 + r2)
        let rb = 1 / (1 / r1 + 1 / r2)
        let ieActive = (vbb - vbe) / (re + rb / (beta + 1))
        if ieActive <= 0 {
            let iR2 = vbb / r2
            return BJTBias(
                vbb: vbb, rb: rb, ib: 0, ic: 0, ie: 0, vb: vbb, vc: vcc, ve: 0, vce: vcc,
                saturated: false, cutoff: true, iR1: (vcc - vbb) / r1, iR2: iR2
            )
        }
        let icActive = ieActive * beta / (beta + 1)
        let veActive = ieActive * re
        let vcActive = vcc - icActive * rc
        let vceActive = vcActive - veActive
        if vceActive < vceSat {
            let ic = (vcc - vceSat) / (rc + re)
            let ie = ic
            let ve = ie * re
            let vc = ve + vceSat
            let vb = ve + vbe
            let iR1 = max(0, (vcc - vb) / r1)
            let iR2 = max(0, vb / r2)
            let ib = max(0, iR1 - iR2)
            return BJTBias(
                vbb: vbb, rb: rb, ib: ib, ic: ic, ie: ie, vb: vb, vc: vc, ve: ve, vce: vceSat,
                saturated: true, cutoff: false, iR1: iR1, iR2: iR2
            )
        }
        let ib = icActive / beta
        let vb = veActive + vbe
        return BJTBias(
            vbb: vbb, rb: rb, ib: ib, ic: icActive, ie: ieActive, vb: vb, vc: vcActive, ve: veActive,
            vce: vceActive, saturated: false, cutoff: false, iR1: (vcc - vb) / r1, iR2: vb / r2
        )
    }

    static func bjtElements(_ bias: BJTBias, vcc: Double, r1: Double, r2: Double, rc: Double, re: Double) -> [LabElement] {
        [
            part("npn", .npn, "Q", "", 52, 44, 52, 44),
            wire("railL", 18, 14, 72, 14),
            res("r1", "R1", eng(r1) + " Ω", 28, 14, 28, 40),
            res("r2", "R2", eng(r2) + " Ω", 28, 40, 28, 70),
            wire("base", 28, 40, 44, 44),
            res("rc", "Rc", eng(rc) + " Ω", 70, 14, 70, 32),
            wire("col", 70, 32, 56, 34),
            res("re", "Re", eng(re) + " Ω", 52, 56, 52, 70),
            wire("gndw", 28, 70, 70, 70),
            gnd("g", 70, 70),
            part("vcc", .voltageSource, "Vcc", eng(vcc) + " V", 18, 70, 18, 14),
        ]
    }

    static func bjtNodes(_ bias: BJTBias, vcc: Double) -> [LabNode] {
        [
            node("vcc", "Vcc", vcc, "V", 18, 14),
            node("b", "Vb", bias.vb, "V", 28, 40),
            node("c", "Vc", bias.vc, "V", 70, 32),
            node("e", "Ve", bias.ve, "V", 52, 56),
            node("gnd", "GND", 0, "V", 70, 70),
        ]
    }

    static func bjtBranches(_ bias: BJTBias) -> [LabBranch] {
        [
            branch("ir1", "IR1", bias.iR1, "A", 28, 18, 28, 36),
            branch("ic", "Ic", bias.ic, "A", 70, 18, 70, 30),
            branch("ie", "Ie", bias.ie, "A", 52, 58, 52, 68),
        ]
    }

    /// Shortest positive electrical length, in wavelengths, for a stub that presents `reactance`.
    static func stubFraction(reactance: Double, z0: Double, shorted: Bool) throws -> Double {
        if abs(reactance) < 1e-9 {
            if shorted { return 0 }
            throw CalcError.outOfRange("An open stub cannot present 0 Ω. Use a shorted stub for a short.")
        }
        let theta: Double
        if shorted {
            theta = atan(reactance / z0)
        } else {
            theta = atan(-z0 / reactance)
        }
        let wrapped = theta <= 0 ? theta + .pi : theta
        return wrapped / (2 * .pi)
    }

    static func segmentMask(digit: Int) -> Int {
        switch digit {
        case 0: return 0b0111111
        case 1: return 0b0000110
        case 2: return 0b1011011
        case 3: return 0b1001111
        case 4: return 0b1100110
        case 5: return 0b1101101
        case 6: return 0b1111101
        case 7: return 0b0000111
        case 8: return 0b1111111
        case 9: return 0b1101111
        default: return 0
        }
    }

    static func segmentNames(_ mask: Int) -> String {
        let names = ["a", "b", "c", "d", "e", "f", "g"]
        return names.enumerated().compactMap { mask & (1 << $0.offset) != 0 ? $0.element : nil }.joined(separator: " ")
    }
}

// File-local names so the passive solvers stay readable.
func pack(
    _ circuit: ElectronicsCircuit,
    headline: String,
    elements: [LabElement],
    nodes: [LabNode],
    branches: [LabBranch],
    quantities: [LabQuantity],
    steps: [String],
    notes: [String],
    warning: String? = nil
) -> LabSolution {
    LabKit.pack(circuit, headline: headline, elements: elements, nodes: nodes, branches: branches, quantities: quantities, steps: steps, notes: notes, warning: warning)
}

func pos(_ inputs: [String: String], _ key: String, _ name: String) throws -> Double {
    try LabKit.pos(inputs, key, name)
}

func eng(_ value: Double) -> String { LabKit.eng(value) }
func si(_ value: Double, unit: String) -> String { LabKit.si(value, unit: unit) }
func wire(_ id: String, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> LabElement { LabKit.wire(id, x1, y1, x2, y2) }
func res(_ id: String, _ label: String, _ detail: String, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> LabElement {
    LabKit.res(id, label, detail, x1, y1, x2, y2)
}
func src(_ id: String, _ label: String, _ detail: String, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> LabElement {
    LabKit.src(id, label, detail, x1, y1, x2, y2)
}
func gnd(_ id: String, _ x: Double, _ y: Double) -> LabElement { LabKit.gnd(id, x, y) }
func cap(_ id: String, _ label: String, _ detail: String, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> LabElement {
    LabKit.cap(id, label, detail, x1, y1, x2, y2)
}
func ind(_ id: String, _ label: String, _ detail: String, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> LabElement {
    LabKit.ind(id, label, detail, x1, y1, x2, y2)
}
func dio(_ id: String, _ label: String, _ detail: String, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> LabElement {
    LabKit.dio(id, label, detail, x1, y1, x2, y2)
}
func ledPart(_ id: String, _ label: String, _ detail: String, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> LabElement {
    LabKit.ledPart(id, label, detail, x1, y1, x2, y2)
}
func part(_ id: String, _ kind: LabPart, _ label: String, _ detail: String, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, flags: Int = 0) -> LabElement {
    LabKit.part(id, kind, label, detail, x1, y1, x2, y2, flags: flags)
}
func node(_ id: String, _ name: String, _ value: Double, _ unit: String, _ x: Double, _ y: Double) -> LabNode {
    LabKit.node(id, name, value, unit, x, y)
}
func branch(_ id: String, _ name: String, _ value: Double, _ unit: String, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> LabBranch {
    LabKit.branch(id, name, value, unit, x1, y1, x2, y2)
}
func q(_ id: String, _ name: String, _ value: Double, _ unit: String, _ emphasis: Bool = false) -> LabQuantity {
    LabKit.q(id, name, value, unit, emphasis)
}

let badUnknown = LabKit.badUnknown
