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
    
    var date: Date {
        return Date(timeIntervalSince1970: timestamp / 1000)
    }
    
    required init(value : Float, timestamp : Double) {
        self.value = value
        self.timestamp = timestamp
    }
    
    // when the noise is very strong, values are not computable... and we should exclude them from any logic & presentation
    var isValid: Bool {
        return BloodSugar.isValid(value: self.value)
    }
    
    static func isValid(value: Float) -> Bool {
        return UnitsConverter.toMgdl(value) > 10
    }
    
    override var debugDescription: String {
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let time = timeFormatter.string(from: self.date)
        
        let value: String
        if self.value.isNaN{
            value = "NaN"
        } else if self.value.isInfinite {
            value = "inf"
        } else {
            value = "\(Int64(self.value.rounded()))"
        }
        
        return "\(value) @ \(time)"
    }
    
    @objc required convenience init(coder decoder: NSCoder) {

        // only initialize if base values could be decoded
        let value = decoder.decodeFloat(forKey: "value")
        let timestamp = decoder.decodeDouble(forKey: "timestamp")
        
        self.init(value : value, timestamp :  timestamp)
    }

    @objc func encodeWithCoder(_ coder: NSCoder) {
        coder.encode(self.value, forKey: "value")
        coder.encode(self.timestamp, forKey: "timestamp")
    }
    
    func isOlderThanXMinutes(_ minutes : Int) -> Bool {
        let timeInterval = Int(Date().timeIntervalSince(self.date))
        return timeInterval > minutes * 60
    }
}
