import Foundation

/// Stage-4 result: the existing editable schedule plus nameplate reads and a
/// 0…1 scan quality score. OCR stays assistive — nothing here is reviewed
/// until a person confirms it.
public struct PanelScanResult: Equatable, Sendable {
    /// Below this, the panel tool should ask for another photo.
    public static let retakeThreshold = 0.45

    public var lines: [PanelOCRLine]
    public var extraction: PanelScheduleExtraction
    public var quality: Double
    public var promptsRetake: Bool
    public var usedFallback: Bool
    public var didFlatten: Bool

    public init(
        lines: [PanelOCRLine],
        extraction: PanelScheduleExtraction,
        quality: Double,
        promptsRetake: Bool,
        usedFallback: Bool = false,
        didFlatten: Bool = false
    ) {
        self.lines = lines
        self.extraction = extraction
        self.quality = quality
        self.promptsRetake = promptsRetake
        self.usedFallback = usedFallback
        self.didFlatten = didFlatten
    }
}

/// Regex and fuzzy reads on top of `PanelScheduleParser`. Runs
/// `FuzzyPanelGrid` first so the schedule, FLA / kAIC, and the quality score
/// share one cleaned line list.
public enum PanelDataExtractor {
    public static func extract(
        text: String,
        usedFallback: Bool = false,
        didFlatten: Bool = false
    ) -> PanelScanResult {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { PanelOCRLine(text: String($0)) }
            .filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        return extract(lines: lines, usedFallback: usedFallback, didFlatten: didFlatten)
    }

    public static func extract(
        lines: [PanelOCRLine],
        usedFallback: Bool = false,
        didFlatten: Bool = false
    ) -> PanelScanResult {
        let prepared = FuzzyPanelGrid.prepare(lines)
        var extraction = PanelScheduleParser.extract(lines: prepared.lines)
        let fla = readFLA(in: prepared.lines)
        let kaic = readKAIC(in: prepared.lines)
        extraction.fla = fla
        extraction.kaic = kaic
        extraction.inferredSlots = prepared.inferredSlots
        extraction.circuits = extraction.circuits.map { row in
            var next = row
            let key = "\(row.circuit) ".uppercased()
            if prepared.lines.contains(where: { $0.inferredCircuit && $0.text.uppercased().hasPrefix(key) }) {
                next.circuitNumberInferred = true
                next.reviewState = .needsReview
                next.evidence = PanelFieldEvidence(
                    source: .heuristic,
                    method: .inferredOddEven,
                    rawText: row.name,
                    review: .needsReview
                )
            }
            next.slotKind = PanelSlotKind.infer(fromName: next.name, poles: next.poles)
            if next.isLowConfidence || next.guessed { next.reviewState = .needsReview }
            return next
        }
        extraction.voltageNeedsVerify = extraction.voltage.isPresent
        extraction.phasesNeedsVerify = extraction.phases.isPresent
        extraction.coverage = PanelCoverage.from(
            circuits: extraction.circuits,
            expectedSlots: extraction.expectedSlotCount,
            inferredSlots: prepared.inferredSlots
        )

        let quality = score(
            lines: prepared.lines,
            extraction: extraction,
            usedFallback: usedFallback
        )
        extraction.scanQuality = quality

        var notes: [String] = []
        if quality < PanelScanResult.retakeThreshold {
            notes.append("Low scan quality. Retake a flatter photo with less glare. These rows are a draft to edit, not a stamped schedule.")
        }
        if prepared.inferredSlots > 0 {
            notes.append("\(prepared.inferredSlots) circuit number\(prepared.inferredSlots == 1 ? "" : "s") were inferred (odd left, even right) because the print was missing. Check them against the sticker.")
        }
        if fla.isPresent || kaic.isPresent {
            notes.append("FLA and kAIC are reads off the photo, not measured values.")
        }
        if usedFallback {
            notes.append("A second on-device pass ran with language correction off so trade codes were less likely to be rewritten.")
        }
        extraction.scanNotes = notes

        let prompts = quality < PanelScanResult.retakeThreshold
        return PanelScanResult(
            lines: prepared.lines,
            extraction: extraction,
            quality: quality,
            promptsRetake: prompts,
            usedFallback: usedFallback,
            didFlatten: didFlatten
        )
    }

    // MARK: - Nameplate reads

    static func readFLA(in lines: [PanelOCRLine]) -> PanelHeaderField {
        let patterns = [
            #"FULL\s*LOAD\s*AMPS?\s*[:#]?\s*(\d+(?:\.\d+)?(?:\s*/\s*\d+(?:\.\d+)?)?)"#,
            #"\bFLA\b\s*[:#]?\s*(\d+(?:\.\d+)?(?:\s*/\s*\d+(?:\.\d+)?)?)"#,
            #"(\d+(?:\.\d+)?(?:\s*/\s*\d+(?:\.\d+)?)?)\s*A?\s*\bFLA\b"#,
        ]
        return firstMatch(patterns, in: lines, confidence: 0.74)
    }

    static func readKAIC(in lines: [PanelOCRLine]) -> PanelHeaderField {
        let patterns = [
            #"(\d+(?:\.\d+)?)\s*K\s*AIC\b"#,
            #"\bK\s*AIC\b\s*[:#]?\s*(\d+(?:\.\d+)?)"#,
            #"(\d+(?:\.\d+)?)\s*KAIC\b"#,
            #"\bKAIC\b\s*[:#]?\s*(\d+(?:\.\d+)?)"#,
        ]
        guard var field = firstMatch(patterns, in: lines, confidence: 0.72) as PanelHeaderField? else {
            return .empty
        }
        if field.isPresent, !field.value.uppercased().contains("K") {
            field = PanelHeaderField(
                value: "\(field.value) kAIC",
                confidence: field.confidence,
                reviewed: false,
                source: .heuristic
            )
        }
        return field
    }

    // MARK: - Quality

    /// 0…1. Typed text with no Vision confidence is treated as a neutral 0.62
    /// so a clear pasted schedule is not punished like a washed-out photo.
    static func score(
        lines: [PanelOCRLine],
        extraction: PanelScheduleExtraction,
        usedFallback: Bool
    ) -> Double {
        let meaningful = lines.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !meaningful.isEmpty else { return 0 }

        let confidences = meaningful.compactMap(\.confidence)
        let mean = confidences.isEmpty
            ? 0.62
            : confidences.reduce(0, +) / Double(confidences.count)

        var score = 0.42 * mean
        if mean < 0.45 { score -= 0.12 }

        if extraction.circuits.isEmpty {
            score = min(score, 0.28)
        } else {
            let rowMean = extraction.circuits.map(\.confidence).reduce(0, +) / Double(extraction.circuits.count)
            score += 0.28 * rowMean
            let coverage = min(1, Double(extraction.circuits.count) / 4)
            score += 0.18 * coverage
        }
        if extraction.voltage.isPresent { score += 0.06 }
        if extraction.phases.isPresent { score += 0.03 }
        if extraction.mainRating.isPresent { score += 0.03 }
        if extraction.panelName.isPresent { score += 0.02 }
        if extraction.fla.isPresent { score += 0.03 }
        if extraction.kaic.isPresent { score += 0.03 }
        score -= min(0.18, Double(extraction.inferredSlots) * 0.04)
        if usedFallback { score -= 0.04 }
        let guessed = extraction.circuits.filter(\.guessed).count
        if !extraction.circuits.isEmpty {
            score -= min(0.12, (Double(guessed) / Double(extraction.circuits.count)) * 0.12)
        }
        return min(1, max(0, score))
    }

    // MARK: - Internals

    private static func firstMatch(_ patterns: [String], in lines: [PanelOCRLine], confidence: Double) -> PanelHeaderField {
        for line in lines {
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
                let text = line.text
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                guard let match = regex.firstMatch(in: text, options: [], range: range),
                      match.numberOfRanges > 1,
                      let capture = Range(match.range(at: 1), in: text) else { continue }
                let value = text[capture]
                    .replacingOccurrences(of: " ", with: "")
                guard !value.isEmpty else { continue }
                let scaled = PanelScheduleParser.scaled(confidence, line.confidence)
                return PanelHeaderField(value: value, confidence: scaled)
            }
        }
        return .empty
    }
}
