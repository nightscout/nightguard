//
//  PurchaseManager.swift
//  nightguard
//
//  Created by Gemini on 2026-01-15.
//

import Foundation
import StoreKit

class PurchaseManager: NSObject, ObservableObject {
    
    static let shared = PurchaseManager()
    
    let proProductIdentifier = "app.hermanns.nightguard.pro"
    
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
    @Published var products: [SKProduct] = []
    
    @Published var restoreAlertMessage: String?
    @Published var showingRestoreAlert = false
    
    private var isRestoring = false
    
    private override init() {
        super.init()
        SKPaymentQueue.default().add(self)
        fetchProducts()
        validateReceipt() // Check subscription status on launch
    }
    
    deinit {
        SKPaymentQueue.default().remove(self)
    }
    
    func fetchProducts() {
        let request = SKProductsRequest(productIdentifiers: [proProductIdentifier])
        request.delegate = self
        request.start()
    }
    
    func buyProVersion() {
        guard let product = products.first(where: { $0.productIdentifier == proProductIdentifier }) else {
            print("Product not found")
            return
        }
        
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    func restorePurchases() {
        isRestoring = true
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    private func updateProStatus(active: Bool) {
        DispatchQueue.main.async {
            if self.isProAccessAvailable != active {
                self.isProAccessAvailable = active
                UserDefaults.standard.set(active, forKey: self.proProductIdentifier)
                
                if active {
                    self.rescheduleAllAgeNotifications()
                } else {
                    // Optionally cancel notifications if subscription expired
                    // AlarmNotificationService.singleton.cancelAgeNotifications()
                }
            }
            
            if self.isRestoring {
                self.isRestoring = false
                if !active {
                     self.restoreAlertMessage = NSLocalizedString("No active subscription found to restore.", comment: "Restore error message")
                     self.showingRestoreAlert = true
                } else {
                     self.restoreAlertMessage = NSLocalizedString("Purchases restored successfully.", comment: "Restore success message")
                     self.showingRestoreAlert = true
                }
            }
        }
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
    
    func validateReceipt() {
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: appStoreReceiptURL.path) else {
            print("No receipt found")
            updateProStatus(active: false)
            return
        }
        
        do {
            let receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
            let receiptString = receiptData.base64EncodedString(options: [])
            
            // First check Sandbox, then Production if needed
            verifyReceipt(receiptString: receiptString, url: URL(string: "https://sandbox.itunes.apple.com/verifyReceipt")!)
        } catch {
            print("Couldn't read receipt data with error: " + error.localizedDescription)
            updateProStatus(active: false)
        }
    }
    
    private func verifyReceipt(receiptString: String, url: URL) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestDictionary = ["receipt-data": receiptString, "password": sharedSecret]
        
        guard let requestData = try? JSONSerialization.data(withJSONObject: requestDictionary) else { return }
        request.httpBody = requestData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Receipt validation error: \(error)")
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                return
            }
            
            if let status = json["status"] as? Int {
                if status == 0 {
                    // Valid receipt
                    self.parseReceiptResponse(json)
                } else if status == 21007 {
                    // Sandbox receipt sent to Production environment, retry with Sandbox
                    self.verifyReceipt(receiptString: receiptString, url: URL(string: "https://sandbox.itunes.apple.com/verifyReceipt")!)
                } else if status == 21008 {
                    // Production receipt sent to Sandbox, retry with Production
                    self.verifyReceipt(receiptString: receiptString, url: URL(string: "https://buy.itunes.apple.com/verifyReceipt")!)
                } else {
                    print("Receipt verification failed with status: \(status)")
                    self.updateProStatus(active: false)
                }
            }
        }
        task.resume()
    }
    
    private func parseReceiptResponse(_ json: [String: Any]) {
        guard let latestReceiptInfo = json["latest_receipt_info"] as? [[String: Any]] else {
            // No subscription info found
            updateProStatus(active: false)
            return
        }
        
        // Find the subscription for our product ID
        let subscriptionInfo = latestReceiptInfo.filter {
            ($0["product_id"] as? String) == proProductIdentifier
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
            
            // Check if active
            if expiresDate > Date() {
                print("Subscription active. Expires: \(expiresDate)")
                updateProStatus(active: true)
            } else {
                print("Subscription expired on: \(expiresDate)")
                updateProStatus(active: false)
            }
        } else {
            updateProStatus(active: false)
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
                validateReceipt() // Validate to unlock
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
        validateReceipt()
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
