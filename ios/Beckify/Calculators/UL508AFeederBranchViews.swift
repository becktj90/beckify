import SwiftUI
import BeckifyMath

private struct FeederDraft: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var kind: FeederLoadInput.Kind
    var amps: String
    var bcpd: String

    static let example: [FeederDraft] = [
        FeederDraft(id: "m1", name: "Conveyor", kind: .motor, amps: "28", bcpd: "70"),
        FeederDraft(id: "m2", name: "Pump", kind: .motor, amps: "14", bcpd: "40"),
        FeederDraft(id: "h1", name: "Heater", kind: .heater, amps: "10", bcpd: ""),
        FeederDraft(id: "o1", name: "Controls", kind: .other, amps: "5", bcpd: ""),
    ]
}

struct UL508AFeederView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.ul508aPanelLab, "environment", default: PanelInstallEnvironment.indoorDry) private var environment
    @StoredChoice(.ul508aPanelLab, "feederTerminal", default: PanelTerminalColumn.c75) private var terminal
    @StoredInput(.ul508aPanelLab, "feederJSON", default: "") private var feederJSON
    @StoredInput(.ul508aPanelLab, "feederAmpacity", default: "85") private var ampacity
    @StoredInput(.ul508aPanelLab, "feederJob", default: "Panel feeder") private var jobName
    @State private var drafts: [FeederDraft] = FeederDraft.example
    @State private var didLoad = false
    @State private var session = ExplicitCalculationState<FeederSizingResult>()

    private var fingerprint: String {
        drafts.map { "\($0.name)|\($0.kind)|\($0.amps)|\($0.bcpd)" }.joined(separator: ";") + "|\(ampacity)|\(terminal)"
    }

    var body: some View {
        PanelLabScreen(
            title: "Feeder Circuit Sizer",
            bullets: [
                "Conductor minimum is 125% of the largest motor, 125% of every heater, and 100% of the other loads that can run together.",
                "Feeder overcurrent device stays at or under the larger of that branch-device sum and the conductor ampacity.",
                "Wire type and conduit follow the location you picked. Confirm NEC and the AHJ.",
                "Planning aid for the panel builder. Field wiring still follows the adopted Code.",
            ],
            stickyAnswer: session.displayedResult.map { "Feeder OCPD ≤ \(Format.amps($0.maximumFeederOCPD))" },
            copyText: session.displayedResult.map(copyText)
        ) {
            EnvironmentMenu(environment: $environment)
            MenuField(title: "Terminal column", selection: $terminal, options: PanelTerminalColumn.allCases) { $0.title }
            Text(terminal.detail)
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
            ForEach($drafts) { $draft in
                loadCard($draft)
            }
            Button("Add load") {
                drafts.append(FeederDraft(id: UUID().uuidString, name: "", kind: .other, amps: "", bcpd: ""))
            }
            .buttonStyle(.bordered)
            .frame(minHeight: Theme.touchTarget)
            NumberField(title: "Conductor ampacity, if you already picked a wire", unit: "A", text: $ampacity, optional: true, fieldID: "feederAmpacity", onSubmit: calculate)
            CalculatorActionBar(onCalculate: calculate, onReset: reset, onExample: applyExample, exampleTitle: "Two motors, heater, controls")
            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }
            if let result = session.displayedResult {
                if let capacity = result.suggestedAmpacity {
                    AmpacityMeter(required: result.minimumConductorAmps, capacity: Double(capacity))
                }
                ResultCard(title: "Feeder", copyText: copyText(result)) {
                    ResultRow(label: "Minimum conductor", value: Format.amps(result.minimumConductorAmps), emphasis: true)
                    ResultRow(label: "Largest motor", value: Format.amps(result.largestMotorFLC))
                    ResultRow(label: "Other motors", value: Format.amps(result.remainingMotorFLC))
                    ResultRow(label: "Heaters", value: Format.amps(result.heaterFLC))
                    ResultRow(label: "Other loads", value: Format.amps(result.otherFLC))
                    ResultRow(
                        label: result.branchDeviceIsPlanning ? "Largest branch device (planning)" : "Largest branch device",
                        value: Format.amps(result.largestBranchDeviceAmps)
                    )
                    ResultRow(label: "Branch-device sum", value: Format.amps(result.overcurrentBasisAmps))
                    ResultRow(label: "Conductor ampacity used", value: Format.amps(result.conductorAmpacityUsed))
                    ResultRow(label: "Feeder OCPD maximum", value: Format.amps(result.maximumFeederOCPD), emphasis: true, tone: Theme.good)
                    if let size = result.suggestedSize, let amps = result.suggestedAmpacity {
                        ResultRow(label: "Planning wire, \(terminal.title)", value: "\(NECTables.wireLabel(size)) · \(amps) A")
                    }
                    if result.branchDeviceIsPlanning {
                        Text("No branch device was entered. The largest motor was given a planning inverse-time breaker from the same percentage Motor Nameplate uses. Replace it with the device you will install.")
                            .font(Theme.TypeRole.help)
                            .foregroundStyle(Theme.warn)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(result.formula)
                        .font(.caption.monospaced())
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                WiringAdviceCard(advice: PanelWiringAdvice.recommend(environment: environment, circuit: .powerFeeder))
                ConductorColorGuide(families: [.powerDistribution])
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    guard let result = session.displayedResult else { return }
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .ul508aPanelLab,
                        inputs: ["step": "feeder"],
                        outputs: [
                            "minA": Format.number(result.minimumConductorAmps, digits: 1),
                            "ocpdMax": Format.number(result.maximumFeederOCPD, digits: 1),
                        ]
                    ))
                }
            }
        }
        .onAppear(perform: load)
        .onChange(of: drafts) { _, newValue in persist(newValue) }
        .onChange(of: fingerprint) { _, _ in session.markInputsChanged() }
    }

    private func loadCard(_ draft: Binding<FeederDraft>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextInputField(title: "Load", text: draft.name, placeholder: "Conveyor", fieldID: "load-\(draft.wrappedValue.id)")
                Button(role: .destructive) {
                    drafts.removeAll { $0.id == draft.wrappedValue.id }
                } label: {
                    Image(systemName: "trash")
                        .frame(minWidth: Theme.touchTarget, minHeight: Theme.touchTarget)
                }
                .accessibilityLabel("Remove \(draft.wrappedValue.name)")
                .disabled(drafts.count <= 1)
            }
            MenuField(title: "Kind", selection: draft.kind, options: [FeederLoadInput.Kind.motor, .heater, .other]) { kind in
                switch kind {
                case .motor: return "Motor"
                case .heater: return "Heater"
                case .other: return "Other"
                }
            }
            NumberField(title: "Full-load current", unit: "A", text: draft.amps, fieldID: "a-\(draft.wrappedValue.id)", onSubmit: calculate)
            NumberField(title: "Branch device", unit: "A", text: draft.bcpd, optional: true, fieldID: "b-\(draft.wrappedValue.id)", onSubmit: calculate)
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }

    private func calculate() {
        session.calculate {
            let loads = try drafts.enumerated().map { index, draft in
                guard let amps = panelParse(draft.amps) else {
                    throw CalcError.missing("current for \(draft.name.isEmpty ? "load \(index + 1)" : draft.name)")
                }
                return FeederLoadInput(
                    name: draft.name.isEmpty ? "Load \(index + 1)" : draft.name,
                    kind: draft.kind,
                    fullLoadAmps: amps,
                    branchDeviceAmps: panelParse(draft.bcpd)
                )
            }
            return try PanelFeederSizing.size(
                loads: loads,
                conductorAmpacity: panelParse(ampacity),
                terminal: terminal
            )
        }
    }

    private func copyText(_ result: FeederSizingResult) -> String {
        "Feeder conductor ≥ \(Format.amps(result.minimumConductorAmps)); OCPD ≤ \(Format.amps(result.maximumFeederOCPD))"
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let data = feederJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([FeederDraft].self, from: data),
              !decoded.isEmpty else { return }
        drafts = decoded
    }

    private func persist(_ drafts: [FeederDraft]) {
        guard didLoad, let data = try? JSONEncoder().encode(drafts), let text = String(data: data, encoding: .utf8) else { return }
        feederJSON = text
    }

    private func reset() {
        drafts = [FeederDraft(id: UUID().uuidString, name: "", kind: .motor, amps: "", bcpd: "")]
        ampacity = ""
        session = ExplicitCalculationState()
    }

    private func applyExample() {
        drafts = FeederDraft.example
        ampacity = "85"
        terminal = .c75
        session = ExplicitCalculationState()
    }
}

private enum BranchMode: String, CaseIterable, Hashable, Identifiable {
    case single
    case group

    var id: String { rawValue }
    var title: String { self == .single ? "One motor" : "Group" }
}

struct UL508ABranchView: View {
    @EnvironmentObject private var jobs: JobStore
    @Environment(\.openRelatedTool) private var openRelated
    @StoredChoice(.ul508aPanelLab, "environment", default: PanelInstallEnvironment.indoorDry) private var environment
    @StoredChoice(.ul508aPanelLab, "branchMode", default: BranchMode.single) private var mode
    @StoredChoice(.ul508aPanelLab, "branchDevice", default: BranchDeviceChoice.inverseTimeBreaker) private var device
    @StoredChoice(.ul508aPanelLab, "groupDevice", default: GroupProtectiveDevice.inverseTimeBreaker) private var groupDevice
    @StoredChoice(.ul508aPanelLab, "motorType", default: MotorNameplateType.squirrelCageOther) private var motorType
    @StoredInput(.ul508aPanelLab, "branchFLC", default: "14") private var flc
    @StoredInput(.ul508aPanelLab, "branchSF", default: "") private var serviceFactor
    @StoredInput(.ul508aPanelLab, "groupFLCs", default: "10, 8, 6") private var groupFLCs
    @StoredInput(.ul508aPanelLab, "branchJob", default: "Branch circuit") private var jobName
    @State private var session = ExplicitCalculationState<BranchScreenResult>()

    private var fingerprint: String {
        "\(mode)|\(device)|\(groupDevice)|\(motorType)|\(flc)|\(serviceFactor)|\(groupFLCs)"
    }

    var body: some View {
        PanelLabScreen(
            title: "Branch / Motor Circuit",
            bullets: [
                "One motor uses the same short-circuit percentages as Motor Nameplate. Conductors are 125% of FLC.",
                "A group device is the percentage of the largest motor plus the other motor currents. Every controller has to be marked for group use.",
                "The one-tenth tap is of the group device you install. Load-side wire is still 125% of that motor.",
                "Look up table FLC in Motor FLA. This screen does not keep a second horsepower table.",
            ],
            stickyAnswer: sticky,
            copyText: session.displayedResult?.summary
        ) {
            EnvironmentMenu(environment: $environment)
            Picker("Branch", selection: $mode) {
                ForEach(BranchMode.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            if mode == .single {
                NumberField(title: "Motor FLC", unit: "A", text: $flc, fieldID: "branchFLC", onSubmit: calculate)
                MenuField(title: "Branch device", selection: $device, options: BranchDeviceChoice.allCases) { $0.title }
                MenuField(title: "Motor type", selection: $motorType, options: MotorNameplateType.allCases) { $0.label }
                NumberField(title: "Service factor", unit: "", text: $serviceFactor, optional: true, fieldID: "sf", onSubmit: calculate)
            } else {
                TextInputField(title: "Motor FLCs", text: $groupFLCs, placeholder: "10, 8, 6", fieldID: "groupFLCs", onSubmit: calculate)
                Text("Comma-separated full-load currents. At least two motors.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                MenuField(title: "Group device", selection: $groupDevice, options: GroupProtectiveDevice.allCases) { $0.title }
            }
            Button {
                openRelated(.motorFLA)
            } label: {
                Label("Open Motor FLA tables", systemImage: "fanblades")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: Theme.touchTarget, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            CalculatorActionBar(onCalculate: calculate, onReset: reset, onExample: applyExample, exampleTitle: mode == .single ? "14 A inverse-time" : "10, 8, 6 A group")
            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }
            if let result = session.displayedResult {
                ResultCard(title: "Branch", copyText: result.summary) {
                    Text(result.headline)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Theme.good)
                    ForEach(result.rows, id: \.label) { row in
                        ResultRow(label: row.label, value: row.value)
                    }
                    ForEach(result.notes, id: \.self) { note in
                        Text(note)
                            .font(Theme.TypeRole.help)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let required = result.conductorMin, let capacity = result.conductorCapacity {
                    AmpacityMeter(required: required, capacity: capacity)
                }
                WiringAdviceCard(advice: PanelWiringAdvice.recommend(environment: environment, circuit: .powerBranch))
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    guard let result = session.displayedResult else { return }
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .ul508aPanelLab,
                        inputs: ["step": "branch", "mode": mode.rawValue],
                        outputs: ["summary": result.summary]
                    ))
                }
            }
        }
        .onChange(of: fingerprint) { _, _ in session.markInputsChanged() }
    }

    private var sticky: String? {
        session.displayedResult?.headline
    }

    private func calculate() {
        session.calculate {
            if mode == .single {
                guard let current = panelParse(flc) else { throw CalcError.missing("motor FLC") }
                let branch = try PanelBranchSizing.singleMotor(
                    flc: current,
                    device: device,
                    motorType: motorType,
                    serviceFactor: panelParse(serviceFactor)
                )
                let wire = try? PanelWireAmpacity.smallest(requiredAmps: branch.conductorMinAmps, column: .c75, includeControlSizes: false)
                var rows = [
                    BranchRow(label: "Percent of FLC", value: Format.percent(branch.percent)),
                    BranchRow(label: "Raw device", value: Format.amps(branch.rawAmps)),
                    BranchRow(label: "Conductor minimum", value: Format.amps(branch.conductorMinAmps)),
                    BranchRow(label: "Overload maximum", value: "\(Format.amps(branch.overloadAmps)) (\(Format.number(branch.overloadPercent, digits: 0))%)"),
                ]
                if let standard = branch.nextStandardAmps {
                    rows.insert(BranchRow(label: "Next standard device", value: "\(standard) A"), at: 2)
                }
                if let wire {
                    rows.append(BranchRow(label: "Planning wire, 75°C", value: "\(NECTables.wireLabel(wire.size)) · \(wire.ampacity) A"))
                }
                let deviceText = branch.nextStandardAmps.map { "\($0) A" } ?? Format.amps(branch.rawAmps)
                return BranchScreenResult(
                    headline: "Branch device \(deviceText)",
                    summary: "Branch \(deviceText); conductor ≥ \(Format.amps(branch.conductorMinAmps))",
                    rows: rows,
                    notes: branch.notes,
                    conductorMin: branch.conductorMinAmps,
                    conductorCapacity: wire.map { Double($0.ampacity) }
                )
            }
            let currents = groupFLCs.split(whereSeparator: { ",; ".contains($0) }).compactMap { panelParse(String($0)) }
            guard currents.count == groupFLCs.split(whereSeparator: { ",; ".contains($0) }).count else {
                throw CalcError.missing("numeric motor currents")
            }
            let group = try PanelBranchSizing.group(motorFLCs: currents, device: groupDevice)
            var rows = [
                BranchRow(label: "Largest motor", value: Format.amps(group.largestFLC)),
                BranchRow(label: "Raw group device", value: Format.amps(group.rawAmps)),
                BranchRow(label: "Tap minimum", value: Format.amps(group.tapMinAmps)),
            ]
            if let standard = group.nextStandardAmps {
                rows.insert(BranchRow(label: "Next standard device", value: "\(standard) A"), at: 2)
            }
            for (index, motor) in group.motors.enumerated() {
                rows.append(BranchRow(label: "Motor \(index + 1) load-side", value: "≥ \(Format.amps(motor.loadSideMinAmps))"))
            }
            let deviceText = group.nextStandardAmps.map { "\($0) A" } ?? Format.amps(group.rawAmps)
            return BranchScreenResult(
                headline: "Group device \(deviceText)",
                summary: "Group \(deviceText); tap ≥ \(Format.amps(group.tapMinAmps))",
                rows: rows,
                notes: group.notes + [group.formula],
                conductorMin: nil,
                conductorCapacity: nil
            )
        }
    }

    private func reset() {
        flc = ""
        groupFLCs = ""
        serviceFactor = ""
        session = ExplicitCalculationState()
    }

    private func applyExample() {
        if mode == .single {
            flc = "14"
            device = .inverseTimeBreaker
            motorType = .squirrelCageOther
            serviceFactor = ""
        } else {
            groupFLCs = "10, 8, 6"
            groupDevice = .inverseTimeBreaker
        }
        session = ExplicitCalculationState()
    }
}

private struct BranchRow: Equatable, Sendable {
    var label: String
    var value: String
}

private struct BranchScreenResult: Equatable, Sendable {
    var headline: String
    var summary: String
    var rows: [BranchRow]
    var notes: [String]
    var conductorMin: Double?
    var conductorCapacity: Double?
}
