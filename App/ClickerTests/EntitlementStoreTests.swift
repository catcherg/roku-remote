import XCTest
@testable import Clicker

/// EntitlementStore against an in-memory App Store.
@MainActor
final class EntitlementStoreTests: XCTestCase {
    private var clock: TestClock!
    private var appStore: FakeAppStore!
    /// This device's own storage: just the count of used free key presses.
    private var device: UserDefaults!
    private var deviceSuite: String!

    override func setUp() {
        super.setUp()
        clock = TestClock()
        appStore = FakeAppStore(clock: clock)
        deviceSuite = "ClickerTests-\(UUID().uuidString)"
        device = UserDefaults(suiteName: deviceSuite)
    }

    override func tearDown() {
        device.removePersistentDomain(forName: deviceSuite)
        super.tearDown()
    }

    /// A new store over the same device storage is a relaunch.
    private func launch() async -> EntitlementStore {
        let store = EntitlementStore(backend: appStore, defaults: device, now: { [clock] in clock!.now })
        await store.load()
        return store
    }

    /// A new store over empty device storage is a new install on the same
    /// Apple Account.
    private func reinstall() async -> EntitlementStore {
        device.removePersistentDomain(forName: deviceSuite)
        return await launch()
    }

    private func waitUntil(_ condition: () -> Bool, timeout: TimeInterval = 2) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    /// Sends `count` key presses the way AppState does: ask, then report the
    /// ones the Roku accepted. Returns how many were allowed.
    @discardableResult
    private func press(_ count: Int, on store: EntitlementStore) -> Int {
        var allowed = 0
        for _ in 0..<count where store.mayPress() {
            store.didPress()
            allowed += 1
        }
        return allowed
    }

    private func subscription(of store: EntitlementStore) -> SubscriptionRecord? {
        if case .subscribed(let record) = store.access { return record }
        return nil
    }

    // MARK: - First launch

    func testIsLoadingUntilStoreKitAnswers() {
        let store = EntitlementStore(backend: appStore, defaults: device)
        XCTAssertEqual(store.access, .loading)
        XCTAssertEqual(store.offer, .loading)
    }

    func testFirstLaunchHasNoEntitlementAndBothPlansOnOffer() async {
        let store = await launch()
        XCTAssertEqual(store.access, .notEntitled(lapsed: false))
        XCTAssertEqual(store.offer, .ready(PurchaseOffer(
            weeklyPrice: "$6.99", weeklyPeriod: FakeAppStore.week, freeTrial: FakeAppStore.trial,
            lifetimePrice: "$24.99", lifetimeIsFamilyShareable: true)))
        XCTAssertNil(store.notice)
    }

    // MARK: - Weekly subscription

    func testStartingTheFreeTrialUnlocks() async {
        let store = await launch()
        await store.subscribe()

        let record = subscription(of: store)
        XCTAssertEqual(record?.isInFreeTrial, true)
        XCTAssertEqual(record?.currentPeriodEnds, clock.now.addingTimeInterval(3 * 24 * 60 * 60))
        XCTAssertTrue(store.access.isUnlocked)
        XCTAssertNil(store.activity)
        XCTAssertNil(store.notice)
    }

    func testTrialTurnsIntoAPaidSubscription() async {
        let store = await launch()
        await store.subscribe()

        clock.advance(days: 3)
        appStore.convertTrialToPaid()
        await waitUntil { self.subscription(of: store)?.isInFreeTrial == false }

        XCTAssertEqual(subscription(of: store)?.isInFreeTrial, false)
        XCTAssertEqual(subscription(of: store)?.state, .subscribed)
        XCTAssertTrue(store.access.isUnlocked)
    }

    func testGracePeriodAndBillingRetryStayUnlocked() async {
        let store = await launch()
        await store.subscribe()

        appStore.updateSubscription { $0.state = .inGracePeriod }
        await waitUntil { self.subscription(of: store)?.state == .inGracePeriod }
        XCTAssertTrue(store.access.isUnlocked)
        XCTAssertEqual(subscription(of: store)?.hasBillingIssue, true)

        appStore.updateSubscription { $0.state = .inBillingRetry }
        await waitUntil { self.subscription(of: store)?.state == .inBillingRetry }
        XCTAssertTrue(store.access.isUnlocked)
        XCTAssertTrue(store.mayPress())
    }

    func testCancelledSubscriptionStaysUnlockedUntilItEnds() async {
        let store = await launch()
        await store.subscribe()

        appStore.updateSubscription { $0.willAutoRenew = false }
        await waitUntil { self.subscription(of: store)?.willAutoRenew == false }
        XCTAssertTrue(store.access.isUnlocked)

        appStore.updateSubscription { $0.state = .expired }
        await waitUntil { !store.access.isUnlocked }
        XCTAssertEqual(store.access, .notEntitled(lapsed: true))
    }

    func testExpiredSubscriptionIsFoundAtTheNextLaunch() async {
        let first = await launch()
        await first.subscribe()
        appStore.updateSubscription { $0.state = .expired }

        let relaunched = await launch()
        XCTAssertEqual(relaunched.access, .notEntitled(lapsed: true))
    }

    func testResubscribingAfterALapseGetsNoSecondFreeTrial() async {
        let store = await launch()
        await store.subscribe()
        appStore.updateSubscription { $0.state = .expired }
        await waitUntil { !store.access.isUnlocked }

        // The offer follows the account: the trial has been used.
        await store.loadOffer()
        guard case .ready(let offer) = store.offer else { return XCTFail("offer not ready") }
        XCTAssertNil(offer.freeTrial)

        await store.subscribe()
        XCTAssertEqual(subscription(of: store)?.isInFreeTrial, false)
        XCTAssertTrue(store.access.isUnlocked)
    }

    func testCancellingThePurchaseSheetChangesNothing() async {
        let store = await launch()
        appStore.setNextPurchaseOutcome(.success(.cancelled))
        await store.subscribe()
        XCTAssertEqual(store.access, .notEntitled(lapsed: false))
        XCTAssertNil(store.notice)
    }

    func testFailedPurchaseShowsANoticeAndStaysLocked() async {
        let store = await launch()
        appStore.setNextPurchaseOutcome(.failure(FakeAppStore.Failure()))
        await store.subscribe()
        XCTAssertEqual(store.access, .notEntitled(lapsed: false))
        XCTAssertEqual(store.notice, .purchaseFailed)

        // The next attempt clears the notice.
        appStore.setNextPurchaseOutcome(.success(.purchased))
        await store.subscribe()
        XCTAssertTrue(store.access.isUnlocked)
        XCTAssertNil(store.notice)
    }

    // MARK: - Lifetime

    func testLifetimeUnlocksForGood() async {
        let store = await launch()
        await store.buyLifetime()
        XCTAssertEqual(store.access, .lifetime)

        clock.advance(days: 3650)
        let years = await launch()
        XCTAssertEqual(years.access, .lifetime)
    }

    func testLifetimeWinsOverALapsedSubscription() async {
        let store = await launch()
        await store.subscribe()
        appStore.updateSubscription { $0.state = .expired }
        await waitUntil { !store.access.isUnlocked }
        XCTAssertEqual(store.access, .notEntitled(lapsed: true))

        await store.buyLifetime()
        XCTAssertEqual(store.access, .lifetime)
        XCTAssertEqual(store.owned.subscription?.state, .expired)
    }

    func testSubscriberWhoBuysLifetimeKeepsItWhenTheSubscriptionLapses() async {
        let store = await launch()
        await store.subscribe()
        await store.buyLifetime()
        XCTAssertEqual(store.access, .lifetime)
        // Settings uses this to warn that the subscription still renews.
        XCTAssertEqual(store.owned.subscription?.isActive, true)
        XCTAssertEqual(store.owned.subscription?.willAutoRenew, true)

        appStore.updateSubscription { $0.state = .expired }
        await waitUntil { store.owned.subscription?.state == .expired }
        XCTAssertEqual(store.access, .lifetime)
    }

    func testAskToBuyStaysPendingThenUnlocksWhenApproved() async {
        let store = await launch()
        appStore.setNextPurchaseOutcome(.success(.pending))
        await store.buyLifetime()
        XCTAssertEqual(store.access, .notEntitled(lapsed: false))
        XCTAssertEqual(store.notice, .pendingApproval)

        // Approval arrives later through the update stream, with no tap.
        appStore.grantLifetimeFromElsewhere()
        await waitUntil { store.access == .lifetime }
        XCTAssertEqual(store.access, .lifetime)
        XCTAssertNil(store.notice, "the waiting message goes away once it is approved")
    }

    func testRefundTakesTheLifetimeAway() async {
        let store = await launch()
        await store.buyLifetime()
        appStore.revokeLifetime()
        await waitUntil { store.access != .lifetime }
        XCTAssertEqual(store.access, .notEntitled(lapsed: false))
    }

    // MARK: - Reinstall and restore

    func testReinstallKeepsWhatTheAccountOwns() async {
        let first = await launch()
        await first.subscribe()
        let second = await reinstall()
        XCTAssertTrue(second.access.isUnlocked)
        XCTAssertEqual(subscription(of: second)?.isInFreeTrial, true)

        await second.buyLifetime()
        let third = await reinstall()
        XCTAssertEqual(third.access, .lifetime)
    }

    func testRestoreFindsALifetimeTheDeviceHadNotSeen() async {
        let first = await launch()
        await first.buyLifetime()

        appStore.simulateInstallThatHasNotSynced()
        let second = await reinstall()
        XCTAssertEqual(second.access, .notEntitled(lapsed: false))

        await second.restore()
        XCTAssertEqual(second.access, .lifetime)
        XCTAssertNil(second.notice)
        XCTAssertNil(second.activity)
    }

    func testRestoreFindsARunningSubscription() async {
        let first = await launch()
        await first.subscribe()

        appStore.simulateInstallThatHasNotSynced()
        let second = await reinstall()
        await second.restore()
        XCTAssertTrue(second.access.isUnlocked)
        XCTAssertNil(second.notice)
    }

    func testRestoreWithNothingToRestoreSaysSo() async {
        let store = await launch()
        await store.restore()
        XCTAssertEqual(store.access, .notEntitled(lapsed: false))
        XCTAssertEqual(store.notice, .nothingToRestore)
    }

    func testRestoreFailureShowsANotice() async {
        let store = await launch()
        appStore.setRestoreResult(.failure(FakeAppStore.Failure()))
        await store.restore()
        XCTAssertEqual(store.notice, .restoreFailed)
    }

    func testBackingOutOfRestoreSaysNothing() async {
        let store = await launch()
        appStore.setRestoreResult(.failure(CancellationError()))
        await store.restore()
        XCTAssertNil(store.notice)
    }

    // MARK: - Free key presses

    func testTheAllowanceIsTenKeyPresses() {
        XCTAssertEqual(FreePreview.keyPressAllowance, 10)
    }

    func testFreeKeyPressesThenThePaywallIsRequested() async {
        let store = await launch()
        XCTAssertEqual(store.freeKeyPressesLeft, 10)

        XCTAssertEqual(press(10, on: store), 10, "the first ten go to the TV")
        XCTAssertEqual(store.freeKeyPressesLeft, 0)
        XCTAssertFalse(store.paywallRequested, "not before a press is actually refused")

        XCTAssertFalse(store.mayPress(), "the eleventh is refused")
        XCTAssertTrue(store.paywallRequested)
        XCTAssertEqual(store.freeKeyPressesUsed, 10)
    }

    func testOnlyKeyPressesTheRokuAcceptedCount() async {
        let store = await launch()
        // Allowed, but the Roku never answered: nothing is used up.
        for _ in 0..<25 { XCTAssertTrue(store.mayPress()) }
        XCTAssertEqual(store.freeKeyPressesLeft, 10)
        XCTAssertFalse(store.paywallRequested)
    }

    func testSubscribersAndLifetimeOwnersAreNeverLimited() async {
        let store = await launch()
        press(4, on: store)
        await store.subscribe()

        XCTAssertEqual(press(200, on: store), 200)
        XCTAssertEqual(store.freeKeyPressesUsed, 4, "paid use does not eat the free presses")
        XCTAssertFalse(store.paywallRequested)

        await store.buyLifetime()
        XCTAssertEqual(press(200, on: store), 200)
        XCTAssertEqual(store.freeKeyPressesUsed, 4)
    }

    func testUsedKeyPressesSurviveARelaunch() async {
        let first = await launch()
        press(7, on: first)

        let relaunched = await launch()
        XCTAssertEqual(relaunched.freeKeyPressesLeft, 3)
        XCTAssertEqual(press(10, on: relaunched), 3)
        XCTAssertTrue(relaunched.paywallRequested)
    }

    func testExpiredSubscriptionBringsThePaywallBack() async {
        let store = await launch()
        press(10, on: store)
        XCTAssertFalse(store.mayPress())
        XCTAssertTrue(store.paywallRequested)

        await store.subscribe()
        XCTAssertFalse(store.paywallRequested, "unlocking clears the request")
        XCTAssertEqual(press(30, on: store), 30)

        appStore.updateSubscription { $0.state = .expired }
        await waitUntil { !store.access.isUnlocked }
        XCTAssertFalse(store.mayPress())
        XCTAssertTrue(store.paywallRequested)

        await store.buyLifetime()
        XCTAssertFalse(store.paywallRequested)
        XCTAssertTrue(store.mayPress())
    }

    func testKeyPressesAreNotHeldUpWhileStoreKitIsStillAnswering() {
        device.set(10, forKey: "freeKeyPressesUsed")
        let store = EntitlementStore(backend: appStore, defaults: device)
        XCTAssertEqual(store.access, .loading)
        XCTAssertTrue(store.mayPress())
        XCTAssertFalse(store.paywallRequested)
    }

    // MARK: - Products

    func testOfferUnavailableThenRetry() async {
        appStore.setOfferFailure(FakeAppStore.Failure())
        let store = await launch()
        XCTAssertEqual(store.offer, .unavailable, "never fall back to a hard-coded price")

        appStore.setOfferFailure(nil)
        appStore.setPrices(weekly: "6,99 €", lifetime: "24,99 €")
        await store.loadOffer()
        guard case .ready(let offer) = store.offer else { return XCTFail("offer not ready") }
        XCTAssertEqual(offer.weeklyPrice, "6,99 €")
        XCTAssertEqual(offer.lifetimePrice, "24,99 €")
    }
}
