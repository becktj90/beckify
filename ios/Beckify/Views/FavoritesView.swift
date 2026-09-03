import SwiftUI

/// Pinned tools for one-tap access — like the starred-tools list in EE-toolkit-style apps.
struct FavoritesView: View {
    @EnvironmentObject private var favorites: FavoritesStore

    private var tools: [ToolDefinition] {
        ToolboxCatalog.tools.filter { favorites.isFavorite($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if tools.isEmpty {
                    ContentUnavailableView(
                        "No favorites yet",
                        systemImage: "star",
                        description: Text("Tap the star on any calculator or sensor to pin it here for one-tap access.")
                    )
                } else {
                    List {
                        ForEach(tools) { tool in
                            NavigationLink {
                                CalculatorHostView(toolID: tool.id)
                            } label: {
                                ToolRow(tool: tool)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { favorites.toggle(tools[index].id) }
                        }
                    }
                }
            }
            .navigationTitle("Favorites")
            .toolbar {
                if !tools.isEmpty { EditButton() }
            }
            .background(Theme.background)
        }
    }
}
