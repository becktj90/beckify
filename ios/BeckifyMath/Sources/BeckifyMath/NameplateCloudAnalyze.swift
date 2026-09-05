import Foundation

/// Normalized `/api/analyze-nameplate` draft. Human confirm is still required.
public struct NameplateCloudDraft: Equatable, Sendable {
    public var extraction: NameplateExtraction
    public var rawOCR: String
    public var warnings: [String]
    public var dualFla: String?

    public init(
        extraction: NameplateExtraction,
        rawOCR: String = "",
        warnings: [String] = [],
        dualFla: String? = nil
    ) {
        self.extraction = extraction
        self.rawOCR = rawOCR
        self.warnings = warnings
        self.dualFla = dualFla
    }
}

/// Maps the live nameplate vision JSON into the shared editable schema.
/// Does not invent FLA from MOCP/LRA. Dual FLA stays a pair until the operator picks a side.
public enum NameplateCloudAnalyze {
    public static let agentID = "cloud-vlm"

    public static func normalize(_ raw: Any?) -> NameplateCloudDraft {
        let envelope = BeckifyVisionAPI.visionDraftInput(raw)
        let payload: [String: Any]
        if let fields = envelope["fields"] as? [String: Any] {
            payload = fields
        } else {
            payload = envelope
        }

        var warnings = BeckifyVisionAPI.stringList(envelope["warnings"])
        let rawOCR = BeckifyVisionAPI.stringValue(envelope["raw_ocr"] ?? envelope["rawOCR"] ?? envelope["rawText"]) ?? ""
        let dualFla = firstDual(
            BeckifyVisionAPI.unwrapValue(payload["dualFla"] ?? envelope["dualFla"]),
            BeckifyVisionAPI.unwrapValue(payload["fla"])
        )

        var fields: [NameplateField] = []
        func take(_ id: NameplateFieldID, _ raw: Any?, formatted: String?) {
            guard let formatted, !formatted.isEmpty else { return }
            fields.append(NameplateField(
                id: id,
                value: formatted,
                confidence: BeckifyVisionAPI.unwrapConfidence(raw),
                source: .vlm
            ))
        }

        take(.manufacturer, payload["manufacturer"], formatted: stringCell(payload["manufacturer"]))
        take(.model, payload["model"], formatted: stringCell(payload["model"]))
        take(.serialNumber, payload["serialNumber"] ?? payload["serial"], formatted: stringCell(payload["serialNumber"] ?? payload["serial"]))
        take(.ratedHP, payload["ratedHP"], formatted: numberCell(payload["ratedHP"]))
        take(.ratedKW, payload["ratedKW"], formatted: numberCell(payload["ratedKW"]))
        take(.voltage, payload["voltage"], formatted: stringCell(payload["voltage"]))
        take(.sf, payload["sf"], formatted: numberCell(payload["sf"]))
        take(.rpm, payload["rpm"], formatted: numberCell(payload["rpm"]))
        take(.poles, payload["poles"], formatted: intCell(payload["poles"]))
        take(.frequencyHz, payload["frequencyHz"], formatted: numberCell(payload["frequencyHz"]))
        take(.phases, payload["phases"], formatted: phaseCell(payload["phases"]))
        take(.enclosure, payload["enclosure"], formatted: stringCell(payload["enclosure"]))
        take(.frame, payload["frame"], formatted: stringCell(payload["frame"]))
        take(.designLetter, payload["designLetter"], formatted: letterCell(payload["designLetter"]))
        take(.codeLetter, payload["codeLetter"], formatted: letterCell(payload["codeLetter"]))
        take(.nomEff, payload["nomEff"], formatted: numberCell(payload["nomEff"]))
        take(.pf, payload["pf"], formatted: powerFactorCell(payload["pf"]))
        take(.mocp, payload["mocp"], formatted: numberCell(payload["mocp"]))
        take(.lra, payload["lra"], formatted: numberCell(payload["lra"]))
        take(.serviceFactorAmps, payload["serviceFactorAmps"], formatted: numberCell(payload["serviceFactorAmps"]))

        let insulation = stringCell(payload["insulationClass"] ?? payload["insulation"] ?? envelope["insulationClass"] ?? envelope["insulation"])
        take(.insulationClass, payload["insulationClass"] ?? payload["insulation"] ?? envelope["insulation"], formatted: insulation)

        var notes = stringCell(payload["notes"]) ?? ""
        let riseC = stringCell(payload["riseC"] ?? envelope["riseC"])
        if let riseC, !riseC.isEmpty {
            notes = joinNote(notes, "Temperature rise \(riseC)")
        }
        let ieClass = stringCell(payload["ieClass"] ?? envelope["ieClass"])
        if let ieClass, !ieClass.isEmpty {
            notes = joinNote(notes, "IE class \(ieClass)")
        }

        var flaValue = numberCell(payload["fla"])
        if let dualFla {
            flaValue = dualFla
            notes = joinNote(notes, "Dual FLA \(dualFla) — enter the amperes that match the voltage you are using.")
        } else if let fla = BeckifyVisionAPI.asFiniteDouble(BeckifyVisionAPI.unwrapValue(payload["fla"])) {
            let mocp = BeckifyVisionAPI.asFiniteDouble(BeckifyVisionAPI.unwrapValue(payload["mocp"]))
            let lra = BeckifyVisionAPI.asFiniteDouble(BeckifyVisionAPI.unwrapValue(payload["lra"]))
            if let mocp, fla == mocp {
                flaValue = nil
                warnings.append("FLA was ignored because it matched MOCP. MOCP is not FLA.")
            } else if let lra, fla == lra {
                flaValue = nil
                warnings.append("FLA was ignored because it matched LRA. LRA is not FLA.")
            }
        }
        take(.fla, payload["fla"], formatted: flaValue)
        take(.notes, payload["notes"], formatted: notes.isEmpty ? nil : notes)

        fields.sort { $0.id.sortOrder < $1.id.sortOrder }
        let extraction = NameplateExtraction(
            fields: fields,
            rawLines: rawOCR.split(whereSeparator: \.isNewline).map(String.init),
            agentID: agentID,
            leavesDevice: true
        )
        return NameplateCloudDraft(
            extraction: extraction,
            rawOCR: rawOCR,
            warnings: warnings,
            dualFla: dualFla
        )
    }

    public static func normalize(jsonData: Data) throws -> NameplateCloudDraft {
        let value = try JSONSerialization.jsonObject(with: jsonData)
        return normalize(value)
    }

    public static func normalize(jsonText: String) throws -> NameplateCloudDraft {
        guard let data = jsonText.data(using: .utf8) else {
            throw BeckifyVisionAPIError.unreadableJSON
        }
        return try normalize(jsonData: data)
    }

    /// Cloud values fill empty fields. Operator edits (`user`) stay. Existing
    /// heuristic values remain when the cloud draft left that slot empty.
    public static func merge(existing: NameplateExtraction?, incoming: NameplateExtraction) -> NameplateExtraction {
        guard let existing else { return incoming }
        var byID: [NameplateFieldID: NameplateField] = [:]
        for field in incoming.fields where !field.value.isEmpty {
            byID[field.id] = field
        }
        for field in existing.fields where !field.value.isEmpty {
            if field.source == .user {
                byID[field.id] = field
                continue
            }
            if byID[field.id] == nil {
                byID[field.id] = field
            }
        }
        let noteParts = [byID[.notes]?.value, incoming.value(.notes), existing.value(.notes)]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !noteParts.isEmpty {
            var seen = Set<String>()
            let unique = noteParts.filter { seen.insert($0).inserted }
            byID[.notes] = NameplateField(
                id: .notes,
                value: unique.joined(separator: "; "),
                confidence: byID[.notes]?.confidence ?? incoming.field(.notes)?.confidence ?? 0.7,
                source: byID[.notes]?.source ?? .vlm
            )
        }
        let fields = NameplateFieldID.allCases.compactMap { byID[$0] }
        let raw = incoming.rawLines.isEmpty ? existing.rawLines : incoming.rawLines
        return NameplateExtraction(
            fields: fields,
            rawLines: raw,
            agentID: incoming.agentID,
            leavesDevice: existing.leavesDevice || incoming.leavesDevice
        )
    }

    // MARK: - Cells

    private static func stringCell(_ raw: Any?) -> String? {
        BeckifyVisionAPI.stringValue(BeckifyVisionAPI.unwrapValue(raw))
    }

    private static func numberCell(_ raw: Any?) -> String? {
        let unwrapped = BeckifyVisionAPI.unwrapValue(raw)
        if let text = BeckifyVisionAPI.stringValue(unwrapped), BeckifyVisionAPI.dualNumberPair(text) != nil {
            return nil
        }
        guard let n = BeckifyVisionAPI.asFiniteDouble(unwrapped) else { return nil }
        return BeckifyVisionAPI.formatNumber(n)
    }

    private static func intCell(_ raw: Any?) -> String? {
        guard let n = BeckifyVisionAPI.asFiniteDouble(BeckifyVisionAPI.unwrapValue(raw)) else { return nil }
        return String(Int(n.rounded()))
    }

    private static func phaseCell(_ raw: Any?) -> String? {
        if let text = stringCell(raw) {
            let folded = text.uppercased()
                .replacingOccurrences(of: "Ø", with: "PH")
                .replacingOccurrences(of: " ", with: "")
            if ["1", "1.0", "1P", "1PH", "1PHASE", "SINGLE"].contains(folded) { return "1" }
            if ["3", "3.0", "3P", "3PH", "3PHASE", "THREE"].contains(folded) { return "3" }
        }
        guard let n = BeckifyVisionAPI.asFiniteDouble(BeckifyVisionAPI.unwrapValue(raw)) else { return nil }
        let i = Int(n.rounded())
        return i == 1 || i == 3 ? "\(i)" : nil
    }

    private static func letterCell(_ raw: Any?) -> String? {
        guard let text = stringCell(raw) else { return nil }
        let letter = text.uppercased().filter(\.isLetter).first
        return letter.map(String.init)
    }

    private static func powerFactorCell(_ raw: Any?) -> String? {
        guard var n = BeckifyVisionAPI.asFiniteDouble(BeckifyVisionAPI.unwrapValue(raw)) else { return nil }
        if n > 1, n <= 100 { n /= 100 }
        guard n > 0, n <= 1 else { return nil }
        return BeckifyVisionAPI.formatNumber((n * 1000).rounded() / 1000)
    }

    private static func firstDual(_ values: Any?...) -> String? {
        for value in values {
            if let text = BeckifyVisionAPI.stringValue(value), let pair = BeckifyVisionAPI.dualNumberPair(text) {
                return pair
            }
        }
        return nil
    }

    private static func joinNote(_ existing: String, _ extra: String) -> String {
        let parts = [existing, extra]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var seen = Set<String>()
        return parts.filter { seen.insert($0).inserted }.joined(separator: "; ")
    }
}
