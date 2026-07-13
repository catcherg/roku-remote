# Creating the Xcode project (one-time, ~5 minutes, requires your Mac)

The `.xcodeproj` bundle must be created in Xcode — do this once, then commit it. CI's app-build job auto-activates when it exists.

1. Xcode → File → New → Project → iOS → **App**
   - Product Name: **Clicker**
   - Team: your Apple Developer team (after enrollment clears; "None" works until then)
   - Organization Identifier: **com.catchergriffin** (bundle ID becomes `com.catchergriffin.clicker`)
   - Interface: SwiftUI, Language: Swift, no tests needed at project creation (RokuKit carries the tests)
2. Save it **inside this `App/` folder** so the project lands at `App/Clicker.xcodeproj`.
3. Project settings → General → Minimum Deployments: **iOS 16.0**.
4. Replace the generated `ClickerApp.swift` / `ContentView.swift` with the files in `App/Clicker/` here (or add these files to the target).
5. Add RokuKit: File → Add Package Dependencies → **Add Local…** → select the `RokuKit/` folder at repo root.
6. Info tab → add key **Privacy - Local Network Usage Description** (`NSLocalNetworkUsageDescription`):
   > This app needs local network access to find and control Roku devices on your Wi-Fi.
7. Build (⌘B), then commit: `git add App && git commit -m "chore: add Xcode project skeleton"`

After the multicast entitlement is approved (Phase 1+), add `com.apple.developer.networking.multicast` under Signing & Capabilities.
