import Foundation

/// The two in-app purchases behind Clicker's paid path: a weekly
/// auto-renewable subscription (with a free trial as its introductory offer)
/// and a one-time lifetime unlock. The identifiers must match App Store
/// Connect and Support/Clicker.storekit.
enum PurchaseProduct: String, CaseIterable, Sendable {
    case weekly = "com.catchergriffin.clicker.weekly"
    case lifetime = "com.catchergriffin.clicker.unlock"
}

/// How much of the remote can be used before the paywall appears.
enum FreePreview {
    /// Key presses the Roku has accepted before a plan is needed. Long enough
    /// that nobody is asked to pay before seeing their TV respond.
    static let keyPressAllowance = 10
}

/// The weekly subscription as StoreKit reports it, reduced to plain values.
struct SubscriptionRecord: Equatable, Sendable {
    enum State: Equatable, Sendable {
        /// Paid up (or inside the free trial).
        case subscribed
        /// A renewal failed; Apple is still giving the customer time to fix it.
        case inGracePeriod
        /// A renewal failed and Apple is retrying the charge.
        case inBillingRetry
        /// Ended: cancelled, or billing never recovered.
        case expired
        /// Refunded, or taken away by Family Sharing.
        case revoked
    }

    var state: State
    /// True while the current period is the free introductory trial.
    var isInFreeTrial = false
    /// End of the period paid for so far: the next renewal date when it will
    /// renew, the last day of access when it will not.
    var currentPeriodEnds: Date?
    /// False once the customer has cancelled.
    var willAutoRenew = true

    /// Whether this subscription unlocks the app right now. Grace period and
    /// billing retry count: a failed card should not switch the remote off.
    var isActive: Bool {
        switch state {
        case .subscribed, .inGracePeriod, .inBillingRetry: return true
        case .expired, .revoked: return false
        }
    }

    /// True when a renewal failed and the customer needs to fix their payment.
    var hasBillingIssue: Bool {
        state == .inGracePeriod || state == .inBillingRetry
    }
}

/// What the App Store says this Apple Account owns. Built only from StoreKit,
/// never from anything saved on the device.
struct OwnedPurchases: Equatable, Sendable {
    /// True when the lifetime unlock is owned (bought here or Family Shared).
    var ownsLifetime = false
    /// The weekly subscription's latest standing, if there ever was one.
    var subscription: SubscriptionRecord?
}

/// What the app is allowed to do right now. Drives all purchase UI.
enum Access: Equatable, Sendable {
    /// StoreKit has not answered yet (first moments after launch).
    case loading
    /// Nothing owned: the remote works until the free key presses run out.
    /// `lapsed` is true when a subscription existed and has ended.
    case notEntitled(lapsed: Bool)
    /// Weekly subscription active: free trial, paid, or riding out a billing
    /// problem.
    case subscribed(SubscriptionRecord)
    /// Lifetime unlock owned. Forever.
    case lifetime

    /// Whether the remote may be used without limit.
    var isUnlocked: Bool {
        switch self {
        case .subscribed, .lifetime: return true
        case .loading, .notEntitled: return false
        }
    }
}

/// The entitlement rules, as a pure function of what is owned.
enum EntitlementPolicy {
    static func access(for owned: OwnedPurchases) -> Access {
        // Lifetime always wins, whatever state a subscription is in.
        if owned.ownsLifetime { return .lifetime }
        guard let subscription = owned.subscription else {
            return .notEntitled(lapsed: false)
        }
        return subscription.isActive ? .subscribed(subscription) : .notEntitled(lapsed: true)
    }
}
