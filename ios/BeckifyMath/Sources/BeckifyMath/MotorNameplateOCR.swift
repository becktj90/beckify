import Foundation

public struct NameplateOCRLine: Equatable, Sendable {
    public var text: String
    /// Optional Vision (or other recognizer) confidence in 0…1.
    public var confidence: Double?

    public init(text: String, confidence: Double? = nil) {
        self.text = text
        self.confidence = confidence
    }
}

public struct NameplateExtraction: Equatable, Sendable {
    public var fields: [NameplateField]
    public var rawLines: [String]
    public var agentID: String
    public var leavesDevice: Bool

    public init(
        fields: [NameplateField],
        rawLines: [String],
        agentID: String,
        leavesDevice: Bool
    ) {
        self.fields = fields
        self.rawLines = rawLines
        self.agentID = agentID
        self.leavesDevice = leavesDevice
    }

    public func field(_ id: NameplateFieldID) -> NameplateField? {
        fields.first { $0.id == id }
    }

    public func value(_ id: NameplateFieldID) -> String? {
        field(id)?.value
    }

    public var populatedCount: Int { fields.filter { !$0.value.isEmpty }.count }

    public var asDictionary: [NameplateFieldID: String] {
        Dictionary(uniqueKeysWithValues: fields.map { ($0.id, $0.value) })
    }
}

public enum NameplateAgentError: Error, Equatable, Sendable {
    case cloudDisabled
    case emptyInput
}

/// Pluggable extract step. v1 ships the on-device heuristic. A cloud VLM can
/// implement this later without an API key in this package.
public protocol NameplateAgent: Sendable {
    var id: String { get }
    var leavesDevice: Bool { get }
    func extract(lines: [NameplateOCRLine]) async throws -> NameplateExtraction
}

/// Default extract is the on-device heuristic. Optional cloud Analyze lives
/// in the iOS view and runs only after an explicit tap.
public enum NameplateAgentPolicy {
    public static let cloudVLMEnabled = false
    public static let cloudVLMRequiresExplicitUserAction = true

    public static var activeAgent: any NameplateAgent {
        HeuristicNameplateAgent()
    }
}

/// On-device structured extract. Maps OCR lines to fields; does not treat the
/// raw dump as a finished nameplate.
public struct HeuristicNameplateAgent: NameplateAgent {
    public let id = "heuristic-v1"
    public let leavesDevice = false

    public init() {}

    public func extract(lines: [NameplateOCRLine]) async throws -> NameplateExtraction {
        var result = NameplateFieldParser.extract(lines: lines)
        result.agentID = id
        result.leavesDevice = false
        return result
    }
}

/// Reserved line-only hook. The live photo Analyze path is `NameplateCloudAnalyze`.
public struct CloudNameplateAgent: NameplateAgent {
    public let id = "cloud-vlm-disabled"
    public let leavesDevice = true

    public init() {}

    public func extract(lines: [NameplateOCRLine]) async throws -> NameplateExtraction {
        throw NameplateAgentError.cloudDisabled
    }
}

/// Label-aware heuristics for motor nameplates. Dual voltage/amps, stacked
/// Vision lines (`HP` then `10`), and value-then-unit forms are first-class.
public enum NameplateFieldParser {
    public static let lowConfidenceThreshold = 0.70

    public static func extract(text: String, agentID: String = "heuristic-v1") -> NameplateExtraction {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { NameplateOCRLine(text: String($0), confidence: nil) }
        var result = extract(lines: lines)
        result.agentID = agentID
        return result
    }

    public static func extract(lines: [NameplateOCRLine]) -> NameplateExtraction {
        let compacted = lines.compactMap { line -> NameplateOCRLine? in
            let text = compact(line.text)
            guard !text.isEmpty else { return nil }
            return NameplateOCRLine(text: text, confidence: line.confidence)
        }
        let raw = compacted.map(\.text)
        var claimed = Set<NameplateFieldID>()
        var fields: [NameplateField] = []

        func take(_ field: NameplateField?) {
            guard let field, !field.value.isEmpty, !claimed.contains(field.id) else { return }
            claimed.insert(field.id)
            fields.append(field)
        }

        func appendNote(_ text: String, confidence: Double) {
            let existing = fields.first { $0.id == .notes }
            let merged = [existing?.value, text].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "; ")
            fields.removeAll { $0.id == .notes }
            claimed.insert(.notes)
            fields.append(NameplateField(id: .notes, value: merged, confidence: confidence))
        }

        for (index, line) in compacted.enumerated() {
            let next = index + 1 < compacted.count ? compacted[index + 1] : nil
            take(labeled(in: line, next: next, id: .ratedHP, labels: hpLabels, parse: parseHorsepower))
            take(labeled(in: line, next: next, id: .ratedKW, labels: kwLabels, parse: parsePositiveNumber))
            take(labeled(in: line, next: next, id: .rpm, labels: rpmLabels, parse: parseRPM))
            take(labeled(in: line, next: next, id: .voltage, labels: voltLabels, parse: parseVoltage))
            take(labeled(in: line, next: next, id: .mocp, labels: mocpLabels, parse: parseSingleAmps))
            take(labeled(in: line, next: next, id: .lra, labels: lraLabels, parse: parseSingleAmps))
            take(labeled(in: line, next: next, id: .serviceFactorAmps, labels: sfaLabels, parse: parseSingleAmps))
            // Hard rule: LOCKED ROTOR AMPS / LRA AMPS / MOCP AMPS are never FLA.
            // Same-line `FLA 12.5 LRA 72` still records FLA from the FLA label.
            if !shouldSkipLabeledFLA(line.text) {
                take(labeled(in: line, next: next, id: .fla, labels: ampLabels, parse: parseFLA))
            }
            take(labeled(in: line, next: next, id: .frequencyHz, labels: hzLabels, parse: parseFrequencyHz))
            take(labeled(in: line, next: next, id: .phases, labels: phaseLabels, parse: parsePhase))
            take(labeled(in: line, next: next, id: .sf, labels: sfLabels, parse: parseServiceFactor))
            take(labeled(in: line, next: next, id: .pf, labels: pfLabels, parse: parsePowerFactor))
            take(labeled(in: line, next: next, id: .nomEff, labels: effLabels, parse: parseNomEff))
            take(labeled(in: line, next: next, id: .frame, labels: frameLabels, parse: parseFrame))
            take(labeled(in: line, next: next, id: .enclosure, labels: enclosureLabels, parse: parseEnclosure))
            take(labeled(in: line, next: next, id: .serialNumber, labels: serialLabels, parse: parseSerialOrModel))
            take(labeled(in: line, next: next, id: .model, labels: modelLabels, parse: parseSerialOrModel))
            take(labeled(in: line, next: next, id: .manufacturer, labels: mfrLabels, parse: parseManufacturer))
            take(labeled(in: line, next: next, id: .poles, labels: poleLabels, parse: parsePoles))
            take(labeled(in: line, next: next, id: .designLetter, labels: designLabels, parse: parseDesignLetter))
            take(labeled(in: line, next: next, id: .codeLetter, labels: codeLabels, parse: parseCodeLetter))
            take(labeled(in: line, next: next, id: .insulationClass, labels: insulationLabels, parse: parseInsulationClass))
        }

        for line in compacted {
            take(unitSuffixed(line, id: .ratedHP, suffixes: ["HP", "H.P."], parse: parseHorsepower))
            take(unitSuffixed(line, id: .ratedKW, suffixes: ["KW", "K.W."], parse: parsePositiveNumber))
            take(unitSuffixed(line, id: .rpm, suffixes: ["RPM", "R.P.M.", "R/MIN"], parse: parseRPM))
            take(unitSuffixed(line, id: .voltage, suffixes: ["V", "VOLT", "VOLTS"], parse: parseVoltage))
            if !isMOCPOrLRALine(line.text) {
                take(unitSuffixed(line, id: .fla, suffixes: ["A", "AMP", "AMPS", "AMPERE", "AMPERES", "FLA"], parse: parseFLA))
            }
            take(unitSuffixed(line, id: .frequencyHz, suffixes: ["HZ", "HERTZ", "CYC", "CYCLES"], parse: parseFrequencyHz))
            take(unitSuffixed(line, id: .phases, suffixes: ["PH", "PHASE", "Ø"], parse: parsePhase))
        }

        for line in compacted {
            if !claimed.contains(.enclosure), let value = enclosureToken(in: line.text) {
                take(NameplateField(id: .enclosure, value: value, confidence: scaled(0.78, line.confidence)))
            }
            if !claimed.contains(.frame), let value = bareFrame(in: line.text) {
                take(NameplateField(id: .frame, value: value, confidence: scaled(0.66, line.confidence)))
            }
            if !claimed.contains(.phases), let value = barePhase(in: line.text) {
                take(NameplateField(id: .phases, value: value, confidence: scaled(0.72, line.confidence)))
            }
            if let ie = ieClass(normalize(line.text)) {
                appendNote("IE class \(ie)", confidence: scaled(0.7, line.confidence))
            }
        }

        if !claimed.contains(.ratedHP), claimed.contains(.ratedKW),
           let kw = Double(fields.first { $0.id == .ratedKW }?.value ?? ""), kw > 0 {
            take(NameplateField(
                id: .ratedHP,
                value: formatNumber(kw / 0.746, digits: kw / 0.746 >= 10 ? 1 : 2),
                confidence: 0.62
            ))
        }
        if !claimed.contains(.ratedKW), claimed.contains(.ratedHP),
           let hp = MotorFLA.horsepowerValue(fields.first { $0.id == .ratedHP }?.value ?? ""), hp > 0 {
            take(NameplateField(
                id: .ratedKW,
                value: formatNumber(hp * 0.746, digits: 2),
                confidence: 0.62
            ))
        }

        if !claimed.contains(.poles),
           let rpm = Double(fields.first { $0.id == .rpm }?.value ?? ""),
           let hz = Double(fields.first { $0.id == .frequencyHz }?.value ?? ""),
           let poles = inferredPoles(rpm: rpm, frequencyHz: hz) {
            take(NameplateField(id: .poles, value: "\(poles)", confidence: 0.64))
        }

        if !claimed.contains(.manufacturer), let mfr = firstManufacturer(in: compacted) {
            take(mfr)
        }

        if let fla = fields.first(where: { $0.id == .fla }), fla.value.contains("/") {
            let three = fields.contains { $0.id == .phases && $0.value == "3" }
            let picked = preferredAmps(raw: fla.value, threePhase: three)
            fields.removeAll { $0.id == .fla }
            fields.append(NameplateField(
                id: .fla,
                value: picked,
                confidence: min(fla.confidence, 0.78),
                source: fla.source
            ))
            appendNote("dual FLA \(fla.value) — recorded \(picked) A", confidence: min(fla.confidence, 0.78))
        }

        let joined = compacted.map { normalize($0.text) }.joined(separator: " ")
        if joined.contains("50/60") || joined.contains("60/50") {
            appendNote("dual frequency 50/60 — recorded 60 Hz", confidence: 0.70)
        }

        fields.sort { $0.id.sortOrder < $1.id.sortOrder }
        return NameplateExtraction(
            fields: fields,
            rawLines: raw,
            agentID: "heuristic-v1",
            leavesDevice: false
        )
    }

    // MARK: - Dual-value / handoff helpers

    /// First number of a dual listing (`230/460` → `230`).
    public static func primaryToken(_ raw: String) -> String {
        let parts = raw.split(whereSeparator: { $0 == "/" || $0 == "," })
        return parts.first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? raw
    }

    /// Last number of a dual listing (`230/460` → `460`). Useful for 3Ø plant voltage.
    public static func secondaryToken(_ raw: String) -> String {
        let parts = raw.split(whereSeparator: { $0 == "/" || $0 == "," })
        return parts.last.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? raw
    }

    public static func preferredVoltage(raw: String, threePhase: Bool) -> String {
        threePhase ? secondaryToken(raw) : primaryToken(raw)
    }

    public static func preferredAmps(raw: String, threePhase: Bool) -> String {
        threePhase ? secondaryToken(raw) : primaryToken(raw)
    }

    /// Dual listings: high side for 3Ø, low side for 1Ø, first token when phase is unknown.
    public static func preferredToken(raw: String, phase: String) -> String {
        switch phase {
        case "3": return secondaryToken(raw)
        case "1": return primaryToken(raw)
        default: return primaryToken(raw)
        }
    }

    /// `true` / `false` only when OCR captured an explicit 3 or 1. Unknown is `nil`.
    public static func explicitThreePhase(_ phase: String) -> Bool? {
        switch phase {
        case "3": return true
        case "1": return false
        default: return nil
        }
    }

    /// Rebuild extractable labeled lines from saved schema keys (job restore).
    public static func reconstructText(from fields: [NameplateFieldID: String]) -> String {
        NameplateFieldID.allCases.compactMap { id in
            guard let value = fields[id]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                return nil
            }
            return "\(id.parserLabel) \(value)"
        }.joined(separator: "\n")
    }

    /// Even pole count whose synchronous speed sits just above a nameplate RPM.
    public static func inferredPoles(rpm: Double, frequencyHz: Double) -> Int? {
        guard rpm > 0, frequencyHz > 0 else { return nil }
        var best: (poles: Int, slip: Double)?
        for poles in stride(from: 2, through: 12, by: 2) {
            let sync = 120 * frequencyHz / Double(poles)
            guard sync > rpm else { continue }
            let slip = (sync - rpm) / sync
            guard slip >= 0, slip <= 0.20 else { continue }
            if best == nil || slip < best!.slip {
                best = (poles, slip)
            }
        }
        return best?.poles
    }

    public static func frequencyHertz(_ raw: String) -> Double? {
        Double(primaryToken(raw))
    }

    // MARK: - Line matching

    private static let hpLabels = ["HP", "H.P.", "H P", "HORSEPOWER", "HORSE POWER"]
    private static let kwLabels = ["KW", "K.W.", "KILOWATT", "KILOWATTS"]
    private static let rpmLabels = ["RPM", "R.P.M.", "R/MIN", "MIN-1", "SPEED"]
    private static let voltLabels = ["VOLTS", "VOLT", "VOLTAGE", "V"]
    private static let ampLabels = ["AMPS", "AMP", "AMPERES", "AMPERE", "FLA", "FLC"]
    private static let mocpLabels = ["MOCP", "MAX OCP", "MAXIMUM OCP", "MAX OVERCURRENT", "MAXIMUM OVERCURRENT"]
    private static let lraLabels = ["LRA", "LOCKED ROTOR", "LOCKED-ROTOR", "LR AMPS", "L.R.A."]
    private static let sfaLabels = ["SFA", "SF AMPS", "SF AMP", "SERVICE FACTOR AMPS"]
    private static let hzLabels = ["HZ", "HERTZ", "FREQ", "FREQUENCY", "CYCLES", "CYC"]
    private static let phaseLabels = ["PH", "PHASE", "PHAS", "Ø"]
    private static let sfLabels = ["SF", "S.F.", "SERVICE FACTOR", "SERV FACTOR"]
    private static let pfLabels = ["PF", "P.F.", "POWER FACTOR", "COS PHI", "COS Φ"]
    private static let effLabels = ["EFF", "EFFICIENCY", "NOM EFF", "NEMA NOM", "%EFF", "EFF."]
    private static let frameLabels = ["FRAME", "FR", "FR.", "IEC"]
    private static let enclosureLabels = ["ENCL", "ENCLOSURE", "ENCL.", "TYPE ENCL"]
    private static let serialLabels = ["SER", "S/N", "S.N.", "SN", "SERIAL", "SERIAL NO", "SERIAL NO.", "SER NO", "SER. NO."]
    private static let modelLabels = ["MODEL", "CAT", "CAT NO", "CAT. NO.", "CAT NO.", "TYPE", "SPEC", "SPEC NO", "SPEC. NO.", "CATALOG"]
    private static let mfrLabels = ["MFR", "MFG", "MANUFACTURER", "MADE BY"]
    private static let poleLabels = ["POLES", "POLE"]
    private static let designLabels = ["DESIGN", "NEMA DESIGN", "DES"]
    private static let codeLabels = ["CODE", "CODE LETTER"]
    private static let insulationLabels = ["INS", "INSUL", "INSULATION", "CLASS", "INS CLASS"]

    /// Hard rule: MOCP and LRA are never FLA, even when the line also says AMPS.
    public static func isMOCPOrLRALine(_ text: String) -> Bool {
        let upper = normalize(text)
        for label in mocpLabels + lraLabels {
            if rangeOfLabel(normalize(label), in: upper) != nil { return true }
        }
        return false
    }

    /// Skip labeled AMPS on LRA/MOCP lines, unless the line also has FLA/FLC.
    private static func shouldSkipLabeledFLA(_ text: String) -> Bool {
        guard isMOCPOrLRALine(text) else { return false }
        let upper = normalize(text)
        if rangeOfLabel("FLA", in: upper) != nil { return false }
        if rangeOfLabel("FLC", in: upper) != nil { return false }
        return true
    }

    private static func labeled(
        in line: NameplateOCRLine,
        next: NameplateOCRLine?,
        id: NameplateFieldID,
        labels: [String],
        parse: (String) -> String?
    ) -> NameplateField? {
        if let value = labeledValue(in: line, next: next, labels: labels, parse: parse) {
            let stacked = isBareLabel(line.text, labels: labels)
            let confidence = scaled(stacked ? 0.80 : 0.90, min(line.confidence ?? 1, next?.confidence ?? 1))
            return NameplateField(id: id, value: value, confidence: confidence)
        }
        return nil
    }

    private static func labeledValue(
        in line: NameplateOCRLine,
        next: NameplateOCRLine?,
        labels: [String],
        parse: (String) -> String?
    ) -> String? {
        let upper = normalize(line.text)
        if isBareLabel(line.text, labels: labels), let next, let parsed = parse(next.text) {
            return parsed
        }
        for label in labels {
            let needle = normalize(label)
            guard let range = rangeOfLabel(needle, in: upper) else { continue }
            // Skip glued unit-inside-token matches (`MODEL 10HP-215` must not claim HP=215).
            // Those are handled by the unit-suffix path (`10HP`).
            if range.lowerBound > upper.startIndex {
                let before = upper[upper.index(before: range.lowerBound)]
                if before.isNumber { continue }
            }
            let remainder = String(upper[range.upperBound...])
                .trimmingCharacters(in: CharacterSet(charactersIn: " :=-–—."))
            if let parsed = parse(remainder) { return parsed }
            // "HP10" with no separator
            if let parsed = parse(String(upper[range.upperBound...])) { return parsed }
        }
        return nil
    }

    private static func unitSuffixed(
        _ line: NameplateOCRLine,
        id: NameplateFieldID,
        suffixes: [String],
        parse: (String) -> String?
    ) -> NameplateField? {
        let tokens = tokenize(line.text)
        for (index, token) in tokens.enumerated() {
            let upper = normalize(token)
            guard suffixes.contains(where: { normalize($0) == upper }) else { continue }
            // Packed `VOLTS 460 AMPS 14`: AMPS is a label, so take 14, not 460.
            // Bare `A` / `V` stay value-then-unit so `14 A 60 HZ` is not stolen.
            if labelBeforeValueSuffixes.contains(upper),
               index + 1 < tokens.count,
               let parsed = parse(tokens[index + 1]) {
                return NameplateField(id: id, value: parsed, confidence: scaled(0.86, line.confidence))
            }
            if index > 0, let parsed = parse(tokens[index - 1]) {
                return NameplateField(id: id, value: parsed, confidence: scaled(0.86, line.confidence))
            }
        }
        // "10HP" glued
        for suffix in suffixes {
            let needle = normalize(suffix)
            let upper = normalize(line.text)
            if upper.hasSuffix(needle), upper.count > needle.count {
                let prefix = String(upper.dropLast(needle.count))
                if let parsed = parse(prefix) {
                    return NameplateField(id: id, value: parsed, confidence: scaled(0.84, line.confidence))
                }
            }
        }
        return nil
    }

    // MARK: - Value parsers

    private static func parseHorsepower(_ raw: String) -> String? {
        let token = firstNumericToken(raw, allowingFraction: true)
        guard let token else { return nil }
        guard let value = MotorFLA.horsepowerValue(token), value > 0, value <= 10_000 else { return nil }
        return token
    }

    private static func parseRPM(_ raw: String) -> String? {
        guard let token = firstNumericToken(raw, allowingFraction: false),
              let value = Double(token),
              value >= 200, value <= 30_000
        else { return nil }
        return stripTrailingZeros(token)
    }

    private static func parseVoltage(_ raw: String) -> String? {
        guard let token = dualOrSingleNumber(raw) else { return nil }
        let parts = token.split(separator: "/").compactMap { Double($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 >= 12 && $0 <= 15_000 }) else { return nil }
        return token
    }

    /// FLA only. Dual listings stay as `a/b` until extract() records one number.
    /// Does not reject a remainder that also mentions LRA — the labeled FLA
    /// token already selected this value. MOCP/LRA lines are skipped for
    /// unit-suffix AMPS so "MOCP 40 A" never becomes FLA.
    private static func parseFLA(_ raw: String) -> String? {
        guard let token = dualOrSingleNumber(raw) else { return nil }
        let parts = token.split(separator: "/").compactMap { Double($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 > 0 && $0 <= 2_000 }) else { return nil }
        return token
    }

    /// Single ampere reading for MOCP / LRA / SFA — never a dual FLA pair.
    private static func parseSingleAmps(_ raw: String) -> String? {
        firstNumber(in: raw, min: 0.1, max: 10_000)
    }

    /// Hertz as a single number. Dual `50/60` records 60 (common US plant).
    private static func parseFrequencyHz(_ raw: String) -> String? {
        let upper = normalize(raw)
        if upper.contains("50/60") || upper.contains("60/50") { return "60" }
        if let dual = dualOrSingleNumber(raw) {
            let parts = dual.split(separator: "/").compactMap { Double($0) }
            if parts.count == 2, parts.allSatisfy({ $0 == 50 || $0 == 60 }) { return "60" }
        }
        return firstNumber(in: raw, min: 25, max: 400)
    }

    /// Nominal efficiency as a percent (50–100). IE class goes to notes, not here.
    private static func parseNomEff(_ raw: String) -> String? {
        if ieClass(normalize(raw)) != nil { return nil }
        if let n = firstNumber(in: raw, min: 0.4, max: 1.0), let v = Double(n), v <= 1 {
            return formatNumber(v * 100, digits: 1)
        }
        return firstNumber(in: raw, min: 50, max: 100)
    }

    private static func parsePoles(_ raw: String) -> String? {
        guard let n = firstNumber(in: raw, min: 2, max: 16),
              let v = Double(n), v == floor(v), Int(v) % 2 == 0 else { return nil }
        return "\(Int(v))"
    }

    private static func parseDesignLetter(_ raw: String) -> String? {
        parseLetterToken(raw, allowed: "ABCDE")
    }

    private static func parseCodeLetter(_ raw: String) -> String? {
        parseLetterToken(raw, allowed: "ABCDEFGHJKLMNPQRSTUV")
    }

    private static func parseInsulationClass(_ raw: String) -> String? {
        parseLetterToken(raw, allowed: "ABFHN")
    }

    private static func parseLetterToken(_ raw: String, allowed: String) -> String? {
        let skip: Set<String> = [
            "LETTER", "CLASS", "NEMA", "DESIGN", "DES", "CODE",
            "INS", "INSUL", "INSULATION",
        ]
        for token in tokenize(raw) {
            let upper = normalize(token)
            if skip.contains(upper) { continue }
            if upper.count == 1, allowed.contains(upper) { return upper }
        }
        return nil
    }

    private static func firstNumber(in text: String, min: Double, max: Double) -> String? {
        guard let token = firstNumericToken(text, allowingFraction: true),
              let value = Double(token),
              value >= min, value <= max
        else { return nil }
        return stripTrailingZeros(token)
    }

    /// Whole tokens only (`1`, `3`, `1PH`, `3PH`). Does not match a `1`/`3` substring
    /// inside volts, amps, or frame numbers.
    private static func parsePhase(_ raw: String) -> String? {
        let tokens = tokenize(raw).map(normalize)
        let candidates = tokens.isEmpty ? [normalize(raw)] : tokens
        for token in candidates {
            if Self.threePhaseTokens.contains(token) { return "3" }
            if Self.singlePhaseTokens.contains(token) { return "1" }
        }
        let joined = candidates.joined(separator: " ")
        if joined.split(whereSeparator: { $0 == " " || $0 == "-" }).contains(where: { $0 == "THREE" }) {
            return "3"
        }
        if joined.split(whereSeparator: { $0 == " " || $0 == "-" }).contains(where: { $0 == "SINGLE" }) {
            return "1"
        }
        return nil
    }

    private static let threePhaseTokens: Set<String> = [
        "3", "3.0", "3PH", "3P", "3PHASE", "3Ø",
    ]
    private static let singlePhaseTokens: Set<String> = [
        "1", "1.0", "1PH", "1P", "1PHASE", "1Ø",
    ]

    private static func parseServiceFactor(_ raw: String) -> String? {
        guard let token = firstNumericToken(raw, allowingFraction: true),
              let value = MotorFLA.horsepowerValue(token) ?? Double(token),
              value >= 0.8, value <= 2.0
        else { return nil }
        return token
    }

    /// Power factor as 0–1. A plate that prints `82` or `82%` becomes `0.82`.
    private static func parsePowerFactor(_ raw: String) -> String? {
        guard let token = firstNumericToken(raw, allowingFraction: true),
              let value = Double(token), value > 0, value <= 100
        else { return nil }
        if value > 1 { return formatNumber(value / 100, digits: 2) }
        return formatNumber(value, digits: 2)
    }

    private static func parseFrame(_ raw: String) -> String? {
        let tokens = tokenize(raw)
        for token in tokens {
            if let frame = frameToken(token) { return frame }
        }
        return frameToken(raw.trimmingCharacters(in: .whitespaces))
    }

    private static func parseEnclosure(_ raw: String) -> String? {
        enclosureToken(in: raw)
    }

    private static func parseSerialOrModel(_ raw: String) -> String? {
        let tokens = tokenize(raw).filter { token in
            let upper = normalize(token)
            return !reservedKeywords.contains(upper) && enclosureToken(in: token) == nil
        }
        let joined = tokens.joined(separator: " ")
        guard joined.count >= 2, joined.count <= 40 else { return nil }
        if joined.allSatisfy({ $0.isNumber }) { return joined }
        guard joined.contains(where: { $0.isLetter || $0.isNumber }) else { return nil }
        return joined
    }

    private static func parseManufacturer(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2, trimmed.count <= 40 else { return nil }
        if let known = knownManufacturer(in: trimmed) { return known }
        let letters = trimmed.filter(\.isLetter)
        guard letters.count >= 3, !reservedKeywords.contains(normalize(trimmed)) else { return nil }
        return trimmed
    }

    private static func parsePositiveNumber(_ raw: String) -> String? {
        guard let token = firstNumericToken(raw, allowingFraction: true),
              let value = Double(token) ?? MotorFLA.horsepowerValue(token),
              value > 0
        else { return nil }
        return token
    }

    // MARK: - Distinctive tokens

    private static let enclosureTokens = [
        "TEFC", "ODP", "TENV", "TEAO", "TEBC", "XP", "XPRF", "WP1", "WP2",
        "WPI", "WPII", "WP-I", "WP-II", "OPEN", "DRIPPROOF",
    ]

    private static func enclosureToken(in text: String) -> String? {
        let tokens = tokenize(text)
        for token in tokens {
            let upper = normalize(token)
            if enclosureTokens.contains(upper) {
                return upper == "DRIPPROOF" ? "ODP" : (upper == "OPEN" ? "ODP" : upper)
            }
        }
        return nil
    }

    private static func bareFrame(in text: String) -> String? {
        tokenize(text).compactMap(frameToken).first
    }

    private static func frameToken(_ token: String) -> String? {
        let upper = token.uppercased()
        // NEMA: 56, 56C, 143T, 215T, 404TS. Not a bare 60 (Hz) or 3 (phase).
        if upper == "56" || upper == "48" || upper == "42" { return upper }
        let patternOK = upper.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0)
        }
        guard patternOK, upper.count >= 3, upper.count <= 6 else { return nil }
        let digits = upper.prefix { $0.isNumber }
        let suffix = upper.dropFirst(digits.count)
        guard digits.count >= 2, digits.count <= 3, !suffix.isEmpty,
              suffix.allSatisfy(\.isLetter),
              Set(suffix).isSubset(of: Set("CTUSHZ"))
        else { return nil }
        if let n = Int(digits), n >= 42, n <= 800 { return upper }
        return nil
    }

    private static func barePhase(in text: String) -> String? {
        let upper = normalize(text)
        if upper == "3PH" || upper == "3P" || upper == "3Ø" { return "3" }
        if upper == "1PH" || upper == "1P" || upper == "1Ø" { return "1" }
        return nil
    }

    private static func ieClass(_ upper: String) -> String? {
        for token in tokenize(upper) {
            let t = normalize(token)
            if t == "IE1" || t == "IE2" || t == "IE3" || t == "IE4" || t == "IE5" {
                return t
            }
        }
        return nil
    }

    private static let knownManufacturers = [
        "BALDOR", "WEG", "SIEMENS", "ABB", "MARATHON", "LEESON", "TECO",
        "TOSHIBA", "RELIANCE", "LINCOLN", "NIDEC", "EMERSON", "REGAL",
        "CENTURY", "FRANKLIN", "GOULDS", "PENTAIR", "GRUNDFOS", "HITACHI",
        "MITSUBISHI", "YASKAWA", "SEW", "NORD", "SUMITOMO", "TMEIC",
        "HYOSUNG", "GE", "US MOTORS", "A.O. SMITH", "AO SMITH",
        "GENERAL ELECTRIC", "BROOK CROMPTON", "WORLDWIDE ELECTRIC",
        "MAXMOTION", "EXAMPLE MOTORS",
    ]

    private static func knownManufacturer(in text: String) -> String? {
        let upper = normalize(text)
        for name in knownManufacturers {
            if upper == normalize(name) || upper.contains(normalize(name)) {
                return name
            }
        }
        return nil
    }

    private static func firstManufacturer(in lines: [NameplateOCRLine]) -> NameplateField? {
        for line in lines.prefix(4) {
            if reservedKeywords.contains(normalize(line.text)) { continue }
            if let known = knownManufacturer(in: line.text) {
                return NameplateField(id: .manufacturer, value: known, confidence: scaled(0.82, line.confidence))
            }
        }
        return nil
    }

    private static let reservedKeywords: Set<String> = [
        "HP", "H.P.", "RPM", "VOLTS", "VOLT", "VOLTAGE", "AMPS", "AMP", "FLA",
        "HZ", "PH", "PHASE", "SF", "PF", "EFF", "FRAME", "ENCL", "ENCLOSURE",
        "MODEL", "SERIAL", "TYPE", "CAT", "TEFC", "ODP", "TENV", "MOTOR",
        "NAMEPLATE", "AC", "DC", "INS", "CLASS", "DUTY", "CONT", "CONTINUOUS",
        "MOCP", "LRA", "SFA", "POLES", "POLE", "DESIGN", "CODE", "FLC",
    ]

    // MARK: - Text helpers

    static func compact(_ line: String) -> String {
        line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func normalize(_ text: String) -> String {
        text.uppercased()
            .replacingOccurrences(of: "Ø", with: "PH")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func tokenize(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "," }).map(String.init)
    }

    private static func isBareLabel(_ text: String, labels: [String]) -> Bool {
        let upper = normalize(text)
        return labels.contains { normalize($0) == upper }
    }

    private static func rangeOfLabel(_ needle: String, in upper: String) -> Range<String.Index>? {
        var searchFrom = upper.startIndex
        while searchFrom < upper.endIndex,
              let range = upper.range(of: needle, range: searchFrom..<upper.endIndex)
        {
            let beforeOK = isLabelBoundary(before: range.lowerBound, in: upper, needle: needle)
            let afterOK = range.upperBound == upper.endIndex
                || !upper[range.upperBound].isLetter
            if beforeOK && afterOK { return range }
            searchFrom = range.upperBound
        }
        return nil
    }

    /// Labels that can follow a value on a packed line (`FLA 12.5 LRA 72`,
    /// `VOLTS 460 AMPS 14`). HP / RPM / V / A stay unit suffixes so
    /// `10 HP 1750 RPM` is not stolen.
    private static let labelsAllowedAfterNumber: Set<String> = [
        "LRA", "L.R.A.", "LOCKED ROTOR", "LOCKED-ROTOR", "LR AMPS",
        "MOCP", "MAX OCP", "MAXIMUM OCP", "MAX OVERCURRENT", "MAXIMUM OVERCURRENT",
        "SFA", "SF AMPS", "SF AMP", "SERVICE FACTOR AMPS",
        "FLA", "FLC", "AMPS", "AMP", "AMPERES", "AMPERE",
        "SF", "S.F.", "SERVICE FACTOR",
        "PF", "P.F.", "POWER FACTOR",
        "DESIGN", "NEMA DESIGN", "CODE", "CODE LETTER",
        "CLASS", "INS CLASS",
        "SER", "SN", "S/N",
    ]

    /// Suffix tokens that may be a label before a value on a packed line.
    private static let labelBeforeValueSuffixes: Set<String> = [
        "AMPS", "AMP", "AMPERES", "AMPERE", "FLA", "FLC",
        "VOLTS", "VOLT", "VOLTAGE",
    ]

    /// Labels must be their own token. Rejects `10HP-215` (HP glued inside a
    /// model) and `10 HP 1750 RPM` (HP is a unit suffix). Allows `215T  SF`
    /// and a second amp label after a number (`FLA 12.5 LRA 72`).
    private static func isLabelBoundary(before index: String.Index, in upper: String, needle: String) -> Bool {
        guard index > upper.startIndex else { return true }
        let immediate = upper[upper.index(before: index)]
        if immediate.isLetter || immediate.isNumber { return false }

        var cursor = upper.index(before: index)
        while cursor > upper.startIndex, upper[cursor].isWhitespace {
            cursor = upper.index(before: cursor)
        }
        if upper[cursor].isWhitespace { return true }

        var tokenStart = cursor
        while tokenStart > upper.startIndex {
            let previous = upper.index(before: tokenStart)
            if upper[previous].isWhitespace { break }
            tokenStart = previous
        }
        let prior = String(upper[tokenStart...cursor])
        if Double(prior) != nil || MotorFLA.horsepowerValue(prior) != nil {
            return labelsAllowedAfterNumber.contains(needle)
        }
        return true
    }

    private static func firstNumericToken(_ raw: String, allowingFraction: Bool) -> String? {
        let compact = raw.trimmingCharacters(in: .whitespaces)
        if allowingFraction, let frac = mixedOrFraction(compact) {
            return frac
        }
        var token = ""
        var started = false
        for character in compact {
            if character.isNumber || character == "." {
                token.append(character)
                started = true
            } else if started {
                break
            }
        }
        return token.isEmpty ? nil : token
    }

    private static func mixedOrFraction(_ raw: String) -> String? {
        var token = ""
        for character in raw {
            if character.isNumber || character == "." || character == "-" || character == "/" {
                token.append(character)
            } else if !token.isEmpty {
                break
            }
        }
        guard token.contains("/"), MotorFLA.horsepowerValue(token) != nil else { return nil }
        return token
    }

    private static func dualOrSingleNumber(_ raw: String) -> String? {
        let compact = raw.trimmingCharacters(in: .whitespaces)
        var token = ""
        var started = false
        for character in compact {
            if character.isNumber || character == "." || character == "/" {
                token.append(character)
                started = true
            } else if started {
                break
            }
        }
        if token.hasPrefix("/") || token.hasSuffix("/") || token.contains("//") { return nil }
        return token.isEmpty ? nil : token
    }

    private static func scaled(_ base: Double, _ vision: Double?) -> Double {
        guard let vision else { return base }
        return min(max(base * max(vision, 0.15), 0), 1)
    }

    private static func stripTrailingZeros(_ token: String) -> String {
        guard token.contains("."), let value = Double(token), value == floor(value) else { return token }
        return String(Int(value))
    }

    private static func formatNumber(_ value: Double, digits: Int) -> String {
        let rounded = (value * pow(10, Double(digits))).rounded() / pow(10, Double(digits))
        if rounded == floor(rounded) { return String(Int(rounded)) }
        return String(format: "%.\(digits)f", rounded)
    }
}
