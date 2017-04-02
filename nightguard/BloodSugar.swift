//
//  BloodSugar.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 25.04.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation

// This class contains the Bloodsugar Value for a certain point in time.
// this class is immutable. Recreate the object in order to change values.
class BloodSugar : NSCoder {
    let value : Float
    let timestamp : Double
    
    init(value : Float, timestamp : Double) {
        self.value = value
        self.timestamp = timestamp
    }
    
    required convenience init(coder decoder: NSCoder) {
        
        self.init(value : decoder.decodeObject(forKey: "value") as! Float,
                  timestamp : decoder.decodeObject(forKey: "timestamp") as! Double)
    }

    func encodeWithCoder(_ coder: NSCoder) {
        coder.encode(self.value, forKey: "value")
        coder.encode(self.timestamp, forKey: "timestamp")
    }
    
    static func getMinimumTimestamp(_ bloodValues : [BloodSugar]) -> Double {
        
        var minimumTimestamp : Double = Double.infinity
        for bloodSugar in bloodValues {
            if bloodSugar.timestamp < minimumTimestamp {
                minimumTimestamp = bloodSugar.timestamp
            }
        }
        return minimumTimestamp
    }
    
    static func getMaximumTimestamp(_ bloodValues : [BloodSugar]) -> Double {
        
        var maximumTimestamp : Double = 0
        for bloodSugar in bloodValues {
            if bloodSugar.timestamp > maximumTimestamp {
                maximumTimestamp = bloodSugar.timestamp
            }
        }
        return maximumTimestamp
    }
}
