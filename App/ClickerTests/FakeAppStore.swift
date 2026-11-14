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

/// An in-memory App Store. It models the *Apple Account's* purchase history,
/// which lives on Apple's side and outlives any one install — so creating a
/// second `EntitlementStore` against the same `FakeAppStore` is a reinstall.
final class FakeAppStore: PurchaseBackend, @unchecked Sendable {
    struct Failure: Error {}

    private let lock = NSLock()
    private let clock: TestClock

    // The account's history, as Apple remembers it.
    private var trialPurchasedAt: Date?
    private var ownsUnlock = false
    private var pendingUnlock = false

    // What this device can currently see of it.
    private var deviceHasSynced = true
    private var continuations: [AsyncStream<Void>.Continuation] = []

    // Scripted behaviour.
    private var nextPurchaseOutcome: Result<PurchaseOutcome, Error> = .success(.purchased)
    private var offerResult: Result<PurchaseOffer, Error> =
        .success(PurchaseOffer(unlockPrice: "$4.99", unlockIsFamilyShareable: true))
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

    func setOfferResult(_ result: Result<PurchaseOffer, Error>) {
        locked { offerResult = result }
    }

    func setRestoreResult(_ result: Result<Void, Error>) {
        locked { restoreResult = result }
    }

    /// A fresh install whose StoreKit cache has not caught up with the account.
    func simulateInstallThatHasNotSynced() {
        locked { deviceHasSynced = false }
    }

    /// The unlock arrives from outside the app: Ask to Buy approved, bought on
    /// another device, or shared by a family member.
    func grantUnlockFromElsewhere() {
        locked { ownsUnlock = true; pendingUnlock = false }
        sendUpdate()
    }

    /// Refund, or Family Sharing switched off.
    func revokeUnlock() {
        locked { ownsUnlock = false }
        sendUpdate()
    }

    private func sendUpdate() {
        let targets = locked { continuations }
        targets.forEach { $0.yield() }
    }

    // MARK: - PurchaseBackend

    func loadOffer() async throws -> PurchaseOffer {
        try locked { try offerResult.get() }
    }

    func ownedPurchases() async -> OwnedPurchases {
        locked {
            guard deviceHasSynced else { return OwnedPurchases() }
            return OwnedPurchases(trialStartedAt: trialPurchasedAt, isUnlocked: ownsUnlock)
        }
    }

    func purchase(_ product: PurchaseProduct) async throws -> PurchaseOutcome {
        try locked {
            let outcome = try nextPurchaseOutcome.get()
            switch outcome {
            case .purchased:
                switch product {
                case .trial:
                    // Like the real App Store: buying a non-consumable that is
                    // already owned hands back the original transaction.
                    if trialPurchasedAt == nil { trialPurchasedAt = clock.now }
                case .unlock:
                    ownsUnlock = true
                }
                deviceHasSynced = true
            case .pending:
                if product == .unlock { pendingUnlock = true }
            case .cancelled:
                break
            }
            return outcome
        }
    }

    func restore() async throws {
        try locked {
            try restoreResult.get()
            deviceHasSynced = true
        }
    }

    func transactionUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            locked { continuations.append(continuation) }
        }
    }
}
