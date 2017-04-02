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
    
    func sendToWatch(_ units : Units) {
        let applicationDict = ["units" : units.rawValue]
        WCSession.default().transferUserInfo(applicationDict)
    }
    
    func sendToWatch(_ alertIfBelowValue : Float, alertIfAboveValue : Float) {
        let applicationDict = ["alertIfBelowValue" : alertIfBelowValue,
                                   "alertIfAboveValue" : alertIfAboveValue]
        WCSession.default().transferUserInfo(applicationDict)
    }
    
    func sendToWatch(_ hostUri : String) {
        let applicationDict = ["hostUri" : hostUri]
        WCSession.default().transferUserInfo(applicationDict)
    }
    
    func sendToWatch(_ hostUri : String, alertIfBelowValue : Float, alertIfAboveValue : Float, units : Units) {
        let applicationDict : [String : Any] =
            ["hostUri" : hostUri,
             "alertIfBelowValue" : alertIfBelowValue,
             "alertIfAboveValue" : alertIfAboveValue,
             "units" : units.rawValue]
        WCSession.default().transferUserInfo(applicationDict as [String : AnyObject])
    }
}
