//
//  ProFeaturesSectionView.swift
//  nightguard
//
//  Created by Gemini on 2026-01-15.
//

import SwiftUI

struct ProFeaturesSectionView: View {

    @ObservedObject var purchaseManager: PurchaseManager
    @Binding var showProPromotion: Bool

    var body: some View {
        Section(header: 
            HStack {
                Text(NSLocalizedString("Pro Features", comment: "Pro Features Section Header"))
                Spacer()
                Button(action: {
                    showProPromotion = true
                    UserDefaultsRepository.markProPromotionSeen()
                }) {
                    Image(systemName: "questionmark.circle")
                }
            }
        ) {
            if purchaseManager.hasProFeatureAccess {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text(purchaseManager.isMaxAccessAvailable
                         ? NSLocalizedString("Pro Features Included", comment: "Pro features included with Max text")
                         : NSLocalizedString("Pro Version Unlocked", comment: "Pro Version Unlocked Text"))
                }
                if purchaseManager.isMaxAccessAvailable {
                    HStack {
                        Image(systemName: "bolt.badge.checkmark.fill")
                            .foregroundColor(.green)
                        Text(NSLocalizedString("Max Subscription Active", comment: "Max subscription active text"))
                    }
                } else {
                    Button(action: {
                        purchaseManager.buyMaxVersion()
                    }) {
                        Text(NSLocalizedString("Upgrade to Max", comment: "Upgrade to Max Button"))
                    }
                }
                Link(NSLocalizedString("Manage Subscription", comment: "Link to manage subscription"), destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
            } else {
                Button(action: {
                    showProPromotion = true
                }) {
                    Text(NSLocalizedString("Unlock Pro Version", comment: "Unlock Pro Version Button"))
                }
                Button(action: {
                    purchaseManager.restorePurchases()
                }) {
                    Text(NSLocalizedString("Restore Purchases", comment: "Restore Purchases Button"))
                }
            }
        }
        .alert(NSLocalizedString("Restore Purchases", comment: "Restore Purchases Alert Title"), isPresented: $purchaseManager.showingRestoreAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(purchaseManager.restoreAlertMessage ?? "")
        }
    }
}

#Preview {
    ProFeaturesSectionView(purchaseManager: PurchaseManager.shared, showProPromotion: .constant(false))
}
