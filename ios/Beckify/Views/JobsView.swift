import SwiftUI

struct JobsView: View {
    @EnvironmentObject private var jobs: JobStore

    var body: some View {
        NavigationStack {
            Group {
                if jobs.jobs.isEmpty {
                    ContentUnavailableView(
                        "No saved jobs",
                        systemImage: "note.text",
                        description: Text("Save a calculator result or a sensor snapshot as a lightweight on-device note for homework or field work. This is not a project gallery and nothing is uploaded.")
                    )
                } else {
                    List {
                        ForEach(jobs.jobs) { job in
                            NavigationLink {
                                JobDetailView(job: job)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(job.name).font(.headline)
                                    Text(ToolboxCatalog.tool(job.toolID).title)
                                        .font(.caption)
                                        .foregroundStyle(Theme.accent)
                                    Text(job.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(Theme.muted)
                                }
                            }
                        }
                        .onDelete(perform: jobs.delete)
                    }
                }
            }
            .navigationTitle("Saved Jobs")
            .toolbar { EditButton() }
        }
    }
}

struct JobDetailView: View {
    let job: SavedJob
    @EnvironmentObject private var jobs: JobStore

    var body: some View {
        List {
            Section("Tool") {
                Text(ToolboxCatalog.tool(job.toolID).title)
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
    }
}
