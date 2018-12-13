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
    
    fileprivate static var snoozedUntilTimestamp = TimeInterval()
    
    static var numberOfConsecutiveValues : Int = 3
    static var deltaAmount : Float = 8
    static var isEdgeDetectionAlarmEnabled : Bool = false
    
    static var alertIfAboveValue : Float = 180
    static var alertIfBelowValue : Float = 80
    
    static var minutesWithoutValues : Int = 15
    
    /*
     * Returns true if the alarm should be played.
     * Snooze is true if the Alarm has been manually deactivated.
     * Suspended is true if the Alarm has been technically deactivated for a short period of time.
     */
    static func isAlarmActivated(_ nightscoutData : NightscoutData, bloodValues : [BloodSugar]) -> Bool {
        return (getAlarmActivationReason(nightscoutData, bloodValues: bloodValues) != nil)
    }
    
    /*
     * Returns a reason (string) if the alarm is activated.
     * Returns nil if the alarm is snoozed or not active.
     */
    static func getAlarmActivationReason(_ nightscoutData : NightscoutData, bloodValues : [BloodSugar]) -> String? {
        
        if isSnoozed() {
            return nil
        }
        
        if nightscoutData.isOlderThanXMinutes(minutesWithoutValues) {
            return "Missed Readings"
        }
        
        let svgInMgdl = UnitsConverter.toMgdl(Float(nightscoutData.sgv)!)
        if isTooHigh(svgInMgdl) {
            return "High BG"
        } else if isTooLow(svgInMgdl) {
            return "Low BG"
        }

        if isEdgeDetectionAlarmEnabled && bloodValuesAreIncreasingOrDecreasingToFast(bloodValues) {
            let lastTwoReadings = bloodValues.suffix(2)
            let positiveDirection = lastTwoReadings[1].value > lastTwoReadings[0].value
            return positiveDirection ? "Fast Rise" : "Fast Drop"
        }
        
        return nil
    }
    
    fileprivate static func isTooHighOrTooLow(_ bloodGlucose : Float) -> Bool {
        return isTooHigh(bloodGlucose) || isTooLow(bloodGlucose)
    }
    
    fileprivate static func isTooHigh(_ bloodGlucose : Float) -> Bool {
        return bloodGlucose > alertIfAboveValue
    }

    fileprivate static func isTooLow(_ bloodGlucose : Float) -> Bool {
        return bloodGlucose < alertIfBelowValue
    }
    
    fileprivate static func bloodValuesAreIncreasingOrDecreasingToFast(_ bloodValues : [BloodSugar]) -> Bool {
        
        // we need at least these number of values, in order to prevent an out of bounds exception
        if bloodValues.count < numberOfConsecutiveValues + 2 {
            return false
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
        return true
    }
    
    static func newDirectionNegative(_ value1 : Float, value2 : Float) -> Bool {
        return value2 - value1 < 0
    }
    
    static func newDirectionPositive(_ value1 : Float, value2 : Float) -> Bool {
        return value2 - value1 > 0
    }
    
    /*
     * Snoozes all alarms for the next x minutes.
     */
    static func snooze(_ minutes : Int) {
        snoozedUntilTimestamp = Date().timeIntervalSince1970 + Double(60 * minutes)
    }
    
    /*
     * This is used to snooze just a few seconds on startup in order to retrieve
     * new values. Otherwise the alarm would play at once which makes no sense on startup.
     */
    static func snoozeSeconds(_ seconds : Int) {
        snoozedUntilTimestamp = Date().timeIntervalSince1970 + Double(seconds)
    }
    
    /*
     * An eventually activated snooze will be disabled again.
     */
    static func disableSnooze() {
        snoozedUntilTimestamp = TimeInterval()
    }
    
    /*
     * Returns true if the alarms are currently snoozed.
     */
    static func isSnoozed() -> Bool {
        let currentTimestamp = Date().timeIntervalSince1970
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
