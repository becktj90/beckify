import SwiftUI
import BeckifyMath

struct JobsView: View {
    @EnvironmentObject private var jobs: JobStore
    @Environment(\.browseFieldHome) private var browseFieldHome

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
                        Label("No saved jobs", systemImage: "note.text")
                    } description: {
                        Text("Run a Field calc, then save the result as an on-device note. Nothing is uploaded — this is not a project gallery.")
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
            .navigationTitle("Saved Jobs")
            .toolbar {
                if !jobs.jobs.isEmpty { EditButton() }
            }
            .background(Theme.ambientBackground.ignoresSafeArea())
        }
    }

    private func delete(jobs list: [SavedJob], at offsets: IndexSet) {
        for index in offsets {
            self.jobs.delete(list[index])
        }
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
