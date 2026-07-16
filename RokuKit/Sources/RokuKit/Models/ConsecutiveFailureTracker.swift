/// Optimistic-UI failure counting (roadmap §2.2): individual command failures
/// are invisible; only N *consecutive* failures surface a "Reconnecting…"
/// banner. Any success resets the streak.
public struct ConsecutiveFailureTracker: Sendable {
    public let threshold: Int
    public private(set) var count = 0

    public init(threshold: Int = 3) {
        self.threshold = max(1, threshold)
    }

    /// Records one failure. Returns `true` when the failure streak has
    /// reached the threshold (i.e. the UI should react).
    @discardableResult
    public mutating func recordFailure() -> Bool {
        count += 1
        return count >= threshold
    }

    public mutating func recordSuccess() {
        count = 0
    }

    public mutating func reset() {
        count = 0
    }

    public var hasCrossedThreshold: Bool { count >= threshold }
}
