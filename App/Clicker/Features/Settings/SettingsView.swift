import SwiftUI
import StoreKit
import RokuKit

/// Settings (Phase 3 task 8): current plan with renewal date, Manage
/// Subscription, lifetime upgrade and Restore; haptics toggle, device
/// management with default device, Help, legal disclaimer (§1.5), terms,
/// privacy policy, version.
struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var entitlements: EntitlementStore
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var renameTarget: RokuDevice?
    @State private var renameText = ""
    @State private var showPlans = false
    @State private var showManageSubscription = false

    var body: some View {
        List {
            purchaseSection

            Section("Feedback") {
                Toggle("Haptics", isOn: $hapticsEnabled)
            }

            Section {
                ForEach(app.devices) { device in
                    deviceRow(device)
                }
                .onDelete { offsets in
                    for offset in offsets {
                        app.forget(app.devices[offset])
                    }
                }
            } header: {
                Text("Devices")
            } footer: {
                Text("Tap a device to make it the default — Clicker connects to it automatically on launch. Swipe to forget.")
            }

            Section("Support") {
                NavigationLink {
                    HelpView()
                } label: {
                    Label("Help & troubleshooting", systemImage: "questionmark.circle")
                }
                Link(destination: AppInfo.termsURL) {
                    Label("Terms of use", systemImage: "doc.text")
                }
                Link(destination: AppInfo.privacyPolicyURL) {
                    Label("Privacy policy", systemImage: "hand.raised")
                }
            }

            Section {
                LabeledContent("Version", value: AppInfo.version)
            } footer: {
                Text(AppInfo.disclaimer)
                    .font(.caption2)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await entitlements.loadOffer() }
        .sheet(isPresented: $showPlans) {
            NavigationStack {
                PaywallView()
            }
        }
        // Apple's own sheet: change, cancel or resubscribe.
        .manageSubscriptionsSheet(isPresented: $showManageSubscription)
        .alert("Rename device", isPresented: renameBinding) {
            TextField("Name", text: $renameText)
            Button("Save") {
                if let target = renameTarget, !renameText.isEmpty {
                    app.rename(target, to: renameText)
                }
                renameTarget = nil
            }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        }
    }

    // MARK: - Purchase

    /// Current plan, when it renews or ends, and what can be done about it.
    private var purchaseSection: some View {
        Section {
            LabeledContent("Plan", value: planName)

            switch entitlements.access {
            case .loading:
                EmptyView()
            case .notEntitled(let lapsed):
                LabeledContent("Free key presses left",
                               value: "\(entitlements.freeKeyPressesLeft) of \(FreePreview.keyPressAllowance)")
                Button("See Plans") { showPlans = true }
                if lapsed { manageSubscriptionButton }
                restoreButton
            case .subscribed(let subscription):
                if let row = renewalRow(for: subscription) {
                    LabeledContent(row.title, value: row.date)
                }
                if subscription.hasBillingIssue {
                    Label("Apple couldn't renew your subscription. Update your payment method to keep it.",
                          systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                }
                manageSubscriptionButton
                lifetimeUpgradeButton
                restoreButton
            case .lifetime:
                if subscriptionStillRenews {
                    Label("Your weekly subscription is still running. Cancel it so you aren't charged again.",
                          systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                    manageSubscriptionButton
                }
            }
        } header: {
            Text("Clicker")
        } footer: {
            if let notice = entitlements.notice {
                Text(notice.message)
            } else {
                switch entitlements.access {
                case .subscribed:
                    Text("Lifetime is a one-time purchase. It does not cancel the weekly subscription; cancel that under Manage Subscription afterwards.")
                case .lifetime:
                    Text("Thank you. Clicker is yours for good.")
                case .loading, .notEntitled:
                    EmptyView()
                }
            }
        }
        .disabled(entitlements.activity != nil)
    }

    private var planName: String {
        switch entitlements.access {
        case .loading:
            return "…"
        case .notEntitled(lapsed: false):
            return "Free preview"
        case .notEntitled(lapsed: true):
            return "Subscription ended"
        case .subscribed(let subscription):
            if subscription.hasBillingIssue { return "Weekly, payment problem" }
            return subscription.isInFreeTrial ? "Weekly, free trial" : "Weekly"
        case .lifetime:
            return "Lifetime"
        }
    }

    /// "Renews" / "First payment" / "Ends" with the date, read from StoreKit.
    private func renewalRow(for subscription: SubscriptionRecord) -> (title: String, date: String)? {
        guard let date = subscription.currentPeriodEnds else { return nil }
        let title: String
        switch subscription.state {
        case .inBillingRetry:
            return nil // already past due; Apple is retrying the charge
        case .inGracePeriod:
            title = "Access until"
        case .subscribed, .expired, .revoked:
            if !subscription.willAutoRenew {
                title = "Ends"
            } else {
                title = subscription.isInFreeTrial ? "First payment" : "Renews"
            }
        }
        return (title, date.formatted(date: .abbreviated, time: .omitted))
    }

    /// A lifetime owner whose weekly subscription would still charge them.
    private var subscriptionStillRenews: Bool {
        guard let subscription = entitlements.owned.subscription else { return false }
        return subscription.isActive && subscription.willAutoRenew
    }

    private var manageSubscriptionButton: some View {
        Button("Manage Subscription") { showManageSubscription = true }
    }

    private var lifetimeUpgradeButton: some View {
        Button {
            Task { await entitlements.buyLifetime() }
        } label: {
            HStack {
                Text("Upgrade to Lifetime")
                Spacer()
                if entitlements.activity == .buyingLifetime {
                    ProgressView()
                } else if case .ready(let offer) = entitlements.offer {
                    Text(offer.lifetimePrice)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var restoreButton: some View {
        Button {
            Task { await entitlements.restore() }
        } label: {
            HStack {
                Text("Restore Purchases")
                Spacer()
                if entitlements.activity == .restoring {
                    ProgressView()
                }
            }
        }
    }

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )
    }

    @ViewBuilder
    private func deviceRow(_ device: RokuDevice) -> some View {
        let isDefault = app.store.lastConnected?.serialNumber == device.serialNumber
        Button {
            app.setDefault(device)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(device.name)
                        .foregroundStyle(.primary)
                    Text("\(device.model) · \(device.ip)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isDefault {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .contextMenu {
            Button {
                renameTarget = device
                renameText = device.name
            } label: {
                Label("Rename", systemImage: "pencil")
            }
        }
    }
}
