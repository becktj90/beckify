import SwiftUI
import UniformTypeIdentifiers
import BeckifyMath

struct JobsView: View {
    @EnvironmentObject private var jobs: JobStore
    @Environment(\.browseFieldHome) private var browseFieldHome
    @State private var document = SavedJobsDocument(data: Data())
    @State private var presentsExporter = false
    @State private var presentsImporter = false
    @State private var transferMessage: String?
    @State private var presentsTransferAlert = false

    private var fieldJobs: [SavedJob] {
        jobs.jobs
            .filter { ToolboxCatalog.area(of: $0.toolID) == .field }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var toolkitJobs: [SavedJob] {
        jobs.jobs
            .filter { ToolboxCatalog.area(of: $0.toolID) != .field }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if jobs.jobs.isEmpty {
                    ContentUnavailableView {
                        Label("No field notes yet", systemImage: "note.text")
                    } description: {
                        Text("Run a Field calc, save an on-device note, or import notes from a Beckify archive. Exported files stay wherever you choose to save them.")
                    } actions: {
                        Button("Browse Field") {
                            browseFieldHome()
                        }
                        .accessibilityIdentifier("browseFieldFromJobsButton")
                    }
                } else {
                    List {
                        if !fieldJobs.isEmpty {
                            Section {
                                ForEach(fieldJobs) { job in
                                    SavedJobRow(job: job)
                                }
                                .onDelete { offsets in
                                    delete(jobs: fieldJobs, at: offsets)
                                }
                            } header: {
                                Text(ToolHomeArea.field.title)
                            }
                        }
                        if !toolkitJobs.isEmpty {
                            Section {
                                ForEach(toolkitJobs) { job in
                                    SavedJobRow(job: job)
                                }
                                .onDelete { offsets in
                                    delete(jobs: toolkitJobs, at: offsets)
                                }
                            } header: {
                                Text(ToolHomeArea.toolkit.title)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Jobs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SettingsToolbarButton()
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Export saved notes…", systemImage: "square.and.arrow.up", action: export)
                            .disabled(jobs.jobs.isEmpty)
                        Button("Import saved notes…", systemImage: "square.and.arrow.down") {
                            presentsImporter = true
                        }
                    } label: {
                        Label("Transfer notes", systemImage: "arrow.left.arrow.right")
                    }
                    .accessibilityLabel("Import or export saved notes")
                }
                if !jobs.jobs.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
            }
            .background(Theme.ambientBackground.ignoresSafeArea())
            .fileExporter(
                isPresented: $presentsExporter,
                document: document,
                contentType: .json,
                defaultFilename: "beckify-saved-jobs"
            ) { result in
                if case .failure(let error) = result, !isCancellation(error) {
                    presentTransferMessage("Could not export saved notes: \(error.localizedDescription)")
                }
            }
            .fileImporter(
                isPresented: $presentsImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false,
                onCompletion: importArchive
            )
            .alert("Saved notes", isPresented: $presentsTransferAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(transferMessage ?? "")
            }
        }
    }

    private func export() {
        do {
            document = SavedJobsDocument(data: try jobs.archiveData())
            presentsExporter = true
        } catch {
            presentTransferMessage("Could not prepare saved notes for export: \(error.localizedDescription)")
        }
    }

    private func importArchive(_ result: Result<[URL], Error>) {
        let url: URL
        do {
            guard let selectedURL = try result.get().first else { return }
            url = selectedURL
        } catch {
            guard !isCancellation(error) else { return }
            presentTransferMessage("Could not import saved notes: \(error.localizedDescription)")
            return
        }

        let importTask = Task.detached(priority: .userInitiated) { () throws -> SavedJobsArchive in
            let canAccess = url.startAccessingSecurityScopedResource()
            defer {
                if canAccess { url.stopAccessingSecurityScopedResource() }
            }
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard let size = values.fileSize, size <= SavedJobsArchive.maximumFileSize else {
                throw SavedJobsArchiveError.fileTooLarge
            }
            let data = try Data(contentsOf: url)
            return try SavedJobsArchive.decode(data)
        }

        Task { @MainActor in
            do {
                let archive = try await importTask.value
                let imported = try jobs.importArchive(archive)
                presentTransferMessage(imported == 0
                    ? "No new notes were imported. Notes with IDs already on this device were left unchanged."
                    : "Imported \(imported) saved \(imported == 1 ? "note" : "notes"). Existing notes were left unchanged.")
            } catch {
                guard !isCancellation(error) else { return }
                presentTransferMessage("Could not import saved notes: \(error.localizedDescription)")
            }
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        return (error as? CocoaError)?.code == .userCancelled
    }

    private func presentTransferMessage(_ message: String) {
        transferMessage = message
        presentsTransferAlert = true
    }

    private func delete(jobs list: [SavedJob], at offsets: IndexSet) {
        for index in offsets {
            self.jobs.delete(list[index])
        }
    }
}

private struct SavedJobsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw SavedJobsArchiveError.invalidJob("The selected file does not contain readable data.")
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct SavedJobRow: View {
    let job: SavedJob

    private var area: ToolHomeArea { ToolboxCatalog.area(of: job.toolID) }

    var body: some View {
        NavigationLink {
            JobDetailView(job: job)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(job.name).font(.headline)
                    HomeAreaBadge(area: area)
                }
                Text(ToolboxCatalog.tool(job.toolID).title)
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                Text(job.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
        }
        .accessibilityLabel("Saved note \(job.name), \(ToolboxCatalog.tool(job.toolID).title), \(area.title)")
    }
}

struct JobDetailView: View {
    let job: SavedJob
    @EnvironmentObject private var jobs: JobStore

    private var area: ToolHomeArea { ToolboxCatalog.area(of: job.toolID) }

    var body: some View {
        List {
            Section("Tool") {
                HStack {
                    Text(ToolboxCatalog.tool(job.toolID).title)
                    Spacer()
                    HomeAreaBadge(area: area)
                }
            }
            Section {
                NavigationLink {
                    JobRestoreHost(job: job)
                } label: {
                    Label(
                        "Open in \(ToolboxCatalog.tool(job.toolID).title)",
                        systemImage: "wrench.and.screwdriver"
                    )
                }
                .accessibilityIdentifier("openInToolButton")
                .accessibilityHint("Restores saved inputs into the tool when they still match. Opens the tool even if some fields cannot be restored.")
            }
            if let calculationBasis = job.calculationBasis {
                Section("Code & method") {
                    Text(calculationBasis)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Section("Inputs") {
                ForEach(job.inputs.keys.sorted(), id: \.self) { key in
                    LabeledContent(key, value: job.inputs[key] ?? "")
                }
            }
            Section("Results") {
                ForEach(job.outputs.keys.sorted(), id: \.self) { key in
                    LabeledContent(key, value: job.outputs[key] ?? "")
                }
            }
            if !job.notes.isEmpty {
                Section("Notes") { Text(job.notes) }
            }
            Section {
                Button("Delete job", role: .destructive) {
                    jobs.delete(job)
                }
            }
        }
        .navigationTitle(job.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CopyResultButton(text: copyBlob, compact: true, accessibilityName: "Copy saved note")
            }
        }
    }

    private var copyBlob: String {
        var lines = [
            job.name,
            ToolboxCatalog.tool(job.toolID).title,
            area.title,
        ]
        if let calculationBasis = job.calculationBasis {
            lines.append("Code & method: \(calculationBasis)")
        }
        if !job.inputs.isEmpty {
            lines.append("Inputs")
            for key in job.inputs.keys.sorted() {
                lines.append("\(key): \(job.inputs[key] ?? "")")
            }
        }
        if !job.outputs.isEmpty {
            lines.append("Results")
            for key in job.outputs.keys.sorted() {
                lines.append("\(key): \(job.outputs[key] ?? "")")
            }
        }
        if !job.notes.isEmpty {
            lines.append("Notes: \(job.notes)")
        }
        return lines.joined(separator: "\n")
    }
}

/// Restores whatever saved fields still map, then opens the tool. Never blocks.
private struct JobRestoreHost: View {
    let job: SavedJob

    init(job: SavedJob) {
        self.job = job
        ToolInputStore.restore(from: job)
    }

    var body: some View {
        CalculatorHostView(toolID: job.toolID)
    }
}
