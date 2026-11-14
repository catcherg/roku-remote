#if DEBUG
import Foundation
import SwiftUI

/// A pretend App Store for Debug builds only: SwiftUI previews, and walking
/// the purchase screens in a simulator when Xcode's StoreKit Testing is not
/// running. Never compiled into Release.
///
/// Launch arguments (Debug builds):
/// - `-ClickerDebugStore YES`                 use this instead of StoreKit
/// - `-ClickerDebugStoreReset YES`            start from a brand-new account
/// - `-ClickerDebugStoreBoughtElsewhere YES`  the account already owns the
///                                            unlock; only Restore reveals it
/// - `-ClickerDebugDaysAhead 8`               run as if it were 8 days later
///
/// It keeps the pretend account in UserDefaults so a relaunch behaves like
/// the real thing. Unlike the real App Store that memory dies with the app,
/// so reinstall behaviour can only be judged against StoreKit itself.
final class DebugPurchaseBackend: PurchaseBackend, @unchecked Sendable {
    private enum Key {
        static let trialStartedAt = "ClickerDebugStore.trialStartedAt"
        static let unlocked = "ClickerDebugStore.unlocked"
        static let unlockNeedsRestore = "ClickerDebugStore.unlockNeedsRestore"
    }

    private let defaults: UserDefaults
    private let now: () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        if defaults.bool(forKey: "ClickerDebugStoreReset") {
            [Key.trialStartedAt, Key.unlocked, Key.unlockNeedsRestore].forEach(defaults.removeObject)
        }
        if defaults.bool(forKey: "ClickerDebugStoreBoughtElsewhere") {
            defaults.set(true, forKey: Key.unlockNeedsRestore)
        }
    }

    func loadOffer() async throws -> PurchaseOffer {
        // Sample price for the stand-in product; the real one comes from StoreKit.
        PurchaseOffer(unlockPrice: "$4.99", unlockIsFamilyShareable: true)
    }

    func ownedPurchases() async -> OwnedPurchases {
        OwnedPurchases(
            trialStartedAt: defaults.object(forKey: Key.trialStartedAt) as? Date,
            isUnlocked: defaults.bool(forKey: Key.unlocked)
        )
    }

    func purchase(_ product: PurchaseProduct) async throws -> PurchaseOutcome {
        try? await Task.sleep(nanoseconds: 600_000_000) // let the spinner show
        switch product {
        case .trial:
            // Like the App Store: an owned non-consumable keeps its first date.
            if defaults.object(forKey: Key.trialStartedAt) == nil {
                defaults.set(now(), forKey: Key.trialStartedAt)
            }
        case .unlock:
            defaults.set(true, forKey: Key.unlocked)
        }
        return .purchased
    }

    func restore() async throws {
        try? await Task.sleep(nanoseconds: 600_000_000)
        if defaults.bool(forKey: Key.unlockNeedsRestore) {
            defaults.set(true, forKey: Key.unlocked)
            defaults.set(false, forKey: Key.unlockNeedsRestore)
        }
    }

    func transactionUpdates() -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }
}

extension EntitlementStore {
    /// Launch argument for walking through the trial without waiting a week:
    /// `-ClickerDebugDaysAhead 8` runs the app as if it were 8 days from now.
    static func debugClock() -> () -> Date {
        let daysAhead = UserDefaults.standard.double(forKey: "ClickerDebugDaysAhead")
        return { Date().addingTimeInterval(daysAhead * 24 * 60 * 60) }
    }

    /// The store Debug builds launch with: StoreKit, unless
    /// `-ClickerDebugStore YES` asks for the stand-in.
    static func debug() -> EntitlementStore {
        let clock = debugClock()
        if UserDefaults.standard.bool(forKey: "ClickerDebugStore") {
            return EntitlementStore(backend: DebugPurchaseBackend(now: clock), now: clock)
        }
        return EntitlementStore(now: clock)
    }

    /// A store in a given state for SwiftUI previews.
    /// `trialStartedDaysAgo: nil` is a brand-new user; 8 is an expired trial.
    static func preview(trialStartedDaysAgo: Double? = 2, unlocked: Bool = false) -> EntitlementStore {
        let defaults = UserDefaults(suiteName: "ClickerPreview-\(UUID().uuidString)") ?? .standard
        if let days = trialStartedDaysAgo {
            defaults.set(Date().addingTimeInterval(-days * 24 * 60 * 60),
                         forKey: "ClickerDebugStore.trialStartedAt")
        }
        defaults.set(unlocked, forKey: "ClickerDebugStore.unlocked")
        let store = EntitlementStore(backend: DebugPurchaseBackend(defaults: defaults))
        Task { await store.load() }
        return store
    }
}

#Preview("Paywall, trial ended") {
    NavigationStack { PaywallView() }
        .environmentObject(EntitlementStore.preview(trialStartedDaysAgo: 8))
        .environmentObject(AppState())
}

#Preview("Trial offer") {
    NavigationStack { TrialOfferScreen() }
        .environmentObject(EntitlementStore.preview(trialStartedDaysAgo: nil))
        .environmentObject(AppState())
}
#endif
