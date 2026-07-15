import Foundation

/// Pure SSDP protocol helpers — parsing kept separate from Network.framework
/// glue so it's unit-testable without sockets.
enum SSDP {
    static let multicastHost = "239.255.255.250"
    static let multicastPort: UInt16 = 1900

    /// M-SEARCH payload with `ST: roku:ecp` (roadmap §1.2 Strategy A).
    static let mSearchString =
        "M-SEARCH * HTTP/1.1\r\n" +
        "Host: 239.255.255.250:1900\r\n" +
        "Man: \"ssdp:discover\"\r\n" +
        "ST: roku:ecp\r\n" +
        "MX: 3\r\n" +
        "\r\n"

    static var mSearchPayload: Data { Data(mSearchString.utf8) }

    /// Extracts the LOCATION header value from an SSDP response (case-insensitive).
    static func location(fromResponse response: String) -> String? {
        for line in response.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2,
                  parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "location" else {
                continue
            }
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
        return nil
    }

    /// "http://192.168.1.23:8060/" → "192.168.1.23"
    static func ip(fromLocation location: String) -> String? {
        guard let url = URL(string: location), let host = url.host, !host.isEmpty else {
            return nil
        }
        return host
    }

    /// Full pipeline: raw SSDP response text → Roku IP, or nil if not a usable response.
    static func ip(fromResponse response: String) -> String? {
        guard let location = location(fromResponse: response) else { return nil }
        return ip(fromLocation: location)
    }
}
