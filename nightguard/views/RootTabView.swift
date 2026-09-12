//
//  RootTabView.swift
//  nightguard
//
//  SwiftUI TabView implementation
//

import SwiftUI
import UIKit

// Environment key to track selected tab
private struct SelectedTabKey: EnvironmentKey {
    static let defaultValue: TabIdentifier = .main
}

extension EnvironmentValues {
    var selectedTab: TabIdentifier {
        get { self[SelectedTabKey.self] }
        set { self[SelectedTabKey.self] = newValue }
    }
}

struct RootTabView: View {

    @State private var selectedTab: TabIdentifier

    @State private var showAppTour = false
    @State private var showGlobalProPromotion = false
    @ObservedObject private var purchaseManager = PurchaseManager.shared



    @State private var startTourOnConfiguration = false

    init() {
        // Always start from the main tab on a fresh app launch.
        _selectedTab = State(initialValue: .main)

        // Configure tab bar appearance

        let appearance = UITabBarAppearance()

        appearance.configureWithOpaqueBackground()

        appearance.backgroundColor = .black



        // Configure selected item appearance

        appearance.stackedLayoutAppearance.selected.iconColor = .white

        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]



        // Configure normal item appearance

        appearance.stackedLayoutAppearance.normal.iconColor = .lightGray

        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.lightGray]



        UITabBar.appearance().standardAppearance = appearance

        if #available(iOS 15.0, *) {

            UITabBar.appearance().scrollEdgeAppearance = appearance

        }



        // Set tint color

        UITabBar.appearance().tintColor = .white

        UITabBar.appearance().unselectedItemTintColor = .lightGray

    }



    var body: some View {
        let selectionBinding = Binding<TabIdentifier>(
            get: { self.selectedTab },
            set: { newValue in
                print("DEBUG: Selection changing to \(newValue), current: \(self.selectedTab)")
                self.selectedTab = newValue
                UserDefaultsRepository.currentTab.value = newValue
            }
        )
        
        return TabView(selection: selectionBinding) {
            // Main Tab
            MainView()
                .accentColor(Color.nightguardAccent)
                .onAppear {
                    print("DEBUG: MainView onAppear. selectedTab: \(self.selectedTab)")
                    if self.selectedTab == .main { forcePortrait() }
                }
                .environment(\.selectedTab, selectedTab)
                .tabItem {
                    Image("Main")
                        .renderingMode(.template)
                    Text(NSLocalizedString("Main", comment: "Main tab"))
                        .accessibilityIdentifier("tab_main")
                }
                .tag(TabIdentifier.main)

            // Alarms Tab
            NavigationView {
                    AlarmView()
                }
                .accentColor(Color.nightguardAccent)
                .navigationViewStyle(StackNavigationViewStyle())
                .onAppear {
                    if self.selectedTab == .alarms { forcePortrait() }
                }
                .tabItem {
                    Image("Alarm")
                        .renderingMode(.template)
                    Text(NSLocalizedString("Alarms", comment: "Alarms tab"))
                        .accessibilityIdentifier("tab_alarms")
                }
                .tag(TabIdentifier.alarms)

            // Care Tab
            CareView(selectedTab: selectionBinding)
                .accentColor(Color.nightguardAccent)
                .onAppear {
                    if self.selectedTab == .care { forcePortrait() }
                }
                .tabItem {
                    Image("Care")
                        .renderingMode(.template)
                    Text(NSLocalizedString("Care", comment: "Care tab"))
                        .accessibilityIdentifier("tab_care")
                }
                .tag(TabIdentifier.care)

            // Duration Tab
            DurationView(selectedTab: selectionBinding)
                .accentColor(Color.nightguardAccent)
                .onAppear {
                    print("DEBUG: DurationView onAppear. selectedTab: \(self.selectedTab)")
                    if self.selectedTab == .duration { forcePortrait() }
                }
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                        .renderingMode(.template)
                    Text(NSLocalizedString("Duration", comment: "Duration tab"))
                        .accessibilityIdentifier("tab_duration")
                }
                .tag(TabIdentifier.duration)

            // Stats Tab
            StatsView()
                .accentColor(Color.nightguardAccent)
                .onAppear {
                    print("DEBUG: StatsView onAppear. selectedTab: \(self.selectedTab)")
                    // Selecting an item from the system More list may not
                    // update the SwiftUI selection binding first.
                    forceLandscape()
                }
                .onDisappear {
                    // The system More list is hosted outside this TabView and
                    // therefore does not always update selectedTab when opened.
                    forcePortrait()
                }
                .tabItem {
                    Image("Stats")
                        .renderingMode(.template)
                    Text(NSLocalizedString("Stats", comment: "Stats tab"))
                        .accessibilityIdentifier("tab_stats")
                }
                .tag(TabIdentifier.stats)

            // Preferences Tab
            PrefsView()
                .accentColor(Color.nightguardAccent)
                .onAppear {
                    print("DEBUG: PrefsView onAppear. selectedTab: \(self.selectedTab)")
                    DispatchQueue.main.async {
                        if self.selectedTab == .prefs { forcePortrait() }
                    }
                }
                .tabItem {
                    Image("Prefs")
                        .renderingMode(.template)
                    Text(NSLocalizedString("Preferences", comment: "Preferences tab"))
                }
                .accessibilityIdentifier("tab_prefs")
                .tag(TabIdentifier.prefs)

            // Subscription tabs are intentionally placed next to Preferences so
            // they also appear as top-level entries in the tab bar's More menu.
            if purchaseManager.isMaxAccessAvailable {
                subscriptionTab(initialPromotion: .max, tab: .subscribeMax, title: "Thank You for Your Support", icon: "heart.fill")
            } else {
                subscriptionTab(
                    initialPromotion: .pro,
                    tab: .subscribePro,
                    title: purchaseManager.hasProFeatureAccess ? "Thank You for Your Support" : "Pro Subscription Information",
                    icon: purchaseManager.hasProFeatureAccess ? "heart.fill" : "star.circle"
                )
                subscriptionTab(initialPromotion: .max, tab: .subscribeMax, title: "Max Subscription Information", icon: "bolt.circle")
            }
        }
        .accentColor(.white)
        .onAppear {
            checkAndShowDisclaimerAndThen {
                let appTourSeen = UserDefaultsRepository.appTourSeen.value
                let baseUri = UserDefaultsRepository.baseUri.value
                
                if !appTourSeen {
                    startTourOnConfiguration = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showAppTour = true
                    }
                } else if baseUri.isEmpty {
                    startTourOnConfiguration = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showAppTour = true
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showProPromotionRequest)) { _ in
            guard !PurchaseManager.shared.hasProFeatureAccess else {
                return
            }

            showGlobalProPromotion = true
        }
        .sheet(isPresented: $showAppTour) {
            AppTourView(isPresented: $showAppTour, startOnConfiguration: startTourOnConfiguration)
        }
        .sheet(isPresented: $showGlobalProPromotion) {
            ProPromotionView(
                onRemindLater: {
                    UserDefaultsRepository.markProPromotionSeen()
                }
            )
        }
    }
    
    private func checkAndShowDisclaimerAndThen(completion: @escaping () -> Void) {
        let versionNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let showOnceKey = "showedWarningIn\(versionNumber)"
        
        if UserDefaultsRepository.disclaimerSeen.value || UserDefaults.standard.bool(forKey: showOnceKey) {
            completion()
            return
        }
        
        // Show Alert
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let window = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }

            if let window = window,
               let rootViewController = window.rootViewController {
                   
                rootViewController.showAcceptDeclineAlert(title: NSLocalizedString("Disclaimer!", comment: "Disclaimer Popup Title"), message:
                NSLocalizedString("Don't use this App for medical decisions! It comes with absolutely NO WARRANTY. It is maintained by volunteers only. Use it at your own risk!", comment: "Disclaimer Popup Message"),
                      showOnceKey: showOnceKey,
                      onAccept: completion)
            } else {
                 completion()
            }
        }
    }
    
    private func forcePortrait() {
        AppDelegate.updateOrientationLock(.portrait, rotateTo: .portrait)
    }

    private func forceLandscape() {
        AppDelegate.updateOrientationLock(.landscape, rotateTo: .landscapeRight)
    }

    private func subscriptionTab(initialPromotion: PromotionFocus, tab: TabIdentifier, title: String, icon: String) -> some View {
        ProPromotionView(initialPromotion: initialPromotion, showsRemindLater: false)
            .accentColor(Color.nightguardAccent)
            .onAppear {
                if self.selectedTab == tab { forcePortrait() }
            }
            .tabItem {
                Image(systemName: icon)
                Text(NSLocalizedString(title, comment: "Subscription tab"))
            }
            .tag(tab)
    }
}

// MARK: - UIKit View Controllers wrapped in SwiftUI
// All view controllers have been converted to native SwiftUI views

// MARK: - Preview

struct RootTabView_Previews: PreviewProvider {
    static var previews: some View {
        RootTabView()
    }
}
