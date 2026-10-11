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

/// Continues the native UILaunchScreen (LaunchLogo on LaunchBackground) with a
/// short branded beat: a faint Penrose (P3) tiling fades in behind the logo while
/// one or two damped ripples spread out from the center like a rock dropped in a
/// pond, then the whole splash cross-fades into home. The root view is built
/// underneath in parallel, so nothing waits on the splash. Tap to skip.
/// Reduce Motion: static tiling, no ripples, short hold.
private struct LaunchSplashContainer<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSplash = !ProcessInfo.processInfo.arguments.contains("-skipLaunchSplash")

    /// Timing (seconds). Total ≈ hold + fade = 2.3 s (1.6 s with Reduce Motion).
    static var hold: Double { 2.0 }
    static var fade: Double { 0.3 }
    static var reducedHold: Double { 1.4 }
    static var reducedFade: Double { 0.2 }

    var body: some View {
        ZStack {
            content
            if showSplash {
                LaunchSplashView(animated: !reduceMotion)
                    .transition(.opacity)
                    .contentShape(Rectangle())
                    .onTapGesture { dismiss(fade: 0.2) }
                    .accessibilityElement()
                    .accessibilityLabel("Beckify")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Skips the intro")
                    .zIndex(1)
            }
        }
        .task {
            guard showSplash else { return }
            let hold = reduceMotion ? Self.reducedHold : Self.hold
            try? await Task.sleep(for: .seconds(hold))
            dismiss(fade: reduceMotion ? Self.reducedFade : Self.fade)
        }
    }

    private func dismiss(fade: Double) {
        guard showSplash else { return }
        withAnimation(.easeInOut(duration: fade)) { showSplash = false }
    }
}

/// Penrose tiling generated once (off the main thread) in unit coordinates and
/// cached for every later use; scaled to the screen with a transform.
private enum PenroseSplashCache {
    static let unitPath: Path = {
        var path = Path()
        for s in PenroseTiling.segments(radius: 1, depth: 6) {
            path.move(to: CGPoint(x: s.p.x, y: s.p.y))
            path.addLine(to: CGPoint(x: s.q.x, y: s.q.y))
        }
        return path
    }()
}

private struct LaunchSplashView: View {
    let animated: Bool
    @State private var tiling: Path?
    @State private var start = Date()
    @State private var logoIn = false

    private let accent = Color(red: 0.0, green: 0.85, blue: 1.0) // retro cyan

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let radius = (size.width * size.width + size.height * size.height).squareRoot() / 2 * 1.05
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let path = tiling?.applying(CGAffineTransform(translationX: center.x, y: center.y).scaledBy(x: radius, y: radius))

            ZStack {
                Color("LaunchBackground")
                if let path {
                    // Static, faint line work (drawn once, not per frame).
                    path.stroke(Color.white.opacity(0.07), lineWidth: 0.5)
                        .transition(.opacity)
                    if animated {
                        TimelineView(.animation) { timeline in
                            let t = timeline.date.timeIntervalSince(start)
                            ripple(path: path, center: center, radius: radius, t: t)
                        }
                        .allowsHitTesting(false)
                    }
                }
                Image("LaunchLogo")
                    .scaleEffect(logoIn || !animated ? 1 : 0.96)
                    .opacity(logoIn || !animated ? 1 : 0.85)
                    .position(center)
                PixelLoadBar(animated: animated, color: accent)
                    .position(x: center.x, y: size.height * 0.78)
            }
        }
        .ignoresSafeArea()
        .task {
            // Build (or reuse) the cached tiling off the main actor.
            let path = await Task.detached(priority: .userInitiated) { PenroseSplashCache.unitPath }.value
            start = Date()
            withAnimation(.easeOut(duration: animated ? 0.3 : 0.15)) { tiling = path }
            if animated { withAnimation(.easeOut(duration: 0.45)) { logoIn = true } }
        }
    }

    /// Accent-tinted copy of the tiling, lit by a radial gradient whose stops are
    /// sampled from a damped radial sine (PondRipple), with a slight outward push.
    private func ripple(path: Path, center: CGPoint, radius: CGFloat, t: Double) -> some View {
        let maxR = Double(radius)
        let samples = 48
        var stops: [Gradient.Stop] = []
        var peak = 0.0
        for i in 0...samples {
            let f = Double(i) / Double(samples)
            let a = PondRipple.amplitude(r: f * maxR, t: t)
            peak = max(peak, a)
            stops.append(.init(color: accent.opacity(0.55 * a), location: f))
        }
        return Canvas { ctx, _ in
            ctx.stroke(path,
                       with: .radialGradient(Gradient(stops: stops), center: center, startRadius: 0, endRadius: radius),
                       lineWidth: 0.9)
        }
        .scaleEffect(1 + 0.01 * peak, anchor: UnitPoint(x: 0.5, y: 0.5))
        .drawingGroup()
    }
}

/// 8-bit style progress: ten square pixels light up one by one across the
/// splash hold. Reduce Motion: all pixels shown, no stepping.
private struct PixelLoadBar: View {
    let animated: Bool
    let color: Color
    @State private var start = Date()
    private let count = 10
    private let step: Double = 0.18

    var body: some View {
        TimelineView(.periodic(from: .now, by: step)) { timeline in
            let lit = animated
                ? min(count, Int(timeline.date.timeIntervalSince(start) / step) + 1)
                : count
            HStack(spacing: 4) {
                ForEach(0..<count, id: \.self) { i in
                    Rectangle()
                        .fill(i < lit ? color : color.opacity(0.15))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .accessibilityHidden(true)
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
