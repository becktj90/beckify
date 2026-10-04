import SwiftUI
import UIKit
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
                                    Text("Wi-Fi Path leads with Online / Captive (Apple hotspot-detect — local / online), then Apple’s 0…1 signalStrength as percent and bars, plus TCP RTT. Cellular Path shows the same Online / Captive card, carrier / RAT, and cellular-path RTT. iOS does not give third-party apps Wi-Fi or cellular dBm (no RSRP).")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Beckify")
            .searchable(text: $query, prompt: "Search tools…")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SettingsToolbarButton()
                }
            }
            .safeAreaInset(edge: .top) {
                if !isSearching {
                    Picker("Home area", selection: $homeArea) {
                        Text(ToolHomeArea.field.title).tag(ToolHomeArea.field)
                        Text(ToolHomeArea.toolkit.title).tag(ToolHomeArea.toolkit)
                    }
                    .segmentedControlStyle()
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
                    description: Text("Field is the jobsite home. Toolkit holds basics, bench, and references. Search covers both. Saved Jobs are on-device notes, not a project gallery.")
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
            || query.localizedCaseInsensitiveContains("captive")
            || query.localizedCaseInsensitiveContains("online")
        {
            return "Wi-Fi Path leads with Online / Captive (Apple hotspot-detect), then Apple’s 0…1 strength as percent/bars plus TCP RTT. Cellular Path reports the same Online / Captive card, carrier, RAT, and cellular-path TCP RTT. iOS does not give third-party apps Wi-Fi or cellular dBm (no RSRP / RSRQ / SINR)."
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
                IconWell(toolID: tool.id, size: 40, selected: true)
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
            case .threePhasePower: ThreePhasePowerView()
            case .powerWizard: PowerWizardView()
            case .voltageDrop: VoltageDropView()
            case .conduitFill: ConduitFillView()
            case .cableLadder: CableLadderView()
            case .equipmentGround: EquipmentGroundingView()
            case .conductorCost: ConductorCostView()
            case .conductorLength: ConductorLengthView()
            case .transformer: TransformerView()
            case .timer555: Timer555View()
            case .motorFLA: MotorFLAView()
            case .wireAmpacity: WireAmpacityView()
            case .flexibleCable: FlexibleCableAmpacityView()
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
            case .acousticImager: AcousticImagerView()
            case .setupCheck: SetupCheckView()
            case .bubbleLevel: BubbleLevelView()
            case .magnetometer: MagnetometerView()
            case .barometer: BarometerView()
            case .motionSnapshot: MotionSnapshotView()
            case .stillnessWatch: StillnessWatchView()
            case .breathFlute: EmptyView() // Removed from catalog (build 232); ToolID kept for Codable.
            case .coupledVibration: CoupledVibrationView()
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
            case .spanishTranslator: SpanishTranslatorView()
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
            case .controlStrategies: ControlStrategiesView()
            case .electronicsLab: ElectronicsLabView()
            case .phasorImpedance: PhasorImpedanceView()
            case .ul508aPanelLab: UL508APanelLabView()
            case .magneticsLab: MagneticsLabView()
            case .emFields: EMFieldsView()
            case .statistics: StatisticsView()
            case .switchgearLogicLab: SwitchgearLogicLabView()
            }
        }
        .background(ToolBackSwipeSupport().allowsHitTesting(false))
    }
}

/// Enable the native edge swipe for pushed calculators. UIKit performs a
/// single interactive pop, so SwiftUI
/// removes only the last destination and preserves the shelf / previous tool.
private struct ToolBackSwipeSupport: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}
    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) {
        controller.restoreGesture()
    }

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        private weak var popGesture: UIGestureRecognizer?
        private var previousDelegate: UIGestureRecognizerDelegate?
        private var previouslyEnabled = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let navigationController,
                  let gesture = navigationController.interactivePopGestureRecognizer,
                  gesture.delegate !== self else { return }
            popGesture = gesture
            if let previousTool = gesture.delegate as? Controller {
                // Preserve the system delegate, not a controller being popped.
                previousDelegate = previousTool.previousDelegate
                previouslyEnabled = previousTool.previouslyEnabled
            } else {
                previousDelegate = gesture.delegate
                previouslyEnabled = gesture.isEnabled
            }
            gesture.delegate = self
            gesture.isEnabled = navigationController.viewControllers.count > 1
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            restoreGesture()
        }

        func restoreGesture() {
            // A newly visible tool may already own the gesture. Do not undo it.
            if let gesture = popGesture, gesture.delegate === self {
                gesture.delegate = previousDelegate
                gesture.isEnabled = previouslyEnabled
            }
            previousDelegate = nil
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let navigationController else { return false }
            return navigationController.viewControllers.count > 1
                && navigationController.transitionCoordinator == nil
        }
    }
}
