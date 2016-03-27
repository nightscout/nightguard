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
}