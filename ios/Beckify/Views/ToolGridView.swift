import SwiftUI

/// Premium adaptive toolbox launcher — Beckify identity, search, favorites,
/// recents, and categorized custom-icon tiles.
struct ToolGridView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var recents: RecentsStore
    @State private var query = ""
    @State private var path: [ToolID] = []
    @State private var showIconGallery = false

    private let columns = [GridItem(.adaptive(minimum: 108), spacing: 14)]

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
                    HomeHeroHeader(onShowIcons: { showIconGallery = true })

                    LazyVGrid(columns: columns, spacing: 18) {
                        if isSearching {
                            section(title: "Results", tools: searchResults)
                        } else {
                            if !favoriteTools.isEmpty {
                                section(title: "Favorites", tools: favoriteTools)
                            }
                            if !recents.tools.isEmpty {
                                section(title: "Recent", tools: recents.tools)
                            }
                            ForEach(ToolCategory.allCases) { category in
                                let tools = ToolboxCatalog.tools(in: category)
                                if !tools.isEmpty {
                                    section(title: category.rawValue, tools: tools)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.md)
                .padding(.bottom, Theme.Space.xl)
            }
            .instrumentPanelBackground()
            .navigationTitle("Beckify")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Ohm, receptacle, 4–20 mA, panel…")
            .overlay {
                if isSearching && searchResults.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationDestination(for: ToolID.self) { id in
                CalculatorHostView(toolID: id)
            }
            .navigationDestination(isPresented: $showIconGallery) {
                IconGalleryView()
            }
        }
        .environment(\.openRelatedTool, { id in
            path.append(id)
        })
    }

    @ViewBuilder
    private func section(title: String, tools: [ToolDefinition]) -> some View {
        Section {
            ForEach(tools) { tool in
                NavigationLink(value: tool.id) {
                    ToolTile(tool: tool, isFavorite: favorites.isFavorite(tool.id))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("toolTile.\(tool.id.rawValue)")
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
        } header: {
            HStack {
                Text(title.uppercased())
                    .font(Theme.TypeRole.label)
                    .tracking(0.8)
                    .foregroundStyle(Theme.muted)
                Spacer()
            }
            .padding(.top, Theme.Space.xs)
        }
    }
}

struct HomeHeroHeader: View {
    var onShowIcons: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BECKIFY")
                        .font(.caption.weight(.bold))
                        .tracking(2.0)
                        .foregroundStyle(Theme.accent2)
                    Text("Field EE instrument")
                        .font(Theme.TypeRole.title)
                        .foregroundStyle(Theme.foreground)
                    Text("Calculators and sensors for the jobsite and the lab. Design aid — not a PE stamp.")
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Theme.Space.sm)
                Button(action: onShowIcons) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.body.weight(.semibold))
                        .frame(width: Theme.touchTarget, height: Theme.touchTarget)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .accessibilityLabel("Icon gallery")
                .accessibilityIdentifier("iconGalleryButton")
            }
        }
        .padding(Theme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous)
                .fill(Theme.panelGradient)
                .overlay {
                    BlueprintGrid(spacing: 18)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
                        .opacity(0.35)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous)
                        .stroke(Theme.accent.opacity(0.35), lineWidth: Theme.Stroke.hairline)
                )
        }
        .environment(\.colorScheme, .dark)
    }
}

struct ToolTile: View {
    let tool: ToolDefinition
    var isFavorite: Bool

    var body: some View {
        VStack(spacing: Theme.Space.xs) {
            ZStack(alignment: .topTrailing) {
                ToolGlyphBadge(kind: GlyphKind.forTool(tool.id), size: 88)
                    .brandGlow(radius: 10, opacity: 0.14)

                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.copper)
                        .padding(7)
                        .accessibilityHidden(true)
                }
            }

            Text(tool.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)

            Text(tool.calculationMode == .live ? "Live" : "Calculate")
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.muted)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tool.title)
        .accessibilityHint(tool.subtitle)
        .accessibilityValue(tool.calculationMode == .live ? "Live calculation" : "Requires calculate")
    }
}
