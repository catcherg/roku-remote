import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Abstracts `getifaddrs` so SubnetScanner is testable with a fake.
public protocol LocalNetworkInfoProviding: Sendable {
    /// The device's primary IPv4 address + netmask (Wi-Fi preferred), or nil
    /// when there is no usable interface (airplane mode, cellular-only, ...).
    func primaryIPv4() -> (address: String, netmask: String)?
}

/// Real implementation backed by `getifaddrs`. Prefers `en0` (Wi-Fi on iOS),
/// otherwise the first up, non-loopback IPv4 interface.
public struct SystemNetworkInfo: LocalNetworkInfoProviding {
    public init() {}

    public func primaryIPv4() -> (address: String, netmask: String)? {
        #if canImport(Darwin)
        var ifaddrPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPointer) == 0, let first = ifaddrPointer else {
            return nil
        }
        defer { freeifaddrs(ifaddrPointer) }

        var fallback: (address: String, netmask: String)?
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard let addressPointer = interface.ifa_addr,
                  addressPointer.pointee.sa_family == sa_family_t(AF_INET) else {
                continue
            }
            let flags = Int32(interface.ifa_flags)
            guard (flags & IFF_UP) != 0,
                  (flags & IFF_RUNNING) != 0,
                  (flags & IFF_LOOPBACK) == 0 else {
                continue
            }
            guard let address = Self.ipv4String(addressPointer),
                  let netmaskPointer = interface.ifa_netmask,
                  let netmask = Self.ipv4String(netmaskPointer) else {
                continue
            }
            let name = String(cString: interface.ifa_name)
            if name == "en0" {
                return (address, netmask)
            }
            if fallback == nil {
                fallback = (address, netmask)
            }
        }
        return fallback
        #else
        return nil
        #endif
    }

    #if canImport(Darwin)
    private static func ipv4String(_ sa: UnsafeMutablePointer<sockaddr>) -> String? {
        var sinAddr = sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
            $0.pointee.sin_addr
        }
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &sinAddr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
            return nil
        }
        return String(cString: buffer)
    }
    #endif
}
