import XCTest
@testable import RokuKit

final class SubnetMathTests: XCTestCase {
    // MARK: - IP ↔ UInt32 conversion

    func testToUInt32() {
        XCTAssertEqual(SubnetMath.toUInt32("192.168.1.10"), 0xC0A8_010A)
        XCTAssertEqual(SubnetMath.toUInt32("0.0.0.0"), 0)
        XCTAssertEqual(SubnetMath.toUInt32("255.255.255.255"), 0xFFFF_FFFF)
    }

    func testToUInt32RejectsMalformedInput() {
        XCTAssertNil(SubnetMath.toUInt32(""))
        XCTAssertNil(SubnetMath.toUInt32("192.168.1"))
        XCTAssertNil(SubnetMath.toUInt32("192.168.1.10.5"))
        XCTAssertNil(SubnetMath.toUInt32("192.168.1.256"))
        XCTAssertNil(SubnetMath.toUInt32("192.168.1.-1"))
        XCTAssertNil(SubnetMath.toUInt32("a.b.c.d"))
        XCTAssertNil(SubnetMath.toUInt32("192.168..1"))
    }

    func testRoundTrip() {
        for ip in ["10.0.0.1", "172.16.254.3", "192.168.1.134"] {
            XCTAssertEqual(SubnetMath.toString(SubnetMath.toUInt32(ip)!), ip)
        }
    }

    // MARK: - Host enumeration

    func testSlash24Yields253HostsExcludingSelfNetworkAndBroadcast() {
        let hosts = SubnetMath.hosts(address: "192.168.1.10", netmask: "255.255.255.0")
        XCTAssertEqual(hosts.count, 253) // 254 usable minus self
        XCTAssertFalse(hosts.contains("192.168.1.10"))  // self
        XCTAssertFalse(hosts.contains("192.168.1.0"))   // network
        XCTAssertFalse(hosts.contains("192.168.1.255")) // broadcast
        XCTAssertEqual(hosts.first, "192.168.1.1")
        XCTAssertEqual(hosts.last, "192.168.1.254")
    }

    func testSlash28SmallSubnet() {
        // 10.0.0.16/28 → usable .17–.30, minus self .20 → 13 hosts
        let hosts = SubnetMath.hosts(address: "10.0.0.20", netmask: "255.255.255.240")
        XCTAssertEqual(hosts.count, 13)
        XCTAssertEqual(hosts.first, "10.0.0.17")
        XCTAssertEqual(hosts.last, "10.0.0.30")
        XCTAssertFalse(hosts.contains("10.0.0.20"))
    }

    func testSlash16ClampsToSurroundingSlash24() {
        // 65534 hosts would be absurd on a phone — clamp to the /24 around us.
        let hosts = SubnetMath.hosts(address: "10.20.30.40", netmask: "255.255.0.0")
        XCTAssertEqual(hosts.count, 253)
        XCTAssertTrue(hosts.allSatisfy { $0.hasPrefix("10.20.30.") })
        XCTAssertFalse(hosts.contains("10.20.30.40"))
    }

    func testDegenerateMasksYieldNoHosts() {
        XCTAssertTrue(SubnetMath.hosts(address: "10.0.0.1", netmask: "255.255.255.255").isEmpty) // /32
        XCTAssertTrue(SubnetMath.hosts(address: "10.0.0.1", netmask: "255.255.255.254").isEmpty) // /31
        XCTAssertTrue(SubnetMath.hosts(address: "10.0.0.1", netmask: "0.0.0.0").isEmpty)
    }

    func testMalformedInputYieldsNoHosts() {
        XCTAssertTrue(SubnetMath.hosts(address: "banana", netmask: "255.255.255.0").isEmpty)
        XCTAssertTrue(SubnetMath.hosts(address: "10.0.0.1", netmask: "banana").isEmpty)
    }
}
