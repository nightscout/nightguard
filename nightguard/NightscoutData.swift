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
    var bgdelta : Float = 0.0
    var timeString : String {
        get {
            if time == 0 {
                return "-min"
            }
            // calculate how old the current data is
            let currentTime = Int64(NSDate().timeIntervalSince1970 * 1000)
            let difference = (currentTime - time.longLongValue) / 60000
            if difference > 59 {
                return ">1Hr"
            }
            return String(difference) + "min"
        }
    }
    var time : NSNumber = 0
    var battery : String = "---"
    
    // NSCoder methods to make this class serializable
    
    override init () {
        super.init()
    }
    
    /* 
        Code to deserialize BgData content. The error handling is need in case that old serialized
        data leads to an error.
    */
    required init(coder decoder: NSCoder) {

        guard let sgv = decoder.decodeObjectForKey("sgv") as? String else {
            return
        }
        self.sgv = sgv
        
        guard let bgdeltaString = decoder.decodeObjectForKey("bgdeltaString") as? String else {
            return
        }
        self.bgdeltaString = bgdeltaString
        
        guard let bgdelta = decoder.decodeObjectForKey("bgdelta") as? Float else {
            return
        }
        self.bgdelta = bgdelta
        
        guard let time = decoder.decodeObjectForKey("time") as? NSNumber else {
            return
        }
        self.time = time
        
        guard let battery = decoder.decodeObjectForKey("battery") as? String else {
            return
        }
        self.battery = battery
    }
    
    /*
        Code to serialize the BgData to store them in UserDefaults.
    */
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(self.sgv, forKey: "sgv")
        aCoder.encodeObject(self.bgdeltaString, forKey: "bgdeltaString")
        aCoder.encodeObject(self.bgdelta, forKey: "bgdelta")
        aCoder.encodeObject(self.time, forKey: "time")
        aCoder.encodeObject(self.battery, forKey: "battery")
    }
    
    func isOlderThan5Minutes() -> Bool {
        return isOlderThanXMinutes(5)
    }
    
    func isOlderThan15Minutes() -> Bool {
        return isOlderThanXMinutes(15)
    }
    
    private func isOlderThanXMinutes(minutes : Int) -> Bool {
        let lastUpdateAsNSDate : NSDate = NSDate(timeIntervalSince1970: time.doubleValue / 1000)
        let timeInterval : Int = Int(NSDate().timeIntervalSinceDate(lastUpdateAsNSDate))
        
        return timeInterval > minutes * 60
    }
}