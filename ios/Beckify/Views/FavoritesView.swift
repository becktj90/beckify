import SwiftUI
import BeckifyMath

/// Pinned tools for one-tap access — like the starred-tools list in EE-toolkit-style apps.
struct FavoritesView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @Environment(\.browseFieldHome) private var browseFieldHome

    private var tools: [ToolDefinition] {
        ToolboxCatalog.tools.filter { favorites.isFavorite($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if tools.isEmpty {
                    ContentUnavailableView {
                        Label("No favorites yet", systemImage: "star")
                    } description: {
                        Text("Star tools you use on the job so they show up here for one-tap access.")
                    } actions: {
                        Button("Browse Field") {
                            browseFieldHome()
                        }
                        .accessibilityIdentifier("browseFieldButton")
                    }
                } else {
                    List {
                        ForEach(tools) { tool in
                            NavigationLink {
                                CalculatorHostView(toolID: tool.id)
                            } label: {
                                FavoriteRowLabel(tool: tool)
                            }
                            .listRowBackground(FavoriteRowBackground(toolID: tool.id))
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                        .onDelete { offsets in
                            for index in offsets { favorites.toggle(tools[index].id) }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Favorites")
            .toolbar {
                if !tools.isEmpty { EditButton() }
            }
            .background {
                ZStack {
                    Theme.ambientBackground.ignoresSafeArea()
                    Circle()
                        .fill(Theme.accent.opacity(0.08))
                        .frame(width: 240, height: 240)
                        .blur(radius: 50)
                        .offset(x: -100, y: -160)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}

private struct FavoriteRowLabel: View {
    let tool: ToolDefinition

    private var area: ToolHomeArea { ToolboxCatalog.area(of: tool.id) }

    var body: some View {
        HStack(spacing: 14) {
            IconWell(toolID: tool.id, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(tool.title)
                        .font(.headline)
                        .foregroundStyle(Theme.foreground)
                    HomeAreaBadge(area: area)
                }
                Text(tool.subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tool.title), \(area.title)")
        .accessibilityHint(tool.subtitle)
        .accessibilityIdentifier("toolRow.\(tool.id.rawValue)")
    }
}

private struct FavoriteRowBackground: View {
    let toolID: ToolID

    private var tint: Color {
        let category = ToolboxCatalog.category(of: toolID)
        return category.map { Theme.categoryColors($0).primary } ?? Theme.accent
    }

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .fill(Theme.glassFill)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .stroke(Theme.glassStroke, lineWidth: Theme.Stroke.hairline)
            )
            .tileLift(tint: tint, radius: 10, opacity: 0.10)
            .padding(.vertical, 3)
    }
}
