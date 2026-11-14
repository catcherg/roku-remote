import StoreKit
import StoreKitTest
import XCTest
@testable import Clicker

/// The real StoreKit 2 backend against Support/Clicker.storekit, using
/// Xcode's local StoreKit test environment. No network, no sandbox account.
/// Needs the Xcode test runner (Cmd-U or `xcodebuild test`).
@MainActor
final class StoreKitIntegrationTests: XCTestCase {
    private var session: SKTestSession!
    private var device: UserDefaults!
    private var deviceSuite: String!

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "Clicker")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        deviceSuite = "ClickerStoreKitTests-\(UUID().uuidString)"
        device = UserDefaults(suiteName: deviceSuite)
    }

    override func tearDown() async throws {
        session.clearTransactions()
        session = nil
        device.removePersistentDomain(forName: deviceSuite)
    }

    private func launch() async -> EntitlementStore {
        let store = EntitlementStore(backend: StoreKitPurchaseBackend(), defaults: device)
        await store.load()
        return store
    }

    private func waitUntil(_ condition: () -> Bool, timeout: TimeInterval = 10) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    func testConfigurationDefinesTheWeeklySubscriptionAndTheLifetimeUnlock() async throws {
        let products = try await Product.products(for: PurchaseProduct.allCases.map(\.rawValue))
        XCTAssertEqual(products.count, 2)

        let weekly = try XCTUnwrap(products.first { $0.id == PurchaseProduct.weekly.rawValue })
        XCTAssertEqual(weekly.type, .autoRenewable)
        let subscription = try XCTUnwrap(weekly.subscription)
        let intro = try XCTUnwrap(subscription.introductoryOffer)
        XCTAssertEqual(intro.paymentMode, .freeTrial)

        let lifetime = try XCTUnwrap(products.first { $0.id == PurchaseProduct.lifetime.rawValue })
        XCTAssertEqual(lifetime.type, .nonConsumable)
        XCTAssertGreaterThan(lifetime.price, weekly.price)
        XCTAssertTrue(lifetime.isFamilyShareable)

        // What the paywall will say comes straight from those products.
        let offer = try await StoreKitPurchaseBackend().loadOffer()
        XCTAssertEqual(offer.weeklyPrice, weekly.displayPrice)
        XCTAssertEqual(offer.weeklyPeriod, BillingPeriod(value: 1, unit: .week))
        XCTAssertEqual(offer.freeTrial, BillingPeriod(value: 3, unit: .day))
        XCTAssertEqual(offer.lifetimePrice, lifetime.displayPrice)
        XCTAssertTrue(offer.lifetimeIsFamilyShareable)
    }

    func testFreeTrialThenLapseThenLifetime() async throws {
        let store = await launch()
        XCTAssertEqual(store.access, .notEntitled(lapsed: false))

        // Starting the subscription starts its free trial and unlocks.
        await store.subscribe()
        guard case .subscribed(let trial) = store.access else {
            return XCTFail("expected an active subscription, got \(store.access)")
        }
        XCTAssertTrue(trial.isInFreeTrial)
        XCTAssertNotNil(trial.currentPeriodEnds)

        // A second launch reads the same standing from StoreKit.
        let relaunched = await launch()
        XCTAssertTrue(relaunched.access.isUnlocked)

        // When it lapses, access goes with it. Nobody calls refresh().
        try session.expireSubscription(productIdentifier: PurchaseProduct.weekly.rawValue)
        await waitUntil { !store.access.isUnlocked }
        XCTAssertEqual(store.access, .notEntitled(lapsed: true))

        // The lifetime unlock wins over the lapsed subscription, for good.
        await store.buyLifetime()
        XCTAssertEqual(store.access, .lifetime)
        let later = await launch()
        XCTAssertEqual(later.access, .lifetime)
    }

    func testRefundedLifetimeIsNoLongerAnEntitlement() async throws {
        let store = await launch()
        await store.buyLifetime()
        XCTAssertEqual(store.access, .lifetime)

        let purchase = try XCTUnwrap(session.allTransactions().first {
            $0.productIdentifier == PurchaseProduct.lifetime.rawValue
        })
        try session.refundTransaction(identifier: purchase.identifier)

        await waitUntil { store.access != .lifetime }
        XCTAssertEqual(store.access, .notEntitled(lapsed: false))
    }
}
