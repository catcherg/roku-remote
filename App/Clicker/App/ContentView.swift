import SwiftUI
import RokuKit

/// Routes on the connection state machine — the enum drives all UI (§2.2).
/// Purchases never change the route: the remote is always reachable, and the
/// paywall appears from it once the free key presses are used up.
struct ContentView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some View {
        Group {
            if case .connected = app.connection {
                NavigationStack {
                    RemoteControlView()
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
            await entitlements.load()
        }
        .task {
            if hasOnboarded {
                await app.autoReconnect()
            }
        }
        .onChange(of: scenePhase) { phase in
            // Back in the foreground: a subscription may have renewed or
            // lapsed while the app was away.
            if phase == .active {
                Task { await entitlements.refresh() }
            }
        }
    }
}
