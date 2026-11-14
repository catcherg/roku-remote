import Foundation

/// The two in-app purchases behind Clicker's paid path. Both are
/// non-consumables — the pattern App Review Guideline 3.1.1 names for a
/// non-subscription trial: a $0 "XX-day Trial" item plus a paid full unlock.
/// The identifiers must match App Store Connect and Support/Clicker.storekit.
enum PurchaseProduct: String, CaseIterable, Sendable {
    case trial = "com.catchergriffin.clicker.trial"
    case unlock = "com.catchergriffin.clicker.unlock"
}

/// What the App Store says this Apple Account owns. Built only from StoreKit
/// transactions, never from anything saved on the device.
struct OwnedPurchases: Equatable, Sendable {
    /// Purchase date of the $0 trial transaction, or nil if never started.
    var trialStartedAt: Date?
    /// True when the full unlock is owned (bought here or Family Shared).
    var isUnlocked = false
}

/// What the app is allowed to do right now. Drives all purchase UI.
enum Access: Equatable, Sendable {
    /// StoreKit has not answered yet (first moments after launch).
    case loading
    /// No trial transaction and no unlock: the trial has to be started first.
    case needsTrial
    /// Trial running. `daysRemaining` is rounded up, so it is never 0.
    case trial(daysRemaining: Int)
    /// Trial over, not unlocked: the remote is blocked behind the paywall.
    case expired
    /// Full unlock owned. Forever.
    case unlocked

    /// Whether the remote and the other feature screens may be used.
    var allowsRemote: Bool {
        switch self {
        case .trial, .unlocked: return true
        case .loading, .needsTrial, .expired: return false
        }
    }
}

/// The trial rules, as pure functions of "what is owned" and "what time is it".
enum TrialPolicy {
    static let lengthInDays = 7

    private static let day: TimeInterval = 24 * 60 * 60

    static func endDate(startedAt: Date) -> Date {
        startedAt.addingTimeInterval(TimeInterval(lengthInDays) * day)
    }

    static func access(for owned: OwnedPurchases, now: Date) -> Access {
        if owned.isUnlocked { return .unlocked }
        guard let startedAt = owned.trialStartedAt else { return .needsTrial }

        let remaining = endDate(startedAt: startedAt).timeIntervalSince(now)
        guard remaining > 0 else { return .expired }
        // Round up so the last partial day still reads "1 day left"; cap at the
        // trial length in case the device clock is behind the purchase date.
        let days = Int((remaining / day).rounded(.up))
        return .trial(daysRemaining: min(max(days, 1), lengthInDays))
    }

    /// Seconds until `access(for:now:)` next returns something different
    /// (the day count drops, or the trial ends). Nil when nothing will change.
    static func secondsUntilNextChange(for owned: OwnedPurchases, now: Date) -> TimeInterval? {
        guard !owned.isUnlocked, let startedAt = owned.trialStartedAt else { return nil }
        let remaining = endDate(startedAt: startedAt).timeIntervalSince(now)
        guard remaining > 0 else { return nil }
        let intoCurrentDay = remaining.truncatingRemainder(dividingBy: day)
        return intoCurrentDay > 0 ? intoCurrentDay : day
    }
}
