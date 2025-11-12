//
//  RootTabView.swift
//  nightguard
//
//  SwiftUI TabView implementation
//

import SwiftUI

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
                .environment(\.selectedTab, selectedTab)
                .tabItem {
                    Image("Main")
                        .renderingMode(.template)
                    Text(NSLocalizedString("Main", comment: "Main tab"))
                }
                .tag(0)

            // Alarms Tab
            NavigationView {
                AlarmView()
            }
            .tabItem {
                Image("Alarm")
                    .renderingMode(.template)
                Text(NSLocalizedString("Alarms", comment: "Alarms tab"))
            }
            .tag(1)

            // Care Tab
            CareView(selectedTab: $selectedTab)
                .tabItem {
                    Image("Care")
                        .renderingMode(.template)
                    Text(NSLocalizedString("Care", comment: "Care tab"))
                }
                .tag(2)

            // Duration Tab
            DurationView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                        .renderingMode(.template)
                    Text(NSLocalizedString("Duration", comment: "Duration tab"))
                }
                .tag(3)

            // Stats Tab
            StatsView()
                .tabItem {
                    Image("Stats")
                        .renderingMode(.template)
                    Text(NSLocalizedString("Stats", comment: "Stats tab"))
                }
                .tag(4)

            // Preferences Tab
            PrefsView()
                .tabItem {
                    Image("Prefs")
                        .renderingMode(.template)
                    Text(NSLocalizedString("Preferences", comment: "Preferences tab"))
                }
                .tag(5)
        }
        .accentColor(.white)
        .onChange(of: selectedTab) { newTab in
            if newTab == 4 {
                // Stats tab - force landscape
                UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            } else {
                // Other tabs - force portrait
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            }
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
