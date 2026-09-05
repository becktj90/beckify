import SwiftUI
import UIKit
import BeckifyMath

private struct OpenRelatedToolKey: EnvironmentKey {
    static let defaultValue: (ToolID) -> Void = { _ in }
}

private struct BrowseFieldHomeKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
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
    var isResultStale: Bool = false
    @ViewBuilder var content: Content

    @EnvironmentObject private var favorites: FavoritesStore
    @StateObject private var chrome = ToolChromeController()
    private var tool: ToolDefinition { ToolboxCatalog.tool(toolID) }

    /// Calculate stays in the sticky strip when the keyboard is down so a
    /// gloved thumb can hit it without scrolling. While editing, it moves to
    /// the keyboard toolbar with Done / Next.
    private var showsStickyCalculate: Bool {
        chrome.hasCalculate && chrome.focusedFieldID == nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                if showsIdentityHeader {
                    ToolIdentityHeader(toolID: toolID)
                }
                AboutToolCard(toolID: toolID)
                if isResultStale {
                    StaleResultBanner()
                }
                content
                RelatedToolsSection(current: toolID)
                disclaimerView
            }
            .padding(Theme.Space.lg)
            .onPreferenceChange(FormFieldOrderKey.self) { chrome.replaceFieldIDs($0) }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(tool.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            stickyChrome
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
                .font(.body.weight(.semibold))
                .frame(minHeight: Theme.touchTarget)
                .accessibilityLabel("Done")
                .accessibilityHint("Dismisses the keyboard so you can Calculate or copy.")
            }
            ToolbarItem(placement: .topBarTrailing) {
                FavoriteToggleButton(isOn: favorites.isFavorite(toolID), name: tool.title) {
                    favorites.toggle(toolID)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HowItWorksToolbarButton(toolID: toolID)
            }
            if let copyText, !copyText.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    CopyResultButton(text: copyText, compact: true, accessibilityName: "Copy result from toolbar")
                }
            }
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
        .environment(\.toolChrome, chrome)
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

    var body: some View {
        Button {
            UIPasteboard.general.string = text
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
        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .accessibilityLabel(copied ? "Copied. \(accessibilityName)" : accessibilityName)
        .accessibilityValue(text)
        .onDisappear {
            resetTask?.cancel()
            copied = false
        }
    }
}

/// Star toggle for pinning a tool to the Favorites tab. Used in tool rows and the tool toolbar.
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
        .accessibilityLabel(isOn ? "Remove \(name) from favorites" : "Add \(name) to favorites")
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

/// Shared AppStorage key so the toolbar About control and `AboutToolCard` stay in sync.
enum HowItWorksExpansion {
    static func storageKey(for id: ToolID) -> String {
        "com.beckify.toolbox.howItWorks.\(id.rawValue)"
    }

    static func defaultExpanded(for id: ToolID) -> Bool {
        ToolboxCatalog.tool(id).kind == .homework
    }
}

/// Compact toolbar affordance. Field stays inputs-first; this opens the same disclosure.
struct HowItWorksToolbarButton: View {
    let toolID: ToolID
    @AppStorage private var expanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(toolID: ToolID) {
        self.toolID = toolID
        _expanded = AppStorage(
            wrappedValue: HowItWorksExpansion.defaultExpanded(for: toolID),
            HowItWorksExpansion.storageKey(for: toolID)
        )
    }

    var body: some View {
        Button {
            BeckifyMotion.withOptionalAnimation(BeckifyMotion.staleReveal, reduceMotion: reduceMotion) {
                expanded.toggle()
            }
        } label: {
            Image(systemName: expanded ? "info.circle.fill" : "info.circle")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: Theme.touchTarget, height: Theme.touchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(expanded ? "Hide how \(ToolboxCatalog.tool(toolID).title) works" : "How \(ToolboxCatalog.tool(toolID).title) works")
        .accessibilityHint("Shows a short how-it-works note. Inputs stay first.")
        .accessibilityIdentifier("howItWorksToolbar.\(toolID.rawValue)")
        .accessibilityAddTraits(expanded ? [.isSelected] : [])
    }
}

/// Collapsed-by-default Field About card. Homework tools start open, matching Show Work.
struct AboutToolCard: View {
    let toolID: ToolID
    @AppStorage private var expanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(toolID: ToolID) {
        self.toolID = toolID
        _expanded = AppStorage(
            wrappedValue: HowItWorksExpansion.defaultExpanded(for: toolID),
            HowItWorksExpansion.storageKey(for: toolID)
        )
    }

    var body: some View {
        if let copy = ToolboxCatalog.tool(toolID).howItWorks {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Button {
                    BeckifyMotion.withOptionalAnimation(BeckifyMotion.staleReveal, reduceMotion: reduceMotion) {
                        expanded.toggle()
                    }
                } label: {
                    HStack {
                        Text("HOW IT WORKS")
                            .font(Theme.TypeRole.sectionLabel)
                            .tracking(0.8)
                            .foregroundStyle(Theme.muted)
                        Spacer()
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(minHeight: Theme.touchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("How it works")
                .accessibilityValue(expanded ? "Expanded" : "Collapsed")
                .accessibilityHint("Short note on what this tool computes and its limits.")
                .accessibilityIdentifier("howItWorksToggle.\(toolID.rawValue)")

                if expanded {
                    Text(copy.summary)
                        .font(Theme.TypeRole.body)
                        .foregroundStyle(Theme.foreground)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(copy.context)
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    if !copy.bullets.isEmpty {
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
                        .padding(.top, 2)
                    }
                }
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.bottom, expanded ? Theme.Space.md : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .instrumentPanel(corner: Theme.Radius.card)
            .accessibilityIdentifier("howItWorksCard.\(toolID.rawValue)")
            .accessibilityElement(children: .contain)
        }
    }
}

/// Formula with the user’s numbers substituted. Expanded for homework, collapsed for field.
struct ShowWorkCard: View {
    let toolID: ToolID
    var symbolic: String
    var substituted: String? = nil
    var meaning: String? = nil
    var citation: String? = nil
    var referenceTool: ToolID? = nil

    @AppStorage private var expanded: Bool
    @State private var meaningOpen = false
    @Environment(\.openRelatedTool) private var openRelated
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        toolID: ToolID,
        symbolic: String,
        substituted: String? = nil,
        meaning: String? = nil,
        citation: String? = nil,
        referenceTool: ToolID? = nil
    ) {
        self.toolID = toolID
        self.symbolic = symbolic
        self.substituted = substituted
        self.meaning = meaning
        self.citation = citation
        self.referenceTool = referenceTool
        let homework = ToolboxCatalog.tool(toolID).kind == .homework
        _expanded = AppStorage(
            wrappedValue: homework,
            "com.beckify.toolbox.showWork.\(toolID.rawValue)"
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                if reduceMotion {
                    expanded.toggle()
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                }
            } label: {
                HStack {
                    Text("SHOW WORK")
                        .font(.caption.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
                .frame(minHeight: Theme.touchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show work")
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")
            .accessibilityHint("Shows the formula with your numbers filled in.")

            if expanded {
                Text(symbolic)
                    .font(.body.monospaced())
                    .foregroundStyle(Theme.accent)
                    .textSelection(.enabled)

                if let substituted, !substituted.isEmpty {
                    Text(substituted)
                        .font(.body.monospacedDigit().weight(.medium))
                        .foregroundStyle(Theme.foreground)
                        .textSelection(.enabled)
                        .accessibilityLabel("With your numbers, \(substituted)")
                } else {
                    Text("Enter numbers to see this formula with your values plugged in.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }

                if let citation, !citation.isEmpty {
                    Text(citation)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }

                if let referenceTool {
                    let tool = ToolboxCatalog.tool(referenceTool)
                    Button {
                        openRelated(referenceTool)
                    } label: {
                        Label("Open \(tool.title)", systemImage: tool.symbol)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: Theme.touchTarget, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                    .accessibilityLabel("Open \(tool.title) for the table this math uses")
                }

                if let meaning, !meaning.isEmpty {
                    DisclosureGroup("What this number means", isExpanded: $meaningOpen) {
                        Text(meaning)
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .padding(.top, 6)
                    }
                    .tint(Theme.accent)
                    .font(.subheadline.weight(.semibold))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, expanded ? 16 : 0)
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
        .brandGlow()
    }
}

/// Deliberately quiet: a single-line strip of compact chips, not a second
/// list of cards competing with the calculator above it. A tool that wants
/// prominence earns it by being in Favorites or Quick Tools, not by showing up
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
                                    Text(tool.title)
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
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { item in
                    Text(label(item)).tag(item)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, minHeight: Theme.touchTarget, alignment: .leading)
            .padding(.horizontal, 14)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .accessibilityLabel(title)
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
