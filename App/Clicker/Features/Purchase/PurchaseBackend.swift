import Foundation
import StoreKit

/// What the purchase screens need to know about the products before they can
/// make an offer. The price is always the App Store's own localized string.
struct PurchaseOffer: Equatable, Sendable {
    /// Localized price of the full unlock, e.g. "$4.99".
    var unlockPrice: String
    /// Whether the unlock is set up for Family Sharing in App Store Connect.
    var unlockIsFamilyShareable: Bool
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
    /// Reads the current entitlements for this Apple Account.
    func ownedPurchases() async -> OwnedPurchases
    func purchase(_ product: PurchaseProduct) async throws -> PurchaseOutcome
    /// Forces a sync with the App Store ("Restore Purchases").
    /// Throws `CancellationError` if the user backs out of the sign-in.
    func restore() async throws
    /// Fires whenever a transaction changes outside a purchase made here:
    /// Ask to Buy approval, a Family Sharing change, a refund, another device.
    func transactionUpdates() -> AsyncStream<Void>
}

/// StoreKit 2 implementation. Stateless: every answer comes from StoreKit.
struct StoreKitPurchaseBackend: PurchaseBackend {
    func loadOffer() async throws -> PurchaseOffer {
        let products = try await Product.products(for: PurchaseProduct.allCases.map(\.rawValue))
        guard products.contains(where: { $0.id == PurchaseProduct.trial.rawValue }),
              let unlock = products.first(where: { $0.id == PurchaseProduct.unlock.rawValue }) else {
            throw PurchaseBackendError.productUnavailable
        }
        return PurchaseOffer(unlockPrice: unlock.displayPrice,
                             unlockIsFamilyShareable: unlock.isFamilyShareable)
    }

    func ownedPurchases() async -> OwnedPurchases {
        var owned = OwnedPurchases()
        // currentEntitlements already leaves out refunded and revoked
        // purchases, and includes ones shared through Family Sharing.
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil else { continue }
            switch PurchaseProduct(rawValue: transaction.productID) {
            case .trial:
                // The trial clock: the App Store's record of when the trial
                // was first started. Survives delete-and-reinstall.
                let startedAt = transaction.originalPurchaseDate
                owned.trialStartedAt = min(owned.trialStartedAt ?? startedAt, startedAt)
            case .unlock:
                owned.isUnlocked = true
            case nil:
                continue
            }
        }
        return owned
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

    func transactionUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let listener = Task.detached(priority: .background) {
                for await result in Transaction.updates {
                    if case .verified(let transaction) = result {
                        await transaction.finish()
                    }
                    continuation.yield()
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in listener.cancel() }
        }
    }
}
