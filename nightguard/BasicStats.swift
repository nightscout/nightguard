//
//  BasicStats.swift
//  nightguard
//
//  Created by Florian Preknya on 3/1/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation

/**
 The stats values calculated by considering all the readings for a given (recent) period.
 */
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
                return NSLocalizedString("Last 24h", comment: "Stats button value for Last 24h")
            case .last8h:
                return NSLocalizedString("Last 8h", comment: "Stats button value for Last 8h")
            case .today:
                return NSLocalizedString("Today", comment: "Stats button value for Today")
            case .yesterday:
                return NSLocalizedString("Yesterday", comment: "Stats button value for Yesterday")
            case .todayAndYesterday:
                return NSLocalizedString("Today & Yesterday", comment: "Stats button value for Today & Yesterday")
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
                    let eightHoursBeforeForYesterday = eightHoursBefore.addingTimeInterval(24 * 60 * 60)
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
    
    // http://www.ngsp.org/ifccngsp.asp
    // DCCT (Diabetes Control and Complications Trial) units - percentage
    let a1c: Float
    // IFCC (International Federation of Clinical Chemistry) units - mmol/mol
    let ifccA1c: Float
    
    let standardDeviation: Float
    let coefficientOfVariation: Float
    
    let readingsCount: Int
    var readingsMaximumCount: Int  {
        return max(period.minutes / 5, readingsCount) // one reading each 5 minutes
    }
    var readingsPercentage: Float {
        return (readingsMaximumCount != 0) ? (Float(readingsCount) / Float(readingsMaximumCount)).roundTo3f.clamped(to: 0...1) : 0
    }
    
    let invalidValuesCount: Int
    var invalidValuesPercentage: Float {
        return (readingsCount != 0) ? (Float(invalidValuesCount) / Float(readingsCount)).roundTo3f : 0
    }
    
    let lowValuesCount: Int
    var lowValuesPercentage: Float {
        if lowValuesCount == 0 {
            return 0.0
        } else {
            // to avoid situations when the sum of high, low & in range is not exactly 100%
            return Float(1.0) - highValuesPercentage - inRangeValuesPercentage
        }
//        let validReadingsCount = readingsCount - invalidValuesCount
//        return (validReadingsCount != 0) ? (Float(lowValuesCount) / Float(validReadingsCount)).roundTo3f : 0
    }
    
    let highValuesCount: Int
    var highValuesPercentage: Float {
        let validReadingsCount = readingsCount - invalidValuesCount
        return (validReadingsCount != 0) ? (Float(highValuesCount) / Float(validReadingsCount)).roundTo3f : 0
    }
    
    let inRangeValuesCount: Int
    var inRangeValuesPercentage: Float {
        let validReadingsCount = readingsCount - invalidValuesCount
        return (validReadingsCount != 0) ? (Float(inRangeValuesCount) / Float(validReadingsCount)).roundTo3f : 0
    }
    
    /// Returns true if the stats are actual, with respect for the input data (contains the most recent readings & the current upper-lower bounds).
    var isUpToDate: Bool {
        return
            self.period.readings.last == self.latestReading &&
            self.upperBound == UserDefaultsRepository.upperBound.value &&
            self.lowerBound == UserDefaultsRepository.lowerBound.value
    }
    
    // store some relevant data about the stats input data (to be able to tell later if the stats are "up to date")
    fileprivate let latestReading: BloodSugar?
    fileprivate let upperBound: Float
    fileprivate let lowerBound: Float
    
    init(period: Period = Period.last24h) {
        
        self.period = period
        
        // get the readings
        let readings = period.readings
        
        // get the upper/lower bounds
        self.upperBound = UserDefaultsRepository.upperBound.value
        self.lowerBound = UserDefaultsRepository.lowerBound.value

        self.readingsCount = readings.count
        self.latestReading = readings.last
        
        var invalidValuesCount = 0, lowValuesCount = 0, highValuesCount = 0, inRangeValuesCount = 0
        var totalGlucoseCount: Float = 0
        
        var validReadings: [BloodSugar] = []
        for reading in readings {
            guard reading.isValid else {
                invalidValuesCount += 1
                continue
            }
            
            validReadings.append(reading)
            
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
        self.ifccA1c = (self.a1c - 2.152) / 0.09148
        self.standardDeviation = Float(validReadings.map { Double($0.value) }.standardDeviation)
        self.coefficientOfVariation = (self.averageGlucose != 0) ? (self.standardDeviation / self.averageGlucose).roundTo3f : Float.nan
    }
}

extension BasicStats {
    
    var formattedInRangeValuesPercentage: String? {
        return formattedPercent(inRangeValuesPercentage)
    }
    
    var formattedLowValuesPercentage: String? {
        return formattedPercent(lowValuesPercentage)
    }

    var formattedHighValuesPercentage: String? {
        return formattedPercent(highValuesPercentage)
    }
    
    var formattedAverageGlucose: String? {
        return formattedUnits(averageGlucose)
    }
    
    var formattedA1c: String? {
        return a1c.isNaN ? nil : "\(a1c.round(to: 1).cleanValue)%"
    }
    
    var formattedIFCCA1c: String? {
        return ifccA1c.isNaN ? nil : "\(ifccA1c.rounded().cleanValue) mmol/mol"
    }
    
    var formattedStandardDeviation: String? {
        return formattedUnits(standardDeviation)
    }
    
    var formattedCoefficientOfVariation: String? {
        return formattedPercent(coefficientOfVariation)
    }
    
    var formattedReadingsPercentage: String? {
        return formattedPercent(readingsPercentage)
    }
    
    var formattedInvalidValuesPercentage: String? {
        return formattedPercent(invalidValuesPercentage)
    }
    
    private func formattedPercent(_ value: Float) -> String? {
        return value.isNaN ? nil : "\((value * 100).cleanValue)%"
    }
    
    private func formattedUnits(_ value: Float) -> String? {
        return value.isNaN ? nil :
        UnitsConverter.toDisplayUnits("\(value)") + " \(UserDefaultsRepository.units.value.description)"
    }
}
