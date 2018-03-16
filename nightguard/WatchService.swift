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
    
    private var lastWatchComplicationUpdateTime: Date?
    private let watchComplicationUpdateRate: Int = 30 // minutes (50 update per day guaranteed by Apple...)
    
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
    
    func updateWatchComplicationIfPossible() {
        
        let calendar = Calendar.current
        if let lastWatchComplicationUpdateTime = self.lastWatchComplicationUpdateTime, calendar.date(byAdding: .minute, value: self.watchComplicationUpdateRate, to: lastWatchComplicationUpdateTime)! >= Date() {
            
            // last watch complication update was more recent than update rate, will skip updating it now!
            return
        }
        
        var shouldUpdate = true
        if #available(iOS 9.3, *) {
            shouldUpdate = WCSession.default.activationState == .activated && WCSession.default.isComplicationEnabled
        }
        
        if shouldUpdate {
                
            // update!
            WCSession.default.transferCurrentComplicationUserInfo(
                WatchMessageService.singleton.currentNightscoutDataAsMessage
            )
            
            // and keep the update time
            self.lastWatchComplicationUpdateTime = Date()
        }
    }
}
