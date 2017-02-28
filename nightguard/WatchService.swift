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
    
    func sendToWatch(units : Units) {
        let applicationDict = ["units" : units.rawValue]
        WCSession.defaultSession().transferUserInfo(applicationDict)
    }
    
    func sendToWatch(alertIfBelowValue : Float, alertIfAboveValue : Float) {
        let applicationDict = ["alertIfBelowValue" : alertIfBelowValue,
                                   "alertIfAboveValue" : alertIfAboveValue]
        WCSession.defaultSession().transferUserInfo(applicationDict)
    }
    
    func sendToWatch(hostUri : String) {
        let applicationDict = ["hostUri" : hostUri]
        WCSession.defaultSession().transferUserInfo(applicationDict)
    }
    
    func sendToWatch(hostUri : String, alertIfBelowValue : Float, alertIfAboveValue : Float, units : Units) {
        let applicationDict = ["hostUri" : hostUri,
                                "alertIfBelowValue" : alertIfBelowValue,
                                "alertIfAboveValue" : alertIfAboveValue,
                                "units" : units.rawValue]
        WCSession.defaultSession().transferUserInfo(applicationDict as! [String : AnyObject])
    }
}
