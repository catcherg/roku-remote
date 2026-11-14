import SwiftUI
import RokuKit

/// Routes on two state machines: the entitlement (trial / expired / unlocked)
/// decides whether the remote may be used at all, then the connection state
/// drives the rest of the UI (§2.2).
struct ContentView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some View {
        Group {
            switch entitlements.access {
            case .loading:
                EntitlementLoadingView()
            case .expired:
                // Trial over: the paywall replaces the remote and every
                // other feature screen. Help and Settings stay reachable.
                NavigationStack {
                    PaywallView()
                }
            case .needsTrial where hasOnboarded:
                NavigationStack {
                    TrialOfferScreen()
                }
            case .needsTrial, .trial, .unlocked:
                remote
            }
        }
        .task {
            await entitlements.load()
        }
        .task(id: canUseRemote) {
            if canUseRemote {
                await app.autoReconnect()
            }
        }
        .onChange(of: scenePhase) { phase in
            // Back in the foreground: the trial may have run out meanwhile.
            if phase == .active {
                Task { await entitlements.refresh() }
            }
        }
    }

    @ViewBuilder private var remote: some View {
        if case .connected = app.connection {
            NavigationStack {
                RemoteControlView()
            }
        } else if hasOnboarded {
            NavigationStack {
                DiscoveryView()
            }
        } else {
            OnboardingView(includesTrialStep: entitlements.access == .needsTrial)
        }
    }

    private var canUseRemote: Bool {
        hasOnboarded && entitlements.access.allowsRemote
    }
}

/// Shown while StoreKit is asked what this Apple Account owns. That is
/// normally answered from a local cache within a frame or two, so this matches
/// the launch screen and only brings in a spinner if the answer is slow.
private struct EntitlementLoadingView: View {
    @State private var isSlow = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if isSlow {
                ProgressView()
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            isSlow = true
        }
    }
}
