//
//  WatchService.swift
//  nightguard
//
//  Created by Dirk Hermanns on 05.06.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation
import WatchConnectivity

class WatchService {
    
    static let singleton = WatchService()
    
    // watch app update frequency (when have new nightscout data)
    var watchUpdateRate: Int = 5 // minutes
    
    // watch app complication update (when have new nightscout data)
    var watchComplicationUpdateRate: Int = 30 // minutes (50 complication update per day guaranteed by Apple...)
    
    private var lastSentNightscoutDataTime: NSNumber?
    private var lastWatchUpdateTime: Date?
    private var lastWatchComplicationUpdateTime: Date?
    
    func sendToWatch(_ units : Units) {
        let applicationDict = ["units" : units.rawValue]
        WCSession.default.transferUserInfo(applicationDict)
    }
    
    func sendToWatch(_ alertIfBelowValue : Float, alertIfAboveValue : Float) {
        let applicationDict = ["alertIfBelowValue" : alertIfBelowValue,
                                   "alertIfAboveValue" : alertIfAboveValue]
        WCSession.default.transferUserInfo(applicationDict)
    }
    
    func sendToWatch(_ hostUri : String) {
        let applicationDict = ["hostUri" : hostUri]
        WCSession.default.transferUserInfo(applicationDict)
    }
    
    func sendToWatch(_ hostUri : String, alertIfBelowValue : Float, alertIfAboveValue : Float, units : Units) {
        let applicationDict : [String : Any] =
            ["hostUri" : hostUri,
             "alertIfBelowValue" : alertIfBelowValue,
             "alertIfAboveValue" : alertIfAboveValue,
             "units" : units.rawValue]
        WCSession.default.transferUserInfo(applicationDict as [String : AnyObject])
    }
    
    func sendToWatchCurrentNightwatchData() {
        
        // send ONLY if the phone app has new nightscout data
        let nightscoutData = NightscoutCacheService.singleton.getCurrentNightscoutData()
        guard !nightscoutData.isOlderThan5Minutes() else {
            return
        }
        
        // the session must be active in order to send data
        if #available(iOS 9.3, *) {
            guard WCSession.default.activationState == .activated else {
                return
            }
        }
        
        if lastSentNightscoutDataTime != nightscoutData.time {
            // Assuring we are sending ONLY once a nightscout data...
            // ... and respecting the update rate!
            if let lastWatchUpdateTime = self.lastWatchUpdateTime, Calendar.current.date(byAdding: .minute, value: self.watchUpdateRate, to: lastWatchUpdateTime)! >= Date() {
                
                // do nothing, last watch update was more recent than update rate, will skip updating it now!
            } else {
                
                // do update!
                try? WCSession.default.updateApplicationContext(
                    WatchMessageService.singleton.currentNightscoutDataAsMessage
                )

                self.lastSentNightscoutDataTime = nightscoutData.time
                self.lastWatchUpdateTime = Date()
            }
        }
        
        // NOTE: complication update is not needed anymore, as we provide data from 5 in 5 minutes on application context (if we send complication updates also, both updates will arrive at the same time... so useless to do it!)
        
//        // update complication also (but respect the update rate - 30 minutes)
//        if WCSession.default.isComplicationEnabled {
//
//            if let lastWatchComplicationUpdateTime = self.lastWatchComplicationUpdateTime, Calendar.current.date(byAdding: .minute, value: self.watchComplicationUpdateRate, to: lastWatchComplicationUpdateTime)! >= Date() {
//
//                // do nothing, last watch complication update was more recent than update rate, will skip updating it now!
//            } else {
//
//                // send in user info along the nightscout data a flag to signal that we want to update complications also
//                var userInfo = WatchMessageService.singleton.currentNightscoutDataAsMessage
//                userInfo["updateComplication"] = true
//
//                // update!
//                WCSession.default.transferCurrentComplicationUserInfo(userInfo)
//
//                // and keep the update time
//                self.lastWatchComplicationUpdateTime = Date()
//            }
//        }
    }
}
