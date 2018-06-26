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
    
    func keepAwakePhoneApp() {
        
        // send a dummy message to keep the phone app awake (start the app if is not started)
        if WCSession.isSupported() {
            
            let session = WCSession.default
            if session.isReachable {
                session.sendMessage(["keepAwake": ""], replyHandler: nil) { error in
                    print(error)
                    BackgroundRefreshLogger.info("Error received while trying to awake phone app: \(error)")
                }
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
        
        if let showRawBG = applicationContext["showRawBG"] as? Bool {
            UserDefaultsRepository.saveShowRawBG(showRawBG)
        }
        
        var shouldRepaintCharts = false
        if let alertIfAboveValue = applicationContext["alertIfAboveValue"] as? Float {
            let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
            defaults!.setValue(alertIfAboveValue, forKey: "alertIfAboveValue")
            AlarmRule.alertIfAboveValue = alertIfAboveValue
            
            shouldRepaintCharts = true
        }
        
        if let alertIfBelowValue = applicationContext["alertIfBelowValue"] as? Float {
            let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
            defaults!.setValue(alertIfBelowValue, forKey: "alertIfBelowValue")
            AlarmRule.alertIfBelowValue = alertIfBelowValue
            
            shouldRepaintCharts = true
        }
        
        if shouldRepaintCharts {
            if #available(watchOSApplicationExtension 3.0, *) {
                if let interfaceController = WKExtension.shared().rootInterfaceController as? InterfaceController {
                    if WKExtension.shared().applicationState == .active {
                        DispatchQueue.main.async {
                            interfaceController.loadAndPaintChartData(forceRepaint: true)
                        }
                    } else {
                        interfaceController.shouldRepaintChartsOnActivation = true
                    }
                }
            }
        }
        
        if let _ = applicationContext["nightscoutData"] {
            if #available(watchOSApplicationExtension 3.0, *) {
                if let extensionDelegate = WKExtension.shared().delegate as? ExtensionDelegate {
                    DispatchQueue.global().async {
                        extensionDelegate.handleNightscoutDataMessage(applicationContext)
                    }
                }
            }
        }
    }
    
    @available(watchOSApplicationExtension 2.2, *)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
        DispatchQueue.global().async { () -> Void in
            
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
    
    @available(watchOS 2.0, *)
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        updateValuesFromApplicationContext(message as [String : AnyObject])
    }
    
    @available(watchOS 2.0, *)
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Swift.Void) {
        updateValuesFromApplicationContext(message as [String : AnyObject])
    }
}
