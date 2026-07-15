/// De-duplicates devices found by multiple discovery strategies, keyed on
/// serial number (roadmap Phase 1 task 5). Pure value type — unit-testable.
public struct DeviceDeduplicator {
    private var seenSerials: Set<String> = []

    public init() {}

    /// Returns `true` if the device is new (caller should emit it),
    /// `false` if a device with the same serial was already seen.
    public mutating func insert(_ device: RokuDevice) -> Bool {
        seenSerials.insert(device.serialNumber).inserted
    }
}
