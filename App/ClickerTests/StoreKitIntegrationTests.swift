import StoreKit
import StoreKitTest
import XCTest
@testable import Clicker

/// The real StoreKit 2 backend against Support/Clicker.storekit, using
/// Xcode's local StoreKit test environment. No network, no sandbox account.
@MainActor
final class StoreKitIntegrationTests: XCTestCase {
    private var session: SKTestSession!

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "Clicker")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
    }

    override func tearDown() async throws {
        session.clearTransactions()
        session = nil
    }

    private func install(daysAhead: Double = 0) async -> EntitlementStore {
        let store = EntitlementStore(
            backend: StoreKitPurchaseBackend(),
            now: { Date().addingTimeInterval(daysAhead * 24 * 60 * 60) }
        )
        await store.load()
        return store
    }

    private func waitUntil(_ condition: () -> Bool, timeout: TimeInterval = 5) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    func testConfigurationDefinesTheTrialAndTheUnlock() async throws {
        let products = try await Product.products(for: PurchaseProduct.allCases.map(\.rawValue))
        XCTAssertEqual(products.count, 2)

        let trial = try XCTUnwrap(products.first { $0.id == PurchaseProduct.trial.rawValue })
        XCTAssertEqual(trial.type, .nonConsumable)
        XCTAssertEqual(trial.price, 0)
        XCTAssertEqual(trial.displayName, "7-day Trial", "Guideline 3.1.1 naming convention")

        let unlock = try XCTUnwrap(products.first { $0.id == PurchaseProduct.unlock.rawValue })
        XCTAssertEqual(unlock.type, .nonConsumable)
        XCTAssertGreaterThan(unlock.price, 0)
        XCTAssertTrue(unlock.isFamilyShareable)

        let offer = try await StoreKitPurchaseBackend().loadOffer()
        XCTAssertEqual(offer.unlockPrice, unlock.displayPrice)
        XCTAssertTrue(offer.unlockIsFamilyShareable)
    }

    func testFirstLaunchTrialExpiryAndUnlock() async throws {
        let store = await install()
        XCTAssertEqual(store.access, .needsTrial)

        await store.startTrial()
        XCTAssertEqual(store.access, .trial(daysRemaining: 7))

        // The trial clock is the transaction's purchase date.
        let owned = await StoreKitPurchaseBackend().ownedPurchases()
        let startedAt = try XCTUnwrap(owned.trialStartedAt)
        XCTAssertEqual(startedAt.timeIntervalSinceNow, 0, accuracy: 60)
        XCTAssertFalse(owned.isUnlocked)

        // A second install (nothing carried over but the Apple Account), a
        // few days on, sees the same trial rather than a new one.
        let reinstall = await install(daysAhead: 3)
        XCTAssertEqual(reinstall.access, .trial(daysRemaining: 4))

        // Starting the trial again does not move its start date.
        await reinstall.startTrial()
        let ownedAgain = await StoreKitPurchaseBackend().ownedPurchases()
        XCTAssertEqual(ownedAgain.trialStartedAt, startedAt)

        // Past day seven the same purchase history reads as expired…
        let later = await install(daysAhead: 8)
        XCTAssertEqual(later.access, .expired)

        // …until the one-time unlock is bought.
        await later.unlock()
        XCTAssertEqual(later.access, .unlocked)
        let reinstalledAfterUnlock = await install(daysAhead: 400)
        XCTAssertEqual(reinstalledAfterUnlock.access, .unlocked)
    }

    func testRefundedUnlockIsNoLongerAnEntitlement() async throws {
        let store = await install(daysAhead: 8)
        await store.startTrial()
        await store.unlock()
        XCTAssertEqual(store.access, .unlocked)

        let unlock = try XCTUnwrap(session.allTransactions().first {
            $0.productIdentifier == PurchaseProduct.unlock.rawValue
        })
        try session.refundTransaction(identifier: unlock.identifier)

        // Arrives through Transaction.updates; nobody calls refresh().
        await waitUntil { store.access == .expired }
        XCTAssertEqual(store.access, .expired)
    }
}
