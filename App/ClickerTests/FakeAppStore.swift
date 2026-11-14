import Foundation
@testable import Clicker

/// A clock the tests can move.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
        current = start
    }

    var now: Date {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    func advance(days: Double) {
        lock.lock(); defer { lock.unlock() }
        current = current.addingTimeInterval(days * 24 * 60 * 60)
    }
}

/// An in-memory App Store. It models the *Apple Account's* purchases, which
/// live on Apple's side and outlive any one install — so creating a second
/// `EntitlementStore` against the same `FakeAppStore` is a reinstall.
final class FakeAppStore: PurchaseBackend, @unchecked Sendable {
    struct Failure: Error {}

    static let trial = BillingPeriod(value: 3, unit: .day)
    static let week = BillingPeriod(value: 1, unit: .week)

    private let lock = NSLock()
    private let clock: TestClock

    // The account, as Apple remembers it.
    private var ownsLifetime = false
    private var subscription: SubscriptionRecord?
    private var trialUsed = false

    // What this device can currently see of it.
    private var deviceHasSynced = true
    private var continuations: [AsyncStream<Void>.Continuation] = []

    // Scripted behaviour.
    private var nextPurchaseOutcome: Result<PurchaseOutcome, Error> = .success(.purchased)
    private var offerFailure: Error?
    private var prices = (weekly: "$6.99", lifetime: "$24.99")
    private var restoreResult: Result<Void, Error> = .success(())

    init(clock: TestClock) {
        self.clock = clock
    }

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }
        return try body()
    }

    // MARK: - Test controls

    func setNextPurchaseOutcome(_ outcome: Result<PurchaseOutcome, Error>) {
        locked { nextPurchaseOutcome = outcome }
    }

    func setOfferFailure(_ error: Error?) {
        locked { offerFailure = error }
    }

    func setPrices(weekly: String, lifetime: String) {
        locked { prices = (weekly, lifetime) }
    }

    func setRestoreResult(_ result: Result<Void, Error>) {
        locked { restoreResult = result }
    }

    /// A fresh install whose StoreKit cache has not caught up with the account.
    func simulateInstallThatHasNotSynced() {
        locked { deviceHasSynced = false }
    }

    /// Changes the subscription the way the App Store would on its own
    /// (renewal, failed payment, lapse, cancellation) and announces it.
    func updateSubscription(_ change: (inout SubscriptionRecord) -> Void) {
        locked {
            guard var record = subscription else { return }
            change(&record)
            subscription = record
        }
        sendUpdate()
    }

    /// The free trial ends and the first payment goes through.
    func convertTrialToPaid() {
        let nextWeek = clock.now.addingTimeInterval(7 * 24 * 60 * 60)
        updateSubscription {
            $0.isInFreeTrial = false
            $0.currentPeriodEnds = nextWeek
        }
    }

    /// The lifetime unlock arrives from outside the app: Ask to Buy approved,
    /// bought on another device, or shared by a family member.
    func grantLifetimeFromElsewhere() {
        locked { ownsLifetime = true }
        sendUpdate()
    }

    /// Refund, or Family Sharing switched off.
    func revokeLifetime() {
        locked { ownsLifetime = false }
        sendUpdate()
    }

    private func sendUpdate() {
        let targets = locked { continuations }
        targets.forEach { $0.yield() }
    }

    // MARK: - PurchaseBackend

    func loadOffer() async throws -> PurchaseOffer {
        try locked {
            if let offerFailure { throw offerFailure }
            return PurchaseOffer(
                weeklyPrice: prices.weekly,
                weeklyPeriod: Self.week,
                // Like the App Store: one free trial per Apple Account.
                freeTrial: trialUsed ? nil : Self.trial,
                lifetimePrice: prices.lifetime,
                lifetimeIsFamilyShareable: true
            )
        }
    }

    func ownedPurchases() async -> OwnedPurchases {
        locked {
            guard deviceHasSynced else { return OwnedPurchases() }
            return OwnedPurchases(ownsLifetime: ownsLifetime, subscription: subscription)
        }
    }

    func purchase(_ product: PurchaseProduct) async throws -> PurchaseOutcome {
        try locked {
            let outcome = try nextPurchaseOutcome.get()
            guard outcome == .purchased else { return outcome }
            switch product {
            case .weekly:
                if subscription?.isActive != true {
                    let days: Double = trialUsed ? 7 : 3
                    subscription = SubscriptionRecord(
                        state: .subscribed,
                        isInFreeTrial: !trialUsed,
                        currentPeriodEnds: clock.now.addingTimeInterval(days * 24 * 60 * 60)
                    )
                    trialUsed = true
                }
            case .lifetime:
                ownsLifetime = true
            }
            deviceHasSynced = true
            return outcome
        }
    }

    func restore() async throws {
        try locked {
            try restoreResult.get()
            deviceHasSynced = true
        }
    }

    func purchaseUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            locked { continuations.append(continuation) }
        }
    }
}
