import SwiftUI
import StoreKit
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
    @State private var didFinishFirstAppear = false
    @ObservedObject private var reviewAsk = ReviewAskStore.shared
    @Environment(\.requestReview) private var requestReview

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
        .onAppear {
            reviewAsk.recordSession()
            // Never request on first-launch onAppear (HIG + App Review 5.6.3).
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                didFinishFirstAppear = true
            }
        }
        .onChange(of: tab) { _, newTab in
            guard didFinishFirstAppear, newTab == .toolbox else { return }
            reviewAsk.presentIfEligible(requestReview, currentVersion: ReviewAskStore.marketingVersion)
        }
    }
}
