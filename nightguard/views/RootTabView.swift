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
    static let defaultValue: Int = 0
}

extension EnvironmentValues {
    var selectedTab: Int {
        get { self[SelectedTabKey.self] }
        set { self[SelectedTabKey.self] = newValue }
    }
}

struct RootTabView: View {

    @State private var selectedTab = 0

    @State private var orientation = UIDeviceOrientation.portrait

    @State private var showAppTour = false



    @State private var startTourOnConfiguration = false



    init() {

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
        TabView(selection: $selectedTab) {
            // Main Tab
            MainView()
                .onAppear {
                    if selectedTab == 0 { forcePortrait() }
                }
                .environment(\.selectedTab, selectedTab)
                .tabItem {
                    Image("Main")
                        .renderingMode(.template)
                    Text(NSLocalizedString("Main", comment: "Main tab"))
                        .accessibilityIdentifier("tab_main")
                }
                .tag(0)

            // Alarms Tab
            NavigationView {
                AlarmView()
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .onAppear {
                if selectedTab == 1 { forcePortrait() }
            }
            .tabItem {
                Image("Alarm")
                    .renderingMode(.template)
                Text(NSLocalizedString("Alarms", comment: "Alarms tab"))
                    .accessibilityIdentifier("tab_alarms")
            }
            .tag(1)

            // Care Tab
            CareView(selectedTab: $selectedTab)
                .onAppear {
                    if selectedTab == 2 { forcePortrait() }
                }
                .tabItem {
                    Image("Care")
                        .renderingMode(.template)
                Text(NSLocalizedString("Care", comment: "Care tab"))
                    .accessibilityIdentifier("tab_care")
            }
            .tag(2)

            // Duration Tab
            DurationView(selectedTab: $selectedTab)
                .onAppear {
                    if selectedTab == 3 { forcePortrait() }
                }
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                        .renderingMode(.template)
                    Text(NSLocalizedString("Duration", comment: "Duration tab"))
                        .accessibilityIdentifier("tab_duration")
                }
                .tag(3)

            // Stats Tab
            StatsView()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        forceLandscape()
                    }
                }
                .onDisappear {
                    forcePortrait()
                }
                .tabItem {
                    Image("Stats")
                        .renderingMode(.template)
                    Text(NSLocalizedString("Stats", comment: "Stats tab"))
                        .accessibilityIdentifier("tab_stats")
                }
                .tag(4)

            // Preferences Tab
            PrefsView()
                .onAppear {
                    if selectedTab == 5 { forcePortrait() }
                }
                .tabItem {
                    Image("Prefs")
                        .renderingMode(.template)
                    Text(NSLocalizedString("Preferences", comment: "Preferences tab"))
                }
                .accessibilityIdentifier("tab_prefs")
                .tag(5)
        }
        .accentColor(.white)
        .onAppear {
            if selectedTab == 4 {
                forceLandscape()
            } else {
                forcePortrait()
            }
            
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
        .sheet(isPresented: $showAppTour) {
            AppTourView(isPresented: $showAppTour, startOnConfiguration: startTourOnConfiguration)
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
            if let window = UIApplication.shared.windows.first,
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
        AppDelegate.orientationLock = .portrait
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        UINavigationController.attemptRotationToDeviceOrientation()
    }

    private func forceLandscape() {
        AppDelegate.orientationLock = .landscape
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        UINavigationController.attemptRotationToDeviceOrientation()
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
