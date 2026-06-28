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
import SwiftUI

struct NightscoutDataEntry: TimelineEntry {
    
    var date: Date = Date()
    
    var sgv : String = "---"
    var sgvColor : UIColor = UIColor.white
    // the delta Value in Display Units
    var bgdeltaString : String = "---"
    var bgdeltaColor : UIColor = UIColor.white
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
    var time : NSNumber = Date().timeIntervalSince1970 as NSNumber
    var battery : String = "---"
    var iob : String = ""
    var cob : String = ""
    var snoozedUntilTimestamp : TimeInterval = 0
    var lastBGValues : [BgEntry] = []
    var errorMessage: String = ""
    let configuration: ConfigurationIntent
    var entryDate: Date = Date()
    
    static let previewValues = NightscoutDataEntry(
        date: Date.now,
        sgv: "100",
        sgvColor: UIColor.nightguardGreen(),
        bgdeltaString: "+2",
        bgdeltaColor: UIColor.nightguardGreen(),
        bgdeltaArrow: "-",
        bgdelta: 2,
        time: NSNumber(value: Date.now.timeIntervalSince1970 * 1000 - 120*1000),
        battery: "100",
        iob: "0.0",
        cob: "0.0",
        snoozedUntilTimestamp:
            0,
        lastBGValues: [
            BgEntry(value: "100", valueColor: UIColor.nightguardGreen(), delta: "+2", timestamp: Date.now.timeIntervalSince1970 * 1000 - 120*1000, arrow: "-"),
            BgEntry(value: "98", valueColor: UIColor.nightguardGreen(), delta: "-3", timestamp: (Date.now.timeIntervalSince1970 * 1000) - (60*5*1000), arrow: "-"),
            BgEntry(value: "101", valueColor: UIColor.nightguardGreen(), delta: "+2", timestamp: (Date.now.timeIntervalSince1970 * 1000) - (60*10*1000), arrow: "-")
        ],
        configuration: ConfigurationIntent())
}

extension NightscoutDataEntry {
    init(snapshot: NightguardDisplaySnapshot) {
        self.init(
            date: snapshot.date,
            sgv: snapshot.sgv,
            sgvColor: UIColor(
                red: CGFloat(snapshot.sgvColorRed),
                green: CGFloat(snapshot.sgvColorGreen),
                blue: CGFloat(snapshot.sgvColorBlue),
                alpha: 1
            ),
            bgdeltaString: snapshot.bgdeltaString,
            bgdeltaColor: UIColor(
                red: CGFloat(snapshot.bgdeltaColorRed),
                green: CGFloat(snapshot.bgdeltaColorGreen),
                blue: CGFloat(snapshot.bgdeltaColorBlue),
                alpha: 1
            ),
            bgdeltaArrow: snapshot.bgdeltaArrow,
            bgdelta: Float(snapshot.bgdelta),
            time: NSNumber(value: snapshot.timestamp),
            battery: snapshot.battery,
            iob: snapshot.iob,
            cob: snapshot.cob,
            snoozedUntilTimestamp: snapshot.snoozedUntilTimestamp,
            lastBGValues: snapshot.lastBGValues.map { bgValue in
                BgEntry(
                    value: bgValue.value,
                    valueColor: UIColor(
                        red: CGFloat(bgValue.valueColorRed),
                        green: CGFloat(bgValue.valueColorGreen),
                        blue: CGFloat(bgValue.valueColorBlue),
                        alpha: 1
                    ),
                    delta: bgValue.delta,
                    timestamp: bgValue.timestamp,
                    arrow: bgValue.arrow
                )
            },
            errorMessage: "",
            configuration: ConfigurationIntent()
        )
    }
}

struct BgEntry : Identifiable, Hashable {
    
    let id = UUID() 
    let value: String
    let valueColor: UIColor
    let delta: String
    let timestamp: Double
    let arrow: String
}
