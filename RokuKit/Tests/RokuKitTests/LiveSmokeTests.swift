import XCTest
@testable import RokuKit

/// Manual smoke test against REAL hardware (roadmap Phase 1 task 8).
/// Skipped everywhere unless ROKU_TEST_IP is set — never runs in CI.
///
/// Usage (find the IP on the Roku: Settings → Network → About):
///
///     cd RokuKit
///     ROKU_TEST_IP=192.168.1.134 swift test --filter LiveSmokeTests
///
/// Add ROKU_SMOKE_FULL=1 to also press keys / launch a channel / type text
/// on the device (visible on the TV — expect it to react!).
final class LiveSmokeTests: XCTestCase {
    private var ip: String!
    private let client = ECPClient()

    override func setUpWithError() throws {
        ip = ProcessInfo.processInfo.environment["ROKU_TEST_IP"]
        try XCTSkipIf(ip == nil, "set ROKU_TEST_IP to run live smoke tests")
    }

    func testDeviceInfo() async throws {
        let info = try await client.deviceInfo(ip: ip)
        XCTAssertFalse(info.serialNumber.isEmpty)
        print("SMOKE ▸ \(info.friendlyName) — model \(info.modelName), isTV=\(info.isTV), power=\(info.powerMode ?? "?")")
    }

    func testAppsAndIcon() async throws {
        let apps = try await client.apps(ip: ip)
        XCTAssertFalse(apps.isEmpty)
        print("SMOKE ▸ \(apps.count) channels: \(apps.prefix(5).map(\.name).joined(separator: ", "))…")
        let icon = try await client.icon(appID: apps[0].id, ip: ip)
        XCTAssertFalse(icon.isEmpty)
    }

    func testSubnetScanFindsTheRoku() async throws {
        let start = Date()
        var serials: [String] = []
        for await device in SubnetScanner().scan() {
            print("SMOKE ▸ found \(device.name) @ \(device.ip) in \(String(format: "%.1f", Date().timeIntervalSince(start)))s")
            serials.append(device.serialNumber)
        }
        let elapsed = Date().timeIntervalSince(start)
        print("SMOKE ▸ scan completed in \(String(format: "%.1f", elapsed))s")
        XCTAssertFalse(serials.isEmpty, "scan must find the Roku at \(ip!)")
        XCTAssertLessThan(elapsed, 10, "DoD: discovery <10s via scan")
    }

    func testFullControl() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["ROKU_SMOKE_FULL"] == nil,
                      "set ROKU_SMOKE_FULL=1 to send visible commands to the device")
        // Wake/verify with Home, navigate, open the keyboard-friendly search, type.
        try await client.keypress(.home, ip: ip)
        try await Task.sleep(nanoseconds: 1_500_000_000)
        try await client.keypress(.down, ip: ip)
        try await client.keypress(.up, ip: ip)
        try await client.keypress(.search, ip: ip)
        try await Task.sleep(nanoseconds: 1_500_000_000)
        try await client.typeText("roku test 😀", ip: ip)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        try await client.keypress(.back, ip: ip)
        try await client.keypress(.home, ip: ip)
        // Launch a channel (first in the list) and come home again.
        let apps = try await client.apps(ip: ip)
        if let first = apps.first {
            try await client.launch(appID: first.id, ip: ip)
            try await Task.sleep(nanoseconds: 3_000_000_000)
            try await client.keypress(.home, ip: ip)
        }
    }
}
