import SwiftUI

/// The plans screen: the weekly subscription (free trial first, when this
/// Apple Account is eligible) or the lifetime unlock. Presented as a sheet
/// from the remote once the free key presses are used up, and from Settings.
/// Every price, period and trial length shown comes from the App Store
/// products; nothing here is hard-coded.
struct PaywallView: View {
    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selection: PurchaseProduct = .weekly

    /// The terms and buttons normally stay pinned under the plans. At
    /// accessibility text sizes they are too tall for that and would cover
    /// the plans, so they scroll with them instead.
    private var pinsActions: Bool { !dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        GeometryReader { proxy in
            // Short screens drop the artwork and put the plans first, so
            // both plans show without scrolling.
            let isShort = pinsActions && proxy.size.height < 430
            ScrollView {
                VStack(spacing: isShort ? 8 : 12) {
                    if !isShort {
                        Image(systemName: "av.remote")
                            .font(.system(size: 34))
                            .foregroundStyle(Theme.accent)
                    }
                    if let status {
                        Text(status)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text("Keep using Clicker")
                        .font(.system(.title, design: .rounded).bold())
                        .multilineTextAlignment(.center)

                    if !isShort { included }
                    plans
                    if isShort { included }

                    if !pinsActions {
                        actions.padding(.top, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if pinsActions {
                actions
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .background(Theme.background)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Close") { dismiss() }
            }
        }
        .task { await entitlements.loadOffer() }
        .onChange(of: entitlements.access) { access in
            if access.isUnlocked {
                Haptics.medium()
                dismiss()
            }
        }
    }

    // MARK: - Plans

    /// What either plan buys.
    private var included: some View {
        Text("Both plans include everything: the swipe remote, typing with your phone's keyboard, the channel launcher, and volume and power on Roku TVs.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var plans: some View {
        switch entitlements.offer {
        case .ready(let offer):
            VStack(spacing: 10) {
                planCard(.weekly,
                         title: "Weekly",
                         price: PlanCopy.weeklyPrice(offer),
                         detail: PlanCopy.weeklyDetail(offer))
                planCard(.lifetime,
                         title: "Lifetime",
                         price: PlanCopy.lifetimePrice(offer),
                         detail: PlanCopy.lifetimeDetail(offer))
            }
        case .loading:
            ProgressView()
                .padding(.vertical, 24)
        case .unavailable:
            Text("Clicker couldn't reach the App Store to show the plans and prices. Check your connection and try again.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.vertical, 12)
        }
    }

    private func planCard(_ product: PurchaseProduct, title: String,
                          price: String, detail: String) -> some View {
        let isSelected = selection == product
        return Button {
            selection = product
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.accent : Color.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(price)
                        .font(.subheadline.weight(.medium))
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Theme.accent : Color.clear, lineWidth: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 6) {
            if let notice = entitlements.notice {
                Text(notice.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if case .ready(let offer) = entitlements.offer {
                // The selected plan's terms stay beside the button, where
                // they cannot be scrolled out of sight.
                Text(PlanCopy.disclosure(for: selection, offer: offer))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                Task {
                    guard case .ready = entitlements.offer else {
                        await entitlements.loadOffer()
                        return
                    }
                    switch selection {
                    case .weekly: await entitlements.subscribe()
                    case .lifetime: await entitlements.buyLifetime()
                    }
                }
            } label: {
                PurchaseButtonLabel(title: buttonTitle, isBusy: isBuying)
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

            // Side by side where they fit, stacked at large text sizes.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) { legalLinks }
                VStack(spacing: 10) { legalLinks }
            }
            .font(.footnote)
        }
    }

    @ViewBuilder private var legalLinks: some View {
        Link("Terms of Use", destination: AppInfo.termsURL)
        Link("Privacy Policy", destination: AppInfo.privacyPolicyURL)
    }

    // MARK: - Copy

    private var status: String? {
        switch entitlements.access {
        case .notEntitled(lapsed: true):
            return "Your subscription has ended"
        case .notEntitled(lapsed: false):
            let left = entitlements.freeKeyPressesLeft
            if left == 0 { return "Your free key presses are used up" }
            return left == 1 ? "1 free key press left" : "\(left) free key presses left"
        case .loading, .subscribed, .lifetime:
            return nil
        }
    }

    private var buttonTitle: String {
        switch entitlements.offer {
        case .ready(let offer): return PlanCopy.buttonTitle(for: selection, offer: offer)
        case .loading: return "Loading"
        case .unavailable: return "Try Again"
        }
    }

    private var isBuying: Bool {
        entitlements.offer == .loading
            || entitlements.activity == .subscribing
            || entitlements.activity == .buyingLifetime
    }

}

/// The words on the plans screen, built from the App Store's own prices,
/// billing period and trial length.
enum PlanCopy {
    /// "3-day free trial, then $6.99 per week", or "$6.99 per week" when
    /// this Apple Account has no free trial to use.
    static func weeklyPrice(_ offer: PurchaseOffer) -> String {
        let recurring = "\(offer.weeklyPrice) per \(offer.weeklyPeriod.perText)"
        guard let trial = offer.freeTrial else { return recurring }
        return "\(trial.adjective) free trial, then \(recurring)"
    }

    static func weeklyDetail(_ offer: PurchaseOffer) -> String {
        "Renews automatically every \(offer.weeklyPeriod.perText) until you cancel."
    }

    static func lifetimePrice(_ offer: PurchaseOffer) -> String {
        "\(offer.lifetimePrice) once"
    }

    static func lifetimeDetail(_ offer: PurchaseOffer) -> String {
        offer.lifetimeIsFamilyShareable
            ? "One payment, nothing renews. Includes Family Sharing."
            : "One payment, nothing renews."
    }

    static func buttonTitle(for product: PurchaseProduct, offer: PurchaseOffer) -> String {
        switch product {
        case .weekly:
            if let trial = offer.freeTrial {
                return "Start \(trial.adjective.capitalized) Free Trial"
            }
            return "Subscribe for \(offer.weeklyPrice) per \(offer.weeklyPeriod.perText)"
        case .lifetime:
            return "Buy Lifetime for \(offer.lifetimePrice)"
        }
    }

    /// The terms of the selected plan, spelled out next to the button.
    static func disclosure(for product: PurchaseProduct, offer: PurchaseOffer) -> String {
        switch product {
        case .weekly:
            let renewal = "the subscription renews automatically at \(offer.weeklyPrice) per \(offer.weeklyPeriod.perText) until you cancel. Cancel any time in your Apple Account settings, at least a day before it renews."
            if let trial = offer.freeTrial {
                return "The free trial lasts \(trial.value) \(trial.unit.rawValue)\(trial.value == 1 ? "" : "s"). After that, \(renewal)"
            }
            return renewal.prefix(1).uppercased() + renewal.dropFirst()
        case .lifetime:
            return "One payment of \(offer.lifetimePrice). It is not a subscription and never renews."
        }
    }
}

/// Full-width label for the purchase buttons, with a spinner while busy.
struct PurchaseButtonLabel: View {
    let title: String
    var isBusy = false

    var body: some View {
        ZStack {
            Text(title).opacity(isBusy ? 0 : 1)
            if isBusy { ProgressView().tint(Theme.onAccent) }
        }
        .font(.headline)
        .foregroundStyle(Theme.onAccent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}
