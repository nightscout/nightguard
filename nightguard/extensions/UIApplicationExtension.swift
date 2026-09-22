//
//  UIApplicationExtension.swift
//  nightguard
//
//  Created by Florian Preknya on 12/10/18.
//  Copyright © 2018 private. All rights reserved.
//

import UIKit
import UserNotifications

#if os(iOS) && MAIN_APP
extension UIApplication {
    
    /*
     * Updates app bagdge with the current BG value
     */
    func setCurrentBGValueOnAppBadge() {
        
        let nightscoutData = NightscoutCacheService.singleton.getCurrentNightscoutData()
        guard let sgvAsDouble = Double(UnitsConverter.mgdlToDisplayUnits(nightscoutData.sgv)) else {
            return
        }
        let sgvAsInt = Int(sgvAsDouble.rounded())
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound, .criticalAlert]) { (granted, error) in
            if granted && error == nil {
                
                // success!
                dispatchOnMain {
                    
                    if #available(iOS 16.0, *) {
                        UNUserNotificationCenter.current().setBadgeCount(sgvAsInt)
                    } else {
                        UIApplication.shared.setValue(sgvAsInt, forKey: "applicationIconBadgeNumber")
                    }
                }
            }
        }
        
    }
    
    /*
     * Removes the current BG value from app badge
     */
    func clearAppBadge() {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0)
        } else {
            UIApplication.shared.setValue(0, forKey: "applicationIconBadgeNumber")
        }
    }
}
#endif
