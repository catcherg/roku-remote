import SwiftUI

@main
struct ClickerApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark) // dark-mode-first per design principles
        }
    }
}
