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
    
    static var minutesToPredictLow : Int = 15
    static var isLowPredictionEnabled : Bool = false

    static var isSmartSnoozeEnabled : Bool = false
    
    /*
     * Returns true if the alarm should be played.
     * Snooze is true if the Alarm has been manually deactivated.
     * Suspended is true if the Alarm has been technically deactivated for a short period of time.
     */
    static func isAlarmActivated() -> Bool {
        return (getAlarmActivationReason() != nil)
    }
    
    /*
     * Returns a reason (string) if the alarm is activated.
     * Returns nil if the alarm is snoozed or not active.
     */
    static func getAlarmActivationReason(ignoreSnooze: Bool = false) -> String? {
        
        if isSnoozed() && !ignoreSnooze {
            return nil
        }
        
        // get the most recent readings
        let bloodValues = [BloodSugar].latestFromRepositories()
        guard let currentReading = bloodValues.last else {
            
            // no values? we'll wait a little more...
            return nil
        }
        
        if currentReading.isOlderThanXMinutes(minutesWithoutValues) {
            return "Missed Readings"
        }
        
        let svgInMgdl = UnitsConverter.toMgdl(currentReading.value)
        let isTooHigh = AlarmRule.isTooHigh(svgInMgdl)
        let isTooLow = AlarmRule.isTooLow(svgInMgdl)
        
        if isSmartSnoozeEnabled && (isTooHigh || isTooLow) {
            
            // if the trend is to leave the too high or too low zone, we'll snooze the alarm (without caring about the edges - we're outside of the board, first get in, then we'll check the edges)
            switch bloodValues.trend {
            case .ascending:
                if isTooLow {
                    return nil
                }
            
            case .descending:
                if isTooHigh {
                    return nil
                }
                
            default:
                break
            }
            
            // let's try also with prediction: we'll snooze the alarm if the prediction says that we'll leave the too high or too low zone in less than 30 minutes
            if isTooHigh && (PredictionService.shared.minutesTo(low: UnitsConverter.toDisplayUnits(alertIfAboveValue)) ?? Int.max) < 30 {
                return nil
            } else if isTooLow && (PredictionService.shared.minutesTo(high: UnitsConverter.toDisplayUnits(alertIfBelowValue)) ?? Int.max) < 30 {
                return nil
            }
        }
        
        if isTooHigh {
            return "High BG"
        } else if isTooLow {
            return "Low BG"
        }

        if isEdgeDetectionAlarmEnabled  {
            if bloodValuesAreIncreasingTooFast(bloodValues) {
                return "Fast Rise"
            } else if bloodValuesAreDecreasingTooFast(bloodValues) {
                return "Fast Drop"
            }
        }
        
        if isLowPredictionEnabled {
            if let minutesToLow = PredictionService.shared.minutesTo(low: UnitsConverter.toDisplayUnits(alertIfBelowValue)), minutesToLow <= minutesToPredictLow {
                #if os(iOS)
                return "Low Predicted in \(minutesToLow)min"
                #else
                // shorter text on watch
                return "Low in \(minutesToLow)min"
                #endif
            }
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
    
    fileprivate static func bloodValuesAreIncreasingOrDecreasingTooFast(_ bloodValues : [BloodSugar]) -> Bool {
        return bloodValuesAreIncreasingTooFast(bloodValues) || bloodValuesAreDecreasingTooFast(bloodValues)
    }
    
    fileprivate static func bloodValuesAreIncreasingTooFast(_ bloodValues : [BloodSugar]) -> Bool {
        
        // we need at least these number of values (the most reacent X readings)
        guard let readings = bloodValues.lastConsecutive(numberOfConsecutiveValues + 1) else {
            return false
        }
        
        return readings.deltas.allSatisfy { $0 > deltaAmount }
    }
    
    fileprivate static func bloodValuesAreDecreasingTooFast(_ bloodValues : [BloodSugar]) -> Bool {
        
        // we need at least these number of values (the most reacent X readings)
        guard let readings = bloodValues.lastConsecutive(numberOfConsecutiveValues + 1) else {
            return false
        }
        
        return readings.deltas.allSatisfy { $0 < -deltaAmount }
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
