//
//  TimeService.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 23.01.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation

class TimeService {
    
    fileprivate static var testTime : Double? = nil
    fileprivate static var testMode : Bool = false
    
    static func getStartOfCurrentDay() -> Double {
        
        let date = Date()
        let cal = Calendar(identifier: .gregorian)
        let startOfCurrentDay = cal.startOfDay(for: date)
        
        return Double(startOfCurrentDay.timeIntervalSince1970 * 1000)
    }
    
    static func setTestTime(_ testTime : Double) {
        self.testTime = testTime;
    }
    
    static func getCurrentTime() -> Double {
        if testTime != nil {
            return testTime!
        } else {
            return Date().timeIntervalSince1970
        }
    }
    
    static func getToday() -> Date {
        if testTime != nil {
            return Date(timeIntervalSince1970: testTime!)
        }
        return Date()
    }
    
    static func get4DaysAgo() -> Date {
        return getToday().addingTimeInterval(4 * -24 * 60 * 60)
    }
    
    static func getNrOfDaysAgo(_ nrOfDaysAgo : Int) -> Date {
        return getToday().addingTimeInterval(Double(nrOfDaysAgo) * -24 * 60 * 60)
    }
    
    static func getYesterday() -> Date {
        let yesterday = getToday().addingTimeInterval(-24*60*60)

        return yesterday
    }
    
    static func getTomorrow() -> Date {
        let tomorrow = getToday().addingTimeInterval(24*60*60)
        
        return tomorrow
    }
    
    static func isYesterday(_ microsSince1970 : Double) -> Bool {
        let secondsSince1970 = microsSince1970 / 1000
        
        let calendar = Calendar.current
        let startOfYesterday = calendar.startOfDay(for: TimeService.getYesterday()).timeIntervalSince1970
        let endOfYesterday = calendar.startOfDay(for: TimeService.getToday()).timeIntervalSince1970
        
        return startOfYesterday <= secondsSince1970 &&
            secondsSince1970 <= endOfYesterday
        
    }
    
    static func isOlderThan30Minutes(_ date : Date) -> Bool {
        return getToday().addingTimeInterval(-30 * 60).compare(date) == ComparisonResult.orderedDescending
    }
}
