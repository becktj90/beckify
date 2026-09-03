import SwiftUI

/// Icon-grid home for the toolbox: tools grouped by the job you are doing,
/// each tile carrying original schematic artwork on the site's nebula gradient.
struct ToolGridView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @State private var query = ""
    @State private var path: [ToolID] = []

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 14)]

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
                LazyVGrid(columns: columns, spacing: 18) {
                    if isSearching {
                        section(title: "Results", tools: searchResults)
                    } else {
                        if !favoriteTools.isEmpty {
                            section(title: "Favorites", tools: favoriteTools)
                        }
                        ForEach(ToolCategory.allCases) { category in
                            let tools = ToolboxCatalog.tools(in: category)
                            if !tools.isEmpty {
                                section(title: category.rawValue, tools: tools)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Beckify")
            .searchable(text: $query, prompt: "Ohm, receptacle, 4–20 mA, modbus…")
            .overlay {
                if isSearching && searchResults.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationDestination(for: ToolID.self) { id in
                CalculatorHostView(toolID: id)
            }
        }
        // "Related tools" on a tool screen pushes onto the same stack.
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
                    .font(.caption.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.muted)
                Spacer()
            }
            .padding(.top, 8)
        }
    }
}

/// One grid tile: original glyph over the brand gradient, name underneath.
struct ToolTile: View {
    let tool: ToolDefinition
    var isFavorite: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.iconGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.accent.opacity(0.28), lineWidth: 1)
                    )
                    .overlay(
                        ToolGlyph(kind: GlyphKind.forTool(tool.id), size: 46)
                    )
                    .aspectRatio(1, contentMode: .fit)

                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.accent2)
                        .padding(7)
                }
            }
            .brandGlow(radius: 10, opacity: 0.16)

            Text(tool.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tool.title)
        .accessibilityHint(tool.subtitle)
    }
}
