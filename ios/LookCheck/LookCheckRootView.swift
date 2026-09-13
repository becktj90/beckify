import PhotosUI
import SwiftUI
import UIKit
import BeckifyMath

/// One-screen Look Check: pick/take photo → Analyze → verdict + surprise roast.
/// Roast tone (mean vs nice) is coined on Analyze and never shown.
/// The photo stays on this device until the user taps Analyze.
struct LookCheckRootView: View {
    @State private var photoItem: PhotosPickerItem?
    @State private var preview: UIImage?
    @State private var showCamera = false
    @State private var cameraUnavailable = false
    @State private var status = "Ready. Taking or choosing a photo does not upload it."
    @State private var progress: Double = 0
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var draft: PhotoLookDraft?
    @State private var successTick = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    privacyNote
                    photoStage
                    captureRow
                    analyzeBar
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(LookTheme.bad)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(LookTheme.bad.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    if let draft {
                        resultBlock(draft)
                    } else if preview == nil {
                        emptyHint(
                            title: "Take or choose a photo",
                            detail: "Then tap Analyze. Entertainment only. Do not use this on photos of children."
                        )
                    } else {
                        emptyHint(
                            title: "Photo is on this device only",
                            detail: "Analyze uploads an upright JPEG. Taking or choosing a photo does not."
                        )
                    }
                }
                .padding(20)
                .padding(.bottom, 28)
            }
            .background(LookTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Look Check")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(LookTheme.foreground)
                }
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await loadLibraryPhoto(item) }
        }
        .sheet(isPresented: $showCamera) {
            LookCheckCameraPicker(image: $preview) {
                showCamera = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: preview) { _, image in
            guard image != nil else { return }
            draft = nil
            errorMessage = nil
            progress = 0
            status = "Photo is on this device only. Analyze uploads it. Taking or choosing a photo does not."
        }
        .sensoryFeedback(.success, trigger: successTick)
        .alert("Camera not available", isPresented: $cameraUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device or Simulator has no camera. Pick a photo from the library instead.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LOOK CHECK")
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(LookTheme.accent)
            Text("Pick a photo. Tap Analyze. Get a verdict and a surprise roast.")
                .font(.title2.weight(.semibold))
                .foregroundStyle(LookTheme.foreground)
            Text("AI comedy. Not medical, dating, or beauty authority.")
                .font(.subheadline)
                .foregroundStyle(LookTheme.muted)
        }
        .accessibilityElement(children: .combine)
    }

    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Photos upload only when you tap Analyze. Anyone who appears under 18 is declined — no roast, no appearance rating.")
                .font(.subheadline)
                .foregroundStyle(LookTheme.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LookTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LookTheme.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var photoStage: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let preview {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 360)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(LookTheme.border, lineWidth: 1)
                    )
                    .accessibilityLabel("Look Check photo preview. Still on this device.")
            } else {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LookTheme.surface)
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "person.crop.rectangle")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundStyle(LookTheme.accent)
                            Text("No photo yet")
                                .font(.headline)
                                .foregroundStyle(LookTheme.foreground)
                            Text("Camera or library. Nothing leaves this phone until Analyze.")
                                .font(.subheadline)
                                .foregroundStyle(LookTheme.muted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(LookTheme.border, lineWidth: 1)
                    )
                    .accessibilityLabel("No Look Check photo yet")
            }
            HStack {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(LookTheme.muted)
                Spacer(minLength: 8)
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(LookTheme.muted)
            }
            ProgressView(value: progress, total: 1)
                .tint(LookTheme.accent)
                .accessibilityLabel("Analyze progress \(Int((progress * 100).rounded())) percent")
        }
    }

    private var captureRow: some View {
        HStack(spacing: 10) {
            Button {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCamera = true
                } else {
                    cameraUnavailable = true
                }
            } label: {
                Label("Camera", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity, minHeight: LookTheme.touchTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(LookTheme.accent)
            .disabled(busy)
            .accessibilityHint("Opens the camera. The photo stays on this device until Analyze.")

            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                Label("Library", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity, minHeight: LookTheme.touchTarget)
            }
            .buttonStyle(.bordered)
            .tint(LookTheme.foreground)
            .disabled(busy)
            .accessibilityHint("Picks one library photo. It stays on this device until Analyze.")
        }
    }

    private var analyzeBar: some View {
        HStack(spacing: 10) {
            Button {
                Task { await analyze() }
            } label: {
                Text(busy ? "Analyzing…" : "Analyze")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: LookTheme.touchTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(LookTheme.accent)
            .disabled(busy || preview == nil)
            .accessibilityIdentifier("lookCheckAnalyzeButton")
            .accessibilityHint("Uploads the photo for a look verdict and roast. Taking or choosing a photo does not upload it.")

            Button(action: reset) {
                Text("Reset")
                    .frame(minWidth: 88, minHeight: LookTheme.touchTarget)
            }
            .buttonStyle(.bordered)
            .tint(LookTheme.muted)
            .disabled(busy)
            .accessibilityIdentifier("lookCheckResetButton")
        }
    }

    @ViewBuilder
    private func resultBlock(_ draft: PhotoLookDraft) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(draft.verdict.badge)
                    .font(.caption.weight(.bold))
                    .tracking(0.6)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(verdictColor(draft.verdict).opacity(0.18), in: Capsule())
                    .foregroundStyle(verdictColor(draft.verdict))
                Spacer()
                if draft.showsScore, let score = draft.score {
                    Text("\(score)")
                        .font(.title.weight(.bold).monospacedDigit())
                        .foregroundStyle(LookTheme.foreground)
                    + Text(" / 100")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LookTheme.muted)
                }
            }

            Text(draft.displayHeadline)
                .font(.title3.weight(.semibold))
                .foregroundStyle(verdictColor(draft.verdict))
            if !draft.summary.isEmpty {
                Text(draft.summary)
                    .font(.subheadline)
                    .foregroundStyle(LookTheme.foreground)
            }

            if draft.verdict == .declined {
                Text("Not rated. Anyone who appears under 18 gets no roast and no appearance score.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(LookTheme.warn)
            }

            if draft.showsRoast {
                LookCheckRoastCard(draft: draft)
            }

            if draft.showsMetrics {
                VStack(alignment: .leading, spacing: 12) {
                    Text("PHOTO METRICS")
                        .font(.caption.weight(.semibold))
                        .tracking(0.6)
                        .foregroundStyle(LookTheme.muted)
                    ForEach(PhotoLookMetrics.metricRows, id: \.key) { row in
                        metricRow(label: row.label, value: draft.metrics.value(forKey: row.key))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LookTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(LookTheme.border, lineWidth: 1)
                )
            }

            noteList(title: "Notes", items: draft.reasons, empty: "No specific notes.")
            noteList(
                title: "Retake tips",
                items: draft.fixes,
                empty: draft.verdict == .declined ? "No retake tips for this photo." : "No retake tips."
            )
            if !draft.warnings.isEmpty {
                noteList(title: "Warnings", items: draft.warnings, empty: "")
            }
        }
    }

    private func metricRow(label: String, value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(LookTheme.muted)
                Spacer()
                Text(value.map(String.init) ?? "—")
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(LookTheme.foreground)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(LookTheme.border)
                    Capsule(style: .continuous)
                        .fill(LookTheme.accent)
                        .frame(width: geo.size.width * CGFloat(value ?? 0) / 100)
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value.map(String.init) ?? "blank")")
    }

    @ViewBuilder
    private func noteList(title: String, items: [String], empty: String) -> some View {
        let rows = items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(LookTheme.muted)
            if rows.isEmpty {
                if !empty.isEmpty {
                    Text(empty)
                        .font(.subheadline)
                        .foregroundStyle(LookTheme.muted)
                }
            } else {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, item in
                    Text("• \(item)")
                        .font(.subheadline)
                        .foregroundStyle(LookTheme.foreground)
                }
            }
        }
        .padding(.top, 4)
    }

    private func emptyHint(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(LookTheme.foreground)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(LookTheme.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LookTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LookTheme.border, lineWidth: 1)
        )
    }

    private func reset() {
        photoItem = nil
        preview = nil
        draft = nil
        errorMessage = nil
        progress = 0
        status = "Ready. Taking or choosing a photo does not upload it."
    }

    private func loadLibraryPhoto(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                if data.count > PhotoLookCheck.maxPickBytes {
                    errorMessage = "Please choose an image smaller than 12 MB."
                    return
                }
                preview = image
                return
            }
            errorMessage = "Please choose a valid image file."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func analyze() async {
        guard let preview, !busy else { return }
        guard let url = PhotoLookCheck.defaultAnalyzeURL() else {
            errorMessage = "Analyze needs https://api.beckify.com/api/analyze-look."
            return
        }
        busy = true
        errorMessage = nil
        draft = nil
        progress = 0.16
        status = "Preparing photo…"
        defer { busy = false }

        guard let prepared = LookCheckVisionClient.prepareUpload(from: preview) else {
            errorMessage = "Could not encode an upright JPEG under 8 MB."
            progress = 0
            status = "Look check failed"
            return
        }
        progress = 0.42
        status = "Sending upright photo…"
        do {
            let result = try await LookCheckVisionClient.analyze(
                dataURL: prepared.dataURL,
                mimeType: prepared.mimeType,
                url: url,
                roastMode: LookRoastMode.randomStandaloneTone()
            )
            progress = 0.92
            status = "Reading the verdict…"
            draft = result
            progress = 1
            status = "Done. Entertainment only — not a beauty contest."
            successTick += 1
        } catch {
            errorMessage = error.localizedDescription
            progress = 0
            status = "Look check failed"
        }
    }

    private func verdictColor(_ verdict: PhotoLookVerdict) -> Color {
        switch verdict {
        case .looksGood: return LookTheme.good
        case .looksBad: return LookTheme.bad
        case .declined, .noPerson, .mixed: return LookTheme.warn
        }
    }
}

struct LookCheckRoastCard: View {
    var draft: PhotoLookDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ROAST")
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(LookTheme.gold)
                Spacer()
                ShareLink(item: draft.shareCardText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                }
                .tint(LookTheme.gold)
                .accessibilityLabel("Share roast card")
            }
            Text(draft.roast)
                .font(.body.weight(.medium))
                .foregroundStyle(LookTheme.foreground)
                .fixedSize(horizontal: false, vertical: true)
            Text("Entertainment only. Comedy roast of this frame — not a beauty score.")
                .font(.caption)
                .foregroundStyle(LookTheme.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LookTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LookTheme.gold.opacity(0.45), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Roast. \(draft.roast)")
    }
}

#Preview {
    LookCheckRootView()
}
