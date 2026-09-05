import Foundation

/// Normalized `/api/analyze-panel` draft. Human confirm is still required.
public struct PanelCloudDraft: Equatable, Sendable {
    public var extraction: PanelScheduleExtraction
    public var rawOCR: String
    public var warnings: [String]
    public var slotCount: Int

    public init(
        extraction: PanelScheduleExtraction,
        rawOCR: String = "",
        warnings: [String] = [],
        slotCount: Int = 0
    ) {
        self.extraction = extraction
        self.rawOCR = rawOCR
        self.warnings = warnings
        self.slotCount = slotCount
    }
}

/// Maps the live panel vision JSON into the editable schedule + header slots.
/// `loadAmps` from the model is ignored — trip is not a reviewed load.
public enum PanelCloudAnalyze {
    public static let agentID = "cloud-vlm"
    public static let maxCircuits = 84

    public static func normalize(_ raw: Any?) -> PanelCloudDraft {
        let envelope = BeckifyVisionAPI.visionDraftInput(raw)
        let rowsIn = (envelope["circuits"] ?? envelope["rows"]) as? [Any] ?? []
        var circuits: [PanelCircuitDraft] = []
        var seen = Set<String>()
        for item in rowsIn.prefix(maxCircuits) {
            guard let circuit = circuit(from: item) else { continue }
            let key = normalizeCircuitKey(circuit.circuit)
            if !key.isEmpty {
                if seen.contains(key) { continue }
                seen.insert(key)
            }
            circuits.append(circuit)
        }
        circuits = sortCircuits(circuits)

        let panel = envelope["panel"] as? [String: Any] ?? [:]
        let panelName = headerField(panel["name"])
        let voltage = headerField(panel["voltage"])
        var main = headerField(panel["mainAmps"] ?? panel["busAmps"] ?? panel["busRating"])
        if main.isPresent, !main.value.uppercased().contains("A") {
            main.value += "A"
        }
        let phases = headerField(panel["phases"], asPhase: true)

        let rawOCR = BeckifyVisionAPI.stringValue(envelope["raw_ocr"] ?? envelope["rawOCR"] ?? envelope["rawText"]) ?? ""
        let warnings = BeckifyVisionAPI.stringList(envelope["warnings"])
        let slotCount = parseSlotCount(envelope["slotCount"] ?? envelope["slot_count"] ?? panel["slotCount"] ?? panel["spaces"])

        let extraction = PanelScheduleExtraction(
            circuits: circuits,
            panelName: panelName,
            voltage: voltage,
            mainRating: main,
            phases: phases,
            rawLines: rawOCR.split(whereSeparator: \.isNewline).map(String.init),
            agentID: agentID,
            leavesDevice: true
        )
        return PanelCloudDraft(
            extraction: extraction,
            rawOCR: rawOCR,
            warnings: warnings,
            slotCount: slotCount
        )
    }

    public static func normalize(jsonData: Data) throws -> PanelCloudDraft {
        let value = try JSONSerialization.jsonObject(with: jsonData)
        return normalize(value)
    }

    public static func normalize(jsonText: String) throws -> PanelCloudDraft {
        guard let data = jsonText.data(using: .utf8) else {
            throw BeckifyVisionAPIError.unreadableJSON
        }
        return try normalize(jsonData: data)
    }

    /// Union by circuit number. Empty slots on the left take values from the right.
    /// Operator-edited (`user`) rows win. Header fills only when the left is blank.
    public static func merge(_ left: PanelScheduleExtraction, _ right: PanelScheduleExtraction) -> PanelScheduleExtraction {
        var byKey: [String: PanelCircuitDraft] = [:]
        var order: [PanelCircuitDraft] = []

        func take(_ row: PanelCircuitDraft) {
            let key = normalizeCircuitKey(row.circuit)
            if key.isEmpty {
                order.append(row)
                return
            }
            var next = row
            next.circuit = key
            if var dest = byKey[key] {
                dest = fillEmpty(dest, from: next)
                byKey[key] = dest
                if let index = order.firstIndex(where: { normalizeCircuitKey($0.circuit) == key }) {
                    order[index] = dest
                }
                return
            }
            byKey[key] = next
            order.append(next)
        }

        left.circuits.forEach(take)
        right.circuits.forEach(take)
        order = sortCircuits(Array(order.prefix(maxCircuits)))

        return PanelScheduleExtraction(
            circuits: order,
            panelName: preferHeader(left.panelName, right.panelName),
            voltage: preferHeader(left.voltage, right.voltage),
            mainRating: preferHeader(left.mainRating, right.mainRating),
            phases: preferHeader(left.phases, right.phases),
            rawLines: [left.rawLines, right.rawLines].flatMap { $0 }.filter { !$0.isEmpty },
            agentID: right.agentID.isEmpty ? left.agentID : right.agentID,
            leavesDevice: left.leavesDevice || right.leavesDevice
        )
    }

    public static func merge(existing: PanelScheduleExtraction?, incoming: PanelScheduleExtraction) -> PanelScheduleExtraction {
        guard let existing else { return incoming }
        return merge(existing, incoming)
    }

    public static func normalizeCircuitKey(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return "" }
        let pattern = #"^0*(\d{1,2})([A-Z])?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return trimmed }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, range: range),
              let numberRange = Range(match.range(at: 1), in: trimmed),
              let number = Int(trimmed[numberRange])
        else { return trimmed }
        var suffix = ""
        if match.range(at: 2).location != NSNotFound, let suffixRange = Range(match.range(at: 2), in: trimmed) {
            suffix = String(trimmed[suffixRange])
        }
        return "\(number)\(suffix)"
    }

    // MARK: - Internals

    private static func circuit(from raw: Any) -> PanelCircuitDraft? {
        let src: [String: Any]
        if let object = raw as? [String: Any] {
            src = (object["fields"] as? [String: Any]) ?? object
        } else {
            return nil
        }
        let rawCircuit = display(src["circuit"]) ?? ""
        let circuit = normalizeCircuitKey(rawCircuit).isEmpty ? rawCircuit : normalizeCircuitKey(rawCircuit)
        var name = display(src["description"] ?? src["name"]) ?? ""
        let notes = display(src["notes"]) ?? ""
        if !notes.isEmpty, notes != name {
            name = name.isEmpty ? notes : "\(name) (\(notes))"
        }
        let trip = formatTrip(src["trip"])
        let poles = formatPoles(src["poles"])
        guard !circuit.isEmpty || !name.isEmpty || !trip.isEmpty || !poles.isEmpty else {
            return nil
        }
        var scores: [Double] = []
        if !circuit.isEmpty { scores.append(BeckifyVisionAPI.unwrapConfidence(src["circuit"])) }
        if !name.isEmpty {
            if src["description"] != nil || src["name"] != nil {
                scores.append(BeckifyVisionAPI.unwrapConfidence(src["description"] ?? src["name"]))
            } else if src["notes"] != nil {
                scores.append(BeckifyVisionAPI.unwrapConfidence(src["notes"]))
            }
        }
        if !trip.isEmpty { scores.append(BeckifyVisionAPI.unwrapConfidence(src["trip"])) }
        if !poles.isEmpty { scores.append(BeckifyVisionAPI.unwrapConfidence(src["poles"])) }
        let confidence = scores.min() ?? BeckifyVisionAPI.unwrapConfidence(nil)
        return PanelCircuitDraft(
            circuit: circuit,
            name: name,
            trip: trip,
            poles: poles,
            loadClass: PanelScheduleParser.classifyLoad(name),
            confidence: confidence,
            source: .vlm
        )
    }

    private static func headerField(_ raw: Any?, asPhase: Bool = false) -> PanelHeaderField {
        let value: String?
        if asPhase {
            value = phaseString(raw)
        } else {
            value = display(raw)
        }
        guard let value, !value.isEmpty else { return .empty }
        return PanelHeaderField(
            value: value,
            confidence: BeckifyVisionAPI.unwrapConfidence(raw),
            source: .vlm
        )
    }

    private static func display(_ raw: Any?) -> String? {
        BeckifyVisionAPI.stringValue(BeckifyVisionAPI.unwrapValue(raw))
    }

    private static func formatTrip(_ raw: Any?) -> String {
        guard let value = BeckifyVisionAPI.unwrapValue(raw) else { return "" }
        if let text = BeckifyVisionAPI.stringValue(value) {
            if text.uppercased().contains("A") { return text.uppercased() }
            if let n = BeckifyVisionAPI.asFiniteDouble(text) {
                return tripNumber(n)
            }
            return text
        }
        if let n = BeckifyVisionAPI.asFiniteDouble(value) {
            return tripNumber(n)
        }
        return ""
    }

    private static func tripNumber(_ n: Double) -> String {
        n == floor(n) ? "\(Int(n))A" : "\(BeckifyVisionAPI.formatNumber(n))A"
    }

    private static func formatPoles(_ raw: Any?) -> String {
        guard let value = BeckifyVisionAPI.unwrapValue(raw) else { return "" }
        if let text = BeckifyVisionAPI.stringValue(value) {
            let folded = text.uppercased().replacingOccurrences(of: " ", with: "")
            if folded.hasSuffix("P"), let n = Int(folded.dropLast()), (1...3).contains(n) {
                return "\(n)"
            }
            if let n = Int(folded), (1...3).contains(n) { return "\(n)" }
        }
        if let n = BeckifyVisionAPI.asFiniteDouble(value) {
            let i = Int(n.rounded())
            if (1...3).contains(i) { return "\(i)" }
        }
        return ""
    }

    private static func phaseString(_ raw: Any?) -> String? {
        if let text = display(raw) {
            let folded = text.uppercased().replacingOccurrences(of: " ", with: "")
            if folded.contains("3") || folded.contains("THREE") { return "3" }
            if folded.contains("1") || folded.contains("SINGLE") { return "1" }
        }
        guard let n = BeckifyVisionAPI.asFiniteDouble(BeckifyVisionAPI.unwrapValue(raw)) else { return nil }
        let i = Int(n.rounded())
        return i == 1 || i == 3 ? "\(i)" : nil
    }

    private static func parseSlotCount(_ raw: Any?) -> Int {
        let value = BeckifyVisionAPI.unwrapValue(raw) ?? raw
        guard let n = BeckifyVisionAPI.asFiniteDouble(value) else { return 0 }
        let rounded = Int(n.rounded())
        guard rounded >= 6 else { return 0 }
        return min(maxCircuits, rounded)
    }

    private static func preferHeader(_ left: PanelHeaderField, _ right: PanelHeaderField) -> PanelHeaderField {
        if left.source == .user, left.isPresent { return left }
        if left.isPresent { return left }
        return right
    }

    private static func fillEmpty(_ dest: PanelCircuitDraft, from incoming: PanelCircuitDraft) -> PanelCircuitDraft {
        if dest.source == .user { return dest }
        var next = dest
        if next.name.isEmpty { next.name = incoming.name }
        if next.trip.isEmpty { next.trip = incoming.trip }
        if next.poles.isEmpty { next.poles = incoming.poles }
        if next.loadClass == .other, incoming.loadClass != .other {
            next.loadClass = incoming.loadClass
        }
        next.confidence = min(next.confidence, incoming.confidence)
        if incoming.source == .vlm { next.source = .vlm }
        return next
    }

    private static func sortCircuits(_ rows: [PanelCircuitDraft]) -> [PanelCircuitDraft] {
        rows.sorted { lhs, rhs in
            let left = circuitSortNumber(lhs.circuit)
            let right = circuitSortNumber(rhs.circuit)
            if left != right { return left < right }
            return normalizeCircuitKey(lhs.circuit) < normalizeCircuitKey(rhs.circuit)
        }
    }

    private static func circuitSortNumber(_ raw: String) -> Int {
        let key = normalizeCircuitKey(raw)
        let digits = key.prefix { $0.isNumber }
        return Int(digits) ?? Int.max
    }
}
