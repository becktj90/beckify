import PhotosUI
import SwiftUI
import UIKit
import ImageIO
@preconcurrency import Vision
import BeckifyMath

/// Paste or OCR a panel schedule / directory sticker into circuit rows.
struct PanelDirectoryView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.panelDirectory, "text", default: "") private var text
    @StoredInput(.panelDirectory, "jobName", default: "Panel directory") private var jobName

    @State private var photoItem: PhotosPickerItem?
    @State private var isRecognizing = false
    @State private var recognizeError: String?
    @State private var session = ExplicitCalculationState<[PanelCircuit]>()
    @State private var successTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inputFingerprint: String { text }

    private var circuits: [PanelCircuit] {
        session.displayedResult ?? []
    }

    private var tsv: String {
        guard !circuits.isEmpty else { return "" }
        var lines = ["Circuit\tName\tTrip\tPoles"]
        for row in circuits {
            lines.append("\(row.circuit)\t\(row.name)\t\(row.trip)\t\(row.poles)")
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        ToolScaffold(
            toolID: .panelDirectory,
            stickyAnswer: sticky,
            copyText: circuits.isEmpty ? nil : tsv,
            disclaimer: .designAidExtra("OCR and parsing stay on this device. Recognition noise can invent or drop circuits — verify against the sticker."),
            isResultStale: session.isStale
        ) {
            ShowWorkCard(
                toolID: .panelDirectory,
                symbolic: "circuit · name · [trip] · [poles]",
                substituted: circuits.isEmpty
                    ? nil
                    : "\(circuits.count) circuit\(circuits.count == 1 ? "" : "s") parsed",
                meaning: "Directory stickers often stop after the name. Trip and poles are optional. Two-up schedules put odds and evens on one line — the parser splits them."
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("SCHEDULE TEXT")
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.muted)
                TextEditor(text: $text)
                    .font(.body.monospaced())
                    .foregroundStyle(Theme.foreground)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
                    .padding(12)
                    .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .accessibilityLabel("Panel schedule text")
                    .accessibilityHint("Paste recognized text from a panel sticker or type circuit rows.")
            }

            ThumbButtonRow {
                PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                    Label(
                        isRecognizing ? "Reading…" : "Read from photo",
                        systemImage: "text.viewfinder"
                    )
                    .frame(minHeight: Theme.touchTarget)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .disabled(isRecognizing)

                if !text.isEmpty {
                    Button {
                        text = ""
                        recognizeError = nil
                        session.reset()
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                            .frame(minHeight: Theme.touchTarget)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await recognize(from: item) }
            }

            if let recognizeError {
                ErrorText(message: recognizeError)
            }

            CalculatorActionBar(
                onCalculate: calculate,
                onReset: {
                    text = ""
                    recognizeError = nil
                    session.reset()
                },
                onExample: {
                    text = """
                    1 LIGHTING OFFICE 20A 1P 2 RECEPTACLES 20A 1P
                    3 AHU-1 40A 2P 4 SPARE 20A 1P
                    """
                    recognizeError = nil
                    session.prepareForNewInputs()
                },
                exampleTitle: "two-up lighting / receptacles"
            )

            if let error = session.lastValidationError ?? session.error {
                ErrorText(message: error.message)
            }

            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ToolEmptyState(
                    title: "Paste a schedule or pick a photo",
                    detail: "Type or paste OCR text, or choose a panel directory photo. Recognition stays on this device.",
                    systemImage: "list.bullet.rectangle"
                )
            } else if session.displayedResult == nil {
                ToolEmptyState(
                    title: "Tap Calculate to parse",
                    detail: "Schedule text is ready. Calculate parses circuit rows without updating on every keystroke.",
                    systemImage: "play.circle"
                )
            } else if circuits.isEmpty {
                ToolEmptyState(
                    title: "No circuits found",
                    detail: "Need a circuit number and a name on each row. Trip and poles are optional. Header lines and panel ratings are skipped.",
                    systemImage: "magnifyingglass"
                )
            } else {
                ResultCard(title: "Circuits", copyText: tsv) {
                    ForEach(Array(circuits.enumerated()), id: \.offset) { _, row in
                        circuitRow(row)
                    }
                }
                .opacity(session.isStale ? 0.72 : 1)
                SaveJobBar(jobName: $jobName, canSave: !session.isStale) {
                    jobs.save(SavedJob(
                        name: jobName,
                        toolID: .panelDirectory,
                        inputs: ["rows": "\(circuits.count)"],
                        outputs: [
                            "circuits": circuits.map(\.circuit).joined(separator: ","),
                            "tsv": tsv,
                        ]
                    ))
                }
            }
        }
        .onChange(of: inputFingerprint) { _, _ in
            session.markInputsChanged()
        }
        .sensoryFeedback(.success, trigger: successTick)
    }

    private func calculate() {
        session.calculate {
            let parsed = PanelDirectory.parse(text)
            guard !parsed.isEmpty else {
                throw CalcError.missing("circuit rows with a number and name")
            }
            return parsed
        }
        if session.displayedResult != nil, !session.isStale, !reduceMotion {
            successTick += 1
        }
    }

    @ViewBuilder
    private func circuitRow(_ row: PanelCircuit) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.circuit)
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(minWidth: 36, alignment: .leading)
                Text(row.name.isEmpty ? "—" : row.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 12) {
                if !row.trip.isEmpty {
                    Text(row.trip)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                }
                if !row.poles.isEmpty {
                    Text("\(row.poles)P")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(.leading, 36)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: row))
    }

    private func accessibilityLabel(for row: PanelCircuit) -> String {
        var parts = ["Circuit \(row.circuit)", row.name]
        if !row.trip.isEmpty { parts.append(row.trip) }
        if !row.poles.isEmpty { parts.append("\(row.poles) pole") }
        return parts.joined(separator: ", ")
    }

    private var sticky: String? {
        guard !circuits.isEmpty else { return nil }
        return "\(circuits.count) circuit\(circuits.count == 1 ? "" : "s")"
    }

    @MainActor
    private func recognize(from item: PhotosPickerItem) async {
        let textBeforeRecognition = text
        isRecognizing = true
        recognizeError = nil
        defer {
            isRecognizing = false
            photoItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                guard text == textBeforeRecognition else { return }
                recognizeError = "Could not read that photo."
                return
            }
            let recognized = try await Self.recognizeText(in: data)
            guard text == textBeforeRecognition else { return }
            let trimmed = recognized.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                recognizeError = "No text found in that photo. Try a sharper, flatter shot of the directory."
                return
            }
            text = trimmed
            session.markInputsChanged()
        } catch {
            guard text == textBeforeRecognition else { return }
            recognizeError = "On-device recognition failed. Paste the text instead."
        }
    }

    /// Vision text recognition on a user-selected image. Nothing leaves the device.
    private static func recognizeText(in imageData: Data) async throws -> String {
        guard let uiImage = UIImage(data: imageData), let cgImage = uiImage.cgImage else {
            throw RecognitionError.unreadableImage
        }
        let orientation = Self.cgImageOrientation(from: uiImage.imageOrientation)

        return try await withCheckedThrowingContinuation { continuation in
            // Built inside the dispatched closure, not captured into it — Vision's
            // request/handler types predate Swift concurrency and aren't Sendable.
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                    let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                    continuation.resume(returning: lines.joined(separator: "\n"))
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
