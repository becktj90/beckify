import Foundation
import Combine

struct SavedJob: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var toolID: ToolID
    var notes: String
    var inputs: [String: String]
    var outputs: [String: String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        toolID: ToolID,
        notes: String = "",
        inputs: [String: String],
        outputs: [String: String],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.toolID = toolID
        self.notes = notes
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
        if let idx = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[idx] = job
        } else {
            jobs.insert(job, at: 0)
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
