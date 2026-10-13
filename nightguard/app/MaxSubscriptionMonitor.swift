import Foundation
import StoreKit

/// Only written after StoreKit verification. The legacy Boolean is never an entitlement.
struct MaxSubscriptionCache: Codable {
    static let key = "maxVerifiedSubscription.v1"
    let transactionID: String
    let expiresAt: Date

    func isActive(at date: Date) -> Bool { expiresAt > date }

    static func load(from defaults: UserDefaults) -> Self? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
}

struct MaxSubscriptionTransaction {
    static let productID = "app.hermanns.nightguard.max"
    let productID: String
    let transactionID: String
    let expiresAt: Date?
    let revoked: Bool
    let upgraded: Bool
    let jws: String

    func isActive(at date: Date) -> Bool {
        productID == Self.productID && !revoked && !upgraded && (expiresAt.map { $0 > date } ?? false)
    }
}

/// Owns the Max entitlement and the exact signed transaction used for registration.
/// Its clock, storage and StoreKit reader are injectable for deterministic tests.
@MainActor
final class MaxSubscriptionMonitor {
    static let refreshInterval: TimeInterval = 15 * 60
    private let defaults: UserDefaults
    private let now: () -> Date
    private let readTransactions: () async throws -> [MaxSubscriptionTransaction]
    private let didRefresh: () -> Void
    private(set) var cache: MaxSubscriptionCache?
    private(set) var transaction: MaxSubscriptionTransaction?
    private(set) var hasResolvedStatus = false
    private(set) var lastCheckFailed = false
    private(set) var lastCheckedAt: Date?
    private var refreshTask: Task<Void, Never>?
    private var refreshAgain = false

    var isActive: Bool { cache?.isActive(at: now()) == true }
    var currentJWS: String? {
        guard let transaction, transaction.isActive(at: now()) else { return nil }
        return transaction.jws
    }

    init(defaults: UserDefaults = .standard,
         now: @escaping () -> Date = Date.init,
         readTransactions: @escaping () async throws -> [MaxSubscriptionTransaction] = MaxSubscriptionMonitor.storeKitTransactions,
         didRefresh: @escaping () -> Void = {}) {
        self.defaults = defaults
        self.now = now
        self.readTransactions = readTransactions
        self.didRefresh = didRefresh
        cache = MaxSubscriptionCache.load(from: defaults)
    }

    func refresh(force: Bool = false) async {
        if let refreshTask {
            // A purchase/update arriving during enumeration needs one fresh pass.
            refreshAgain = refreshAgain || force
            await refreshTask.value
            return
        }
        if !force, let lastCheckedAt,
           now() >= lastCheckedAt, now().timeIntervalSince(lastCheckedAt) < Self.refreshInterval {
            return
        }
        let task = Task { @MainActor in
            repeat {
                self.refreshAgain = false
                do {
                    let transactions = try await self.readTransactions()
                    let checkedAt = self.now()
                    self.transaction = transactions.filter { $0.isActive(at: checkedAt) }
                        .max { ($0.expiresAt ?? .distantPast) < ($1.expiresAt ?? .distantPast) }
                    self.cache = self.transaction.flatMap { transaction in
                        transaction.expiresAt.map {
                            MaxSubscriptionCache(transactionID: transaction.transactionID, expiresAt: $0)
                        }
                    }
                    if let cache = self.cache, let data = try? JSONEncoder().encode(cache) {
                        self.defaults.set(data, forKey: MaxSubscriptionCache.key)
                    } else {
                        self.defaults.removeObject(forKey: MaxSubscriptionCache.key)
                    }
                    self.hasResolvedStatus = true
                    self.lastCheckFailed = false
                } catch {
                    // An unverifiable result is not proof of expiry. Never extend the
                    // previously verified period, nor register using unverified data.
                    self.hasResolvedStatus = self.hasResolvedStatus || self.cache != nil
                    self.lastCheckFailed = true
                }
                self.lastCheckedAt = self.now()
                self.didRefresh()
            } while self.refreshAgain
            self.refreshTask = nil
        }
        refreshTask = task
        await task.value
    }

    static func storeKitTransactions() async throws -> [MaxSubscriptionTransaction] {
        var transactions: [MaxSubscriptionTransaction] = []
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                guard transaction.productID == MaxSubscriptionTransaction.productID else { continue }
                transactions.append(MaxSubscriptionTransaction(
                    productID: transaction.productID,
                    transactionID: String(transaction.id),
                    expiresAt: transaction.expirationDate,
                    revoked: transaction.revocationDate != nil,
                    upgraded: transaction.isUpgraded,
                    jws: result.jwsRepresentation
                ))
            case .unverified(let transaction, _):
                if transaction.productID == MaxSubscriptionTransaction.productID {
                    throw VerificationError.unverifiedMaxTransaction
                }
            }
        }
        return transactions
    }

    private enum VerificationError: Error { case unverifiedMaxTransaction }
}
