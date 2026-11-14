import SwiftUI

/// The pre-trial disclosure. Before the trial starts it states the three
/// things App Review Guideline 3.1.1 asks for: how long the trial lasts, what
/// stops working when it ends, and what unlocking costs. The price is the App
/// Store's own string, so the trial cannot be started until it has loaded.
struct TrialOfferContent: View {
    @EnvironmentObject private var entitlements: EntitlementStore

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 64))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.system(.title2, design: .rounded).bold())
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 14) {
                term("checkmark.circle",
                     Text("The full remote, keyboard and channel launcher are free for **\(TrialPolicy.lengthInDays) days**."))
                term("lock",
                     Text("When the trial ends, **the remote stops working** until you unlock Clicker."))
                term("tag", priceTerm)
            }
            if let notice = entitlements.notice {
                Text(notice.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            if entitlements.access == .needsTrial {
                Button {
                    Task { await entitlements.restore() }
                } label: {
                    if entitlements.activity == .restoring {
                        ProgressView()
                    } else {
                        Text("Already bought Clicker? Restore Purchases")
                    }
                }
                .font(.footnote)
                .frame(minHeight: Theme.minTarget)
                .disabled(entitlements.activity != nil)
            }
            Spacer()
        }
    }

    private var title: String {
        switch entitlements.access {
        case .unlocked:
            return "Clicker is unlocked"
        case .trial:
            return "Your free trial has started"
        case .needsTrial, .expired, .loading:
            return "Try Clicker free for \(TrialPolicy.lengthInDays) days"
        }
    }

    private var priceTerm: Text {
        switch entitlements.offer {
        case .ready(let offer):
            return Text("Unlocking is a one-time purchase of **\(offer.unlockPrice)**. There is no subscription and you are never charged automatically.")
        case .loading:
            return Text("Unlocking is a one-time purchase. Loading the price from the App Store…")
        case .unavailable:
            return Text("Unlocking is a one-time purchase. Clicker couldn't reach the App Store to show the price, so the trial can't start yet.")
        }
    }

    private func term(_ symbol: String, _ text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            text
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The button that starts the trial. Disabled until the unlock price has
/// loaded, and turns into "Try Again" when the App Store can't be reached.
struct TrialOfferButton: View {
    @EnvironmentObject private var entitlements: EntitlementStore

    var body: some View {
        Button {
            Task {
                if entitlements.offer == .unavailable {
                    await entitlements.loadOffer()
                } else {
                    Haptics.medium()
                    await entitlements.startTrial()
                }
            }
        } label: {
            PurchaseButtonLabel(title: title, isBusy: isBusy)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isBusy || entitlements.activity != nil)
    }

    private var title: String {
        entitlements.offer == .unavailable
            ? "Try Again"
            : "Start \(TrialPolicy.lengthInDays)-Day Free Trial"
    }

    private var isBusy: Bool {
        entitlements.offer == .loading || entitlements.activity == .startingTrial
    }
}

/// Full-width label shared by the onboarding and purchase buttons.
struct PurchaseButtonLabel: View {
    let title: String
    var isBusy = false

    var body: some View {
        ZStack {
            Text(title).opacity(isBusy ? 0 : 1)
            if isBusy { ProgressView() }
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

/// Shown instead of the device list when onboarding is already done but no
/// trial was ever started (an install from before the trial existed, or the
/// App Store sheet was dismissed). Settings and Help stay reachable.
struct TrialOfferScreen: View {
    var body: some View {
        VStack(spacing: 0) {
            TrialOfferContent()
                .padding(.horizontal, 32)
            TrialOfferButton()
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .purchaseScreenToolbar()
    }
}

extension View {
    /// Help and Settings links for the screens that stand in front of the
    /// remote, so neither is ever locked away behind a purchase.
    func purchaseScreenToolbar() -> some View {
        toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                NavigationLink {
                    HelpView()
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .accessibilityLabel("Help")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
    }
}
