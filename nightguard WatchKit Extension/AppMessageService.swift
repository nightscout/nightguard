//
//  AppPushService.swift
//  nightguard
//
//  Created by Dirk Hermanns on 27.06.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation
import WatchKit
import WatchConnectivity

// This class handles values that are passed from the ios app.
class AppMessageService : NSObject, WCSessionDelegate {
    
    static let singleton = AppMessageService()
    
    // request the baseUri from the iosApp and stores the result in the UserDefaultsRepository
    func requestBaseUri() {
        
        if WCSession.isSupported() {
            
            let session = WCSession.default
            
            if session.isReachable {
                session.sendMessage(["requestBaseUri": ""], replyHandler: { (response) -> Void in
                
                    if let baseUri = response.first?.1 {
                        UserDefaultsRepository.saveBaseUri(String(describing: baseUri))
                    }
                    }, errorHandler: { (error) -> Void in
                        print(error)
                })
            }
        }
    }
    
    func updateValuesFromApplicationContext(_ applicationContext: [String : AnyObject]) {
        if let units = applicationContext["units"] as? String {
            UserDefaultsRepository.saveUnits(Units(rawValue: units)!)
        }
        
        if let hostUri = applicationContext["hostUri"] as? String {
            UserDefaultsRepository.saveBaseUri(hostUri)
        }
        
        if let alertIfAboveValue = applicationContext["alertIfAboveValue"] as? Float {
            let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
            defaults!.setValue(alertIfAboveValue, forKey: "alertIfAboveValue")
            AlarmRule.alertIfAboveValue = alertIfAboveValue
        }
        
        if let alertIfBelowValue = applicationContext["alertIfBelowValue"] as? Float {
            let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
            defaults!.setValue(alertIfBelowValue, forKey: "alertIfBelowValue")
            AlarmRule.alertIfBelowValue = alertIfBelowValue
        }
        
        if let _ = applicationContext["nightscoutData"] {
            if #available(watchOSApplicationExtension 3.0, *) {
                if let extensionDelegate = WKExtension.shared().delegate as? ExtensionDelegate {
                    extensionDelegate.handleNightscoutDataMessage(applicationContext)
                }
            }
        }
    }
    
    @available(watchOSApplicationExtension 2.2, *)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
        DispatchQueue.main.async { () -> Void in
            
            self.updateValuesFromApplicationContext(session.receivedApplicationContext as [String : AnyObject])
        }
    }
    
    /** Called on the delegate of the receiver. Will be called on startup if an applicationContext is available. */
    @available(watchOS 2.0, *)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        updateValuesFromApplicationContext(applicationContext as [String : AnyObject])
    }
    
    /** Called on the delegate of the receiver. Will be called on startup if the user info finished transferring when the receiver was not running. */
    @available(watchOS 2.0, *)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        updateValuesFromApplicationContext(userInfo as [String : AnyObject])
    }
}
