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
class BgData : NSObject, NSCoding {
    var sgv : String = "---"
    var bgdeltaString : String = "---"
    var bgdelta : NSNumber = 0.0
    var timeString : String = "--:--"
    var time : NSNumber = 0
    var battery : String = "---"
    
    func isOlderThan5Minutes() -> Bool {
        let lastUpdateAsNSDate : NSDate = NSDate(timeIntervalSince1970: time.doubleValue / 1000)
        let timeInterval : Int = Int(NSDate().timeIntervalSinceDate(lastUpdateAsNSDate))
        
        return timeInterval > 5 * 60
    }
    
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
        
        guard let bgdelta = decoder.decodeObjectForKey("bgdelta") as? NSNumber else {
            return
        }
        self.bgdelta = bgdelta
        
        guard let timeString = decoder.decodeObjectForKey("timeString") as? String else {
            return
        }
        self.timeString = timeString
        
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
        aCoder.encodeObject(self.timeString, forKey: "timeString")
        aCoder.encodeObject(self.time, forKey: "time")
        aCoder.encodeObject(self.battery, forKey: "battery")
    }
}