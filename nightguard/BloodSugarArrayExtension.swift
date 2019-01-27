//
//  BloodSugarArrayExtension.swift
//  nightguard
//
//  Created by Florian Preknya on 12/18/18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation

/// The blood sugar trend, calculated by examining an array of BG readings
enum BloodSugarTrend {
    case ascending
    case descending
    case unknown
}

extension Array where Element: BloodSugar {

    static func latestFromRepositories() -> [BloodSugar] {
        
        // get today's data
        var result = NightscoutCacheService.singleton.getTodaysBgData()

        // augment it with current reading (if not already there)
        let nightscoutData = NightscoutCacheService.singleton.getCurrentNightscoutData()
        result.assureCurrentReadingExists(nightscoutData)
        
        // if day just began, we don't have enough readings from today, so we'll take also the some of the last yesterday's readings
        
        // skip adding the yesterday's data for the moment!
//        if result.count < 12 {
//            result.insert(contentsOf: NightscoutCacheService.singleton.getYesterdaysBgData().suffix(12), at: 0)
//        }
        
        return result
    }
}

extension Array where Element: BloodSugar {
    
    /// Get the array of deltas, calculating each delta element as the difference
    /// between the current reading value and the previous reading value.
    ///
    /// The returned array will have count - 1 elements (because the first element
    /// from the readings array have no previous BG reading to compare with).
    var deltas: [Float] {
        
        guard !self.isEmpty else {
            return []
        }
        
        var result: [Float] = []
        for i in 0..<(self.count-1) {
            result.append(self[i+1].value - self[i].value)
        }
        
        return result
    }
    
    /// Get the BG readings trend by checking the dynamics of the last 3 readings
    ///
    /// The same algorithm is implemented in xDrip+ for getting the trend.
    /// https://github.com/jamorham/xDrip-plus/blob/master/app/src/main/java/com/eveningoutpost/dexdrip/Models/BgReading.java
    var trend: BloodSugarTrend {
        
        guard let readings = self.lastConsecutive(3) else {
            return .unknown
        }
        
        let deltasInMgdl = readings.deltas.map { UnitsConverter.toMgdl($0) }
        if abs(deltasInMgdl[1]) > 4 || abs(deltasInMgdl[0] + deltasInMgdl[1]) > 10 {
            return deltasInMgdl[1] > 0 ? .ascending : .descending
        } else {
            return .unknown
        }
    }
    
    /// Get the readings from last X minutes
    func lastXMinutes(_ minutes: Int) -> Array<BloodSugar> {
        
        let now = Date()
        return self.reversed().prefix(while: { reading in
            let readingDate = Date(timeIntervalSince1970: reading.timestamp / 1000)
            return now.timeIntervalSince(readingDate) < (Double(minutes) * 60)
        }).reversed()
    }
    
    /// Get the most recent consecutive X readings, tolerating a number of missed readings.
    ///
    /// If there are not enough most recent values or the number of missed values exceed the
    /// missed param, nil is returned.
    func lastConsecutive(_ count: Int, maxMissedReadings: Int = 1) -> [BloodSugar]? {
        let minutes = (count + maxMissedReadings) * 5 + 2
        let readings = lastXMinutes(minutes).suffix(count)
        return readings.count == count ? Array<BloodSugar>(readings) : nil
    }
    
    /// Appends the current reading to readings if it doesn't exist already.
    mutating func assureCurrentReadingExists(_ nightscoutData: NightscoutData) {
        
        if (self.last?.timestamp ?? 0) < nightscoutData.time.doubleValue {
            self.append(
                Element (value: Float(nightscoutData.sgv)!, timestamp: nightscoutData.time.doubleValue)
            )
        }
    }
    
    /// If current reading doesn't exist, will retunr a new array containing all the readings
    /// plus the current reading as last element, otherwise will return the original array.
    func assuringCurrentReadingExists(_ nightscoutData: NightscoutData) -> [BloodSugar] {
        
        if (self.last?.timestamp ?? 0) < nightscoutData.time.doubleValue {
            var copy = self
            copy.assureCurrentReadingExists(nightscoutData)
            return copy
        } else {
            return self
        }
    }
}
