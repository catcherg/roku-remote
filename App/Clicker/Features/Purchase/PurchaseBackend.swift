import Foundation
import StoreKit

/// A subscription or trial length, e.g. one week or three days.
struct BillingPeriod: Equatable, Sendable {
    enum Unit: String, Equatable, Sendable {
        case day, week, month, year
    }

    var value: Int
    var unit: Unit

    /// StoreKit sometimes reports a week as seven days; say "week".
    init(value: Int, unit: Unit) {
        if unit == .day, value > 0, value % 7 == 0 {
            self.value = value / 7
            self.unit = .week
        } else {
            self.value = value
            self.unit = unit
        }
    }

    /// For "$6.99 per week": "week", or "2 weeks".
    var perText: String {
        value == 1 ? unit.rawValue : "\(value) \(unit.rawValue)s"
    }

    /// For "3-day free trial": "3-day", "1-week".
    var adjective: String {
        "\(value)-\(unit.rawValue)"
    }
}

/// What the purchase screens need to know about the products before they can
/// make an offer. Every price and period is the App Store's own.
struct PurchaseOffer: Equatable, Sendable {
    /// Localized price of one subscription period, e.g. "$6.99".
    var weeklyPrice: String
    /// How often the subscription renews.
    var weeklyPeriod: BillingPeriod
    /// Length of the free trial, or nil when there is none on offer — either
    /// none is configured or this Apple Account has already used it.
    var freeTrial: BillingPeriod?
    /// Localized price of the lifetime unlock, e.g. "$24.99".
    var lifetimePrice: String
    /// Whether the lifetime unlock is set up for Family Sharing.
    var lifetimeIsFamilyShareable: Bool
}

enum PurchaseOutcome: Equatable, Sendable {
    case purchased
    /// Ask to Buy or similar: arrives later through the transaction updates.
    case pending
    case cancelled
}

enum PurchaseBackendError: Error {
    /// The App Store did not return one of the two products.
    case productUnavailable
    /// StoreKit could not verify the transaction's signature.
    case unverified
}

/// The seam between the entitlement logic and StoreKit, so the logic can be
/// unit-tested against an in-memory App Store.
protocol PurchaseBackend: Sendable {
    /// Loads both products. Throws if the App Store cannot be reached or a
    /// product is missing.
    func loadOffer() async throws -> PurchaseOffer
    /// Reads what this Apple Account owns right now.
    func ownedPurchases() async -> OwnedPurchases
    func purchase(_ product: PurchaseProduct) async throws -> PurchaseOutcome
    /// Forces a sync with the App Store ("Restore Purchases").
    /// Throws `CancellationError` if the user backs out of the sign-in.
    func restore() async throws
    /// Fires whenever something changes outside a purchase made here: a
    /// renewal, a lapse, Ask to Buy approval, a refund, another device.
    func purchaseUpdates() -> AsyncStream<Void>
}

/// StoreKit 2 implementation. Stateless: every answer comes from StoreKit.
struct StoreKitPurchaseBackend: PurchaseBackend {
    func loadOffer() async throws -> PurchaseOffer {
        let products = try await Product.products(for: PurchaseProduct.allCases.map(\.rawValue))
        guard let weekly = products.first(where: { $0.id == PurchaseProduct.weekly.rawValue }),
              let subscription = weekly.subscription,
              let lifetime = products.first(where: { $0.id == PurchaseProduct.lifetime.rawValue }) else {
            throw PurchaseBackendError.productUnavailable
        }

        // Only promise a free trial this Apple Account can actually get.
        var freeTrial: BillingPeriod?
        if let intro = subscription.introductoryOffer, intro.paymentMode == .freeTrial,
           await subscription.isEligibleForIntroOffer {
            freeTrial = BillingPeriod(intro.period)
        }
        return PurchaseOffer(
            weeklyPrice: weekly.displayPrice,
            weeklyPeriod: BillingPeriod(subscription.subscriptionPeriod),
            freeTrial: freeTrial,
            lifetimePrice: lifetime.displayPrice,
            lifetimeIsFamilyShareable: lifetime.isFamilyShareable
        )
    }

    func ownedPurchases() async -> OwnedPurchases {
        var owned = OwnedPurchases()
        var entitledSubscription: Transaction?
        // currentEntitlements already leaves out refunded and expired
        // purchases, and includes ones shared through Family Sharing.
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil else { continue }
            switch PurchaseProduct(rawValue: transaction.productID) {
            case .lifetime: owned.ownsLifetime = true
            case .weekly: entitledSubscription = transaction
            case nil: continue
            }
        }
        owned.subscription = await subscriptionRecord(entitled: entitledSubscription)
        return owned
    }

    /// The subscription's standing. `currentEntitlements` cannot tell a grace
    /// period or billing retry from a lapse, so this asks the subscription
    /// status, and falls back to the transaction alone when that is not
    /// available (offline, for example).
    private func subscriptionRecord(entitled: Transaction?) async -> SubscriptionRecord? {
        var latest = entitled
        if latest == nil,
           case .verified(let transaction)? = await Transaction.latest(for: PurchaseProduct.weekly.rawValue) {
            latest = transaction
        }
        guard let latest else { return nil } // never subscribed

        if let groupID = latest.subscriptionGroupID,
           let statuses = try? await Product.SubscriptionInfo.status(for: groupID) {
            // One product in the group, but Family Sharing can report more
            // than one status: the best one is what the customer gets.
            let records = statuses.compactMap(Self.record(from:))
            if let best = records.first(where: \.isActive) ?? records.first {
                return best
            }
        }
        return SubscriptionRecord(
            state: entitled == nil ? .expired : .subscribed,
            isInFreeTrial: entitled != nil && latest.offerType == .introductory,
            currentPeriodEnds: latest.expirationDate
        )
    }

    private static func record(from status: Product.SubscriptionInfo.Status) -> SubscriptionRecord? {
        guard case .verified(let transaction) = status.transaction,
              transaction.productID == PurchaseProduct.weekly.rawValue else { return nil }

        let state: SubscriptionRecord.State
        switch status.state {
        case .subscribed: state = .subscribed
        case .inGracePeriod: state = .inGracePeriod
        case .inBillingRetryPeriod: state = .inBillingRetry
        case .revoked: state = .revoked
        default: state = .expired
        }

        var willAutoRenew = true
        var periodEnds = transaction.expirationDate
        if case .verified(let renewal) = status.renewalInfo {
            willAutoRenew = renewal.willAutoRenew
            if state == .inGracePeriod, let graceEnds = renewal.gracePeriodExpirationDate {
                periodEnds = graceEnds
            }
        }
        return SubscriptionRecord(
            state: state,
            isInFreeTrial: state == .subscribed && transaction.offerType == .introductory,
            currentPeriodEnds: periodEnds,
            willAutoRenew: willAutoRenew
        )
    }

    func purchase(_ product: PurchaseProduct) async throws -> PurchaseOutcome {
        guard let storeProduct = try await Product.products(for: [product.rawValue]).first else {
            throw PurchaseBackendError.productUnavailable
        }
        switch try await storeProduct.purchase() {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw PurchaseBackendError.unverified
            }
            await transaction.finish()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func restore() async throws {
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            throw CancellationError()
        }
    }

    func purchaseUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            // New and changed transactions: purchases elsewhere, renewals,
            // refunds, Ask to Buy approvals.
            let transactions = Task.detached(priority: .background) {
                for await result in Transaction.updates {
                    if case .verified(let transaction) = result {
                        await transaction.finish()
                    }
                    continuation.yield()
                }
            }
            // Subscription standing: lapses, grace period, billing retry.
            let statuses = Task.detached(priority: .background) {
                for await _ in Product.SubscriptionInfo.Status.updates {
                    continuation.yield()
                }
            }
            continuation.onTermination = { _ in
                transactions.cancel()
                statuses.cancel()
            }
        }
    }
}

private extension BillingPeriod {
    init(_ period: Product.SubscriptionPeriod) {
        let unit: Unit
        switch period.unit {
        case .day: unit = .day
        case .week: unit = .week
        case .month: unit = .month
        case .year: unit = .year
        @unknown default: unit = .day
        }
        self.init(value: period.value, unit: unit)
    }
}
