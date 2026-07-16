import XCTest
@testable import RokuKit

final class ConnectionStateTests: XCTestCase {
    private let device = RokuDevice(serialNumber: "SN", name: "TV", ip: "10.0.0.2",
                                    isTV: true, model: "Test")

    func testDeviceAccessor() {
        XCTAssertNil(ConnectionState.disconnected.device)
        XCTAssertNil(ConnectionState.discovering.device)
        XCTAssertEqual(ConnectionState.connected(device).device, device)
        XCTAssertEqual(ConnectionState.unreachable(device).device, device)
    }

    func testIsConnected() {
        XCTAssertTrue(ConnectionState.connected(device).isConnected)
        XCTAssertFalse(ConnectionState.disconnected.isConnected)
        XCTAssertFalse(ConnectionState.discovering.isConnected)
        XCTAssertFalse(ConnectionState.unreachable(device).isConnected)
    }

    func testEquatableDistinguishesDevices() {
        let other = RokuDevice(serialNumber: "OTHER", name: "TV2", ip: "10.0.0.3",
                               isTV: false, model: "Test")
        XCTAssertEqual(ConnectionState.connected(device), .connected(device))
        XCTAssertNotEqual(ConnectionState.connected(device), .connected(other))
        XCTAssertNotEqual(ConnectionState.connected(device), .unreachable(device))
    }
}

final class ConsecutiveFailureTrackerTests: XCTestCase {
    func testThresholdCrossing() {
        var tracker = ConsecutiveFailureTracker(threshold: 3)
        XCTAssertFalse(tracker.recordFailure()) // 1
        XCTAssertFalse(tracker.recordFailure()) // 2
        XCTAssertTrue(tracker.recordFailure())  // 3 — react now
        XCTAssertTrue(tracker.recordFailure())  // 4 — still bad
        XCTAssertTrue(tracker.hasCrossedThreshold)
    }

    func testSuccessResetsStreak() {
        var tracker = ConsecutiveFailureTracker(threshold: 3)
        tracker.recordFailure()
        tracker.recordFailure()
        tracker.recordSuccess()
        XCTAssertEqual(tracker.count, 0)
        XCTAssertFalse(tracker.recordFailure(), "streak must restart after success")
    }

    func testIntermittentFailuresNeverSurface() {
        // The optimistic-UI contract: flaky-but-working never shows a banner.
        var tracker = ConsecutiveFailureTracker(threshold: 3)
        for _ in 0..<10 {
            XCTAssertFalse(tracker.recordFailure())
            XCTAssertFalse(tracker.recordFailure())
            tracker.recordSuccess()
        }
    }

    func testThresholdFloorIsOne() {
        var tracker = ConsecutiveFailureTracker(threshold: 0)
        XCTAssertTrue(tracker.recordFailure())
    }
}
