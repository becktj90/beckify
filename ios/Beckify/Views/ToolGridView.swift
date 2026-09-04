import SwiftUI
import BeckifyMath

/// Premium adaptive tool launcher — Field vs Toolkit, search, favorites,
/// recents, and shelf hierarchy with original schematic icons in soft wells.
struct ToolGridView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @ObservedObject private var recents = RecentToolsStore.shared
    @State private var query = ""
    @State private var homeArea: ToolHomeArea = .field
    @State private var path: [ToolID] = []
    @State private var appeared = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var columns: [GridItem] {
        let minimum: CGFloat = sizeClass == .regular ? 128 : 108
        return [GridItem(.adaptive(minimum: minimum), spacing: 14)]
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

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    if !isSearching {
                        homeHeader
                            .opacity(appeared || reduceMotion ? 1 : 0)
                            .offset(y: appeared || reduceMotion ? 0 : 10)
                        areaPicker
                        if !favoriteTools.isEmpty {
                            avatarStrip(title: "Favorites", tools: favoriteTools)
                                .opacity(appeared || reduceMotion ? 1 : 0)
                                .offset(y: appeared || reduceMotion ? 0 : 8)
                        }
                        if !recents.tools.isEmpty {
                            avatarStrip(title: "Recent", tools: recents.tools)
                                .opacity(appeared || reduceMotion ? 1 : 0)
                                .offset(y: appeared || reduceMotion ? 0 : 8)
                        }
                    }

                    if isSearching {
                        searchResultSections
                    } else {
                        homeShelfSections
                    }
                }
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
            .navigationTitle("Beckify")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: "Search Field and Toolkit…")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        IconGalleryView()
                    } label: {
                        Image(systemName: "square.grid.3x3.fill")
                            .accessibilityLabel("Icon gallery")
                    }
                    .accessibilityIdentifier("iconGalleryButton")
                }
            }
            .overlay {
                if isSearching && searchResults.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationDestination(for: ToolID.self) { id in
                CalculatorHostView(toolID: id)
                    .onAppear { recents.record(id) }
            }
            .onAppear {
                BeckifyMotion.withOptionalAnimation(
                    BeckifyMotion.homeReveal,
                    reduceMotion: reduceMotion
                ) {
                    appeared = true
                }
            }
        }
        .environment(\.openRelatedTool, { id in
            path.append(id)
            recents.record(id)
        })
    }

    // MARK: - Header

    private var areaPicker: some View {
        Picker("Home area", selection: $homeArea) {
            Text(ToolHomeArea.field.title).tag(ToolHomeArea.field)
            Text(ToolHomeArea.toolkit.title).tag(ToolHomeArea.toolkit)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("homeAreaPicker")
    }

    private var homeHeader: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous)
                .fill(Theme.instrumentPanel)
                .overlay {
                    // Concentric instrument rings — depth cue inspired by
                    // premium mobile heroes, drawn in brand teal not purple.
                    ConcentricRings()
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
                }
                .overlay {
                    BlueprintGridBackground(opacity: 0.10)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: Theme.Stroke.hairline)
                )
                .overlay(alignment: .trailing) {
                    IconWell(
                        toolID: homeArea == .field ? .voltageDrop : .ohmsLaw,
                        size: 92,
                        selected: true
                    )
                    .opacity(0.28)
                    .padding(.trailing, 16)
                    .accessibilityHidden(true)
                }
                .brandGlow(radius: 18, opacity: 0.18)

            VStack(alignment: .leading, spacing: 8) {
                Text("BECKIFY")
                    .font(Theme.TypeRole.hud)
                    .tracking(2.4)
                    .foregroundStyle(Color.white.opacity(0.72))
                Text(homeArea.headline)
                    .font(Theme.TypeRole.heroBrand)
                    .foregroundStyle(Color.white)
                Text(homeArea.blurb)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Color.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    headerChip("\(ToolboxCatalog.tools(in: homeArea).count) in \(homeArea.title)")
                    headerChip("\(ToolboxCatalog.tools.count) total")
                }
                .padding(.top, 4)
            }
            .padding(Theme.Space.lg)
        }
        .frame(maxWidth: .infinity, minHeight: 168)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Beckify. \(homeArea.headline). \(homeArea.blurb) \(ToolboxCatalog.tools(in: homeArea).count) tools in \(homeArea.title).")
        .accessibilityIdentifier("homeHeader")
    }

    private func headerChip(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.white.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.14), in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    // MARK: - Strips & sections

    /// Search hits grouped by home area. Split out of `body` so the type checker
    /// does not have to solve the filter + ForEach in one expression.
    @ViewBuilder
    private var searchResultSections: some View {
        ForEach(Array(ToolHomeArea.allCases.enumerated()), id: \.element) { index, area in
            searchAreaBlock(index: index, area: area)
        }
    }

    /// Field / Toolkit shelves for the selected home area.
    @ViewBuilder
    private var homeShelfSections: some View {
        ForEach(Array(ToolShelfKind.shelves(in: homeArea).enumerated()), id: \.element) { index, shelf in
            homeShelfBlock(index: index, shelf: shelf)
        }
    }

    @ViewBuilder
    private func searchAreaBlock(index: Int, area: ToolHomeArea) -> some View {
        let tools = searchResults.filter { ToolboxCatalog.area(of: $0.id) == area }
        if !tools.isEmpty {
            categoryBlock(
                title: area.title,
                tools: tools,
                delay: Double(index) * 0.04,
                showAreaBadge: true
            )
        }
    }

    @ViewBuilder
    private func homeShelfBlock(index: Int, shelf: ToolShelfKind) -> some View {
        let tools = ToolboxCatalog.tools(on: shelf)
        if !tools.isEmpty {
            categoryBlock(
                title: shelf.title,
                tools: tools,
                delay: Double(index) * 0.04
            )
        }
    }

    @ViewBuilder
    private func avatarStrip(title: String, tools: [ToolDefinition]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(title.uppercased())
                .font(Theme.TypeRole.sectionLabel)
                .tracking(1.0)
                .foregroundStyle(Theme.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.md) {
                    ForEach(tools) { tool in
                        NavigationLink(value: tool.id) {
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
                                    .lineLimit(1)
                                    .frame(width: 64)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tool.title)
                        .accessibilityHint(tool.subtitle)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func categoryBlock(
        title: String,
        tools: [ToolDefinition],
        delay: Double,
        showAreaBadge: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack(spacing: 8) {
                Capsule(style: .continuous)
                    .fill(Theme.accent.opacity(0.85))
                    .frame(width: 3, height: 12)
                Text(title.uppercased())
                    .font(Theme.TypeRole.sectionLabel)
                    .tracking(1.0)
                    .foregroundStyle(Theme.muted)
                Spacer(minLength: 0)
                Text("\(tools.count)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.muted.opacity(0.8))
            }
            .padding(.top, 4)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(tools) { tool in
                    NavigationLink(value: tool.id) {
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
        .opacity(appeared || reduceMotion || isSearching ? 1 : 0)
        .offset(y: appeared || reduceMotion || isSearching ? 0 : 12)
        .animation(
            reduceMotion ? nil : BeckifyMotion.homeReveal.delay(delay),
            value: appeared
        )
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
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                IconWell(toolID: tool.id, size: 72)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)

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
                    .fixedSize(horizontal: false, vertical: true)
                if showArea {
                    HomeAreaBadge(area: area)
                }
                Text(tool.subtitle)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
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
