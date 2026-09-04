import Foundation

/// Structured motor-nameplate fields. Raw OCR lines are evidence, not truth.
public enum NameplateFieldID: String, Codable, CaseIterable, Sendable, Hashable {
    case horsepower
    case rpm
    case voltage
    case amps
    case powerFactor
    case serviceFactor
    case frame
    case model
    case serial
    case manufacturer
    case frequency
    case phase
    case efficiency
    case enclosure

    public var label: String {
        switch self {
        case .horsepower: return "Horsepower"
        case .rpm: return "RPM"
        case .voltage: return "Voltage"
        case .amps: return "Amps"
        case .powerFactor: return "Power factor"
        case .serviceFactor: return "Service factor"
        case .frame: return "Frame"
        case .model: return "Model"
        case .serial: return "Serial"
        case .manufacturer: return "Manufacturer"
        case .frequency: return "Frequency"
        case .phase: return "Phase"
        case .efficiency: return "Efficiency"
        case .enclosure: return "Enclosure"
        }
    }

    public var unit: String {
        switch self {
        case .horsepower: return "HP"
        case .rpm: return "RPM"
        case .voltage: return "V"
        case .amps: return "A"
        case .powerFactor: return ""
        case .serviceFactor: return ""
        case .frame: return ""
        case .model: return ""
        case .serial: return ""
        case .manufacturer: return ""
        case .frequency: return "Hz"
        case .phase: return ""
        case .efficiency: return "%"
        case .enclosure: return ""
        }
    }
}

/// Where a structured value came from. `vlm` is reserved for a future cloud
/// path and is not emitted by the on-device heuristic in this package.
public enum NameplateFieldSource: String, Codable, Sendable {
    case heuristic
    case user
    case vlm
}

public struct NameplateOCRLine: Equatable, Sendable {
    public var text: String
    /// Optional Vision (or other recognizer) confidence in 0…1.
    public var confidence: Double?

    public init(text: String, confidence: Double? = nil) {
        self.text = text
        self.confidence = confidence
    }
}

public struct NameplateField: Equatable, Sendable {
    public var id: NameplateFieldID
    public var value: String
    /// 0…1. Below `NameplateFieldParser.lowConfidenceThreshold` the review UI
    /// should highlight the field so a human confirms it.
    public var confidence: Double
    public var source: NameplateFieldSource

    public init(
        id: NameplateFieldID,
        value: String,
        confidence: Double,
        source: NameplateFieldSource = .heuristic
    ) {
        self.id = id
        self.value = value
        self.confidence = min(max(confidence, 0), 1)
        self.source = source
    }

    public var isLowConfidence: Bool {
        source != .user && confidence < NameplateFieldParser.lowConfidenceThreshold
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

/// Policy for which agent runs. Cloud upload stays compiled-in as a stub and
/// is never enabled here — a future build would still require an explicit
/// user action before anything left the device.
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

/// Reserved cloud VLM hook. Throws rather than inventing model output.
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

        for (index, line) in compacted.enumerated() {
            let next = index + 1 < compacted.count ? compacted[index + 1] : nil
            take(labeled(in: line, next: next, id: .horsepower, labels: hpLabels, parse: parseHorsepower))
            take(labeled(in: line, next: next, id: .rpm, labels: rpmLabels, parse: parseRPM))
            take(labeled(in: line, next: next, id: .voltage, labels: voltLabels, parse: parseVoltage))
            take(labeled(in: line, next: next, id: .amps, labels: ampLabels, parse: parseAmps))
            take(labeled(in: line, next: next, id: .frequency, labels: hzLabels, parse: parseFrequency))
            take(labeled(in: line, next: next, id: .phase, labels: phaseLabels, parse: parsePhase))
            take(labeled(in: line, next: next, id: .serviceFactor, labels: sfLabels, parse: parseServiceFactor))
            take(labeled(in: line, next: next, id: .powerFactor, labels: pfLabels, parse: parsePowerFactor))
            take(labeled(in: line, next: next, id: .efficiency, labels: effLabels, parse: parseEfficiency))
            take(labeled(in: line, next: next, id: .frame, labels: frameLabels, parse: parseFrame))
            take(labeled(in: line, next: next, id: .enclosure, labels: enclosureLabels, parse: parseEnclosure))
            take(labeled(in: line, next: next, id: .serial, labels: serialLabels, parse: parseSerialOrModel))
            take(labeled(in: line, next: next, id: .model, labels: modelLabels, parse: parseSerialOrModel))
            take(labeled(in: line, next: next, id: .manufacturer, labels: mfrLabels, parse: parseManufacturer))
        }

        for line in compacted {
            take(unitSuffixed(line, id: .horsepower, suffixes: ["HP", "H.P."], parse: parseHorsepower))
            take(unitSuffixed(line, id: .rpm, suffixes: ["RPM", "R.P.M.", "R/MIN"], parse: parseRPM))
            take(unitSuffixed(line, id: .voltage, suffixes: ["V", "VOLT", "VOLTS"], parse: parseVoltage))
            take(unitSuffixed(line, id: .amps, suffixes: ["A", "AMP", "AMPS", "AMPERE", "AMPERES", "FLA"], parse: parseAmps))
            take(unitSuffixed(line, id: .frequency, suffixes: ["HZ", "HERTZ", "CYC", "CYCLES"], parse: parseFrequency))
            take(unitSuffixed(line, id: .phase, suffixes: ["PH", "PHASE", "Ø"], parse: parsePhase))
        }

        for line in compacted {
            if !claimed.contains(.enclosure), let value = enclosureToken(in: line.text) {
                take(NameplateField(id: .enclosure, value: value, confidence: scaled(0.78, line.confidence)))
            }
            if !claimed.contains(.frame), let value = bareFrame(in: line.text) {
                take(NameplateField(id: .frame, value: value, confidence: scaled(0.66, line.confidence)))
            }
            if !claimed.contains(.phase), let value = barePhase(in: line.text) {
                take(NameplateField(id: .phase, value: value, confidence: scaled(0.72, line.confidence)))
            }
        }

        if !claimed.contains(.horsepower) {
            for line in compacted {
                if let kw = labeledValue(in: line, next: nil, labels: ["KW", "K.W."], parse: parsePositiveNumber) {
                    let hp = (Double(kw) ?? 0) / 0.746
                    if hp > 0 {
                        take(NameplateField(
                            id: .horsepower,
                            value: formatNumber(hp, digits: hp >= 10 ? 1 : 2),
                            confidence: scaled(0.62, line.confidence)
                        ))
                    }
                }
            }
        }

        if !claimed.contains(.manufacturer), let mfr = firstManufacturer(in: compacted) {
            take(mfr)
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
    private static let rpmLabels = ["RPM", "R.P.M.", "R/MIN", "MIN-1", "SPEED"]
    private static let voltLabels = ["VOLTS", "VOLT", "VOLTAGE", "V"]
    private static let ampLabels = ["AMPS", "AMP", "AMPERES", "AMPERE", "FLA", "FLC", "AMPERES AMPS"]
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

    private static func parseAmps(_ raw: String) -> String? {
        guard let token = dualOrSingleNumber(raw) else { return nil }
        let parts = token.split(separator: "/").compactMap { Double($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 > 0 && $0 <= 20_000 }) else { return nil }
        return token
    }

    private static func parseFrequency(_ raw: String) -> String? {
        if let dual = dualOrSingleNumber(raw) {
            let parts = dual.split(separator: "/").compactMap { Double($0) }
            if parts.allSatisfy({ $0 == 50 || $0 == 60 }) { return dual }
        }
        guard let token = firstNumericToken(raw, allowingFraction: false),
              let value = Double(token),
              value == 50 || value == 60
        else { return nil }
        return stripTrailingZeros(token)
    }

    private static func parsePhase(_ raw: String) -> String? {
        let token = tokenize(raw).first.map(normalize) ?? normalize(raw)
        if token == "3" || token == "3.0" || token.hasPrefix("3PH") || token.hasPrefix("3P") { return "3" }
        if token == "1" || token == "1.0" || token.hasPrefix("1PH") || token.hasPrefix("1P") { return "1" }
        if token.contains("THREE") { return "3" }
        if token.contains("SINGLE") { return "1" }
        return nil
    }

    private static func parseServiceFactor(_ raw: String) -> String? {
        guard let token = firstNumericToken(raw, allowingFraction: true),
              let value = MotorFLA.horsepowerValue(token) ?? Double(token),
              value >= 0.8, value <= 2.0
        else { return nil }
        return token
    }

    private static func parsePowerFactor(_ raw: String) -> String? {
        guard let token = firstNumericToken(raw, allowingFraction: true),
              let value = Double(token)
        else { return nil }
        if value > 0, value <= 1.0 { return token }
        if value > 1, value <= 100 { return token }
        return nil
    }

    private static func parseEfficiency(_ raw: String) -> String? {
        let upper = normalize(raw)
        if let ie = ieClass(upper) { return ie }
        guard let token = firstNumericToken(raw, allowingFraction: true),
              let value = Double(token),
              value >= 20, value <= 100
        else { return nil }
        return token
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
            let beforeOK = isLabelBoundary(before: range.lowerBound, in: upper)
            let afterOK = range.upperBound == upper.endIndex
                || !upper[range.upperBound].isLetter
            if beforeOK && afterOK { return range }
            searchFrom = range.upperBound
        }
        return nil
    }

    /// Labels must be their own token. Rejects `10HP-215` (HP glued inside a
    /// model) and `10 HP 1750 RPM` (HP is a unit suffix). Allows `215T  SF`.
    private static func isLabelBoundary(before index: String.Index, in upper: String) -> Bool {
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
            return false
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

private extension NameplateFieldID {
    var sortOrder: Int {
        switch self {
        case .manufacturer: return 0
        case .model: return 1
        case .serial: return 2
        case .horsepower: return 3
        case .rpm: return 4
        case .voltage: return 5
        case .amps: return 6
        case .frequency: return 7
        case .phase: return 8
        case .serviceFactor: return 9
        case .powerFactor: return 10
        case .efficiency: return 11
        case .frame: return 12
        case .enclosure: return 13
        }
    }
}
