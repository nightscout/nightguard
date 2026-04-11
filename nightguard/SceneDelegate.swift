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

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        (UIApplication.shared.delegate as? AppDelegate)?.applicationWillResignActive(UIApplication.shared)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        (UIApplication.shared.delegate as? AppDelegate)?.applicationDidEnterBackground(UIApplication.shared)
    }
}

