import BeckifyMath
import UIKit
import Vision

/// Multi-pass on-device `VNRecognizeTextRequest`. The primary pass uses
/// accurate recognition, language correction, and electrical custom words.
/// A second pass turns language correction off and picks among
/// `topCandidates(3)` when confidence is low, circuit numbers are missing,
/// or a trade code survived only as an alternate (`BKR-3A` and similar).
///
/// Nothing leaves the device. Callers stay on the existing panel and
/// nameplate tools — this is not a second product path.
enum ResilientOCREngine {
    enum Profile: Sendable {
        case panel
        case nameplate
    }

    struct Result: Sendable {
        var lines: [PanelOCRLine]
        var usedFallback: Bool
        var meanConfidence: Double
        var didFlatten: Bool
    }

    enum Failure: Error {
        case unreadableImage
    }

    static let panelWords: [String] = [
        "208Y/120", "480Y/277", "120/240", "240/120",
        "FLA", "LRA", "kAIC", "KAIC", "NEMA", "VAC", "VDC",
        "CCT", "MAIN", "BREAKER", "DISCONNECT", "TRANSFORMER",
        "MTR", "REC", "A/C", "BKR", "AHU", "RTU", "GFCI", "MCB", "MLO",
        "SPARE", "SPACE", "PANEL", "VOLTAGE", "PHASE", "HVAC", "LTG",
    ]

    static let nameplateWords: [String] = [
        "FLA", "LRA", "SFA", "SF", "NEMA", "HP", "RPM", "HZ",
        "VAC", "VDC", "kAIC", "KAIC", "FRAME", "AMB", "EFF", "CODE",
        "PH", "INS", "DUTY",
    ]

    static func recognize(_ image: UIImage, profile: Profile = .panel) async throws -> Result {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try recognizeSync(image, profile: profile)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Passes

    private static func recognizeSync(_ image: UIImage, profile: Profile) throws -> Result {
        let sanitized = ImageSanitizer.sanitize(image)
        let cgImage = sanitized?.cgImage ?? image.cgImage
        let orientation = sanitized?.orientation ?? ImageSanitizer.cgImageOrientation(from: image.imageOrientation)
        guard let cgImage else { throw Failure.unreadableImage }

        let words = profile == .panel ? panelWords : nameplateWords
        let primary = try pass(
            cgImage: cgImage,
            orientation: orientation,
            languageCorrection: true,
            customWords: words,
            preferCodes: false
        )

        var lines = primary
        var usedFallback = false
        if needsFallback(primary, profile: profile) {
            let fallback = try pass(
                cgImage: cgImage,
                orientation: orientation,
                languageCorrection: false,
                customWords: words,
                preferCodes: true
            )
            let merged = merge(primary: primary, fallback: fallback, profile: profile)
            lines = merged.lines
            usedFallback = merged.adoptedFallback
        }

        let confidences = lines.compactMap(\.confidence)
        let mean = confidences.isEmpty ? 0 : confidences.reduce(0, +) / Double(confidences.count)
        return Result(
            lines: lines,
            usedFallback: usedFallback,
            meanConfidence: mean,
            didFlatten: sanitized?.didFlatten ?? false
        )
    }

    private static func pass(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation,
        languageCorrection: Bool,
        customWords: [String],
        preferCodes: Bool
    ) throws -> [PanelOCRLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = languageCorrection
        request.customWords = customWords
        request.recognitionLanguages = ["en-US"]
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try handler.perform([request])
        let observations = request.results ?? []
        return observations.compactMap { observation in
            let candidates = observation.topCandidates(3)
            guard let chosen = preferCodes ? pickCode(candidates) : candidates.first else { return nil }
            let rect = observation.boundingBox
            let alternates = candidates.map(\.string).filter { $0 != chosen.string }
            return PanelOCRLine(
                text: chosen.string,
                confidence: Double(chosen.confidence),
                box: PanelOCRBox(
                    x: rect.origin.x,
                    y: rect.origin.y,
                    width: rect.size.width,
                    height: rect.size.height
                ),
                alternates: alternates
            )
        }
    }

    /// Fallback candidate choice. A lower-confidence string that still looks
    /// like a trade code beats a dictionary rewrite of that code.
    static func pickCode(_ candidates: [VNRecognizedText]) -> VNRecognizedText? {
        guard !candidates.isEmpty else { return nil }
        return candidates.max { lhs, rhs in
            score(lhs.string, confidence: lhs.confidence) < score(rhs.string, confidence: rhs.confidence)
        }
    }

    static func score(_ text: String, confidence: Float) -> Double {
        var value = Double(confidence)
        if looksLikeTradeCode(text) { value += 0.35 }
        if lineLooksLikeCircuitRow(text) { value += 0.2 }
        let upper = text.uppercased()
        if upper.contains("FLA") || upper.contains("KAIC") || upper.contains("K AIC") { value += 0.15 }
        if upper.contains("A/C") || upper.contains("VAC") || upper.contains("NEMA") { value += 0.05 }
        return value
    }

    static func needsFallback(_ lines: [PanelOCRLine], profile: Profile) -> Bool {
        if lines.isEmpty { return true }
        let confidences = lines.compactMap(\.confidence)
        let mean = confidences.isEmpty ? 0 : confidences.reduce(0, +) / Double(confidences.count)
        if mean < 0.55 { return true }
        if profile == .panel && !lines.contains(where: { lineLooksLikeCircuitRow($0.text) }) { return true }
        return lines.contains { line in
            line.alternates.contains { looksLikeTradeCode($0) && !looksLikeTradeCode(line.text) }
        }
    }

    static func lineLooksLikeCircuitRow(_ text: String) -> Bool {
        let tokens = text.uppercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard let first = tokens.first, tokens.count >= 2 else { return false }
        let bareNumber = first.allSatisfy(\.isNumber)
        let numberPlusLetter = first.dropLast().allSatisfy(\.isNumber)
            && first.last?.isLetter == true
            && !first.hasSuffix("A")
        guard bareNumber || numberPlusLetter else { return false }
        guard let value = Int(first.prefix(while: \.isNumber)), value >= 1, value <= 84 else { return false }
        return true
    }

    static func looksLikeTradeCode(_ text: String) -> Bool {
        let upper = text.uppercased()
        if upper.range(of: #"\b[A-Z]{2,5}-?\d+[A-Z0-9]*\b"#, options: .regularExpression) != nil {
            return true
        }
        if upper.range(of: #"\b\d{2,3}Y/\d{2,3}\b"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    // MARK: - Merge

    private static func merge(
        primary: [PanelOCRLine],
        fallback: [PanelOCRLine],
        profile: Profile
    ) -> (lines: [PanelOCRLine], adoptedFallback: Bool) {
        if fallback.isEmpty { return (primary, false) }
        if primary.isEmpty { return (fallback, true) }

        if profile == .panel {
            let primaryRows = primary.filter { lineLooksLikeCircuitRow($0.text) }.count
            let fallbackRows = fallback.filter { lineLooksLikeCircuitRow($0.text) }.count
            if primaryRows == 0, fallbackRows > 0 {
                return (fallback, true)
            }
        }

        var adopted = false
        var used = Set<Int>()
        var merged: [PanelOCRLine] = []
        for line in primary {
            guard let match = bestOverlap(for: line, in: fallback, used: &used) else {
                merged.append(line)
                continue
            }
            let chosen = choose(primary: line, fallback: match)
            if chosen.text != line.text { adopted = true }
            merged.append(chosen)
        }
        return (merged, adopted)
    }

    private static func choose(primary: PanelOCRLine, fallback: PanelOCRLine) -> PanelOCRLine {
        let primaryCode = looksLikeTradeCode(primary.text)
        let fallbackCode = looksLikeTradeCode(fallback.text)
        if fallbackCode && !primaryCode {
            var copy = fallback
            if !copy.alternates.contains(primary.text) {
                copy.alternates.insert(primary.text, at: 0)
            }
            return copy
        }
        if primaryCode && !fallbackCode {
            return primary
        }
        if let fallbackConfidence = fallback.confidence,
           let primaryConfidence = primary.confidence,
           fallbackConfidence > primaryConfidence + 0.08,
           primaryConfidence < 0.62 {
            return fallback
        }
        return primary
    }

    private static func bestOverlap(
        for line: PanelOCRLine,
        in lines: [PanelOCRLine],
        used: inout Set<Int>
    ) -> PanelOCRLine? {
        guard let box = line.box else { return nil }
        var bestIndex: Int?
        var best = 0.25
        for (index, candidate) in lines.enumerated() where !used.contains(index) {
            guard let other = candidate.box else { continue }
            let overlap = iou(box, other)
            if overlap > best {
                best = overlap
                bestIndex = index
            }
        }
        guard let bestIndex else { return nil }
        used.insert(bestIndex)
        return lines[bestIndex]
    }

    private static func iou(_ a: PanelOCRBox, _ b: PanelOCRBox) -> Double {
        let intersectionW = max(0, min(a.x + a.width, b.x + b.width) - max(a.x, b.x))
        let intersectionH = max(0, min(a.y + a.height, b.y + b.height) - max(a.y, b.y))
        let intersection = intersectionW * intersectionH
        let union = a.width * a.height + b.width * b.height - intersection
        guard union > 0 else { return 0 }
        return intersection / union
    }
}
