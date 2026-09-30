import SwiftUI
import BeckifyMath

struct ConduitFillView: View {
    private enum FillMode: String, CaseIterable, Identifiable {
        case same = "Same size"
        case mixed = "Mixed sizes"
        var id: String { rawValue }
    }

    private struct MixedRow: Identifiable, Equatable {
        var id: UUID = UUID()
        var qty: String
        var size: String
        var insulation: ConductorInsulationKind
    }

    @EnvironmentObject private var jobs: JobStore
    @AppStorage(ToolboxPreferenceKey.electricalCode) private var codeRaw = ElectricalCode.nec.rawValue
    @StoredChoice(.conduitFill, "mode", default: FillMode.same) private var mode
    @StoredInput(.conduitFill, "qty", default: "4") private var qty
    @StoredInput(.conduitFill, "size", default: "12") private var size
    @StoredInput(.conduitFill, "trade", default: "3/4") private var trade
    @StoredChoice(.conduitFill, "raceway", default: RacewayKind.emt) private var raceway
    @StoredChoice(.conduitFill, "insulation", default: ConductorInsulationKind.thhn) private var insulation
    @StoredToggle(.conduitFill, "nipple", default: false) private var nipple
    @StoredChoice(.conduitFill, "phaseTint", default: ConduitDistributionColors.off) private var distributionColors
    @StoredChoice(.conduitFill, "grounding", default: EquipmentGroundingContext.none) private var grounding
    @StoredInput(.conduitFill, "ocpd", default: "") private var ocpd
    @StoredInput(.conduitFill, "loadAmps", default: "") private var loadAmps
    @StoredChoice(.conduitFill, "egcMaterial", default: ConductorMaterial.copper) private var egcMaterial
    @StoredToggle(.conduitFill, "countEGC", default: false) private var countEGC
    @StoredInput(.conduitFill, "mixedJSON", default: "") private var mixedJSON
    @StoredInput(.conduitFill, "jobName", default: "Conduit fill") private var jobName
    @State private var session = ExplicitCalculationState<ConduitFillResult>()
    @State private var mixedRows: [MixedRow] = ConduitFillView.defaultMixedRows()
    @State private var importedBanner: String?
    @State private var displayedEGC: EquipmentGroundingRecommendation?
    @State private var egcCounted = false
    @State private var egcNote: String?
    @State private var egcGroupIndex: Int?
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var code: ElectricalCode { ElectricalCode(rawValue: codeRaw) ?? .nec }

    private var sizes: [String] {
        NECTables.wireSizeOrder.filter { NECTables.thhnArea[$0] != nil }
    }

    private var trades: [String] { NECTables.tradeSizes(for: raceway) }

    private var inputFingerprint: String {
        let mixed = mixedRows.map { "\($0.qty):\($0.size):\($0.insulation.rawValue)" }.joined(separator: ",")
        return "\(mode)|\(qty)|\(size)|\(trade)|\(raceway)|\(insulation)|\(nipple)|\(grounding)|\(ocpd)|\(loadAmps)|\(egcMaterial)|\(countEGC)|\(mixed)"
    }

    var body: some View {
        ToolScaffold(
            toolID: .conduitFill,
            stickyAnswer: sticky,
            copyText: copyText,
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .conduitFill,
                symbolic: "1 wire → 53%    2 wires → 31%    3+ → 40%    nipple → 60%",
                substituted: substituted,
                meaning: "Fill percent is the sum of Chapter 9 Table 5 areas over the Table 4 raceway area. The cross-section packs those circles in the bore as an illustration — it is not a jam or pulling calculation. An equipment grounding conductor counts only when Count EGC is on.",
                citation: "NEC Chapter 9 Table 1 (and Note 4). Areas from Table 4 and Table 5. Optional EGC: NEC 2023 Table 250.122. Confirm Code / AHJ."
            )

            if let importedBanner {
                Text(importedBanner)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.accent)
            }

            Picker("Mode", selection: $mode) {
                ForEach(FillMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .segmentedControlStyle()

            MenuField(title: "Raceway", selection: $raceway, options: RacewayKind.allCases) { $0.displayName }
            MenuField(title: "Trade size", selection: $trade, options: trades, label: { "\($0)\"" })
            Toggle("Nipple — 24 in or shorter (60% fill)", isOn: $nipple)
            MenuField(title: "Phase tint", selection: $distributionColors, options: ConduitDistributionColors.allCases) { $0.displayName }
            Text("Optional legend. 120/208 and 277/480 names match Reference Library. Pick 1Ø, multiwire, or 3Ø so phase, neutral, and EGC can be marked.")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            MenuField(title: "Circuit", selection: $grounding, options: EquipmentGroundingContext.allCases) { $0.displayName }
            if grounding.impliesEquipmentGround {
                NumberField(title: "OCPD rating", unit: "A", text: $ocpd, optional: true, fieldID: "ocpd", onSubmit: calculate)
                NumberField(title: "Load current if no OCPD", unit: "A", text: $loadAmps, optional: true, fieldID: "loadAmps", onSubmit: calculate)
                MenuField(title: "EGC material", selection: $egcMaterial, options: ConductorMaterial.allCases) { $0.displayName }
                Toggle("Count EGC in fill", isOn: $countEGC)
                Text("The minimum size is NEC 2023 Table 250.122, shown here as soon as the amps are entered. Turn the count on to add that one conductor. Leave it off if the ground is already listed. The same table is the Equipment Grounding tool.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let live = liveGround {
                    EquipmentGroundingSummary(recommendation: live, countedInFill: countEGC)
                }
            }

            if mode == .same {
                NumberField(title: "Conductor count", unit: "ea", text: $qty, fieldID: "qty", onSubmit: calculate)
                MenuField(title: "Size", selection: $size, options: sizes, label: NECTables.wireLabel)
                MenuField(title: "Insulation", selection: $insulation, options: ConductorInsulationKind.allCases) { $0.displayName }
            } else {
                Text("CONDUCTOR GROUPS")
                    .font(Theme.TypeRole.fieldLabel)
                    .tracking(0.6)
                    .foregroundStyle(Theme.muted)
                ForEach($mixedRows) { $row in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: Theme.Space.sm) {
                            NumberField(title: "Qty", unit: "ea", text: $row.qty, fieldID: "mixed-\(row.id.uuidString)", onSubmit: calculate)
                                .frame(maxWidth: 140)
                            MenuField(title: "Size", selection: $row.size, options: sizes, label: NECTables.wireLabel)
                        }
                        // Full width so "THHN / THWN-2" and "RHH / RHW / RHW-2" stay one readable line.
                        MenuField(title: "Insulation", selection: $row.insulation, options: ConductorInsulationKind.allCases) { $0.displayName }
                        if mixedRows.count > 1 {
                            Button(role: .destructive) {
                                mixedRows.removeAll { $0.id == row.id }
                                persistMixedRows()
                            } label: {
                                Text("Remove group")
                                    .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Button {
                    mixedRows.append(MixedRow(qty: "1", size: "12", insulation: .thhn))
                    persistMixedRows()
                } label: {
                    Label("Add conductor group", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
                }
                .buttonStyle(.bordered)
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: applyExample,
                exampleTitle: mode == .same
                    ? "Four 12 AWG THHN in ¾\" EMT"
                    : "3× 3/0 + 1× 3/0 + 1× 6 THHN, auto EMT"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if let r = session.displayedResult {
                if let section = sectionLayout(for: r) {
                    ConduitFillDiagram(
                        layout: section,
                        showsASNZSGuidance: code == .asnzs,
                        recommendedEGCNote: recommendedEGCNote
                    )
                    .opacity(session.isStale ? 0.72 : 1)
                }
                ResultCard(copyText: copyText) {
                    if r.isMixed || r.groups.count > 1 {
                        ForEach(Array(r.groups.enumerated()), id: \.offset) { index, group in
                            let area = index < r.groupAreas.count ? r.groupAreas[index] : 0
                            ResultRow(label: group.label, value: "\(Format.number(area, digits: 4)) in²")
                        }
                    }
                    ResultRow(label: "Conductors", value: "\(r.conductorCount)")
                    ResultRow(label: "Wire area", value: "\(Format.number(r.totalWireArea, digits: 4)) in²")
                    ResultRow(label: "\(r.raceway.displayName) area", value: "\(Format.number(r.conduitArea, digits: 3)) in²")
                    ResultRow(label: "Table 1 limit", value: Format.percent(r.maxFillPercent))
                    ResultRow(label: "Basis", value: r.fillBasis, tone: Theme.muted)
                    ResultRow(label: "Actual fill", value: Format.percent(r.actualFillPercent), emphasis: true, tone: r.passes ? Theme.good : Theme.bad)
                    if let section = sectionLayout(for: r) {
                        ResultRow(label: "Free area", value: Format.percent(section.freeAreaPercent), tone: Theme.muted)
                        if let annex = section.annexCMaximum {
                            ResultRow(label: "Annex C style max", value: "\(annex)", tone: Theme.muted)
                        }
                        if code == .asnzs {
                            ResultRow(
                                label: "AS/NZS C6.2 guidance",
                                value: Format.percent(section.asnzsSpaceFactorPercent),
                                tone: section.exceedsASNZSGuidance ? Theme.warn : Theme.muted
                            )
                        }
                        if let ratio = section.jamRatio, section.jamNote != nil {
                            ResultRow(label: "Jam ratio", value: Format.number(ratio, digits: 2), tone: Theme.warn)
                        }
                    }
                    ResultRow(label: "Status", value: r.passes ? "PASS" : "FAIL — exceeds Table 1", tone: r.passes ? Theme.good : Theme.bad)
                    if let displayedEGC {
                        ResultRow(
                            label: "Minimum EGC",
                            value: "\(displayedEGC.label) \(displayedEGC.material.displayName)",
                            emphasis: true,
                            tone: Theme.copper
                        )
                    }
                    if let sug = r.suggestedTradeSize {
                        ResultRow(label: "Minimum \(r.raceway.displayName)", value: "\(sug)\"", tone: Theme.warn)
                    }
                    if let egcNote {
                        ResultRow(label: "EGC in this fill", value: egcNote, tone: Theme.muted)
                    }
                }
                EquipmentGroundingCard(recommendation: displayedEGC, countedInFill: displayedEGC == nil ? nil : egcCounted)
                .opacity(session.isStale ? 0.72 : 1)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .conduitFill,
                        inputs: [
                            "n": "\(r.conductorCount)",
                            "size": r.conductorSize,
                            "emt": trade,
                            "raceway": raceway.rawValue,
                        ],
                        outputs: [
                            "fill": Format.percent(r.actualFillPercent),
                            "ok": r.passes ? "PASS" : "FAIL",
                            "EGC": displayedEGC?.copyLine ?? "",
                        ]
                    ))
                }
            }
        }
        .onAppear {
            loadMixedRows()
            applyIncomingHandoff()
        }
        .onChange(of: inputFingerprint) { _, _ in
            persistMixedRows()
            session.markInputsChanged()
        }
        .onChange(of: raceway) { _, newValue in
            if !trades.contains(trade) {
                trade = trades.first ?? "3/4"
            }
            _ = newValue
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private struct PreparedFill {
        var groups: [ConduitFillGroup]
        var recommendation: EquipmentGroundingRecommendation?
        var counted: Bool
        var note: String?
        var egcGroupIndex: Int?
    }

    private func calculate() {
        let prepared: PreparedFill
        do {
            prepared = try preparedFill()
        } catch let error as CalcError {
            session.calculate { throw error }
            return
        } catch {
            session.calculate { throw CalcError.outOfRange(error.localizedDescription) }
            return
        }
        let groups = prepared.groups
        session.calculate {
            try ConduitFill.calculate(
                groups: groups,
                raceway: raceway,
                tradeSize: trade,
                nipple: nipple
            )
        }
        if session.displayedResult != nil, !session.isStale {
            displayedEGC = prepared.recommendation
            egcCounted = prepared.counted
            egcNote = prepared.note
            egcGroupIndex = prepared.egcGroupIndex
            if !reduceMotion { successTick += 1 }
        }
    }

    private func preparedFill() throws -> PreparedFill {
        var groups: [ConduitFillGroup]
        if mode == .same {
            let n = try WholeCount.parse(qty.parsedDouble ?? .nan, name: "Conductor quantity")
            groups = [ConduitFillGroup(quantity: n, size: size, insulation: insulation)]
        } else {
            groups = try mixedRows.map { row in
                let n = try WholeCount.parse(row.qty.parsedDouble ?? .nan, name: "Conductor quantity")
                return ConduitFillGroup(quantity: n, size: row.size, insulation: row.insulation)
            }
        }

        let recommendation = equipmentGroundRecommendation()
        var counted = false
        var note: String?
        var egcGroupIndex: Int?
        if let recommendation {
            if countEGC {
                let egcInsulation: ConductorInsulationKind = mode == .same ? insulation : .thhn
                if NECTables.conductorArea(size: recommendation.size, insulation: egcInsulation) != nil {
                    groups.append(ConduitFillGroup(quantity: 1, size: recommendation.size, insulation: egcInsulation))
                    counted = true
                    egcGroupIndex = groups.count - 1
                    note = "Added 1 × \(recommendation.label)"
                } else {
                    note = "No Table 5 area — not added"
                }
            } else {
                note = "Recommended, not added"
            }
        }
        return PreparedFill(
            groups: groups,
            recommendation: recommendation,
            counted: counted,
            note: note,
            egcGroupIndex: egcGroupIndex
        )
    }

    private func sectionLayout(for result: ConduitFillResult) -> ConduitCrossSectionLayout? {
        ConduitCrossSection.make(
            result: result,
            egcGroupIndex: egcGroupIndex,
            context: grounding,
            colors: distributionColors
        )
    }

    private var recommendedEGCNote: String? {
        guard let displayedEGC, !egcCounted else { return nil }
        return "EGC \(displayedEGC.label) \(displayedEGC.material.displayName) is recommended and is not drawn in this bore."
    }

    private func equipmentGroundRecommendation() -> EquipmentGroundingRecommendation? {
        let ocpdText = ocpd.trimmingCharacters(in: .whitespacesAndNewlines)
        let loadText = loadAmps.trimmingCharacters(in: .whitespacesAndNewlines)
        let explicit = !ocpdText.isEmpty
        guard let amps = explicit ? ocpd.parsedDouble : (loadText.isEmpty ? nil : loadAmps.parsedDouble) else {
            return nil
        }
        let extra = "Shown beside the fill. Turn Count EGC on to add one conductor. Leave it off if that ground is already listed."
        return EquipmentGrounding.recommend(
            amps: amps,
            material: egcMaterial,
            context: grounding,
            ampsAreOCPDRating: explicit,
            ungroundedSize: mode == .same ? size : nil,
            extraNote: extra
        )
    }

    private func reset() {
        qty = ""
        size = "12"
        trade = "3/4"
        raceway = .emt
        insulation = .thhn
        nipple = false
        grounding = .none
        ocpd = ""
        loadAmps = ""
        egcMaterial = .copper
        countEGC = false
        distributionColors = .off
        displayedEGC = nil
        egcCounted = false
        egcNote = nil
        egcGroupIndex = nil
        mixedRows = Self.defaultMixedRows()
        persistMixedRows()
        importedBanner = nil
        session.reset()
    }

    private func applyExample() {
        if mode == .mixed {
            raceway = .emt
            trade = "2"
            nipple = false
            mixedRows = [
                MixedRow(qty: "3", size: "3/0", insulation: .thhn),
                MixedRow(qty: "1", size: "3/0", insulation: .thhn),
                MixedRow(qty: "1", size: "6", insulation: .thhn),
            ]
        } else {
            qty = "4"
            size = "12"
            trade = "3/4"
            raceway = .emt
            insulation = .thhn
            nipple = false
        }
        persistMixedRows()
        session.prepareForNewInputs()
    }

    private func applyIncomingHandoff() {
        guard let seed = ConductorHandoff.consume() else { return }
        size = seed.size
        if seed.parallelRuns > 1 {
            qty = "\(max(3, seed.parallelRuns) + 1)"
        }
        importedBanner = "Imported \(NECTables.wireLabel(seed.size)) from \(seed.sourceSummary). Edit freely, then Calculate."
        session.prepareForNewInputs()
    }

    private var substituted: String? {
        guard let r = session.displayedResult else { return nil }
        return "\(r.formula)  →  \(Format.percent(r.actualFillPercent))  (limit \(Format.percent(r.maxFillPercent)), \(r.conductorCount) conductors)"
    }

    private var liveGround: EquipmentGroundingRecommendation? {
        equipmentGroundRecommendation()
    }

    private var sticky: String? {
        guard let r = session.displayedResult else { return nil }
        let fill = "\(Format.percent(r.actualFillPercent))  ·  \(r.passes ? "PASS" : "FAIL")"
        guard let displayedEGC else { return fill }
        return "\(fill)  ·  EGC \(displayedEGC.label)"
    }

    private var copyText: String? {
        guard let sticky else { return nil }
        guard let displayedEGC else { return sticky }
        return "\(sticky) · \(displayedEGC.copyLine)"
    }

    private static func defaultMixedRows() -> [MixedRow] {
        [
            MixedRow(qty: "3", size: "3/0", insulation: .thhn),
            MixedRow(qty: "1", size: "6", insulation: .thhn),
        ]
    }

    private func persistMixedRows() {
        let payload = mixedRows.map { row in
            ["qty": row.qty, "size": row.size, "insul": row.insulation.rawValue]
        }
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let text = String(data: data, encoding: .utf8) {
            mixedJSON = text
        }
    }

    private func loadMixedRows() {
        guard let data = mixedJSON.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: String]],
              !raw.isEmpty
        else { return }
        mixedRows = raw.map { dict in
            MixedRow(
                qty: dict["qty"] ?? "1",
                size: dict["size"] ?? "12",
                insulation: ConductorInsulationKind(rawValue: dict["insul"] ?? "") ?? .thhn
            )
        }
    }
}
