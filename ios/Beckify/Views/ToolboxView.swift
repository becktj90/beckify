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
                        if query.localizedCaseInsensitiveContains("rssi") || query.localizedCaseInsensitiveContains("wifi") || query.localizedCaseInsensitiveContains("dbm") {
                            Text("Wi-Fi dBm/RSSI is not a public iOS API. Wi-Fi Path maps Apple’s 0…1 signalStrength (percent/bars) with a location heatmap — it will not invent dBm.")
                        }
                    }
                }
            }
            .navigationTitle("Beckify")
            .searchable(text: $query, prompt: "Ohm, receptacle, NEMA, LED, wifi…")
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
        .environment(\.openRelatedTool, { id in
            selected = id
        })
    }

    private var calcs: [ToolDefinition] { filtered.filter { $0.kind == .calculator } }
    private var homework: [ToolDefinition] { filtered.filter { $0.kind == .homework } }
    private var sensors: [ToolDefinition] { filtered.filter { $0.kind == .sensor } }
}

struct ToolRow: View {
    let tool: ToolDefinition
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 14) {
                IconWell(toolID: tool.id, size: 40, glyphSize: 24, selected: true)
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel(tool.title)
            .accessibilityHint(tool.subtitle)

            Spacer(minLength: 8)

            FavoriteToggleButton(isOn: favorites.isFavorite(tool.id), name: tool.title) {
                favorites.toggle(tool.id)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("toolRow.\(tool.id.rawValue)")
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
            case .receptacleSelector: ReceptacleSelectorView()
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
            case .reactance: ReactanceView()
            case .powerFactor: PowerFactorView()
            case .shortCircuit: ShortCircuitView()
            case .circularMils: CircularMilsView()
            case .loadFactors: LoadFactorsView()
            case .signalScaling: SignalScalingView()
            case .modbusAddress: ModbusAddressView()
            case .plcTimer: PLCTimerView()
            case .panelDirectory: PanelDirectoryView()
            case .motorSpeed: MotorSpeedView()
            case .rfLink: RFLinkView()
            case .phasorDiagram: PhasorDiagramView()
            case .numberBase: NumberBaseView()
            case .batteryBank: BatteryBankView()
            case .referenceLibrary: ReferenceLibraryView()
            case .magneticCircuit: MagneticCircuitView()
            case .fiberLink: FiberLinkView()
            case .gaussianBeam: GaussianBeamView()
            case .transientCircuit: TransientCircuitView()
            case .rackCurrent: RackCurrentView()
            case .diodeIV: DiodeIVView()
            case .isLoopVerifier: ISLoopVerifierView()
            }
        }
    }
}
