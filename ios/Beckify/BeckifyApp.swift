import SwiftUI

@main
struct BeckifyApp: App {
    @StateObject private var jobs = JobStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(jobs)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            ToolboxView()
                .tabItem { Label("Toolbox", systemImage: "wrench.and.screwdriver.fill") }
            JobsView()
                .tabItem { Label("Jobs", systemImage: "note.text") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle.fill") }
        }
        .tint(Theme.accent)
    }
}
