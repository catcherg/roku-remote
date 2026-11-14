import Foundation
import SwiftUI

/// Source of truth for "may this person use the remote?". Free download,
/// 7-day trial, then a one-time unlock.
///
/// Nothing here is persisted on the device. The trial clock is the purchase
/// date of the $0 trial transaction, read from StoreKit every time, so
/// deleting and reinstalling Clicker cannot restart a trial.
@MainActor
final class EntitlementStore: ObservableObject {
    /// Whether the product details needed to make an offer are available.
    enum OfferState: Equatable {
        case loading
        case ready(PurchaseOffer)
        /// The App Store could not be reached, or a product is missing.
        case unavailable
    }

    /// The one purchase action in flight, if any. Drives spinners.
    enum Activity: Equatable {
        case startingTrial, unlocking, restoring
    }

    /// Something worth telling the user after an action finished.
    enum Notice: Equatable {
        case pendingApproval, purchaseFailed, nothingToRestore, restoreFailed
    }

    @Published private(set) var access: Access = .loading
    @Published private(set) var offer: OfferState = .loading
    @Published private(set) var activity: Activity?
    @Published var notice: Notice?

    /// Localized unlock price, once the App Store has answered.
    var unlockPrice: String? {
        if case .ready(let details) = offer { return details.unlockPrice }
        return nil
    }

    private let backend: PurchaseBackend
    private let now: () -> Date
    private var owned: OwnedPurchases?
    private var updatesTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?
    private var offerLoad: Task<PurchaseOffer?, Never>?

    /// - Parameter now: injectable clock, so tests (and the Debug-only launch
    ///   arguments in DebugPurchaseBackend.swift) can move time without
    ///   waiting a week.
    init(backend: PurchaseBackend = StoreKitPurchaseBackend(),
         now: @escaping () -> Date = Date.init) {
        self.backend = backend
        self.now = now
        // Listen from the first moment so no update is missed: Ask to Buy
        // approvals, refunds, Family Sharing changes, purchases elsewhere.
        let updates = backend.transactionUpdates()
        updatesTask = Task { [weak self] in
            for await _ in updates {
                await self?.refresh()
            }
        }
    }

    deinit {
        updatesTask?.cancel()
        clockTask?.cancel()
    }

    // MARK: - Loading

    /// Call once at launch: resolves access and fetches the products.
    func load() async {
        await refresh()
        await loadOffer()
    }

    /// Re-reads the owned purchases from StoreKit and re-derives access.
    func refresh() async {
        owned = await backend.ownedPurchases()
        reevaluate()
    }

    /// Re-derives access from what is already known and the current time.
    /// Cheap; call when the app returns to the foreground.
    func reevaluate() {
        guard let owned else { return }
        let resolved = TrialPolicy.access(for: owned, now: now())
        if resolved != access {
            access = resolved
            notice = nil // whatever it said is out of date now
        }
        scheduleClockCheck(for: owned)
    }

    /// Fetches the products (and so the price). Safe to call again to retry;
    /// screens that ask at the same time share one request.
    func loadOffer() async {
        if case .ready = offer { return }
        if offerLoad == nil {
            offer = .loading
            offerLoad = Task { [backend] in try? await backend.loadOffer() }
        }
        let loaded = await offerLoad?.value ?? nil
        offerLoad = nil
        offer = loaded.map(OfferState.ready) ?? .unavailable
    }

    // MARK: - Actions

    /// Starts the free trial by "buying" the $0 trial product.
    func startTrial() async {
        await purchase(.trial, as: .startingTrial)
    }

    /// Buys the one-time full unlock.
    func unlock() async {
        await purchase(.unlock, as: .unlocking)
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
            if access == before, access != .unlocked { notice = .nothingToRestore }
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

    // MARK: - Trial clock

    /// While a trial is running, wake up when the day count drops or the trial
    /// ends, so the paywall appears even if the app stays open.
    private func scheduleClockCheck(for owned: OwnedPurchases) {
        clockTask?.cancel()
        guard let seconds = TrialPolicy.secondsUntilNextChange(for: owned, now: now()) else {
            clockTask = nil
            return
        }
        clockTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((seconds + 1) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.reevaluate()
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
