import XCTest
@testable import Clicker

/// The trial rules as pure functions: what is owned + what time it is → access.
final class TrialPolicyTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    private func access(trialStartedAt: Date? = nil, unlocked: Bool = false,
                        afterDays days: Double) -> Access {
        TrialPolicy.access(
            for: OwnedPurchases(trialStartedAt: trialStartedAt, isUnlocked: unlocked),
            now: start.addingTimeInterval(days * day)
        )
    }

    func testTrialIsSevenDays() {
        XCTAssertEqual(TrialPolicy.lengthInDays, 7)
        XCTAssertEqual(TrialPolicy.endDate(startedAt: start), start.addingTimeInterval(7 * day))
    }

    func testNothingOwnedNeedsTrial() {
        XCTAssertEqual(access(afterDays: 0), .needsTrial)
        XCTAssertEqual(access(afterDays: 400), .needsTrial)
    }

    func testTrialActiveCountsDaysRoundedUp() {
        XCTAssertEqual(access(trialStartedAt: start, afterDays: 0), .trial(daysRemaining: 7))
        XCTAssertEqual(access(trialStartedAt: start, afterDays: 0.5), .trial(daysRemaining: 7))
        XCTAssertEqual(access(trialStartedAt: start, afterDays: 1), .trial(daysRemaining: 6))
        XCTAssertEqual(access(trialStartedAt: start, afterDays: 2.5), .trial(daysRemaining: 5))
        XCTAssertEqual(access(trialStartedAt: start, afterDays: 6), .trial(daysRemaining: 1))
        // One second before the end still counts as the last day.
        XCTAssertEqual(access(trialStartedAt: start, afterDays: 7 - 1 / day), .trial(daysRemaining: 1))
    }

    func testTrialExpiresAtSevenDays() {
        XCTAssertEqual(access(trialStartedAt: start, afterDays: 7), .expired)
        XCTAssertEqual(access(trialStartedAt: start, afterDays: 7.01), .expired)
        XCTAssertEqual(access(trialStartedAt: start, afterDays: 365), .expired)
    }

    func testUnlockedWinsOverEverything() {
        XCTAssertEqual(access(unlocked: true, afterDays: 0), .unlocked)
        XCTAssertEqual(access(trialStartedAt: start, unlocked: true, afterDays: 3), .unlocked)
        XCTAssertEqual(access(trialStartedAt: start, unlocked: true, afterDays: 3650), .unlocked)
    }

    func testClockBehindPurchaseDateNeverShowsMoreThanSevenDays() {
        XCTAssertEqual(access(trialStartedAt: start, afterDays: -30), .trial(daysRemaining: 7))
    }

    func testOnlyTrialAndUnlockedAllowTheRemote() {
        XCTAssertTrue(Access.trial(daysRemaining: 1).allowsRemote)
        XCTAssertTrue(Access.unlocked.allowsRemote)
        XCTAssertFalse(Access.loading.allowsRemote)
        XCTAssertFalse(Access.needsTrial.allowsRemote)
        XCTAssertFalse(Access.expired.allowsRemote)
    }

    func testNextChangeIsTheNextDayBoundaryOrTheEnd() {
        func seconds(afterDays days: Double, unlocked: Bool = false) -> TimeInterval? {
            TrialPolicy.secondsUntilNextChange(
                for: OwnedPurchases(trialStartedAt: start, isUnlocked: unlocked),
                now: start.addingTimeInterval(days * day)
            )
        }
        XCTAssertEqual(seconds(afterDays: 0) ?? -1, day, accuracy: 0.001)
        XCTAssertEqual(seconds(afterDays: 0.25) ?? -1, 0.75 * day, accuracy: 0.001)
        XCTAssertEqual(seconds(afterDays: 6.5) ?? -1, 0.5 * day, accuracy: 0.001)
        XCTAssertNil(seconds(afterDays: 7))
        XCTAssertNil(seconds(afterDays: 2, unlocked: true))
        XCTAssertNil(TrialPolicy.secondsUntilNextChange(for: OwnedPurchases(), now: start))
    }

    func testProductIdentifiers() {
        XCTAssertEqual(PurchaseProduct.trial.rawValue, "com.catchergriffin.clicker.trial")
        XCTAssertEqual(PurchaseProduct.unlock.rawValue, "com.catchergriffin.clicker.unlock")
    }
}
