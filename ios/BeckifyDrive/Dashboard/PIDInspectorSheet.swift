#if DEBUG
import BeckifyMath
import SwiftUI

/// Debug builds only. Every table signal with its request, the last raw reply,
/// the decoded value, and its age — for checking decodes against a real car.
struct PIDInspectorSheet: View {
    @ObservedObject var model: DashboardModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(DriveSignalTable.ev) { row in
                        InspectorRow(row: row, model: model)
                    }
                } header: {
                    Text("EV signals")
                } footer: {
                    Text("HV current sign convention: + leaves the pack. Check it against a known regen event.")
                }
                Section("Mode 01") {
                    ForEach(DriveSignalTable.all.filter { $0.group == .vehicle || $0.group == .powertrain }) { row in
                        InspectorRow(row: row, model: model)
                    }
                }
            }
            .font(.callout)
            .navigationTitle("PID Inspector")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct InspectorRow: View {
    let row: DriveSignalDefinition
    @ObservedObject var model: DashboardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.name)
                    .font(.callout.weight(.semibold))
                Spacer()
                Text(decoded)
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .foregroundStyle(row.isReported ? DriveTheme.text : DriveTheme.muted)
            }
            Text("\(row.header.map { "ATSH \($0)" } ?? "no header") · \(row.request ?? "not sent")")
                .font(.caption.monospaced())
                .foregroundStyle(DriveTheme.muted)
            if let raw {
                Text("raw: \(raw.reply)")
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                Text("\(Int(model.now.timeIntervalSince(raw.at).rounded())) s ago")
                    .font(.caption2)
                    .foregroundStyle(DriveTheme.muted)
            } else if row.isReported {
                Text("No reply yet")
                    .font(.caption2)
                    .foregroundStyle(DriveTheme.muted)
            }
            Text(row.source)
                .font(.caption2)
                .foregroundStyle(DriveTheme.muted)
        }
        .padding(.vertical, 2)
    }

    private var raw: OBDBluetoothSession.RawReply? {
        guard let request = row.request else { return nil }
        return model.rawReplies[request]
    }

    private var decoded: String {
        guard let reading = row.reading, let sample = model.book.sample(reading) else { return "—" }
        let text = "\(String(format: "%.2f", sample.value)) \(row.unit)"
        return row.accepts(sample.value) ? text : "\(text) ⚠︎ out of range"
    }
}
#endif
