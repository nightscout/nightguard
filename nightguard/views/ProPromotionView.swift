//
//  ProPromotionView.swift
//  nightguard
//

import SwiftUI

struct ProPromotionView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var purchaseManager = PurchaseManager.shared
    
    var onRemindLater: () -> Void = {}
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "star.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                        .padding(.top, 20)
                    
                    Text(NSLocalizedString("Support Nightguard", comment: "Pro Promotion Title"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                }
                
                // Philosophy
                VStack(spacing: 12) {
                    Text(NSLocalizedString("The app will always stay free and open source.", comment: "Pro Promotion Philosophy 1"))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Text(NSLocalizedString("You can support the app by subscribing and get some extra features as a goodie!", comment: "Pro Promotion Philosophy 2"))
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Features
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(
                        icon: "bell.badge.fill",
                        title: NSLocalizedString("Pro Notifications", comment: "Pro Feature 1 Title"),
                        description: NSLocalizedString("Push Notifications for Cannula Age, Battery Age, Sensor Age and Reservoir capacity.", comment: "Pro Feature 1 Description")
                    )
                    
                    FeatureRow(
                        icon: "app.badge.fill",
                        title: NSLocalizedString("Live Activities", comment: "Pro Feature 2 Title"),
                        description: NSLocalizedString("Support for the dynamic island and live activities to see your BG at a glance.", comment: "Pro Feature 2 Description")
                    )
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Actions
                VStack(spacing: 12) {
                    if !purchaseManager.isProAccessAvailable {
                        Button(action: {
                            purchaseManager.buyProVersion()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text(NSLocalizedString("Support & Subscribe", comment: "Pro Promotion Subscribe Button"))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text(NSLocalizedString("Pro Version Unlocked", comment: "Pro Version Unlocked Text"))
                                .fontWeight(.bold)
                        }
                        .padding()
                    }
                    
                    Button(action: {
                        onRemindLater()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text(NSLocalizedString("Remind me later", comment: "Pro Promotion Remind Button"))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    ProPromotionView()
}
