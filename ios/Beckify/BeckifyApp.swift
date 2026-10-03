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


extension Notification.Name {
    /// Full app received the Voltage Drop permalink. Opens that tool only.
    static let beckifyOpenVoltageDrop = Notification.Name("beckify.openVoltageDrop")
}

enum VoltageDropInvocation {
    private static let pendingKey = "beckify.pendingVoltageDrop"

    /// Existing toolbox permalink (`#sec-vdrop` is a fragment; the path is the match).
    static func matches(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        guard host == "beckify.com" || host == "www.beckify.com" else { return false }
        var path = url.path
        if path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return path.lowercased() == "/toolbox/voltage-drop"
    }

    /// Survives the gap before Toolbox home is on screen.
    static func requestOpen() {
        UserDefaults.standard.set(true, forKey: pendingKey)
        NotificationCenter.default.post(name: .beckifyOpenVoltageDrop, object: nil)
    }

    static func consumePending() -> Bool {
        guard UserDefaults.standard.bool(forKey: pendingKey) else { return false }
        UserDefaults.standard.set(false, forKey: pendingKey)
        return true
    }
}

private enum RootTab: Hashable {
    case toolbox
    case favorites
    case jobs
}

struct RootView: View {
    @EnvironmentObject private var jobs: JobStore
    @State private var tab: RootTab = .toolbox
    @State private var toolboxArea: ToolHomeArea = .field
    @State private var didFinishFirstAppear = false
    @ObservedObject private var reviewAsk = ReviewAskStore.shared
    @Environment(\.requestReview) private var requestReview
    @AppStorage(ToolboxPreferenceKey.appearance) private var appearanceRaw = ToolboxAppearance.system.rawValue

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
        .preferredColorScheme((ToolboxAppearance(rawValue: appearanceRaw) ?? .system).colorScheme)
        // Frosted tab chrome — reads as a floating bar over the ambient wash.
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .alert("Could not save note", isPresented: Binding(
            get: { jobs.saveError != nil },
            set: { if !$0 { jobs.clearSaveError() } }
        )) {
            Button("OK", role: .cancel) {
                jobs.clearSaveError()
            }
        } message: {
            Text(jobs.saveError ?? "")
        }
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
            reviewAsk.presentIfEligible({ requestReview() }, currentVersion: ReviewAskStore.marketingVersion)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL, VoltageDropInvocation.matches(url) else { return }
            tab = .toolbox
            VoltageDropInvocation.requestOpen()
        }
    }
}
