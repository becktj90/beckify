import SwiftUI
import BeckifyMath

private enum LabPicture: String, CaseIterable, Identifiable, Hashable {
    case schematic
    case breadboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .schematic: return "Schematic"
        case .breadboard: return "Breadboard"
        }
    }
}

struct ElectronicsLabView: View {
    @StateObject private var model = ElectronicsLabModel()
    @EnvironmentObject private var jobs: JobStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var picture: LabPicture = .schematic

    var body: some View {
        ToolScaffold(
            toolID: .electronicsLab,
            stickyAnswer: model.solution?.headline,
            copyText: model.copyText
        ) {
            if let circuit = model.circuit {
                circuitScreen(circuit)
            } else {
                hub
            }
        }
    }

    private var hub: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text("Pick a circuit. The schematic, node voltages, and branch currents (A / mA / µA) update as you edit. Circuits that fit a solderless board also open a Breadboard with the whole board in view and on-board meters.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(ElectronicsFamily.allCases) { family in
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(family.title.uppercased())
                        .font(Theme.TypeRole.sectionLabel)
                        .tracking(0.8)
                        .foregroundStyle(Theme.muted)
                    ForEach(ElectronicsLab.circuits(in: family)) { info in
                        Button {
                            model.open(info.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(info.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Theme.foreground)
                                Text(info.blurb)
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Theme.Space.sm)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                    .stroke(Theme.border, lineWidth: Theme.Stroke.hairline)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("electronicsLab.circuit.\(info.id.rawValue)")
                    }
                }
            }
        }
        .accessibilityIdentifier("electronicsLab.hub")
    }

    private func circuitScreen(_ circuit: ElectronicsCircuit) -> some View {
        let info = ElectronicsLab.info(circuit)
        return VStack(alignment: .leading, spacing: Theme.Space.md) {
            Button {
                model.close()
            } label: {
                Label("All circuits", systemImage: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: Theme.touchTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accent)
            .accessibilityIdentifier("electronicsLab.back")

            Text(info.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.foreground)
            Text(info.blurb)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            unknownPicker(info)

            ForEach(ElectronicsLab.fields(for: circuit, unknown: model.unknown, inputs: model.values)) { field in
                if field.choices.isEmpty {
                    NumberField(
                        title: field.title,
                        unit: field.unit,
                        text: model.binding(field.id),
                        optional: field.optional,
                        allowsEngineering: true,
                        helpText: field.help.isEmpty ? nil : field.help,
                        fieldID: field.id,
                        spokenLabel: spokenAmplitude(field.id)
                    )
                    if let paired = LabSourceSpeech.pairedAmplitude(id: field.id, raw: model.values[field.id] ?? "") {
                        Text(paired)
                            .font(Theme.TypeRole.help)
                            .foregroundStyle(Theme.muted)
                            .accessibilityLabel(paired)
                    }
                } else {
                    choiceField(field)
                }
            }

            Text("Part values are yours to edit. Where a circuit has a source, switch DC or AC sine and set the magnitude. The transfer updates as you type.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("electronicsLab.editHint")

            if let errorMessage = model.errorMessage {
                ErrorText(message: errorMessage)
            }

            if let solution = model.solution {
                let breadboard = BreadboardLayouts.make(solution)
                if breadboard != nil {
                    Picker("View", selection: $picture) {
                        ForEach(LabPicture.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("electronicsLab.viewMode")
                }
                if picture == .breadboard, let breadboard {
                    BreadboardCard(layout: breadboard)
                } else {
                SchematicCard(
                    solution: solution,
                    pickedNodeID: model.pickedNodeID,
                    pickedBranchID: model.pickedBranchID,
                    reduceMotion: reduceMotion,
                    onPickNode: { model.pickedNodeID = $0; model.pickedBranchID = nil },
                    onPickBranch: { model.pickedBranchID = $0; model.pickedNodeID = nil }
                )
                }
                if let callout = model.callout {
                    Text(callout)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .accessibilityIdentifier("electronicsLab.callout")
                }
                LabResponseCard(io: solution.io)
                readingTable(title: "Nodes", rows: solution.nodes.map {
                    ($0.id, $0.name, labReading($0.value, unit: $0.unit))
                })
                readingTable(title: "Branches", rows: solution.branches.map {
                    ($0.id, $0.name, labReading($0.value, unit: $0.unit))
                })
                if !solution.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionLabel("Steps")
                        ForEach(Array(solution.steps.enumerated()), id: \.offset) { _, step in
                            Text(step)
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(Theme.foreground)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if let warning = solution.warning {
                    Text(warning)
                        .font(.footnote)
                        .foregroundStyle(Theme.warn)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("How it works")
                    ForEach(Array(solution.notes.prefix(4).enumerated()), id: \.offset) { _, note in
                        Text("• \(note)")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if BreadboardLayouts.supports(circuit) {
                        Text("• \(BreadboardLayouts.disclosure)")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                SaveJobBar(jobName: $model.jobName, canSave: true) {
                    save(info: info, solution: solution)
                }
            }
        }
        .onChange(of: model.circuit?.rawValue) { _, _ in
            picture = .schematic
        }
    }

    private func unknownPicker(_ info: ElectronicsCircuitInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Solve for")
            if info.unknowns.count <= 3 {
                Picker("Solve for", selection: model.unknownBinding) {
                    ForEach(info.unknowns) { item in
                        Text(item.title).tag(item.id)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("electronicsLab.unknown")
            } else {
                Picker("Solve for", selection: model.unknownBinding) {
                    ForEach(info.unknowns) { item in
                        Text(item.title).tag(item.id)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("electronicsLab.unknown")
            }
        }
    }

    private func spokenAmplitude(_ id: String) -> String? {
        switch id {
        case "vrms": return "Vrms, volts RMS"
        case "vp": return "Vp, volts peak"
        case "vdc": return "Vdc, volts DC"
        case "f": return "Frequency, hertz"
        default: return nil
        }
    }

    private func choiceAccessibilityLabel(_ field: LabField) -> String {
        guard field.id == "source" else { return field.title }
        let raw = model.values["source"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let spoken = LabSourceSpeech.kind(ac: raw != "dc")
        return "Source, \(spoken)"
    }

    private func choiceField(_ field: LabField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(field.title)
            Picker(field.title, selection: model.binding(field.id)) {
                ForEach(field.choices) { choice in
                    Text(choice.title).tag(choice.id)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("electronicsLab.choice.\(field.id)")
            .accessibilityLabel(choiceAccessibilityLabel(field))
            if !field.help.isEmpty {
                Text(field.help)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private func readingTable(title: String, rows: [(String, String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(title)
            ForEach(rows, id: \.0) { row in
                HStack(alignment: .firstTextBaseline) {
                    Text(row.1)
                        .foregroundStyle(Theme.muted)
                    Spacer(minLength: 8)
                    Text(row.2)
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(Theme.TypeRole.sectionLabel)
            .tracking(0.8)
            .foregroundStyle(Theme.muted)
    }

    private func save(info: ElectronicsCircuitInfo, solution: LabSolution) {
        var inputs = model.values
        inputs["circuit"] = info.id.rawValue
        inputs["unknown"] = model.unknown
        var outputs: [String: String] = ["headline": solution.headline]
        for quantity in solution.quantities {
            outputs[quantity.name] = labReading(quantity.value, unit: quantity.unit)
        }
        jobs.save(SavedJob(
            name: model.jobName,
            toolID: .electronicsLab,
            inputs: inputs,
            outputs: outputs
        ))
    }
}

private func labReading(_ value: Double, unit: String) -> String {
    switch unit {
    case "V": return Format.volts(value)
    case "A": return Format.amps(value)
    case "W": return Format.watts(value)
    case "Ω", "ohm", "Ohms": return Format.si(value, unit: "Ω")
    case "F": return Format.si(value, unit: "F")
    case "H": return Format.si(value, unit: "H")
    case "Hz": return Format.frequency(value)
    case "s": return value > 0 ? Format.time(value) : Format.number(value, digits: 4) + " s"
    case "°": return Format.degrees(value)
    case "%": return Format.percent(value)
    case "m": return Format.meters(value)
    default:
        let number = Format.number(value, digits: 4)
        return unit.isEmpty ? number : "\(number) \(unit)"
    }
}

// MARK: - Session

@MainActor
final class ElectronicsLabModel: ObservableObject {
    @Published private(set) var circuit: ElectronicsCircuit?
    @Published private(set) var unknown: String = ""
    @Published private(set) var values: [String: String] = [:]
    @Published private(set) var solution: LabSolution?
    @Published private(set) var errorMessage: String?
    @Published var pickedNodeID: String?
    @Published var pickedBranchID: String?
    @Published var jobName: String = "Electronics lab"

    func open(_ circuit: ElectronicsCircuit) {
        let info = ElectronicsLab.info(circuit)
        let draft = DraftStore.load(circuit) ?? Draft(unknown: info.defaultUnknown, values: info.defaults, jobName: "\(info.title) note")
        self.circuit = circuit
        unknown = info.unknowns.contains(where: { $0.id == draft.unknown }) ? draft.unknown : info.defaultUnknown
        values = info.defaults.merging(draft.values) { draft, _ in draft }
        jobName = draft.jobName
        pickedNodeID = nil
        pickedBranchID = nil
        resolve()
    }

    func close() {
        circuit = nil
        solution = nil
        errorMessage = nil
    }

    var unknownBinding: Binding<String> {
        Binding(get: { self.unknown }, set: { self.setUnknown($0) })
    }

    func binding(_ id: String) -> Binding<String> {
        Binding(
            get: { self.values[id] ?? "" },
            set: { self.setValue(id, $0) }
        )
    }

    func setUnknown(_ id: String) {
        unknown = id
        pickedNodeID = nil
        pickedBranchID = nil
        resolve()
    }

    func setValue(_ id: String, _ text: String) {
        values[id] = text
        resolve()
    }

    var callout: String? {
        guard let solution else { return nil }
        if let id = pickedNodeID, let node = solution.node(id) {
            return "\(node.name)  \(labReading(node.value, unit: node.unit))"
        }
        if let id = pickedBranchID, let branch = solution.branch(id) {
            return "\(branch.name)  \(labReading(branch.value, unit: branch.unit))"
        }
        return nil
    }

    var copyText: String? {
        guard let solution else { return nil }
        let emphasized = solution.quantities.filter(\.emphasis).map {
            "\($0.name) \(labReading($0.value, unit: $0.unit))"
        }
        if emphasized.isEmpty { return solution.headline }
        return ([solution.headline] + emphasized).joined(separator: "  ·  ")
    }

    private func resolve() {
        guard let circuit else { return }
        do {
            solution = try ElectronicsLab.solve(circuit, unknown: unknown, inputs: values)
            errorMessage = nil
        } catch let error as CalcError {
            solution = nil
            errorMessage = error.message
        } catch {
            solution = nil
            errorMessage = "Could not solve this circuit."
        }
        DraftStore.save(circuit, Draft(unknown: unknown, values: values, jobName: jobName))
    }
}

private struct Draft: Codable {
    var unknown: String
    var values: [String: String]
    var jobName: String
}

private enum DraftStore {
    static func load(_ circuit: ElectronicsCircuit) -> Draft? {
        guard let data = UserDefaults.standard.data(forKey: key(circuit)) else { return nil }
        return try? JSONDecoder().decode(Draft.self, from: data)
    }

    static func save(_ circuit: ElectronicsCircuit, _ draft: Draft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: key(circuit))
    }

    private static func key(_ circuit: ElectronicsCircuit) -> String {
        ToolInputStore.key(.electronicsLab, "draft.\(circuit.rawValue)")
    }
}

// MARK: - Schematic

private struct LabResponseCard: View {
    let io: LabIO

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("TRANSFER")
                .font(Theme.TypeRole.sectionLabel)
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
            transferLine
            if let evaluated = io.evaluated, !evaluated.isEmpty {
                Text("= \(evaluated)")
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
            }
            if !io.detail.isEmpty {
                Text(io.detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(io.plots) { plot in
                DiagramCard(
                    title: plot.title,
                    accessibilitySummary: plotSummary(plot),
                    exportName: "electronics-lab-\(plot.id)"
                ) {
                    EngineerLinePlot(
                        series: plot.series.enumerated().map { index, series in
                            EngineerSeries(
                                name: series.name,
                                points: series.points,
                                color: labTraceColor(index),
                                fills: index == 0 && plot.series.count == 1
                            )
                        },
                        xLabel: plot.xLabel,
                        yLabel: plot.yLabel,
                        xGuides: plot.xGuide.map { [EngineerGuide(value: $0, label: plot.xGuideLabel, axis: .x)] } ?? [],
                        yGuides: plot.showZero ? [EngineerGuide(value: 0, label: "0", axis: .y)] : [],
                        logX: plot.logX,
                        smooth: plot.smooth
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var transferLine: some View {
        if let tex = io.expressionTeX, let math = LabMath.parse(tex) {
            LabMathView(math: math)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(io.expression)
                .accessibilityIdentifier("electronicsLab.transfer")
        } else {
            Text(io.expression)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(io.expression)
                .accessibilityIdentifier("electronicsLab.transfer")
        }
    }

    private func plotSummary(_ plot: LabPlot) -> String {
        "\(plot.title). \(plot.yLabel) versus \(plot.xLabel). \(io.expression)"
    }
}

private func labTraceColor(_ index: Int) -> Color {
    switch index {
    case 0: return Theme.chartPrimary
    case 1: return Theme.chartSecondary
    case 2: return Theme.chartTertiary
    default: return Theme.good
    }
}

private struct SchematicCard: View {
    var solution: LabSolution
    var pickedNodeID: String?
    var pickedBranchID: String?
    var reduceMotion: Bool
    var onPickNode: (String) -> Void
    var onPickBranch: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("SCHEMATIC")
                    .font(Theme.TypeRole.sectionLabel)
                    .tracking(0.8)
                    .foregroundStyle(Theme.muted)
                Spacer(minLength: 8)
                PlotFullscreenControl(title: "Schematic", plotName: "schematic") {
                    TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { timeline in
                        let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
                        schematic(phase: phase)
                            .frame(minHeight: 420)
                    }
                    Text("Node voltages and branch currents sit on the drawing. Tap a node or branch to highlight. This is a schematic, not an X–Y plot.")
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                }
            }
            Text("Node volts and branch currents (A / mA / µA) are labeled on the schematic.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { timeline in
                let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
                schematic(phase: phase)
            }
        }
    }

    private func schematic(phase: Double) -> some View {
        GeometryReader { geo in
            Canvas { context, size in
                SchematicDraw.paint(
                    solution: solution,
                    in: context,
                    size: size,
                    phase: phase,
                    pickedNodeID: pickedNodeID,
                    pickedBranchID: pickedBranchID
                )
            }
            .gesture(
                SpatialTapGesture().onEnded { value in
                    let hit = SchematicDraw.hit(
                        solution: solution,
                        at: value.location,
                        size: geo.size
                    )
                    switch hit {
                    case .node(let id): onPickNode(id)
                    case .branch(let id): onPickBranch(id)
                    case .none: break
                    }
                }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
        }
        .aspectRatio(LabCanvas.width / LabCanvas.height, contentMode: .fit)
        .background(Theme.inputFill, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .stroke(Theme.border, lineWidth: Theme.Stroke.hairline)
        )
    }

    private var accessibilitySummary: String {
        let nodes = solution.nodes.map { "\($0.name) \(labReading($0.value, unit: $0.unit))" }.joined(separator: ", ")
        let branches = solution.branches.map { "\($0.name) \(labReading($0.value, unit: $0.unit))" }.joined(separator: ", ")
        let sources = LabSourceSpeech.schematicSummary(solution.elements)
        if sources.isEmpty {
            return "Schematic. Nodes: \(nodes). Branches: \(branches)."
        }
        return "Schematic. \(sources). Nodes: \(nodes). Branches: \(branches)."
    }
}

private enum SchematicHit {
    case node(String)
    case branch(String)
    case none
}

private enum SchematicDraw {
    static func paint(
        solution: LabSolution,
        in context: GraphicsContext,
        size: CGSize,
        phase: Double,
        pickedNodeID: String?,
        pickedBranchID: String?
    ) {
        for element in solution.elements where element.part == .wire || element.part == .line {
            strokeElement(element, in: context, size: size, emphasized: false)
        }
        for element in solution.elements where element.part != .wire && element.part != .line {
            strokeElement(element, in: context, size: size, emphasized: false)
            label(element, in: context, size: size)
        }
        for branch in solution.branches {
            drawCurrent(
                branch,
                in: context,
                size: size,
                phase: phase,
                emphasized: branch.id == pickedBranchID
            )
        }
        for node in solution.nodes {
            drawNode(node, in: context, size: size, emphasized: node.id == pickedNodeID)
        }
    }

    static func hit(solution: LabSolution, at point: CGPoint, size: CGSize) -> SchematicHit {
        var bestNode: (String, CGFloat)?
        for node in solution.nodes {
            let distance = hypot(map(node.at, size).x - point.x, map(node.at, size).y - point.y)
            if distance < 22, bestNode == nil || distance < bestNode!.1 {
                bestNode = (node.id, distance)
            }
        }
        if let bestNode { return .node(bestNode.0) }
        var bestBranch: (String, CGFloat)?
        for branch in solution.branches {
            let distance = pointToSegment(point, map(branch.a, size), map(branch.b, size))
            if distance < 18, bestBranch == nil || distance < bestBranch!.1 {
                bestBranch = (branch.id, distance)
            }
        }
        if let bestBranch { return .branch(bestBranch.0) }
        return .none
    }

    private static func strokeElement(_ element: LabElement, in context: GraphicsContext, size: CGSize, emphasized: Bool) {
        let a = map(element.a, size)
        let b = map(element.b, size)
        var path = Path()
        switch element.part {
        case .wire:
            path.move(to: a)
            path.addLine(to: b)
            stroke(path, in: context, color: Theme.foreground, width: 1.6)
        case .line:
            transmission(from: a, to: b, into: &path)
            stroke(path, in: context, color: Theme.accent, width: 1.6)
        case .resistor:
            zigzag(from: a, to: b, into: &path)
            stroke(path, in: context, color: Theme.foreground, width: 1.7)
        case .capacitor:
            capacitor(from: a, to: b, into: &path)
            stroke(path, in: context, color: Theme.foreground, width: 1.7)
        case .inductor:
            inductor(from: a, to: b, into: &path)
            stroke(path, in: context, color: Theme.foreground, width: 1.7)
        case .voltageSource:
            source(from: a, to: b, ac: element.flags & LabSourceSpeech.acSineFlag != 0, into: &path)
            stroke(path, in: context, color: Theme.accent, width: 1.7)
        case .diode:
            diode(from: a, to: b, led: false, into: &path)
            stroke(path, in: context, color: Theme.foreground, width: 1.7)
        case .led:
            diode(from: a, to: b, led: true, into: &path)
            stroke(path, in: context, color: Theme.energized, width: 1.7)
        case .ground:
            ground(at: a, into: &path)
            stroke(path, in: context, color: Theme.foreground, width: 1.7)
        case .npn:
            npn(at: a, into: &path)
            stroke(path, in: context, color: Theme.foreground, width: 1.7)
        case .nmos:
            mosfet(at: a, pChannel: false, into: &path)
            stroke(path, in: context, color: Theme.foreground, width: 1.7)
        case .pmos:
            mosfet(at: a, pChannel: true, into: &path)
            stroke(path, in: context, color: Theme.foreground, width: 1.7)
        case .opAmp:
            opAmp(at: a, in: context, size: size)
        case .timer555:
            chip(at: a, title: "555", in: context, size: size)
        case .sevenSegment:
            seven(at: a, flags: element.flags, in: context, size: size)
        case .zBlock:
            block(from: a, to: b, in: context, size: size)
        }
        _ = emphasized
    }

    private static func label(_ element: LabElement, in context: GraphicsContext, size: CGSize) {
        guard !element.label.isEmpty || !element.detail.isEmpty else { return }
        let a = map(element.a, size)
        let b = map(element.b, size)
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let delta = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let length = max(hypot(delta.x, delta.y), 1)
        let normal = CGPoint(x: -delta.y / length, y: delta.x / length)
        let point = CGPoint(x: mid.x + normal.x * 12, y: mid.y + normal.y * 12)
        let text = [element.label, element.detail].filter { !$0.isEmpty }.joined(separator: " ")
        let resolved = context.resolve(
            Text(text).font(.system(size: 10, weight: .medium)).foregroundColor(Theme.muted)
        )
        context.draw(resolved, at: point, anchor: .center)
    }

    private static func drawNode(_ node: LabNode, in context: GraphicsContext, size: CGSize, emphasized: Bool) {
        let center = map(node.at, size)
        let radius: CGFloat = emphasized ? 6 : 4.5
        let dot = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.fill(dot, with: .color(emphasized ? Theme.good : Theme.accent))
        let reading = labReading(node.value, unit: node.unit)
        let resolved = context.resolve(
            Text("\(node.name) \(reading)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(emphasized ? Theme.good : Theme.foreground)
        )
        context.draw(resolved, at: CGPoint(x: center.x, y: center.y - 12), anchor: .bottom)
    }

    private static func drawCurrent(
        _ branch: LabBranch,
        in context: GraphicsContext,
        size: CGSize,
        phase: Double,
        emphasized: Bool
    ) {
        guard abs(branch.value) > 1e-15 || branch.unit.isEmpty else { return }
        let start = map(branch.value >= 0 ? branch.a : branch.b, size)
        let end = map(branch.value >= 0 ? branch.b : branch.a, size)
        let delta = CGPoint(x: end.x - start.x, y: end.y - start.y)
        let length = hypot(delta.x, delta.y)
        guard length > 8 else { return }
        let unit = CGPoint(x: delta.x / length, y: delta.y / length)
        let headAt = CGPoint(x: start.x + delta.x * 0.72, y: start.y + delta.y * 0.72)
        var head = Path()
        arrowHead(into: &head, tip: headAt, dir: unit, size: emphasized ? 11 : 8)
        context.fill(head, with: .color(Theme.energized))
        let travel = CGFloat(phase)
        let dotCenter = CGPoint(x: start.x + delta.x * travel, y: start.y + delta.y * travel)
        let dot = Path(ellipseIn: CGRect(x: dotCenter.x - 3, y: dotCenter.y - 3, width: 6, height: 6))
        context.fill(dot, with: .color(Theme.energized.opacity(0.9)))
        let normal = CGPoint(x: -unit.y, y: unit.x)
        let labelAt = CGPoint(
            x: start.x + delta.x * 0.45 + normal.x * 11,
            y: start.y + delta.y * 0.45 + normal.y * 11
        )
        let unitText = branch.unit.isEmpty ? "" : branch.unit
        let reading = labReading(abs(branch.value), unit: unitText.isEmpty ? "A" : unitText)
        let label = "\(branch.name) \(reading)"
        let resolved = context.resolve(
            Text(label)
                .font(.system(size: emphasized ? 11 : 10, weight: .semibold).monospacedDigit())
                .foregroundColor(emphasized ? Theme.good : Theme.energized)
        )
        context.draw(resolved, at: labelAt, anchor: .center)
    }

    private static func stroke(_ path: Path, in context: GraphicsContext, color: Color, width: CGFloat) {
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private static func map(_ point: LabPoint, _ size: CGSize) -> CGPoint {
        CGPoint(
            x: point.x / LabCanvas.width * size.width,
            y: point.y / LabCanvas.height * size.height
        )
    }

    private static func axis(from a: CGPoint, to b: CGPoint) -> (unit: CGPoint, normal: CGPoint, length: CGFloat)? {
        let delta = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let length = hypot(delta.x, delta.y)
        guard length > 1 else { return nil }
        let unit = CGPoint(x: delta.x / length, y: delta.y / length)
        let normal = CGPoint(x: -unit.y, y: unit.x)
        return (unit, normal, length)
    }

    private static func zigzag(from a: CGPoint, to b: CGPoint, into path: inout Path) {
        guard let axis = axis(from: a, to: b) else { return }
        let lead = axis.length * 0.16
        let span = axis.length - 2 * lead
        let teeth = 6
        let amp = min(7, span * 0.16)
        path.move(to: a)
        let start = CGPoint(x: a.x + axis.unit.x * lead, y: a.y + axis.unit.y * lead)
        path.addLine(to: start)
        for index in 0...teeth {
            let t = CGFloat(index) / CGFloat(teeth)
            let along = CGPoint(x: start.x + axis.unit.x * span * t, y: start.y + axis.unit.y * span * t)
            let sign: CGFloat = (index == 0 || index == teeth) ? 0 : (index % 2 == 0 ? 1 : -1)
            path.addLine(to: CGPoint(x: along.x + axis.normal.x * amp * sign, y: along.y + axis.normal.y * amp * sign))
        }
        path.addLine(to: b)
    }

    private static func capacitor(from a: CGPoint, to b: CGPoint, into path: inout Path) {
        guard let axis = axis(from: a, to: b) else { return }
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let gap: CGFloat = 5
        let plate = min(12, axis.length * 0.35)
        let left = CGPoint(x: mid.x - axis.unit.x * gap, y: mid.y - axis.unit.y * gap)
        let right = CGPoint(x: mid.x + axis.unit.x * gap, y: mid.y + axis.unit.y * gap)
        path.move(to: a)
        path.addLine(to: left)
        path.move(to: right)
        path.addLine(to: b)
        path.move(to: CGPoint(x: left.x + axis.normal.x * plate, y: left.y + axis.normal.y * plate))
        path.addLine(to: CGPoint(x: left.x - axis.normal.x * plate, y: left.y - axis.normal.y * plate))
        path.move(to: CGPoint(x: right.x + axis.normal.x * plate, y: right.y + axis.normal.y * plate))
        path.addLine(to: CGPoint(x: right.x - axis.normal.x * plate, y: right.y - axis.normal.y * plate))
    }

    private static func inductor(from a: CGPoint, to b: CGPoint, into path: inout Path) {
        guard let axis = axis(from: a, to: b) else { return }
        let lead = axis.length * 0.14
        let span = axis.length - 2 * lead
        let bumps = 4
        let radius = span / CGFloat(bumps) / 2
        path.move(to: a)
        let start = CGPoint(x: a.x + axis.unit.x * lead, y: a.y + axis.unit.y * lead)
        path.addLine(to: start)
        let base = atan2(axis.unit.y, axis.unit.x)
        for index in 0..<bumps {
            let center = CGPoint(
                x: start.x + axis.unit.x * (radius + CGFloat(index) * radius * 2),
                y: start.y + axis.unit.y * (radius + CGFloat(index) * radius * 2)
            )
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .radians(base + .pi),
                endAngle: .radians(base),
                clockwise: false
            )
        }
        path.addLine(to: b)
    }

    private static func source(from a: CGPoint, to b: CGPoint, ac: Bool, into path: inout Path) {
        guard let axis = axis(from: a, to: b) else { return }
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let radius = min(11, axis.length * 0.28)
        path.move(to: a)
        path.addLine(to: CGPoint(x: mid.x - axis.unit.x * radius, y: mid.y - axis.unit.y * radius))
        path.addEllipse(in: CGRect(x: mid.x - radius, y: mid.y - radius, width: radius * 2, height: radius * 2))
        path.move(to: CGPoint(x: mid.x + axis.unit.x * radius, y: mid.y + axis.unit.y * radius))
        path.addLine(to: b)
        if ac {
            let perp = CGPoint(x: -axis.unit.y, y: axis.unit.x)
            let samples = 8
            let amp = radius * 0.42
            let span = radius * 1.35
            for index in 0...samples {
                let t = CGFloat(index) / CGFloat(samples)
                let along = (t - 0.5) * span
                let wave = sin(t * 2 * .pi) * amp
                let point = CGPoint(
                    x: mid.x + axis.unit.x * along + perp.x * wave,
                    y: mid.y + axis.unit.y * along + perp.y * wave
                )
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        } else {
            let plus = CGPoint(x: mid.x - axis.unit.x * radius * 0.45, y: mid.y - axis.unit.y * radius * 0.45)
            path.move(to: CGPoint(x: plus.x - 3, y: plus.y))
            path.addLine(to: CGPoint(x: plus.x + 3, y: plus.y))
            path.move(to: CGPoint(x: plus.x, y: plus.y - 3))
            path.addLine(to: CGPoint(x: plus.x, y: plus.y + 3))
            let minus = CGPoint(x: mid.x + axis.unit.x * radius * 0.45, y: mid.y + axis.unit.y * radius * 0.45)
            path.move(to: CGPoint(x: minus.x - 3, y: minus.y))
            path.addLine(to: CGPoint(x: minus.x + 3, y: minus.y))
        }
    }

    private static func diode(from a: CGPoint, to b: CGPoint, led: Bool, into path: inout Path) {
        guard let axis = axis(from: a, to: b) else { return }
        let lead = axis.length * 0.22
        let base = CGPoint(x: a.x + axis.unit.x * lead, y: a.y + axis.unit.y * lead)
        let tip = CGPoint(x: b.x - axis.unit.x * lead, y: b.y - axis.unit.y * lead)
        let amp = min(9, axis.length * 0.22)
        path.move(to: a)
        path.addLine(to: base)
        path.move(to: tip)
        path.addLine(to: b)
        path.move(to: CGPoint(x: base.x + axis.normal.x * amp, y: base.y + axis.normal.y * amp))
        path.addLine(to: tip)
        path.addLine(to: CGPoint(x: base.x - axis.normal.x * amp, y: base.y - axis.normal.y * amp))
        path.closeSubpath()
        path.move(to: CGPoint(x: tip.x + axis.normal.x * amp, y: tip.y + axis.normal.y * amp))
        path.addLine(to: CGPoint(x: tip.x - axis.normal.x * amp, y: tip.y - axis.normal.y * amp))
        if led {
            let corner = CGPoint(x: tip.x - axis.normal.x * amp * 0.2, y: tip.y - axis.normal.y * amp * 0.2)
            for index in 0..<2 {
                let shift = CGFloat(index) * 4
                let tail = CGPoint(x: corner.x + axis.normal.x * shift, y: corner.y + axis.normal.y * shift)
                let head = CGPoint(x: tail.x + axis.normal.x * 7 - axis.unit.x * 2, y: tail.y + axis.normal.y * 7 - axis.unit.y * 2)
                path.move(to: tail)
                path.addLine(to: head)
            }
        }
    }

    private static func ground(at a: CGPoint, into path: inout Path) {
        path.move(to: a)
        path.addLine(to: CGPoint(x: a.x, y: a.y + 6))
        for (index, width) in [14.0, 9.0, 4.0].enumerated() {
            let y = a.y + 6 + CGFloat(index) * 4
            path.move(to: CGPoint(x: a.x - width / 2, y: y))
            path.addLine(to: CGPoint(x: a.x + width / 2, y: y))
        }
    }

    private static func npn(at c: CGPoint, into path: inout Path) {
        path.move(to: CGPoint(x: c.x - 16, y: c.y))
        path.addLine(to: CGPoint(x: c.x - 4, y: c.y))
        path.move(to: CGPoint(x: c.x - 4, y: c.y - 12))
        path.addLine(to: CGPoint(x: c.x - 4, y: c.y + 12))
        path.move(to: CGPoint(x: c.x - 4, y: c.y - 6))
        path.addLine(to: CGPoint(x: c.x + 10, y: c.y - 16))
        path.move(to: CGPoint(x: c.x - 4, y: c.y + 6))
        path.addLine(to: CGPoint(x: c.x + 10, y: c.y + 16))
        arrowHead(into: &path, tip: CGPoint(x: c.x + 10, y: c.y + 16), dir: CGPoint(x: 0.62, y: 0.78), size: 7)
    }

    private static func mosfet(at c: CGPoint, pChannel: Bool, into path: inout Path) {
        path.move(to: CGPoint(x: c.x - 18, y: c.y))
        path.addLine(to: CGPoint(x: c.x - 8, y: c.y))
        if pChannel {
            path.addEllipse(in: CGRect(x: c.x - 12, y: c.y - 2.5, width: 5, height: 5))
        }
        path.move(to: CGPoint(x: c.x - 8, y: c.y - 12))
        path.addLine(to: CGPoint(x: c.x - 8, y: c.y + 12))
        for offset in [-8.0, 0.0, 8.0] {
            path.move(to: CGPoint(x: c.x - 4, y: c.y + offset - 3))
            path.addLine(to: CGPoint(x: c.x - 4, y: c.y + offset + 3))
        }
        path.move(to: CGPoint(x: c.x - 4, y: c.y - 8))
        path.addLine(to: CGPoint(x: c.x + 12, y: c.y - 8))
        path.addLine(to: CGPoint(x: c.x + 12, y: c.y - 18))
        path.move(to: CGPoint(x: c.x - 4, y: c.y + 8))
        path.addLine(to: CGPoint(x: c.x + 8, y: c.y + 8))
        path.addLine(to: CGPoint(x: c.x + 8, y: c.y + 18))
        let dir = pChannel ? CGPoint(x: -1.0, y: 0.0) : CGPoint(x: 1.0, y: 0.0)
        arrowHead(into: &path, tip: CGPoint(x: c.x + (pChannel ? -4 : 6), y: c.y + 8), dir: dir, size: 6)
    }

    private static func opAmp(at c: CGPoint, in context: GraphicsContext, size: CGSize) {
        let w = min(size.width, size.height) * 0.16
        let h = w * 1.15
        var path = Path()
        path.move(to: CGPoint(x: c.x - w * 0.55, y: c.y - h * 0.55))
        path.addLine(to: CGPoint(x: c.x - w * 0.55, y: c.y + h * 0.55))
        path.addLine(to: CGPoint(x: c.x + w * 0.7, y: c.y))
        path.closeSubpath()
        stroke(path, in: context, color: Theme.accent, width: 1.7)
        let plus = context.resolve(Text("+").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.accent))
        let minus = context.resolve(Text("−").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.accent))
        context.draw(plus, at: CGPoint(x: c.x - w * 0.28, y: c.y - h * 0.22), anchor: .center)
        context.draw(minus, at: CGPoint(x: c.x - w * 0.28, y: c.y + h * 0.22), anchor: .center)
    }

    private static func chip(at c: CGPoint, title: String, in context: GraphicsContext, size: CGSize) {
        let w = min(size.width * 0.28, 78)
        let h = min(size.height * 0.46, 92)
        let rect = CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)
        let path = Path(roundedRect: rect, cornerRadius: 6)
        stroke(path, in: context, color: Theme.accent, width: 1.7)
        let text = context.resolve(Text(title).font(.system(size: 13, weight: .bold)).foregroundColor(Theme.foreground))
        context.draw(text, at: c, anchor: .center)
    }

    private static func block(from a: CGPoint, to b: CGPoint, in context: GraphicsContext, size: CGSize) {
        guard let axis = axis(from: a, to: b) else { return }
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let w = max(28, axis.length * 0.55)
        let h: CGFloat = 22
        let rect = CGRect(x: mid.x - w / 2, y: mid.y - h / 2, width: w, height: h)
        stroke(Path(roundedRect: rect, cornerRadius: 4), in: context, color: Theme.accent, width: 1.6)
        _ = size
    }

    private static func seven(at c: CGPoint, flags: Int, in context: GraphicsContext, size: CGSize) {
        let s = min(size.width, size.height) * 0.16
        let t = max(3, s * 0.16)
        func segment(_ on: Bool, _ rect: CGRect) {
            let path = Path(roundedRect: rect, cornerRadius: t / 2)
            context.fill(path, with: .color(on ? Theme.energized : Theme.border))
        }
        let x = c.x
        let y = c.y
        segment(flags & 1 != 0, CGRect(x: x - s * 0.35, y: y - s * 0.95, width: s * 0.7, height: t))
        segment(flags & 2 != 0, CGRect(x: x + s * 0.35, y: y - s * 0.85, width: t, height: s * 0.75))
        segment(flags & 4 != 0, CGRect(x: x + s * 0.35, y: y + s * 0.1, width: t, height: s * 0.75))
        segment(flags & 8 != 0, CGRect(x: x - s * 0.35, y: y + s * 0.8, width: s * 0.7, height: t))
        segment(flags & 16 != 0, CGRect(x: x - s * 0.5, y: y + s * 0.1, width: t, height: s * 0.75))
        segment(flags & 32 != 0, CGRect(x: x - s * 0.5, y: y - s * 0.85, width: t, height: s * 0.75))
        segment(flags & 64 != 0, CGRect(x: x - s * 0.35, y: y - t / 2, width: s * 0.7, height: t))
    }

    private static func transmission(from a: CGPoint, to b: CGPoint, into path: inout Path) {
        guard let axis = axis(from: a, to: b) else { return }
        let gap: CGFloat = 3.5
        for sign in [-1.0, 1.0] as [CGFloat] {
            let ox = axis.normal.x * gap * sign
            let oy = axis.normal.y * gap * sign
            path.move(to: CGPoint(x: a.x + ox, y: a.y + oy))
            path.addLine(to: CGPoint(x: b.x + ox, y: b.y + oy))
        }
    }

    private static func arrowHead(into path: inout Path, tip: CGPoint, dir: CGPoint, size: CGFloat) {
        let length = max(hypot(dir.x, dir.y), 0.001)
        let unit = CGPoint(x: dir.x / length, y: dir.y / length)
        let normal = CGPoint(x: -unit.y, y: unit.x)
        let back = CGPoint(x: tip.x - unit.x * size, y: tip.y - unit.y * size)
        path.move(to: tip)
        path.addLine(to: CGPoint(x: back.x + normal.x * size * 0.55, y: back.y + normal.y * size * 0.55))
        path.addLine(to: CGPoint(x: back.x - normal.x * size * 0.55, y: back.y - normal.y * size * 0.55))
        path.closeSubpath()
    }

    private static func pointToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let length2 = ab.x * ab.x + ab.y * ab.y
        if length2 < 1 { return hypot(p.x - a.x, p.y - a.y) }
        let t = min(1, max(0, ((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / length2))
        let x = a.x + ab.x * t
        let y = a.y + ab.y * t
        return hypot(p.x - x, p.y - y)
    }
}
