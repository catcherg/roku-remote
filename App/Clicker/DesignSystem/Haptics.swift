import UIKit

/// Haptics engine (Phase 3 task 3): light for d-pad, medium for Select/Home,
/// rigid for power. Global toggle lives in UserDefaults ("hapticsEnabled").
enum Haptics {
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }

    static func light() { impact(.light) }
    static func medium() { impact(.medium) }
    static func rigid() { impact(.rigid) }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
