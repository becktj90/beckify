import SwiftUI

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

struct RootView: View {
    var body: some View {
        TabView {
            ToolGridView()
                .tabItem { Label("Toolbox", systemImage: "square.grid.2x2.fill") }
            FavoritesView()
                .tabItem { Label("Favorites", systemImage: "star.fill") }
            JobsView()
                .tabItem { Label("Jobs", systemImage: "note.text") }
        }
        .tint(Theme.accent)
    }
}
