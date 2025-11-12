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
                    Text("Main")
                }
                .tag(0)

            // Alarms Tab
            NavigationView {
                AlarmView()
            }
            .tabItem {
                Image("Alarm")
                    .renderingMode(.template)
                Text("Alarms")
            }
            .tag(1)
            
            // Care Tab
            CareViewRepresentable()
                .tabItem {
                    Image("Care")
                        .renderingMode(.template)
                    Text("Care")
                }
                .tag(2)

            // Duration Tab
            DurationViewRepresentable()
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                        .renderingMode(.template)
                    Text("Duration")
                }
                .tag(3)
            
            // Stats Tab
            StatsViewRepresentable()
                .tabItem {
                    Image("Stats")
                        .renderingMode(.template)
                    Text("Stats")
                }
                .tag(4)

            // Preferences Tab
            PrefsViewRepresentable()
                .tabItem {
                    Image("Prefs")
                        .renderingMode(.template)
                    Text("Preferences")
                }
                .tag(5)
        }
        .accentColor(.white)
    }
}

// MARK: - UIKit View Controllers wrapped in SwiftUI

struct CareViewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let storyboard = UIStoryboard(name: "Care", bundle: Bundle.main)
        return storyboard.instantiateInitialViewController() ?? UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}

struct StatsViewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let storyboard = UIStoryboard(name: "Stats", bundle: Bundle.main)
        return storyboard.instantiateInitialViewController() ?? UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}

struct PrefsViewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let storyboard = UIStoryboard(name: "Preferences", bundle: Bundle.main)
        return storyboard.instantiateInitialViewController() ?? UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}

// AlarmViewRepresentable removed - using native SwiftUI AlarmView instead

struct DurationViewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let storyboard = UIStoryboard(name: "Duration", bundle: Bundle.main)
        return storyboard.instantiateInitialViewController() ?? UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Preview

struct RootTabView_Previews: PreviewProvider {
    static var previews: some View {
        RootTabView()
    }
}
