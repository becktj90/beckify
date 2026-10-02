import Foundation

// MARK: - Review / evidence (not calibrated %)

public enum PanelFieldReviewState: String, Codable, Sendable, CaseIterable {
    case needsReview = "needs_review"
    case conflict
    case verified

    public var label: String {
        switch self {
        case .needsReview: return "Needs review"
        case .conflict: return "Conflict"
        case .verified: return "Verified"
        }
    }
}

public enum PanelEvidenceMethod: String, Codable, Sendable {
    case visionOCR = "vision_ocr"
    case heuristicParse = "heuristic_parse"
    case fuzzyCleanup = "fuzzy_cleanup"
    case inferredOddEven = "inferred_odd_even"
    case cloudVLM = "cloud_vlm"
    case userEdit = "user_edit"
    case defaultAssumption = "default_assumption"
}

public struct PanelFieldEvidence: Equatable, Sendable, Codable {
    public var source: PanelFieldSource
    public var method: PanelEvidenceMethod
    public var rawText: String?
    public var crop: PanelOCRBox?
    public var review: PanelFieldReviewState
    public var photoIndex: Int?

    public init(
        source: PanelFieldSource = .heuristic,
        method: PanelEvidenceMethod = .heuristicParse,
        rawText: String? = nil,
        crop: PanelOCRBox? = nil,
        review: PanelFieldReviewState = .needsReview,
        photoIndex: Int? = nil
    ) {
        self.source = source
        self.method = method
        self.rawText = rawText
        self.crop = crop
        self.review = review
        self.photoIndex = photoIndex
    }
}

public enum PanelPhotoRole: String, Codable, Sendable, CaseIterable {
    case directory, nameplate, deadfront

    public var label: String {
        switch self {
        case .directory: return "Directory"
        case .nameplate: return "Nameplate"
        case .deadfront: return "Deadfront"
        }
    }

    public var guidance: String {
        switch self {
        case .directory:
            return "Fill the frame with the closed-door directory card. Crop glare sleeves. Rotate so circuit 1 is at the top. Partial cards are OK — do not invent missing rows."
        case .nameplate:
            return "Square the main/bus/nameplate. Lift glare. Voltage and phase here are reads to verify — not silent defaults."
        case .deadfront:
            return "Cover-on deadfront only. Count visible spaces; tandems count as two. Do not invent missing handles."
        }
    }
}

public enum PanelSlotKind: String, Codable, Sendable, CaseIterable {
    case circuit, spare, space, unreadable
    case notPhotographed = "not_photographed"
    case tandem

    public static func infer(fromName name: String, poles: String = "") -> PanelSlotKind {
        let upper = name.uppercased()
        if upper.contains("SPARE") { return .spare }
        if upper.contains("SPACE") || upper == "BLANK" { return .space }
        if upper.contains("UNREAD") || upper.contains("ILLEGIBLE") { return .unreadable }
        if upper.contains("NOT PHOTO") || upper.contains("NOT IN FRAME") { return .notPhotographed }
        return name.trimmingCharacters(in: .whitespaces).isEmpty ? .unreadable : .circuit
    }
}

public struct PanelCoverage: Equatable, Sendable, Codable {
    public var expectedSlots: Int?
    public var photographedSlots: Int
    public var readableSlots: Int
    public var inferredCircuitNumbers: Int
    public var unreadableSlots: Int
    public var notPhotographedSlots: Int
    public var notes: [String]

    public init(
        expectedSlots: Int? = nil,
        photographedSlots: Int = 0,
        readableSlots: Int = 0,
        inferredCircuitNumbers: Int = 0,
        unreadableSlots: Int = 0,
        notPhotographedSlots: Int = 0,
        notes: [String] = []
    ) {
        self.expectedSlots = expectedSlots
        self.photographedSlots = photographedSlots
        self.readableSlots = readableSlots
        self.inferredCircuitNumbers = inferredCircuitNumbers
        self.unreadableSlots = unreadableSlots
        self.notPhotographedSlots = notPhotographedSlots
        self.notes = notes
    }

    public var isComplete: Bool {
        guard let expected = expectedSlots, expected > 0 else {
            return notPhotographedSlots == 0 && unreadableSlots == 0
        }
        return readableSlots + unreadableSlots >= expected && notPhotographedSlots == 0
    }

    public var summaryLine: String {
        var parts: [String] = []
        if let expected = expectedSlots, expected > 0 {
            parts.append("Coverage \(readableSlots)/\(expected) readable")
        } else {
            parts.append("Coverage \(readableSlots) readable (expected slot count unknown)")
        }
        if inferredCircuitNumbers > 0 { parts.append("\(inferredCircuitNumbers) circuit # inferred") }
        if unreadableSlots > 0 { parts.append("\(unreadableSlots) unreadable") }
        if notPhotographedSlots > 0 { parts.append("\(notPhotographedSlots) not photographed") }
        if !isComplete { parts.append("incomplete") }
        return parts.joined(separator: " · ")
    }

    public static func from(circuits: [PanelCircuitDraft], expectedSlots: Int?, inferredSlots: Int) -> PanelCoverage {
        var readable = 0, unreadable = 0, notPhoto = 0
        for row in circuits {
            switch row.slotKind {
            case .unreadable: unreadable += 1
            case .notPhotographed: notPhoto += 1
            default: readable += 1
            }
        }
        var notes: [String] = []
        if let expected = expectedSlots, expected > readable + unreadable {
            let missing = expected - readable - unreadable
            notes.append("\(missing) slot\(missing == 1 ? "" : "s") not in these photos.")
        }
        if inferredSlots > 0 {
            notes.append("\(inferredSlots) circuit number\(inferredSlots == 1 ? "" : "s") were inferred (odd left / even right), not read.")
        }
        if expectedSlots == nil {
            notes.append("Expected space/circuit count not printed or not photographed — coverage is incomplete until you set it.")
        }
        return PanelCoverage(
            expectedSlots: expectedSlots,
            photographedSlots: readable + unreadable,
            readableSlots: readable,
            inferredCircuitNumbers: inferredSlots,
            unreadableSlots: unreadable,
            notPhotographedSlots: max(0, notPhoto),
            notes: notes
        )
    }
}

public struct PanelFieldConflict: Equatable, Sendable, Identifiable, Codable {
    public var id: String
    public var circuitKey: String
    public var field: String
    public var existingValue: String
    public var incomingValue: String
    public var existingSource: PanelFieldSource
    public var incomingSource: PanelFieldSource
    public var resolvedValue: String?
    public var resolvedByUser: Bool

    public init(
        id: String = UUID().uuidString,
        circuitKey: String,
        field: String,
        existingValue: String,
        incomingValue: String,
        existingSource: PanelFieldSource,
        incomingSource: PanelFieldSource,
        resolvedValue: String? = nil,
        resolvedByUser: Bool = false
    ) {
        self.id = id
        self.circuitKey = circuitKey
        self.field = field
        self.existingValue = existingValue
        self.incomingValue = incomingValue
        self.existingSource = existingSource
        self.incomingSource = incomingSource
        self.resolvedValue = resolvedValue
        self.resolvedByUser = resolvedByUser
    }

    public var isOpen: Bool { resolvedValue == nil && !resolvedByUser }
    public var label: String {
        "Ckt \(circuitKey.isEmpty ? "—" : circuitKey) \(field): “\(existingValue)” vs “\(incomingValue)”"
    }
}

public struct PanelMergeResult: Equatable, Sendable {
    public var extraction: PanelScheduleExtraction
    public var conflicts: [PanelFieldConflict]
    public init(extraction: PanelScheduleExtraction, conflicts: [PanelFieldConflict] = []) {
        self.extraction = extraction
        self.conflicts = conflicts
    }
    public var openConflictCount: Int { conflicts.filter(\.isOpen).count }
}

public enum PanelConflictMerge {
    public static func merge(_ left: PanelScheduleExtraction, _ right: PanelScheduleExtraction) -> PanelMergeResult {
        var byKey: [String: PanelCircuitDraft] = [:]
        var order: [PanelCircuitDraft] = []
        var conflicts: [PanelFieldConflict] = []

        func take(_ row: PanelCircuitDraft) {
            let key = PanelCloudAnalyze.normalizeCircuitKey(row.circuit)
            if key.isEmpty { order.append(row); return }
            var next = row
            next.circuit = key
            if let dest = byKey[key] {
                let merged = mergeRow(dest, next, key: key, conflicts: &conflicts)
                byKey[key] = merged
                if let index = order.firstIndex(where: { PanelCloudAnalyze.normalizeCircuitKey($0.circuit) == key }) {
                    order[index] = merged
                }
                return
            }
            byKey[key] = next
            order.append(next)
        }

        left.circuits.forEach(take)
        right.circuits.forEach(take)
        order = Array(order.prefix(PanelCloudAnalyze.maxCircuits)).sorted {
            circuitSort($0.circuit) < circuitSort($1.circuit)
        }

        var headerConflicts: [PanelFieldConflict] = []
        let panelName = mergeHeader(left.panelName, right.panelName, field: "panelName", conflicts: &headerConflicts)
        let voltage = mergeHeader(left.voltage, right.voltage, field: "voltage", conflicts: &headerConflicts)
        let mainRating = mergeHeader(left.mainRating, right.mainRating, field: "mainRating", conflicts: &headerConflicts)
        let busRating = mergeHeader(left.busRating, right.busRating, field: "busRating", conflicts: &headerConflicts)
        let feederRating = mergeHeader(left.feederRating, right.feederRating, field: "feederRating", conflicts: &headerConflicts)
        let phases = mergeHeader(left.phases, right.phases, field: "phases", conflicts: &headerConflicts)

        var extraction = PanelScheduleExtraction(
            circuits: order,
            panelName: panelName,
            voltage: voltage,
            mainRating: mainRating,
            phases: phases,
            rawLines: [left.rawLines, right.rawLines].flatMap { $0 }.filter { !$0.isEmpty },
            agentID: right.agentID.isEmpty ? left.agentID : right.agentID,
            leavesDevice: left.leavesDevice || right.leavesDevice,
            scanQuality: left.scanQuality ?? right.scanQuality,
            fla: preferPresent(left.fla, right.fla),
            kaic: preferPresent(left.kaic, right.kaic),
            inferredSlots: left.inferredSlots + right.inferredSlots,
            scanNotes: left.scanNotes + right.scanNotes,
            busRating: busRating,
            feederRating: feederRating,
            spacesCount: left.spacesCount ?? right.spacesCount,
            expectedSlotCount: left.expectedSlotCount ?? right.expectedSlotCount,
            voltageNeedsVerify: left.voltageNeedsVerify || right.voltageNeedsVerify || voltage.isPresent,
            phasesNeedsVerify: left.phasesNeedsVerify || right.phasesNeedsVerify || phases.isPresent
        )
        let allConflicts = conflicts + headerConflicts
        extraction.conflicts = allConflicts
        extraction.coverage = PanelCoverage.from(
            circuits: extraction.circuits,
            expectedSlots: extraction.expectedSlotCount ?? extraction.spacesCount,
            inferredSlots: extraction.inferredSlots
        )
        return PanelMergeResult(extraction: extraction, conflicts: allConflicts)
    }

    public static func merge(existing: PanelScheduleExtraction?, incoming: PanelScheduleExtraction) -> PanelMergeResult {
        guard let existing else { return PanelMergeResult(extraction: incoming, conflicts: incoming.conflicts) }
        return merge(existing, incoming)
    }

    private static func mergeRow(
        _ dest: PanelCircuitDraft,
        _ incoming: PanelCircuitDraft,
        key: String,
        conflicts: inout [PanelFieldConflict]
    ) -> PanelCircuitDraft {
        if dest.source == .user { return dest }
        var next = dest
        func field(_ name: String, current: String, other: String, currentSource: PanelFieldSource, otherSource: PanelFieldSource) -> String {
            let a = current.trimmingCharacters(in: .whitespacesAndNewlines)
            let b = other.trimmingCharacters(in: .whitespacesAndNewlines)
            if a.isEmpty { return b }
            if b.isEmpty || a.caseInsensitiveCompare(b) == .orderedSame { return a }
            conflicts.append(PanelFieldConflict(
                circuitKey: key, field: name,
                existingValue: a, incomingValue: b,
                existingSource: currentSource, incomingSource: otherSource
            ))
            next.reviewState = .conflict
            return a
        }
        next.name = field("name", current: next.name, other: incoming.name, currentSource: next.source, otherSource: incoming.source)
        next.trip = field("trip", current: next.trip, other: incoming.trip, currentSource: next.source, otherSource: incoming.source)
        next.poles = field("poles", current: next.poles, other: incoming.poles, currentSource: next.source, otherSource: incoming.source)
        if next.loadClass == .other, incoming.loadClass != .other { next.loadClass = incoming.loadClass }
        next.confidence = min(next.confidence, incoming.confidence)
        if incoming.source == .vlm { next.source = .vlm }
        if next.reviewState != .conflict, next.isLowConfidence || next.circuitNumberInferred || next.guessed {
            next.reviewState = .needsReview
        }
        next.slotKind = PanelSlotKind.infer(fromName: next.name, poles: next.poles)
        return next
    }

    private static func mergeHeader(
        _ left: PanelHeaderField, _ right: PanelHeaderField, field: String,
        conflicts: inout [PanelFieldConflict]
    ) -> PanelHeaderField {
        if left.source == .user, left.isPresent { return left }
        if !left.isPresent { return right }
        if !right.isPresent { return left }
        if left.value.caseInsensitiveCompare(right.value) == .orderedSame { return left }
        conflicts.append(PanelFieldConflict(
            circuitKey: "", field: field,
            existingValue: left.value, incomingValue: right.value,
            existingSource: left.source, incomingSource: right.source
        ))
        var flagged = left
        flagged.review = .conflict
        return flagged
    }

    private static func preferPresent(_ left: PanelHeaderField, _ right: PanelHeaderField) -> PanelHeaderField {
        if left.source == .user, left.isPresent { return left }
        if left.isPresent { return left }
        return right
    }

    private static func circuitSort(_ raw: String) -> (Int, String) {
        let key = PanelCloudAnalyze.normalizeCircuitKey(raw)
        let digits = key.prefix { $0.isNumber }
        return (Int(digits) ?? Int.max, key)
    }
}

public struct PanelPoleGroup: Equatable, Sendable, Identifiable {
    public var id: String
    public var circuitKeys: [String]
    public var poles: Int
    public var name: String
    public var trip: String
    public init(id: String = UUID().uuidString, circuitKeys: [String], poles: Int, name: String, trip: String) {
        self.id = id; self.circuitKeys = circuitKeys; self.poles = poles; self.name = name; self.trip = trip
    }
}

public enum PanelPoleGrouping {
    public static func groups(from circuits: [PanelCircuitDraft]) -> [PanelPoleGroup] {
        var result: [PanelPoleGroup] = []
        var consumed = Set<String>()
        let sorted = circuits.sorted {
            (Int($0.circuit.prefix { $0.isNumber }) ?? Int.max) < (Int($1.circuit.prefix { $0.isNumber }) ?? Int.max)
        }
        for row in sorted {
            let key = PanelCloudAnalyze.normalizeCircuitKey(row.circuit)
            if key.isEmpty || consumed.contains(key) { continue }
            let poles = Int(row.poles.filter(\.isNumber)) ?? 1
            if poles <= 1 || key.last?.isLetter == true {
                consumed.insert(key)
                result.append(PanelPoleGroup(circuitKeys: [key], poles: max(1, poles), name: row.name, trip: row.trip))
                continue
            }
            guard let start = Int(key) else {
                consumed.insert(key)
                result.append(PanelPoleGroup(circuitKeys: [key], poles: 1, name: row.name, trip: row.trip))
                continue
            }
            var keys = [key]
            consumed.insert(key)
            if poles >= 2 {
                for offset in 1..<poles {
                    let sibling = "\(start + offset)"
                    if sorted.contains(where: {
                        PanelCloudAnalyze.normalizeCircuitKey($0.circuit) == sibling
                            && ($0.name.isEmpty || $0.name.caseInsensitiveCompare(row.name) == .orderedSame)
                    }) {
                        keys.append(sibling)
                        consumed.insert(sibling)
                    }
                }
            }
            result.append(PanelPoleGroup(circuitKeys: keys, poles: poles, name: row.name, trip: row.trip))
        }
        return result
    }
}

public enum PanelDemandScenario: String, Codable, Sendable {
    case tripAsConservativeConnected = "trip_as_conservative_connected"
    case measuredOrEnteredLoads = "measured_or_entered_loads"

    public var label: String {
        switch self {
        case .tripAsConservativeConnected:
            return "Scenario: trip as conservative connected (not measured load)"
        case .measuredOrEnteredLoads:
            return "Scenario: entered / measured loads"
        }
    }
}

public struct PanelDemandPresentation: Equatable, Sendable {
    public var scenario: PanelDemandScenario
    public var result: PanelDemandResult
    public var coverage: PanelCoverage
    public var showsCapacityToAdd: Bool
    public var capacityWithheldReason: String?

    public init(
        scenario: PanelDemandScenario,
        result: PanelDemandResult,
        coverage: PanelCoverage,
        showsCapacityToAdd: Bool,
        capacityWithheldReason: String? = nil
    ) {
        self.scenario = scenario
        self.result = result
        self.coverage = coverage
        self.showsCapacityToAdd = showsCapacityToAdd
        self.capacityWithheldReason = capacityWithheldReason
    }

    public var copyLine: String {
        var parts = [scenario.label, "Demand \(Int(result.totalDemandVA.rounded())) VA", String(format: "%.1f A", result.demandAmps)]
        if showsCapacityToAdd, let add = result.capacityToAddAmps {
            parts.append(String(format: "remaining main %.1f A (not OCR capacity)", add))
        } else if let reason = capacityWithheldReason {
            parts.append(reason)
        }
        if !coverage.isComplete { parts.append(coverage.summaryLine) }
        return parts.joined(separator: " · ")
    }
}

public enum PanelDemandAnalysis {
    public static func present(
        result: PanelDemandResult,
        coverage: PanelCoverage,
        scenario: PanelDemandScenario = .tripAsConservativeConnected
    ) -> PanelDemandPresentation {
        switch scenario {
        case .tripAsConservativeConnected:
            return PanelDemandPresentation(
                scenario: scenario, result: result, coverage: coverage,
                showsCapacityToAdd: false,
                capacityWithheldReason: "No capacity-to-add from trips alone"
            )
        case .measuredOrEnteredLoads:
            let show = coverage.isComplete && result.capacityToAddAmps != nil
            return PanelDemandPresentation(
                scenario: scenario, result: result, coverage: coverage,
                showsCapacityToAdd: show,
                capacityWithheldReason: show ? nil : (coverage.isComplete
                    ? "Remaining main needs a confirmed main rating"
                    : "Incomplete coverage — remaining main withheld")
            )
        }
    }
}

public enum PanelHandoffMode: String, Codable, Sendable { case replace, merge }

public struct PanelWorksheetHandoffPreview: Equatable, Sendable {
    public var mode: PanelHandoffMode
    public var totals: [LoadRowType: Double]
    public var existing: [LoadRowType: Double]
    public var merged: [LoadRowType: Double]
    public var voltage: Double
    public var phases: Int
    public var occupancy: LoadWorksheetOccupancy
    public var provenance: [String]
    public var coverage: PanelCoverage

    public init(
        mode: PanelHandoffMode, totals: [LoadRowType: Double], existing: [LoadRowType: Double],
        merged: [LoadRowType: Double], voltage: Double, phases: Int, occupancy: LoadWorksheetOccupancy,
        provenance: [String], coverage: PanelCoverage
    ) {
        self.mode = mode; self.totals = totals; self.existing = existing; self.merged = merged
        self.voltage = voltage; self.phases = phases; self.occupancy = occupancy
        self.provenance = provenance; self.coverage = coverage
    }

    public var summaryLines: [String] {
        let keys: [LoadRowType] = [.lighting, .receptacle, .continuous, .motor, .other]
        let source = mode == .replace ? totals : merged
        return keys.compactMap { key in
            let value = source[key] ?? 0
            guard value > 0 else { return nil }
            return "\(key.label): \(Int(value.rounded())) VA"
        }
    }
}

public enum PanelWorksheetHandoff {
    public static func preview(
        circuits: [PanelCircuitDraft], voltage: Double, phases: Int,
        occupancy: LoadWorksheetOccupancy, mode: PanelHandoffMode,
        existing: [LoadRowType: Double] = [:], coverage: PanelCoverage = PanelCoverage(),
        confirmed: Bool, agentID: String
    ) -> PanelWorksheetHandoffPreview {
        let totals = PanelScheduleDemand.categoryTotals(from: circuits, voltage: voltage, phases: phases)
        var merged = existing
        for (key, value) in totals { merged[key, default: 0] += value }
        var provenance = [
            "Source: Panel Directory (\(agentID))",
            confirmed ? "Schedule confirmed by operator" : "Schedule NOT confirmed — draft only",
            "VA from breaker trip as conservative connected — not measured load",
            "Handoff mode: \(mode.rawValue)",
            coverage.summaryLine,
        ]
        provenance.append(contentsOf: coverage.notes)
        provenance.append("Not a stamped NEC 220 load calc or available-capacity claim from OCR.")
        return PanelWorksheetHandoffPreview(
            mode: mode, totals: totals, existing: existing, merged: merged,
            voltage: voltage, phases: phases, occupancy: occupancy,
            provenance: provenance, coverage: coverage
        )
    }

    public static func values(for preview: PanelWorksheetHandoffPreview) -> [LoadRowType: Double] {
        preview.mode == .replace ? preview.totals : preview.merged
    }
}

public enum PanelReviewFilter: String, CaseIterable, Sendable {
    case all, needsReview, conflict, verified

    public var label: String {
        switch self {
        case .all: return "All"
        case .needsReview: return "Needs review"
        case .conflict: return "Conflict"
        case .verified: return "Verified"
        }
    }

    public func includes(_ row: PanelCircuitDraft) -> Bool {
        switch self {
        case .all: return true
        case .needsReview: return row.reviewState == .needsReview || row.isLowConfidence || row.circuitNumberInferred
        case .conflict: return row.reviewState == .conflict
        case .verified: return row.reviewState == .verified || row.reviewed
        }
    }
}
