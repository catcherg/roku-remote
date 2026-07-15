import XCTest
@testable import RokuKit

final class DeviceInfoParsingTests: XCTestCase {
    func testParsesTVFixture() throws {
        let info = try DeviceInfo.parse(Fixtures.tvDeviceInfoData)
        XCTAssertEqual(info.serialNumber, "YN00H5555555")
        XCTAssertEqual(info.modelName, "65S455")
        XCTAssertEqual(info.friendlyName, "Living Room TV")
        XCTAssertTrue(info.isTV)
        XCTAssertEqual(info.powerMode, "PowerOn")
    }

    func testParsesStickFixtureFallsBackToDefaultName() throws {
        let info = try DeviceInfo.parse(Fixtures.stickDeviceInfoData)
        XCTAssertEqual(info.serialNumber, "X01000AAAAAA")
        XCTAssertFalse(info.isTV)
        // No friendly/user name in fixture → default-device-name wins.
        XCTAssertEqual(info.friendlyName, "Roku Express - X01000AAAAAA")
    }

    func testMissingSerialThrows() {
        let xml = Data("<device-info><model-name>Fake</model-name></device-info>".utf8)
        XCTAssertThrowsError(try DeviceInfo.parse(xml)) { error in
            XCTAssertEqual(error as? ECPError, .decodingFailed)
        }
    }

    func testNonXMLThrows() {
        XCTAssertThrowsError(try DeviceInfo.parse(Data("garbage".utf8)))
    }

    func testDeviceConversionCarriesIP() throws {
        let info = try DeviceInfo.parse(Fixtures.tvDeviceInfoData)
        let device = info.device(ip: "10.0.0.9")
        XCTAssertEqual(device.ip, "10.0.0.9")
        XCTAssertEqual(device.serialNumber, info.serialNumber)
        XCTAssertEqual(device.name, "Living Room TV")
        XCTAssertEqual(device.id, device.serialNumber)
        XCTAssertTrue(device.isTV)
    }
}

final class AppsParsingTests: XCTestCase {
    func testParsesAppsFixture() {
        let apps = AppsXMLParser.parse(Fixtures.appsData)
        XCTAssertEqual(apps.count, 4)
        XCTAssertEqual(apps[0], RokuApp(id: "12", name: "Netflix"))
        XCTAssertEqual(apps[1], RokuApp(id: "837", name: "YouTube"))
        XCTAssertEqual(apps[3].name, "Movie Store and TV Store")
    }

    func testEmptyAndGarbageInputYieldNoApps() {
        XCTAssertTrue(AppsXMLParser.parse(Data()).isEmpty)
        XCTAssertTrue(AppsXMLParser.parse(Data("not xml".utf8)).isEmpty)
        XCTAssertTrue(AppsXMLParser.parse(Data("<apps></apps>".utf8)).isEmpty)
    }

    func testAppMissingIDIsSkipped() {
        let xml = Data("<apps><app>NoID</app><app id=\"12\">Netflix</app></apps>".utf8)
        let apps = AppsXMLParser.parse(xml)
        XCTAssertEqual(apps, [RokuApp(id: "12", name: "Netflix")])
    }
}

final class SSDPParsingTests: XCTestCase {
    func testMSearchPayloadIsWellFormed() {
        let text = SSDP.mSearchString
        XCTAssertTrue(text.hasPrefix("M-SEARCH * HTTP/1.1\r\n"))
        XCTAssertTrue(text.contains("ST: roku:ecp\r\n"))
        XCTAssertTrue(text.contains("Man: \"ssdp:discover\"\r\n"))
        XCTAssertTrue(text.hasSuffix("\r\n\r\n"))
    }

    func testParsesLocationFromRealResponse() {
        XCTAssertEqual(SSDP.ip(fromResponse: Fixtures.ssdpResponse), "192.168.1.134")
    }

    func testLocationHeaderIsCaseInsensitive() {
        let response = "HTTP/1.1 200 OK\r\nLOCATION: http://10.1.1.2:8060/\r\n\r\n"
        XCTAssertEqual(SSDP.ip(fromResponse: response), "10.1.1.2")
    }

    func testMissingLocationReturnsNil() {
        XCTAssertNil(SSDP.ip(fromResponse: "HTTP/1.1 200 OK\r\nST: roku:ecp\r\n\r\n"))
        XCTAssertNil(SSDP.ip(fromResponse: ""))
    }

    func testMalformedLocationURLReturnsNil() {
        XCTAssertNil(SSDP.ip(fromLocation: ""))
        XCTAssertNil(SSDP.ip(fromLocation: "http://"))
    }
}
