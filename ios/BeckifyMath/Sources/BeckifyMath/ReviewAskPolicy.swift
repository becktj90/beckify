import Foundation

/// Snapshot the app feeds into `ReviewAskPolicy`. Pure data — no StoreKit.
public struct ReviewAskSnapshot: Equatable, Sendable {
    public var savedJobCount: Int
    public var successfulCalcCount: Int
    public var distinctSessionDays: Int
    public var firstLaunchAt: Date
    public var lastPromptedVersion: String
    public var currentVersion: String
    public var now: Date

    public init(
        savedJobCount: Int,
        successfulCalcCount: Int,
        distinctSessionDays: Int,
        firstLaunchAt: Date,
        lastPromptedVersion: String,
        currentVersion: String,
        now: Date
    ) {
        self.savedJobCount = savedJobCount
        self.successfulCalcCount = successfulCalcCount
        self.distinctSessionDays = distinctSessionDays
        self.firstLaunchAt = firstLaunchAt
        self.lastPromptedVersion = lastPromptedVersion
        self.currentVersion = currentVersion
        self.now = now
    }
}

/// When Beckify is allowed to *consider* Apple’s system review prompt.
///
/// This does **not** show UI. The app calls StoreKit `requestReview` only after
/// this returns true, and never from first launch or a Save/Calculate tap.
/// Apple still decides whether the sheet appears (max 3 times / 365 days).
///
/// Gates exist because field-EE peers punish review nagging (Ugly’s “asks every
/// launch” 1★/2★ pattern) harder than a missing prompt.
public enum ReviewAskPolicy {
    public static let minimumSavedJobs = 2
    public static let minimumSuccessfulCalcsWithOneSave = 5
    public static let minimumSuccessfulCalcsAlone = 8
    public static let minimumSessionDays = 2
    public static let minimumHoursSinceFirstLaunch: Double = 12

    /// A jobsite-shaped win: saved notes, or enough successful Calculate presses.
    public static func hasClearWin(_ snapshot: ReviewAskSnapshot) -> Bool {
        if snapshot.savedJobCount >= minimumSavedJobs { return true }
        if snapshot.savedJobCount >= 1,
           snapshot.successfulCalcCount >= minimumSuccessfulCalcsWithOneSave
        {
            return true
        }
        if snapshot.successfulCalcCount >= minimumSuccessfulCalcsAlone { return true }
        return false
    }

    /// True only after a returning session, a cooling-off period, a clear win,
    /// and not already prompted on this marketing version.
    public static func shouldRequest(_ snapshot: ReviewAskSnapshot) -> Bool {
        guard snapshot.currentVersion != snapshot.lastPromptedVersion else { return false }
        guard snapshot.distinctSessionDays >= minimumSessionDays else { return false }
        let hours = snapshot.now.timeIntervalSince(snapshot.firstLaunchAt) / 3600
        guard hours >= minimumHoursSinceFirstLaunch else { return false }
        return hasClearWin(snapshot)
    }
}
