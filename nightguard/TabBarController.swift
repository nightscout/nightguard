//
//  UITabBarController.swift
//  nightguard
//
//  Created by Dirk Hermanns on 23.06.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

class TabBarController: UITabBarController {
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        if let selectedViewController = (self.selectedViewController as? UINavigationController)?.viewControllers.first ?? self.selectedViewController {
            return selectedViewController.supportedInterfaceOrientations
        }
        return .allButUpsideDown
    }
    
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            print("Device shaken")
            
            if !AlarmRule.isSnoozed() {
                DispatchQueue.main.async { [weak self] in
                    self?.handleQuickSnooze(option: UserDefaultsRepository.shakingOnAlertSnoozeOption.value)
                }
            }
        }
    }
}
