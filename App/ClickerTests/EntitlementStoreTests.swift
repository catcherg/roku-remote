import XCTest
@testable import Clicker

/// EntitlementStore against an in-memory App Store and a movable clock.
@MainActor
final class EntitlementStoreTests: XCTestCase {
    private var clock: TestClock!
    private var appStore: FakeAppStore!

    override func setUp() {
        super.setUp()
        clock = TestClock()
        appStore = FakeAppStore(clock: clock)
    }

    /// A new store is a new install: it has nothing but the App Store to ask.
    private func install() async -> EntitlementStore {
        let store = EntitlementStore(backend: appStore, now: { [clock] in clock!.now })
        await store.load()
        return store
    }

    private func waitUntil(_ condition: () -> Bool, timeout: TimeInterval = 2) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    // MARK: - First launch

    func testIsLoadingUntilStoreKitAnswers() {
        let store = EntitlementStore(backend: appStore, now: { [clock] in clock!.now })
        XCTAssertEqual(store.access, .loading)
        XCTAssertEqual(store.offer, .loading)
        XCTAssertNil(store.unlockPrice)
    }

    func testFirstLaunchNeedsTrialAndKnowsThePrice() async {
        let store = await install()
        XCTAssertEqual(store.access, .needsTrial)
        XCTAssertEqual(store.unlockPrice, "$4.99")
        XCTAssertNil(store.notice)
    }

    // MARK: - Trial

    func testStartingTheTrialGivesSevenDays() async {
        let store = await install()
        await store.startTrial()
        XCTAssertEqual(store.access, .trial(daysRemaining: 7))
        XCTAssertNil(store.activity)
        XCTAssertNil(store.notice)
    }

    func testDaysLeftCountDownAndThenTheTrialExpires() async {
        let store = await install()
        await store.startTrial()

        clock.advance(days: 2)
        store.reevaluate()
        XCTAssertEqual(store.access, .trial(daysRemaining: 5))

        clock.advance(days: 4.9)
        store.reevaluate()
        XCTAssertEqual(store.access, .trial(daysRemaining: 1))

        clock.advance(days: 0.1)
        store.reevaluate()
        XCTAssertEqual(store.access, .expired)
        XCTAssertFalse(store.access.allowsRemote)
    }

    func testCancellingTheTrialSheetChangesNothing() async {
        let store = await install()
        appStore.setNextPurchaseOutcome(.success(.cancelled))
        await store.startTrial()
        XCTAssertEqual(store.access, .needsTrial)
        XCTAssertNil(store.notice)
    }

    // MARK: - Unlock

    func testUnlockingAfterTheTrialExpired() async {
        let store = await install()
        await store.startTrial()
        clock.advance(days: 8)
        store.reevaluate()
        XCTAssertEqual(store.access, .expired)

        await store.unlock()
        XCTAssertEqual(store.access, .unlocked)

        clock.advance(days: 3650)
        store.reevaluate()
        XCTAssertEqual(store.access, .unlocked, "one price, forever")
    }

    func testUnlockingEarlyDuringTheTrial() async {
        let store = await install()
        await store.startTrial()
        clock.advance(days: 1)
        await store.unlock()
        XCTAssertEqual(store.access, .unlocked)
    }

    func testFailedPurchaseShowsANoticeAndStaysLocked() async {
        let store = await install()
        await store.startTrial()
        clock.advance(days: 8)
        store.reevaluate()

        appStore.setNextPurchaseOutcome(.failure(FakeAppStore.Failure()))
        await store.unlock()
        XCTAssertEqual(store.access, .expired)
        XCTAssertEqual(store.notice, .purchaseFailed)

        // The next attempt clears the notice.
        appStore.setNextPurchaseOutcome(.success(.purchased))
        await store.unlock()
        XCTAssertEqual(store.access, .unlocked)
        XCTAssertNil(store.notice)
    }

    func testAskToBuyStaysPendingThenUnlocksWhenApproved() async {
        let store = await install()
        await store.startTrial()
        clock.advance(days: 8)
        store.reevaluate()

        appStore.setNextPurchaseOutcome(.success(.pending))
        await store.unlock()
        XCTAssertEqual(store.access, .expired)
        XCTAssertEqual(store.notice, .pendingApproval)

        // Approval arrives later through Transaction.updates, with no tap.
        appStore.grantUnlockFromElsewhere()
        await waitUntil { store.access == .unlocked }
        XCTAssertEqual(store.access, .unlocked)
        XCTAssertNil(store.notice, "the waiting message goes away once it is approved")
    }

    func testFamilySharedUnlockArrivesWithoutAnyAction() async {
        let store = await install()
        XCTAssertEqual(store.access, .needsTrial)
        appStore.grantUnlockFromElsewhere()
        await waitUntil { store.access == .unlocked }
        XCTAssertEqual(store.access, .unlocked)
    }

    func testRefundTakesTheUnlockAway() async {
        let store = await install()
        await store.startTrial()
        clock.advance(days: 30)
        await store.unlock()
        XCTAssertEqual(store.access, .unlocked)

        appStore.revokeUnlock()
        await waitUntil { store.access == .expired }
        XCTAssertEqual(store.access, .expired)
    }

    // MARK: - Reinstall

    func testReinstallKeepsTheOriginalTrialStart() async {
        let firstInstall = await install()
        await firstInstall.startTrial()
        XCTAssertEqual(firstInstall.access, .trial(daysRemaining: 7))

        // Five days later: delete the app, install it again.
        clock.advance(days: 5)
        let secondInstall = await install()
        XCTAssertEqual(secondInstall.access, .trial(daysRemaining: 2),
                       "the trial clock comes from the App Store, not from the device")

        // Three more days and another reinstall: the trial is simply over.
        clock.advance(days: 3)
        let thirdInstall = await install()
        XCTAssertEqual(thirdInstall.access, .expired)
    }

    func testStartingTheTrialAgainDoesNotResetTheClock() async {
        let firstInstall = await install()
        await firstInstall.startTrial()
        clock.advance(days: 10)

        // A fresh install whose StoreKit cache is still empty looks like a new
        // user, so it offers the trial…
        appStore.simulateInstallThatHasNotSynced()
        let reinstall = await install()
        XCTAssertEqual(reinstall.access, .needsTrial)

        // …but the App Store hands back the original trial transaction.
        await reinstall.startTrial()
        XCTAssertEqual(reinstall.access, .expired)
    }

    func testReinstallKeepsTheUnlock() async {
        let firstInstall = await install()
        await firstInstall.startTrial()
        await firstInstall.unlock()

        clock.advance(days: 400)
        let reinstall = await install()
        XCTAssertEqual(reinstall.access, .unlocked)
    }

    // MARK: - Restore

    func testRestoreFindsAnUnlockTheDeviceHadNotSeen() async {
        let firstInstall = await install()
        await firstInstall.startTrial()
        await firstInstall.unlock()

        appStore.simulateInstallThatHasNotSynced()
        let reinstall = await install()
        XCTAssertEqual(reinstall.access, .needsTrial)

        await reinstall.restore()
        XCTAssertEqual(reinstall.access, .unlocked)
        XCTAssertNil(reinstall.notice)
        XCTAssertNil(reinstall.activity)
    }

    func testRestoreWithNothingToRestoreSaysSo() async {
        let store = await install()
        await store.startTrial()
        clock.advance(days: 8)
        store.reevaluate()

        await store.restore()
        XCTAssertEqual(store.access, .expired)
        XCTAssertEqual(store.notice, .nothingToRestore)
    }

    func testRestoreThatRevealsARunningTrialDoesNotClaimNothingWasFound() async {
        let firstInstall = await install()
        await firstInstall.startTrial()
        clock.advance(days: 2)

        appStore.simulateInstallThatHasNotSynced()
        let reinstall = await install()
        XCTAssertEqual(reinstall.access, .needsTrial)

        await reinstall.restore()
        XCTAssertEqual(reinstall.access, .trial(daysRemaining: 5))
        XCTAssertNil(reinstall.notice)
    }

    func testRestoreFailureShowsANotice() async {
        let store = await install()
        appStore.setRestoreResult(.failure(FakeAppStore.Failure()))
        await store.restore()
        XCTAssertEqual(store.notice, .restoreFailed)
        XCTAssertEqual(store.access, .needsTrial)
    }

    func testBackingOutOfRestoreSaysNothing() async {
        let store = await install()
        appStore.setRestoreResult(.failure(CancellationError()))
        await store.restore()
        XCTAssertNil(store.notice)
    }

    // MARK: - Products

    func testOfferUnavailableThenRetry() async {
        appStore.setOfferResult(.failure(FakeAppStore.Failure()))
        let store = await install()
        XCTAssertEqual(store.offer, .unavailable)
        XCTAssertNil(store.unlockPrice, "never fall back to a hard-coded price")

        appStore.setOfferResult(.success(PurchaseOffer(unlockPrice: "4,99 €",
                                                       unlockIsFamilyShareable: true)))
        await store.loadOffer()
        XCTAssertEqual(store.unlockPrice, "4,99 €")
    }
}
