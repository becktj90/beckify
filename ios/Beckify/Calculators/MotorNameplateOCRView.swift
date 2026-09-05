import PhotosUI
import SwiftUI
import UIKit
import ImageIO
@preconcurrency import Vision
import BeckifyMath

/// Photograph or pick a motor nameplate, run on-device Vision, then map lines
/// into editable fields. A human must confirm before Saved Jobs. Optional
/// cloud Analyze POSTs only after the user taps the button.
struct MotorNameplateOCRView: View {
    @EnvironmentObject private var jobs: JobStore
    @Environment(\.openRelatedTool) private var openRelated
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StoredInput(.motorNameplateOCR, "text", default: "") private var text
    @StoredInput(.motorNameplateOCR, "jobName", default: "Motor nameplate") private var jobName
    @StoredInput(.motorNameplateOCR, "endpoint", default: "") private var customEndpoint

    @State private var photoItem: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var isRecognizing = false
    @State private var recognizeError: String?
    @State private var session = ExplicitCalculationState<NameplateExtraction>()
    @State private var draft: [NameplateFieldID: String] = [:]
    @State private var confidence: [NameplateFieldID: Double] = [:]
    @State private var confirmed = false
    @State private var successTick = 0
    @State private var cameraUnavailable = false
    /// Vision lines with `VNRecognizedText.confidence`. Used by extract so
    /// low-confidence fields stay highlighted instead of the parser default.
    @State private var recognizedLines: [NameplateOCRLine] = []
    @State private var token = ""
    @State private var analyzing = false
    @State private var analyzeProgress: Double = 0
    @State private var analyzeStatus = ""
    @State private var analyzeError: String?
    @State private var cloudWarnings: [String] = []

    private var inputFingerprint: String { text }

    private var reviewFields: [NameplateFieldID] { NameplateFieldID.allCases }

    private var filledDraft: [NameplateFieldID: String] {
        Dictionary(uniqueKeysWithValues: draft.filter { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    var body: some View {
        ToolScaffold(
            toolID: .motorNameplateOCR,
            stickyAnswer: sticky,
            copyText: copyText,
            disclaimer: .designAidExtra(
                "On-device Vision is the default. Recognition can misread a stamped plate — confirm every field against the photo before saving. The photo leaves this device only if you tap Analyze."
            ),
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .motorNameplateOCR,
                symbolic: "Vision lines → nameplate fields (HP, RPM, V, A, …) → optional Analyze → human confirm",
                substituted: substituted,
                meaning: "On-device text recognition is evidence, not the nameplate. The heuristic agent maps labeled lines into the shared nameplate schema (value + confidence + reviewed). Optional Analyze POSTs an upright JPEG to /api/analyze-nameplate and fills empty fields. Confirm marks reviewed. MOCP and LRA are never used as FLA. Then optionally seed Motor FLA, Motor Nameplate Analyzer, or Motor Speed. Design aid — not a PE stamp.",
                citation: "Apple Vision on-device. Optional cloud Analyze uses the same JSON contract as the website. Parser is a heuristic agent unless you tap Analyze. NEC math stays in Motor Nameplate Analyzer."
            )

            photoBlock

            VStack(alignment: .leading, spacing: 8) {
                Text("RECOGNIZED TEXT")
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.muted)
                TextEditor(text: $text)
                    .font(.body.monospaced())
                    .foregroundStyle(Theme.foreground)
                    .scrollContentBackground(.hidden)
                    .formFieldFocus("recognizedText")
                    .frame(minHeight: 120)
                    .padding(12)
                    .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .accessibilityLabel("Recognized nameplate text")
                    .accessibilityHint("Edit Vision text before extracting fields. Analyze uploads only if you tap it.")
            }

            captureButtons

            if let recognizeError {
                ErrorText(message: recognizeError)
            }
            if let analyzeError {
                ErrorText(message: analyzeError)
            }

            CloudVisionAnalyzeChrome(
                title: "Analyze nameplate",
                defaultPath: BeckifyVisionAPI.analyzePath(for: .nameplate),
                accessibilityID: "analyzeNameplateButton",
                busy: analyzing,
                enabled: capturedImage != nil,
                progress: analyzeProgress,
                status: analyzeStatus,
                endpointFieldID: "nameplateEndpoint",
                tokenFieldID: "nameplateToken",
                customEndpoint: $customEndpoint,
                token: $token,
                onAnalyze: { Task { await analyzeCloud() } }
            )

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: reset,
                onExample: loadExample,
                exampleTitle: "10 HP dual-voltage plate"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ToolEmptyState(
                    title: "Photograph or pick a nameplate",
                    detail: "Use the camera or photo library. Vision reads the plate on this device, then Calculate maps lines into fields you can correct. Analyze is optional and uploads only if you tap it.",
                    systemImage: "text.viewfinder"
                )
            } else if session.displayedResult == nil {
                ToolEmptyState(
                    title: "Tap Calculate to extract fields",
                    detail: "Recognized text is ready. Calculate runs the on-device heuristic agent — it does not dump the raw lines as truth.",
                    systemImage: "play.circle"
                )
            } else {
                reviewSheet
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
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await recognize(from: item) }
        }
        .sheet(isPresented: $showCamera) {
            CameraImagePicker(image: $capturedImage) {
                showCamera = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: capturedImage) { _, image in
            guard let image else { return }
            Task { await recognize(from: image) }
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
        if let capturedImage {
            VStack(alignment: .leading, spacing: 8) {
                Text("NAMEPLATE PHOTO")
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.muted)
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .accessibilityLabel("Nameplate photo. On-device unless you tap Analyze.")
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

            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                Label(
                    isRecognizing ? "Reading…" : "Choose photo",
                    systemImage: "photo.on.rectangle"
                )
                .frame(minHeight: Theme.touchTarget)
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .disabled(isRecognizing || analyzing)

            if !text.isEmpty || capturedImage != nil {
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

    // MARK: - Review

    @ViewBuilder
    private var reviewSheet: some View {
        let lowCount = reviewFields.filter { isLow($0) && !(draft[$0] ?? "").isEmpty }.count

        ResultCard(title: "Review fields", copyText: copyText) {
            Text(confirmed
                 ? "Confirmed. You can save a job or seed a related motor tool."
                 : "Correct any field against the plate, then confirm. Yellow fields are low confidence.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)

            if lowCount > 0, !confirmed {
                Text("\(lowCount) field\(lowCount == 1 ? "" : "s") flagged for a closer look.")
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

            ForEach(reviewFields, id: \.self) { id in
                reviewRow(id)
            }
        }
        .opacity(session.isStale ? 0.72 : 1)

        Button {
            confirmReview()
        } label: {
            Text(confirmed ? "Confirmed" : "Confirm reviewed fields")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
        }
        .buttonStyle(.borderedProminent)
        .tint(confirmed ? Theme.good : Theme.accent)
        .disabled(session.isStale || filledDraft.isEmpty)
        .accessibilityIdentifier("confirmNameplateButton")
        .accessibilityHint("Required before saving a job. Check highlighted fields against the photo.")

        if confirmed, !session.isStale {
            SaveJobBar(jobName: $jobName, canSave: true) {
                let record = session.displayedResult?
                    .applying(draft: draft, confidence: confidence)
                    .confirmingReview()
                    .schemaRecord(forceReviewed: true)
                var inputs = Dictionary(uniqueKeysWithValues: filledDraft.map { ($0.rawValue, $1) })
                let persistText = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? NameplateFieldParser.reconstructText(from: filledDraft)
                    : text
                inputs["text"] = persistText
                inputs["jobName"] = jobName
                jobs.save(SavedJob(
                    name: jobName,
                    toolID: .motorNameplateOCR,
                    inputs: inputs,
                    outputs: [
                        "confirmed": "true",
                        "reviewed": "true",
                        "agent": session.displayedResult?.agentID ?? "heuristic-v1",
                        "fields": "\(filledDraft.count)",
                        "schema": record?.jsonString() ?? "",
                    ]
                ))
            }

            handoffSection
        }
    }

    @ViewBuilder
    private func reviewRow(_ id: NameplateFieldID) -> some View {
        let binding = Binding(
            get: { draft[id] ?? "" },
            set: { newValue in
                draft[id] = newValue
                confidence[id] = 1
                confirmed = false
            }
        )
        let low = isLow(id)
        if id.isNumeric {
            NumberField(
                title: id.label,
                unit: id.unit(forValue: draft[id] ?? ""),
                text: binding,
                optional: id.isOptional,
                allowsScientific: true,
                fieldID: id.rawValue,
                lowConfidence: low
            )
        } else {
            TextInputField(
                title: id.label,
                text: binding,
                optional: id.isOptional,
                unit: id.unit(forValue: draft[id] ?? ""),
                autocapitalization: .characters,
                fieldID: id.rawValue,
                lowConfidence: low
            )
        }
    }

    private func isLow(_ id: NameplateFieldID) -> Bool {
        guard !confirmed else { return false }
        guard !(draft[id] ?? "").isEmpty else { return false }
        return (confidence[id] ?? 1) < NameplateFieldParser.lowConfidenceThreshold
    }

    private var handoffSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SEED A RELATED TOOL")
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.muted)
            Text("Writes confirmed values into that tool’s last-used fields on this device.")
                .font(.caption)
                .foregroundStyle(Theme.muted)

            ForEach([ToolID.motorFLA, .motorNameplate, .motorSpeed], id: \.self) { id in
                let tool = ToolboxCatalog.tool(id)
                Button {
                    MotorNameplateHandoff.seed(filledDraft, into: id)
                    openRelated(id)
                } label: {
                    Label("Open \(tool.title) with these values", systemImage: tool.symbol)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: Theme.touchTarget, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .accessibilityLabel("Seed \(tool.title) from confirmed nameplate fields")
            }
        }
    }

    // MARK: - Actions

    private func calculate() {
        session.calculate {
            let extracted = extractionFromCurrentText()
            guard extracted.populatedCount > 0 else {
                throw CalcError.missing("nameplate fields — check the photo or edit the recognized text")
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
        guard let current = session.displayedResult, !session.isStale, !filledDraft.isEmpty else { return }
        let reviewed = current.applying(draft: draft, confidence: confidence).confirmingReview()
        session.calculate { reviewed }
        confirmed = true
        apply(reviewed)
        if !reduceMotion { successTick += 1 }
    }

    private func apply(_ extracted: NameplateExtraction) {
        var nextDraft: [NameplateFieldID: String] = [:]
        var nextConfidence: [NameplateFieldID: Double] = [:]
        for id in NameplateFieldID.allCases {
            nextDraft[id] = extracted.value(id) ?? ""
            nextConfidence[id] = extracted.field(id)?.confidence ?? 1
        }
        draft = nextDraft
        confidence = nextConfidence
    }

    private func extractionFromCurrentText() -> NameplateExtraction {
        if recognizedLinesMatchEditor() {
            return NameplateFieldParser.extract(lines: recognizedLines)
        }
        return NameplateFieldParser.extract(text: text)
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

    /// Opening a saved job writes `text` / schema keys into last-used inputs.
    /// Rebuild the review sheet so it is not blank or leftover last-used text.
    private func restoreSavedReviewIfNeeded() {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var stored: [NameplateFieldID: String] = [:]
            for id in NameplateFieldID.allCases {
                let value = UserDefaults.standard.string(forKey: ToolInputStore.key(.motorNameplateOCR, id.rawValue)) ?? ""
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { stored[id] = trimmed }
            }
            if !stored.isEmpty {
                text = NameplateFieldParser.reconstructText(from: stored)
            }
        }
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
        capturedImage = nil
        photoItem = nil
        draft = [:]
        confidence = [:]
        recognizedLines = []
        confirmed = false
        session.reset()
    }

    @MainActor
    private func analyzeCloud() async {
        guard let capturedImage, !analyzing else { return }
        analyzing = true
        analyzeError = nil
        recognizeError = nil
        analyzeProgress = 0.16
        analyzeStatus = "Preparing photo…"
        defer { analyzing = false }
        do {
            analyzeProgress = 0.42
            analyzeStatus = "Sending upright photo for a nameplate draft…"
            let payload = try await BeckifyVisionClient.analyze(
                image: capturedImage,
                task: .nameplate,
                customEndpoint: customEndpoint,
                token: token
            )
            analyzeProgress = 0.86
            analyzeStatus = "Reading the cloud draft…"
            let cloud = NameplateCloudAnalyze.normalize(payload)
            let existing = session.displayedResult?.applying(draft: draft, confidence: confidence)
            let merged = NameplateCloudAnalyze.merge(existing: existing, incoming: cloud.extraction)
            guard merged.populatedCount > 0 else {
                analyzeError = "Need nameplate fields — check the photo or edit the recognized text."
                analyzeProgress = 0
                analyzeStatus = "Nameplate analysis failed"
                return
            }
            if !cloud.rawOCR.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                text = cloud.rawOCR
                recognizedLines = []
            }
            session.calculate { merged }
            if let extracted = session.displayedResult, !session.isStale {
                apply(extracted)
            }
            cloudWarnings = cloud.warnings
            confirmed = false
            analyzeProgress = 1
            analyzeStatus = "Cloud draft ready. Confirm every field against the photo."
            if !reduceMotion { successTick += 1 }
        } catch {
            analyzeError = error.localizedDescription
            analyzeProgress = 0
            analyzeStatus = "Nameplate analysis failed"
        }
    }

    private func invalidateConfirmedReview() {
        text = ""
        recognizedLines = []
        draft = [:]
        confidence = [:]
        confirmed = false
        session.reset()
    }

    private func loadExample() {
        capturedImage = nil
        recognizedLines = []
        analyzeError = nil
        analyzeProgress = 0
        analyzeStatus = ""
        cloudWarnings = []
        text = """
        EXAMPLE MOTORS
        MODEL 10HP-215
        HP 10
        RPM 1750
        VOLTS 230/460
        AMPS 25.0/12.5
        LRA 72
        MOCP 40
        HZ 60
        PH 3
        SF 1.15
        PF 82
        EFF 89.5
        FRAME 215T
        ENCL TEFC
        DESIGN B
        CODE G
        CLASS F
        SER A12345
        """
        recognizeError = nil
        confirmed = false
        session.prepareForNewInputs()
    }

    private var substituted: String? {
        guard let extracted = session.displayedResult else { return nil }
        let hp = draft[.ratedHP] ?? extracted.value(.ratedHP) ?? "—"
        let rpm = draft[.rpm] ?? extracted.value(.rpm) ?? "—"
        let volts = draft[.voltage] ?? extracted.value(.voltage) ?? "—"
        return "\(extracted.populatedCount) fields · HP \(hp) · \(rpm) RPM · \(volts) V"
    }

    private var sticky: String? {
        guard session.displayedResult != nil else { return nil }
        let hp = draft[.ratedHP] ?? "—"
        let rpm = draft[.rpm] ?? "—"
        return confirmed
            ? "Confirmed  ·  \(hp) HP  ·  \(rpm) RPM"
            : "Review  ·  \(hp) HP  ·  \(rpm) RPM"
    }

    private var copyText: String? {
        guard !filledDraft.isEmpty else { return nil }
        return reviewFields.compactMap { id in
            guard let value = filledDraft[id] else { return nil }
            return "\(id.label): \(value)"
        }.joined(separator: "\n")
    }

    // MARK: - Vision (on-device)

    /// Library photos only assign `capturedImage`. Recognition runs once via
    /// `onChange(of: capturedImage)` — not a second concurrent Vision pass.
    @MainActor
    private func recognize(from item: PhotosPickerItem) async {
        recognizeError = nil
        defer { photoItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)
            else {
                recognizeError = "Could not read that photo."
                return
            }
            isRecognizing = true
            capturedImage = image
        } catch {
            recognizeError = "On-device recognition failed. Edit the text or try a flatter shot."
        }
    }

    @MainActor
    private func recognize(from image: UIImage) async {
        let textBefore = text
        isRecognizing = true
        recognizeError = nil
        defer { isRecognizing = false }
        do {
            try await applyRecognition(image, textBefore: textBefore)
        } catch {
            guard text == textBefore else { return }
            recognizeError = "On-device recognition failed. Edit the text or try a flatter shot."
        }
    }

    @MainActor
    private func applyRecognition(_ image: UIImage, textBefore: String) async throws {
        let lines = try await Self.recognizeText(in: image)
        guard text == textBefore else { return }
        let trimmed = lines
            .map(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            recognizeError = "No text found. Try a sharper, square-on shot of the nameplate."
            invalidateConfirmedReview()
            return
        }
        recognizedLines = lines
        text = trimmed
        session.markInputsChanged()
        confirmed = false
    }

    /// Vision text recognition. Nothing leaves the device. Keeps each
    /// candidate's confidence so extract can flag uncertain fields.
    private static func recognizeText(in image: UIImage) async throws -> [NameplateOCRLine] {
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
                    let lines: [NameplateOCRLine] = observations.compactMap { observation in
                        guard let candidate = observation.topCandidates(1).first else { return nil }
                        return NameplateOCRLine(
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

/// Still-photo capture. Live DataScanner is a poor fit for a nameplate review
/// sheet — the operator needs the photo next to the fields.
struct CameraImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraImagePicker
        init(_ parent: CameraImagePicker) { self.parent = parent }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onDismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            parent.image = info[.originalImage] as? UIImage
            parent.onDismiss()
        }
    }
}
