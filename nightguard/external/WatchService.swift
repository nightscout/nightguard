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
    
    private var lastSentNightscoutDataTime: NSNumber?
    private var lastWatchUpdateTime: Date?
    
    func sendToWatchCurrentNightwatchData(
        nightscoutData suppliedNightscoutData: NightscoutData? = nil,
        displaySnapshot suppliedDisplaySnapshot: NightguardDisplaySnapshot? = nil
    ) {
        
        // send ONLY if the phone app has new nightscout data
        let nightscoutData = suppliedNightscoutData ?? NightscoutCacheService.singleton.getCurrentNightscoutData()
        guard !nightscoutData.isOlderThanXMinutes(15) else {
            return
        }
        
        // the session must be active in order to send data
        guard WCSession.default.activationState == .activated else {
            return
        }
        
        // update watch
        if lastSentNightscoutDataTime != nightscoutData.time {
            // Assuring we are sending ONLY once a nightscout data...
            // ... and respecting the update rate!
            if let lastWatchUpdateTime = self.lastWatchUpdateTime, (Calendar.current.date(byAdding: .minute, value: 5, to: lastWatchUpdateTime) ?? Date()) >= Date() {
                
                // do nothing, last watch update was more recent than update rate, will skip updating it now!
            } else {
                
                // Send the regular application context for the watch app.
                let message: NightscoutDataMessage
                if let suppliedDisplaySnapshot {
                    message = NightscoutDataMessage(
                        nightscoutData: nightscoutData,
                        displaySnapshot: suppliedDisplaySnapshot
                    )
                } else {
                    message = NightscoutDataMessage()
                }
                message.send()

                // updateApplicationContext does not reliably wake the watch
                // app in the background. A complication transfer does, and
                // the receiving handler reloads all WidgetKit timelines.
                if WCSession.default.isComplicationEnabled {
                    var complicationMessage = message.dictionary
                    complicationMessage["_type"] = String(describing: type(of: message))
                    WCSession.default.transferCurrentComplicationUserInfo(complicationMessage)
                }
                self.lastSentNightscoutDataTime = nightscoutData.time
                self.lastWatchUpdateTime = Date()
            }
        }
    }
    
    private func sendOrTransmitToWatch(_ message: [String : Any]) {
        
        // send message if watch is reachable
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: { data in
                print("Received data: \(data)")
            }, errorHandler: { error in
                print(error)
                
                // transmit message on failure
                try? WCSession.default.updateApplicationContext(message)
            })
        } else {
            
            // otherwise, transmit application context
            try? WCSession.default.updateApplicationContext(message)
        }
    }
}
