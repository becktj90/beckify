import Foundation
import Combine
import BeckifyMath

struct SavedJob: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var toolID: ToolID
    var notes: String
    var calculationBasis: String?
    var inputs: [String: String]
    var outputs: [String: String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        toolID: ToolID,
        notes: String = "",
        calculationBasis: String? = nil,
        inputs: [String: String],
        outputs: [String: String],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
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

/// Local-only job store. Nothing leaves the device — no account, no analytics.
@MainActor
final class JobStore: ObservableObject {
    @Published private(set) var jobs: [SavedJob] = []

    private let key = "com.beckify.toolbox.savedJobs"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func save(_ job: SavedJob) {
        var savedJob = job
        let code = ElectricalCode(
            rawValue: defaults.string(forKey: ToolboxPreferenceKey.electricalCode) ?? ""
        ) ?? .nec
        if let notice = ElectricalCodeSupport.notice(toolID: job.toolID.rawValue, code: code) {
            savedJob.calculationBasis = "\(notice.title). \(notice.message)"
        }

        if let idx = jobs.firstIndex(where: { $0.id == savedJob.id }) {
            jobs[idx] = savedJob
        } else {
            jobs.insert(savedJob, at: 0)
        }
        persist()
        ReviewAskStore.shared.recordSavedJob()
    }

    func delete(at offsets: IndexSet) {
        jobs.remove(atOffsets: offsets)
        persist()
    }

    func delete(_ job: SavedJob) {
        jobs.removeAll { $0.id == job.id }
        persist()
    }

    func archiveData() throws -> Data {
        let records = jobs.map { job in
            SavedJobArchiveRecord(
                id: job.id.uuidString,
                name: job.name,
                toolID: job.toolID.rawValue,
                notes: job.notes,
                calculationBasis: job.calculationBasis,
                inputs: job.inputs,
                outputs: job.outputs,
                createdAt: job.createdAt,
                updatedAt: job.updatedAt
            )
        }
        return try SavedJobsArchive(jobs: records).encodedData()
    }

    @discardableResult
    func importArchive(_ data: Data) throws -> Int {
        let archive = try SavedJobsArchive.decode(data)
        let existingIDs = Set(jobs.map(\.id))
        let additions = archive.jobs.compactMap { record -> SavedJob? in
            guard let id = UUID(uuidString: record.id),
                  !existingIDs.contains(id),
                  let toolID = ToolID(rawValue: record.toolID) else {
                return nil
            }
            return SavedJob(
                id: id,
                name: record.name,
                toolID: toolID,
                notes: record.notes,
                calculationBasis: record.calculationBasis,
                inputs: record.inputs,
                outputs: record.outputs,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
        }
        guard jobs.count + additions.count <= SavedJobsArchive.maximumJobCount else {
            throw SavedJobsArchiveError.tooManyJobs
        }
        guard !additions.isEmpty else { return 0 }
        jobs = (jobs + additions).sorted { $0.updatedAt > $1.updatedAt }
        persist()
        return additions.count
    }

    private func load() {
        guard let data = defaults.data(forKey: key) else { return }
        if let decoded = try? JSONDecoder().decode([SavedJob].self, from: data) {
            jobs = decoded.sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(jobs) {
            defaults.set(data, forKey: key)
        }
    }
}
