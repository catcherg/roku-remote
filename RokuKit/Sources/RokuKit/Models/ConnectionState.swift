/// Connection state machine (roadmap §2.2):
/// `disconnected → discovering → connected(device) → unreachable(device)`.
/// The single source of truth that drives all UI.
public enum ConnectionState: Equatable, Sendable {
    case disconnected
    case discovering
    case connected(RokuDevice)
    case unreachable(RokuDevice)

    /// The device this state refers to, when there is one.
    public var device: RokuDevice? {
        switch self {
        case .connected(let device), .unreachable(let device):
            return device
        case .disconnected, .discovering:
            return nil
        }
    }

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}
