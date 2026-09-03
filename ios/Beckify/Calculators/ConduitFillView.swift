import SwiftUI
import BeckifyMath

struct ConduitFillView: View {
    @EnvironmentObject private var jobs: JobStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StoredInput(.conduitFill, "qty", default: "4") private var legacyQty
    @StoredInput(.conduitFill, "size", default: "12") private var legacySize
    @StoredInput(.conduitFill, "trade", default: "3/4") private var trade
    @StoredInput(.conduitFill, "jobName", default: "Conduit fill") private var jobName
    @StoredInput(.conduitFill, "schedule", default: "") private var scheduleJSON
    @StoredChoice(.conduitFill, "raceway", default: RacewayType.emt) private var racewayType
    @StoredChoice(.conduitFill, "runKind", default: RacewayRunKind.normal) private var runKind
    @StoredChoice(.conduitFill, "location", default: InstallationLocation.dry) private var location
    @StoredInput(.conduitFill, "nippleIn", default: "") private var nippleInches
    @StoredInput(.conduitFill, "lengthFt", default: "") private var lengthFeet
    @StoredInput(.conduitFill, "bendDeg", default: "") private var bendDegrees
    @StoredInput(.conduitFill, "bendCount", default: "") private var bendCount
    @StoredInput(.conduitFill, "bendRadius", default: "") private var bendRadius
    @StoredInput(.conduitFill, "riseFt", default: "") private var riseFeet
    @StoredInput(.conduitFill, "pullPoints", default: "") private var pullPoints
    @StoredInput(.conduitFill, "preferred", default: "30") private var preferredFill
    @StoredToggle(.conduitFill, "lube", default: false) private var lubricant
    @StoredChoice(.conduitFill, "pullMethod", default: PullingMethod.unspecified) private var pullMethod
    @StoredInput(.conduitFill, "maxTension", default: "") private var maxTension
    @StoredInput(.conduitFill, "sidewall", default: "") private var sidewall
    @StoredInput(.conduitFill, "cccOverride", default: "") private var cccOverride
    @StoredChoice(.conduitFill, "preset", default: ConduitFillPreset.custom) private var preset

    @State private var groups: [ConductorGroup] = []
    @State private var editor: ConductorGroup?
    @State private var lastResult: ConduitFillDesignResult?
    @State private var lastError: CalcError?
    @State private var lastFingerprint = ""
    @FocusState private var focus: FocusField?
    @State private var didMigrate = false

    private enum FocusField: Hashable {
        case nipple
        case preferred
        case groupQty(UUID)
        case customArea(UUID)
    }

    var body: some View {
        ToolScaffold(
            toolID: .conduitFill,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .designAidExtra("Verify the adopted code edition, local amendments, conductor dimensions, raceway dimensions, and manufacturer pulling limits before construction. Preferred fill is a Beckify design preference, not an NEC requirement. Pull-planning status is not a guarantee.")
        ) {
            ShowWorkCard(
                toolID: .conduitFill,
                symbolic: "Fill % = (Σ qty × conductor area) / raceway area × 100",
                substituted: lastResult?.formula,
                meaning: "One conductor 53%, two 31%, over two 40%. A qualifying nipple ≤ 24 in may use 60% (Table 1 Note 4). Preferred fill is not a code limit. Ampacity adjustment is a separate review.",
                citation: "NEC 2023 Art. 300.17; Chapter 9 Tables 1, 4, and 5. Areas transcribed \(NECDimensionalCatalog.verifiedOn)."
            )

            presetSection
            racewaySection
            scheduleSection
            routeSection
            preferenceSection

            Button(action: calculate) {
                Label("Calculate", systemImage: "equal.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .accessibilityHint("Runs fill, preferred-size, and pull-planning results from the current schedule.")

            if isStale {
                Label("Inputs changed — Calculate again", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.warn)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.warn.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("Inputs changed. Calculate again.")
            }

            if let lastError {
                ErrorText(message: lastError.message)
            }

            if let lastResult {
                results(lastResult)
                SaveJobBar(jobName: $jobName, canSave: true) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .conduitFill,
                        inputs: snapshot.encodeInputs(),
                        outputs: shareLines(lastResult)
                    ))
                }
            }
        }
        .onAppear {
            migrateIfNeeded()
            applyPendingRestore()
        }
        .onChange(of: racewayType) { _, newType in
            if newType.area(for: trade) == nil {
                trade = newType.orderedTradeSizes.first ?? "1/2"
            }
        }
        .sheet(item: $editor) { group in
            ConductorGroupEditor(group: group, sizes: NECTables.wireSizeOrder) { updated in
                if let idx = groups.firstIndex(where: { $0.id == updated.id }) {
                    groups[idx] = updated
                } else {
                    groups.append(updated)
                }
                persistSchedule()
                editor = nil
            } onCancel: {
                editor = nil
            }
        }
    }

    // MARK: - Sections

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Quick-start preset")
            MenuField(title: "Preset", selection: $preset, options: ConduitFillPreset.allCases) { $0.displayName }
            Button("Apply preset") {
                groups = ConduitFillPlanning.groups(for: preset)
                persistSchedule()
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .frame(minHeight: Theme.touchTarget)
            Text("Presets stay editable. Neutrals are left unmarked so current-carrying treatment is not assumed.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }

    private var racewaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("1. Raceway")
            MenuField(title: "Raceway type", selection: $racewayType, options: RacewayType.allCases) { $0.displayName }
            MenuField(title: "Trade size", selection: $trade, options: racewayType.orderedTradeSizes) { size in
                let metric = racewayType.metricDesignator(for: size).map { " · metric \($0)" } ?? ""
                return "\(size)\"\(metric)"
            }
            Picker("Run", selection: $runKind) {
                ForEach(RacewayRunKind.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Run kind")
            if runKind == .nipple {
                focusNumber("Nipple length", unit: "in", text: $nippleInches, field: .nipple, optional: false)
                Text("Note 4 applies only at 24 in or shorter between boxes or cabinets.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Picker("Location", selection: $location) {
                ForEach(InstallationLocation.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Installation location")
            Text("Wet/dry is a field note. It does not change Table 1 percentages.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("2. Conductor schedule")
            Text("Every row’s listed or custom area is added. Multiconductor cable fill is not calculated as the sum of internal conductors.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                conductorRow(group, index: index)
            }
            ThumbButtonRow {
                Button {
                    editor = ConductorGroup(quantity: 1, size: "12", insulation: .thhnTHWN2, purpose: .phase, countsAsCurrentCarrying: true)
                } label: {
                    Label("Add group", systemImage: "plus")
                        .frame(minHeight: Theme.touchTarget)
                }
                if groups.count > 1 {
                    Button("Move up first") {
                        groups.swapAt(0, 1)
                        persistSchedule()
                    }
                    .frame(minHeight: Theme.touchTarget)
                }
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
        }
    }

    private func conductorRow(_ group: ConductorGroup, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.summaryLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.foreground)
            if !group.description.isEmpty {
                Text(group.description)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Text(cccCaption(group))
                .font(.caption)
                .foregroundStyle(Theme.muted)
            ThumbButtonRow {
                Button("Edit") { editor = group }
                Button("Duplicate") {
                    var copy = group
                    copy.id = UUID()
                    groups.insert(copy, at: min(index + 1, groups.count))
                    persistSchedule()
                }
                if index > 0 {
                    Button("Move up") {
                        groups.swapAt(index, index - 1)
                        persistSchedule()
                    }
                }
                if index + 1 < groups.count {
                    Button("Move down") {
                        groups.swapAt(index, index + 1)
                        persistSchedule()
                    }
                }
                Button("Delete", role: .destructive) {
                    groups.removeAll { $0.id == group.id }
                    persistSchedule()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Conductor group \(index + 1), \(group.summaryLabel)")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Edit") { editor = group }
            Button("Duplicate") {
                var copy = group
                copy.id = UUID()
                groups.insert(copy, at: min(index + 1, groups.count))
                persistSchedule()
            }
            Button("Delete", role: .destructive) {
                groups.removeAll { $0.id == group.id }
                persistSchedule()
            }
        }
    }

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("3. Route and pull conditions")
            Text("Optional. Used for installation-planning status, not for fill percent.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            NumberField(title: "Raceway length", unit: "ft", text: $lengthFeet, optional: true)
            NumberField(title: "Total bend degrees", unit: "deg", text: $bendDegrees, optional: true)
            NumberField(title: "Bend count", unit: "ea", text: $bendCount, optional: true)
            NumberField(title: "Bend radius", unit: "in", text: $bendRadius, optional: true)
            NumberField(title: "Vertical rise", unit: "ft", text: $riseFeet, optional: true)
            NumberField(title: "Pull points", unit: "ea", text: $pullPoints, optional: true)
            MenuField(title: "Pulling method", selection: $pullMethod, options: PullingMethod.allCases) { $0.displayName }
            Toggle(isOn: $lubricant) {
                Text("Listed pulling lubricant planned")
                    .frame(minHeight: Theme.touchTarget)
            }
            .tint(Theme.accent)
            NumberField(title: "Manufacturer max tension", unit: "lbf", text: $maxTension, optional: true)
            NumberField(title: "Manufacturer sidewall limit", unit: "lbf/ft", text: $sidewall, optional: true)
            Text("Tension and sidewall pressure are not calculated. Entered manufacturer limits are stored for the share sheet only.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }

    private var preferenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("4. Design preferences")
            focusNumber("Preferred maximum fill", unit: "%", text: $preferredFill, field: .preferred, optional: false)
            Text("Default 30% is a Beckify design preference for easier pulling. It is not a Chapter 9 Table 1 limit.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            NumberField(title: "Current-carrying override", unit: "ea", text: $cccOverride, optional: true)
            Text("Leave blank to use marked current-carrying rows. Neutrals stay unmarked unless you set them in the row editor.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }

    // MARK: - Results

    private func results(_ r: ConduitFillDesignResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ResultCard(title: "6. Code compliance", copyText: copyText) {
                ResultRow(label: "Selected", value: r.selectedRaceway.displayName)
                ResultRow(label: "Occupied area", value: "\(Format.number(r.totalConductorArea, digits: 4)) in²")
                ResultRow(label: "Raceway area", value: "\(Format.number(r.racewayArea, digits: 3)) in²")
                ResultRow(label: "Code maximum", value: "\(Format.percent(r.codeMaximumPercent)) · \(Format.number(r.codeMaximumArea, digits: 4)) in²")
                ResultRow(label: "Actual fill", value: Format.percent(r.actualFillPercent), emphasis: true, tone: r.passesCodeFill ? Theme.good : Theme.bad)
                ResultRow(label: "Remaining", value: "\(Format.number(r.remainingArea, digits: 4)) in² · \(Format.number(r.remainingPercentPoints, digits: 2)) pt")
                ResultRow(
                    label: "Table 1 result",
                    value: r.passesCodeFill ? "PASS — code fill" : "FAIL — exceeds Table 1",
                    tone: r.passesCodeFill ? Theme.good : Theme.bad
                )
                if let min = r.minimumCompliantRaceway {
                    ResultRow(label: "Minimum code size", value: min.displayName, tone: Theme.warn)
                }
                ResultRow(label: "Nipple", value: r.nippleNote)
                ForEach(r.conductorBreakdown, id: \.groupID) { row in
                    ResultRow(label: row.label, value: "\(Format.number(row.totalArea, digits: 4)) in²")
                }
            }

            ResultCard(title: "7. Installation recommendation") {
                Text("Code minimum is the smallest listed size that meets Table 1. Preferred size uses the \(Format.percent(r.preferredMaximumPercent)) Beckify target — not a code limit. Fill alone does not make a pull “easy.”")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .padding(.bottom, 6)
                ForEach(r.sizeOptions, id: \.selection.tradeSize) { option in
                    ResultRow(
                        label: optionLabel(option),
                        value: "\(Format.percent(option.actualFillPercent)) · \(option.passesCode ? "code OK" : "over code")",
                        tone: option.passesCode ? Theme.foreground : Theme.bad
                    )
                }
                ForEach(r.recommendations, id: \.kind.rawValue) { rec in
                    Text(rec.text)
                        .font(.subheadline)
                        .foregroundStyle(Theme.foreground)
                        .padding(.top, 4)
                        .accessibilityLabel("Recommendation. \(rec.text)")
                }
            }

            ResultCard(title: "8. Pull planning") {
                ResultRow(label: "Status", value: r.pullPlanning.status.displayName, emphasis: true, tone: pullTone(r.pullPlanning.status))
                Text("Installation-planning indicator, not a guarantee.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                ForEach(Array(r.pullPlanning.factors.enumerated()), id: \.offset) { _, factor in
                    ResultRow(label: factor.status.displayName, value: factor.detail)
                }
                jamRow(r.pullPlanning.jamming)
                Text(r.pullPlanning.tensionNote)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
            }

            ResultCard(title: "Current-carrying conductors") {
                ResultRow(label: "Physical conductors", value: "\(r.currentCarrying.physicalConductorCount)")
                ResultRow(label: "Marked current-carrying", value: "\(r.currentCarrying.automaticCurrentCarryingCount)")
                ResultRow(label: "Reported CCC", value: "\(r.currentCarrying.reportedCount)")
                ResultRow(label: "Unconfirmed neutrals", value: "\(r.currentCarrying.unconfirmedNeutralCount)")
                ResultRow(
                    label: "Ampacity review",
                    value: r.currentCarrying.adjustmentReviewMayBeRequired ? "May be required — 310.15(C)(1)" : "Not flagged from this count"
                )
                ForEach(Array(r.currentCarrying.notes.enumerated()), id: \.offset) { _, note in
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }

            ResultCard(title: "9. Visualization") {
                Text("Packing graphic is illustrative. Area-based fill does not predict exact conductor positions.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                ConduitCrossSectionCanvas(result: r)
                    .frame(height: 220)
                    .accessibilityLabel(crossSectionLabel(r))
                ConduitSizeComparisonBars(options: r.sizeOptions, preferred: r.preferredMaximumPercent, code: r.codeMaximumPercent)
            }

            ResultCard(title: "10. Assumptions and references") {
                ForEach(Array(r.assumptions.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                ForEach(r.references, id: \.citation) { ref in
                    ResultRow(label: ref.citation, value: ref.note)
                }
            }
        }
    }

    // MARK: - Actions

    private func calculate() {
        persistSchedule()
        if let problem = firstValidationProblem() {
            lastError = problem.error
            lastResult = nil
            focus = problem.field
            return
        }
        switch CalcCatch.run({ try ConduitFillPlanning.design(makeInput()) }) {
        case .success(let result):
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.2)) {
                    lastResult = result
                    lastError = nil
                    lastFingerprint = fingerprint
                }
            } else {
                lastResult = result
                lastError = nil
                lastFingerprint = fingerprint
            }
            legacyQty = String(groups.first?.quantity ?? 0)
            legacySize = groups.first?.size ?? legacySize
        case .failure(let error):
            lastError = error
            lastResult = nil
        }
    }

    private func firstValidationProblem() -> (error: CalcError, field: FocusField?)? {
        if groups.isEmpty {
            return (.missing("at least one conductor group"), nil)
        }
        if runKind == .nipple, (nippleInches.parsedDouble == nil || (nippleInches.parsedDouble ?? 0) <= 0) {
            return (.missing("nipple length in inches"), .nipple)
        }
        if let pref = preferredFill.parsedDouble {
            if !pref.isFinite || pref <= 0 || pref >= 100 {
                return (.outOfRange("Preferred fill must be greater than 0 and less than 100 percent."), .preferred)
            }
        } else {
            return (.missing("preferred maximum fill"), .preferred)
        }
        for group in groups {
            if group.quantity < 1 {
                return (.nonPositive("Conductor quantity"), .groupQty(group.id))
            }
            if !group.insulation.hasListedTable5Area && finite(group.customAreaSquareInches) == nil && finite(group.customOutsideDiameterInches) == nil {
                return (.notListed("\(group.insulation.displayName) needs a manufacturer area or OD."), .customArea(group.id))
            }
        }
        if racewayType.area(for: trade) == nil {
            return (.notListed("\(trade)\" is not listed for \(racewayType.displayName)."), nil)
        }
        return nil
    }

    // MARK: - Persistence

    private func migrateIfNeeded() {
        guard !didMigrate else { return }
        didMigrate = true
        if applyPendingRestore() { return }
        if let data = scheduleJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([ConductorGroup].self, from: data),
           !decoded.isEmpty {
            groups = decoded
            return
        }
        if let n = legacyQty.parsedDouble, let qty = try? WholeCount.parse(n, name: "Conductor quantity") {
            groups = [
                ConductorGroup(
                    quantity: qty,
                    size: legacySize,
                    insulation: .thhnTHWN2,
                    purpose: .phase,
                    description: "Restored last-used THHN group",
                    countsAsCurrentCarrying: true
                )
            ]
        } else {
            groups = ConduitFillPlanning.groups(for: .controlCircuit)
        }
        persistSchedule()
    }

    @discardableResult
    private func applyPendingRestore() -> Bool {
        let restoreKey = ToolInputStore.key(.conduitFill, "pendingRestore")
        guard let blob = UserDefaults.standard.string(forKey: restoreKey),
              let snap = try? ConduitFillJobSnapshot.decode(from: ["v2": blob]) else { return false }
        applySnapshot(snap)
        UserDefaults.standard.removeObject(forKey: restoreKey)
        persistSchedule()
        lastResult = nil
        lastFingerprint = ""
        return true
    }

    private func applySnapshot(_ snap: ConduitFillJobSnapshot) {
        groups = snap.input.groups
        racewayType = snap.input.raceway.type
        trade = snap.input.raceway.tradeSize
        if let nipple = snap.input.raceway.nippleLengthInches {
            nippleInches = String(nipple)
        }
        runKind = snap.input.installation.runKind
        location = snap.input.installation.location
        if let length = snap.input.route.lengthFeet { lengthFeet = String(length) }
        if let deg = snap.input.route.totalBendDegrees { bendDegrees = String(deg) }
        preferredFill = String(snap.input.preferences.preferredMaximumPercent)
        lubricant = snap.input.preferences.pullingLubricantPlanned
        pullMethod = snap.input.preferences.pullingMethod
    }

    private func persistSchedule() {
        if let data = try? JSONEncoder().encode(groups), let text = String(data: data, encoding: .utf8) {
            scheduleJSON = text
        }
        if let first = groups.first {
            legacyQty = String(first.quantity)
            legacySize = first.size
        }
    }

    private var snapshot: ConduitFillJobSnapshot {
        ConduitFillJobSnapshot(input: makeInput())
    }

    private func makeInput() -> ConduitFillInput {
        ConduitFillInput(
            groups: groups,
            raceway: RacewaySelection(
                type: racewayType,
                tradeSize: trade,
                nippleLengthInches: nippleInches.parsedDouble
            ),
            route: PullRoute(
                lengthFeet: lengthFeet.parsedDouble,
                totalBendDegrees: bendDegrees.parsedDouble,
                bendCount: intValue(bendCount),
                bendRadiusInches: bendRadius.parsedDouble,
                verticalRiseFeet: riseFeet.parsedDouble,
                pullPointCount: intValue(pullPoints)
            ),
            preferences: ConduitFillPreferences(
                preferredMaximumPercent: preferredFill.parsedDouble ?? 30,
                pullingLubricantPlanned: lubricant,
                pullingMethod: pullMethod,
                manufacturerMaxTensionPounds: maxTension.parsedDouble,
                manufacturerSidewallPoundsPerFoot: sidewall.parsedDouble,
                currentCarryingOverride: intValue(cccOverride)
            ),
            installation: InstallationConditions(location: location, runKind: runKind)
        )
    }

    private var fingerprint: String {
        let data = try? JSONEncoder().encode(makeInput())
        return data?.base64EncodedString() ?? ""
    }

    private var isStale: Bool {
        lastResult != nil && !lastFingerprint.isEmpty && lastFingerprint != fingerprint
    }

    private var sticky: String? {
        guard let lastResult else { return nil }
        let stale = isStale ? " · inputs changed" : ""
        return "\(Format.percent(lastResult.actualFillPercent))  ·  \(lastResult.passesCodeFill ? "CODE PASS" : "CODE FAIL")\(stale)"
    }

    private var copyText: String? {
        guard let lastResult else { return nil }
        return shareLines(lastResult).sorted().map { "\($0.key): \($0.value)" }.joined(separator: "\n")
    }

    private func shareLines(_ r: ConduitFillDesignResult) -> [String: String] {
        var out: [String: String] = [
            "raceway": r.selectedRaceway.displayName,
            "fill": Format.percent(r.actualFillPercent),
            "codeMax": Format.percent(r.codeMaximumPercent),
            "compliance": r.passesCodeFill ? "PASS" : "FAIL",
            "minCode": r.minimumCompliantRaceway?.displayName ?? "none listed",
            "preferred": r.preferredRaceway?.displayName ?? "none listed",
            "ccc": "\(r.currentCarrying.reportedCount) of \(r.currentCarrying.physicalConductorCount)",
            "pull": r.pullPlanning.status.displayName,
            "edition": r.edition.displayName,
            "schedule": r.conductorBreakdown.map(\.label).joined(separator: "; "),
        ]
        if case .unavailable(let reason) = r.pullPlanning.jamming {
            out["jamming"] = "Unavailable — \(reason)"
        } else if case .screened(let ratio, let caution, _, _) = r.pullPlanning.jamming {
            out["jamming"] = "Ratio \(Format.number(ratio, digits: 2))\(caution ? " caution band" : "")"
        }
        return out
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(Theme.muted)
    }

    private func cccCaption(_ group: ConductorGroup) -> String {
        switch group.resolvedCurrentCarrying {
        case true: return "Counts as current-carrying for adjustment review"
        case false: return "Not current-carrying; still counts toward physical fill"
        default: return "Current-carrying treatment not assumed"
        }
    }

    private func optionLabel(_ option: RacewaySizeOption) -> String {
        let kind: String
        switch option.kind {
        case .selected: kind = "Selected"
        case .minimumCode: kind = "Code minimum"
        case .preferred: kind = "Preferred (not code)"
        case .nextLarger: kind = "Next larger"
        }
        return "\(kind) · \(option.selection.displayName)"
    }

    private func pullTone(_ status: PullPlanningStatus) -> Color {
        switch status {
        case .favorable: return Theme.good
        case .moderate: return Theme.warn
        case .difficult, .engineeringReview: return Theme.bad
        }
    }

    @ViewBuilder
    private func jamRow(_ jam: JammingScreening) -> some View {
        switch jam {
        case .unavailable(let reason):
            ResultRow(label: "Jamming analysis", value: "Unavailable")
            Text(reason)
                .font(.caption)
                .foregroundStyle(Theme.muted)
        case .screened(let ratio, let caution, _, _):
            ResultRow(
                label: "Jam-ratio screen",
                value: "\(Format.number(ratio, digits: 2))\(caution ? " · caution band" : " · outside 2.8–3.2")",
                tone: caution ? Theme.warn : Theme.foreground
            )
            Text("Derived ID/OD screen, not proof that jamming will or will not occur.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }

    private func crossSectionLabel(_ r: ConduitFillDesignResult) -> String {
        "Illustrative raceway cross-section. Actual fill \(Format.percent(r.actualFillPercent)). Code limit \(Format.percent(r.codeMaximumPercent)). Preferred target \(Format.percent(r.preferredMaximumPercent))."
    }

    private func intValue(_ text: String) -> Int? {
        guard let value = text.parsedDouble, value.isFinite else { return nil }
        return try? WholeCount.parse(value, name: "Count")
    }

    private func finite(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value > 0 else { return nil }
        return value
    }

    private func focusNumber(_ title: String, unit: String, text: Binding<String>, field: FocusField, optional: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.muted)
                if optional {
                    Text("optional")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted.opacity(0.7))
                }
            }
            HStack {
                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .font(.title3.monospacedDigit().weight(.medium))
                    .focused($focus, equals: field)
                    .accessibilityLabel(title)
                Text(unit)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: Theme.touchTarget)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(focus == field ? Theme.accent : Theme.border, lineWidth: focus == field ? 2 : 1)
            )
        }
    }
}

private struct ConductorGroupEditor: View {
    @State var group: ConductorGroup
    let sizes: [String]
    var onSave: (ConductorGroup) -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    stepper("Quantity", value: $group.quantity)
                    MenuField(title: "Size", selection: $group.size, options: sizes, label: NECTables.wireLabel)
                    MenuField(title: "Insulation / type", selection: $group.insulation, options: ConductorInsulation.allCases) { $0.displayName }
                    if !group.insulation.hasListedTable5Area {
                        Text(group.insulation.source.notes)
                            .font(.caption)
                            .foregroundStyle(Theme.warn)
                    }
                    Picker("Material", selection: $group.material) {
                        ForEach(ConductorMaterial.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    MenuField(title: "Purpose", selection: $group.purpose, options: ConductorPurpose.allCases) { $0.displayName }
                    TextField("Description / purpose note", text: $group.description)
                        .padding(12)
                        .frame(minHeight: Theme.touchTarget)
                        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    TextField("Manufacturer / product note", text: $group.manufacturerNote)
                        .padding(12)
                        .frame(minHeight: Theme.touchTarget)
                        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Picker("Current-carrying", selection: cccBinding) {
                        Text("Default for purpose").tag(Optional<Bool>.none)
                        Text("Yes — counts for adjustment").tag(Optional.some(true))
                        Text("No — fill only").tag(Optional.some(false))
                    }
                    optionalDouble("Custom area", unit: "in²", value: $group.customAreaSquareInches)
                    optionalDouble("Custom OD", unit: "in", value: $group.customOutsideDiameterInches)
                    Text("Custom area is used for fill when present. Otherwise custom OD is converted with π(d/2)². Table 5 is never silently substituted.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Conductor group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(group) }
                }
            }
        }
    }

    private var cccBinding: Binding<Bool?> {
        Binding(
            get: { group.countsAsCurrentCarrying },
            set: { group.countsAsCurrentCarrying = $0 }
        )
    }

    private func stepper(_ title: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: 1...400) {
            Text("\(title): \(value.wrappedValue)")
                .frame(minHeight: Theme.touchTarget)
        }
        .accessibilityLabel(title)
        .accessibilityValue("\(value.wrappedValue)")
    }

    private func optionalDouble(_ title: String, unit: String, value: Binding<Double?>) -> some View {
        let text = Binding<String>(
            get: { value.wrappedValue.map { String($0) } ?? "" },
            set: { new in
                if new.trimmingCharacters(in: .whitespaces).isEmpty {
                    value.wrappedValue = nil
                } else {
                    value.wrappedValue = NumericParse.parse(new)
                }
            }
        )
        return NumberField(title: title, unit: unit, text: text, optional: true)
    }
}

private struct ConduitCrossSectionCanvas: View {
    let result: ConduitFillDesignResult
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let racewayR = side * 0.42
            var raceway = Path()
            raceway.addEllipse(in: CGRect(x: center.x - racewayR, y: center.y - racewayR, width: racewayR * 2, height: racewayR * 2))
            context.stroke(raceway, with: .color(Theme.foreground), lineWidth: 3)
            context.fill(raceway, with: .color(Theme.accent.opacity(0.08)))

            let conductors = result.conductorBreakdown.flatMap { row in
                (0..<row.quantity).map { _ in row }
            }
            guard !conductors.isEmpty else { return }
            let maxUnit = conductors.map(\.unitArea).max() ?? 1
            let count = conductors.count
            for (index, row) in conductors.enumerated() {
                let frac = max(0.12, min(0.28, (row.unitArea / maxUnit).squareRoot() * 0.22))
                let cr = racewayR * frac
                let ring = racewayR * (count == 1 ? 0 : 0.55)
                let angle = (Double.pi * 2 * Double(index) / Double(max(count, 1))) - Double.pi / 2
                let cx = center.x + ring * Foundation.cos(angle)
                let cy = center.y + ring * Foundation.sin(angle)
                var wire = Path()
                wire.addEllipse(in: CGRect(x: cx - cr, y: cy - cr, width: cr * 2, height: cr * 2))
                let hue = purposeColor(row.purpose)
                context.fill(wire, with: .color(hue.opacity(0.85)))
                context.stroke(wire, with: .color(Theme.foreground.opacity(0.7)), lineWidth: 1)
            }
        }
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityAddTraits(.isImage)
    }

    private func purposeColor(_ purpose: ConductorPurpose) -> Color {
        switch purpose {
        case .phase: return Theme.accent
        case .neutral: return Theme.foreground
        case .equipmentGround: return Theme.good
        case .control: return Theme.accent2
        case .spare: return Theme.muted
        }
    }
}

private struct ConduitSizeComparisonBars: View {
    let options: [RacewaySizeOption]
    let preferred: Double
    let code: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Raceway-size comparison")
                .font(.subheadline.weight(.semibold))
            ForEach(options, id: \.selection.tradeSize) { option in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(kindName(option.kind)): \(option.selection.displayName) — \(Format.percent(option.actualFillPercent))")
                        .font(.caption)
                        .foregroundStyle(Theme.foreground)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.border.opacity(0.4))
                            Capsule()
                                .fill(option.passesCode ? Theme.accent : Theme.bad)
                                .frame(width: geo.size.width * min(1, option.actualFillPercent / max(code, 1)))
                            Rectangle()
                                .fill(Theme.warn)
                                .frame(width: 2, height: 12)
                                .offset(x: geo.size.width * min(1, preferred / max(code, 1)))
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(height: 12)
                    Text(option.passesCode ? "Code compliant" : "Over code limit")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(kindName(option.kind)) \(option.selection.displayName), fill \(Format.percent(option.actualFillPercent)), \(option.passesCode ? "code compliant" : "over code limit")")
            }
            Text("Tick mark is the preferred-fill target, not a code line.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
        }
    }

    private func kindName(_ kind: RacewaySizeOption.Kind) -> String {
        switch kind {
        case .selected: return "Selected"
        case .minimumCode: return "Code minimum"
        case .preferred: return "Preferred"
        case .nextLarger: return "Next larger"
        }
    }
}
