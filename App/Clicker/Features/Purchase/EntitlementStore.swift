import Foundation
import SwiftUI

/// What the remote asks before it sends anything to the Roku. Keeps AppState
/// free of purchase logic.
@MainActor
protocol CommandGate: AnyObject {
    /// Asked before every key press. False drops the press.
    func mayPress() -> Bool
    /// Told once the Roku has accepted a key press.
    func didPress()
}

/// Source of truth for "may this person keep using the remote?".
///
/// Free download; the remote works for a handful of key presses, then needs
/// either the weekly subscription (free trial first) or the lifetime unlock.
/// What is owned is read from StoreKit every time and never saved on the
/// device. The only thing kept locally is how many free key presses are used.
@MainActor
final class EntitlementStore: ObservableObject, CommandGate {
    /// Whether the product details needed to make an offer are available.
    enum OfferState: Equatable {
        case loading
        case ready(PurchaseOffer)
        /// The App Store could not be reached, or a product is missing.
        case unavailable
    }

    /// The one purchase action in flight, if any. Drives spinners.
    enum Activity: Equatable {
        case subscribing, buyingLifetime, restoring
    }

    /// Something worth telling the user after an action finished.
    enum Notice: Equatable {
        case pendingApproval, purchaseFailed, nothingToRestore, restoreFailed
    }

    @Published private(set) var access: Access = .loading
    /// The raw standing behind `access`. Settings shows the renewal date from
    /// it, and whether a subscription is still running beside a lifetime unlock.
    @Published private(set) var owned = OwnedPurchases()
    @Published private(set) var offer: OfferState = .loading
    @Published private(set) var activity: Activity?
    @Published var notice: Notice?
    /// Key presses the Roku has accepted without a plan. Stops counting at
    /// the allowance.
    @Published private(set) var freeKeyPressesUsed: Int
    /// Set when a key press was refused because the free presses are used
    /// up. The remote screen answers by showing the paywall.
    @Published var paywallRequested = false

    var freeKeyPressesLeft: Int {
        max(0, FreePreview.keyPressAllowance - freeKeyPressesUsed)
    }

    private static let usedKey = "freeKeyPressesUsed"

    private let backend: PurchaseBackend
    private let defaults: UserDefaults
    private let now: () -> Date
    private var updatesTask: Task<Void, Never>?
    private var periodEndTask: Task<Void, Never>?
    private var offerLoad: Task<PurchaseOffer?, Never>?
    private var offerIsStale = false

    /// - Parameters:
    ///   - defaults: where the count of used free key presses is kept.
    ///   - now: injectable clock, so the Debug stand-in store can be run as
    ///     if it were a later date (see DebugPurchaseBackend.swift).
    init(backend: PurchaseBackend = StoreKitPurchaseBackend(),
         defaults: UserDefaults = .standard,
         now: @escaping () -> Date = Date.init) {
        self.backend = backend
        self.defaults = defaults
        self.now = now
        freeKeyPressesUsed = defaults.integer(forKey: Self.usedKey)
        // Listen from the first moment so no update is missed: renewals,
        // lapses, Ask to Buy approvals, refunds, purchases on other devices.
        let updates = backend.purchaseUpdates()
        updatesTask = Task { [weak self] in
            for await _ in updates {
                await self?.refresh()
            }
        }
    }

    deinit {
        updatesTask?.cancel()
        periodEndTask?.cancel()
    }

    // MARK: - Loading

    /// Call once at launch: resolves access and fetches the products.
    func load() async {
        await refresh()
        await loadOffer()
    }

    /// Re-reads what is owned from StoreKit and re-derives access.
    func refresh() async {
        let latest = await backend.ownedPurchases()
        if latest.subscription != owned.subscription {
            offerIsStale = true // free-trial eligibility may have changed
        }
        owned = latest
        let resolved = EntitlementPolicy.access(for: latest)
        if resolved != access {
            access = resolved
            notice = nil // whatever it said is out of date now
        }
        if resolved.isUnlocked { paywallRequested = false }
        scheduleCheckAtPeriodEnd()
    }

    /// Fetches the products (and so the prices). Safe to call again to retry
    /// or to pick up a change; screens that ask at the same time share one
    /// request, and a known offer stays on screen while it is re-fetched.
    func loadOffer() async {
        if case .ready = offer, !offerIsStale { return }
        if offerLoad == nil {
            if case .ready = offer {} else { offer = .loading }
            offerIsStale = false
            offerLoad = Task { [backend] in try? await backend.loadOffer() }
        }
        let loaded = await offerLoad?.value ?? nil
        offerLoad = nil
        if let loaded {
            offer = .ready(loaded)
        } else if case .ready = offer {
            offerIsStale = true // keep what is shown; try again next time
        } else {
            offer = .unavailable
        }
    }

    // MARK: - Actions

    /// Starts the weekly subscription (with its free trial when eligible).
    func subscribe() async {
        await purchase(.weekly, as: .subscribing)
    }

    /// Buys the one-time lifetime unlock.
    func buyLifetime() async {
        await purchase(.lifetime, as: .buyingLifetime)
    }

    func restore() async {
        guard activity == nil else { return }
        activity = .restoring
        notice = nil
        defer { activity = nil }
        let before = access
        do {
            try await backend.restore()
            await refresh()
            // Say so only when the sync changed nothing on screen.
            if access == before, !access.isUnlocked { notice = .nothingToRestore }
        } catch is CancellationError {
            // User backed out of the App Store sign-in. Nothing to say.
        } catch {
            notice = .restoreFailed
        }
    }

    private func purchase(_ product: PurchaseProduct, as kind: Activity) async {
        guard activity == nil else { return }
        activity = kind
        notice = nil
        defer { activity = nil }
        do {
            switch try await backend.purchase(product) {
            case .purchased:
                await refresh()
            case .pending:
                notice = .pendingApproval
            case .cancelled:
                break
            }
        } catch {
            notice = .purchaseFailed
        }
    }

    // MARK: - Free key presses (CommandGate)

    /// False means the free presses are used up and no plan is owned: the
    /// press is dropped and the paywall is requested instead.
    func mayPress() -> Bool {
        switch access {
        case .subscribed, .lifetime:
            return true
        case .loading:
            // StoreKit has not answered yet. Never hold up a paying customer.
            return true
        case .notEntitled:
            if freeKeyPressesLeft > 0 { return true }
            paywallRequested = true
            return false
        }
    }

    /// Only presses the TV actually received count against the allowance.
    func didPress() {
        guard case .notEntitled = access, freeKeyPressesLeft > 0 else { return }
        freeKeyPressesUsed += 1
        defaults.set(freeKeyPressesUsed, forKey: Self.usedKey)
    }

    // MARK: - Subscription period end

    /// StoreKit announces renewals and lapses, but look again just after the
    /// current period ends in case the app is open at that moment.
    private func scheduleCheckAtPeriodEnd() {
        periodEndTask?.cancel()
        periodEndTask = nil
        guard case .subscribed(let subscription) = access,
              let ends = subscription.currentPeriodEnds else { return }
        let seconds = ends.timeIntervalSince(now())
        guard seconds > 0 else { return }
        periodEndTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((seconds + 2) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }
}

// MARK: - Copy

extension EntitlementStore.Notice {
    var message: String {
        switch self {
        case .pendingApproval:
            return "Waiting for approval. Clicker unlocks as soon as the purchase is approved."
        case .purchaseFailed:
            return "The App Store couldn't complete that. Check your connection and try again."
        case .nothingToRestore:
            return "No Clicker purchase was found for this Apple Account."
        case .restoreFailed:
            return "Couldn't reach the App Store to restore. Check your connection and try again."
        }
    }
}
