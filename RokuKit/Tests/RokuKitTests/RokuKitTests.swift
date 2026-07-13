import XCTest
@testable import RokuKit

/// Placeholder test — proves the package + CI pipeline work end-to-end.
/// Replaced by real ECP/discovery tests in Phase 1.
final class RokuKitTests: XCTestCase {
    func testPackageVersionIsSet() {
        XCTAssertFalse(RokuKit.version.isEmpty)
    }
}
