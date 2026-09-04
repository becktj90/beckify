import Foundation
import BeckifyMath

/// On-device counters for a respectful App Store review ask.
///
/// StoreKit stays at the SwiftUI environment boundary. There is still no IAP,
/// no StoreKit product, and no paid listing. Apple’s system prompt is the only
/// UI — no custom “Rate us 5★” sheet (App Review 5.6.1).
@MainActor
final class ReviewAskStore: ObservableObject {
    static let shared = ReviewAskStore()

    private enum Key {
        static let savedJobs = "com.beckify.toolbox.reviewAsk.savedJobs"
        static let successfulCalcs = "com.beckify.toolbox.reviewAsk.successfulCalcs"
        static let sessionDays = "com.beckify.toolbox.reviewAsk.sessionDays"
        static let lastSessionDay = "com.beckify.toolbox.reviewAsk.lastSessionDay"
        static let firstLaunch = "com.beckify.toolbox.reviewAsk.firstLaunch"
        static let lastPromptedVersion = "com.beckify.toolbox.reviewAsk.lastPromptedVersion"
        static let pending = "com.beckify.toolbox.reviewAsk.pending"
    }

    private let defaults: UserDefaults
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    @Published private(set) var pendingAsk = false

    /// Session-only. A permission deny is not a win and must not be followed
    /// by Apple’s review sheet (Ugly’s-style 1★ pattern).
    private var deniedPermissionThisSession = false

    private var savedJobCount: Int
    private var successfulCalcCount: Int
    private var distinctSessionDays: Int
    private var firstLaunchAt: Date
    private var lastPromptedVersion: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        savedJobCount = defaults.integer(forKey: Key.savedJobs)
        successfulCalcCount = defaults.integer(forKey: Key.successfulCalcs)
        distinctSessionDays = max(defaults.integer(forKey: Key.sessionDays), 0)
        lastPromptedVersion = defaults.string(forKey: Key.lastPromptedVersion) ?? ""
        pendingAsk = defaults.bool(forKey: Key.pending)
        if let stored = defaults.object(forKey: Key.firstLaunch) as? Date {
            firstLaunchAt = stored
        } else {
            firstLaunchAt = Date()
            defaults.set(firstLaunchAt, forKey: Key.firstLaunch)
        }
    }

    /// Call once when the app becomes active. Counts a session day, never asks.
    func recordSession(now: Date = Date()) {
        let day = dayFormatter.string(from: now)
        let last = defaults.string(forKey: Key.lastSessionDay)
        if last != day {
            distinctSessionDays += 1
            defaults.set(day, forKey: Key.lastSessionDay)
            defaults.set(distinctSessionDays, forKey: Key.sessionDays)
        }
    }

    func notePermissionDenied() {
        deniedPermissionThisSession = true
    }

    func recordSavedJob() {
        savedJobCount += 1
        defaults.set(savedJobCount, forKey: Key.savedJobs)
        armIfEligible()
    }

    func recordSuccessfulCalc() {
        successfulCalcCount += 1
        defaults.set(successfulCalcCount, forKey: Key.successfulCalcs)
        armIfEligible()
    }

    /// After a win, remember to ask later — not from the Save/Calculate tap.
    private func armIfEligible() {
        guard ReviewAskPolicy.hasClearWin(snapshot()) else { return }
        pendingAsk = true
        defaults.set(true, forKey: Key.pending)
    }

    /// If a win is pending and the policy gates pass, consume the ask and
    /// present Apple’s system sheet after a short pause. Caller must be at
    /// Field home (or switching back to Toolbox) — never first-launch onAppear.
    func presentIfEligible(_ requestReview: @MainActor @escaping () -> Void, currentVersion: String) {
        guard !deniedPermissionThisSession else { return }
        guard pendingAsk, ReviewAskPolicy.shouldRequest(snapshot(currentVersion: currentVersion)) else {
            return
        }
        pendingAsk = false
        lastPromptedVersion = currentVersion
        defaults.set(false, forKey: Key.pending)
        defaults.set(currentVersion, forKey: Key.lastPromptedVersion)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            requestReview()
        }
    }

    func snapshot(now: Date = Date(), currentVersion: String = ReviewAskStore.marketingVersion) -> ReviewAskSnapshot {
        ReviewAskSnapshot(
            savedJobCount: savedJobCount,
            successfulCalcCount: successfulCalcCount,
            distinctSessionDays: distinctSessionDays,
            firstLaunchAt: firstLaunchAt,
            lastPromptedVersion: lastPromptedVersion,
            currentVersion: currentVersion,
            now: now
        )
    }

    nonisolated static var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
