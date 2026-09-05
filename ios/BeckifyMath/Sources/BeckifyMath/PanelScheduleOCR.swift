import Foundation

/// One Vision (or fixture) line from a panel schedule / directory sticker.
public struct PanelOCRLine: Equatable, Sendable {
    public var text: String
    /// Optional recognizer confidence in 0…1.
    public var confidence: Double?

    public init(text: String, confidence: Double? = nil) {
        self.text = text
        self.confidence = confidence
    }
}

/// Where a structured panel value came from. `vlm` is reserved for a future
/// cloud path and is not emitted by the on-device heuristic in this package.
public enum PanelFieldSource: String, Codable, Sendable {
    case heuristic
    case user
    case vlm
}

/// One guessed circuit row: value + confidence + reviewed. Never treat as
/// truth until a human confirms.
public struct PanelCircuitDraft: Equatable, Sendable, Identifiable, Codable {
    public var id: String
    public var circuit: String
    public var name: String
    public var trip: String
    public var poles: String
    public var loadClass: LoadRowType
    public var confidence: Double
    public var reviewed: Bool
    public var source: PanelFieldSource
    /// True when the heuristic rewrote a hard-to-read token (UGHTING → LIGHTING).
    public var guessed: Bool

    public init(
        id: String = UUID().uuidString,
        circuit: String,
        name: String,
        trip: String = "",
        poles: String = "",
        loadClass: LoadRowType = .other,
        confidence: Double,
        reviewed: Bool = false,
        source: PanelFieldSource = .heuristic,
        guessed: Bool = false
    ) {
        self.id = id
        self.circuit = circuit
        self.name = name
        self.trip = trip
        self.poles = poles
        self.loadClass = loadClass
        self.confidence = min(max(confidence, 0), 1)
        self.reviewed = reviewed
        self.source = source
        self.guessed = guessed
    }

    public var isLowConfidence: Bool {
        !reviewed && source != .user && confidence < PanelScheduleParser.lowConfidenceThreshold
    }

    public var isSpareOrSpace: Bool {
        PanelScheduleParser.isSpareOrSpace(name)
    }

    public var asCircuit: PanelCircuit {
        PanelCircuit(circuit: circuit, name: name, trip: trip, poles: poles)
    }

    public static func from(
        _ row: PanelCircuit,
        confidence: Double,
        guessed: Bool = false,
        source: PanelFieldSource = .heuristic
    ) -> PanelCircuitDraft {
        PanelCircuitDraft(
            circuit: row.circuit,
            name: row.name,
            trip: row.trip,
            poles: row.poles,
            loadClass: PanelScheduleParser.classifyLoad(row.name),
            confidence: confidence,
            source: source,
            guessed: guessed
        )
    }
}

/// Panel-level metadata slot (name, voltage, main, phases).
public struct PanelHeaderField: Equatable, Sendable, Codable {
    public var value: String
    public var confidence: Double
    public var reviewed: Bool
    public var source: PanelFieldSource

    public init(
        value: String = "",
        confidence: Double = 0,
        reviewed: Bool = false,
        source: PanelFieldSource = .heuristic
    ) {
        self.value = value
        self.confidence = min(max(confidence, 0), 1)
        self.reviewed = reviewed
        self.source = source
    }

    public static var empty: PanelHeaderField { PanelHeaderField() }

    public var isPresent: Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var isLowConfidence: Bool {
        isPresent && !reviewed && source != .user && confidence < PanelScheduleParser.lowConfidenceThreshold
    }

    public func markingReviewedIfPresent() -> PanelHeaderField {
        guard isPresent else { return self }
        return PanelHeaderField(value: value, confidence: confidence, reviewed: true, source: source)
    }
}

public struct PanelScheduleExtraction: Equatable, Sendable {
    public var circuits: [PanelCircuitDraft]
    public var panelName: PanelHeaderField
    public var voltage: PanelHeaderField
    public var mainRating: PanelHeaderField
    public var phases: PanelHeaderField
    public var rawLines: [String]
    public var agentID: String
    public var leavesDevice: Bool

    public init(
        circuits: [PanelCircuitDraft],
        panelName: PanelHeaderField = .empty,
        voltage: PanelHeaderField = .empty,
        mainRating: PanelHeaderField = .empty,
        phases: PanelHeaderField = .empty,
        rawLines: [String],
        agentID: String,
        leavesDevice: Bool
    ) {
        self.circuits = circuits
        self.panelName = panelName
        self.voltage = voltage
        self.mainRating = mainRating
        self.phases = phases
        self.rawLines = rawLines
        self.agentID = agentID
        self.leavesDevice = leavesDevice
    }

    public var populatedCount: Int { circuits.count }

    public func confirmingReview() -> PanelScheduleExtraction {
        var copy = self
        copy.circuits = circuits.map { row in
            var next = row
            next.reviewed = true
            return next
        }
        copy.panelName = panelName.markingReviewedIfPresent()
        copy.voltage = voltage.markingReviewedIfPresent()
        copy.mainRating = mainRating.markingReviewedIfPresent()
        copy.phases = phases.markingReviewedIfPresent()
        return copy
    }

    /// Merge operator edits. Edited values are `user` with confidence 1;
    /// `reviewed` stays false until confirm.
    public func applying(draft: [PanelCircuitDraft]) -> PanelScheduleExtraction {
        var copy = self
        copy.circuits = draft.map { row in
            let original = circuits.first { $0.id == row.id }
            let edited = original.map {
                $0.circuit != row.circuit
                    || $0.name != row.name
                    || $0.trip != row.trip
                    || $0.poles != row.poles
                    || $0.loadClass != row.loadClass
            } ?? true
            var next = row
            if edited {
                next.confidence = 1
                next.source = .user
                next.reviewed = false
                next.guessed = false
            }
            return next
        }
        return copy
    }

    public func applyingHeader(
        panelName: String,
        voltage: String,
        mainRating: String,
        phases: String
    ) -> PanelScheduleExtraction {
        var copy = self
        func apply(_ current: PanelHeaderField, _ next: String) -> PanelHeaderField {
            let trimmed = next.trimmingCharacters(in: .whitespacesAndNewlines)
            let edited = current.value != trimmed
            return PanelHeaderField(
                value: trimmed,
                confidence: edited ? 1 : current.confidence,
                reviewed: false,
                source: edited ? .user : current.source
            )
        }
        copy.panelName = apply(self.panelName, panelName)
        copy.voltage = apply(self.voltage, voltage)
        copy.mainRating = apply(self.mainRating, mainRating)
        copy.phases = apply(self.phases, phases)
        return copy
    }

    public func tsv() -> String {
        var lines = ["Circuit\tName\tTrip\tPoles\tClass"]
        for row in circuits {
            lines.append("\(row.circuit)\t\(row.name)\t\(row.trip)\t\(row.poles)\t\(row.loadClass.rawValue)")
        }
        return lines.joined(separator: "\n")
    }
}

public enum PanelAgentError: Error, Equatable, Sendable {
    case cloudDisabled
    case emptyInput
}

/// Pluggable extract step. v1 ships the on-device heuristic. A cloud VLM can
/// implement this later without an API key in this package.
public protocol PanelAgent: Sendable {
    var id: String { get }
    var leavesDevice: Bool { get }
    func extract(lines: [PanelOCRLine]) async throws -> PanelScheduleExtraction
}

/// Default extract is the on-device heuristic. Optional cloud Analyze lives
/// in the iOS view and runs only after an explicit tap.
public enum PanelAgentPolicy {
    public static let cloudVLMEnabled = false
    public static let cloudVLMRequiresExplicitUserAction = true

    public static var activeAgent: any PanelAgent {
        HeuristicPanelAgent()
    }
}

/// On-device structured extract. Maps OCR lines to circuit rows; does not
/// treat the raw dump as a finished schedule.
public struct HeuristicPanelAgent: PanelAgent {
    public let id = "heuristic-v1"
    public let leavesDevice = false

    public init() {}

    public func extract(lines: [PanelOCRLine]) async throws -> PanelScheduleExtraction {
        var result = PanelScheduleParser.extract(lines: lines)
        result.agentID = id
        result.leavesDevice = false
        return result
    }
}

/// Reserved line-only hook. The live photo Analyze path is `PanelCloudAnalyze`.
public struct CloudPanelAgent: PanelAgent {
    public let id = "cloud-vlm-disabled"
    public let leavesDevice = true

    public init() {}

    public func extract(lines: [PanelOCRLine]) async throws -> PanelScheduleExtraction {
        throw PanelAgentError.cloudDisabled
    }
}

/// Label-aware heuristics for panel schedules and directory stickers.
/// Guessed tokens are flagged so the review sheet can highlight them.
public enum PanelScheduleParser {
    public static let lowConfidenceThreshold = 0.70

    public static func extract(text: String, agentID: String = "heuristic-v1") -> PanelScheduleExtraction {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { PanelOCRLine(text: String($0), confidence: nil) }
        var result = extract(lines: lines)
        result.agentID = agentID
        return result
    }

    public static func extract(lines: [PanelOCRLine]) -> PanelScheduleExtraction {
        let compacted = lines.compactMap { line -> PanelOCRLine? in
            let text = PanelDirectory.compact(line.text)
            guard !text.isEmpty else { return nil }
            return PanelOCRLine(text: text, confidence: line.confidence)
        }
        let raw = compacted.map(\.text)
        let header = extractHeader(from: compacted)

        var drafts: [PanelCircuitDraft] = []
        var seen = Set<String>()
        for line in compacted {
            if PanelDirectory.isIgnored(line.text) { continue }
            let guessed = guessHardToRead(line.text)
            let parsed = PanelDirectory.parse(guessed.text)
            let vision = line.confidence
            for row in parsed {
                let key = "\(row.circuit)|\(row.name)|\(row.trip)|\(row.poles)".uppercased()
                if seen.contains(key) { continue }
                seen.insert(key)
                let base = rowBaseConfidence(row, guessed: guessed.changed)
                drafts.append(PanelCircuitDraft.from(
                    row,
                    confidence: scaled(base, vision),
                    guessed: guessed.changed
                ))
            }
        }

        return PanelScheduleExtraction(
            circuits: drafts,
            panelName: header.panelName,
            voltage: header.voltage,
            mainRating: header.mainRating,
            phases: header.phases,
            rawLines: raw,
            agentID: "heuristic-v1",
            leavesDevice: false
        )
    }

    // MARK: - Header

    public struct HeaderGuess: Equatable, Sendable {
        public var panelName: PanelHeaderField
        public var voltage: PanelHeaderField
        public var mainRating: PanelHeaderField
        public var phases: PanelHeaderField
    }

    public static func extractHeader(from lines: [PanelOCRLine]) -> HeaderGuess {
        var panelName = PanelHeaderField.empty
        var voltage = PanelHeaderField.empty
        var mainRating = PanelHeaderField.empty
        var phases = PanelHeaderField.empty

        for line in lines {
            let upper = line.text.uppercased()
            let confidence = scaled(0.86, line.confidence)

            if !panelName.isPresent, let name = labeledValue(in: upper, keys: ["PANEL ID", "PANEL NO", "PANEL#", "PANEL"]) {
                let token = name.split(separator: " ").first.map(String.init) ?? name
                if !PanelDirectory.looksLikeCircuit(token),
                   token.count >= 2, token.count <= 24,
                   !rejectedPanelNames.contains(token) {
                    panelName = PanelHeaderField(value: token, confidence: confidence)
                }
            }
            if !voltage.isPresent, let raw = labeledValue(in: upper, keys: ["VOLTAGE", "VOLTS", "SYSTEM"]) {
                if parseVoltage(raw) != nil {
                    voltage = PanelHeaderField(value: normalizeVoltage(raw), confidence: confidence)
                }
            }
            if !mainRating.isPresent, let raw = labeledValue(in: upper, keys: ["MAIN RATING", "MAIN", "BUS", "BUS RATING"]) {
                if let amps = parseMainAmps(raw) {
                    mainRating = PanelHeaderField(value: "\(formatAmps(amps))A", confidence: confidence)
                }
            }
            if !phases.isPresent, let raw = labeledValue(in: upper, keys: ["PHASE", "PHASES", "PH"]) {
                if let n = parsePhaseCount(raw) {
                    phases = PanelHeaderField(value: "\(n)", confidence: confidence)
                }
            }

            if !voltage.isPresent, let parsed = firstVoltageToken(in: upper) {
                voltage = PanelHeaderField(value: parsed, confidence: scaled(0.78, line.confidence))
            }
            if !mainRating.isPresent, let amps = firstMainAmps(in: upper) {
                mainRating = PanelHeaderField(value: "\(formatAmps(amps))A", confidence: scaled(0.74, line.confidence))
            }
            if !phases.isPresent, let n = parsePhaseCount(upper), upper.contains("PH") || upper.contains("PHASE") {
                phases = PanelHeaderField(value: "\(n)", confidence: scaled(0.72, line.confidence))
            }
        }

        if !phases.isPresent, let inferred = parseVoltage(voltage.value)?.phases {
            phases = PanelHeaderField(value: "\(inferred)", confidence: min(voltage.confidence, 0.64))
        }

        return HeaderGuess(panelName: panelName, voltage: voltage, mainRating: mainRating, phases: phases)
    }

    // MARK: - Hard-to-read guesses

    public struct GuessedLine: Equatable, Sendable {
        public var text: String
        public var changed: Bool
    }

    /// Rewrites common OCR substitutions on trip/pole tokens and near-miss
    /// directory names. Guessed lines stay lower confidence in extract().
    public static func guessHardToRead(_ line: String) -> GuessedLine {
        let tokens = line.split(separator: " ").map(String.init)
        var changed = false
        var out: [String] = []
        for token in tokens {
            if let trip = guessTripToken(token) {
                if trip != token { changed = true }
                out.append(trip)
                continue
            }
            if let poles = guessPolesToken(token) {
                if poles != token { changed = true }
                out.append(poles)
                continue
            }
            if let name = guessNameToken(token) {
                if name != token { changed = true }
                out.append(name)
                continue
            }
            out.append(token)
        }
        return GuessedLine(text: out.joined(separator: " "), changed: changed)
    }

    public static func guessTripToken(_ token: String) -> String? {
        let mapped = token.uppercased()
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "L", with: "1")
        guard PanelDirectory.looksLikeTrip(mapped) else { return nil }
        return mapped
    }

    public static func guessPolesToken(_ token: String) -> String? {
        let mapped = token.uppercased()
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "L", with: "1")
        guard PanelDirectory.looksLikePoles(mapped) else { return nil }
        return mapped
    }

    public static func guessNameToken(_ token: String) -> String? {
        let upper = token.uppercased()
        guard upper.count >= 4 else { return nil }
        if PanelDirectory.looksLikeCircuit(upper) || PanelDirectory.looksLikeTrip(upper) {
            return nil
        }
        if knownNames.contains(upper) { return token }
        let maxDistance = upper.count <= 6 ? 1 : 2
        var best: (name: String, distance: Int)?
        // First listed name at the minimum distance wins — Set order is not stable.
        for name in knownNameOrder {
            let distance = editDistance(upper, name)
            guard distance > 0, distance <= maxDistance else { continue }
            if best == nil || distance < best!.distance {
                best = (name, distance)
            }
        }
        return best?.name
    }

    // MARK: - Load class

    public static func classifyLoad(_ name: String) -> LoadRowType {
        let upper = name.uppercased()
        if isSpareOrSpace(upper) { return .other }
        if matches(upper, lightingKeys) { return .lighting }
        if matches(upper, receptacleKeys) { return .receptacle }
        if matches(upper, motorKeys) { return .motor }
        if matches(upper, continuousKeys) { return .continuous }
        return .other
    }

    public static func isSpareOrSpace(_ name: String) -> Bool {
        let tokens = name.uppercased().split(whereSeparator: { $0 == " " || $0 == "/" || $0 == "-" }).map(String.init)
        let keys: Set<String> = ["SPARE", "SPACE", "BLANK", "FUTURE", "UNUSED", "EMPTY"]
        return tokens.contains { keys.contains($0) }
    }

    public static func parseTripAmps(_ trip: String) -> Double? {
        var numeric = ""
        for character in trip {
            if character.isNumber || character == "." {
                numeric.append(character)
            } else if !numeric.isEmpty {
                break
            }
        }
        guard let value = Double(numeric), value > 0, value <= 6_000 else { return nil }
        return value
    }

    public static func parseMainAmps(_ raw: String) -> Double? {
        parseTripAmps(raw)
    }

    public struct VoltageGuess: Equatable, Sendable {
        public var lineToNeutral: Double?
        public var lineToLine: Double?
        public var phases: Int?
        public var display: String
    }

    public static func parseVoltage(_ raw: String) -> VoltageGuess? {
        let upper = raw.uppercased().replacingOccurrences(of: " ", with: "")
        let compact = upper.replacingOccurrences(of: "V", with: "")
        if let match = yVoltage(compact) { return match }
        if let slash = slashVoltage(compact) { return slash }
        guard let value = Double(compact), value >= 12, value <= 15_000 else { return nil }
        if value >= 200 && (isThreePhaseVoltage(value) || value >= 380) {
            return VoltageGuess(lineToNeutral: value / sqrt(3), lineToLine: value, phases: 3, display: "\(formatVolts(value))V")
        }
        if value >= 200 {
            return VoltageGuess(lineToNeutral: value / 2, lineToLine: value, phases: 1, display: "\(formatVolts(value))V")
        }
        return VoltageGuess(lineToNeutral: value, lineToLine: nil, phases: 1, display: "\(formatVolts(value))V")
    }

    public static func parsePhaseCount(_ raw: String) -> Int? {
        let upper = raw.uppercased()
        if upper.contains("3") || upper.contains("THREE") { return 3 }
        if upper.contains("1") || upper.contains("SINGLE") { return 1 }
        return nil
    }

    /// Missing poles: 1-pole on 3Ø (typical lighting/receptacle), 2-pole on
    /// 1Ø ≥200 V so split-phase demand is not halved. Explicit 1/2/3 wins.
    public static func poleCount(_ poles: String, phases: Int, voltage: Double = 0) -> Int {
        let trimmed = poles.trimmingCharacters(in: .whitespacesAndNewlines)
        if let n = Int(trimmed), n >= 1, n <= 3 { return n }
        if trimmed.isEmpty, phases == 1, abs(voltage) >= 200 { return 2 }
        return 1
    }

    /// Connected VA from breaker trip. Trip is not measured load — this is a
    /// conservative connected-amp estimate for a 220.42-style demand pass.
    public static func connectedVA(tripAmps: Double, poles: Int, voltage: Double, phases: Int) -> Double {
        let v = abs(voltage)
        if phases == 3 {
            if poles >= 3 { return tripAmps * v * sqrt(3) }
            if poles == 2 { return tripAmps * v }
            return tripAmps * (v / sqrt(3))
        }
        // 1Ø / split-phase: ≥200 V is treated as L-L.
        if v >= 200 {
            return poles >= 2 ? tripAmps * v : tripAmps * (v / 2)
        }
        return poles >= 2 ? tripAmps * v * 2 : tripAmps * v
    }

    // MARK: - Internals

    private static let rejectedPanelNames: Set<String> = [
        "SCHEDULE", "DIRECTORY", "BOARD", "LEGEND", "LABEL", "STICKER",
        "SUMMARY", "RATING", "VOLTAGE", "MAIN",
    ]

    /// SPARE before SPACE so a one-letter miss like SPAPE / SPARF is not a coin flip.
    private static let knownNameOrder: [String] = [
        "LIGHTING", "LIGHTS", "LTG", "RECEPTACLES", "RECEPTACLE", "RECEPT",
        "HVAC", "AHU", "RTU", "SPARE", "SPACE", "EXTERIOR", "GARAGE",
        "KITCHEN", "BATHROOM", "BEDROOM", "DISHWASHER", "DISPOSAL", "DRYER",
        "RANGE", "OVEN", "MICROWAVE", "WASHER", "FREEZER", "REFRIGERATOR",
        "WATER", "HEATER", "EMERGENCY", "EXIT", "SIGN", "FAN", "PUMP",
        "COMPRESSOR", "CHILLER", "BOILER", "ELEVATOR", "CORRIDOR", "LOBBY",
        "OFFICE", "BREAK", "ROOM", "PANEL", "FEED", "CONTACTOR",
    ]
    private static let knownNames = Set(knownNameOrder)

    private static let lightingKeys = [
        "LIGHT", "LIGHTING", "LIGHTS", "LTG", "LITE", "EMERGENCY", "EXIT", "SIGN",
    ]
    private static let receptacleKeys = [
        "RECEPT", "RECEPTACLE", "RECEPTACLES", "OUTLET", "REC", "GFCI",
    ]
    private static let motorKeys = [
        "HVAC", "AHU", "RTU", "MOTOR", "PUMP", "FAN", "COMPRESSOR", "CHILLER",
        "BOILER", "ELEVATOR", "ACU", "MAU", "EF-", "SF-", "RF-",
    ]
    private static let continuousKeys = [
        "WATER HEATER", "WH", "HEAT TAPE", "SNOW", "BASEBOARD", "HEAT TRACE",
        "HW HEATER", "DWH",
    ]

    private static func matches(_ upper: String, _ keys: [String]) -> Bool {
        keys.contains { upper.contains($0) }
    }

    private static func rowBaseConfidence(_ row: PanelCircuit, guessed: Bool) -> Double {
        var base = 0.88
        if row.trip.isEmpty { base = min(base, 0.66) }
        if row.poles.isEmpty { base = min(base, 0.78) }
        if guessed { base *= 0.78 }
        let letters = row.name.filter(\.isLetter).count
        if letters < 3 { base = min(base, 0.60) }
        return base
    }

    private static func labeledValue(in upper: String, keys: [String]) -> String? {
        for key in keys {
            guard let range = upper.range(of: key) else { continue }
            var rest = String(upper[range.upperBound...])
                .trimmingCharacters(in: CharacterSet(charactersIn: " :=-–—#."))
            if rest.isEmpty { continue }
            if let note = rest.range(of: "  ") {
                rest = String(rest[..<note.lowerBound])
            }
            return rest.trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func firstVoltageToken(in upper: String) -> String? {
        let tokens = upper.split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)
        for token in tokens {
            if parseVoltage(token) != nil { return normalizeVoltage(token) }
        }
        return nil
    }

    private static func firstMainAmps(in upper: String) -> Double? {
        guard upper.contains("MCB") || upper.contains("MLO") || upper.contains("MAIN") else {
            return nil
        }
        let tokens = upper.split(separator: " ").map(String.init)
        for token in tokens where PanelDirectory.looksLikeTrip(token) {
            if let amps = parseMainAmps(token), amps >= 60 { return amps }
        }
        return nil
    }

    private static func yVoltage(_ compact: String) -> VoltageGuess? {
        let parts = compact.split(separator: "Y", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2, let ll = Double(parts[0]) else { return nil }
        let lnRaw = parts[1].split(separator: "/").map(String.init)
        let ln = lnRaw.last.flatMap(Double.init)
        guard ll >= 12, ll <= 15_000 else { return nil }
        if let ln, !(ln >= 12 && ln <= 15_000) { return nil }
        return VoltageGuess(
            lineToNeutral: ln ?? ll / sqrt(3),
            lineToLine: ll,
            phases: 3,
            display: ln.map { "\(formatVolts(ll))Y/\(formatVolts($0))V" } ?? "\(formatVolts(ll))Y V"
        )
    }

    private static func slashVoltage(_ compact: String) -> VoltageGuess? {
        let parts = compact.split(separator: "/").compactMap { Double($0) }
        guard parts.count == 2, parts.allSatisfy({ $0 >= 12 && $0 <= 15_000 }) else { return nil }
        let hi = max(parts[0], parts[1])
        let lo = min(parts[0], parts[1])
        let three = abs(hi / lo - sqrt(3)) < 0.15
        return VoltageGuess(
            lineToNeutral: lo,
            lineToLine: hi,
            phases: three ? 3 : 1,
            display: "\(formatVolts(hi))/\(formatVolts(lo))V"
        )
    }

    private static func isThreePhaseVoltage(_ value: Double) -> Bool {
        [208, 220, 380, 400, 415, 480, 600].contains { abs(value - $0) < 2 }
    }

    private static func normalizeVoltage(_ raw: String) -> String {
        parseVoltage(raw)?.display ?? raw.uppercased()
    }

    private static func formatVolts(_ value: Double) -> String {
        value == floor(value) ? String(Int(value)) : String(format: "%.1f", value)
    }

    private static func formatAmps(_ value: Double) -> String {
        value == floor(value) ? String(Int(value)) : String(format: "%.1f", value)
    }

    static func scaled(_ base: Double, _ vision: Double?) -> Double {
        guard let vision else { return min(max(base, 0), 1) }
        return min(max(base * max(vision, 0.15), 0), 1)
    }

    static func editDistance(_ a: String, _ b: String) -> Int {
        if a == b { return 0 }
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        var current = Array(repeating: 0, count: b.count + 1)
        let aChars = Array(a)
        let bChars = Array(b)
        for i in 1...aChars.count {
            current[0] = i
            for j in 1...bChars.count {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + cost
                )
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }
}

public struct PanelDemandResult: Equatable, Sendable {
    public var connectedVA: Double
    public var lightingConnectedVA: Double
    public var lightingDemandVA: Double
    public var otherDemandVA: Double
    public var totalDemandVA: Double
    public var spareVA: Double
    public var grandTotalVA: Double
    public var demandAmps: Double
    public var mainAmps: Double?
    public var capacityToAddAmps: Double?
    public var capacityToAddVA: Double?
    public var utilization: Double?
    public var unusedPositions: Int
    public var circuitsMissingTrip: Int
    public var circuitsInDemand: Int
    public var voltage: Double
    public var phases: Int
    public var occupancy: LoadWorksheetOccupancy
    public var worksheet: LoadWorksheetResult
    public var formula: String
    public var caveats: [String]

    public var copyLine: String {
        var parts = [
            "Demand \(formatVA(totalDemandVA)) VA",
            "\(formatA(demandAmps)) A",
        ]
        if let add = capacityToAddAmps {
            parts.append("capacity to add \(formatA(add)) A")
        }
        return parts.joined(separator: " · ")
    }

    private func formatVA(_ value: Double) -> String {
        String(format: "%.0f", value.rounded())
    }

    private func formatA(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

/// Demand and remaining main capacity from a cleaned schedule.
///
/// Breaker trip is treated as a conservative connected-amp estimate, then
/// run through the same NEC 220.42 worksheet as Load Calculation Worksheet.
/// This is a design aid — not a stamped load calc.
public enum PanelScheduleDemand {
    public static func estimate(
        circuits: [PanelCircuitDraft],
        voltage: Double,
        phases: Int,
        mainAmps: Double?,
        occupancy: LoadWorksheetOccupancy,
        sparePercent: Double = 0
    ) throws -> PanelDemandResult {
        let v = try Positive.require(voltage, name: "Voltage")
        guard phases == 1 || phases == 3 else {
            throw CalcError.outOfRange("Phases must be 1 or 3.")
        }
        if let main = mainAmps {
            _ = try Positive.require(main, name: "Main rating")
        }

        var rows: [LoadWorksheetRow] = []
        var unused = 0
        var missingTrip = 0
        var inDemand = 0

        for circuit in circuits {
            if circuit.isSpareOrSpace {
                unused += 1
                continue
            }
            guard let trip = PanelScheduleParser.parseTripAmps(circuit.trip) else {
                missingTrip += 1
                continue
            }
            let poles = PanelScheduleParser.poleCount(circuit.poles, phases: phases, voltage: v)
            let va = PanelScheduleParser.connectedVA(
                tripAmps: trip,
                poles: poles,
                voltage: v,
                phases: phases
            )
            guard va.isFinite, va >= 0 else { continue }
            inDemand += 1
            rows.append(LoadWorksheetRow(
                description: circuit.name.isEmpty ? "Circuit \(circuit.circuit)" : circuit.name,
                type: circuit.loadClass,
                vaEach: va
            ))
        }

        let worksheet = try LoadWorksheet.calculate(
            rows: rows,
            occupancy: occupancy,
            voltage: v,
            phases: phases,
            sparePercent: sparePercent
        )

        var capacityAmps: Double?
        var capacityVA: Double?
        var utilization: Double?
        if let main = mainAmps, main > 0 {
            capacityAmps = main - worksheet.amps
            let vaPerAmp = phases == 3 ? sqrt(3) * v : v
            capacityVA = capacityAmps.map { $0 * vaPerAmp }
            utilization = worksheet.amps / main
        }

        var caveats = [
            "Breaker trip is not measured load. This treats trip as a conservative connected-amp estimate.",
            "Design aid — not a stamped NEC 220 load calculation or a PE stamp.",
        ]
        if missingTrip > 0 {
            caveats.append("\(missingTrip) circuit\(missingTrip == 1 ? "" : "s") skipped — no trip to convert to VA.")
        }
        if unused > 0 {
            caveats.append("\(unused) spare/space position\(unused == 1 ? "" : "s") excluded from demand.")
        }

        return PanelDemandResult(
            connectedVA: worksheet.connectedVA,
            lightingConnectedVA: worksheet.lightingConnectedVA,
            lightingDemandVA: worksheet.lightingDemandVA,
            otherDemandVA: worksheet.otherDemandVA,
            totalDemandVA: worksheet.totalDemandVA,
            spareVA: worksheet.spareVA,
            grandTotalVA: worksheet.grandTotalVA,
            demandAmps: worksheet.amps,
            mainAmps: mainAmps,
            capacityToAddAmps: capacityAmps,
            capacityToAddVA: capacityVA,
            utilization: utilization,
            unusedPositions: unused,
            circuitsMissingTrip: missingTrip,
            circuitsInDemand: inDemand,
            voltage: v,
            phases: phases,
            occupancy: occupancy,
            worksheet: worksheet,
            formula: "trip → connected VA → Table 220.42 / motor ×1.25 / continuous +25%; remaining A = main − demand A",
            caveats: caveats
        )
    }

    /// Category VA totals for seeding Load Calculation Worksheet.
    public static func categoryTotals(from circuits: [PanelCircuitDraft], voltage: Double, phases: Int) -> [LoadRowType: Double] {
        var totals: [LoadRowType: Double] = [:]
        for circuit in circuits {
            guard !circuit.isSpareOrSpace else { continue }
            guard let trip = PanelScheduleParser.parseTripAmps(circuit.trip) else { continue }
            let poles = PanelScheduleParser.poleCount(circuit.poles, phases: phases, voltage: voltage)
            let va = PanelScheduleParser.connectedVA(
                tripAmps: trip,
                poles: poles,
                voltage: voltage,
                phases: phases
            )
            totals[circuit.loadClass, default: 0] += va
        }
        return totals
    }
}
