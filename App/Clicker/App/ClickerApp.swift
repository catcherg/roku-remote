import SwiftUI

@main
struct ClickerApp: App {
    @StateObject private var entitlements: EntitlementStore
    @StateObject private var appState: AppState

    init() {
        // One entitlement store for the whole app; the remote's command layer
        // asks it before every key press.
        let store = ClickerApp.makeEntitlementStore()
        _entitlements = StateObject(wrappedValue: store)
        _appState = StateObject(wrappedValue: AppState(gate: store))
    }

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
