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
                    
                    UIApplication.shared.applicationIconBadgeNumber = sgvAsInt
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
    
    /*
     * function will return reference to tabbarcontroller
     */
    func showMain() {
        // Use the modern approach for accessing the rootViewController in multi-scene environments
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
#endif
