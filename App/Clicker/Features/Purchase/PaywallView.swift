import SwiftUI

/// The unlock screen. Two uses:
/// - the root screen once the trial has expired, where it replaces the remote
///   and every other feature screen (Help and Settings stay in the toolbar);
/// - a sheet during the trial, for people who want to unlock early.
struct PaywallView: View {
    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.dismiss) private var dismiss
    /// True when presented as a dismissable sheet rather than the root screen.
    var isSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "av.remote")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 32)
                Text(status)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("One price, forever.")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .multilineTextAlignment(.center)
                Text("Unlock Clicker once and it's yours. No subscription, no ads, no account.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    feature("hand.draw", "Eyes-free swipe remote")
                    feature("keyboard", "Type with your phone's keyboard")
                    feature("square.grid.3x3", "One-tap channel launcher")
                    if isFamilyShareable {
                        feature("person.2", "Shared with your family through Family Sharing")
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) { actions }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isSheet {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .modifier(RootPaywallToolbar(isEnabled: !isSheet))
        .task { await entitlements.loadOffer() }
        .onChange(of: entitlements.access) { access in
            if isSheet, access == .unlocked { dismiss() }
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 10) {
            if let notice = entitlements.notice {
                Text(notice.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                Task {
                    if entitlements.offer == .unavailable {
                        await entitlements.loadOffer()
                    } else {
                        Haptics.medium()
                        await entitlements.unlock()
                    }
                }
            } label: {
                PurchaseButtonLabel(title: buyTitle, isBusy: isBuying)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isBuying || entitlements.activity != nil)

            Button {
                Task { await entitlements.restore() }
            } label: {
                if entitlements.activity == .restoring {
                    ProgressView()
                } else {
                    Text("Restore Purchases")
                }
            }
            .font(.subheadline)
            .frame(minHeight: Theme.minTarget)
            .disabled(entitlements.activity != nil)

            Text("One-time purchase. No subscription.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Theme.background)
    }

    // MARK: - Copy

    private var status: String {
        switch entitlements.access {
        case .trial(let days):
            return "\(TrialCopy.daysLeft(days)) in your free trial"
        case .unlocked:
            return "Clicker is unlocked"
        case .expired, .needsTrial, .loading:
            return "Your free trial has ended"
        }
    }

    /// The price always comes from the App Store product; with no product
    /// loaded the button offers a retry instead of guessing an amount.
    private var buyTitle: String {
        switch entitlements.offer {
        case .ready(let offer): return "Unlock for \(offer.unlockPrice)"
        case .loading: return "Unlock Clicker"
        case .unavailable: return "Try Again"
        }
    }

    private var isBuying: Bool {
        entitlements.offer == .loading || entitlements.activity == .unlocking
    }

    private var isFamilyShareable: Bool {
        if case .ready(let offer) = entitlements.offer { return offer.unlockIsFamilyShareable }
        return false
    }

    private func feature(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            Text(text)
        }
    }
}

/// Help + Settings links, only when the paywall is the root screen.
private struct RootPaywallToolbar: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.purchaseScreenToolbar()
        } else {
            content
        }
    }
}

enum TrialCopy {
    static func daysLeft(_ days: Int) -> String {
        days == 1 ? "1 day left" : "\(days) days left"
    }
}

/// Quiet "N days left" line under the remote and the device list while the
/// trial runs. Tapping it opens the unlock sheet. Renders nothing otherwise.
struct TrialMarker: View {
    @EnvironmentObject private var entitlements: EntitlementStore
    @State private var showUnlock = false

    var body: some View {
        if case .trial(let days) = entitlements.access {
            Button {
                showUnlock = true
            } label: {
                Text("Free trial · \(TrialCopy.daysLeft(days))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Theme.background)
            .accessibilityHint("Shows the one-time unlock")
            .sheet(isPresented: $showUnlock) {
                NavigationStack {
                    PaywallView(isSheet: true)
                }
            }
        }
    }
}
