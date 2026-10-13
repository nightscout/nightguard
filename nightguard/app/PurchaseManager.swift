//
//  PurchaseManager.swift
//  nightguard
//
//  Created by Gemini on 2026-01-15.
//

import Foundation
import StoreKit
#if os(iOS) && MAIN_APP
import UIKit
#endif

class PurchaseManager: NSObject, ObservableObject {
    
    static let shared = PurchaseManager(defaults: .standard, observeStoreKit: true)
    
    let proProductIdentifier = "app.hermanns.nightguard.pro"
    let maxProductIdentifier = "app.hermanns.nightguard.max"
    
    private var sharedSecret: String {
        guard let filePath = Bundle.main.path(forResource: ".env", ofType: nil) else {
            print("Error: .env file not found in bundle")
            return ""
        }
        
        do {
            let contents = try String(contentsOfFile: filePath)
            let lines = contents.components(separatedBy: .newlines)
            for line in lines {
                let parts = line.split(separator: "=", maxSplits: 1).map { String($0) }
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if key == "SHARED_SECRET" {
                        return value
                    }
                }
            }
        } catch {
            print("Error reading .env file: \(error)")
        }
        
        return ""
    }
    
    @Published var isProAccessAvailable: Bool = false
    @Published private(set) var isMaxAccessAvailable: Bool = false
    @Published private(set) var isMaxStatusResolved = false
    @Published var products: [SKProduct] = []

    var hasProFeatureAccess: Bool {
        isProAccessAvailable || isMaxAccessAvailable
    }
    
    var formattedProPrice: String? {
        return formattedPrice(for: proProductIdentifier)
    }

    var formattedMaxPrice: String? {
        return formattedPrice(for: maxProductIdentifier)
    }

    private func formattedPrice(for productIdentifier: String) -> String? {
        guard let product = products.first(where: { $0.productIdentifier == productIdentifier }) else {
            return nil
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price)
    }
    
    @Published var restoreAlertMessage: String?
    @Published var showingRestoreAlert = false
    
    private var isRestoring = false
    private var maxUpdatesTask: Task<Void, Never>?
    private var maxRefreshTimer: Timer?
    private let purchaseDefaults: UserDefaults
    private let maxClock: () -> Date
    private let readMaxTransactions: () async throws -> [MaxSubscriptionTransaction]
    private let proValidationOverride: ((@escaping (Bool?) -> Void) -> Void)?
    private let observeStoreKit: Bool

    @MainActor private var maxMonitorStorage: MaxSubscriptionMonitor?
    @MainActor private var maxMonitor: MaxSubscriptionMonitor {
        if let maxMonitorStorage { return maxMonitorStorage }
        let monitor = MaxSubscriptionMonitor(defaults: purchaseDefaults, now: maxClock,
                                             readTransactions: readMaxTransactions,
                                             didRefresh: { [weak self] in self?.handleMaxRefresh() })
        maxMonitorStorage = monitor
        return monitor
    }

    @MainActor
    private func handleMaxRefresh() {
        isMaxStatusResolved = maxMonitor.hasResolvedStatus
        updateSubscriptionStatus(maxActive: maxMonitor.isActive)
        #if os(iOS) && MAIN_APP
        if maxMonitor.lastCheckFailed {
            AppLogger.singleton.warning("Max entitlement verification failed; retaining only the unexpired verified cache", category: .backgroundUpdates)
        }
        #endif
    }

    @MainActor
    func refreshMaxStatusIfNeeded() async {
        await maxMonitor.refresh()
    }

    @MainActor
    func startMaxStatusChecks() {
        maxRefreshTimer?.invalidate()
        Task { await refreshMaxStatusIfNeeded() }
        // Foreground activations only check the due time; frequent switches do not
        // enumerate StoreKit. While continuously active, check every 15 minutes.
        let nextCheck = maxMonitor.lastCheckedAt?.addingTimeInterval(MaxSubscriptionMonitor.refreshInterval) ?? Date()
        let timer = Timer(fireAt: max(nextCheck, Date().addingTimeInterval(1)),
                          interval: MaxSubscriptionMonitor.refreshInterval,
                          target: self, selector: #selector(maxRefreshTimerDidFire),
                          userInfo: nil, repeats: true)
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        maxRefreshTimer = timer
    }

    func stopMaxStatusChecks() {
        maxRefreshTimer?.invalidate()
        maxRefreshTimer = nil
    }

    @objc private func maxRefreshTimerDidFire() {
        Task { @MainActor in await refreshMaxStatusIfNeeded() }
    }

    private func observeMaxTransactions() {
        maxUpdatesTask = Task { @MainActor [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { break }
                guard result.unsafePayloadValue.productID == MaxSubscriptionTransaction.productID else { continue }
                await self?.maxMonitor.refresh(force: true)
                // SKPaymentQueue remains responsible for finishing purchases.
            }
        }
    }
    
    init(defaults: UserDefaults,
         now: @escaping () -> Date = Date.init,
         readMaxTransactions: @escaping () async throws -> [MaxSubscriptionTransaction] = MaxSubscriptionMonitor.storeKitTransactions,
         proValidation: ((@escaping (Bool?) -> Void) -> Void)? = nil,
         observeStoreKit: Bool = false) {
        purchaseDefaults = defaults
        maxClock = now
        self.readMaxTransactions = readMaxTransactions
        proValidationOverride = proValidation
        self.observeStoreKit = observeStoreKit
        self.isProAccessAvailable = defaults.bool(forKey: proProductIdentifier)
        self.isMaxAccessAvailable = MaxSubscriptionCache.load(from: defaults)?.isActive(at: now()) == true
        super.init()
        
        // Ensure initial watch status is in sync with last known state
        if self.hasProFeatureAccess {
            UserDefaultsRepository.watchProAccessAvailable.value = true
        }
        
        if observeStoreKit {
            SKPaymentQueue.default().add(self)
            fetchProducts()
            observeMaxTransactions()
            validateReceipt() // Check subscription status on launch
        }
    }
    
    deinit {
        maxUpdatesTask?.cancel()
        maxRefreshTimer?.invalidate()
        if observeStoreKit { SKPaymentQueue.default().remove(self) }
    }
    
    func fetchProducts() {
        let request = SKProductsRequest(productIdentifiers: [proProductIdentifier, maxProductIdentifier])
        request.delegate = self
        request.start()
    }
    
    func buyProVersion() {
        buy(productIdentifier: proProductIdentifier)
    }

    func buyMaxVersion() {
        buy(productIdentifier: maxProductIdentifier)
    }

    private func buy(productIdentifier: String) {
        guard let product = products.first(where: { $0.productIdentifier == productIdentifier }) else {
            print("Product not found")
            return
        }

        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    func restorePurchases() {
        guard !isRestoring else { return }
        isRestoring = true
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    @MainActor
    private func updateSubscriptionStatus(proActive: Bool? = nil, maxActive: Bool? = nil) {
        let hadProFeatureAccess = hasProFeatureAccess
        let previousMax = isMaxAccessAvailable
        if let proActive {
            isProAccessAvailable = proActive
            purchaseDefaults.set(proActive, forKey: proProductIdentifier)
        }
        if let maxActive {
            isMaxAccessAvailable = maxActive
            // Kept for compatibility, but never read as proof of Max access.
            purchaseDefaults.set(maxActive, forKey: maxProductIdentifier)
        }
        // Do not revoke Watch access because the initial Max check is still pending.
        if isMaxStatusResolved || hasProFeatureAccess {
            UserDefaultsRepository.watchProAccessAvailable.value = hasProFeatureAccess
        }
        if hadProFeatureAccess != hasProFeatureAccess {
            NotificationCenter.default.post(name: NSNotification.Name("ProAccessStatusChanged"), object: nil)
            if observeStoreKit && hasProFeatureAccess { rescheduleAllAgeNotifications() }
        }
        if previousMax != isMaxAccessAvailable {
            NotificationCenter.default.post(name: NSNotification.Name("MaxAccessStatusChanged"), object: nil)
        }
        #if os(iOS) && MAIN_APP
        if observeStoreKit && isMaxStatusResolved {
            MaxBackgroundPushRegistrationService.shared.configureForCurrentEntitlement()
        }
        #endif
    }

    private func rescheduleAllAgeNotifications() {
        let cannulaDate = NightscoutCacheService.singleton.getCannulaChangeTime()
        let sensorDate = NightscoutCacheService.singleton.getSensorChangeTime()
        let batteryDate = NightscoutCacheService.singleton.getPumpBatteryChangeTime()
        
        AlarmNotificationService.singleton.scheduleCannulaNotification(changeDate: cannulaDate)
        AlarmNotificationService.singleton.scheduleSensorNotification(changeDate: sensorDate)
        AlarmNotificationService.singleton.scheduleBatteryNotification(changeDate: batteryDate)
    }
    
    // MARK: - Receipt Validation
    
    func validateReceipt(completion: ((Bool) -> Void)? = nil) {
        Task { @MainActor in
            let maxRefresh = Task { @MainActor in await self.maxMonitor.refresh(force: true) }
            validateProReceipt { proActive in
                Task { @MainActor in
                    await maxRefresh.value
                    if let proActive { self.updateSubscriptionStatus(proActive: proActive) }
                    completion?(proActive == true || (proActive != nil && !self.maxMonitor.lastCheckFailed))
                }
            }
        }
    }

    // Legacy receipts remain responsible for Pro only. Every completion path is
    // reported, so restoring cannot hang or complete before the Max check.
    private func validateProReceipt(completion: @escaping (Bool?) -> Void) {
        if let proValidationOverride {
            proValidationOverride(completion)
            return
        }
        guard let url = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: url.path) else {
            completion(false)
            return
        }
        do {
            let receipt = try Data(contentsOf: url, options: .alwaysMapped).base64EncodedString()
            verifyReceipt(receiptString: receipt,
                          url: URL(string: "https://sandbox.itunes.apple.com/verifyReceipt")!,
                          completion: completion)
        } catch {
            completion(false)
        }
    }

    private func verifyReceipt(receiptString: String, url: URL, redirectsRemaining: Int = 1,
                               completion: @escaping (Bool?) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        guard let data = try? JSONSerialization.data(withJSONObject: ["receipt-data": receiptString, "password": sharedSecret]) else {
            completion(nil)
            return
        }
        request.httpBody = data
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil, let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode), let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? Int else {
                completion(nil)
                return
            }
            if status == 0 {
                let receiptInfo = json["latest_receipt_info"] as? [[String: Any]] ?? []
                completion(self.isSubscriptionActive(productIdentifier: self.proProductIdentifier, latestReceiptInfo: receiptInfo))
            } else if (status == 21007 || status == 21008), redirectsRemaining > 0 {
                let host = status == 21007 ? "sandbox.itunes.apple.com" : "buy.itunes.apple.com"
                self.verifyReceipt(receiptString: receiptString, url: URL(string: "https://\(host)/verifyReceipt")!,
                                   redirectsRemaining: redirectsRemaining - 1, completion: completion)
            } else {
                completion(false)
            }
        }.resume()
    }

    private func isSubscriptionActive(productIdentifier: String, latestReceiptInfo: [[String: Any]]) -> Bool {
        let subscriptionInfo = latestReceiptInfo.filter {
            ($0["product_id"] as? String) == productIdentifier
        }.sorted {
            // Sort by expiry date (newest first)
            guard let d1 = $0["expires_date_ms"] as? String, let t1 = Double(d1),
                  let d2 = $1["expires_date_ms"] as? String, let t2 = Double(d2) else { return false }
            return t1 > t2
        }.first

        if let currentSubscription = subscriptionInfo,
           let expiresDateMs = currentSubscription["expires_date_ms"] as? String,
           let expiresDateDouble = Double(expiresDateMs) {

            let expiresDate = Date(timeIntervalSince1970: expiresDateDouble / 1000.0)
            print("Subscription \(productIdentifier) expires: \(expiresDate)")
            return expiresDate > Date()
        }

        return false
    }

    @MainActor
    func currentMaxTransactionJWS() async throws -> String {
        // Do not run a second, independent entitlement check for registration.
        guard isMaxStatusResolved, let jws = maxMonitor.currentJWS else {
            throw MaxTransactionError.unavailable
        }
        return jws
    }

    enum MaxTransactionError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            return "No active Max StoreKit transaction is available"
        }
    }
}

extension PurchaseManager: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            self.products = response.products
        }
    }
}

extension PurchaseManager: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                SKPaymentQueue.default().finishTransaction(transaction)
                validateReceipt() // Validate to unlock
            case .restored:
                SKPaymentQueue.default().finishTransaction(transaction)
                if !isRestoring { validateReceipt() }
            case .failed:
                SKPaymentQueue.default().finishTransaction(transaction)
            case .deferred, .purchasing:
                break
            @unknown default:
                break
            }
        }
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        validateReceipt { [weak self] succeeded in
            guard let self, self.isRestoring else { return }
            self.isRestoring = false
            self.restoreAlertMessage = succeeded
                ? (self.hasProFeatureAccess
                   ? NSLocalizedString("Purchases restored successfully.", comment: "Restore success message")
                   : NSLocalizedString("No active subscription found to restore.", comment: "Restore error message"))
                : NSLocalizedString("Unable to verify purchases. Please try again.", comment: "Restore verification failure")
            self.showingRestoreAlert = true
        }
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        print("Restore failed: \(error.localizedDescription)")
        if isRestoring {
            isRestoring = false
            DispatchQueue.main.async {
                self.restoreAlertMessage = String(format: NSLocalizedString("Restore failed: %@", comment: "Restore failed error"), error.localizedDescription)
                self.showingRestoreAlert = true
            }
        }
    }
}
