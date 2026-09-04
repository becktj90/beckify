import Foundation

/// Shared motor-nameplate field ids. Website OCR and iOS Vision/heuristic
/// extract use the same keys so a confirmed plate can move between them later
/// without a second mapping layer.
public enum NameplateFieldID: String, Codable, CaseIterable, Sendable, Hashable {
    case manufacturer
    case model
    case serialNumber
    case ratedHP
    case ratedKW
    case voltage
    case fla
    case sf
    case rpm
    case poles
    case frequencyHz
    case phases
    case enclosure
    case frame
    case designLetter
    case codeLetter
    case nomEff
    case pf
    case mocp
    case lra
    case serviceFactorAmps
    case insulationClass
    case notes

    public var label: String {
        switch self {
        case .manufacturer: return "Manufacturer"
        case .model: return "Model"
        case .serialNumber: return "Serial"
        case .ratedHP: return "Rated HP"
        case .ratedKW: return "Rated kW"
        case .voltage: return "Voltage"
        case .fla: return "FLA"
        case .sf: return "Service factor"
        case .rpm: return "RPM"
        case .poles: return "Poles"
        case .frequencyHz: return "Frequency"
        case .phases: return "Phases"
        case .enclosure: return "Enclosure"
        case .frame: return "Frame"
        case .designLetter: return "Design letter"
        case .codeLetter: return "Code letter"
        case .nomEff: return "Nom. efficiency"
        case .pf: return "Power factor"
        case .mocp: return "MOCP"
        case .lra: return "LRA"
        case .serviceFactorAmps: return "SF amps"
        case .insulationClass: return "Insulation class"
        case .notes: return "Notes"
        }
    }

    public var unit: String {
        switch self {
        case .ratedHP: return "HP"
        case .ratedKW: return "kW"
        case .voltage: return "V"
        case .fla, .mocp, .lra, .serviceFactorAmps: return "A"
        case .rpm: return "RPM"
        case .frequencyHz: return "Hz"
        case .nomEff: return "%"
        default: return ""
        }
    }

    public var isNumeric: Bool {
        switch self {
        case .ratedHP, .ratedKW, .fla, .sf, .rpm, .poles, .frequencyHz, .phases,
             .nomEff, .pf, .mocp, .lra, .serviceFactorAmps:
            return true
        default:
            return false
        }
    }

    public var isOptional: Bool {
        switch self {
        case .serialNumber, .insulationClass, .notes, .ratedKW, .designLetter,
             .codeLetter, .mocp, .lra, .serviceFactorAmps, .nomEff, .pf, .poles:
            return true
        default:
            return false
        }
    }

    var sortOrder: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}

/// Where a structured value came from. `vlm` is reserved for a future cloud
/// path and is not emitted by the on-device heuristic in this package.
public enum NameplateFieldSource: String, Codable, Sendable {
    case heuristic
    case user
    case vlm
}

/// One schema field: a value, a 0…1 confidence, and whether a human reviewed it.
public struct NameplateField: Equatable, Sendable, Codable {
    public var id: NameplateFieldID
    public var value: String
    public var confidence: Double
    public var reviewed: Bool
    public var source: NameplateFieldSource

    public init(
        id: NameplateFieldID,
        value: String,
        confidence: Double,
        reviewed: Bool = false,
        source: NameplateFieldSource = .heuristic
    ) {
        self.id = id
        self.value = value
        self.confidence = min(max(confidence, 0), 1)
        self.reviewed = reviewed
        self.source = source
    }

    public var isLowConfidence: Bool {
        !reviewed && source != .user && confidence < NameplateFieldParser.lowConfidenceThreshold
    }
}

/// JSON slot shared with website OCR. `value` is omitted when empty so a
/// number field is a JSON number and a string field is a JSON string.
public struct NameplateSlot<Value: Equatable & Codable & Sendable>: Equatable, Sendable, Codable {
    public var value: Value?
    public var confidence: Double
    public var reviewed: Bool

    public init(value: Value? = nil, confidence: Double = 0, reviewed: Bool = false) {
        self.value = value
        self.confidence = min(max(confidence, 0), 1)
        self.reviewed = reviewed
    }

    public static var empty: NameplateSlot { NameplateSlot() }

    enum CodingKeys: String, CodingKey {
        case value, confidence, reviewed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(reviewed, forKey: .reviewed)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decodeIfPresent(Value.self, forKey: .value)
        confidence = min(max(try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0, 0), 1)
        reviewed = try container.decodeIfPresent(Bool.self, forKey: .reviewed) ?? false
    }
}

/// Canonical nameplate record. Keys match the website OCR schema.
public struct MotorNameplateRecord: Equatable, Sendable, Codable {
    public var manufacturer: NameplateSlot<String>
    public var model: NameplateSlot<String>
    public var serialNumber: NameplateSlot<String>
    public var ratedHP: NameplateSlot<Double>
    public var ratedKW: NameplateSlot<Double>
    public var voltage: NameplateSlot<String>
    public var fla: NameplateSlot<Double>
    public var sf: NameplateSlot<Double>
    public var rpm: NameplateSlot<Double>
    public var poles: NameplateSlot<Int>
    public var frequencyHz: NameplateSlot<Double>
    public var phases: NameplateSlot<Int>
    public var enclosure: NameplateSlot<String>
    public var frame: NameplateSlot<String>
    public var designLetter: NameplateSlot<String>
    public var codeLetter: NameplateSlot<String>
    public var nomEff: NameplateSlot<Double>
    public var pf: NameplateSlot<Double>
    public var mocp: NameplateSlot<Double>
    public var lra: NameplateSlot<Double>
    public var serviceFactorAmps: NameplateSlot<Double>
    public var insulationClass: NameplateSlot<String>
    public var notes: NameplateSlot<String>

    public init(
        manufacturer: NameplateSlot<String> = .empty,
        model: NameplateSlot<String> = .empty,
        serialNumber: NameplateSlot<String> = .empty,
        ratedHP: NameplateSlot<Double> = .empty,
        ratedKW: NameplateSlot<Double> = .empty,
        voltage: NameplateSlot<String> = .empty,
        fla: NameplateSlot<Double> = .empty,
        sf: NameplateSlot<Double> = .empty,
        rpm: NameplateSlot<Double> = .empty,
        poles: NameplateSlot<Int> = .empty,
        frequencyHz: NameplateSlot<Double> = .empty,
        phases: NameplateSlot<Int> = .empty,
        enclosure: NameplateSlot<String> = .empty,
        frame: NameplateSlot<String> = .empty,
        designLetter: NameplateSlot<String> = .empty,
        codeLetter: NameplateSlot<String> = .empty,
        nomEff: NameplateSlot<Double> = .empty,
        pf: NameplateSlot<Double> = .empty,
        mocp: NameplateSlot<Double> = .empty,
        lra: NameplateSlot<Double> = .empty,
        serviceFactorAmps: NameplateSlot<Double> = .empty,
        insulationClass: NameplateSlot<String> = .empty,
        notes: NameplateSlot<String> = .empty
    ) {
        self.manufacturer = manufacturer
        self.model = model
        self.serialNumber = serialNumber
        self.ratedHP = ratedHP
        self.ratedKW = ratedKW
        self.voltage = voltage
        self.fla = fla
        self.sf = sf
        self.rpm = rpm
        self.poles = poles
        self.frequencyHz = frequencyHz
        self.phases = phases
        self.enclosure = enclosure
        self.frame = frame
        self.designLetter = designLetter
        self.codeLetter = codeLetter
        self.nomEff = nomEff
        self.pf = pf
        self.mocp = mocp
        self.lra = lra
        self.serviceFactorAmps = serviceFactorAmps
        self.insulationClass = insulationClass
        self.notes = notes
    }

    /// Human confirm: every populated slot is marked reviewed.
    public func confirmed() -> MotorNameplateRecord {
        var copy = self
        copy.manufacturer = copy.manufacturer.markReviewedIfPresent()
        copy.model = copy.model.markReviewedIfPresent()
        copy.serialNumber = copy.serialNumber.markReviewedIfPresent()
        copy.ratedHP = copy.ratedHP.markReviewedIfPresent()
        copy.ratedKW = copy.ratedKW.markReviewedIfPresent()
        copy.voltage = copy.voltage.markReviewedIfPresent()
        copy.fla = copy.fla.markReviewedIfPresent()
        copy.sf = copy.sf.markReviewedIfPresent()
        copy.rpm = copy.rpm.markReviewedIfPresent()
        copy.poles = copy.poles.markReviewedIfPresent()
        copy.frequencyHz = copy.frequencyHz.markReviewedIfPresent()
        copy.phases = copy.phases.markReviewedIfPresent()
        copy.enclosure = copy.enclosure.markReviewedIfPresent()
        copy.frame = copy.frame.markReviewedIfPresent()
        copy.designLetter = copy.designLetter.markReviewedIfPresent()
        copy.codeLetter = copy.codeLetter.markReviewedIfPresent()
        copy.nomEff = copy.nomEff.markReviewedIfPresent()
        copy.pf = copy.pf.markReviewedIfPresent()
        copy.mocp = copy.mocp.markReviewedIfPresent()
        copy.lra = copy.lra.markReviewedIfPresent()
        copy.serviceFactorAmps = copy.serviceFactorAmps.markReviewedIfPresent()
        copy.insulationClass = copy.insulationClass.markReviewedIfPresent()
        copy.notes = copy.notes.markReviewedIfPresent()
        return copy
    }

    public func jsonString() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

private extension NameplateSlot {
    func markReviewedIfPresent() -> NameplateSlot {
        guard value != nil else { return self }
        return NameplateSlot(value: value, confidence: confidence, reviewed: true)
    }
}

public extension NameplateExtraction {
    func schemaRecord(forceReviewed: Bool = false) -> MotorNameplateRecord {
        func stringSlot(_ id: NameplateFieldID) -> NameplateSlot<String> {
            guard let field = field(id), !field.value.isEmpty else { return .empty }
            return NameplateSlot(
                value: field.value,
                confidence: field.confidence,
                reviewed: forceReviewed || field.reviewed
            )
        }
        func numberSlot(_ id: NameplateFieldID) -> NameplateSlot<Double> {
            guard let field = field(id), !field.value.isEmpty else { return .empty }
            let number = MotorFLA.horsepowerValue(field.value) ?? Double(field.value)
            return NameplateSlot(
                value: number,
                confidence: field.confidence,
                reviewed: forceReviewed || field.reviewed
            )
        }
        func intSlot(_ id: NameplateFieldID) -> NameplateSlot<Int> {
            guard let field = field(id), let number = Int(field.value) else { return .empty }
            return NameplateSlot(
                value: number,
                confidence: field.confidence,
                reviewed: forceReviewed || field.reviewed
            )
        }
        return MotorNameplateRecord(
            manufacturer: stringSlot(.manufacturer),
            model: stringSlot(.model),
            serialNumber: stringSlot(.serialNumber),
            ratedHP: numberSlot(.ratedHP),
            ratedKW: numberSlot(.ratedKW),
            voltage: stringSlot(.voltage),
            fla: numberSlot(.fla),
            sf: numberSlot(.sf),
            rpm: numberSlot(.rpm),
            poles: intSlot(.poles),
            frequencyHz: numberSlot(.frequencyHz),
            phases: intSlot(.phases),
            enclosure: stringSlot(.enclosure),
            frame: stringSlot(.frame),
            designLetter: stringSlot(.designLetter),
            codeLetter: stringSlot(.codeLetter),
            nomEff: numberSlot(.nomEff),
            pf: numberSlot(.pf),
            mocp: numberSlot(.mocp),
            lra: numberSlot(.lra),
            serviceFactorAmps: numberSlot(.serviceFactorAmps),
            insulationClass: stringSlot(.insulationClass),
            notes: stringSlot(.notes)
        )
    }

    func confirmingReview() -> NameplateExtraction {
        var copy = self
        copy.fields = fields.map { field in
            var next = field
            if !next.value.isEmpty { next.reviewed = true }
            return next
        }
        return copy
    }

    /// Merge operator edits into the extraction. Edited values are marked
    /// `user` with confidence 1; `reviewed` stays false until confirm.
    func applying(
        draft: [NameplateFieldID: String],
        confidence: [NameplateFieldID: Double] = [:]
    ) -> NameplateExtraction {
        var copy = self
        copy.fields = NameplateFieldID.allCases.compactMap { id in
            let value = (draft[id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            let original = field(id)
            let edited = original?.value != value
            return NameplateField(
                id: id,
                value: value,
                confidence: edited ? 1 : (confidence[id] ?? original?.confidence ?? 1),
                reviewed: false,
                source: edited ? .user : (original?.source ?? .heuristic)
            )
        }
        return copy
    }
}
