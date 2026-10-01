import Foundation

/// Face used when a transfer glyph is typeset.
public enum LabMathFace: String, Equatable, Sendable {
    /// Variable letters, including multi-letter subscripts such as `out`.
    case italic
    /// Function names (`tan`) and upright symbols (`Ω`).
    case upright
    /// Numerals stay upright so a gain like `0.5` does not look like a variable.
    case number
    /// `=`, `≈`, `∠`.
    case relation
    /// `+`, `−`, `·`, `×`.
    case operation
}

/// Structured transfer math. Built from a small TeX-lite subset so the bench
/// can stack fractions and subscripts without a web view.
public indirect enum LabMath: Equatable, Sendable {
    case row([LabMath])
    case fraction(LabMath, LabMath)
    case radical(LabMath)
    case glyph(String, face: LabMathFace)
    case script(base: LabMath, sub: LabMath?, sup: LabMath?)
    case delimited(LabMath, open: String, close: String)

    /// Parses a TeX-lite formula. Returns nil when the string is empty or unbalanced.
    /// Supported: `\frac{}{}`, `\sqrt{}`, `_{}` / `^{}`, `\cdot`, `\approx`, `\angle`,
    /// greek (`\omega`, `\pi`, `\eta`, `\theta`, `\beta`, `\ell`, `\tau`), and
    /// juxtaposition. Spaces are ignored, as in math mode.
    public static func parse(_ source: String) -> LabMath? {
        var parser = Parser(Array(source))
        return parser.parseAll()
    }

    /// Stable tree dump for tests. Not a display string.
    public var structure: String {
        switch self {
        case .row(let items):
            return "row(" + items.map(\.structure).joined(separator: " ") + ")"
        case .fraction(let numerator, let denominator):
            return "frac(\(numerator.structure) / \(denominator.structure))"
        case .radical(let body):
            return "sqrt(\(body.structure))"
        case .glyph(let text, let face):
            return "\(face.rawValue)[\(text)]"
        case .script(let base, let sub, let sup):
            let down = sub.map { "_(\($0.structure))" } ?? ""
            let up = sup.map { "^(\($0.structure))" } ?? ""
            return "script(\(base.structure)\(down)\(up))"
        case .delimited(let body, let open, let close):
            return "\(open)\(body.structure)\(close)"
        }
    }

    public var fractionCount: Int {
        switch self {
        case .row(let items):
            return items.reduce(0) { $0 + $1.fractionCount }
        case .fraction(let numerator, let denominator):
            return 1 + numerator.fractionCount + denominator.fractionCount
        case .radical(let body):
            return body.fractionCount
        case .glyph:
            return 0
        case .script(let base, let sub, let sup):
            return base.fractionCount + (sub?.fractionCount ?? 0) + (sup?.fractionCount ?? 0)
        case .delimited(let body, _, _):
            return body.fractionCount
        }
    }
}

private struct Parser {
    let chars: [Character]
    var index = 0
    var failed = false

    init(_ chars: [Character]) {
        self.chars = chars
    }

    mutating func parseAll() -> LabMath? {
        skipSpace()
        guard !chars.isEmpty else { return nil }
        let node = parseExpression(until: [])
        skipSpace()
        if failed || index != chars.count { return nil }
        return node
    }

    mutating func parseExpression(until stop: Set<Character>) -> LabMath {
        var parts: [LabMath] = []
        if let lead = takePrefixSign(until: stop) {
            parts.append(lead)
        }
        parts.append(parseTerm(until: stop))
        while !failed, let op = takeInfix(until: stop) {
            parts.append(op)
            parts.append(parseTerm(until: stop))
        }
        return combine(parts)
    }

    mutating func parseTerm(until stop: Set<Character>) -> LabMath {
        var parts: [LabMath] = []
        // A term after `=` may still start with a sign: `H(s) = -\frac{1}{sRC}`.
        if let sign = takePrefixSign(until: stop) {
            parts.append(sign)
        }
        while !failed {
            skipSpace()
            if stopped(until: stop) { break }
            if !parts.isEmpty, infixAhead(until: stop) { break }
            guard let factor = parseFactor(until: stop) else { break }
            parts.append(factor)
        }
        if parts.isEmpty {
            failed = true
            return .glyph("?", face: .upright)
        }
        return combine(parts)
    }

    mutating func parseFactor(until stop: Set<Character>) -> LabMath? {
        skipSpace()
        if stopped(until: stop) { return nil }
        if infixAhead(until: stop) { return nil }
        guard index < chars.count else { return nil }

        let base: LabMath
        let ch = chars[index]
        if ch == "(" {
            base = parseDelimited(open: "(", close: ")", until: stop)
        } else if ch == "|" {
            base = parseDelimited(open: "|", close: "|", until: stop)
        } else if ch == "\\" {
            guard let command = parseCommand(until: stop) else { return nil }
            base = command
        } else if ch.isNumber || (ch == "." && nextIsDigit) {
            base = parseNumber()
        } else if ch.isLetter {
            index += 1
            base = .glyph(String(ch), face: .italic)
        } else if let mapped = Self.unicode[ch] {
            index += 1
            base = mapped
        } else {
            failed = true
            return nil
        }
        if failed { return nil }
        return applyScripts(to: base, until: stop)
    }

    mutating func parseDelimited(open: Character, close: Character, until _: Set<Character>) -> LabMath {
        index += 1
        let body = parseExpression(until: [close])
        if !consume(close) { failed = true }
        return .delimited(body, open: String(open), close: String(close))
    }

    mutating func parseCommand(until stop: Set<Character>) -> LabMath? {
        guard consume("\\") else {
            failed = true
            return nil
        }
        let name = readCommandName()
        if name.isEmpty {
            failed = true
            return nil
        }
        switch name {
        case "frac":
            guard consume("{") else { failed = true; return nil }
            let numerator = parseExpression(until: ["}"])
            guard consume("}") else { failed = true; return nil }
            guard consume("{") else { failed = true; return nil }
            let denominator = parseExpression(until: ["}"])
            guard consume("}") else { failed = true; return nil }
            return .fraction(numerator, denominator)
        case "sqrt":
            guard consume("{") else { failed = true; return nil }
            let body = parseExpression(until: ["}"])
            guard consume("}") else { failed = true; return nil }
            return .radical(body)
        case "left", "right":
            return parseFactor(until: stop)
        case "approx":
            return .glyph("≈", face: .relation)
        case "angle":
            return .glyph("∠", face: .relation)
        case "cdot":
            return .glyph("·", face: .operation)
        case "times":
            return .glyph("×", face: .operation)
        default:
            if let symbol = Self.commands[name] {
                return symbol
            }
            failed = true
            return nil
        }
    }

    mutating func applyScripts(to base: LabMath, until stop: Set<Character>) -> LabMath {
        var sub: LabMath?
        var sup: LabMath?
        while !failed {
            skipSpace()
            if stopped(until: stop) { break }
            if peek == "_" {
                index += 1
                sub = parseScriptAtom(until: stop)
            } else if peek == "^" {
                index += 1
                sup = parseScriptAtom(until: stop)
            } else {
                break
            }
        }
        if sub == nil, sup == nil { return base }
        return .script(base: base, sub: sub, sup: sup)
    }

    mutating func parseScriptAtom(until stop: Set<Character>) -> LabMath {
        skipSpace()
        if peek == "{" {
            index += 1
            let body = parseExpression(until: ["}"])
            if !consume("}") { failed = true }
            return body
        }
        if let factor = parseFactor(until: stop.union(["_", "^"])) {
            return factor
        }
        failed = true
        return .glyph("?", face: .upright)
    }

    mutating func parseNumber() -> LabMath {
        var text = ""
        var sawDot = false
        while index < chars.count {
            let ch = chars[index]
            if ch.isNumber {
                text.append(ch)
                index += 1
            } else if ch == ".", !sawDot {
                let next = index + 1
                guard next < chars.count, chars[next].isNumber else { break }
                sawDot = true
                text.append(ch)
                index += 1
            } else {
                break
            }
        }
        if text.isEmpty { failed = true }
        return .glyph(text, face: .number)
    }

    mutating func takePrefixSign(until stop: Set<Character>) -> LabMath? {
        skipSpace()
        if stopped(until: stop) { return nil }
        if peek == "-" || peek == "−" {
            index += 1
            return .glyph("−", face: .operation)
        }
        if peek == "+" {
            index += 1
            return .glyph("+", face: .operation)
        }
        return nil
    }

    mutating func takeInfix(until stop: Set<Character>) -> LabMath? {
        skipSpace()
        if stopped(until: stop) { return nil }
        if peek == "+" {
            index += 1
            return .glyph("+", face: .operation)
        }
        if peek == "-" || peek == "−" {
            index += 1
            return .glyph("−", face: .operation)
        }
        if peek == "=" {
            index += 1
            return .glyph("=", face: .relation)
        }
        if peek == "≈" {
            index += 1
            return .glyph("≈", face: .relation)
        }
        if peek == "∠" {
            index += 1
            return .glyph("∠", face: .relation)
        }
        if peek == "\\" {
            let saved = index
            index += 1
            let name = readCommandName()
            if name == "approx" { return .glyph("≈", face: .relation) }
            if name == "angle" { return .glyph("∠", face: .relation) }
            index = saved
        }
        return nil
    }

    func infixAhead(until stop: Set<Character>) -> Bool {
        var copy = self
        return copy.takeInfix(until: stop) != nil
    }

    mutating func readCommandName() -> String {
        var name = ""
        while index < chars.count, chars[index].isLetter {
            name.append(chars[index])
            index += 1
        }
        return name
    }

    mutating func skipSpace() {
        while index < chars.count, chars[index].isWhitespace {
            index += 1
        }
    }

    func stopped(until stop: Set<Character>) -> Bool {
        if index >= chars.count { return true }
        return stop.contains(chars[index])
    }

    var peek: Character? {
        index < chars.count ? chars[index] : nil
    }

    var nextIsDigit: Bool {
        let next = index + 1
        return next < chars.count && chars[next].isNumber
    }

    @discardableResult
    mutating func consume(_ expected: Character) -> Bool {
        skipSpace()
        guard peek == expected else { return false }
        index += 1
        return true
    }

    func combine(_ parts: [LabMath]) -> LabMath {
        var flat: [LabMath] = []
        for part in parts {
            if case .row(let inner) = part {
                flat.append(contentsOf: inner)
            } else {
                flat.append(part)
            }
        }
        let merged = coalesce(flat)
        if merged.count == 1, let only = merged.first { return only }
        return .row(merged)
    }

    /// Adjacent single letters become one italic run (`sRC`, `out`) so a product
    /// reads as a word instead of three spaced glyphs.
    func coalesce(_ parts: [LabMath]) -> [LabMath] {
        var result: [LabMath] = []
        var letters = ""
        func flush() {
            if !letters.isEmpty {
                result.append(.glyph(letters, face: .italic))
                letters = ""
            }
        }
        for part in parts {
            if case .glyph(let text, .italic) = part, text.count == 1, text.allSatisfy(\.isLetter) {
                letters.append(contentsOf: text)
            } else {
                flush()
                result.append(part)
            }
        }
        flush()
        return result
    }

    static let commands: [String: LabMath] = [
        "omega": .glyph("ω", face: .italic),
        "Omega": .glyph("Ω", face: .upright),
        "pi": .glyph("π", face: .italic),
        "tau": .glyph("τ", face: .italic),
        "theta": .glyph("θ", face: .italic),
        "eta": .glyph("η", face: .italic),
        "beta": .glyph("β", face: .italic),
        "ell": .glyph("ℓ", face: .italic),
        "tan": .glyph("tan", face: .upright),
        "cot": .glyph("cot", face: .upright),
        "sin": .glyph("sin", face: .upright),
        "cos": .glyph("cos", face: .upright),
        "ln": .glyph("ln", face: .upright),
    ]

    static let unicode: [Character: LabMath] = [
        "ω": .glyph("ω", face: .italic),
        "Ω": .glyph("Ω", face: .upright),
        "π": .glyph("π", face: .italic),
        "τ": .glyph("τ", face: .italic),
        "θ": .glyph("θ", face: .italic),
        "η": .glyph("η", face: .italic),
        "β": .glyph("β", face: .italic),
        "ℓ": .glyph("ℓ", face: .italic),
        "·": .glyph("·", face: .operation),
        "×": .glyph("×", face: .operation),
        "√": .glyph("√", face: .upright),
    ]
}
