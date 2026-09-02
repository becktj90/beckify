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
                if !calcs.isEmpty {
                    Section {
                        ForEach(calcs) { tool in
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
                if !homework.isEmpty {
                    Section {
                        ForEach(homework) { tool in
                            NavigationLink(value: tool.id) {
                                ToolRow(tool: tool)
                            }
                            .tag(tool.id)
                        }
                    } header: {
                        Text("Homework")
                    }
                }
                if !sensors.isEmpty {
                    Section {
                        ForEach(sensors) { tool in
                            NavigationLink(value: tool.id) {
                                ToolRow(tool: tool)
                            }
                            .tag(tool.id)
                        }
                    } header: {
                        Text("Sensors")
                    } footer: {
                        if query.localizedCaseInsensitiveContains("rssi") || query.localizedCaseInsensitiveContains("wifi") {
                            Text("Wi-Fi RSSI is not available through public iOS APIs. The Wi-Fi Path tool shows path status and will not invent a signal bar.")
                        }
                    }
                }
            }
            .navigationTitle("Beckify")
            .searchable(text: $query, prompt: "Ohm, divider, color code, LED, wifi…")
            .background(Theme.background)
            .overlay {
                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && filtered.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
        } detail: {
            if let selected {
                CalculatorHostView(toolID: selected)
            } else {
                ContentUnavailableView(
                    "Choose a tool",
                    systemImage: "wrench.and.screwdriver",
                    description: Text("Search the toolbox or pick a calculator or sensor. Saved Jobs are on-device notes, not a project gallery.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var calcs: [ToolDefinition] { filtered.filter { $0.kind == .calculator } }
    private var homework: [ToolDefinition] { filtered.filter { $0.kind == .homework } }
    private var sensors: [ToolDefinition] { filtered.filter { $0.kind == .sensor } }
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
            case .voltageDivider: VoltageDividerView()
            case .seriesParallel: SeriesParallelView()
            case .resistorColor: ResistorColorView()
            case .unitConverter: UnitConverterView()
            case .frequencyWave: FrequencyView()
            case .ledRC: LEDRCView()
            case .wifiStatus: WiFiStatusView()
            case .bluetoothScan: BluetoothScannerView()
            case .noiseMeter: NoiseMeterView()
            case .bubbleLevel: BubbleLevelView()
            case .magnetometer: MagnetometerView()
            case .barometer: BarometerView()
            case .motionSnapshot: MotionSnapshotView()
            case .fieldPosition: FieldPositionView()
            case .deviceHealth: DeviceHealthView()
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }
}
