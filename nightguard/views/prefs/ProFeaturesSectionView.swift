//
//  ProFeaturesSectionView.swift
//  nightguard
//
//  Created by Gemini on 2026-01-15.
//

import SwiftUI

struct ProFeaturesSectionView: View {
    @ObservedObject var purchaseManager: PurchaseManager
    
    var body: some View {
        Section(header: Text(NSLocalizedString("Pro Features", comment: "Pro Features Section Header"))) {
            if purchaseManager.isProAccessAvailable {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text(NSLocalizedString("Pro Version Unlocked", comment: "Pro Version Unlocked Text"))
                }
            } else {
                Button(action: {
                    purchaseManager.buyProVersion()
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
    }
}