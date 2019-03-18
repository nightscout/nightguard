//
//  BasicStats.swift
//  nightguard
//
//  Created by Florian Preknya on 3/1/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation

struct BasicStats {
    
    // The time period of the stats data (most recent data)
    enum Period: CustomStringConvertible {
        case last24h
        case last8h
        case today
        case yesterday
        case todayAndYesterday

        var description: String {
            
            switch self {
            case .last24h:
                return "Last 24h"
            case .last8h:
                return "Last 8h"
            case .today:
                return "Today"
            case .yesterday:
                return "Yesterday"
            case .todayAndYesterday:
                return "Today & Yesterday"
            }
        }
        
        // how many minutes are in the period?
        var minutes: Int {
            switch self {
            case .last24h:
                return 24 * 60
            case .last8h:
                return 8 * 60
            case .today:
                let secondsFromStartOfDay = Date().timeIntervalSince(
                    Calendar(identifier: .gregorian).startOfDay(for: Date())
                )
                return Int(secondsFromStartOfDay / 60)
            case .yesterday:
                return 24 * 60
            case .todayAndYesterday:
                return Period.today.minutes + 24 * 60
            }
        }
        
        // the period readings
        var readings: [BloodSugar] {
            switch self {
            case .last24h:
                let now = Date()

                // get today's data
                let todaysReadings = NightscoutCacheService.singleton.getTodaysBgData()
                
                // get yesterday's data, the ones that are newer than 24h
                let yesterdaysReadings = NightscoutCacheService.singleton.getYesterdaysBgData()
                let yesterdaysReadingsNewerThan24h = yesterdaysReadings.suffix(yesterdaysReadings.count) { $0.date > now }
                
                return yesterdaysReadingsNewerThan24h + todaysReadings
                
            case .last8h:
                let eightHoursBefore = Date().addingTimeInterval(-8 * 60 * 60)

                // get today's data
                let todaysReadings = NightscoutCacheService.singleton.getTodaysBgData()
                let todaysReadingsNewerThan8h = todaysReadings.suffix(todaysReadings.count) { $0.date > eightHoursBefore }
                if todaysReadingsNewerThan8h.count < todaysReadings.count {
                    return todaysReadingsNewerThan8h
                } else {
                    
                    // hack for yesterday 8 hours before (because yesterday dates are changed for today - a trick for displaying them in the graph) - we'll have to add 16h for getting the corresponding readings
                    let eightHoursBeforeForYesterday = eightHoursBefore.addingTimeInterval(16 * 60 * 60)
                    let yesterdaysReadings = NightscoutCacheService.singleton.getYesterdaysBgData()
                    let yesterdaysReadingsNewerThan8h = yesterdaysReadings.suffix(yesterdaysReadings.count) { $0.date > eightHoursBeforeForYesterday }

                    return yesterdaysReadingsNewerThan8h + todaysReadingsNewerThan8h
                }

            case .today:
                return NightscoutCacheService.singleton.getTodaysBgData()
            case .yesterday:
                return NightscoutCacheService.singleton.getYesterdaysBgData()
            case .todayAndYesterday:
                return NightscoutCacheService.singleton.getYesterdaysBgData() + NightscoutCacheService.singleton.getTodaysBgData()
            }
        }
        
    }
    let period: Period
    
    let averageGlucose: Float
    let a1c: Float
    
    let readingsCount: Int
    var readingsMaximumCount: Int  {
        return period.minutes / 5 // one reading each 5 minutes
    }
    var readingsPercentage: Float {
        return Float(readingsCount) / Float(readingsMaximumCount)
    }
    
    let invalidValuesCount: Int
    var invalidValuesPercentage: Float {
        return (readingsCount != 0) ? (Float(invalidValuesCount) / Float(readingsCount)) : 0
    }
    
    let lowValuesCount: Int
    var lowValuesPercentage: Float {
        let validReadingsCount = readingsCount - invalidValuesCount
        return (validReadingsCount != 0) ? (Float(lowValuesCount) / Float(validReadingsCount)) : 0
    }
    
    let highValuesCount: Int
    var highValuesPercentage: Float {
        let validReadingsCount = readingsCount - invalidValuesCount
        return (validReadingsCount != 0) ? (Float(highValuesCount) / Float(validReadingsCount)) : 0
    }
    
    let inRangeValuesCount: Int
    var inRangeValuesPercentage: Float {
        let validReadingsCount = readingsCount - invalidValuesCount
        return (validReadingsCount != 0) ? (Float(inRangeValuesCount) / Float(validReadingsCount)) : 0
    }
    
    init(period: Period = Period.last24h) {
        
        self.period = period
        
        // get the readings
        let readings = period.readings
        
        // get the upper/lower bounds
        let upperBound = UserDefaultsRepository.upperBound.value
        let lowerBound = UserDefaultsRepository.lowerBound.value

        self.readingsCount = readings.count
        
        var invalidValuesCount = 0, lowValuesCount = 0, highValuesCount = 0, inRangeValuesCount = 0
        var totalGlucoseCount: Float = 0
        for reading in readings {
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
            
            totalGlucoseCount += reading.value
        }
        
        self.invalidValuesCount = invalidValuesCount
        self.lowValuesCount = lowValuesCount
        self.highValuesCount = highValuesCount
        self.inRangeValuesCount = inRangeValuesCount
        
        self.averageGlucose = totalGlucoseCount / Float(readings.count - invalidValuesCount)
        self.a1c = (46.7 + self.averageGlucose) / 28.7
    }
}
