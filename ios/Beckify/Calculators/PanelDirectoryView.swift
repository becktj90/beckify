import PhotosUI
import SwiftUI
import UIKit
import Vision
import BeckifyMath

/// Paste or OCR a panel schedule / directory sticker into circuit rows.
struct PanelDirectoryView: View {
    @EnvironmentObject private var jobs: JobStore
    @StoredInput(.panelDirectory, "text", default: "") private var text
    @StoredInput(.panelDirectory, "jobName", default: "Panel directory") private var jobName

    @State private var photoItem: PhotosPickerItem?
    @State private var isRecognizing = false
    @State private var recognizeError: String?

    private var circuits: [PanelCircuit] {
        PanelDirectory.parse(text)
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
            disclaimer: .designAidExtra("OCR and parsing stay on this device. Recognition noise can invent or drop circuits — verify against the sticker.")
        ) {
            ShowWorkCard(
                toolID: .panelDirectory,
                symbolic: "circuit · name · [trip] · [poles]",
                substituted: circuits.isEmpty
                    ? nil
                    : "\(circuits.count) circuit\(circuits.count == 1 ? "" : "s") parsed",
                meaning: "Directory stickers often stop after the name. Trip and poles are optional. Two-up schedules put odds and evens on one line — the parser splits them."
            )

            TryExampleButton(title: "two-up lighting / receptacles") {
                text = """
                1 LIGHTING OFFICE 20A 1P 2 RECEPTACLES 20A 1P
                3 AHU-1 40A 2P 4 SPARE 20A 1P
                """
                recognizeError = nil
            }

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

            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ToolEmptyState(
                    title: "Paste a schedule or pick a photo",
                    detail: "Type or paste OCR text, or choose a panel directory photo. Recognition stays on this device.",
                    systemImage: "list.bullet.rectangle"
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
                SaveJobBar(jobName: $jobName, canSave: true) {
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
        isRecognizing = true
        recognizeError = nil
        defer {
            isRecognizing = false
            photoItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                recognizeError = "Could not read that photo."
                return
            }
            let recognized = try await Self.recognizeText(in: data)
            let trimmed = recognized.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                recognizeError = "No text found in that photo. Try a sharper, flatter shot of the directory."
                return
            }
            text = trimmed
        } catch {
            recognizeError = "On-device recognition failed. Paste the text instead."
        }
    }

    /// Vision text recognition on a user-selected image. Nothing leaves the device.
    private static func recognizeText(in imageData: Data) async throws -> String {
        guard let image = UIImage(data: imageData)?.cgImage else {
            throw CalcError.missing("a readable image")
        }

        return try await withCheckedThrowingContinuation { continuation in
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

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
