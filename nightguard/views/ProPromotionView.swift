//
//  ProPromotionView.swift
//  nightguard
//

import SwiftUI

struct ProPromotionView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var purchaseManager = PurchaseManager.shared
    @State private var selectedPromotion: PromotionFocus = .pro
    
    var onRemindLater: () -> Void = {}
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "star.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(Color.nightguardAccent)
                        .padding(.top, 20)
                    
                    Text(NSLocalizedString("Support Nightguard", comment: "Pro Promotion Title"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Picker("", selection: $selectedPromotion) {
                        Text(NSLocalizedString("Pro", comment: "Pro subscription option title")).tag(PromotionFocus.pro)
                        Text(NSLocalizedString("Max", comment: "Max subscription option title")).tag(PromotionFocus.max)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
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

                    Text(selectedPromotion.introText)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Features
                VStack(alignment: .leading, spacing: 16) {
                    if selectedPromotion == .pro {
                        FeatureRow(
                            icon: "bell.badge.fill",
                            title: NSLocalizedString("Pro Notifications", comment: "Pro Feature 1 Title"),
                            description: NSLocalizedString("Push Notifications for Cannula Age, Battery Age, Sensor Age and Reservoir capacity.", comment: "Pro Feature 1 Description")
                        )
                    }

                    if selectedPromotion == .pro {
                        FeatureRow(
                            icon: "app.badge.fill",
                            title: NSLocalizedString("Live Activities", comment: "Pro Feature 2 Title"),
                            description: NSLocalizedString("Support for the dynamic island and live activities to see your BG at a glance.", comment: "Pro Feature 2 Description")
                        )
                    }

                    if selectedPromotion == .pro {
                        FeatureRow(
                            icon: "car.fill",
                            title: NSLocalizedString("CarPlay", comment: "Pro Feature 3 Title"),
                            description: NSLocalizedString("Glucose and alarms on your CarPlay screen while driving.", comment: "Pro Feature 3 Description")
                        )

                        FeatureRow(
                            icon: "chart.pie.fill",
                            title: NSLocalizedString("Watch Statistics", comment: "Pro Feature 4 Title"),
                            description: NSLocalizedString("See the four main glucose stats directly on your Apple Watch in a compact 2x2 view.", comment: "Pro Feature 4 Description")
                        )
                    }

                    if selectedPromotion == .max {
                        FeatureRow(
                            icon: "bolt.badge.clock.fill",
                            title: NSLocalizedString("Max Background Updates", comment: "Max Feature Title"),
                            description: NSLocalizedString("Silent push wakeups improve background refreshes for the app, widgets, Live Activities and complications.", comment: "Max Feature Description")
                        )

                        FeatureRow(
                            icon: "app.badge.checkmark.fill",
                            title: NSLocalizedString("Dynamic Island and Live Activity Updates", comment: "Max Live Activity updates title"),
                            description: NSLocalizedString("Updating Dynamic Island and Live Activities in the background is only possible through push notifications in Max. This is an Apple limitation.", comment: "Max Live Activity updates Apple limitation")
                        )

                        FeatureRow(
                            icon: "server.rack",
                            title: NSLocalizedString("Why Max costs more", comment: "Max price explanation title"),
                            description: NSLocalizedString("Every Max user receives thousands of push notifications per month. This requires a hosted server backend, which is why the higher price is unfortunately necessary.", comment: "Max price explanation description")
                        )
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                // Subscription choices
                VStack(spacing: 12) {
                    SubscriptionOptionView(
                        icon: "star.circle.fill",
                        title: NSLocalizedString("Pro", comment: "Pro subscription option title"),
                        subtitle: NSLocalizedString("Unlock Pro notifications, Live Activities, CarPlay and Watch statistics.", comment: "Pro subscription option subtitle"),
                        price: purchaseManager.formattedProPrice,
                        statusText: proStatusText,
                        footnoteText: nil,
                        buttonTitle: purchaseManager.hasProFeatureAccess ? nil : NSLocalizedString("Support & Subscribe", comment: "Pro Promotion Subscribe Button"),
                        action: {
                            purchaseManager.buyProVersion()
                            presentationMode.wrappedValue.dismiss()
                        }
                    )

                    SubscriptionOptionView(
                        icon: "bolt.badge.clock.fill",
                        title: NSLocalizedString("Max", comment: "Max subscription option title"),
                        subtitle: NSLocalizedString("Includes all Pro features plus Max Background Updates.", comment: "Max subscription option subtitle"),
                        price: purchaseManager.formattedMaxPrice,
                        statusText: purchaseManager.isMaxAccessAvailable ? NSLocalizedString("Max Subscription Active", comment: "Max subscription active text") : nil,
                        footnoteText: maxUpgradeFootnoteText,
                        buttonTitle: purchaseManager.isMaxAccessAvailable ? nil : maxButtonTitle,
                        action: {
                            purchaseManager.buyMaxVersion()
                            presentationMode.wrappedValue.dismiss()
                        }
                    )
                    
                    Button(action: {
                        onRemindLater()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text(NSLocalizedString("Remind me later", comment: "Pro Promotion Remind Button"))
                            .foregroundColor(Color.nightguardAccent)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .accentColor(.nightguardAccent)
    }

    private var proStatusText: String? {
        if purchaseManager.isMaxAccessAvailable {
            return NSLocalizedString("Included with Max", comment: "Pro features included with Max status")
        }

        if purchaseManager.isProAccessAvailable {
            return NSLocalizedString("Pro Version Unlocked", comment: "Pro Version Unlocked Text")
        }

        return nil
    }

    private var maxButtonTitle: String {
        purchaseManager.hasProFeatureAccess
            ? NSLocalizedString("Upgrade to Max", comment: "Max Promotion Subscribe Button")
            : NSLocalizedString("Subscribe to Max", comment: "Max Promotion Subscribe Button")
    }

    private var maxUpgradeFootnoteText: String? {
        guard purchaseManager.hasProFeatureAccess, !purchaseManager.isMaxAccessAvailable else {
            return nil
        }

        return NSLocalizedString("When upgrading from Pro to Max, Apple automatically accounts for your remaining Pro subscription time in the purchase dialog.", comment: "Max upgrade proration footnote")
    }
}

private enum PromotionFocus: Hashable {
    case pro
    case max

    var introText: String {
        switch self {
        case .pro:
            return NSLocalizedString("Pro unlocks the core premium features. For push-based background updates, choose Max.", comment: "Pro promotion intro with Max hint")
        case .max:
            return NSLocalizedString("Max includes Pro and adds the background update features below.", comment: "Max promotion intro")
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
                .foregroundColor(Color.nightguardAccent)
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

struct SubscriptionOptionView: View {
    let icon: String
    let title: String
    let subtitle: String
    let price: String?
    let statusText: String?
    let footnoteText: String?
    let buttonTitle: String?
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(Color.nightguardAccent)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    if let statusText {
                        Label(statusText, systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if let buttonTitle {
                Button(action: action) {
                    VStack(spacing: 4) {
                        Text(buttonTitle)
                            .fontWeight(.bold)
                        if let price {
                            Text(String(format: NSLocalizedString("%@ / month", comment: "Price per month"), price))
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.nightguardAccent)
                    .cornerRadius(12)
                }
            } else if let price {
                Text(String(format: NSLocalizedString("%@ / month", comment: "Price per month"), price))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let footnoteText {
                Text(footnoteText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    ProPromotionView()
}
