//
//  AppPushService.swift
//  nightguard
//
//  Created by Dirk Hermanns on 27.06.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation
import WatchConnectivity

// This class handles values that are passed from the ios app.
class AppMessageService : NSObject, WCSessionDelegate {
    
    static let singleton = AppMessageService()
    
    // request the baseUri from the iosApp and stores the result in the UserDefaultsRepository
    func requestBaseUri() {
        
        if WCSession.isSupported() {
            
            let session = WCSession.defaultSession()
            
            session.sendMessage(["requestBaseUri": ""], replyHandler: { (response) -> Void in
                
                if let baseUri = response.first?.1 {
                    UserDefaultsRepository.saveBaseUri(String(baseUri))
                }
            }, errorHandler: { (error) -> Void in
                print(error)
            })
        }
    }
    
    // Receives values that are pushed from the ios app
    func session(session: WCSession, didReceiveApplicationContext applicationContext: [String : AnyObject]) {
        
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            
            if let units = applicationContext["units"] as? String {
                UserDefaultsRepository.saveUnits(Units(rawValue: units)!)
            }
            
            if let hostUri = applicationContext["hostUri"] as? String {
                UserDefaultsRepository.saveBaseUri(hostUri)
            }
            
            if let alertIfAboveValue = applicationContext["alertIfAboveValue"] as? Float {
                let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
                defaults!.setValue(alertIfAboveValue, forKey: "alertIfAboveValue")
            }
            
            if let alertIfBelowValue = applicationContext["alertIfBelowValue"] as? Float {
                let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
                defaults!.setValue(alertIfBelowValue, forKey: "alertIfBelowValue")
            }
        }
    }
}