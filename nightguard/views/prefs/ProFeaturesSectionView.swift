//
//  ProFeaturesSectionView.swift
//  nightguard
//
//  Created by Gemini on 2026-01-15.
//

import SwiftUI

struct ProFeaturesSectionView: View {

    @ObservedObject var purchaseManager: PurchaseManager
    @Binding var promotionFocus: PromotionFocus?

    var body: some View {
        Section(header: 
            HStack {
                Text(NSLocalizedString("Pro Features", comment: "Pro Features Section Header"))
                Spacer()
                Button(action: {
                    promotionFocus = .pro
                    UserDefaultsRepository.markProPromotionSeen()
                }) {
                    Image(systemName: "questionmark.circle")
                }
            }
        ) {
            if !purchaseManager.isMaxStatusResolved && !purchaseManager.hasProFeatureAccess {
                ProgressView()
            } else if purchaseManager.hasProFeatureAccess {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text(purchaseManager.isMaxAccessAvailable
                         ? NSLocalizedString("Pro Features Included", comment: "Pro features included with Max text")
                         : NSLocalizedString("Pro Subscription Active", comment: "Pro subscription active text"))
                }
                if purchaseManager.isMaxAccessAvailable {
                    HStack {
                        Image(systemName: "bolt.badge.checkmark.fill")
                            .foregroundColor(.green)
                        Text(NSLocalizedString("Max Subscription Active", comment: "Max subscription active text"))
                    }
                    if let nextRefresh = purchaseManager.nextMaxRefreshAt {
                        HStack(alignment: .firstTextBaseline) {
                            Text(NSLocalizedString("Next Subscription Refresh", comment: "Next Max subscription refresh label"))
                            Spacer(minLength: 8)
                            Text(nextRefresh, format: .dateTime.weekday(.wide).day().month(.abbreviated).hour().minute())
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                        .font(.footnote)
                    }
                } else if purchaseManager.isMaxStatusResolved {
                    Button(action: {
                        promotionFocus = .max
                    }) {
                        Text(NSLocalizedString("Upgrade to Max", comment: "Upgrade to Max Button"))
                    }
                }
                Link(NSLocalizedString("Manage Subscription", comment: "Link to manage subscription"), destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
            } else {
                Button(action: {
                    promotionFocus = .pro
                }) {
                    Text(NSLocalizedString("Unlock Pro Version", comment: "Unlock Pro Version Button"))
                }
                Button(action: {
                    promotionFocus = .max
                }) {
                    Text(NSLocalizedString("Subscribe to Max", comment: "Subscribe to Max Button"))
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
    ProFeaturesSectionView(
        purchaseManager: PurchaseManager.shared,
        promotionFocus: .constant(.pro)
    )
}
