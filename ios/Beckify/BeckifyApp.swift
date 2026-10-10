import SwiftUI
import StoreKit
import BeckifyMath

@main
struct BeckifyApp: App {
    @StateObject private var jobs = JobStore()
    @StateObject private var favorites = FavoritesStore()
    @AppStorage(AppLanguage.storageKey) private var languageRaw = AppLanguage.system.rawValue

    var body: some Scene {
        WindowGroup {
            LaunchSplashContainer {
                RootView()
                    .environmentObject(jobs)
                    .environmentObject(favorites)
                    // Rebuild the tree so String-backed titles (tools, shelves)
                    // pick up the new language immediately.
                    .id(languageRaw)
            }
            .environment(\.locale, (AppLanguage(rawValue: languageRaw) ?? .system).locale)
        }
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
    // Keep history above the launcher whose Recent / Pinned contents can change
    // while a tool is visible. Native back navigation removes one entry at a time.
    @State private var toolboxPath = NavigationPath()
    @State private var didFinishFirstAppear = false
    @ObservedObject private var reviewAsk = ReviewAskStore.shared
    @Environment(\.requestReview) private var requestReview
    @AppStorage(ToolboxPreferenceKey.appearance) private var appearanceRaw = ToolboxAppearance.system.rawValue
    @StateObject private var updateCheck = AppUpdateCheck()
    @Environment(\.openURL) private var openURL

    var body: some View {
        TabView(selection: $tab) {
            ToolGridView(homeArea: $toolboxArea, path: $toolboxPath)
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
        .alert(Text("Update available"), isPresented: Binding(
            get: { updateCheck.availableVersion != nil },
            set: { if !$0 { updateCheck.dismiss() } }
        )) {
            Button("Update") {
                openURL(AppUpdateCheck.storeURL)
                updateCheck.dismiss()
            }
            Button("Later", role: .cancel) {
                updateCheck.dismiss()
            }
        } message: {
            Text("Beckify \(updateCheck.availableVersion ?? "") is on the App Store. You have \(AppUpdateCheck.installedVersion).")
        }
        .task {
            await updateCheck.checkIfDue()
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
    }
}

// MARK: - Launch splash

/// Continues the native UILaunchScreen (LaunchLogo on LaunchBackground) for a
/// brief fade into the root view. No artificial wait: the logo starts fading
/// as soon as the first frame is up. With Reduce Motion it is skipped.
private struct LaunchSplashContainer<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSplash = true

    var body: some View {
        ZStack {
            content
            if showSplash && !reduceMotion {
                ZStack {
                    Color("LaunchBackground").ignoresSafeArea()
                    Image("LaunchLogo")
                        .accessibilityHidden(true)
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        .task {
            guard showSplash else { return }
            if reduceMotion { showSplash = false; return }
            withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
        }
    }
}

// MARK: - Update available prompt

/// Once per day, asks the public iTunes lookup for the App Store version and
/// offers Update / Later when it is newer. Sends no user data; fails silently.
@MainActor
final class AppUpdateCheck: ObservableObject {
    static let appID = "6807908745"
    static let storeURL = URL(string: "itms-apps://apps.apple.com/app/id6807908745")!
    private static let lookupURL = URL(string: "https://itunes.apple.com/lookup?id=6807908745")!
    private static let lastCheckKey = "beckify.updateCheck.lastCheck"

    @Published private(set) var availableVersion: String?

    nonisolated static var installedVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func checkIfDue(now: Date = Date(), defaults: UserDefaults = .standard) async {
        let last = defaults.object(forKey: Self.lastCheckKey) as? Date
        guard AppVersionCheck.shouldCheck(lastCheck: last, now: now) else { return }
        var request = URLRequest(url: Self.lookupURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "GET"
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let store = AppVersionCheck.storeVersion(fromLookup: data)
        else { return }
        defaults.set(now, forKey: Self.lastCheckKey)
        if AppVersionCheck.isStoreNewer(store: store, installed: Self.installedVersion) {
            availableVersion = store
        }
    }

    func dismiss() { availableVersion = nil }
}

// MARK: - App language

/// In-app language override (Settings → Language). System follows iOS.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case spanish = "es"

    static let storageKey = "beckify.appLanguage"
    var id: String { rawValue }

    /// Shown in its own language so it is findable from either one.
    var pickerLabel: LocalizedStringKey {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .spanish: return "Español"
        }
    }

    var locale: Locale {
        switch self {
        case .system: return .autoupdatingCurrent
        case .english: return Locale(identifier: "en")
        case .spanish: return Locale(identifier: "es")
        }
    }

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
    }

    /// Bundle for the effective language; nil means use Bundle.main as-is.
    fileprivate static func bundle() -> Bundle? {
        let code: String
        switch current {
        case .system: return nil
        case .english: code = "en"
        case .spanish: code = "es"
        }
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj") else {
            return code == "en" ? .main : nil
        }
        return Bundle(path: path)
    }
}

/// Localizes a String-backed UI label (tool titles, shelf names) through the
/// String Catalog, honoring the in-app language override.
func L(_ english: String) -> String {
    let bundle = AppLanguage.bundle() ?? .main
    return bundle.localizedString(forKey: english, value: english, table: nil)
}
