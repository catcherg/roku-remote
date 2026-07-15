import XCTest
@testable import RokuKit

final class ECPClientTests: XCTestCase {
    private var client: ECPClient!
    private let ip = "192.168.1.50"

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        client = ECPClient(session: ECPClient.makeSession(
            protocolClasses: [MockURLProtocol.self]
        ))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func lastRequest(file: StaticString = #filePath, line: UInt = #line) throws -> URLRequest {
        try XCTUnwrap(MockURLProtocol.recordedRequests.last, file: file, line: line)
    }

    // MARK: - Command paths & methods

    func testKeypressSendsPOSTToCorrectPath() async throws {
        MockURLProtocol.succeed()
        try await client.keypress(.home, ip: ip)
        let request = try lastRequest()
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "http://192.168.1.50:8060/keypress/Home")
    }

    func testKeydownAndKeyupPaths() async throws {
        MockURLProtocol.succeed()
        try await client.keydown(.volumeUp, ip: ip)
        XCTAssertEqual(try lastRequest().url?.path, "/keydown/VolumeUp")
        try await client.keyup(.volumeUp, ip: ip)
        XCTAssertEqual(try lastRequest().url?.path, "/keyup/VolumeUp")
        XCTAssertTrue(MockURLProtocol.recordedRequests.allSatisfy { $0.httpMethod == "POST" })
    }

    func testLaunchSendsPOSTWithAppID() async throws {
        MockURLProtocol.succeed()
        try await client.launch(appID: "12", ip: ip)
        let request = try lastRequest()
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "http://192.168.1.50:8060/launch/12")
    }

    func testEveryECPKeyRawValueBuildsAValidURL() async throws {
        MockURLProtocol.succeed()
        for key in ECPKey.allCases {
            try await client.keypress(key, ip: ip)
            XCTAssertEqual(try lastRequest().url?.path, "/keypress/\(key.rawValue)")
        }
        XCTAssertEqual(MockURLProtocol.recordedRequests.count, ECPKey.allCases.count)
    }

    // MARK: - Queries

    func testDeviceInfoParsesTVPayload() async throws {
        MockURLProtocol.succeed(with: Fixtures.tvDeviceInfoData)
        let info = try await client.deviceInfo(ip: ip)
        XCTAssertEqual(try lastRequest().httpMethod, "GET")
        XCTAssertEqual(try lastRequest().url?.path, "/query/device-info")
        XCTAssertEqual(info.serialNumber, "YN00H5555555")
        XCTAssertTrue(info.isTV)
    }

    func testAppsParsesChannelList() async throws {
        MockURLProtocol.succeed(with: Fixtures.appsData)
        let apps = try await client.apps(ip: ip)
        XCTAssertEqual(try lastRequest().url?.path, "/query/apps")
        XCTAssertEqual(apps.count, 4)
        XCTAssertEqual(apps.first, RokuApp(id: "12", name: "Netflix"))
    }

    func testIconFetchesPNGData() async throws {
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        MockURLProtocol.succeed(with: png)
        let data = try await client.icon(appID: "837", ip: ip)
        XCTAssertEqual(try lastRequest().url?.path, "/query/icon/837")
        XCTAssertEqual(data, png)
    }

    // MARK: - typeText / Lit_ encoding (roadmap: spaces, emoji, unicode)

    func testTypeTextSendsOneRequestPerCharacterInOrder() async throws {
        MockURLProtocol.succeed()
        try await client.typeText("hi 5", ip: ip)
        let paths = MockURLProtocol.recordedRequests.compactMap { $0.url?.absoluteString }
        XCTAssertEqual(paths, [
            "http://192.168.1.50:8060/keypress/Lit_h",
            "http://192.168.1.50:8060/keypress/Lit_i",
            "http://192.168.1.50:8060/keypress/Lit_%20",
            "http://192.168.1.50:8060/keypress/Lit_5",
        ])
        XCTAssertTrue(MockURLProtocol.recordedRequests.allSatisfy { $0.httpMethod == "POST" })
    }

    func testEncodeCharacterUnreservedPassThrough() {
        XCTAssertEqual(ECPClient.encode(character: "a"), "a")
        XCTAssertEqual(ECPClient.encode(character: "Z"), "Z")
        XCTAssertEqual(ECPClient.encode(character: "7"), "7")
        XCTAssertEqual(ECPClient.encode(character: "-"), "-")
        XCTAssertEqual(ECPClient.encode(character: "."), ".")
        XCTAssertEqual(ECPClient.encode(character: "_"), "_")
        XCTAssertEqual(ECPClient.encode(character: "~"), "~")
    }

    func testEncodeCharacterSpaceAndSymbols() {
        XCTAssertEqual(ECPClient.encode(character: " "), "%20")
        XCTAssertEqual(ECPClient.encode(character: "&"), "%26")
        XCTAssertEqual(ECPClient.encode(character: "/"), "%2F")
        XCTAssertEqual(ECPClient.encode(character: "+"), "%2B")
    }

    func testEncodeCharacterMultiByteUnicode() {
        XCTAssertEqual(ECPClient.encode(character: "é"), "%C3%A9")       // 2-byte UTF-8
        XCTAssertEqual(ECPClient.encode(character: "日"), "%E6%97%A5")   // 3-byte UTF-8
        XCTAssertEqual(ECPClient.encode(character: "😀"), "%F0%9F%98%80") // 4-byte UTF-8
    }

    func testTypeTextEmojiGoesOverTheWireEncoded() async throws {
        MockURLProtocol.succeed()
        try await client.typeText("😀", ip: ip)
        XCTAssertEqual(
            try lastRequest().url?.absoluteString,
            "http://192.168.1.50:8060/keypress/Lit_%F0%9F%98%80"
        )
    }

    // MARK: - Errors

    func testNon200ThrowsHTTPError() async {
        MockURLProtocol.fail(statusCode: 503)
        do {
            try await client.keypress(.home, ip: ip)
            XCTFail("expected throw")
        } catch let error as ECPError {
            XCTAssertEqual(error, .httpError(statusCode: 503))
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }

    func testGarbageDeviceInfoThrowsDecodingFailed() async {
        MockURLProtocol.succeed(with: Data("<html>not a roku</html>".utf8))
        do {
            _ = try await client.deviceInfo(ip: ip)
            XCTFail("expected throw")
        } catch let error as ECPError {
            XCTAssertEqual(error, .decodingFailed)
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }
}
