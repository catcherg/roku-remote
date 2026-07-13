import SwiftUI

@main
struct ClickerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark) // dark-mode-first per design principles
        }
    }
}
