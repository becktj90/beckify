import SwiftUI

/// Premium adaptive tool launcher — identity, search, favorites, recents,
/// and category hierarchy with original schematic icons.
struct ToolGridView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @ObservedObject private var recents = RecentToolsStore.shared
    @State private var query = ""
    @State private var path: [ToolID] = []
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] {
        let minimum: CGFloat = sizeClass == .regular ? 120 : 104
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
                        if !favoriteTools.isEmpty {
                            horizontalStrip(title: "Favorites", tools: favoriteTools)
                        }
                        if !recents.tools.isEmpty {
                            horizontalStrip(title: "Recent", tools: recents.tools)
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 18) {
                        if isSearching {
                            section(title: "Results", category: nil, tools: searchResults)
                        } else {
                            ForEach(ToolCategory.allCases) { category in
                                let tools = ToolboxCatalog.tools(in: category)
                                if !tools.isEmpty {
                                    section(title: category.rawValue, category: category, tools: tools)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .padding(.top, 8)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Beckify")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: "Ohm, receptacle, 4–20 mA, modbus…")
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
        }
        .environment(\.openRelatedTool, { id in
            path.append(id)
            recents.record(id)
        })
    }

    private var homeHeader: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous)
                .fill(Theme.instrumentPanel)
                .overlay {
                    BlueprintGridBackground(opacity: 0.14)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
                }
                .overlay(alignment: .trailing) {
                    IconWell(toolID: .ohmsLaw, size: 96, selected: true)
                        .opacity(0.28)
                        .padding(.trailing, 18)
                        .accessibilityHidden(true)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text("BECKIFY")
                    .font(.caption.weight(.bold))
                    .tracking(2.4)
                    .foregroundStyle(Color.white.opacity(0.72))
                Text("Field EE Toolbox")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.white)
                Text("Calculators and sensors for the job site and the bench.")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.Space.md)
        }
        .frame(maxWidth: .infinity, minHeight: 132)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Beckify. Field EE Toolbox.")
        .accessibilityIdentifier("homeHeader")
    }

    @ViewBuilder
    private func horizontalStrip(title: String, tools: [ToolDefinition]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(title.uppercased())
                .font(Theme.TypeRole.sectionLabel)
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.sm) {
                    ForEach(tools) { tool in
                        NavigationLink(value: tool.id) {
                            compactTile(tool)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func compactTile(_ tool: ToolDefinition) -> some View {
        HStack(spacing: 10) {
            IconWell(toolID: tool.id, size: 32, glyphSize: 20, selected: true)
            Text(tool.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: Theme.touchTarget)
        .background(Theme.surface, in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(Theme.border, lineWidth: 1))
        .accessibilityLabel(tool.title)
        .accessibilityHint(tool.subtitle)
    }

    @ViewBuilder
    private func section(title: String, category: ToolCategory?, tools: [ToolDefinition]) -> some View {
        Section {
            ForEach(tools) { tool in
                NavigationLink(value: tool.id) {
                    ToolTile(tool: tool, isFavorite: favorites.isFavorite(tool.id))
                }
                .buttonStyle(.plain)
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
            HStack(spacing: Theme.Space.xs) {
                if let category {
                    CategoryWell(category: category, size: 22)
                }
                Text(title.uppercased())
                    .font(Theme.TypeRole.sectionLabel)
                    .tracking(0.8)
                    .foregroundStyle(Theme.muted)
                Spacer()
            }
            .padding(.top, 8)
        }
    }
}

/// One grid tile: IconWell glyph, title, and compact subtitle.
struct ToolTile: View {
    let tool: ToolDefinition
    var isFavorite: Bool

    private var category: ToolCategory? { ToolboxCatalog.category(of: tool.id) }
    private var borderTint: Color {
        category.map { Theme.categoryColors($0).primary } ?? Theme.accent
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        GeometryReader { geo in
                            IconWell(toolID: tool.id, size: geo.size.width, selected: true)
                        }
                    }
                    .shadow(color: borderTint.opacity(0.18), radius: 8, x: 0, y: 4)

                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.energized)
                        .padding(7)
                        .accessibilityHidden(true)
                }
            }

            VStack(spacing: 2) {
                Text(tool.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(tool.subtitle)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tool.title)
        .accessibilityHint(tool.subtitle)
        .accessibilityIdentifier("toolTile.\(tool.id.rawValue)")
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
