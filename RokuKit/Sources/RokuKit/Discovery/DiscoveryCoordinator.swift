import Foundation

/// Public discovery façade (roadmap Phase 1 task 5): merges every strategy into
/// one de-duplicated `AsyncStream<RokuDevice>`. SSDP runs alongside the subnet
/// scan; SSDP soft-fails to an empty stream when the multicast entitlement is
/// missing, so the scanner alone still finds everything.
public struct DiscoveryCoordinator {
    public typealias Source = @Sendable () -> AsyncStream<RokuDevice>

    private let sources: [Source]

    /// Test-friendly initializer: inject any set of device streams.
    public init(sources: [Source]) {
        self.sources = sources
    }

    /// Production configuration: SSDP (if enabled) + subnet scan.
    public init(client: ECPClient = ECPClient(),
                scanner: SubnetScanner = SubnetScanner(),
                ssdp: SSDPDiscoverer? = nil) {
        let ssdp = ssdp ?? SSDPDiscoverer(client: client)
        self.init(sources: [
            { ssdp.discover() },
            { scanner.scan() },
        ])
    }

    /// Runs all sources concurrently; yields each unique device (by serial)
    /// exactly once. Finishes when every source has finished.
    public func discover() -> AsyncStream<RokuDevice> {
        let sources = self.sources
        return AsyncStream { continuation in
            let task = Task {
                let merged = AsyncStream<RokuDevice> { inner in
                    let mergeTask = Task {
                        await withTaskGroup(of: Void.self) { group in
                            for source in sources {
                                group.addTask {
                                    for await device in source() {
                                        inner.yield(device)
                                    }
                                }
                            }
                        }
                        inner.finish()
                    }
                    inner.onTermination = { _ in mergeTask.cancel() }
                }

                var deduplicator = DeviceDeduplicator()
                for await device in merged {
                    if deduplicator.insert(device) {
                        continuation.yield(device)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
