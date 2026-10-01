import SwiftUI
import StoreKit
import BeckifyMath

/// Navigation destinations from Toolbox home. Shelves and tools share one stack
/// so related-tool deep links and the review-ask-on-return path stay intact.
private enum ToolboxHomeRoute: Hashable {
    case shelf(ToolShelfKind)
    case tool(ToolID)
}

/// Premium adaptive tool launcher — Field vs Toolkit, search, favorites,
/// recents, and shelf hierarchy with original schematic icons in soft wells.
///
/// Home shows short shelf cards (not every tile). Opening a shelf pushes a
/// dedicated grid screen. That keeps scroll identity stable when favoriting,
/// returning from a tool, toggling Field/Toolkit, or dismissing search — the
/// long LazyVGrid no longer lives on the root scroll view.
struct ToolGridView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @ObservedObject private var reviewAsk = ReviewAskStore.shared
    @ObservedObject private var recents = RecentToolsStore.shared
    @Binding var homeArea: ToolHomeArea
    @State private var query = ""
    @State private var path: [ToolboxHomeRoute] = []
    @State private var appeared = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview

    init(homeArea: Binding<ToolHomeArea> = .constant(.field)) {
        _homeArea = homeArea
    }

    /// Wide enough that two-line titles like "Conductor Cost Optimizer"
    /// fit on iPhone without a mid-word ellipsis. Compact phones land on
    /// two columns; iPad still uses an adaptive grid.
    private var columns: [GridItem] {
        ToolShelfGridLayout.columns(sizeClass: sizeClass)
    }

    private var searchResults: [ToolDefinition] {
        ToolboxCatalog.matching(query)
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var favoriteTools: [ToolDefinition] {
        ToolboxCatalog.tools.filter { favorites.isFavorite($0.id) }
    }

    /// Pinned one-tap jobsite tools on Field home. Policy owns the ID list.
    private var fieldQuickTools: [ToolDefinition] {
        ToolHomeAreaPolicy.fieldQuickIDs.compactMap { raw in
            ToolboxCatalog.tools.first { $0.id.rawValue == raw }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    if !isSearching {
                        homeHeader
                            .opacity(appeared || reduceMotion ? 1 : 0)
                            .offset(y: appeared || reduceMotion ? 0 : 10)
                        if !favoriteTools.isEmpty {
                            avatarStrip(title: "Favorites", tools: favoriteTools)
                        }
                        // Cold start: hide Recents entirely. Do not seed fake
                        // tools or leave an empty strip for App Store shots.
                        if !recents.tools.isEmpty {
                            avatarStrip(title: "Recent", tools: Array(recents.tools.prefix(5)))
                        }
                        if homeArea == .field {
                            avatarStrip(
                                title: "Quick",
                                tools: fieldQuickTools,
                                accessibilityNamePrefix: "Quick"
                            )
                            .accessibilityIdentifier("fieldQuickStrip")
                        }
                        homeShelfCards
                    } else {
                        searchResultSections
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
                .padding(.top, 10)
                // Favorites / Recents membership changes must not animate the
                // root layout — that was the main "menu hop" when starring or
                // returning from a tool that updates Recents.
                .animation(nil, value: favorites.ids)
                .animation(nil, value: recents.recentIDs)
                .animation(nil, value: homeArea)
                .animation(nil, value: isSearching)
            }
            .scrollDismissesKeyboard(.immediately)
            .background {
                ZStack {
                    Theme.ambientBackground.ignoresSafeArea()
                    AmbientGlowOrbs()
                }
            }
            .navigationTitle("Beckify")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: "Search Field and Toolkit…")
            .safeAreaInset(edge: .top, spacing: 0) {
                if !isSearching && path.isEmpty {
                    stickyAreaPicker
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SettingsToolbarButton()
                }
            }
            .overlay {
                if isSearching && searchResults.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationDestination(for: ToolboxHomeRoute.self) { route in
                switch route {
                case .shelf(let shelf):
                    ToolShelfScreen(shelf: shelf, columns: columns)
                case .tool(let id):
                    CalculatorHostView(toolID: id)
                        .onAppear { recents.record(id) }
                }
            }
            .onChange(of: path) { oldPath, newPath in
                // End of a tool / shelf sequence — user is back on home.
                // Never ask from a Save tap or from first-launch onAppear.
                if !oldPath.isEmpty && newPath.isEmpty {
                    reviewAsk.presentIfEligible(
                        { requestReview() },
                        currentVersion: ReviewAskStore.marketingVersion
                    )
                }
            }
            .onChange(of: homeArea) { _, _ in
                // Area switch replaces shelf cards only; keep scroll calm.
                query = ""
            }
            .onAppear {
                guard !appeared else { return }
                BeckifyMotion.withOptionalAnimation(
                    BeckifyMotion.homeReveal,
                    reduceMotion: reduceMotion
                ) {
                    appeared = true
                }
            }
        }
        .environment(\.openRelatedTool, { id in
            path.append(.tool(id))
            recents.record(id)
        })
    }

    // MARK: - Sticky chrome

    private var stickyAreaPicker: some View {
        Picker("Home area", selection: $homeArea) {
            Text(ToolHomeArea.field.title).tag(ToolHomeArea.field)
            Text(ToolHomeArea.toolkit.title).tag(ToolHomeArea.toolkit)
        }
        .segmentedControlStyle()
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .accessibilityIdentifier("homeAreaPicker")
    }

    // MARK: - Header

    private var homeHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Beckify")
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Color.white.opacity(0.62))
                Text(homeArea.headline)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.white)
                Text(homeArea.blurb)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            IconWell(
                toolID: homeArea == .field ? .voltageDrop : .ohmsLaw,
                size: 44,
                selected: true
            )
            .opacity(0.35)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, Theme.Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.instrumentPanel)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: Theme.Stroke.hairline)
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Beckify. \(homeArea.headline). \(homeArea.blurb)")
        .accessibilityIdentifier("homeHeader")
    }

    // MARK: - Strips & sections

    /// Search hits grouped by home area. Split out of `body` so the type checker
    /// does not have to solve the filter + ForEach in one expression.
    @ViewBuilder
    private var searchResultSections: some View {
        ForEach(ToolHomeArea.allCases, id: \.self) { area in
            searchAreaBlock(area: area)
        }
    }

    /// One card per shelf in the selected home area — opens a dedicated grid.
    @ViewBuilder
    private var homeShelfCards: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            HStack(spacing: 8) {
                Capsule(style: .continuous)
                    .fill(Theme.accent.opacity(0.85))
                    .frame(width: 3, height: 12)
                Text("SHELVES")
                    .font(Theme.TypeRole.sectionLabel)
                    .tracking(1.0)
                    .foregroundStyle(Theme.muted)
            }
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: Theme.Space.md) {
                ForEach(ToolShelfKind.shelves(in: homeArea), id: \.self) { shelf in
                    let tools = ToolboxCatalog.tools(on: shelf)
                    if !tools.isEmpty {
                        NavigationLink(value: ToolboxHomeRoute.shelf(shelf)) {
                            ShelfCard(shelf: shelf, previewTools: Array(tools.prefix(4)))
                        }
                        .buttonStyle(ToolTileButtonStyle())
                        .accessibilityIdentifier("shelfCard.\(shelf.rawValue)")
                    }
                }
            }
        }
        .opacity(appeared || reduceMotion ? 1 : 0)
        .offset(y: appeared || reduceMotion ? 0 : 12)
    }

    @ViewBuilder
    private func searchAreaBlock(area: ToolHomeArea) -> some View {
        let tools = searchResults.filter { ToolboxCatalog.area(of: $0.id) == area }
        if !tools.isEmpty {
            ToolCategoryGrid(
                title: area.title,
                tools: tools,
                columns: columns,
                showAreaBadge: true
            )
        }
    }

    @ViewBuilder
    private func avatarStrip(
        title: String,
        tools: [ToolDefinition],
        accessibilityNamePrefix: String? = nil
    ) -> some View {
        let strip = VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(title.uppercased())
                .font(Theme.TypeRole.sectionLabel)
                .tracking(1.0)
                .foregroundStyle(Theme.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.md) {
                    ForEach(tools) { tool in
                        avatarStripLink(
                            tool: tool,
                            accessibilityNamePrefix: accessibilityNamePrefix
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
        if accessibilityNamePrefix != nil {
            strip
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Quick access")
        } else {
            strip
        }
    }

    @ViewBuilder
    private func avatarStripLink(
        tool: ToolDefinition,
        accessibilityNamePrefix: String?
    ) -> some View {
        let link = NavigationLink(value: ToolboxHomeRoute.tool(tool.id)) {
            VStack(spacing: 6) {
                IconWell(toolID: tool.id, size: 52, circular: true)
                    .tileLift(
                        tint: Theme.categoryColors(
                            ToolboxCatalog.category(of: tool.id) ?? .power
                        ).primary,
                        radius: 10,
                        opacity: 0.2
                    )
                Text(tool.title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.foreground)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(width: 80)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            accessibilityNamePrefix.map { "\($0), \(tool.title)" } ?? tool.title
        )
        .accessibilityHint(tool.subtitle)
        if accessibilityNamePrefix != nil {
            link.accessibilityIdentifier("quickTool.\(tool.id.rawValue)")
        } else {
            link
        }
    }
}

// MARK: - Shelf screen

/// Dedicated grid for one shelf. Keeps home scroll short and identity-stable.
struct ToolShelfScreen: View {
    let shelf: ToolShelfKind
    let columns: [GridItem]

    private var tools: [ToolDefinition] {
        ToolboxCatalog.tools(on: shelf)
    }

    var body: some View {
        ScrollView {
            ToolCategoryGrid(
                title: shelf.title,
                tools: tools,
                columns: columns,
                showAreaBadge: false,
                showsSectionChrome: false
            )
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
            .padding(.top, 10)
        }
        .background {
            ZStack {
                Theme.ambientBackground.ignoresSafeArea()
                AmbientGlowOrbs()
            }
        }
        .navigationTitle(shelf.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Shared grid

enum ToolShelfGridLayout {
    static func columns(sizeClass: UserInterfaceSizeClass?) -> [GridItem] {
        // Denser tiles so more icons show on home shelf screens.
        let minimum: CGFloat = sizeClass == .regular ? 128 : 118
        return [GridItem(.adaptive(minimum: minimum), spacing: 10)]
    }

    /// Fixed tile height so LazyVGrid rows do not reflow as cells appear.
    static let tileHeight: CGFloat = 148
}

/// Section chrome + LazyVGrid of tool tiles. Used by search results and shelf screens.
struct ToolCategoryGrid: View {
    let title: String
    let tools: [ToolDefinition]
    let columns: [GridItem]
    var showAreaBadge: Bool = false
    var showsSectionChrome: Bool = true
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            if showsSectionChrome {
                HStack(spacing: 8) {
                    Capsule(style: .continuous)
                        .fill(Theme.accent.opacity(0.85))
                        .frame(width: 3, height: 12)
                    Text(title.uppercased())
                        .font(Theme.TypeRole.sectionLabel)
                        .tracking(1.0)
                        .foregroundStyle(Theme.muted)
                }
                .padding(.top, 4)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(tools) { tool in
                    NavigationLink(value: ToolboxHomeRoute.tool(tool.id)) {
                        ToolTile(
                            tool: tool,
                            isFavorite: favorites.isFavorite(tool.id),
                            showArea: showAreaBadge
                        )
                    }
                    .buttonStyle(ToolTileButtonStyle())
                    .contextMenu {
                        Button {
                            favorites.toggle(tool.id)
                        } label: {
                            Label(
                                favorites.isFavorite(tool.id) ? "Remove from Favorites" : "Add to Favorites",
                                systemImage: favorites.isFavorite(tool.id) ? "star.slash" : "star"
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Shelf card

/// Four 40pt preview wells in a light fan. Spacing of -6 is 15% overlap.
/// The slot is that fan's natural width (142pt) so a short frame cannot
/// squeeze the wells tighter than the spacing says.
private enum ShelfPreviewFan {
    static let well: CGFloat = 40
    static let spacing: CGFloat = -6
    static let count = 4

    static var slotWidth: CGFloat {
        let n = CGFloat(count)
        return well * n + spacing * (n - 1)
    }
}

/// Compact home entry for one shelf — preview wells, no tool-count capsule.
private struct ShelfCard: View {
    let shelf: ToolShelfKind
    let previewTools: [ToolDefinition]

    private var borderTint: Color {
        Theme.categoryColors(shelf.category).primary
    }

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: ShelfPreviewFan.spacing) {
                ForEach(previewTools) { tool in
                    IconWell(toolID: tool.id, size: ShelfPreviewFan.well, circular: true)
                        .overlay {
                            Circle()
                                .stroke(Theme.surface.opacity(0.95), lineWidth: 2)
                        }
                }
                if previewTools.isEmpty {
                    IconWell(toolID: .ohmsLaw, size: ShelfPreviewFan.well, circular: true)
                        .opacity(0.35)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: ShelfPreviewFan.slotWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(shelf.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(shelfHomeHint)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .glassCard(corner: Theme.Radius.tile, tint: borderTint)
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(shelf.title)
        .accessibilityHint(shelfHomeHint)
        .accessibilityAddTraits(.isButton)
    }

    private var shelfHomeHint: String {
        switch shelf {
        case .jobsite: return "Voltage drop, fill, motors, receptacles…"
        case .power: return "kVA, transformers, solar, UPS…"
        case .controls: return "Loops, panels, phasors, Modbus…"
        case .magnetics: return "Cores, flux, and EM fields."
        case .analysis: return "Distributions and Monte Carlo."
        case .instruments: return "RF, mic, motion…"
        case .basics: return "Ohm's Law, divider, RC, units…"
        case .bench: return "Lab, RF, e-bike, analog…"
        case .reference: return "Tables, schedules, Spanish…"
        }
    }
}

// MARK: - Tile

/// One grid tile: soft icon well on glass, title, and compact subtitle.
struct ToolTile: View {
    let tool: ToolDefinition
    var isFavorite: Bool
    var showArea: Bool = false

    private var category: ToolCategory? { ToolboxCatalog.category(of: tool.id) }
    private var area: ToolHomeArea { ToolboxCatalog.area(of: tool.id) }
    private var borderTint: Color {
        category.map { Theme.categoryColors($0).primary } ?? Theme.accent
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                IconWell(toolID: tool.id, size: 56)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)

                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.energized)
                        .padding(8)
                        .accessibilityHidden(true)
                }
            }

            VStack(spacing: 3) {
                Text(tool.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)
                if showArea {
                    HomeAreaBadge(area: area)
                }
                Text(tool.subtitle)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
            .padding(.bottom, 4)

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .frame(height: ToolShelfGridLayout.tileHeight, alignment: .top)
        .glassCard(corner: Theme.Radius.tile, tint: borderTint)
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(showArea ? "\(tool.title), \(area.title)" : tool.title)
        .accessibilityHint(tool.subtitle)
        .accessibilityIdentifier("toolTile.\(tool.id.rawValue)")
    }
}

/// Press feedback without spring noise. Honors Reduce Motion.
private struct ToolTileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : BeckifyMotion.tilePress, value: configuration.isPressed)
    }
}

/// Soft atmospheric orbs behind the grid — teal/copper brand, not purple glow.
private struct AmbientGlowOrbs: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: -120, y: -180)
            Circle()
                .fill(Theme.energized.opacity(0.07))
                .frame(width: 220, height: 220)
                .blur(radius: 50)
                .offset(x: 140, y: 320)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Concentric rings for the hero panel — instrument / radar language.
private struct ConcentricRings: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width * 0.78, y: size.height * 0.42)
            for i in 1...4 {
                let radius = CGFloat(i) * min(size.width, size.height) * 0.14
                let rect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(Color.white.opacity(0.10 - Double(i) * 0.015)),
                    lineWidth: 1
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("Home — light") {
    ToolGridView()
        .environmentObject(FavoritesStore())
}

#Preview("Home — dark") {
    ToolGridView()
        .environmentObject(FavoritesStore())
        .preferredColorScheme(.dark)
}

#Preview("Home — large type") {
    ToolGridView()
        .environmentObject(FavoritesStore())
        .environment(\.sizeCategory, .accessibilityExtraExtraLarge)
}
