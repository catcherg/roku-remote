import SwiftUI
import RokuKit

/// Routes on the connection state machine — the enum drives all UI (§2.2).
struct ContentView: View {
    @EnvironmentObject private var app: AppState
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some View {
        Group {
            if case .connected = app.connection {
                NavigationStack {
                    RemoteView()
                }
            } else if hasOnboarded {
                NavigationStack {
                    DiscoveryView()
                }
            } else {
                OnboardingView()
            }
        }
        .task {
            if hasOnboarded {
                await app.autoReconnect()
            }
        }
    }
}
