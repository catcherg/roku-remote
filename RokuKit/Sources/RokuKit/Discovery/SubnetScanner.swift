import Foundation

/// Fallback discovery: probes every host on the local subnet with
/// `GET /query/device-info` (1s timeout, ≤32 concurrent — per roadmap §1.2
/// Strategy B). Requires no entitlements; works everywhere unicast TCP works.
public struct SubnetScanner {
    private let client: ECPClient
    private let networkInfo: LocalNetworkInfoProviding
    private let maxConcurrent: Int

    public init(client: ECPClient = ECPClient(session: ECPClient.makeSession(timeout: 1)),
                networkInfo: LocalNetworkInfoProviding = SystemNetworkInfo(),
                maxConcurrent: Int = 32) {
        self.client = client
        self.networkInfo = networkInfo
        self.maxConcurrent = max(1, maxConcurrent)
    }

    /// Streams devices as they answer. Finishes when the whole subnet has been
    /// probed (worst case ~10s for a /24) or the consumer cancels.
    public func scan() -> AsyncStream<RokuDevice> {
        let client = self.client
        let networkInfo = self.networkInfo
        let maxConcurrent = self.maxConcurrent

        return AsyncStream { continuation in
            let task = Task {
                guard let info = networkInfo.primaryIPv4() else {
                    continuation.finish()
                    return
                }
                let hosts = SubnetMath.hosts(address: info.address, netmask: info.netmask)
                await withTaskGroup(of: RokuDevice?.self) { group in
                    var iterator = hosts.makeIterator()
                    var started = 0
                    while started < maxConcurrent, let ip = iterator.next() {
                        group.addTask { await Self.probe(ip: ip, client: client) }
                        started += 1
                    }
                    for await device in group {
                        if let device {
                            continuation.yield(device)
                        }
                        if !Task.isCancelled, let ip = iterator.next() {
                            group.addTask { await Self.probe(ip: ip, client: client) }
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func probe(ip: String, client: ECPClient) async -> RokuDevice? {
        guard !Task.isCancelled else { return nil }
        guard let info = try? await client.deviceInfo(ip: ip) else { return nil }
        return info.device(ip: ip)
    }
}
