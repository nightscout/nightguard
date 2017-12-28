//
//  BgData.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 26.12.15.
//  Copyright © 2015 private. All rights reserved.
//

import Foundation

// Contains all available information of a current Blood Glucose value.
// This data can be stored in the user defaults.
class NightscoutData : NSObject, NSCoding {
    
    var sgv : String = "---"
    var bgdeltaString : String = "---"
    var bgdeltaArrow : String = "-"
    var bgdelta : Float = 0.0
    var hourAndMinutes : String {
        get {
            if time == 0 {
                return "??:??"
            }
            let formatter = DateFormatter.init()
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
            // calculate how old the current data is
            let currentTime = Int64(Date().timeIntervalSince1970 * 1000)
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
    
    // NSCoder methods to make this class serializable
    
    override init () {
        super.init()
    }
    
    /* 
        Code to deserialize BgData content. The error handling is need in case that old serialized
        data leads to an error.
    */
    required init(coder decoder: NSCoder) {

        guard let sgv = decoder.decodeObject(forKey: "sgv") as? String else {
            return
        }
        self.sgv = sgv
        
        guard let bgdeltaString = decoder.decodeObject(forKey: "bgdeltaString") as? String else {
            return
        }
        self.bgdeltaString = bgdeltaString
        
        guard let bgdeltaArrow = decoder.decodeObject(forKey: "bgdeltaArrow") as? String else {
            return
        }
        self.bgdeltaArrow = bgdeltaArrow
        
        guard let bgdelta = decoder.decodeObject(forKey: "bgdelta") as? Float else {
            return
        }
        self.bgdelta = bgdelta
        
        guard let time = decoder.decodeObject(forKey: "time") as? NSNumber else {
            return
        }
        self.time = time
        
        guard let battery = decoder.decodeObject(forKey: "battery") as? String else {
            return
        }
        self.battery = battery
        
        guard let iob = decoder.decodeObject(forKey: "iob") as? String else {
            return
        }
        self.iob = iob
    }
    
    /*
        Code to serialize the BgData to store them in UserDefaults.
    */
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.sgv, forKey: "sgv")
        aCoder.encode(self.bgdeltaString, forKey: "bgdeltaString")
        aCoder.encode(self.bgdeltaArrow, forKey: "bgdeltaArrow")
        aCoder.encode(self.bgdelta, forKey: "bgdelta")
        aCoder.encode(self.time, forKey: "time")
        aCoder.encode(self.battery, forKey: "battery")
        aCoder.encode(self.iob, forKey: "iob")
    }
    
    func isOlderThan5Minutes() -> Bool {
        return isOlderThanXMinutes(5)
    }
    
    func isOlderThanXMinutes(_ minutes : Int) -> Bool {
        let lastUpdateAsNSDate : Date = Date(timeIntervalSince1970: time.doubleValue / 1000)
        let timeInterval : Int = Int(Date().timeIntervalSince(lastUpdateAsNSDate))
        
        return timeInterval > minutes * 60
    }
}
