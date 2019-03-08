//
//  BasicStats.swift
//  nightguard
//
//  Created by Florian Preknya on 3/1/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation

struct BasicStats {
    
    let averageGlucose: Float
    let a1c: Float
    
    let readingsCount: Int
    let readingsMaximumCount: Int = 288 // maximum for 24h
    var readingsPercentage: Float {
        return Float(readingsCount) / Float(readingsMaximumCount)
    }
    
    let invalidValuesCount: Int
    var invalidValuesPercentage: Float {
        return (readingsCount != 0) ? (Float(invalidValuesCount) / Float(readingsCount)) : 0
    }
    
    let lowValuesCount: Int
    var lowValuesPercentage: Float {
        return (readingsCount != 0) ? (Float(lowValuesCount) / Float(readingsCount)) : 0
    }
    
    let highValuesCount: Int
    var highValuesPercentage: Float {
        return (readingsCount != 0) ? (Float(highValuesCount) / Float(readingsCount)) : 0
    }
    
    let inRangeValuesCount: Int
    var inRangeValuesPercentage: Float {
        return (readingsCount != 0) ? (Float(inRangeValuesCount) / Float(readingsCount)) : 0
    }
    
    init() {
        
        // get the readings
        
        // get today's data
        let todaysReadings = NightscoutCacheService.singleton.getTodaysBgData()
        
        // get yesterday's data, the ones that are newer than 24h
        let now = Date()
        let yesterdaysReadings = NightscoutCacheService.singleton.getYesterdaysBgData()
        let yesterdaysReadingsNewerThan24h = yesterdaysReadings.suffix(yesterdaysReadings.count) { $0.date > now }

        // 24h values
        let last24hReadings = yesterdaysReadingsNewerThan24h + todaysReadings
        
        // get the upper/lower bounds
        let upperBound = UserDefaultsRepository.upperBound.value
        let lowerBound = UserDefaultsRepository.lowerBound.value

        self.readingsCount = last24hReadings.count
        
        var invalidValuesCount = 0, lowValuesCount = 0, highValuesCount = 0, inRangeValuesCount = 0
        for reading in last24hReadings {
            guard reading.isValid else {
                invalidValuesCount += 1
                continue
            }
            
            if reading.value <= lowerBound {
                lowValuesCount += 1
            } else if reading.value >= upperBound {
                highValuesCount += 1
            } else {
                inRangeValuesCount += 1
            }
        }
        
        self.invalidValuesCount = invalidValuesCount
        self.lowValuesCount = lowValuesCount
        self.highValuesCount = highValuesCount
        self.inRangeValuesCount = inRangeValuesCount
        
        self.averageGlucose = last24hReadings.reduce(0, { sum, bg in return sum + bg.value }) / Float(last24hReadings.count)
        self.a1c = (46.7 + self.averageGlucose) / 28.7
    }
}
