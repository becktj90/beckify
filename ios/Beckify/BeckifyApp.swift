import SwiftUI
import BeckifyMath

@main
struct BeckifyApp: App {
    @StateObject private var jobs = JobStore()
    @StateObject private var favorites = FavoritesStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(jobs)
                .environmentObject(favorites)
        }
    }
}

private enum RootTab: Hashable {
    case toolbox
    case favorites
    case jobs
}

struct RootView: View {
    @State private var tab: RootTab = .toolbox
    @State private var toolboxArea: ToolHomeArea = .field

    var body: some View {
        TabView(selection: $tab) {
            ToolGridView(homeArea: $toolboxArea)
                .tabItem {
                    Label("Toolbox", systemImage: "square.grid.2x2.fill")
                }
                .tag(RootTab.toolbox)
            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "star.fill")
                }
                .tag(RootTab.favorites)
            JobsView()
                .tabItem {
                    Label("Jobs", systemImage: "note.text")
                }
                .tag(RootTab.jobs)
        }
        .tint(Theme.accent)
        // Frosted tab chrome — reads as a floating bar over the ambient wash.
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .environment(\.browseFieldHome) {
            toolboxArea = .field
            tab = .toolbox
        }
    }
}
