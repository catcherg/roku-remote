/// Pure IPv4 subnet arithmetic — fully unit-testable, no networking.
public enum SubnetMath {
    /// Hard cap on how many hosts a scan will probe. If the netmask implies a
    /// larger range (e.g. /16 corporate networks), we clamp to the /24
    /// containing `address` — scanning 65k hosts on a phone is never right.
    public static let maxHosts = 1024

    /// All probe-worthy host IPs on the subnet, excluding the network address,
    /// broadcast address, and `address` itself.
    public static func hosts(address: String, netmask: String) -> [String] {
        guard let addr = toUInt32(address), var mask = toUInt32(netmask),
              mask != 0, mask != 0xFFFF_FFFF else {
            return []
        }
        var hostCount = (~mask) &- 1 // usable hosts = 2^n - 2
        if hostCount > UInt32(maxHosts) {
            mask = 0xFFFF_FF00 // clamp to the /24 around the device
            hostCount = 254
        }
        let network = addr & mask
        let broadcast = network | ~mask
        guard broadcast > network + 1 else { return [] }

        var result: [String] = []
        result.reserveCapacity(Int(hostCount))
        var host = network + 1
        while host < broadcast {
            if host != addr {
                result.append(toString(host))
            }
            host += 1
        }
        return result
    }

    /// "192.168.1.10" → 0xC0A8010A. Returns nil for malformed input.
    public static func toUInt32(_ ip: String) -> UInt32? {
        let parts = ip.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var value: UInt32 = 0
        for part in parts {
            guard let octet = UInt8(part) else { return nil }
            value = (value << 8) | UInt32(octet)
        }
        return value
    }

    /// 0xC0A8010A → "192.168.1.10"
    public static func toString(_ value: UInt32) -> String {
        "\((value >> 24) & 0xFF).\((value >> 16) & 0xFF).\((value >> 8) & 0xFF).\(value & 0xFF)"
    }
}
