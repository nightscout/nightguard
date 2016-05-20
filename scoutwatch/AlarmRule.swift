//
//  AlarmRule.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 25.01.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation

/**
 * This class implements the Rules for which an alarm should be played.
 * 
 * This is right now the case if
 * - the blood glucose is above 180 or below 80
 * - or the last value is older than 15 Minutes
 *
 * Further more an Alarm can be snoozed temporarily.
 * Therefore this class remembers whether an alarm has been snoozed
 * and how long the snooze should last.
 */
class AlarmRule {
    
    private static var snoozedUntilTimestamp = NSTimeInterval()
    
    static var numberOfConsecutiveValues : Int = 3
    static var deltaAmount : Int = 8
    static var isEdgeDetectionAlarmEnabled : Bool = false
    
    static var alertIfAboveValue : Int = 180
    static var alertIfBelowValue : Int = 80
    
    /*
     * Returns true if the alarm should be played.
     * Snooze is true if the Alarm has been manually deactivated.
     * Suspended is true if the Alarm has been technically deactivated for a short period of time.
     */
    static func isAlarmActivated(nightscoutData : NightscoutData, bloodValues : [BloodSugar]) -> Bool {
        
        if isSnoozed() {
            return false
        }
        
        if nightscoutData.isOlderThan15Minutes() {
            return true
        }
        
        if isTooHighOrTooLow(Int(nightscoutData.sgv)!) {
            return true
        }
        
        if isEdgeDetectionAlarmEnabled && bloodValuesAreIncreasingOrDecreasingToFast(bloodValues) {
            return true
        }
        
        return false
    }
    
    private static func isTooHighOrTooLow(bloodGlucose : Int) -> Bool {
        return bloodGlucose > alertIfAboveValue || bloodGlucose < alertIfBelowValue
    }
    
    private static func bloodValuesAreIncreasingOrDecreasingToFast(bloodValues : [BloodSugar]) -> Bool {
        if bloodValues.count < numberOfConsecutiveValues {
            return false;
        }
        
        let maxItems = bloodValues.count
        var positiveDirection : Bool? = nil
        for index in maxItems-numberOfConsecutiveValues...maxItems {
            
            if abs(bloodValues[index-2].value - bloodValues[index-1].value) < deltaAmount {
                return false
            }
            if (positiveDirection == nil) {
                positiveDirection = (bloodValues[index-1].value - bloodValues[index-2].value) > 0
            } else if positiveDirection! && newDirectionNegative(bloodValues[index-2].value, value2: bloodValues[index-1].value) {
                return false
            } else if !positiveDirection! && newDirectionPositive(bloodValues[index-2].value, value2: bloodValues[index-1].value) {
                return false
            }
        }
        return true;
    }
    
    static func newDirectionNegative(value1 : Int, value2 : Int) -> Bool {
        return value2 - value1 < 0
    }
    
    static func newDirectionPositive(value1 : Int, value2 : Int) -> Bool {
        return value2 - value1 > 0
    }
    
    /*
     * Snoozes all alarms for the next x minutes.
     */
    static func snooze(minutes : Int) {
        snoozedUntilTimestamp = NSDate().timeIntervalSince1970 + Double(60 * minutes)
    }
    
    /*
     * This is used to snooze just a few seconds on startup in order to retrieve
     * new values. Otherwise the alarm would play at once which makes no sense on startup.
     */
    static func snoozeSeconds(seconds : Int) {
        snoozedUntilTimestamp = NSDate().timeIntervalSince1970 + Double(seconds)
    }
    
    /*
     * An eventually activated snooze will be disabled again.
     */
    static func disableSnooze() {
        snoozedUntilTimestamp = NSTimeInterval()
    }
    
    /*
     * Returns true if the alarms are currently snoozed.
     */
    static func isSnoozed() -> Bool {
        let currentTimestamp = NSDate().timeIntervalSince1970
        return currentTimestamp < snoozedUntilTimestamp
    }
    
    /*
     * Return the number of remaing minutes till the snooze state ends.
     * The value will always be rounded up.
     */
    static func getRemainingSnoozeMinutes() -> Int {
        let currentTimestamp = TimeService.getCurrentTime()
        
        if (snoozedUntilTimestamp - currentTimestamp) <= 0 {
            return 0
        }
        
        return Int(ceil((snoozedUntilTimestamp - currentTimestamp) / 60.0))
    }
}