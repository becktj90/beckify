import SwiftUI

struct ToolboxView: View {
    @State private var query = ""
    @State private var selected: ToolID?

    var filtered: [ToolDefinition] {
        ToolboxCatalog.matching(query)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selected) {
                Section {
                    ForEach(filtered) { tool in
                        NavigationLink(value: tool.id) {
                            ToolRow(tool: tool)
                        }
                        .tag(tool.id)
                    }
                } header: {
                    Text("Field calculators")
                } footer: {
                    if query.localizedCaseInsensitiveContains("ampacity") {
                        Text("Ampacity is used by Voltage Drop (cross-check) and Wire Size & Ampacity (310.16).")
                    }
                }
            }
            .navigationTitle("Beckify")
            .searchable(text: $query, prompt: "Ohm, ampacity, 555, conduit…")
            .background(Theme.background)
        } detail: {
            if let selected {
                CalculatorHostView(toolID: selected)
            } else {
                ContentUnavailableView(
                    "Choose a calculator",
                    systemImage: "wrench.and.screwdriver",
                    description: Text("Search the toolbox or pick a tool. Live results update as you type.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct ToolRow: View {
    let tool: ToolDefinition

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: tool.symbol)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(tool.title)
                    .font(.headline)
                    .foregroundStyle(Theme.foreground)
                Text(tool.subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CalculatorHostView: View {
    let toolID: ToolID

    var body: some View {
        Group {
            switch toolID {
            case .ohmsLaw: OhmsLawView()
            case .power: PowerView()
            case .powerWizard: PowerWizardView()
            case .voltageDrop: VoltageDropView()
            case .conduitFill: ConduitFillView()
            case .transformer: TransformerView()
            case .timer555: Timer555View()
            case .motorFLA: MotorFLAView()
            case .wireAmpacity: WireAmpacityView()
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }
}
