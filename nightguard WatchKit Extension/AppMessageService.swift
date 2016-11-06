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
            
            if session.reachable {
                session.sendMessage(["requestBaseUri": ""], replyHandler: { (response) -> Void in
                
                    if let baseUri = response.first?.1 {
                        UserDefaultsRepository.saveBaseUri(String(baseUri))
                    }
                    }, errorHandler: { (error) -> Void in
                        print(error)
                })
            }
        }
    }
    
    func updateValuesFromApplicationContext(applicationContext: [String : AnyObject]) {
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
    
    @available(watchOSApplicationExtension 2.2, *)
    func session(session: WCSession, activationDidCompleteWithState activationState: WCSessionActivationState, error: NSError?) {
        
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            
            self.updateValuesFromApplicationContext(session.receivedApplicationContext)
        }
    }
    
    /** Called on the delegate of the receiver. Will be called on startup if an applicationContext is available. */
    @available(watchOS 2.0, *)
    func session(session: WCSession, didReceiveApplicationContext applicationContext: [String : AnyObject]) {
        updateValuesFromApplicationContext(applicationContext)
    }
    
    /** Called on the delegate of the receiver. Will be called on startup if the user info finished transferring when the receiver was not running. */
    @available(watchOS 2.0, *)
    func session(session: WCSession, didReceiveUserInfo userInfo: [String : AnyObject]) {
        updateValuesFromApplicationContext(userInfo)
    }
}
