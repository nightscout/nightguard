//
//  UIApplicationExtension.swift
//  nightguard
//
//  Created by Florian Preknya on 12/10/18.
//  Copyright © 2018 private. All rights reserved.
//

import UIKit
import UserNotifications

extension UIApplication {
    
    /*
     * Updates app bagdge with the current BG value
     */
    func setCurrentBGValueOnAppBadge() {
        
        let nightscoutData = NightscoutCacheService.singleton.getCurrentNightscoutData()
        guard let sgv = Int(nightscoutData.sgv) else {
            return
        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: .badge) { (granted, error) in
            if granted && error == nil {
                
                // success!
                dispatchOnMain {
                    UIApplication.shared.applicationIconBadgeNumber = sgv
                }
            }
        }
        
    }
    
    /*
     * Removes the current BG value from app badge
     */
    func clearAppBadge() {
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
}
