import SwiftUI
import BeckifyMath

struct ToolboxView: View {
    @State private var query = ""
    @State private var selected: ToolID?
    @State private var homeArea: ToolHomeArea = .field

    var filtered: [ToolDefinition] {
        ToolboxCatalog.matching(query)
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selected) {
                if isSearching {
                    ForEach(ToolHomeArea.allCases, id: \.self) { area in
                        let tools = filtered.filter { ToolboxCatalog.area(of: $0.id) == area }
                        if !tools.isEmpty {
                            Section {
                                ForEach(tools) { tool in
                                    NavigationLink(value: tool.id) {
                                        ToolRow(tool: tool, showArea: true)
                                    }
                                    .tag(tool.id)
                                }
                            } header: {
                                Text(area.title)
                            }
                        }
                    }
                    if searchFooterText != nil {
                        Section {
                            EmptyView()
                        } footer: {
                            if let searchFooterText {
                                Text(searchFooterText)
                            }
                        }
                    }
                } else {
                    ForEach(ToolShelfKind.shelves(in: homeArea), id: \.self) { shelf in
                        let tools = ToolboxCatalog.tools(on: shelf)
                        if !tools.isEmpty {
                            Section {
                                ForEach(tools) { tool in
                                    NavigationLink(value: tool.id) {
                                        ToolRow(tool: tool)
                                    }
                                    .tag(tool.id)
                                }
                            } header: {
                                Text(shelf.title)
                            } footer: {
                                if shelf == .jobsite, homeArea == .field {
                                    Text("Ampacity is used by Voltage Drop, Wire Size & Ampacity (310.16), and Conductor Cost Optimizer.")
                                }
                                if shelf == .instruments {
                                    Text("Wi-Fi Path shows Apple’s 0…1 signalStrength as percent and bars, plus TCP RTT. Cellular Path shows carrier / RAT and cellular-path RTT. iOS does not give third-party apps Wi-Fi or cellular dBm (no RSRP).")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Beckify")
            .searchable(text: $query, prompt: "Search Field and Toolkit…")
            .safeAreaInset(edge: .top) {
                if !isSearching {
                    Picker("Home area", selection: $homeArea) {
                        Text(ToolHomeArea.field.title).tag(ToolHomeArea.field)
                        Text(ToolHomeArea.toolkit.title).tag(ToolHomeArea.toolkit)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("homeAreaPicker")
                }
            }
            .background(Theme.background)
            .overlay {
                if isSearching && filtered.isEmpty {
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
                    description: Text("Field is the jobsite home. Toolkit holds basics, bench homework, and references. Search covers both. Saved Jobs are on-device notes, not a project gallery.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .environment(\.openRelatedTool, { id in
            selected = id
        })
    }

    private var searchFooterText: String? {
        if query.localizedCaseInsensitiveContains("ampacity") {
            return "Ampacity is used by Voltage Drop, Wire Size & Ampacity (310.16), and Conductor Cost Optimizer."
        }
        if query.localizedCaseInsensitiveContains("rssi")
            || query.localizedCaseInsensitiveContains("wifi")
            || query.localizedCaseInsensitiveContains("dbm")
            || query.localizedCaseInsensitiveContains("rsrp")
            || query.localizedCaseInsensitiveContains("cellular")
            || query.localizedCaseInsensitiveContains("lte")
            || query.localizedCaseInsensitiveContains("5g")
        {
            return "Wi-Fi Path reports Apple’s 0…1 strength as percent/bars plus TCP RTT. Cellular Path reports carrier, RAT, and cellular-path TCP RTT. iOS does not give third-party apps Wi-Fi or cellular dBm (no RSRP / RSRQ / SINR)."
        }
        return nil
    }
}

struct ToolRow: View {
    let tool: ToolDefinition
    var showArea: Bool = false
    @EnvironmentObject private var favorites: FavoritesStore

    private var area: ToolHomeArea { ToolboxCatalog.area(of: tool.id) }

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 14) {
                IconWell(toolID: tool.id, size: 40, glyphSize: 24, selected: true)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(tool.title)
                            .font(.headline)
                            .foregroundStyle(Theme.foreground)
                        if showArea {
                            HomeAreaBadge(area: area)
                        }
                    }
                    Text(tool.subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(showArea ? "\(tool.title), \(area.title)" : tool.title)
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
            case .conductorCost: ConductorCostView()
            case .conductorLength: ConductorLengthView()
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
            case .cellularStatus: CellularStatusView()
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
            case .tapChanger: TapChangerView()
            case .harmonicsTHD: HarmonicsTHDView()
            case .upsSizing: UPSSizingView()
            case .motorNameplate: MotorNameplateView()
            case .motorNameplateOCR: MotorNameplateOCRView()
            case .heaterDesign: HeaterDesignView()
            case .empEmc: EMPEMCView()
            case .necCircuit: NECCircuitView()
            case .loadWorksheet: LoadWorksheetView()
            case .cableSchedule: CableScheduleView()
            case .solenoidDesign: SolenoidDesignView()
            case .solarDesign: SolarDesignWizardView()
            case .analogWorkbench: AnalogDesignWorkbenchView()
            case .noiseSNR: NoiseSNRView()
            case .linearRegulator: LinearRegulatorView()
            case .instrumentationAmp: InstrumentationAmpView()
            case .adcDac: ADCDACView()
            case .eBikeTorqueRPM: EbikeTorqueRPMView()
            case .eBikeSprocket: EbikeSprocketView()
            case .eBikeRange: EbikeRangeView()
            case .eBikePackDesigner: EbikePackDesignerView()
            case .nickelStrip: NickelStripView()
            case .controlSystems: ControlSystemsLabView()
            }
        }
    }
}
