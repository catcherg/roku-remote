import XCTest
@testable import RokuKit

final class SavedDeviceStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: SavedDeviceStore!
    private let suiteName = "rokukit.tests.\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        store = SavedDeviceStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func device(serial: String = "SN1", name: String = "Living Room TV",
                        ip: String = "192.168.1.134") -> RokuDevice {
        RokuDevice(serialNumber: serial, name: name, ip: ip, isTV: true, model: "65S455")
    }

    func testEmptyStore() {
        XCTAssertTrue(store.devices.isEmpty)
        XCTAssertNil(store.lastConnected)
    }

    func testSaveAndLoadRoundTrip() {
        let d = device()
        store.save(d)
        XCTAssertEqual(store.devices, [d])
    }

    func testSaveSameSerialUpserts() {
        store.save(device(ip: "192.168.1.134"))
        store.save(device(ip: "192.168.1.200")) // DHCP moved it
        XCTAssertEqual(store.devices.count, 1)
        XCTAssertEqual(store.devices[0].ip, "192.168.1.200")
    }

    func testMultipleDevicesPreserveOrder() {
        store.save(device(serial: "A"))
        store.save(device(serial: "B"))
        store.save(device(serial: "A", name: "Renamed")) // update keeps position
        XCTAssertEqual(store.devices.map(\.serialNumber), ["A", "B"])
        XCTAssertEqual(store.devices[0].name, "Renamed")
    }

    func testLastConnected() {
        let d = device()
        store.setLastConnected(d)
        XCTAssertEqual(store.lastConnected, d)
        XCTAssertEqual(store.devices, [d], "setLastConnected must also save the device")
    }

    func testForgetRemovesDeviceAndLastConnected() {
        let d = device()
        store.setLastConnected(d)
        store.forget(serial: d.serialNumber)
        XCTAssertTrue(store.devices.isEmpty)
        XCTAssertNil(store.lastConnected)
    }

    func testForgetOtherDeviceKeepsLastConnected() {
        let a = device(serial: "A")
        let b = device(serial: "B")
        store.setLastConnected(a)
        store.save(b)
        store.forget(serial: "B")
        XCTAssertEqual(store.lastConnected, a)
    }

    func testRename() {
        store.save(device())
        store.rename(serial: "SN1", to: "Bedroom TV")
        XCTAssertEqual(store.devices[0].name, "Bedroom TV")
    }

    func testUpdateIP() {
        store.save(device())
        store.updateIP(serial: "SN1", ip: "10.0.0.5")
        XCTAssertEqual(store.devices[0].ip, "10.0.0.5")
    }

    func testRenameUnknownSerialIsNoOp() {
        store.save(device())
        store.rename(serial: "NOPE", to: "X")
        XCTAssertEqual(store.devices[0].name, "Living Room TV")
    }

    func testCorruptDataYieldsEmptyList() {
        defaults.set(Data("corrupt".utf8), forKey: "rokukit.savedDevices")
        XCTAssertTrue(store.devices.isEmpty)
    }
}
