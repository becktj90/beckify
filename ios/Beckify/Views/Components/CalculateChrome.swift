import SwiftUI
import UIKit
import BeckifyMath

// MARK: - Tool chrome coordinator

/// Shared Calculate + keyboard-focus coordinator for `ToolScaffold`.
/// `CalculatorActionBar` publishes Calculate here so the primary action can
/// live in sticky / keyboard chrome instead of mid-scroll.
@MainActor
final class ToolChromeController: ObservableObject {
    @Published var calculateEnabled = true
    @Published private(set) var hasCalculate = false
    @Published var focusedFieldID: String?
    @Published private(set) var fieldIDs: [String] = []

    private var calculateAction: (() -> Void)?
    private var pendingEnabled = true

    /// Stores the latest action without publishing. Call `publishCalculateIfNeeded()`
    /// from `onAppear` / `onChange` so SwiftUI is not mutated during `body`.
    func bindCalculate(enabled: Bool, action: @escaping () -> Void) {
        calculateAction = action
        pendingEnabled = enabled
    }

    func publishCalculateIfNeeded() {
        if calculateEnabled != pendingEnabled {
            calculateEnabled = pendingEnabled
        }
        if !hasCalculate {
            hasCalculate = true
        }
    }

    func clearCalculate() {
        calculateAction = nil
        if hasCalculate {
            hasCalculate = false
        }
        if !calculateEnabled {
            calculateEnabled = true
        }
    }

    func performCalculate() {
        calculateAction?()
        dismissKeyboard()
    }

    /// Replaces the Next-tab order from the view-tree preference, so
    /// conditionally shown fields stay in visual order instead of `onAppear` append order.
    func replaceFieldIDs(_ ids: [String]) {
        var seen = Set<String>()
        let unique = ids.filter { seen.insert($0).inserted }
        guard fieldIDs != unique else { return }
        fieldIDs = unique
        if let focused = focusedFieldID, !unique.contains(focused) {
            focusedFieldID = nil
        }
    }

    var hasNextField: Bool {
        guard let focused = focusedFieldID,
              let index = fieldIDs.firstIndex(of: focused)
        else { return false }
        return index + 1 < fieldIDs.count
    }

    func focusNext() {
        guard let focused = focusedFieldID,
              let index = fieldIDs.firstIndex(of: focused),
              index + 1 < fieldIDs.count
        else {
            dismissKeyboard()
            return
        }
        focusedFieldID = fieldIDs[index + 1]
    }

    func dismissKeyboard() {
        focusedFieldID = nil
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

private struct ToolChromeControllerKey: EnvironmentKey {
    static let defaultValue: ToolChromeController? = nil
}

extension EnvironmentValues {
    var toolChrome: ToolChromeController? {
        get { self[ToolChromeControllerKey.self] }
        set { self[ToolChromeControllerKey.self] = newValue }
    }
}

/// Collects participating field IDs in view-tree order for keyboard Next.
enum FormFieldOrderKey: PreferenceKey {
    static var defaultValue: [String] = []
    static func reduce(value: inout [String], nextValue: () -> [String]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - Calculate interaction chrome

/// Primary Calculate control for explicit tools. Always tappable unless a
/// structural reason disables it — validation runs on press.
struct CalculateButton: View {
    var title: String = "Calculate"
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.accent)
        .disabled(!isEnabled)
        .accessibilityIdentifier("calculateButton")
        .accessibilityLabel(title)
        .accessibilityHint("Validates inputs and updates the result.")
    }
}

/// Sticky Calculate strip so one-thumb / gloves can hit the primary action
/// without scrolling past fields. Does not replace the answer bar.
struct StickyCalculateBar: View {
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        CalculateButton(isEnabled: isEnabled, action: action)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Theme.border)
                    .frame(height: 1)
            }
            .accessibilityIdentifier("stickyCalculateBar")
    }
}

/// Reset / Example stay in the scroll body. Calculate is hoisted into
/// `ToolScaffold` sticky + keyboard chrome via `ToolChromeController`.
struct CalculatorActionBar: View {
    var onCalculate: () -> Void
    var onReset: (() -> Void)? = nil
    var onExample: (() -> Void)? = nil
    var exampleTitle: String? = nil
    var calculateEnabled: Bool = true

    @Environment(\.toolChrome) private var chrome

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            if chrome == nil {
                CalculateButton(isEnabled: calculateEnabled, action: onCalculate)
            }
            if onReset != nil || onExample != nil {
                HStack(spacing: Theme.Space.sm) {
                    if let onReset {
                        Button("Reset", action: onReset)
                            .buttonStyle(.bordered)
                            .tint(Theme.muted)
                            .frame(minHeight: Theme.touchTarget)
                            .accessibilityIdentifier("resetButton")
                    }
                    if let onExample {
                        Button {
                            onExample()
                        } label: {
                            Label(
                                exampleTitle.map { "Example: \($0)" } ?? "Example",
                                systemImage: "sparkle"
                            )
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.accent2)
                        .frame(maxWidth: .infinity, minHeight: Theme.touchTarget, alignment: .leading)
                        .accessibilityIdentifier("exampleButton")
                        .accessibilityLabel("Try an example")
                        .accessibilityHint(exampleTitle ?? "Loads sample inputs")
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .background {
            BindCalculateProbe(enabled: calculateEnabled, action: onCalculate)
        }
    }
}

/// Keeps the hoisted Calculate closure current whenever the action bar
/// is re-evaluated, without publishing on every pass.
private struct BindCalculateProbe: View {
    var enabled: Bool
    var action: () -> Void
    @Environment(\.toolChrome) private var chrome

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear {
                chrome?.bindCalculate(enabled: enabled, action: action)
                chrome?.publishCalculateIfNeeded()
            }
            .onChange(of: enabled) { _, newValue in
                chrome?.bindCalculate(enabled: newValue, action: action)
                chrome?.publishCalculateIfNeeded()
            }
    }
}

// MARK: - Form field keyboard focus

/// Registers a text field with `ToolChromeController` and binds `@FocusState`
/// so the scaffold keyboard toolbar can offer Done / Next.
struct FormFieldFocusModifier: ViewModifier {
    let fieldID: String
    @Environment(\.toolChrome) private var chrome

    func body(content: Content) -> some View {
        if let chrome {
            content.modifier(BoundFormFieldFocusModifier(fieldID: fieldID, chrome: chrome))
        } else {
            content.modifier(LocalKeyboardDoneModifier())
        }
    }
}

/// Observes the scaffold chrome so Next / Done can move `@FocusState`.
private struct BoundFormFieldFocusModifier: ViewModifier {
    let fieldID: String
    @ObservedObject var chrome: ToolChromeController
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .preference(key: FormFieldOrderKey.self, value: [fieldID])
            .onChange(of: isFocused) { _, focused in
                if focused {
                    chrome.focusedFieldID = fieldID
                } else if chrome.focusedFieldID == fieldID {
                    chrome.focusedFieldID = nil
                }
            }
            .onChange(of: chrome.focusedFieldID) { _, newValue in
                isFocused = (newValue == fieldID)
            }
    }
}

/// Fallback Done when a field is used outside `ToolScaffold`.
private struct LocalKeyboardDoneModifier: ViewModifier {
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Done") {
                        isFocused = false
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                    }
                }
            }
    }
}

extension View {
    /// Shared decimal-pad / text-field focus participation for Done / Next.
    func formFieldFocus(_ fieldID: String) -> some View {
        modifier(FormFieldFocusModifier(fieldID: fieldID))
    }
}

struct StaleResultBanner: View {
    var message: String = Theme.staleResultMessage

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.sm) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(Theme.warn)
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.foreground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.warn.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .stroke(Theme.warn.opacity(0.35), lineWidth: Theme.Stroke.hairline)
        )
        .accessibilityIdentifier("staleResultBanner")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

struct ToolIdentityHeader: View {
    let toolID: ToolID
    var purpose: String? = nil

    private var tool: ToolDefinition { ToolboxCatalog.tool(toolID) }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.sm) {
            IconWell(toolID: toolID, size: 56)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(tool.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .accessibilityAddTraits(.isHeader)
                Text(purpose ?? tool.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if tool.calculationMode == .explicit {
                    Text("Calculate to update results")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.accent2)
                } else if tool.calculationMode == .live {
                    Text("Updates as you type")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tool.title). \(purpose ?? tool.subtitle)\(modeHint.map { ". \($0)" } ?? "")")
    }

    private var modeHint: String? {
        switch tool.calculationMode {
        case .explicit: return "Calculate to update results"
        case .live: return "Updates as you type"
        default: return nil
        }
    }
}

struct DiagramCard<Content: View>: View {
    var title: String
    var accessibilitySummary: String
    /// Optional file-friendly name used when sharing (without extension).
    var exportName: String = "beckify-plot"
    @ViewBuilder var content: Content

    @State private var sharePayload: SharePayload?
    @State private var exportFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title.uppercased())
                    .font(Theme.TypeRole.sectionLabel)
                    .tracking(0.8)
                    .foregroundStyle(Theme.muted)
                Spacer(minLength: 8)
                Button {
                    exportAndShare()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .accessibilityLabel("Share or save plot image")
                .accessibilityHint("Opens the system share sheet so you can save or send a PNG of this plot.")
                .accessibilityIdentifier("diagramShareButton")
            }

            content
                .frame(maxWidth: .infinity)
                .frame(minHeight: 160)
                .padding(Theme.Space.sm)
                .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .stroke(Theme.border, lineWidth: Theme.Stroke.hairline)
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
        }
        .sheet(item: $sharePayload) { payload in
            ActivityShareSheet(items: payload.items)
        }
        .alert("Couldn’t export plot", isPresented: $exportFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The plot image couldn’t be rendered. Try again after the chart finishes drawing.")
        }
    }

    @MainActor
    private func exportAndShare() {
        let exportView = DiagramExportCanvas(
            title: title,
            summary: accessibilitySummary,
            content: { content }
        )
        .frame(width: 720)
        .padding(20)
        .background(Theme.background)

        let renderer = ImageRenderer(content: exportView)
        renderer.scale = 3
        guard let image = renderer.uiImage else {
            exportFailed = true
            return
        }
        let fileName = "\(sanitize(exportName)).png"
        if let data = image.pngData() {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            do {
                try data.write(to: url, options: .atomic)
                sharePayload = SharePayload(items: [url, accessibilitySummary])
            } catch {
                // Temp write failed — share the in-memory UIImage instead of a missing file URL.
                sharePayload = SharePayload(items: [image, accessibilitySummary])
            }
        } else {
            sharePayload = SharePayload(items: [image, accessibilitySummary])
        }
    }

    private func sanitize(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = trimmed.replacingOccurrences(of: "[^A-Za-z0-9._-]+", with: "-", options: .regularExpression)
        return safe.isEmpty ? "beckify-plot" : safe
    }
}

/// Renders the diagram with a print-friendly header for PNG export.
private struct DiagramExportCanvas<Content: View>: View {
    let title: String
    let summary: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("BECKIFY")
                    .font(.caption.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.accent)
                Spacer()
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
            }
            content
                .frame(maxWidth: .infinity)
                .frame(minHeight: 280)
                .padding(12)
                .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(summary)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text("Design aid only — not a PE stamp or calibrated instrument.")
                .font(.caption2)
                .foregroundStyle(Theme.muted.opacity(0.8))
        }
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

/// System share sheet — Save Image, Messages, Files, AirDrop, etc.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct FieldValidationText: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(Theme.bad)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("fieldValidation")
    }
}

/// Blueprint grid used sparingly in atmospheric headers / empty states.
struct BlueprintGridBackground: View {
    var opacity: Double = 0.12

    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 24
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            context.stroke(
                path,
                with: .color(Color.white.opacity(opacity)),
                lineWidth: 0.5
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
