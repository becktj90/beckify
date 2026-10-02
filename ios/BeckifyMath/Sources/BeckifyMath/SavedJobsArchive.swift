import Foundation

public struct SavedJobsArchive: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let maximumFileSize = 8 * 1_024 * 1_024
    public static let maximumJobCount = 10_000

    public var schemaVersion: Int
    public var exportedAt: Date
    public var jobs: [SavedJobArchiveRecord]

    public init(
        schemaVersion: Int = currentSchemaVersion,
        exportedAt: Date = Date(),
        jobs: [SavedJobArchiveRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.jobs = jobs
    }

    public func encodedData() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumFileSize else {
            throw SavedJobsArchiveError.fileTooLarge
        }
        return data
    }

    public static func decode(_ data: Data) throws -> SavedJobsArchive {
        guard data.count <= maximumFileSize else {
            throw SavedJobsArchiveError.fileTooLarge
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(Self.self, from: data)
        try archive.validate()
        return archive
    }

    public func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw SavedJobsArchiveError.unsupportedVersion(schemaVersion)
        }
        guard jobs.count <= Self.maximumJobCount else {
            throw SavedJobsArchiveError.tooManyJobs
        }

        var seenIDs = Set<String>()
        var estimatedPayloadSize = 256
        for job in jobs {
            guard let parsedID = UUID(uuidString: job.id),
                  seenIDs.insert(parsedID.uuidString.lowercased()).inserted else {
                throw SavedJobsArchiveError.invalidJob("A saved note has an invalid or duplicate ID.")
            }
            guard !job.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  job.name.count <= 160 else {
                throw SavedJobsArchiveError.invalidJob("A saved note name is empty or too long.")
            }
            guard ToolCalculationPolicy.knownToolIDs.contains(job.toolID) else {
                throw SavedJobsArchiveError.invalidJob("A saved note references an unknown tool.")
            }
            guard job.notes.count <= 10_000,
                  (job.calculationBasis?.count ?? 0) <= 4_000,
                  job.inputs.count <= 100,
                  job.outputs.count <= 100,
                  Self.fieldsAreBounded(job.inputs),
                  Self.fieldsAreBounded(job.outputs) else {
                throw SavedJobsArchiveError.invalidJob("A saved note contains a field that is too large.")
            }
            estimatedPayloadSize += Self.estimatedSize(of: job)
            guard estimatedPayloadSize <= Self.maximumFileSize else {
                throw SavedJobsArchiveError.fileTooLarge
            }
        }
    }

    private static func fieldsAreBounded(_ fields: [String: String]) -> Bool {
        fields.allSatisfy { key, value in
            !key.isEmpty && key.count <= 160 && value.count <= 8_000
        }
    }

    private static func estimatedSize(of job: SavedJobArchiveRecord) -> Int {
        var size = job.id.utf8.count + job.name.utf8.count + job.toolID.utf8.count
            + job.notes.utf8.count + (job.calculationBasis?.utf8.count ?? 0) + 256
        for (key, value) in job.inputs {
            size += key.utf8.count + value.utf8.count + 8
        }
        for (key, value) in job.outputs {
            size += key.utf8.count + value.utf8.count + 8
        }
        return size
    }
}

public struct SavedJobArchiveRecord: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var toolID: String
    public var notes: String
    public var calculationBasis: String?
    public var inputs: [String: String]
    public var outputs: [String: String]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        name: String,
        toolID: String,
        notes: String = "",
        calculationBasis: String? = nil,
        inputs: [String: String],
        outputs: [String: String],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.toolID = toolID
        self.notes = notes
        self.calculationBasis = calculationBasis
        self.inputs = inputs
        self.outputs = outputs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum SavedJobsArchiveError: Error, Equatable, LocalizedError, Sendable {
    case fileTooLarge
    case tooManyJobs
    case unsupportedVersion(Int)
    case invalidJob(String)

    public var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            return "The archive is larger than the 8 MB limit."
        case .tooManyJobs:
            return "The archive contains more than 10,000 saved notes."
        case .unsupportedVersion(let version):
            return "Archive version \(version) is not supported by this version of Beckify."
        case .invalidJob(let reason):
            return reason
        }
    }
}
