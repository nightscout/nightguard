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

    @State private var orientation = UIDeviceOrientation.portrait

    @State private var showAppTour = false



    @State private var startTourOnConfiguration = false

    init() {
        _selectedTab = State(initialValue: UserDefaultsRepository.currentTab.value)

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
                .onAppear {
                    print("DEBUG: MainView onAppear. selectedTab: \(self.selectedTab)")
                    if self.selectedTab == .main {
                        forcePortrait()
                    }
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
                .navigationViewStyle(StackNavigationViewStyle())
                .onAppear {
                    if self.selectedTab == .alarms {
                        forcePortrait()
                    }
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
                .onAppear {
                    if self.selectedTab == .care {
                        forcePortrait()
                    }
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
                .onAppear {
                    print("DEBUG: DurationView onAppear. selectedTab: \(self.selectedTab)")
                    if self.selectedTab == .duration {
                        forcePortrait()
                    }
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
                .onAppear {
                    print("DEBUG: StatsView onAppear. selectedTab: \(self.selectedTab)")
                    if self.selectedTab == .stats {
                        forceLandscape()
                    } else {
                        print("DEBUG: StatsView appeared with mismatch. Fixing selection.")
                        DispatchQueue.main.async {
                            self.selectedTab = .stats
                            forceLandscape()
                        }
                    }
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
                .onAppear {
                    print("DEBUG: PrefsView onAppear. selectedTab: \(self.selectedTab)")
                    if self.selectedTab == .prefs {
                        forcePortrait()
                    } else {
                        print("DEBUG: PrefsView appeared with mismatch. Fixing selection.")
                        DispatchQueue.main.async {
                            self.selectedTab = .prefs
                            forcePortrait()
                        }
                    }
                }
                .tabItem {
                    Image("Prefs")
                        .renderingMode(.template)
                    Text(NSLocalizedString("Preferences", comment: "Preferences tab"))
                }
                .accessibilityIdentifier("tab_prefs")
                .tag(TabIdentifier.prefs)
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
        AppDelegate.orientationLock = .portrait
        
        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { error in
                print("Error requesting portrait orientation: \(error.localizedDescription)")
            }
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            UINavigationController.attemptRotationToDeviceOrientation()
        }
    }

    private func forceLandscape() {
        AppDelegate.orientationLock = .landscape
        
        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { error in
                print("Error requesting landscape orientation: \(error.localizedDescription)")
            }
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            UINavigationController.attemptRotationToDeviceOrientation()
        }
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
