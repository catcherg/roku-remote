#if DEBUG
import Foundation
import SwiftUI

/// A pretend App Store for Debug builds only: SwiftUI previews, and walking
/// the purchase screens in a simulator when Xcode's StoreKit Testing is not
/// running. Never compiled into Release.
///
/// Launch arguments (Debug builds):
/// - `-ClickerDebugStore YES`                    use this instead of StoreKit
/// - `-ClickerDebugStoreReset YES`               start from a brand-new account
///                                               (also resets the free key presses)
/// - `-ClickerDebugStoreCancelSubscription YES`  turn off auto-renew: the
///                                               subscription ends with its period
/// - `-ClickerDebugStoreBilling grace|retry`     the last renewal failed
/// - `-ClickerDebugStoreBoughtElsewhere YES`     the account already owns the
///                                               lifetime unlock; only Restore
///                                               reveals it
/// - `-ClickerDebugDaysAhead 4`                  run as if it were 4 days later
///
/// It keeps the pretend account in UserDefaults so a relaunch behaves like
/// the real thing, and bills a 3-day trial then a week at a time. Its prices
/// are samples; the real ones come from StoreKit.
final class DebugPurchaseBackend: PurchaseBackend, @unchecked Sendable {
    private enum Key {
        static let ownsLifetime = "ClickerDebugStore.ownsLifetime"
        static let lifetimeNeedsRestore = "ClickerDebugStore.lifetimeNeedsRestore"
        static let subscribedAt = "ClickerDebugStore.subscribedAt"
        static let startedWithTrial = "ClickerDebugStore.startedWithTrial"
        static let trialUsed = "ClickerDebugStore.trialUsed"
        static let endsAt = "ClickerDebugStore.endsAt"
        static let all = [ownsLifetime, lifetimeNeedsRestore, subscribedAt,
                          startedWithTrial, trialUsed, endsAt]
    }

    private static let day: TimeInterval = 24 * 60 * 60
    private static let trial = BillingPeriod(value: 3, unit: .day)
    private static let week = BillingPeriod(value: 1, unit: .week)

    private let defaults: UserDefaults
    private let now: () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        if defaults.bool(forKey: "ClickerDebugStoreReset") {
            Key.all.forEach(defaults.removeObject)
            defaults.removeObject(forKey: "freeKeyPressesUsed")
        }
        if defaults.bool(forKey: "ClickerDebugStoreBoughtElsewhere") {
            defaults.set(true, forKey: Key.lifetimeNeedsRestore)
        }
        if defaults.bool(forKey: "ClickerDebugStoreCancelSubscription"),
           defaults.object(forKey: Key.endsAt) == nil,
           let current = subscription(), current.isActive {
            defaults.set(current.currentPeriodEnds, forKey: Key.endsAt)
        }
    }

    func loadOffer() async throws -> PurchaseOffer {
        PurchaseOffer(
            weeklyPrice: "$6.99",
            weeklyPeriod: Self.week,
            freeTrial: defaults.bool(forKey: Key.trialUsed) ? nil : Self.trial,
            lifetimePrice: "$24.99",
            lifetimeIsFamilyShareable: true
        )
    }

    func ownedPurchases() async -> OwnedPurchases {
        OwnedPurchases(ownsLifetime: defaults.bool(forKey: Key.ownsLifetime),
                       subscription: subscription())
    }

    /// Where the pretend subscription stands at the pretend current time.
    private func subscription() -> SubscriptionRecord? {
        guard let subscribedAt = defaults.object(forKey: Key.subscribedAt) as? Date else { return nil }
        let startedWithTrial = defaults.bool(forKey: Key.startedWithTrial)
        let endsAt = defaults.object(forKey: Key.endsAt) as? Date
        let now = now()

        if let endsAt, now >= endsAt {
            return SubscriptionRecord(state: .expired, currentPeriodEnds: endsAt, willAutoRenew: false)
        }

        let firstPeriodEnds = subscribedAt.addingTimeInterval((startedWithTrial ? 3 : 7) * Self.day)
        var record = SubscriptionRecord(state: .subscribed, willAutoRenew: endsAt == nil)
        if now < firstPeriodEnds {
            record.isInFreeTrial = startedWithTrial
            record.currentPeriodEnds = firstPeriodEnds
        } else {
            let weeksPaid = (now.timeIntervalSince(firstPeriodEnds) / (7 * Self.day)).rounded(.down) + 1
            record.currentPeriodEnds = firstPeriodEnds.addingTimeInterval(weeksPaid * 7 * Self.day)
        }

        switch defaults.string(forKey: "ClickerDebugStoreBilling") {
        case "grace": record.state = .inGracePeriod
        case "retry": record.state = .inBillingRetry
        default: break
        }
        return record
    }

    func purchase(_ product: PurchaseProduct) async throws -> PurchaseOutcome {
        try? await Task.sleep(nanoseconds: 600_000_000) // let the spinner show
        switch product {
        case .weekly:
            if subscription()?.isActive != true {
                // Like the App Store: the free trial is offered once.
                defaults.set(now(), forKey: Key.subscribedAt)
                defaults.set(!defaults.bool(forKey: Key.trialUsed), forKey: Key.startedWithTrial)
                defaults.set(true, forKey: Key.trialUsed)
                defaults.removeObject(forKey: Key.endsAt)
            }
        case .lifetime:
            defaults.set(true, forKey: Key.ownsLifetime)
        }
        return .purchased
    }

    func restore() async throws {
        try? await Task.sleep(nanoseconds: 600_000_000)
        if defaults.bool(forKey: Key.lifetimeNeedsRestore) {
            defaults.set(true, forKey: Key.ownsLifetime)
            defaults.set(false, forKey: Key.lifetimeNeedsRestore)
        }
    }

    func purchaseUpdates() -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }
}

extension EntitlementStore {
    /// Launch argument for seeing later dates without waiting:
    /// `-ClickerDebugDaysAhead 4` runs the app as if it were 4 days from now.
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

    /// A store for SwiftUI previews: a new customer by default, with the
    /// free key presses already used when `keyPressesUsed` says so.
    static func preview(keyPressesUsed: Int = 0) -> EntitlementStore {
        let defaults = UserDefaults(suiteName: "ClickerPreview-\(UUID().uuidString)") ?? .standard
        defaults.set(keyPressesUsed, forKey: "freeKeyPressesUsed")
        let store = EntitlementStore(backend: DebugPurchaseBackend(defaults: defaults), defaults: defaults)
        Task { await store.load() }
        return store
    }
}

#Preview("Paywall") {
    NavigationStack { PaywallView() }
        .environmentObject(EntitlementStore.preview(keyPressesUsed: FreePreview.keyPressAllowance))
}
#endif
