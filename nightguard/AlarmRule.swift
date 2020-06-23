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
    
    private(set) static var snoozedUntilTimestamp = UserDefaultsValue<TimeInterval>(
        key: "snoozedUntilTimestamp",
        default: TimeInterval(),
        onChange: { _ in
            onSnoozeTimestampChanged?()
    }).group(UserDefaultsValueGroups.GroupNames.alarm)
    // NOTE that we're not synchronizing the snoozeTimestamp with watch. It is the custom SnoozeMessage that does that.
    
    // closure for listening to snooze timestamp changes
    static var onSnoozeTimestampChanged: (() -> ())?
    
    static let areAlertsGenerallyDisabled = UserDefaultsValue<Bool>(key: "areAlertsGenerallyDisabled", default: false)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
        .group(UserDefaultsValueGroups.GroupNames.alarm)
    
    static let numberOfConsecutiveValues = UserDefaultsValue<Int>(key: "numberOfConsecutiveValues", default: 3)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
        .group(UserDefaultsValueGroups.GroupNames.alarm)
    
    static let deltaAmount = UserDefaultsValue<Float>(key: "deltaAmount", default: 8)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
        .group(UserDefaultsValueGroups.GroupNames.alarm)

    static let isEdgeDetectionAlarmEnabled = UserDefaultsValue<Bool>(key: "edgeDetectionAlarmEnabled", default: false)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
        .group(UserDefaultsValueGroups.GroupNames.alarm)
    
    static let alertIfAboveValue = UserDefaultsRepository.upperBound
    static let alertIfBelowValue = UserDefaultsRepository.lowerBound
    
    static let noDataAlarmEnabled = UserDefaultsValue<Bool>(key: "noDataAlarmEnabled", default: true)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
        .group(UserDefaultsValueGroups.GroupNames.alarm)
    
    static let minutesWithoutValues = UserDefaultsValue<Int>(key: "noDataAlarmAfterMinutes", default: 15)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
        .group(UserDefaultsValueGroups.GroupNames.alarm)
    
    static var minutesToPredictLow = UserDefaultsValue<Int>(key: "lowPredictionMinutes", default: 15)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
        .group(UserDefaultsValueGroups.GroupNames.alarm)

    static var isLowPredictionEnabled = UserDefaultsValue<Bool>(key: "lowPredictionEnabled", default: true)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
        .group(UserDefaultsValueGroups.GroupNames.alarm)


    static var isSmartSnoozeEnabled = UserDefaultsValue<Bool>(key: "smartSnoozeEnabled", default: true)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
        .group(UserDefaultsValueGroups.GroupNames.alarm)

    static var isPersistentHighEnabled = UserDefaultsValue<Bool>(key: "persistentHighEnabled", default: false)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
        .group(UserDefaultsValueGroups.GroupNames.alarm)
    
    static var persistentHighMinutes = UserDefaultsValue<Int>(key: "persistentHighMinutes", default: 30)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
        .group(UserDefaultsValueGroups.GroupNames.alarm)
    
    static var persistentHighUpperBound = UserDefaultsValue<Float>(key: "persistentHighUpperBound", default: 250)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
        .group(UserDefaultsValueGroups.GroupNames.alarm)

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
        
        if areAlertsGenerallyDisabled.value {
            return nil
        }
        
        if isSnoozed() && !ignoreSnooze {
            return nil
        }
        
        // get the most recent readings
        let bloodValues = [BloodSugar].latestFromRepositories()
        guard let currentReading = bloodValues.last else {
            
            // no values? we'll wait a little more...
            return nil
        }
        
        if currentReading.isOlderThanXMinutes(minutesWithoutValues.value) {
            if noDataAlarmEnabled.value {
                return NSLocalizedString("Missed Readings", comment: "noDataAlarmEnabled.value in AlarmRule Class")
            } else {
                
                // no alarm at all... because old readings cannot be used for further alert evaluations
                return nil
            }
        }
        
        let isTooHigh = AlarmRule.isTooHigh(currentReading.value)
        let isTooLow = AlarmRule.isTooLow(currentReading.value)
        
        if isSmartSnoozeEnabled.value && (isTooHigh || isTooLow) {
            
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
            if isTooHigh && (PredictionService.singleton.minutesTo(low: alertIfAboveValue.value) ?? Int.max) < 30 {
                return nil
            } else if isTooLow && (PredictionService.singleton.minutesTo(high: alertIfBelowValue.value) ?? Int.max) < 30 {
                return nil
            }
        }
        
        if isTooHigh {
            
            if isPersistentHighEnabled.value {
                if currentReading.value < persistentHighUpperBound.value {
                    
                    // if all the previous readings (for the defined minutes are high, we'll consider it a persistent high)
                    let lastReadings = bloodValues.lastXMinutes(persistentHighMinutes.value)
                    
                    // we should have at least a reading in 10 minutes for considering a persistent high
                    if !lastReadings.isEmpty && (lastReadings.count >= (persistentHighMinutes.value / 10)) {
                        if lastReadings.allSatisfy({ AlarmRule.isTooHigh($0.value) }) {
                            return NSLocalizedString("Persistent High BG", comment: "Persistent High BG in AlarmRule Class")
                        } else {
                            return nil
                        }
                    }
                }
            }
            
            return NSLocalizedString("High BG", comment: "High BG in AlarmRule Class")
        } else if isTooLow {
            return NSLocalizedString("Low BG", comment: "Low BG in AlarmRule Class")
        }

        if isEdgeDetectionAlarmEnabled.value  {
            if bloodValuesAreIncreasingTooFast(bloodValues) {
                return NSLocalizedString("Fast Rise", comment: "Fast Rise in AlarmRule Class")
            } else if bloodValuesAreDecreasingTooFast(bloodValues) {
                return NSLocalizedString("Fast Drop", comment: "Fast Drop in AlarmRule Class")
            }
        }
        
        if isLowPredictionEnabled.value {
            if let minutesToLow = PredictionService.singleton.minutesTo(low: alertIfBelowValue.value), minutesToLow <= minutesToPredictLow.value {
                #if os(iOS)
                return String(format: NSLocalizedString("Low Predicted in %dmin", comment: "Low Predicted in %dmin in AlarmRule Class"), minutesToLow)
                #else
                // shorter text on watch
                return String(format: NSLocalizedString("Low in %dmin", comment: "Low in %dmin in AlarmRule Class"), minutesToLow)
                #endif
            }
        }
        
        return nil
    }
    
    fileprivate static func isTooHighOrTooLow(_ bloodGlucose : Float) -> Bool {
        return isTooHigh(bloodGlucose) || isTooLow(bloodGlucose)
    }
    
    fileprivate static func isTooHigh(_ bloodGlucose : Float) -> Bool {
        return bloodGlucose > alertIfAboveValue.value
    }

    fileprivate static func isTooLow(_ bloodGlucose : Float) -> Bool {
        return bloodGlucose < alertIfBelowValue.value
    }
    
    fileprivate static func bloodValuesAreIncreasingOrDecreasingTooFast(_ bloodValues : [BloodSugar]) -> Bool {
        return bloodValuesAreIncreasingTooFast(bloodValues) || bloodValuesAreDecreasingTooFast(bloodValues)
    }
    
    fileprivate static func bloodValuesAreIncreasingTooFast(_ bloodValues : [BloodSugar]) -> Bool {
        return bloodValuesAreMovingTooFast(bloodValues, increasing: true)
    }
    
    fileprivate static func bloodValuesAreDecreasingTooFast(_ bloodValues : [BloodSugar]) -> Bool {
        return bloodValuesAreMovingTooFast(bloodValues, increasing: false)
    }
    
    fileprivate static func bloodValuesAreMovingTooFast(_ bloodValues : [BloodSugar], increasing: Bool) -> Bool {
        
        // we need at least these number of values (the most reacent X readings)
        guard let readings = bloodValues.lastConsecutive(numberOfConsecutiveValues.value), readings.count > 1 else  {
            return false
        }
        
        // calculate the difference in time and values between newest and oldest reading
        let totalMinutes = Float((readings[readings.count - 1].timestamp - readings[0].timestamp) / 60000)
        var totalDelta = readings[readings.count - 1].value - readings[0].value
        if !increasing {
            totalDelta *= -1
        }
        
        let alarmDeltaPerMinute = deltaAmount.value / 5
        if totalDelta < (totalMinutes * alarmDeltaPerMinute) {
            return false
        }
        
        // calculate the difference in time and values between the most recent 2 values
        let recentMinutes = Float((readings[readings.count - 1].timestamp - readings[readings.count - 2].timestamp) / 60000)
        var recentDelta = readings[readings.count - 1].value - readings[readings.count - 2].value
        if !increasing {
            recentDelta *= -1
        }

        if recentMinutes > 7 {
            
            // lost reading, cannot risk...
            return true
        }
        
        if recentDelta < ((recentMinutes * alarmDeltaPerMinute) / 2) {
            
            // in the most recent readings the raise/drop speed halved, do not alert!
            return false
        }
        
        // do alert!
        return true
    }
    
    /*
     * Snoozes all alarms for the next x minutes.
     */
    static func snooze(_ minutes : Int) {
        snoozedUntilTimestamp.value = Date().timeIntervalSince1970 + Double(60 * minutes)
        SnoozeMessage(timestamp: snoozedUntilTimestamp.value).send()
    }
    
    /*
     * This is used to snooze just a few seconds on startup in order to retrieve
     * new values. Otherwise the alarm would play at once which makes no sense on startup.
     */
    static func snoozeSeconds(_ seconds : Int) {
        snoozedUntilTimestamp.value = Date().timeIntervalSince1970 + Double(seconds)
        SnoozeMessage(timestamp: snoozedUntilTimestamp.value).send()
    }
    
    /*
     * Snooze called from a message received from the connected device (watch or phone).
     */
    static func snoozeFromMessage(_ message: SnoozeMessage) {
        snoozedUntilTimestamp.value = message.timestamp
    }
    
    /*
     * An eventually activated snooze will be disabled again.
     */
    static func disableSnooze() {
        snoozedUntilTimestamp.value = TimeInterval()
        SnoozeMessage(timestamp: snoozedUntilTimestamp.value).send()
    }
    
    /*
     * Returns true if the alarms are currently snoozed.
     */
    static func isSnoozed() -> Bool {
        let currentTimestamp = Date().timeIntervalSince1970
        return currentTimestamp < snoozedUntilTimestamp.value
    }
    
    /*
     * Return the number of remaing minutes till the snooze state ends.
     * The value will always be rounded up.
     */
    static func getRemainingSnoozeMinutes() -> Int {
        let currentTimestamp = TimeService.getCurrentTime()
        
        if (snoozedUntilTimestamp.value - currentTimestamp) <= 0 {
            return 0
        }
        
        return Int(ceil((snoozedUntilTimestamp.value - currentTimestamp) / 60.0))
    }
}
