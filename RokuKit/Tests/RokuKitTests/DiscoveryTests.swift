import XCTest
@testable import RokuKit

final class DeviceDeduplicatorTests: XCTestCase {
    private func device(serial: String, ip: String = "10.0.0.1") -> RokuDevice {
        RokuDevice(serialNumber: serial, name: "Roku", ip: ip, isTV: false, model: "Test")
    }

    func testFirstInsertReturnsTrueDuplicateReturnsFalse() {
        var dedupe = DeviceDeduplicator()
        XCTAssertTrue(dedupe.insert(device(serial: "A")))
        XCTAssertFalse(dedupe.insert(device(serial: "A")))
        XCTAssertTrue(dedupe.insert(device(serial: "B")))
    }

    func testSameSerialDifferentIPIsStillADuplicate() {
        // SSDP and the subnet scan will find the same box at the same IP,
        // but identity is the serial — not the IP.
        var dedupe = DeviceDeduplicator()
        XCTAssertTrue(dedupe.insert(device(serial: "A", ip: "10.0.0.1")))
        XCTAssertFalse(dedupe.insert(device(serial: "A", ip: "10.0.0.99")))
    }
}

final class DiscoveryCoordinatorTests: XCTestCase {
    private func device(serial: String) -> RokuDevice {
        RokuDevice(serialNumber: serial, name: "Roku \(serial)", ip: "10.0.0.1",
                   isTV: false, model: "Test")
    }

    private func source(_ devices: [RokuDevice]) -> DiscoveryCoordinator.Source {
        { [devices] in
            AsyncStream { continuation in
                for d in devices { continuation.yield(d) }
                continuation.finish()
            }
        }
    }

    func testMergesSourcesAndDeduplicatesBySerial() async {
        let coordinator = DiscoveryCoordinator(sources: [
            source([device(serial: "A"), device(serial: "B")]), // "SSDP"
            source([device(serial: "B"), device(serial: "C"), device(serial: "A")]), // "scan"
        ])
        var found: [RokuDevice] = []
        for await d in coordinator.discover() {
            found.append(d)
        }
        XCTAssertEqual(Set(found.map(\.serialNumber)), ["A", "B", "C"])
        XCTAssertEqual(found.count, 3, "duplicates must be suppressed")
    }

    func testEmptySourcesFinishImmediately() async {
        let coordinator = DiscoveryCoordinator(sources: [source([]), source([])])
        var found: [RokuDevice] = []
        for await d in coordinator.discover() {
            found.append(d)
        }
        XCTAssertTrue(found.isEmpty)
    }

    func testSingleSourcePassesThrough() async {
        let coordinator = DiscoveryCoordinator(sources: [source([device(serial: "X")])])
        var found: [RokuDevice] = []
        for await d in coordinator.discover() {
            found.append(d)
        }
        XCTAssertEqual(found.map(\.serialNumber), ["X"])
    }
}

final class SSDPDiscovererDisabledTests: XCTestCase {
    func testDisabledDiscovererFinishesEmptyImmediately() async {
        // Default state: multicast entitlement not granted → stream must
        // finish empty (soft-fail), never hang.
        XCTAssertFalse(SSDPDiscoverer.isEnabled)
        var found: [RokuDevice] = []
        for await d in SSDPDiscoverer().discover() {
            found.append(d)
        }
        XCTAssertTrue(found.isEmpty)
    }
}

final class SystemNetworkInfoTests: XCTestCase {
    func testPrimaryIPv4IsWellFormedWhenPresent() {
        // CI runners have a network; but airplane-mode-like environments return
        // nil, which is also valid. We only assert well-formedness.
        guard let info = SystemNetworkInfo().primaryIPv4() else { return }
        XCTAssertNotNil(SubnetMath.toUInt32(info.address), "bad address: \(info.address)")
        XCTAssertNotNil(SubnetMath.toUInt32(info.netmask), "bad netmask: \(info.netmask)")
        XCTAssertFalse(info.address.hasPrefix("127."), "loopback must be skipped")
    }
}

final class SubnetScannerTests: XCTestCase {
    private struct NoNetwork: LocalNetworkInfoProviding {
        func primaryIPv4() -> (address: String, netmask: String)? { nil }
    }

    func testNoNetworkFinishesEmptyImmediately() async {
        let scanner = SubnetScanner(networkInfo: NoNetwork())
        var found: [RokuDevice] = []
        for await d in scanner.scan() {
            found.append(d)
        }
        XCTAssertTrue(found.isEmpty)
    }

    private struct TinySubnet: LocalNetworkInfoProviding {
        // /30: exactly one other host (10.0.0.2 from 10.0.0.1's view)
        func primaryIPv4() -> (address: String, netmask: String)? {
            ("10.0.0.1", "255.255.255.252")
        }
    }

    func testScannerProbesHostsAndYieldsRokus() async {
        MockURLProtocol.reset()
        MockURLProtocol.handler = { request in
            (200, Fixtures.tvDeviceInfoData)
        }
        defer { MockURLProtocol.reset() }

        let client = ECPClient(session: ECPClient.makeSession(
            timeout: 1, protocolClasses: [MockURLProtocol.self]
        ))
        let scanner = SubnetScanner(client: client, networkInfo: TinySubnet())
        var found: [RokuDevice] = []
        for await d in scanner.scan() {
            found.append(d)
        }
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found[0].ip, "10.0.0.2")
        XCTAssertEqual(found[0].serialNumber, "YN00H5555555")
        XCTAssertEqual(
            MockURLProtocol.recordedRequests.compactMap { $0.url?.host },
            ["10.0.0.2"]
        )
    }
}
