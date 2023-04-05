//
//  NightscoutDataEntry.swift
//  nightguard
//
//  Created by Dirk Hermanns on 02.04.23.
//  Copyright © 2023 private. All rights reserved.
//

import Foundation
import WidgetKit
import Intents

struct NightscoutDataEntry: TimelineEntry {
    
    var date: Date = Date()
    
    var sgv : String = "---"
    // the delta Value in Display Units
    var bgdeltaString : String = "---"
    var bgdeltaArrow : String = "-"
    // the delta value in mgdl
    var bgdelta : Float = 0.0
    var hourAndMinutes : String {
        get {
            if time == 0 {
                return "??:??"
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            
            let date = Date.init(timeIntervalSince1970: Double(time.int64Value / 1000))
            return formatter.string(from: date)
        }
    }
    var timeString : String {
        get {
            if time == 0 {
                return "-min"
            }
            
            // trick: when displaying the time, we'll add 30 seconds to current time for showing the difference like Nightscout does (0-30 seconds: "0 mins", 31-90 seconds: "1 min", ...)
            let thirtySeconds = Int64(30 * 1000)
            
            // calculate how old the current data is
            let currentTime = Int64(Date().timeIntervalSince1970 * 1000) + thirtySeconds
            let difference = (currentTime - time.int64Value) / 60000
            if difference > 59 {
                return ">1Hr"
            }
            return String(difference) + "min"
        }
    }
    var time : NSNumber = 0
    var battery : String = "---"
    var iob : String = ""
    var cob : String = ""
    let configuration: ConfigurationIntent
}
