//
//  NightguardApp.swift
//  nightguard WatchKit App
//
//  Created by conversion to SwiftUI.
//

import SwiftUI

@main
struct NightguardApp: App {
    @WKApplicationDelegateAdaptor(ExtensionDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            TabView {
                MainView(mainViewModel: MainController.mainViewModel)
                ActionButtonView(mainViewModel: MainController.mainViewModel)
                TemporaryTargetView()
                CarbsView()
                InfoView()
            }
            .tabViewStyle(PageTabViewStyle())
        }
    }
}
