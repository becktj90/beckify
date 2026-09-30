import SwiftUI
import BeckifyMath

struct CableLadderView: View {
    private struct CableRow: Identifiable, Codable, Equatable {
        var id: UUID
        var qty: String
        var entry: String
        var size: String
        var insulation: String
        var material: String
        var od: String
        var weight: String
        var role: String

        static func phase(_ role: CableLadderCableRole, qty: String = "3") -> CableRow {
            CableRow(
                id: UUID(),
                qty: qty,
                entry: "size",
                size: "500",
                insulation: ConductorInsulationKind.thhn.rawValue,
                material: ConductorMaterial.copper.rawValue,
                od: "1.25",
                weight: "",
                role: role.rawValue
            )
        }
    }

    private enum EntryKind: String, CaseIterable, Identifiable {
        case size
        case od
        var id: String { rawValue }
        var displayName: String { self == .size ? "AWG / kcmil" : "Overall OD" }
    }

    @EnvironmentObject private var jobs: JobStore
    @StoredChoice(.cableLadder, "tray", default: CableLadderTrayType.ladder) private var trayType
    @StoredChoice(.cableLadder, "cover", default: CableLadderCover.none) private var cover
    @StoredChoice(.cableLadder, "contents", default: CableLadderContents.singleConductor) private var contents
    @StoredInput(.cableLadder, "width", default: "12") private var width
    @StoredInput(.cableLadder, "depth", default: "4") private var depth
    @StoredInput(.cableLadder, "rung", default: "9") private var rung
    @StoredInput(.cableLadder, "length", default: "80") private var length
    @StoredChoice(.cableLadder, "rail", default: CableLadderRailMaterial.steel) private var rail
    @StoredChoice(.cableLadder, "environment", default: CableLadderEnvironment.indoorDry) private var environment
    @StoredChoice(.cableLadder, "orientation", default: CableLadderOrientation.horizontal) private var orientation
    @StoredInput(.cableLadder, "span", default: "8") private var span
    @StoredInput(.cableLadder, "ambient", default: "30") private var ambient
    @StoredToggle(.cableLadder, "shielded", default: false) private var shielded
    @StoredToggle(.cableLadder, "divider", default: false) private var divider
    @StoredToggle(.cableLadder, "exposed", default: false) private var exposedRun
    @StoredToggle(.cableLadder, "whip", default: false) private var flexibleDrop
    @StoredToggle(.cableLadder, "tint", default: true) private var tintByRole
    @StoredChoice(.cableLadder, "colors", default: CableLadderColorSystem.low120) private var colorSystem
    @StoredInput(.cableLadder, "cables", default: "") private var cablesJSON
    @StoredInput(.cableLadder, "jobName", default: "Cable ladder") private var jobName
    @State private var session = ExplicitCalculationState<CableLadderResult>()
    @State private var rows: [CableRow] = CableLadderView.defaultRows()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String {
        let cables = rows.map {
            "\($0.qty):\($0.entry):\($0.size):\($0.insulation):\($0.material):\($0.od):\($0.weight):\($0.role)"
        }.joined(separator: ",")
        return "\(trayType)|\(cover)|\(contents)|\(width)|\(depth)|\(rung)|\(length)|\(rail)|\(environment)|\(orientation)|\(span)|\(ambient)|\(shielded)|\(divider)|\(exposedRun)|\(flexibleDrop)|\(tintByRole)|\(colorSystem)|\(cables)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .cableLadder,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .cableLadder,
                symbolic: "fill % = cable area / Article 392 allowable",
                substituted: substituted,
                meaning: "Eighty percent of the cited limit is a warning. Over one hundred percent fails. A cable that does not fit in the width or depth fails even when the area percent is low. Phase colors are a legend, not a jacket.",
                citation: "NEC Article 392 (Tables 392.22(A), 392.22(A)(5), 392.22(B)(1); 392.10; 392.30; 392.60) and 336.10(7) for TC-ER. Areas from Chapter 9 Table 5. NEMA VE 1 class letters and NEMA 250 / IP words match Reference Library. Planning estimate — confirm the code book, the manufacturer load table, and the AHJ.",
                referenceTool: .equipmentGround
            )

            MenuField(title: "Tray type", selection: $trayType, options: CableLadderTrayType.allCases) { $0.displayName }
            MenuField(title: "Cover", selection: $cover, options: CableLadderCover.allCases) { $0.displayName }
            MenuField(title: "What is in the tray", selection: $contents, options: CableLadderContents.allCases) { $0.displayName }
            Text("Type and cover pick the Article 392 column. A solid cover on ladder or ventilated trough uses the solid-bottom areas as a planning treatment. Confirm the listing.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            NumberField(title: "Inside width", unit: "in", text: $width, fieldID: "width", onSubmit: calculate)
            NumberField(title: "Usable depth", unit: "in", text: $depth, fieldID: "depth", onSubmit: calculate)
            NumberField(title: "Rung spacing", unit: "in", text: $rung, fieldID: "rung", onSubmit: calculate)
            NumberField(title: "Run length", unit: "ft", text: $length, fieldID: "length", onSubmit: calculate)
            NumberField(title: "Support span", unit: "ft", text: $span, fieldID: "span", onSubmit: calculate)
            NumberField(title: "Ambient", unit: "°C", text: $ambient, fieldID: "ambient", onSubmit: calculate)
            MenuField(title: "Rail material", selection: $rail, options: CableLadderRailMaterial.allCases) { $0.displayName }
            MenuField(title: "Where it is mounted", selection: $environment, options: CableLadderEnvironment.allCases) { $0.displayName }
            MenuField(title: "Run", selection: $orientation, options: CableLadderOrientation.allCases) { $0.displayName }

            Text("CABLES")
                .font(Theme.TypeRole.fieldLabel)
                .tracking(0.6)
                .foregroundStyle(Theme.muted)
            ForEach($rows) { $row in
                cableRow($row)
            }
            Button {
                rows.append(CableRow.phase(.unmarked, qty: "1"))
                persistRows()
            } label: {
                Label("Add cable row", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
            }
            .buttonStyle(.bordered)

            Toggle("Tint circles by phase, neutral, and EGC", isOn: $tintByRole)
            MenuField(title: "Color convention", selection: $colorSystem, options: CableLadderColorSystem.allCases) { $0.displayName }
            Text("Convention aid only. Same names as Reference Library conductor colors. A tray-cable jacket is often black. Turn the tint off to draw every circle the same. Letters stay either way.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("Shielded cable (12× OD bend note)", isOn: $shielded)
            Toggle("Barrier between power and control", isOn: $divider)
            Toggle("Exposed run off the tray (TC-ER)", isOn: $exposedRun)
            Toggle("Flexible drop to equipment", isOn: $flexibleDrop)

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: applyExample,
                exampleTitle: "Three 500 kcmil per phase, 12 in ladder"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let result = session.displayedResult {
                resultBody(result)
                    .opacity(session.isStale ? 0.72 : 1)
            }
        }
        .onAppear(perform: loadRows)
        .onChange(of: inputFingerprint) { _, _ in
            persistRows()
            session.markInputsChanged()
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    @ViewBuilder
    private func cableRow(_ row: Binding<CableRow>) -> some View {
        let entry = EntryKind(rawValue: row.wrappedValue.entry) ?? .size
        let insulation = ConductorInsulationKind(rawValue: row.wrappedValue.insulation) ?? .thhn
        let material = ConductorMaterial(rawValue: row.wrappedValue.material) ?? .copper
        let role = CableLadderCableRole(rawValue: row.wrappedValue.role) ?? .unmarked
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: Theme.Space.sm) {
                NumberField(title: "Qty", unit: "ea", text: row.qty, fieldID: "qty-\(row.wrappedValue.id.uuidString)", onSubmit: calculate)
                    .frame(maxWidth: 120)
                MenuField(title: "Role", selection: Binding(
                    get: { role },
                    set: { row.wrappedValue.role = $0.rawValue }
                ), options: CableLadderCableRole.allCases) { $0.displayName }
            }
            MenuField(title: "How to size it", selection: Binding(
                get: { entry },
                set: { row.wrappedValue.entry = $0.rawValue }
            ), options: EntryKind.allCases) { $0.displayName }
            if entry == .size {
                MenuField(title: "Size", selection: Binding(
                    get: { row.wrappedValue.size },
                    set: { row.wrappedValue.size = $0 }
                ), options: sizes(for: insulation), label: NECTables.wireLabel)
                MenuField(title: "Insulation", selection: Binding(
                    get: { insulation },
                    set: { row.wrappedValue.insulation = $0.rawValue }
                ), options: ConductorInsulationKind.allCases) { $0.displayName }
                MenuField(title: "Metal", selection: Binding(
                    get: { material },
                    set: { row.wrappedValue.material = $0.rawValue }
                ), options: ConductorMaterial.allCases) { $0.displayName }
            } else {
                NumberField(title: "Overall diameter", unit: "in", text: row.od, fieldID: "od-\(row.wrappedValue.id.uuidString)", onSubmit: calculate)
                NumberField(title: "Weight", unit: "lb/kft", text: row.weight, optional: true, fieldID: "lb-\(row.wrappedValue.id.uuidString)", onSubmit: calculate)
            }
            if rows.count > 1 {
                Button(role: .destructive) {
                    rows.removeAll { $0.id == row.wrappedValue.id }
                    persistRows()
                } label: {
                    Text("Remove row")
                        .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func resultBody(_ result: CableLadderResult) -> some View {
        ResultCard(copyText: copyText) {
            ResultRow(label: "Status", value: result.status.label, emphasis: true, tone: tone(result.status))
            ResultRow(label: result.codePercentLabel, value: Format.percent(result.codePercent), emphasis: true, tone: tone(result.status))
            ResultRow(label: "Cable area", value: "\(Format.number(result.cableArea, digits: 3)) in²")
            if let allowable = result.allowableArea {
                ResultRow(label: "Allowable area", value: "\(Format.number(allowable, digits: 3)) in²")
            }
            ResultRow(label: "Usable section", value: "\(Format.number(result.usableCrossSection, digits: 2)) in²")
            ResultRow(label: "Packed height", value: "\(Format.number(result.stackHeightInches, digits: 2)) in (\(Format.percent(result.stackPercent)))")
            ResultRow(label: "Basis", value: result.basis, tone: Theme.muted)
            ResultRow(
                label: "NEMA VE 1",
                value: result.load.matchedClass ?? (result.load.weightComplete ? (result.load.exceedsClassC ? "Over class C" : "Not a listed span") : "Weight incomplete"),
                emphasis: true
            )
            if result.load.weightComplete {
                ResultRow(label: "Bare-metal load", value: "\(Format.number(result.load.cableLbPerFt, digits: 2)) lb/ft")
            }
            ResultRow(label: "Bend note", value: "\(Format.number(result.bendRadiusInches, digits: 2)) in")
            ForEach(result.reasons, id: \.self) { reason in
                Text(reason)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        CableLadderSpecGrid(chips: result.specChips)

        CableLadderCrossSection(
            result: result,
            widthInches: width.parsedDouble ?? 12,
            depthInches: depth.parsedDouble ?? 4,
            cover: cover,
            tint: tintByRole
        )
        CableLadderElevation(
            result: result,
            lengthFeet: length.parsedDouble ?? 80
        )

        VStack(alignment: .leading, spacing: 6) {
            Text("NOTES")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
            ForEach(result.notes, id: \.self) { note in
                Text(note)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
            jobs.save(SavedJob(
                name: jobName,
                toolID: .cableLadder,
                inputs: [
                    "tray": trayType.rawValue,
                    "width": width,
                    "depth": depth,
                    "length": length,
                    "span": span,
                    "env": environment.rawValue,
                ],
                outputs: [
                    "fill": Format.percent(result.codePercent),
                    "status": result.status.label,
                    "class": result.load.matchedClass ?? "",
                    "drop": result.conduitDropLabel,
                ]
            ))
        }
    }

    private func sizes(for insulation: ConductorInsulationKind) -> [String] {
        NECTables.wireSizeOrder.filter { NECTables.conductorArea(size: $0, insulation: insulation) != nil }
    }

    private func calculate() {
        let built: CableLadderInput
        do {
            built = try makeInput()
        } catch let error as CalcError {
            session.calculate { throw error }
            return
        } catch {
            session.calculate { throw CalcError.outOfRange(error.localizedDescription) }
            return
        }
        let before = session.displayedResult
        session.calculate { try CableLadder.calculate(built) }
        if session.displayedResult != nil, session.displayedResult != before {
            successTick += 1
        }
    }

    private func makeInput() throws -> CableLadderInput {
        var cables: [CableLadderCableInput] = []
        for row in rows {
            let count = try WholeCount.parse(row.qty.parsedDouble ?? .nan, name: "Cable count")
            let role = CableLadderCableRole(rawValue: row.role) ?? .unmarked
            let sizing: CableLadderCableInput.Sizing
            if row.entry == EntryKind.od.rawValue {
                let od = try Positive.require(row.od.parsedDouble ?? .nan, name: "Overall diameter")
                let weightText = row.weight.trimmingCharacters(in: .whitespacesAndNewlines)
                let weight: Double? = weightText.isEmpty ? nil : try Positive.require(weightText.parsedDouble ?? .nan, name: "Cable weight")
                sizing = .overallDiameter(inches: od, weightLbPerKft: weight)
            } else {
                let insulation = ConductorInsulationKind(rawValue: row.insulation) ?? .thhn
                let material = ConductorMaterial(rawValue: row.material) ?? .copper
                sizing = .table5(size: row.size, insulation: insulation, material: material)
            }
            cables.append(CableLadderCableInput(count: count, sizing: sizing, role: role))
        }
        return CableLadderInput(
            trayType: trayType,
            cover: cover,
            contents: contents,
            widthInches: try Positive.require(width.parsedDouble ?? .nan, name: "Inside width"),
            depthInches: try Positive.require(depth.parsedDouble ?? .nan, name: "Usable depth"),
            rungSpacingInches: try Positive.require(rung.parsedDouble ?? .nan, name: "Rung spacing"),
            lengthFeet: try Positive.require(length.parsedDouble ?? .nan, name: "Run length"),
            railMaterial: rail,
            environment: environment,
            orientation: orientation,
            supportSpanFeet: try Positive.require(span.parsedDouble ?? .nan, name: "Support span"),
            ambientC: ambient.parsedDouble ?? .nan,
            shielded: shielded,
            divider: divider,
            exposedRun: exposedRun,
            flexibleDrop: flexibleDrop,
            tintByRole: tintByRole,
            colorSystem: colorSystem,
            cables: cables
        )
    }

    private func reset() {
        trayType = .ladder
        cover = .none
        contents = .singleConductor
        width = "12"
        depth = "4"
        rung = "9"
        length = "80"
        rail = .steel
        environment = .indoorDry
        orientation = .horizontal
        span = "8"
        ambient = "30"
        shielded = false
        divider = false
        exposedRun = false
        flexibleDrop = false
        tintByRole = true
        colorSystem = .low120
        rows = Self.defaultRows()
        persistRows()
        session.reset()
    }

    private func applyExample() {
        reset()
        session.prepareForNewInputs()
    }

    private static func defaultRows() -> [CableRow] {
        [.phase(.phaseA), .phase(.phaseB), .phase(.phaseC)]
    }

    private func loadRows() {
        guard let data = cablesJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([CableRow].self, from: data),
              !decoded.isEmpty else {
            if rows.isEmpty { rows = Self.defaultRows() }
            return
        }
        rows = decoded
    }

    private func persistRows() {
        guard let data = try? JSONEncoder().encode(rows),
              let text = String(data: data, encoding: .utf8) else { return }
        if cablesJSON != text { cablesJSON = text }
    }

    private var sticky: String? {
        guard let result = session.displayedResult else { return nil }
        let klass = result.load.matchedClass.map { "  ·  VE 1 \($0)" } ?? ""
        return "\(Format.percent(result.codePercent))  ·  \(result.status.label)\(klass)"
    }

    private var substituted: String? {
        guard let result = session.displayedResult else { return nil }
        return "\(result.formula)  →  \(Format.percent(result.codePercent))  \(result.status.label)"
    }

    private var copyText: String? {
        guard let result = session.displayedResult else { return nil }
        let chips = result.specChips.map { "\($0.title): \($0.value)" }.joined(separator: "\n")
        return """
        Cable ladder \(result.status.label)
        \(result.codePercentLabel): \(Format.percent(result.codePercent))
        \(result.basis)
        VE 1: \(result.load.matchedClass ?? "—")  \(Format.number(result.load.cableLbPerFt, digits: 2)) lb/ft
        \(chips)
        \(CableLadder.planningBanner)
        """
    }

    private func tone(_ status: CableLadderStatus) -> Color {
        switch status {
        case .pass: return Theme.good
        case .warn: return Theme.warn
        case .fail: return Theme.bad
        }
    }
}

private struct CableLadderSpecGrid: View {
    let chips: [CableLadderSpecChip]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(chips) { chip in
                VStack(alignment: .leading, spacing: 4) {
                    Text(chip.title.uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(0.5)
                        .foregroundStyle(Theme.muted)
                    Text(chip.value)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(chip.detail)
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: Theme.touchTarget, alignment: .topLeading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.border, lineWidth: Theme.Stroke.hairline)
                )
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct CableLadderCrossSection: View {
    let result: CableLadderResult
    let widthInches: Double
    let depthInches: Double
    let cover: CableLadderCover
    let tint: Bool

    var body: some View {
        DiagramCard(title: "Cross-section  \(result.status.label)", accessibilitySummary: result.accessibilitySummary) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: symbol)
                        .foregroundStyle(tone)
                        .accessibilityHidden(true)
                    Text("\(Format.percent(result.codePercent))  \(result.status.label)")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(tone)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Fill \(Format.percent(result.codePercent)), status \(result.status.label)")

                GeometryReader { geo in
                    crossSection(in: geo.size)
                }
                .frame(height: 220)

                Text("Inside width \(Format.number(widthInches, digits: 2)) in  ·  usable depth \(Format.number(depthInches, digits: 2)) in")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.muted)

                legend
            }
        }
    }

    private var tone: Color {
        switch result.status {
        case .pass: return Theme.good
        case .warn: return Theme.warn
        case .fail: return Theme.bad
        }
    }

    private var symbol: String {
        switch result.status {
        case .pass: return "checkmark.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.octagon.fill"
        }
    }

    private func crossSection(in size: CGSize) -> some View {
        let plot = CGRect(origin: .zero, size: size).insetBy(dx: 8, dy: 8)
        let scale = min(plot.width / CGFloat(widthInches), plot.height / CGFloat(depthInches))
        let drawnW = scale * CGFloat(widthInches)
        let drawnH = scale * CGFloat(depthInches)
        let origin = CGPoint(x: plot.midX - drawnW / 2, y: plot.midY - drawnH / 2)
        return ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(Theme.accent, lineWidth: 8)
                .frame(width: drawnW, height: drawnH)
                .position(x: origin.x + drawnW / 2, y: origin.y + drawnH / 2)
            if cover != .none {
                Path { path in
                    path.move(to: CGPoint(x: origin.x, y: origin.y))
                    path.addLine(to: CGPoint(x: origin.x + drawnW, y: origin.y))
                }
                .stroke(Theme.foreground, style: StrokeStyle(lineWidth: 2, dash: cover == .ventilated ? [4, 3] : []))
            }
            ForEach(result.circles) { circle in
                let diameter = CGFloat(circle.diameterInches) * scale
                let center = CGPoint(
                    x: origin.x + CGFloat(circle.centerXInches) * scale,
                    y: origin.y + drawnH - CGFloat(circle.centerYInches) * scale
                )
                let entry = result.legend.entries.first { $0.role == circle.role }
                let name = entry?.colorName ?? ""
                let fill = tint ? conventionColor(name) : nil
                ZStack {
                    if let fill {
                        Circle().fill(fill)
                        Circle().stroke(Theme.foreground.opacity(0.85), lineWidth: 1)
                    } else {
                        Circle().stroke(circle.fits ? Theme.energized : Theme.bad, lineWidth: 1.5)
                    }
                    if diameter >= 16, let letter = entry?.letter, !letter.isEmpty {
                        Text(letter)
                            .font(.system(size: min(13, diameter * 0.38), weight: .bold))
                            .minimumScaleFactor(0.4)
                            .foregroundStyle(fill == nil ? Theme.foreground : ink(on: name))
                    }
                }
                .frame(width: max(diameter, 1), height: max(diameter, 1))
                .position(center)
            }
        }
    }

    @ViewBuilder
    private var legend: some View {
        if result.legend.tintEnabled {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.legend.systemTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                ForEach(result.legend.entries) { entry in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(conventionColor(entry.colorName) ?? Theme.surfaceRaised)
                            .overlay(Circle().stroke(Theme.foreground.opacity(0.5), lineWidth: 1))
                            .frame(width: 14, height: 14)
                            .accessibilityHidden(true)
                        Text(entry.letter.isEmpty ? entry.role.displayName : "\(entry.letter)  \(entry.role.displayName)")
                            .font(.caption2.weight(.semibold))
                        Text(entry.colorName)
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                    }
                    .accessibilityElement(children: .combine)
                }
                Text(result.legend.disclaimer)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text("Tint off — circles are not phase colors. \(result.legend.disclaimer)")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func conventionColor(_ name: String) -> Color? {
        switch name.lowercased() {
        case "black": return Color(white: 0.12)
        case "red": return Color(red: 0.78, green: 0.12, blue: 0.14)
        case "blue": return Color(red: 0.15, green: 0.35, blue: 0.78)
        case "white": return Color(white: 0.96)
        case "green": return Color(red: 0.12, green: 0.55, blue: 0.28)
        case "brown": return Color(red: 0.45, green: 0.28, blue: 0.14)
        case "orange": return Color(red: 0.90, green: 0.48, blue: 0.10)
        case "yellow": return Color(red: 0.93, green: 0.78, blue: 0.15)
        case "grey", "gray": return Color(white: 0.62)
        default: return nil
        }
    }

    private func ink(on name: String) -> Color {
        switch name.lowercased() {
        case "white", "yellow", "orange", "grey", "gray":
            return Color(white: 0.12)
        default:
            return Color.white
        }
    }
}

private struct CableLadderElevation: View {
    let result: CableLadderResult
    let lengthFeet: Double

    private var summary: String {
        let marks = result.supportStationsFeet.map { Format.number($0, digits: 1) }.joined(separator: ", ")
        return "Elevation \(Format.number(lengthFeet, digits: 1)) feet. Supports at \(marks) feet. Conduit drop \(result.conduitDropLabel). Transition sketch, not a routing plan."
    }

    var body: some View {
        DiagramCard(title: "Elevation — supports", accessibilitySummary: summary) {
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geo in
                    elevation(in: geo.size)
                }
                .frame(height: 150)
                Text("Run \(Format.number(lengthFeet, digits: 1)) ft  ·  \(result.supportStationsFeet.count) supports  ·  drop \(result.conduitDropLabel)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.muted)
                Text("Listed tray-to-conduit fitting at the drop. Not a routing plan.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private func elevation(in size: CGSize) -> some View {
        let left: CGFloat = 12
        let right: CGFloat = 36
        let axisY = size.height * 0.42
        let width = max(size.width - left - right, 1)
        let length = max(lengthFeet, 0.001)
        func x(_ feet: Double) -> CGFloat {
            left + CGFloat(feet / length) * width
        }
        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: x(0), y: axisY - 8))
                path.addLine(to: CGPoint(x: x(lengthFeet), y: axisY - 8))
                path.move(to: CGPoint(x: x(0), y: axisY + 8))
                path.addLine(to: CGPoint(x: x(lengthFeet), y: axisY + 8))
            }
            .stroke(Theme.accent, lineWidth: 2)

            ForEach(Array(result.supportStationsFeet.enumerated()), id: \.offset) { index, station in
                let px = x(station)
                Path { path in
                    path.move(to: CGPoint(x: px, y: axisY - 14))
                    path.addLine(to: CGPoint(x: px, y: axisY + 22))
                }
                .stroke(Theme.foreground, lineWidth: index == 0 || index == result.supportStationsFeet.count - 1 ? 2 : 1)
                if shouldLabel(index: index, count: result.supportStationsFeet.count) {
                    Text(Format.number(station, digits: station.rounded() == station ? 0 : 1))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                        .position(x: px, y: axisY + 36)
                }
            }

            Path { path in
                let end = x(lengthFeet)
                path.move(to: CGPoint(x: end, y: axisY + 8))
                path.addLine(to: CGPoint(x: end, y: axisY + 52))
            }
            .stroke(Theme.copper, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            Text(result.conduitDropLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .position(x: min(x(lengthFeet) + 8, size.width - 28), y: axisY + 66)
        }
    }

    private func shouldLabel(index: Int, count: Int) -> Bool {
        if count <= 8 { return true }
        if index == 0 || index == count - 1 { return true }
        return index % 2 == 0
    }
}
