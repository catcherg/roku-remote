import Foundation

/// Codable persistence of known devices + last-connected on UserDefaults
/// (roadmap Phase 1 task 6). Keyed by serial number; IPs are updated in place
/// when DHCP moves a device.
public struct SavedDeviceStore {
    private let defaults: UserDefaults
    private let devicesKey = "rokukit.savedDevices"
    private let lastConnectedKey = "rokukit.lastConnectedSerial"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Devices

    public var devices: [RokuDevice] {
        guard let data = defaults.data(forKey: devicesKey),
              let decoded = try? JSONDecoder().decode([RokuDevice].self, from: data) else {
            return []
        }
        return decoded
    }

    /// Insert or update (by serial). Existing devices keep their position.
    public func save(_ device: RokuDevice) {
        var current = devices
        if let index = current.firstIndex(where: { $0.serialNumber == device.serialNumber }) {
            current[index] = device
        } else {
            current.append(device)
        }
        write(current)
    }

    public func forget(serial: String) {
        write(devices.filter { $0.serialNumber != serial })
        if defaults.string(forKey: lastConnectedKey) == serial {
            defaults.removeObject(forKey: lastConnectedKey)
        }
    }

    public func rename(serial: String, to name: String) {
        update(serial: serial) { $0.name = name }
    }

    public func updateIP(serial: String, ip: String) {
        update(serial: serial) { $0.ip = ip }
    }

    // MARK: - Last connected

    public var lastConnected: RokuDevice? {
        guard let serial = defaults.string(forKey: lastConnectedKey) else { return nil }
        return devices.first { $0.serialNumber == serial }
    }

    /// Marks the device as last-connected (and saves/updates it in the list).
    public func setLastConnected(_ device: RokuDevice) {
        save(device)
        defaults.set(device.serialNumber, forKey: lastConnectedKey)
    }

    // MARK: - Private

    private func update(serial: String, _ mutate: (inout RokuDevice) -> Void) {
        var current = devices
        guard let index = current.firstIndex(where: { $0.serialNumber == serial }) else { return }
        mutate(&current[index])
        write(current)
    }

    private func write(_ devices: [RokuDevice]) {
        if let data = try? JSONEncoder().encode(devices) {
            defaults.set(data, forKey: devicesKey)
        }
    }
}
