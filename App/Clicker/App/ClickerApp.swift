import SwiftUI

@main
struct ClickerApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .tint(Theme.accent)
                // Dark-mode-first; light mode supported via dynamic Theme colors.
        }
    }
}
