import SwiftUI
import UIKit
import BeckifyMath

private struct OpenRelatedToolKey: EnvironmentKey {
    static let defaultValue: (ToolID) -> Void = { _ in }
}

private struct BrowseFieldHomeKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

private struct ResultProvenanceKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

private struct ResultCopyDisabledKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var openRelatedTool: (ToolID) -> Void {
        get { self[OpenRelatedToolKey.self] }
        set { self[OpenRelatedToolKey.self] = newValue }
    }

    /// Switches to the Toolbox tab and selects Field. Used by Favorites empty state.
    var browseFieldHome: () -> Void {
        get { self[BrowseFieldHomeKey.self] }
        set { self[BrowseFieldHomeKey.self] = newValue }
    }

    var resultProvenance: String? {
        get { self[ResultProvenanceKey.self] }
        set { self[ResultProvenanceKey.self] = newValue }
    }

    var resultCopyDisabled: Bool {
        get { self[ResultCopyDisabledKey.self] }
        set { self[ResultCopyDisabledKey.self] = newValue }
    }
}

enum ToolDisclaimer {
    case designAid
    case designAidExtra(String)
    case sensor(extra: String?)
    case none
}

/// Shared chrome for every calculator and sensor: scroll, 44pt sticky answer, copy, related tools.
struct ToolScaffold<Content: View>: View {
    let toolID: ToolID
    var stickyAnswer: String? = nil
    var copyText: String? = nil
    var disclaimer: ToolDisclaimer = .designAid
    var showsIdentityHeader: Bool = true
    var showsRelatedTools: Bool = true
    /// Play-surface tools (legacy immersive flag): skip scroll chrome, sticky answer, and disclaimer.
    /// Toolbar favorite + How-it-works `i` stay so honesty copy is one tap away.
    var immersivePlay: Bool = false
    var isResultStale: Bool = false
    /// Crew Talk supplies its own single keyboard Done. Other tools keep this one.
    var showsKeyboardToolbar: Bool = true
    @ViewBuilder var content: Content

    @EnvironmentObject private var favorites: FavoritesStore
    @StateObject private var chrome = ToolChromeController()
    /// The info pop-up (how it works, formula, your numbers). Nothing of it takes room in the scroll.
    @State private var showsInfo = false
    @State private var showWork: [ShowWorkPayload] = []
    @AppStorage(ToolboxPreferenceKey.electricalCode) private var codeRaw = ElectricalCode.nec.rawValue
    private var tool: ToolDefinition { ToolboxCatalog.tool(toolID) }
    private var codeNotice: ElectricalCodeNotice? {
        ElectricalCodeSupport.notice(
            toolID: toolID.rawValue,
            code: ElectricalCode(rawValue: codeRaw) ?? .nec
        )
    }

    /// Calculate stays in the sticky strip when the keyboard is down so a
    /// gloved thumb can hit it without scrolling. While editing, it moves to
    /// the keyboard toolbar with Done / Next.
    private var showsStickyCalculate: Bool {
        chrome.hasCalculate && chrome.focusedFieldID == nil
    }

    var body: some View {
        Group {
            if immersivePlay {
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .padding(.horizontal, Theme.Space.md)
                .padding(.top, Theme.Space.xs)
                .padding(.bottom, Theme.Space.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.md) {
                        if showsIdentityHeader {
                            ToolIdentityHeader(toolID: toolID)
                        }
                        if let codeNotice {
                            ElectricalCodeBannerView(notice: codeNotice)
                        }
                        if isResultStale {
                            StaleResultBanner()
                        }
                        content
                        if showsRelatedTools {
                            RelatedToolsSection(current: toolID)
                        }
                        disclaimerView
                    }
                    .padding(Theme.Space.lg)
                    .onPreferenceChange(FormFieldOrderKey.self) { chrome.replaceFieldIDs($0) }
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onPreferenceChange(ShowWorkPreferenceKey.self) { showWork = $0 }
        .sheet(isPresented: $showsInfo) {
            ToolInfoSheet(toolID: toolID, showWork: showWork)
        }
        // Native back history needs a title even when the identity header is visible.
        // Hide the duplicate visually in the principal toolbar item below.
        .navigationTitle(tool.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.background.ignoresSafeArea())
        .supportLegacyBackSwipe()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !immersivePlay {
                stickyChrome
            }
        }
        .toolbar {
            if immersivePlay || showsIdentityHeader {
                ToolbarItem(placement: .principal) {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityHidden(true)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                FavoriteToggleButton(isOn: favorites.isFavorite(toolID), name: tool.title) {
                    favorites.toggle(toolID)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HowItWorksToolbarButton(toolID: toolID) { showsInfo = true }
            }
            if let copyText, !copyText.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    CopyResultButton(text: copyText, compact: true, accessibilityName: "Copy result from toolbar")
                }
            }
            if showsKeyboardToolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Done") { chrome.dismissKeyboard() }
                        .accessibilityIdentifier("keyboardDone")
                    if chrome.hasNextField {
                        Button("Next") { chrome.focusNext() }
                            .accessibilityIdentifier("keyboardNext")
                    }
                    Spacer()
                    if chrome.hasCalculate {
                        Button("Calculate") { chrome.performCalculate() }
                            .fontWeight(.semibold)
                            .disabled(!chrome.calculateEnabled)
                            .accessibilityIdentifier("keyboardCalculate")
                    }
                }
            }
        }
        .environment(\.toolChrome, chrome)
        .environment(\.resultProvenance, codeNotice?.accessibilityLabel)
        .environment(\.resultCopyDisabled, isResultStale)
    }

    @ViewBuilder
    private var stickyChrome: some View {
        VStack(spacing: 0) {
            if showsStickyCalculate {
                StickyCalculateBar(
                    isEnabled: chrome.calculateEnabled,
                    action: { chrome.performCalculate() }
                )
            }
            if let stickyAnswer, !stickyAnswer.isEmpty {
                StickyAnswerBar(answer: stickyAnswer, copyText: copyText, isStale: isResultStale)
            }
        }
    }

    @ViewBuilder
    private var disclaimerView: some View {
        switch disclaimer {
        case .designAid:
            DisclaimerBanner()
        case .designAidExtra(let extra):
            DisclaimerBanner(text: Theme.disclaimer + " " + extra)
        case .sensor(let extra):
            SensorDisclaimer(extra: extra)
        case .none:
            EmptyView()
        }
    }
}

struct StickyAnswerBar: View {
    let answer: String
    var copyText: String? = nil
    var isStale: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("ANSWER")
                        .font(.caption2.weight(.semibold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.muted)
                        .accessibilityHidden(true)
                    if isStale {
                        Text("STALE")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.warn)
                            .accessibilityLabel("Stale result")
                    }
                }
                Text(answer)
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(isStale ? Theme.muted : Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(isStale ? "Stale answer \(answer). Inputs changed — Calculate again." : "Answer \(answer)")
            }
            Spacer(minLength: 8)
            if let copyText, !copyText.isEmpty {
                CopyResultButton(text: copyText, compact: true, accessibilityName: "Copy answer from the bottom bar")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: Theme.touchTarget)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(isStale ? Theme.warn.opacity(0.5) : Theme.border)
                .frame(height: 1)
        }
        .accessibilityIdentifier("stickyAnswerBar")
    }
}

struct CopyResultButton: View {
    let text: String
    var compact: Bool = false
    var accessibilityName: String = "Copy result"
    @State private var copied = false
    @State private var resetTask: Task<Void, Never>?
    @Environment(\.resultProvenance) private var resultProvenance
    @Environment(\.resultCopyDisabled) private var resultCopyDisabled

    private var copyPayload: String {
        guard let resultProvenance, !resultProvenance.isEmpty else { return text }
        return "\(text)\n\n\(resultProvenance)"
    }

    var body: some View {
        Button {
            UIPasteboard.general.string = copyPayload
            copied = true
            resetTask?.cancel()
            resetTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard !Task.isCancelled else { return }
                copied = false
            }
        } label: {
            if compact {
                Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(.subheadline.weight(.semibold))
                    .labelStyle(.iconOnly)
                    .frame(minWidth: Theme.touchTarget, minHeight: Theme.touchTarget)
            } else {
                Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: Theme.touchTarget)
            }
        }
        .buttonStyle(.bordered)
        .tint(Theme.accent)
        .disabled(resultCopyDisabled || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .accessibilityLabel(copied ? "Copied. \(accessibilityName)" : accessibilityName)
        .accessibilityValue(copyPayload)
        .onDisappear {
            resetTask?.cancel()
            copied = false
        }
    }
}

/// Star toggle for pinning a tool to home Pinned / Favorites. Used in tool rows and the tool toolbar.
struct FavoriteToggleButton: View {
    var isOn: Bool
    var name: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isOn ? "star.fill" : "star")
                .font(.body.weight(.semibold))
                .foregroundStyle(isOn ? Theme.accent2 : Theme.muted.opacity(0.7))
                .frame(width: Theme.touchTarget, height: Theme.touchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "Unpin \(name) from home" : "Pin \(name) to home")
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

struct TryExampleButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Try example: \(title)", systemImage: "sparkle")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: Theme.touchTarget, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .tint(Theme.accent)
        .accessibilityLabel("Try an example")
        .accessibilityHint(title)
    }
}

/// Toolbar info button. It opens the pop-up with how the tool works and its math, so neither takes room in the scroll.
struct HowItWorksToolbarButton: View {
    let toolID: ToolID
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: Theme.touchTarget, height: Theme.touchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("How \(ToolboxCatalog.tool(toolID).title) works, and the math")
        .accessibilityHint("Opens a pop-up with the explanation, the formula, and your numbers.")
        .accessibilityIdentifier("howItWorksToolbar.\(toolID.rawValue)")
    }
}

private struct ExplanationSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(Theme.TypeRole.sectionLabel)
            .tracking(0.6)
            .foregroundStyle(Theme.muted)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The formula block a calculator reports for the info pop-up.
struct ShowWorkPayload: Equatable {
    var symbolic: String
    var substituted: String?
    var meaning: String?
    var citation: String?
    var referenceTool: ToolID?
}

struct ShowWorkPreferenceKey: PreferenceKey {
    static var defaultValue: [ShowWorkPayload] = []

    static func reduce(value: inout [ShowWorkPayload], nextValue: () -> [ShowWorkPayload]) {
        value.append(contentsOf: nextValue())
    }
}

/// Used to be an inline, collapsible "Show work" card. It now only reports its formula, your numbers,
/// and the plain-language note to the scaffold, and the info button's pop-up shows them. That keeps
/// every calculator's inputs and results higher on the screen.
struct ShowWorkCard: View {
    let toolID: ToolID
    var symbolic: String
    var substituted: String? = nil
    var meaning: String? = nil
    var citation: String? = nil
    var referenceTool: ToolID? = nil

    var body: some View {
        // Zero size. The negative top padding cancels the stack spacing this child would otherwise add.
        Color.clear
            .frame(width: 0, height: 0)
            .padding(.top, -Theme.Space.md)
            .preference(
                key: ShowWorkPreferenceKey.self,
                value: [ShowWorkPayload(
                    symbolic: symbolic,
                    substituted: substituted,
                    meaning: meaning,
                    citation: citation,
                    referenceTool: referenceTool
                )]
            )
            .accessibilityHidden(true)
    }
}

/// The pop-up behind the toolbar info button: what the tool does, when to use it, its limits,
/// then the formula with the user's numbers.
struct ToolInfoSheet: View {
    let toolID: ToolID
    let showWork: [ShowWorkPayload]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openRelatedTool) private var openRelated

    private var tool: ToolDefinition { ToolboxCatalog.tool(toolID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.md) {
                    HStack(alignment: .top, spacing: Theme.Space.sm) {
                        IconWell(toolID: toolID, size: 44)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L(tool.title))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Theme.foreground)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.isHeader)
                            Text(L(tool.subtitle))
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let copy = tool.howItWorks {
                        section("WHAT IT DOES") {
                            Text(copy.summary)
                                .font(Theme.TypeRole.body)
                                .foregroundStyle(Theme.foreground)
                        }
                        section("WHEN TO USE IT") {
                            Text(copy.context)
                                .font(Theme.TypeRole.help)
                                .foregroundStyle(Theme.muted)
                        }
                        if !copy.bullets.isEmpty {
                            section("DETAILS & LIMITS") {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(Array(copy.bullets.enumerated()), id: \.offset) { _, bullet in
                                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                                            Text("·")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(Theme.accent)
                                                .accessibilityHidden(true)
                                            Text(bullet)
                                                .font(Theme.TypeRole.help)
                                                .foregroundStyle(Theme.muted)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ForEach(Array(showWork.enumerated()), id: \.offset) { _, item in
                        mathBlock(item)
                    }
                }
                .padding(Theme.Space.lg)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("How it works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("toolInfoDone")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("toolInfoSheet.\(toolID.rawValue)")
    }

    private func section<Body: View>(_ title: String, @ViewBuilder _ content: () -> Body) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ExplanationSectionTitle(title: title)
            content()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mathBlock(_ item: ShowWorkPayload) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            section("FORMULA") {
                Text(item.symbolic)
                    .font(.body.monospaced())
                    .foregroundStyle(Theme.accent)
                    .textSelection(.enabled)
            }
            section("WITH YOUR VALUES") {
                if let substituted = item.substituted, !substituted.isEmpty {
                    Text(substituted)
                        .font(.body.monospacedDigit().weight(.medium))
                        .foregroundStyle(Theme.foreground)
                        .textSelection(.enabled)
                        .accessibilityLabel("With your numbers, \(substituted)")
                } else {
                    Text("Enter numbers and calculate to see this formula with your values plugged in.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            if let meaning = item.meaning, !meaning.isEmpty {
                section("IN PLAIN LANGUAGE") {
                    Text(meaning)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
            }
            if let citation = item.citation, !citation.isEmpty {
                section("REFERENCE") {
                    Text(citation)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            if let referenceTool = item.referenceTool {
                let reference = ToolboxCatalog.tool(referenceTool)
                Button {
                    dismiss()
                    DispatchQueue.main.async { openRelated(referenceTool) }
                } label: {
                    Label("Open \(reference.title)", systemImage: reference.symbol)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: Theme.touchTarget, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .accessibilityLabel("Open \(reference.title) for the table this math uses")
            }
        }
        .padding(Theme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Theme.accent.opacity(0.12), Theme.accent2.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.accent.opacity(0.25), lineWidth: 1)
        )
    }
}

/// Deliberately quiet: a single-line strip of compact chips, not a second
/// list of cards competing with the calculator above it. A tool that wants
/// prominence earns it by being in Pinned / Favorites, not by showing up
/// here three times over. Icons use `IconWell` so they follow Dynamic Type.
struct RelatedToolsSection: View {
    let current: ToolID
    @Environment(\.openRelatedTool) private var openRelated

    private var related: [ToolDefinition] {
        ToolboxCatalog.related(to: current)
    }

    var body: some View {
        if !related.isEmpty {
            HStack(alignment: .center, spacing: 8) {
                Text("Also")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted.opacity(0.8))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(related) { tool in
                            Button {
                                openRelated(tool.id)
                            } label: {
                                HStack(spacing: 6) {
                                    IconWell(toolID: tool.id, size: 22, selected: true)
                                    Text(L(tool.title))
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(Theme.muted)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.surfaceRaised.opacity(0.7), in: Capsule())
                                .frame(minHeight: Theme.touchTarget)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open related tool \(tool.title)")
                        }
                    }
                }
            }
            .padding(.top, 2)
            .opacity(0.85)
        }
    }
}

struct MenuField<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [Value]
    var label: (Value) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.muted)
            // A system `.menu` picker lays its label out at a tiny width inside
            // a fixed-height button. Long names ("THHN / THWN-2") then wrap a
            // few letters per line and the glyphs overlap. This label owns the
            // width and grows to two lines instead of crushing the type.
            Menu {
                ForEach(options, id: \.self) { item in
                    Button {
                        selection = item
                    } label: {
                        if item == selection {
                            Label(label(item), systemImage: "checkmark")
                        } else {
                            Text(label(item))
                        }
                    }
                }
            } label: {
                HStack(alignment: .center, spacing: 8) {
                    Text(label(selection))
                        .font(.body)
                        .foregroundStyle(Theme.foreground)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: Theme.touchTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .accessibilityLabel(title)
            .accessibilityValue(label(selection))
        }
    }
}

struct ToolEmptyState: View {
    let title: String
    let detail: String
    var systemImage: String = "exclamationmark.triangle"
    var showsSettings: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(Theme.foreground)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            if showsSettings {
                SettingsLinkButton()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

/// Compact Field / Toolkit chip for search results and saved jobs.
struct HomeAreaBadge: View {
    let area: ToolHomeArea

    private var tint: Color {
        area == .field ? Theme.energized : Theme.good
    }

    var body: some View {
        Text(area.title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.14), in: Capsule(style: .continuous))
            .accessibilityLabel(area.title)
            .accessibilityIdentifier("homeAreaBadge.\(area.rawValue)")
    }
}

struct ThumbButtonRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { content }
            VStack(alignment: .leading, spacing: 10) { content }
        }
    }
}

/// Optional user-initiated cloud Analyze — same chrome as Look Check.
/// Photos stay on device until the button is tapped.
struct CloudVisionAnalyzeChrome: View {
    var title: String
    var defaultPath: String
    var accessibilityID: String
    var busy: Bool
    var enabled: Bool
    var progress: Double
    var status: String
    var endpointFieldID: String
    var tokenFieldID: String
    @Binding var customEndpoint: String
    @Binding var token: String
    var onAnalyze: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup("Optional custom HTTPS endpoint") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Leave blank to use the Beckify API (`https://api.beckify.com\(defaultPath)`). A personal token stays in this session and is sent only to a different HTTPS endpoint you enter — never to api.beckify.com, even if you paste that host. The Beckify proxy may forward the photo to OpenAI and/or Anthropic.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                    TextField("https://your-proxy.example/ocr", text: $customEndpoint)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.body.monospaced())
                        .formFieldFocus(endpointFieldID)
                        .padding(12)
                        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                        .accessibilityLabel("Custom HTTPS Analyze endpoint")
                    SecureField("Bearer token for that endpoint (optional)", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                        .formFieldFocus(tokenFieldID)
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

            HStack(spacing: 10) {
                ProgressView(value: progress, total: 1)
                    .tint(Theme.accent)
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(minWidth: 40, alignment: .trailing)
            }
            .accessibilityLabel("Analyze progress \(Int((progress * 100).rounded())) percent")

            if !status.isEmpty {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }

            Button(action: onAnalyze) {
                Text(busy ? "Analyzing…" : title)
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(busy || !enabled)
            .accessibilityIdentifier(accessibilityID)
            .accessibilityHint("Uploads the photo for a cloud draft. Taking or choosing a photo does not upload it.")
        }
    }

    private var endpointNote: String {
        if BeckifyVisionAPI.httpsBase(customEndpoint) != nil {
            return "Custom HTTPS endpoint will receive the photo when you tap \(title)."
        }
        return "No custom URL yet. \(title) uses https://api.beckify.com\(defaultPath)."
    }
}

extension View {
    func supportLegacyBackSwipe() -> some View {
        modifier(LegacyBackSwipeModifier())
    }
}

/// Some older SwiftUI stacks do not start UIKit's screen-edge recognizer.
/// Complete a qualifying edge drag with the destination's one-page dismiss.
/// Leave an active native pop alone so it cannot remove a second page.
private struct LegacyBackSwipeModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var navigation = BackSwipeNavigationContext()
    @State private var startingDepth: Int?

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content
                .background(BackSwipeNavigationProbe(navigation: navigation).allowsHitTesting(false))
                .simultaneousGesture(
                    DragGesture(minimumDistance: 16)
                        .onChanged { value in
                            if startingDepth == nil, value.startLocation.x >= 0, value.startLocation.x <= 24 {
                                startingDepth = navigation.depth
                            }
                        }
                        .onEnded { value in
                            defer { startingDepth = nil }
                            let distance = value.translation.width
                            guard value.startLocation.x >= 0, value.startLocation.x <= 24,
                                  distance > 30, distance > abs(value.translation.height) * 2,
                                  navigation.width > 0,
                                  max(distance, value.predictedEndTranslation.width) > navigation.width * 0.45,
                                  let startingDepth, navigation.canDismiss(startingAt: startingDepth) else { return }
                            dismiss()
                        }
                )
                .onDisappear { startingDepth = nil }
        }
    }
}

private final class BackSwipeNavigationContext: ObservableObject {
    weak var navigation: UINavigationController?
    weak var carrier: UIView?

    var depth: Int? { navigation?.viewControllers.count }
    var width: CGFloat { navigation?.view.bounds.width ?? 0 }

    func canDismiss(startingAt depth: Int) -> Bool {
        guard let navigation, let carrier,
              navigation.viewControllers.count == depth, depth > 1,
              navigation.transitionCoordinator == nil,
              let top = navigation.topViewController?.viewIfLoaded,
              carrier.isDescendant(of: top) else { return false }
        switch navigation.interactivePopGestureRecognizer?.state {
        case .began, .changed, .ended: return false
        default: return true
        }
    }

    func resolve(in view: UIView) {
        carrier = view
        guard let root = view.window?.rootViewController else { navigation = nil; return }
        navigation = findNavigation(in: root, containing: view)
    }

    private func findNavigation(in controller: UIViewController, containing view: UIView) -> UINavigationController? {
        if let navigation = controller as? UINavigationController,
           let navigationView = navigation.viewIfLoaded,
           view.isDescendant(of: navigationView) {
            return navigation
        }
        for child in controller.children {
            if let navigation = findNavigation(in: child, containing: view) { return navigation }
        }
        return nil
    }
}

private struct BackSwipeNavigationProbe: UIViewRepresentable {
    let navigation: BackSwipeNavigationContext

    func makeUIView(context: Context) -> CarrierView {
        let view = CarrierView()
        view.windowChanged = { [weak view, navigation] in
            DispatchQueue.main.async {
                guard let view else { return }
                navigation.resolve(in: view)
            }
        }
        return view
    }

    func updateUIView(_ view: CarrierView, context: Context) {
        navigation.resolve(in: view)
    }

    static func dismantleUIView(_ view: CarrierView, coordinator: ()) {
        view.windowChanged = nil
    }

    final class CarrierView: UIView {
        var windowChanged: (() -> Void)?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            windowChanged?()
        }
    }
}
