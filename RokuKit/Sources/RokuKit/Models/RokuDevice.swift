/// A discovered (or remembered) Roku device. Identity is the serial number —
/// IPs change with DHCP; serials don't. De-duplication and persistence key on it.
public struct RokuDevice: Identifiable, Codable, Hashable, Sendable {
    public let serialNumber: String
    public var name: String
    public var ip: String
    public let isTV: Bool
    public let model: String

    public var id: String { serialNumber }

    public init(serialNumber: String, name: String, ip: String, isTV: Bool, model: String) {
        self.serialNumber = serialNumber
        self.name = name
        self.ip = ip
        self.isTV = isTV
        self.model = model
    }
}
