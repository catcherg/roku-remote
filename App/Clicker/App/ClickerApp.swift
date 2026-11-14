import SwiftUI

@main
struct ClickerApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var entitlements = ClickerApp.makeEntitlementStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(entitlements)
                .tint(Theme.accent)
                // Dark-mode-first; light mode supported via dynamic Theme colors.
        }
    }

    private static func makeEntitlementStore() -> EntitlementStore {
        #if DEBUG
        // Debug builds honour the launch arguments in DebugPurchaseBackend.swift.
        return EntitlementStore.debug()
        #else
        return EntitlementStore()
        #endif
    }
}
