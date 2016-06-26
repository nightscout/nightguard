//
//  TimeService.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 23.01.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation

class TimeService {
    
    private static var testTime : Double? = nil
    private static var testMode : Bool = false
    
    static func setTestTime(testTime : Double) {
        self.testTime = testTime;
    }
    
    static func getCurrentTime() -> Double {
        if testTime != nil {
            return testTime!
        } else {
            return NSDate().timeIntervalSince1970
        }
    }
    
    static func getToday() -> NSDate {
        if testTime != nil {
            return NSDate(timeIntervalSince1970: testTime!)
        }
        return NSDate()
    }
    
    static func get4DaysAgo() -> NSDate {
        return getToday().dateByAddingTimeInterval(4 * -24 * 60 * 60)
    }
    
    static func getYesterday() -> NSDate {
        let yesterday = getToday().dateByAddingTimeInterval(-24*60*60)

        return yesterday
    }
    
    static func isYesterday(microsSince1970 : Double) -> Bool {
        let secondsSince1970 = microsSince1970 / 1000
        
        let calendar = NSCalendar.currentCalendar()
        let startOfYesterday = calendar.startOfDayForDate(TimeService.getYesterday()).timeIntervalSince1970
        let endOfYesterday = calendar.startOfDayForDate(TimeService.getToday()).timeIntervalSince1970
        
        return startOfYesterday <= secondsSince1970 &&
            secondsSince1970 <= endOfYesterday
        
    }
}