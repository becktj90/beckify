import PhotosUI
import SwiftUI
import UIKit
import ImageIO
@preconcurrency import Vision
import BeckifyMath

/// Photograph or pick a panel schedule / directory sticker, run on-device
/// Vision, then map lines into an editable circuit table. A human must
/// confirm before Saved Jobs or demand numbers are treated as reviewed.
/// Optional cloud Analyze POSTs only after the user taps the button.
struct PanelDirectoryView: View {
    @EnvironmentObject private var jobs: JobStore
    @Environment(\.openRelatedTool) private var openRelated
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StoredInput(.panelDirectory, "text", default: "") private var text
    @StoredInput(.panelDirectory, "jobName", default: "Panel directory") private var jobName
    @StoredInput(.panelDirectory, "panelName", default: "") private var panelName
    @StoredInput(.panelDirectory, "volts", default: "208") private var volts
    @StoredInput(.panelDirectory, "phases", default: "3") private var phases
    @StoredInput(.panelDirectory, "mainAmps", default: "") private var mainAmps
    @StoredInput(.panelDirectory, "occ", default: "other") private var occupancy
    @StoredInput(.panelDirectory, "spare", default: "0") private var spare
    @StoredInput(.panelDirectory, "endpoint", default: "") private var customEndpoint

    @State private var photoItems: [PhotosPickerItem] = []
    @State private var capturedImages: [UIImage] = []
    @State private var pendingCameraImage: UIImage?
    @State private var showCamera = false
    @State private var isRecognizing = false
    @State private var recognizeError: String?
    @State private var session = ExplicitCalculationState<PanelScheduleExtraction>()
    @State private var draft: [PanelCircuitDraft] = []
    @State private var confirmed = false
    @State private var successTick = 0
    @State private var cameraUnavailable = false
    @State private var recognizedLines: [PanelOCRLine] = []
    @State private var token = ""
    @State private var analyzing = false
    @State private var analyzeProgress: Double = 0
    @State private var analyzeStatus = ""
    @State private var analyzeError: String?
    @State private var cloudWarnings: [String] = []

    private var inputFingerprint: String { text }

    private var occupancyValue: LoadWorksheetOccupancy {
        LoadWorksheetOccupancy(rawValue: occupancy) ?? .other
    }

    private var phaseCount: Int { Int(phases) ?? 3 }

    private var tsv: String {
        guard !draft.isEmpty else { return "" }
        return PanelScheduleExtraction(
            circuits: draft,
            rawLines: [],
            agentID: session.displayedResult?.agentID ?? "heuristic-v1",
            leavesDevice: false
        ).tsv()
    }

    var body: some View {
        ToolScaffold(
            toolID: .panelDirectory,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .designAidExtra(
                "On-device Vision is the default. Recognition can invent or drop circuits — confirm every row against the photo before trusting demand or capacity-to-add. Breaker trip is not measured load. The photo leaves this device only if you tap Analyze."
            ),
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .panelDirectory,
                symbolic: "Vision lines → circuit · name · trip · poles → optional Analyze → confirm → 220.42 demand / remaining A",
                substituted: substituted,
                meaning: "On-device text recognition is evidence, not the sticker. The heuristic agent maps lines into an editable schedule (value + confidence + reviewed) and guesses common hard-to-read tokens. Optional Analyze POSTs upright JPEGs to /api/analyze-panel and fills empty rows. Confirm marks reviewed. Demand treats trip as a conservative connected-amp estimate, then uses the same NEC 220.42 worksheet as Load Calculation Worksheet. Capacity-to-add is remaining main amps after that demand. Design aid — not a PE stamp.",
                citation: "Apple Vision on-device. Optional cloud Analyze uses the same JSON contract as the website. Parser is a heuristic agent unless you tap Analyze. NEC Table 220.42 as coded in Load Worksheet."
            )

            photoBlock

            panelInputs

            VStack(alignment: .leading, spacing: 8) {
                Text("SCHEDULE TEXT")
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.muted)
                TextEditor(text: $text)
                    .font(.body.monospaced())
                    .foregroundStyle(Theme.foreground)
                    .scrollContentBackground(.hidden)
                    .formFieldFocus("scheduleText")
                    .disabled(analyzing)
                    .frame(minHeight: 140)
                    .padding(12)
                    .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .accessibilityLabel("Panel schedule text")
                    .accessibilityHint("Paste recognized text from a panel sticker or type circuit rows. Locked while Analyze is running so the cloud draft cannot overwrite your edits. Analyze uploads only if you tap it.")
            }

            captureButtons

            if let recognizeError {
                ErrorText(message: recognizeError)
            }
            if let analyzeError {
                ErrorText(message: analyzeError)
            }

            CloudVisionAnalyzeChrome(
                title: "Analyze panel",
                defaultPath: BeckifyVisionAPI.analyzePath(for: .panel),
                accessibilityID: "analyzePanelButton",
                busy: analyzing,
                enabled: !capturedImages.isEmpty,
                progress: analyzeProgress,
                status: analyzeStatus,
                endpointFieldID: "panelEndpoint",
                tokenFieldID: "panelToken",
                customEndpoint: $customEndpoint,
                token: $token,
                onAnalyze: { Task { await analyzeCloud() } }
            )

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: loadExample,
                exampleTitle: "two-up lighting / receptacles"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ToolEmptyState(
                    title: "Photograph or pick a schedule",
                    detail: "Use the camera or photo library. Photos stay on screen. Vision reads them on this device, then Calculate maps lines into rows you can correct. Analyze is optional and uploads only if you tap it.",
                    systemImage: "list.bullet.rectangle"
                )
            } else if session.displayedResult == nil {
                ToolEmptyState(
                    title: "Tap Calculate to extract rows",
                    detail: "Schedule text is ready. Calculate runs the on-device heuristic agent — it does not dump the raw lines as truth.",
                    systemImage: "play.circle"
                )
            } else if draft.isEmpty {
                ToolEmptyState(
                    title: "No circuits found",
                    detail: "Need a circuit number and a name on each row. Trip and poles are optional. Header lines and panel ratings are skipped.",
                    systemImage: "magnifyingglass"
                )
            } else {
                reviewSheet
                demandCard
            }
        }
        .onAppear {
            restoreSavedReviewIfNeeded()
        }
        .onChange(of: inputFingerprint) { _, _ in
            guard !analyzing else { return }
            session.markInputsChanged()
            confirmed = false
        }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await recognize(from: items) }
        }
        .sheet(isPresented: $showCamera) {
            CameraImagePicker(image: $pendingCameraImage) {
                showCamera = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: pendingCameraImage) { _, image in
            guard let image else { return }
            capturedImages.append(image)
            pendingCameraImage = nil
            Task { await recognize(from: [image], replacingText: false) }
        }
        .sensoryFeedback(.success, trigger: successTick)
        .alert("Camera not available", isPresented: $cameraUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device or Simulator has no camera. Pick a photo from the library instead.")
        }
    }

    // MARK: - Photo + capture

    @ViewBuilder
    private var photoBlock: some View {
        if !capturedImages.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(capturedImages.count == 1 ? "SCHEDULE PHOTO" : "SCHEDULE PHOTOS")
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.muted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(capturedImages.enumerated()), id: \.offset) { index, image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Theme.border, lineWidth: 1)
                                )
                                .accessibilityLabel("Panel schedule photo \(index + 1) of \(capturedImages.count). On-device unless you tap Analyze.")
                        }
                    }
                }
            }
        }
    }

    private var captureButtons: some View {
        ThumbButtonRow {
            Button {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCamera = true
                } else {
                    cameraUnavailable = true
                }
            } label: {
                Label("Take photo", systemImage: "camera")
                    .frame(minHeight: Theme.touchTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(isRecognizing || analyzing)
            .accessibilityHint("Opens the camera. The photo stays on this device until you tap Analyze.")

            PhotosPicker(selection: $photoItems, maxSelectionCount: 6, matching: .images, photoLibrary: .shared()) {
                Label(
                    isRecognizing ? "Reading…" : "Choose photo",
                    systemImage: "photo.on.rectangle"
                )
                .frame(minHeight: Theme.touchTarget)
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .disabled(isRecognizing || analyzing)

            if !text.isEmpty || !capturedImages.isEmpty {
                Button {
                    reset()
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                        .frame(minHeight: Theme.touchTarget)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var panelInputs: some View {
        TextInputField(
            title: "Panel",
            text: $panelName,
            optional: true,
            autocapitalization: .characters,
            fieldID: "panelName"
        )
        NumberField(title: "Voltage", unit: "V", text: $volts, fieldID: "volts")
        MenuField(title: "System", selection: $phases, options: ["1", "3"]) {
            $0 == "1" ? "1-phase" : "3-phase"
        }
        NumberField(title: "Main rating", unit: "A", text: $mainAmps, optional: true, fieldID: "mainAmps")
        MenuField(title: "Occupancy", selection: $occupancy, options: LoadWorksheetOccupancy.allCases.map(\.rawValue)) {
            LoadWorksheetOccupancy(rawValue: $0)?.label ?? $0
        }
        NumberField(title: "Spare", unit: "%", text: $spare, fieldID: "spare")
    }

    // MARK: - Review

    @ViewBuilder
    private var reviewSheet: some View {
        let lowCount = draft.filter(\.isLowConfidence).count

        ResultCard(title: "Editable schedule", copyText: tsv) {
            Text(confirmed
                 ? "Confirmed. Demand below uses these rows. You can save a job or seed Load Calculation Worksheet."
                 : "Correct any row against the photo, then confirm. Yellow fields are low confidence or guessed.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)

            if lowCount > 0, !confirmed {
                Text("\(lowCount) row\(lowCount == 1 ? "" : "s") flagged for a closer look.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.warn)
            }
            if !cloudWarnings.isEmpty {
                ForEach(Array(cloudWarnings.enumerated()), id: \.offset) { _, warning in
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(Theme.warn)
                }
            }

            ForEach(Array(draft.enumerated()), id: \.element.id) { index, _ in
                circuitEditor(index)
            }

            Button {
                draft.append(PanelCircuitDraft(
                    circuit: nextCircuitNumber(),
                    name: "",
                    confidence: 1,
                    source: .user
                ))
                confirmed = false
            } label: {
                Label("Add circuit", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity, minHeight: Theme.touchTarget, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
        }
        .opacity(session.isStale ? 0.72 : 1)

        Button {
            confirmReview()
        } label: {
            Text(confirmed ? "Confirmed" : "Confirm reviewed schedule")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
        }
        .buttonStyle(.borderedProminent)
        .tint(confirmed ? Theme.good : Theme.accent)
        .disabled(session.isStale || draft.isEmpty)
        .accessibilityIdentifier("confirmPanelScheduleButton")
        .accessibilityHint("Required before saving a job or seeding Load Calculation Worksheet. Check highlighted rows against the photo.")
    }

    @ViewBuilder
    private func circuitEditor(_ index: Int) -> some View {
        let low = !confirmed && draft[index].isLowConfidence
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CIRCUIT \(draft[index].circuit.isEmpty ? "—" : draft[index].circuit)")
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.muted)
                if low {
                    Text(draft[index].guessed ? "guessed" : "check")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.warn)
                }
                Spacer()
                Button(role: .destructive) {
                    draft.remove(at: index)
                    confirmed = false
                } label: {
                    Image(systemName: "trash")
                        .frame(minWidth: Theme.touchTarget, minHeight: Theme.touchTarget)
                }
                .accessibilityLabel("Delete circuit")
            }

            HStack(spacing: 10) {
                TextInputField(
                    title: "Ckt",
                    text: binding(index, \.circuit),
                    fieldID: "ckt-\(draft[index].id)",
                    lowConfidence: low
                )
                .frame(maxWidth: 88)
                TextInputField(
                    title: "Name",
                    text: binding(index, \.name),
                    autocapitalization: .characters,
                    fieldID: "name-\(draft[index].id)",
                    lowConfidence: low
                )
            }
            HStack(spacing: 10) {
                TextInputField(
                    title: "Trip",
                    text: binding(index, \.trip),
                    optional: true,
                    unit: "",
                    autocapitalization: .characters,
                    fieldID: "trip-\(draft[index].id)",
                    lowConfidence: low && draft[index].trip.isEmpty
                )
                TextInputField(
                    title: "Poles",
                    text: binding(index, \.poles),
                    optional: true,
                    fieldID: "poles-\(draft[index].id)"
                )
                .frame(maxWidth: 100)
            }
            MenuField(
                title: "Class",
                selection: binding(index, \.loadClass),
                options: LoadRowType.allCases
            ) { $0.label }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }

    private func binding<Value>(_ index: Int, _ keyPath: WritableKeyPath<PanelCircuitDraft, Value>) -> Binding<Value> {
        Binding(
            get: { draft[index][keyPath: keyPath] },
            set: { newValue in
                draft[index][keyPath: keyPath] = newValue
                draft[index].source = .user
                draft[index].confidence = 1
                draft[index].guessed = false
                draft[index].reviewed = false
                confirmed = false
            }
        )
    }

    @ViewBuilder
    private var demandCard: some View {
        if let demand = currentDemand() {
            ResultCard(title: "Demand / capacity to add", copyText: demand.copyLine) {
                ResultRow(label: "Connected", value: "\(Format.number(demand.connectedVA, digits: 0)) VA")
                ResultRow(label: "Lighting demand", value: "\(Format.number(demand.lightingDemandVA, digits: 0)) VA")
                ResultRow(label: "Other demand", value: "\(Format.number(demand.otherDemandVA, digits: 0)) VA")
                ResultRow(label: "Total demand", value: "\(Format.number(demand.totalDemandVA, digits: 0)) VA", emphasis: true)
                if demand.spareVA > 0 {
                    ResultRow(label: "With spare", value: "\(Format.number(demand.grandTotalVA, digits: 0)) VA", tone: Theme.copper)
                }
                ResultRow(label: "Demand amps", value: Format.amps(demand.demandAmps), emphasis: true, tone: Theme.good)
                if let main = demand.mainAmps {
                    ResultRow(label: "Main", value: Format.amps(main))
                }
                if let add = demand.capacityToAddAmps {
                    ResultRow(
                        label: "Capacity to add",
                        value: Format.amps(add),
                        emphasis: true,
                        tone: add >= 0 ? Theme.good : Theme.bad
                    )
                }
                if let util = demand.utilization {
                    ResultRow(label: "Main utilization", value: "\(Format.number(util * 100, digits: 0)) %")
                }
                if demand.unusedPositions > 0 {
                    ResultRow(label: "Spare / space", value: "\(demand.unusedPositions)")
                }
                if demand.circuitsMissingTrip > 0 {
                    ResultRow(label: "Missing trip", value: "\(demand.circuitsMissingTrip)", tone: Theme.warn)
                }
                Text(demand.caveats.joined(separator: " "))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 6)
            }
            .opacity(session.isStale || !confirmed ? 0.72 : 1)

            if !confirmed {
                Text("Confirm the schedule before treating these amps as reviewed.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.warn)
            }

            if confirmed, !session.isStale {
                SaveJobBar(jobName: $jobName, canSave: true) {
                    let extraction = session.displayedResult?
                        .applying(draft: draft)
                        .applyingHeader(panelName: panelName, voltage: volts, mainRating: mainAmps, phases: phases)
                        .confirmingReview()
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .panelDirectory,
                        inputs: [
                            "text": text,
                            "jobName": jobName,
                            "panelName": panelName,
                            "volts": volts,
                            "phases": phases,
                            "mainAmps": mainAmps,
                            "occ": occupancy,
                            "spare": spare,
                            "rows": "\(draft.count)",
                        ],
                        outputs: [
                            "circuits": draft.map(\.circuit).joined(separator: ","),
                            "tsv": tsv,
                            "confirmed": "true",
                            "reviewed": "true",
                            "agent": extraction?.agentID ?? "heuristic-v1",
                            "demandVA": Format.number(demand.totalDemandVA, digits: 0),
                            "demandA": Format.amps(demand.demandAmps),
                            "capacityToAddA": demand.capacityToAddAmps.map(Format.amps) ?? "",
                        ]
                    ))
                }

                handoffSection
            }
        }
    }

    private var handoffSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SEED A RELATED TOOL")
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.muted)
            Text("Writes confirmed category VA totals into that tool’s last-used fields on this device.")
                .font(.caption)
                .foregroundStyle(Theme.muted)

            Button {
                PanelScheduleHandoff.seedWorksheet(
                    circuits: draft,
                    voltage: volts.parsedDouble ?? .nan,
                    phases: phaseCount,
                    occupancy: occupancyValue
                )
                openRelated(.loadWorksheet)
            } label: {
                Label("Open Load Calculation Worksheet with these totals", systemImage: "list.clipboard")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: Theme.touchTarget, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .accessibilityLabel("Seed Load Calculation Worksheet from confirmed panel rows")
        }
    }

    // MARK: - Actions

    private func calculate() {
        session.calculate {
            let extracted = extractionFromCurrentText()
            guard !extracted.circuits.isEmpty else {
                throw CalcError.missing("circuit rows with a number and a name")
            }
            return extracted
        }
        if let extracted = session.displayedResult, !session.isStale {
            apply(extracted)
            confirmed = false
            if !reduceMotion { successTick += 1 }
        }
    }

    private func confirmReview() {
        guard let current = session.displayedResult, !session.isStale, !draft.isEmpty else { return }
        let reviewed = current
            .applying(draft: draft)
            .applyingHeader(panelName: panelName, voltage: volts, mainRating: mainAmps, phases: phases)
            .confirmingReview()
        session.calculate { reviewed }
        confirmed = true
        draft = reviewed.circuits
        if !reduceMotion { successTick += 1 }
    }

    private func apply(_ extracted: PanelScheduleExtraction) {
        draft = extracted.circuits
        if extracted.panelName.isPresent { panelName = extracted.panelName.value }
        if extracted.phases.isPresent { phases = extracted.phases.value }
        if extracted.mainRating.isPresent {
            mainAmps = extracted.mainRating.value.replacingOccurrences(of: "A", with: "")
        }
        if let guess = PanelScheduleParser.parseVoltage(extracted.voltage.value) {
            if let ll = guess.lineToLine {
                volts = ll == floor(ll) ? String(Int(ll)) : String(format: "%.1f", ll)
            } else if let ln = guess.lineToNeutral {
                volts = ln == floor(ln) ? String(Int(ln)) : String(format: "%.1f", ln)
            }
            if let inferred = guess.phases {
                phases = "\(inferred)"
            }
        }
    }

    private func extractionFromCurrentText() -> PanelScheduleExtraction {
        if recognizedLinesMatchEditor() {
            return PanelScheduleParser.extract(lines: recognizedLines)
        }
        return PanelScheduleParser.extract(text: text)
    }

    private func recognizedLinesMatchEditor() -> Bool {
        guard !recognizedLines.isEmpty else { return false }
        let fromLines = recognizedLines
            .map(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let editor = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return fromLines == editor
    }

    private func restoreSavedReviewIfNeeded() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard session.displayedResult == nil else { return }
        calculate()
    }

    private func reset() {
        text = ""
        recognizeError = nil
        analyzeError = nil
        analyzeProgress = 0
        analyzeStatus = ""
        cloudWarnings = []
        capturedImages = []
        photoItems = []
        pendingCameraImage = nil
        draft = []
        recognizedLines = []
        confirmed = false
        session.reset()
    }

    @MainActor
    private func analyzeCloud() async {
        guard !capturedImages.isEmpty, !analyzing else { return }
        analyzing = true
        analyzeError = nil
        recognizeError = nil
        analyzeProgress = 0.12
        analyzeStatus = "Preparing photo…"
        defer { analyzing = false }
        do {
            var merged: PanelScheduleExtraction?
            var warnings: [String] = []
            var rawParts: [String] = []
            let total = capturedImages.count
            for (index, image) in capturedImages.enumerated() {
                let start = Double(index) / Double(total)
                analyzeProgress = min(0.9, start + 0.2 / Double(total))
                analyzeStatus = total == 1
                    ? "Sending upright photo for a panel draft…"
                    : "Sending photo \(index + 1) of \(total)…"
                let payload = try await BeckifyVisionClient.analyze(
                    image: image,
                    task: .panel,
                    customEndpoint: customEndpoint,
                    token: token,
                    timeout: 90
                )
                let cloud = PanelCloudAnalyze.normalize(payload)
                warnings.append(contentsOf: cloud.warnings)
                if !cloud.rawOCR.isEmpty { rawParts.append(cloud.rawOCR) }
                merged = merged.map { PanelCloudAnalyze.merge($0, cloud.extraction) } ?? cloud.extraction
            }
            guard var extracted = merged, !extracted.circuits.isEmpty else {
                analyzeError = "Need circuit rows with a number and a name."
                analyzeProgress = 0
                analyzeStatus = "Panel analysis failed"
                return
            }
            if let current = session.displayedResult?.applying(draft: draft) {
                extracted = PanelCloudAnalyze.merge(existing: current, incoming: extracted)
            }
            if !rawParts.isEmpty {
                text = rawParts.joined(separator: "\n")
                recognizedLines = []
            }
            session.calculate { extracted }
            if let result = session.displayedResult, !session.isStale {
                apply(result)
            }
            cloudWarnings = warnings
            confirmed = false
            analyzeProgress = 1
            analyzeStatus = "Cloud draft ready. Confirm every row against the photo."
            if !reduceMotion { successTick += 1 }
        } catch {
            analyzeError = error.localizedDescription
            analyzeProgress = 0
            analyzeStatus = "Panel analysis failed"
        }
    }

    private func loadExample() {
        capturedImages = []
        recognizedLines = []
        analyzeError = nil
        analyzeProgress = 0
        analyzeStatus = ""
        cloudWarnings = []
        text = """
        Panel: LP-1
        Voltage: 208Y/120V
        Main Rating: 225A MCB
        1 LIGHTING OFFICE 20A 1P 2 RECEPTACLES 20A 1P
        3 AHU-1 40A 3P 4 SPARE 20A 1P
        """
        panelName = "LP-1"
        volts = "208"
        phases = "3"
        mainAmps = "225"
        occupancy = "other"
        spare = "0"
        recognizeError = nil
        confirmed = false
        session.prepareForNewInputs()
    }

    private func currentDemand() -> PanelDemandResult? {
        guard !draft.isEmpty else { return nil }
        return try? PanelScheduleDemand.estimate(
            circuits: draft,
            voltage: volts.parsedDouble ?? .nan,
            phases: phaseCount,
            mainAmps: mainAmps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : mainAmps.parsedDouble,
            occupancy: occupancyValue,
            sparePercent: spare.parsedDouble ?? 0
        )
    }

    private func nextCircuitNumber() -> String {
        let used = Set(draft.compactMap { Int($0.circuit) })
        var n = 1
        while used.contains(n) { n += 1 }
        return "\(n)"
    }

    private var substituted: String? {
        guard !draft.isEmpty else { return nil }
        if let demand = currentDemand() {
            return "\(draft.count) circuits · \(Format.number(demand.totalDemandVA, digits: 0)) VA · \(Format.amps(demand.demandAmps))"
        }
        return "\(draft.count) circuit\(draft.count == 1 ? "" : "s") extracted"
    }

    private var sticky: String? {
        guard !draft.isEmpty else { return nil }
        if let demand = currentDemand() {
            let prefix = confirmed ? "Confirmed" : "Review"
            if let add = demand.capacityToAddAmps {
                return "\(prefix)  ·  \(Format.amps(demand.demandAmps))  ·  add \(Format.amps(add))"
            }
            return "\(prefix)  ·  \(draft.count) ckt  ·  \(Format.amps(demand.demandAmps))"
        }
        return confirmed
            ? "Confirmed  ·  \(draft.count) circuit\(draft.count == 1 ? "" : "s")"
            : "Review  ·  \(draft.count) circuit\(draft.count == 1 ? "" : "s")"
    }

    private var copyText: String? {
        if let demand = currentDemand(), !draft.isEmpty {
            return [tsv, demand.copyLine].joined(separator: "\n")
        }
        return draft.isEmpty ? nil : tsv
    }

    // MARK: - Vision (on-device)

    @MainActor
    private func recognize(from items: [PhotosPickerItem]) async {
        recognizeError = nil
        defer { photoItems = [] }
        var images: [UIImage] = []
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data)
                else { continue }
                if data.count > BeckifyVisionAPI.maxPickBytes {
                    recognizeError = "Please choose an image smaller than 12 MB."
                    return
                }
                images.append(image)
            } catch {
                continue
            }
        }
        guard !images.isEmpty else {
            recognizeError = "Could not read that photo."
            return
        }
        capturedImages = images
        await recognize(from: images, replacingText: true)
    }

    @MainActor
    private func recognize(from images: [UIImage], replacingText: Bool) async {
        let textBefore = text
        isRecognizing = true
        recognizeError = nil
        defer { isRecognizing = false }
        do {
            var allLines: [PanelOCRLine] = replacingText ? [] : recognizedLines
            var chunks: [String] = []
            if !replacingText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                chunks.append(text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            for image in images {
                let lines = try await Self.recognizeText(in: image)
                allLines.append(contentsOf: lines)
                let chunk = lines
                    .map(\.text)
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !chunk.isEmpty { chunks.append(chunk) }
            }
            guard text == textBefore else { return }
            let trimmed = chunks.joined(separator: "\n")
            if trimmed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                recognizeError = "No text found. Try a sharper, flatter shot of the directory."
                return
            }
            recognizedLines = allLines
            text = trimmed
            session.markInputsChanged()
            confirmed = false
        } catch {
            guard text == textBefore else { return }
            recognizeError = "On-device recognition failed. Paste the text instead."
        }
    }

    /// Vision text recognition. Nothing leaves the device. Keeps each
    /// candidate's confidence so extract can flag uncertain rows.
    private static func recognizeText(in image: UIImage) async throws -> [PanelOCRLine] {
        guard let cgImage = image.cgImage else { throw RecognitionError.unreadableImage }
        let orientation = cgImageOrientation(from: image.imageOrientation)

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                    let lines: [PanelOCRLine] = observations.compactMap { observation in
                        guard let candidate = observation.topCandidates(1).first else { return nil }
                        return PanelOCRLine(
                            text: candidate.string,
                            confidence: Double(candidate.confidence)
                        )
                    }
                    continuation.resume(returning: lines)
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false

                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func cgImageOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    private enum RecognitionError: Error {
        case unreadableImage
    }
}
