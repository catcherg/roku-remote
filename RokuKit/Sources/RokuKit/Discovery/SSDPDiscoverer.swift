import Foundation
import Network

/// Primary discovery: UDP multicast M-SEARCH (roadmap §1.2 Strategy A).
///
/// ⚠️ Sending multicast on iOS requires the `com.apple.developer.networking.multicast`
/// entitlement. Without it the send fails at the socket layer — this type is built
/// to SOFT-FAIL: any error simply finishes the stream empty, and
/// `DiscoveryCoordinator` falls through to `SubnetScanner`. SSDP is an upgrade,
/// never a dependency.
public final class SSDPDiscoverer: @unchecked Sendable {
    /// Flip to `true` in the app once the multicast entitlement is granted and
    /// added to the target's capabilities. Defaults to `false` so the un-entitled
    /// build never waits on a doomed socket.
    public static var isEnabled = false

    private let client: ECPClient
    private let window: TimeInterval

    /// - Parameter window: how long to listen for responses (4s per CLAUDE.md).
    public init(client: ECPClient = ECPClient(), window: TimeInterval = 4) {
        self.client = client
        self.window = window
    }

    public func discover() -> AsyncStream<RokuDevice> {
        let client = self.client
        let window = self.window

        return AsyncStream { continuation in
            guard Self.isEnabled else {
                continuation.finish()
                return
            }

            let connection = NWConnection(
                host: NWEndpoint.Host(SSDP.multicastHost),
                port: NWEndpoint.Port(rawValue: SSDP.multicastPort)!,
                using: .udp
            )

            @Sendable func receiveNext() {
                connection.receiveMessage { data, _, _, error in
                    if let data,
                       let text = String(data: data, encoding: .utf8),
                       let ip = SSDP.ip(fromResponse: text) {
                        Task {
                            if let info = try? await client.deviceInfo(ip: ip) {
                                continuation.yield(info.device(ip: ip))
                            }
                        }
                    }
                    if error == nil {
                        receiveNext()
                    } else {
                        continuation.finish()
                    }
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(
                        content: SSDP.mSearchPayload,
                        completion: .contentProcessed { error in
                            if error != nil {
                                // No entitlement (or network refuses multicast): soft-fail.
                                connection.cancel()
                                continuation.finish()
                            }
                        }
                    )
                    receiveNext()
                case .failed, .cancelled:
                    continuation.finish()
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .userInitiated))

            // Bounded listen window; discovery must never hang the UI.
            let timeout = Task {
                try? await Task.sleep(nanoseconds: UInt64(window * 1_000_000_000))
                connection.cancel()
                continuation.finish()
            }
            continuation.onTermination = { _ in
                timeout.cancel()
                connection.cancel()
            }
        }
    }
}
