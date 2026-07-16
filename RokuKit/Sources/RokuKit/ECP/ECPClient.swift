import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum ECPError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingFailed
}

/// All ECP HTTP commands. Fire-and-forget semantics: success == HTTP 2xx, empty body.
/// 2s timeout, no retries at this layer (per CLAUDE.md / roadmap §1.1).
///
/// @unchecked Sendable: immutable struct whose only stored property is a
/// URLSession, which is documented thread-safe.
public struct ECPClient: @unchecked Sendable {
    public static let port = 8060
    private let session: URLSession

    public init(session: URLSession = ECPClient.makeSession()) {
        self.session = session
    }

    /// Session factory. `timeout` 2s for commands; discovery probes pass 1s.
    /// `protocolClasses` lets tests inject a mock URLProtocol.
    public static func makeSession(timeout: TimeInterval = 2,
                                   protocolClasses: [AnyClass]? = nil) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.waitsForConnectivity = false
        if let protocolClasses {
            config.protocolClasses = protocolClasses
        }
        return URLSession(configuration: config)
    }

    // MARK: - Queries

    public func deviceInfo(ip: String) async throws -> DeviceInfo {
        try DeviceInfo.parse(await request(ip: ip, path: "/query/device-info", method: "GET"))
    }

    public func apps(ip: String) async throws -> [RokuApp] {
        AppsXMLParser.parse(try await request(ip: ip, path: "/query/apps", method: "GET"))
    }

    public func activeApp(ip: String) async throws -> Data {
        try await request(ip: ip, path: "/query/active-app", method: "GET")
    }

    /// Raw PNG data for a channel icon.
    public func icon(appID: String, ip: String) async throws -> Data {
        try await request(ip: ip, path: "/query/icon/\(appID)", method: "GET")
    }

    // MARK: - Commands

    public func keypress(_ key: ECPKey, ip: String) async throws {
        _ = try await request(ip: ip, path: "/keypress/\(key.rawValue)", method: "POST")
    }

    public func keydown(_ key: ECPKey, ip: String) async throws {
        _ = try await request(ip: ip, path: "/keydown/\(key.rawValue)", method: "POST")
    }

    public func keyup(_ key: ECPKey, ip: String) async throws {
        _ = try await request(ip: ip, path: "/keyup/\(key.rawValue)", method: "POST")
    }

    public func launch(appID: String, ip: String) async throws {
        _ = try await request(ip: ip, path: "/launch/\(appID)", method: "POST")
    }

    /// Sends text one character at a time as `keypress/Lit_{percent-encoded UTF-8}`.
    /// Stops at the first failure so the Roku doesn't receive garbled partial input
    /// out of order.
    public func typeText(_ text: String, ip: String) async throws {
        for character in text {
            _ = try await request(
                ip: ip,
                path: "/keypress/Lit_\(Self.encode(character: character))",
                method: "POST"
            )
        }
    }

    /// Percent-encodes every UTF-8 byte of the character except RFC 3986
    /// unreserved bytes (ALPHA / DIGIT / "-" / "." / "_" / "~").
    /// "a" → "a", " " → "%20", "é" → "%C3%A9", "😀" → "%F0%9F%98%80".
    static func encode(character: Character) -> String {
        String(character).utf8.map { byte -> String in
            switch byte {
            case UInt8(ascii: "A")...UInt8(ascii: "Z"),
                 UInt8(ascii: "a")...UInt8(ascii: "z"),
                 UInt8(ascii: "0")...UInt8(ascii: "9"),
                 UInt8(ascii: "-"), UInt8(ascii: "."),
                 UInt8(ascii: "_"), UInt8(ascii: "~"):
                return String(UnicodeScalar(byte))
            default:
                return String(format: "%%%02X", byte)
            }
        }.joined()
    }

    // MARK: - Transport

    private func request(ip: String, path: String, method: String) async throws -> Data {
        guard let url = URL(string: "http://\(ip):\(Self.port)\(path)") else {
            throw ECPError.invalidURL
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw ECPError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ECPError.httpError(statusCode: http.statusCode)
        }
        return data
    }
}
