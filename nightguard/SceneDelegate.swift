//
//  SceneDelegate.swift
//  nightguard
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let rootTabView = RootTabView()
        let hostingController = UIHostingController(rootView: rootTabView)

        let window = UserInteractionDetectorWindow(windowScene: windowScene)
        window.frame = windowScene.coordinateSpace.bounds
        
        // Always force a dark theme for nightguard. Otherwise e.g. the file picker would be white ^^
        window.overrideUserInterfaceStyle = .dark
        
        window.rootViewController = hostingController
        self.window = window
        window.makeKeyAndVisible()
        window.tintColor = UIColor.nightguardAccent()
        
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.window = window
            appDelegate.dimScreenOnIdle()
        }
    }
}
