//
//  RootTabView.swift
//  nightguard
//
//  SwiftUI TabView implementation
//

import SwiftUI

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
                .tabItem {
                    Image("Main")
                        .renderingMode(.template)
                    Text("Main")
                }
                .tag(0)

            // Care Tab
            CareViewRepresentable()
                .tabItem {
                    Image("Care")
                        .renderingMode(.template)
                    Text("Care")
                }
                .tag(1)

            // Stats Tab
            StatsViewRepresentable()
                .tabItem {
                    Image("Stats")
                        .renderingMode(.template)
                    Text("Stats")
                }
                .tag(2)

            // Preferences Tab
            PrefsViewRepresentable()
                .tabItem {
                    Image("Prefs")
                        .renderingMode(.template)
                    Text("Preferences")
                }
                .tag(3)

            // Alarms Tab
            AlarmViewRepresentable()
                .tabItem {
                    Image("Alarm")
                        .renderingMode(.template)
                    Text("Alarms")
                }
                .tag(4)
        }
        .accentColor(.white)
    }
}

// MARK: - UIKit View Controllers wrapped in SwiftUI

struct CareViewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let tabBarController = storyboard.instantiateInitialViewController() as! UITabBarController
        // Care tab is at index 1
        return tabBarController.viewControllers?[1] ?? UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}

struct StatsViewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let tabBarController = storyboard.instantiateInitialViewController() as! UITabBarController
        // Stats tab is at index 2
        return tabBarController.viewControllers?[2] ?? UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}

struct PrefsViewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let tabBarController = storyboard.instantiateInitialViewController() as! UITabBarController
        // Prefs tab is at index 3
        return tabBarController.viewControllers?[3] ?? UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}

struct AlarmViewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let tabBarController = storyboard.instantiateInitialViewController() as! UITabBarController
        // Alarm tab is at index 4
        return tabBarController.viewControllers?[4] ?? UIViewController()
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
