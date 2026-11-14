import XCTest
@testable import Clicker

/// The entitlement rules as a pure function: what is owned → access.
final class EntitlementPolicyTests: XCTestCase {
    private let renewal = Date(timeIntervalSince1970: 1_800_000_000)

    private func subscription(_ state: SubscriptionRecord.State, trial: Bool = false,
                              willAutoRenew: Bool = true) -> SubscriptionRecord {
        SubscriptionRecord(state: state, isInFreeTrial: trial,
                           currentPeriodEnds: renewal, willAutoRenew: willAutoRenew)
    }

    private func access(lifetime: Bool = false, _ record: SubscriptionRecord? = nil) -> Access {
        EntitlementPolicy.access(for: OwnedPurchases(ownsLifetime: lifetime, subscription: record))
    }

    func testNoEntitlement() {
        XCTAssertEqual(access(), .notEntitled(lapsed: false))
        XCTAssertFalse(access().isUnlocked)
    }

    func testInFreeTrial() {
        let trial = subscription(.subscribed, trial: true)
        XCTAssertEqual(access(trial), .subscribed(trial))
        XCTAssertTrue(access(trial).isUnlocked)
    }

    func testSubscribed() {
        let paid = subscription(.subscribed)
        XCTAssertEqual(access(paid), .subscribed(paid))
        XCTAssertTrue(access(paid).isUnlocked)
        XCTAssertFalse(paid.hasBillingIssue)
    }

    func testCancelledButNotYetEndedIsStillUnlocked() {
        let cancelled = subscription(.subscribed, willAutoRenew: false)
        XCTAssertTrue(access(cancelled).isUnlocked)
    }

    func testGracePeriodStaysUnlocked() {
        let grace = subscription(.inGracePeriod)
        XCTAssertEqual(access(grace), .subscribed(grace))
        XCTAssertTrue(access(grace).isUnlocked)
        XCTAssertTrue(grace.hasBillingIssue)
    }

    func testBillingRetryStaysUnlocked() {
        let retry = subscription(.inBillingRetry)
        XCTAssertEqual(access(retry), .subscribed(retry))
        XCTAssertTrue(access(retry).isUnlocked)
        XCTAssertTrue(retry.hasBillingIssue)
    }

    func testExpiredSubscriptionIsNotEntitled() {
        XCTAssertEqual(access(subscription(.expired)), .notEntitled(lapsed: true))
        XCTAssertFalse(access(subscription(.expired)).isUnlocked)
    }

    func testRevokedSubscriptionIsNotEntitled() {
        XCTAssertEqual(access(subscription(.revoked)), .notEntitled(lapsed: true))
    }

    func testLifetime() {
        XCTAssertEqual(access(lifetime: true), .lifetime)
        XCTAssertTrue(access(lifetime: true).isUnlocked)
    }

    func testLifetimeWinsOverALapsedSubscription() {
        XCTAssertEqual(access(lifetime: true, subscription(.expired)), .lifetime)
        XCTAssertEqual(access(lifetime: true, subscription(.revoked)), .lifetime)
    }

    func testLifetimeWinsOverARunningSubscriptionToo() {
        XCTAssertEqual(access(lifetime: true, subscription(.subscribed)), .lifetime)
        XCTAssertEqual(access(lifetime: true, subscription(.inBillingRetry)), .lifetime)
    }

    func testLoadingIsNotUnlocked() {
        XCTAssertFalse(Access.loading.isUnlocked)
    }

    func testProductIdentifiers() {
        XCTAssertEqual(PurchaseProduct.weekly.rawValue, "com.catchergriffin.clicker.weekly")
        XCTAssertEqual(PurchaseProduct.lifetime.rawValue, "com.catchergriffin.clicker.unlock")
    }
}

/// The plans screen wording, which must be built from the store's own values.
final class PlanCopyTests: XCTestCase {
    private func offer(trial: BillingPeriod? = BillingPeriod(value: 3, unit: .day),
                       weekly: String = "$6.99", lifetime: String = "$24.99",
                       familyShareable: Bool = true) -> PurchaseOffer {
        PurchaseOffer(weeklyPrice: weekly, weeklyPeriod: BillingPeriod(value: 1, unit: .week),
                      freeTrial: trial, lifetimePrice: lifetime,
                      lifetimeIsFamilyShareable: familyShareable)
    }

    func testWeeklyStatesTheTrialThePriceAndThePeriod() {
        XCTAssertEqual(PlanCopy.weeklyPrice(offer()), "3-day free trial, then $6.99 per week")
        XCTAssertEqual(PlanCopy.weeklyDetail(offer()), "Renews automatically every week until you cancel.")
        XCTAssertEqual(PlanCopy.buttonTitle(for: .weekly, offer: offer()), "Start 3-Day Free Trial")
    }

    func testNoTrialIsPromisedWhenTheAccountHasNone() {
        let used = offer(trial: nil)
        XCTAssertEqual(PlanCopy.weeklyPrice(used), "$6.99 per week")
        XCTAssertEqual(PlanCopy.buttonTitle(for: .weekly, offer: used), "Subscribe for $6.99 per week")
        XCTAssertFalse(PlanCopy.disclosure(for: .weekly, offer: used).lowercased().contains("trial"))
    }

    func testWeeklyDisclosureSaysItRenewsUntilCancelled() {
        let text = PlanCopy.disclosure(for: .weekly, offer: offer())
        XCTAssertTrue(text.contains("The free trial lasts 3 days."))
        XCTAssertTrue(text.contains("renews automatically at $6.99 per week until you cancel"))
    }

    func testLifetimeIsOnePaymentThatNeverRenews() {
        XCTAssertEqual(PlanCopy.lifetimePrice(offer()), "$24.99 once")
        XCTAssertEqual(PlanCopy.buttonTitle(for: .lifetime, offer: offer()), "Buy Lifetime for $24.99")
        XCTAssertTrue(PlanCopy.disclosure(for: .lifetime, offer: offer()).contains("never renews"))
        XCTAssertTrue(PlanCopy.lifetimeDetail(offer()).contains("Family Sharing"))
        XCTAssertFalse(PlanCopy.lifetimeDetail(offer(familyShareable: false)).contains("Family Sharing"))
    }

    func testPricesAndPeriodsAreWhateverTheStoreSays() {
        let other = PurchaseOffer(weeklyPrice: "6,99 €", weeklyPeriod: BillingPeriod(value: 1, unit: .month),
                                  freeTrial: BillingPeriod(value: 1, unit: .week),
                                  lifetimePrice: "29,99 €", lifetimeIsFamilyShareable: false)
        XCTAssertEqual(PlanCopy.weeklyPrice(other), "1-week free trial, then 6,99 € per month")
        XCTAssertEqual(PlanCopy.buttonTitle(for: .lifetime, offer: other), "Buy Lifetime for 29,99 €")
        XCTAssertTrue(PlanCopy.disclosure(for: .weekly, offer: other).contains("The free trial lasts 1 week."))
    }

    func testSevenDaysReadsAsAWeek() {
        XCTAssertEqual(BillingPeriod(value: 7, unit: .day), BillingPeriod(value: 1, unit: .week))
        XCTAssertEqual(BillingPeriod(value: 14, unit: .day).perText, "2 weeks")
        XCTAssertEqual(BillingPeriod(value: 3, unit: .day).adjective, "3-day")
    }
}
