import SwiftUI
import UIKit

/// Design tokens (Phase 3 task 1). True-black dark-mode-first with one
/// restrained accent (deliberately NOT purple — §1.5); light mode is a
/// correct-but-secondary citizen via dynamic colors.
enum Theme {
    // MARK: - Colors

    /// Screen background. True black in dark mode for OLED.
    static let background = dynamic(dark: UIColor(white: 0.0, alpha: 1),
                                    light: UIColor.systemGroupedBackground)

    /// Elevated surfaces (cards, d-pad ring).
    static let surface = dynamic(dark: UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1),
                                 light: UIColor.secondarySystemGroupedBackground)

    /// Resting key fill.
    static let keyFill = dynamic(dark: UIColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1),
                                 light: UIColor.systemGray5)

    /// Pressed key fill (brighter — pairs with the scale-down animation).
    static let keyPressed = dynamic(dark: UIColor(red: 0.20, green: 0.20, blue: 0.24, alpha: 1),
                                    light: UIColor.systemGray3)

    /// Accent (teal — set in Assets as AccentColor; mirrored here for shapes).
    static let accent = Color("AccentColor")

    /// Text and glyphs on an accent fill. Black reads on both accent teals
    /// (6.8:1 light, 12.1:1 dark); white drops to 1.7:1 on the dark-mode one.
    static let onAccent = Color.black

    /// Live status dot colors for the connected pill.
    static let statusConnected = Color.green
    static let statusReconnecting = Color.yellow

    // MARK: - Metrics

    /// Standard press animation (roadmap: 100–150ms).
    static let pressAnimation: Animation = .easeOut(duration: 0.12)

    /// Minimum hit target (accessibility).
    static let minTarget: CGFloat = 44

    private static func dynamic(dark: UIColor, light: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

/// App-wide constants used by Settings/About.
enum AppInfo {
    static let disclaimer = "Not affiliated with or endorsed by Roku, Inc. Roku is a trademark of Roku, Inc."
    static let privacyPolicyURL = URL(string: "https://getclicker.me/privacy")!
    /// Terms of Use, linked from the paywall beside the privacy policy.
    static let termsURL = URL(string: "https://getclicker.me/terms")!

    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(short) (\(build))"
    }
}
