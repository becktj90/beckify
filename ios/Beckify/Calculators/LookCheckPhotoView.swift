import PhotosUI
import SwiftUI
import UIKit
import BeckifyMath

/// Catalog Look Check — website photo verdict. Distinct from the Wi-Fi /
/// Cellular **Online / Captive** hotspot-detect card (`LookCheckCard`).
/// The photo stays on this device until the user taps Analyze Look.
struct LookCheckPhotoView: View {
    @StoredInput(.lookCheck, "endpoint", default: "") private var customEndpoint

    @State private var photoItem: PhotosPickerItem?
    @State private var preview: UIImage?
    @State private var showCamera = false
    @State private var cameraUnavailable = false
    @State private var token = ""
    @State private var status = "Ready for a camera photo or a file. Taking or choosing a photo does not upload it."
    @State private var progress: Double = 0
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var draft: PhotoLookDraft?
    @State private var successTick = 0

    var body: some View {
        ToolScaffold(
            toolID: .lookCheck,
            stickyAnswer: sticky,
            copyText: draft?.copyLine,
            disclaimer: .designAidExtra(PhotoLookCheck.disclaimer),
            isResultStale: false
        ) {
            ShowWorkCard(
                toolID: .lookCheck,
                symbolic: "photo (on device) → Analyze Look → /api/analyze-look → verdict + metrics",
                substituted: substituted,
                meaning: "Taking or choosing a photo does not upload it. Analyze Look sends an upright JPEG to the Beckify HTTPS look API (or your custom endpoint). Entertainment only — not medical, dating, or beauty authority.",
                citation: "Same JSON contract as the website Look Check: POST { imageBase64, mimeType, task: \"look\" }."
            )

            privacyNote
            photoBlock
            captureButtons
            endpointBlock
            progressBlock

            if let errorMessage {
                ErrorText(message: errorMessage)
            }

            analyzeBar

            if let draft {
                verdictCard(draft)
            } else if preview == nil {
                ToolEmptyState(
                    title: "Take or choose a photo",
                    detail: "The image stays on this device until you tap Analyze Look. Entertainment only — not medical or dating advice. Do not use this on photos of children.",
                    systemImage: "person.crop.rectangle"
                )
            } else {
                ToolEmptyState(
                    title: "Photo is on this device only",
                    detail: "Analyze Look uploads an upright copy. Taking or choosing a photo does not.",
                    systemImage: "arrow.up.circle"
                )
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await loadLibraryPhoto(item) }
        }
        .sheet(isPresented: $showCamera) {
            CameraImagePicker(image: $preview) {
                showCamera = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: preview) { _, image in
            guard image != nil else { return }
            draft = nil
            errorMessage = nil
            progress = 0
            status = "Photo is on this device only. Analyze Look uploads it. Taking or choosing a photo does not."
        }
        .sensoryFeedback(.success, trigger: successTick)
        .alert("Camera not available", isPresented: $cameraUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device or Simulator has no camera. Pick a photo from the library instead.")
        }
    }

    // MARK: - Blocks

    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Privacy: this tool is cloud-only. Taking or choosing a photo does not upload it. The image leaves this device only when you tap Analyze Look. Anyone who appears under 18 is not rated.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            Text("Entertainment only. Photo notes plus a roast — not medical, dating, or beauty authority. Do not use this on photos of children.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var photoBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LOOK CHECK PHOTO")
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.muted)
            if let preview {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .accessibilityLabel("Look Check photo preview. Still on this device.")
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.surfaceRaised)
                    .frame(maxWidth: .infinity, minHeight: 140)
                    .overlay {
                        Text("No image loaded yet.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .accessibilityLabel("No Look Check photo yet")
            }
            Text(status)
                .font(.caption)
                .foregroundStyle(Theme.muted)
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
            .disabled(busy)
            .accessibilityHint("Opens the camera. The photo stays on this device until Analyze Look.")

            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                Label("Choose photo", systemImage: "photo.on.rectangle")
                    .frame(minHeight: Theme.touchTarget)
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .disabled(busy)
            .accessibilityHint("Picks one library photo. It stays on this device until Analyze Look.")
        }
    }

    private var endpointBlock: some View {
        DisclosureGroup("Optional custom HTTPS endpoint") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Leave blank to use the Beckify API (`https://api.beckify.com/api/analyze-look`). A personal token stays in this session and is never sent to Beckify unless you set it on your own endpoint. The Beckify proxy may forward the photo to OpenAI and/or Anthropic.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                TextField("https://your-proxy.example/ocr", text: $customEndpoint)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .font(.body.monospaced())
                    .formFieldFocus("lookEndpoint")
                    .padding(12)
                    .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .accessibilityLabel("Custom HTTPS Analyze Look endpoint")
                SecureField("Bearer token for that endpoint (optional)", text: $token)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())
                    .formFieldFocus("lookToken")
                    .padding(12)
                    .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .accessibilityLabel("Optional bearer token for the custom endpoint")
                Text(endpointNote)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            .padding(.top, 8)
        }
        .font(.subheadline.weight(.semibold))
    }

    private var progressBlock: some View {
        HStack(spacing: 10) {
            ProgressView(value: progress, total: 1)
                .tint(Theme.accent)
            Text("\(Int((progress * 100).rounded()))%")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.muted)
                .frame(minWidth: 40, alignment: .trailing)
        }
        .accessibilityLabel("Analyze Look progress \(Int((progress * 100).rounded())) percent")
    }

    private var analyzeBar: some View {
        ThumbButtonRow {
            Button {
                Task { await analyze() }
            } label: {
                Text(busy ? "Analyzing…" : "Analyze Look")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(busy || preview == nil)
            .accessibilityIdentifier("analyzeLookButton")
            .accessibilityHint("Uploads the photo for a look verdict. Taking or choosing a photo does not upload it.")

            Button(action: reset) {
                Text("Reset")
                    .frame(minHeight: Theme.touchTarget)
            }
            .buttonStyle(.bordered)
            .tint(Theme.muted)
            .disabled(busy)
            .accessibilityIdentifier("resetButton")
        }
    }

    @ViewBuilder
    private func verdictCard(_ draft: PhotoLookDraft) -> some View {
        ResultCard(title: draft.verdict.badge, copyText: draft.copyLine) {
            Text(draft.displayHeadline)
                .font(.title3.weight(.semibold))
                .foregroundStyle(verdictTone(draft.verdict))
            if !draft.summary.isEmpty {
                Text(draft.summary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.foreground)
                    .padding(.top, 4)
            }
            if draft.showsRoast {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Roast")
                        .font(.caption.weight(.semibold))
                        .tracking(0.5)
                        .foregroundStyle(Theme.warn)
                    Text(draft.roast)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.foreground)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.warn.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.warn.opacity(0.35), lineWidth: 1)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Roast. \(draft.roast)")
            }
            if draft.showsScore, let score = draft.score {
                ResultRow(label: "Score", value: "\(score)", emphasis: true, tone: verdictTone(draft.verdict))
            }

            if draft.showsMetrics {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(PhotoLookMetrics.metricRows, id: \.key) { row in
                        metricRow(label: row.label, value: draft.metrics.value(forKey: row.key))
                    }
                }
                .padding(.top, 8)
            }

            noteList(title: "Notes", items: draft.reasons, empty: "No specific notes.")
            noteList(
                title: "Retake tips",
                items: draft.fixes,
                empty: draft.verdict == .declined ? "No retake tips for this photo." : "No retake tips."
            )
            noteList(title: "Photo notes", items: draft.photoNotes, empty: "No photo notes.")
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
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text(value.map(String.init) ?? "—")
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.foreground)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Theme.border.opacity(0.45))
                    Capsule(style: .continuous)
                        .fill(Theme.accent)
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
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(Theme.muted)
                .padding(.top, 8)
            if rows.isEmpty {
                if !empty.isEmpty {
                    Text(empty)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
            } else {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, item in
                    Text("• \(item)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.foreground)
                }
            }
        }
    }

    // MARK: - Actions

    private func reset() {
        photoItem = nil
        preview = nil
        draft = nil
        errorMessage = nil
        progress = 0
        status = "Ready for a camera photo or a file. Taking or choosing a photo does not upload it."
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
        guard let url = PhotoLookCheck.analyzeURL(customEndpoint: customEndpoint) else {
            errorMessage = "Analyze Look needs an HTTPS endpoint. Leave the custom URL blank to use api.beckify.com, or enter a https:// URL."
            return
        }
        busy = true
        errorMessage = nil
        draft = nil
        progress = 0.16
        status = "Preparing photo…"
        defer { busy = false }

        guard let prepared = PhotoLookCheckClient.prepareUpload(from: preview) else {
            errorMessage = "Could not encode an upright JPEG under 8 MB."
            progress = 0
            status = "Look check failed"
            return
        }
        progress = 0.42
        status = "Sending upright photo for a look check…"
        do {
            let result = try await PhotoLookCheckClient.analyze(
                dataURL: prepared.dataURL,
                mimeType: prepared.mimeType,
                url: url,
                token: PhotoLookCheck.authorizationToken(customEndpoint: customEndpoint, token: token)
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

    private var endpointNote: String {
        if PhotoLookCheck.httpsBase(customEndpoint) != nil {
            return "Custom HTTPS endpoint will receive the photo when you tap Analyze Look."
        }
        return "No custom URL yet. Analyze Look uses https://api.beckify.com/api/analyze-look."
    }

    private var sticky: String? {
        guard let draft else { return nil }
        if draft.showsScore, let score = draft.score {
            return "\(draft.verdict.badge) · \(score)"
        }
        return draft.verdict.badge
    }

    private var substituted: String? {
        guard let draft else { return nil }
        return draft.copyLine
    }

    private func verdictTone(_ verdict: PhotoLookVerdict) -> Color {
        switch verdict {
        case .looksGood: return Theme.good
        case .looksBad: return Theme.bad
        case .declined, .noPerson, .mixed: return Theme.warn
        }
    }
}

/// URLSession client for `/api/analyze-look`. Encoding happens only here.
enum PhotoLookCheckClient {
    struct PreparedUpload: Equatable {
        var dataURL: String
        var mimeType: String
        var byteCount: Int
    }

    static func prepareUpload(from image: UIImage) -> PreparedUpload? {
        guard let jpeg = uprightJPEG(from: image) else { return nil }
        let dataURL = PhotoLookCheck.dataURL(jpegBase64: jpeg.base64EncodedString())
        return PreparedUpload(dataURL: dataURL, mimeType: "image/jpeg", byteCount: jpeg.count)
    }

    static func analyze(
        dataURL: String,
        mimeType: String,
        url: URL,
        token: String
    ) async throws -> PhotoLookDraft {
        let body = try PhotoLookCheck.requestJSON(imageBase64: dataURL, mimeType: mimeType)
        do {
            return try await post(url: url, body: body, token: token)
        } catch let error as PhotoLookHTTPError where error.status == 502 || error.status == 504 {
            try await Task.sleep(nanoseconds: 800_000_000)
            return try await post(url: url, body: body, token: token)
        }
    }

    private static func post(url: URL, body: Data, token: String) async throws -> PhotoLookDraft {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if status < 200 || status >= 300 {
            let retry = retryAfter(http: http, payload: payload)
            let message = PhotoLookCheck.formatVisionError(
                status: status,
                message: payload["error"] as? String,
                retryAfter: retry,
                endpoint: url.absoluteString
            )
            throw PhotoLookHTTPError(status: status, message: message)
        }
        return PhotoLookCheck.normalizeDraft(payload)
    }

    private static func retryAfter(http: HTTPURLResponse?, payload: [String: Any]) -> Int {
        if let header = http?.value(forHTTPHeaderField: "Retry-After"), let n = Int(header), n > 0 {
            return n
        }
        if let n = payload["retryAfter"] as? Int, n > 0 { return n }
        if let n = payload["retry_after"] as? Int, n > 0 { return n }
        return 0
    }

    private static func uprightJPEG(from image: UIImage) -> Data? {
        let rendered = uprightImage(image)
        let scaled = scaleToMaxEdge(rendered, edge: PhotoLookCheck.maxUploadEdge)
        for quality in [0.82, 0.7, 0.55, 0.4] as [CGFloat] {
            guard let data = scaled.jpegData(compressionQuality: quality) else { continue }
            if data.count <= PhotoLookCheck.maxUploadBytes { return data }
        }
        return scaled.jpegData(compressionQuality: 0.32).flatMap { data in
            data.count <= PhotoLookCheck.maxUploadBytes ? data : nil
        }
    }

    private static func uprightImage(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func scaleToMaxEdge(_ image: UIImage, edge: Int) -> UIImage {
        let maxSide = max(image.size.width, image.size.height)
        guard maxSide > CGFloat(edge), maxSide > 0 else { return image }
        let scale = CGFloat(edge) / maxSide
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

struct PhotoLookHTTPError: LocalizedError {
    var status: Int
    var message: String
    var errorDescription: String? { message }
}
