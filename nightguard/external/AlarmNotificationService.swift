//
//  AlarmNotificationService.swift
//  nightguard
//
//  Created by Florian Preknya on 12/10/18.
//  Copyright © 2018 private. All rights reserved.
//

import UIKit
import UserNotifications

// Alarm notification authorization, triggering & handling logic.
class AlarmNotificationService {
    
    static let singleton = AlarmNotificationService()
    
    // service state
    var enabled: Bool {
        get {
            return UserDefaultsRepository.alarmNotificationState.value
        }
        
        set(value) {
            UserDefaultsRepository.alarmNotificationState.value = value
            if value {
                requestAuthorization()
            }
        }
    }
    /*
     * Request authorization from user to use local notifications for alarms
     */
    func requestAuthorization(completion: ((Bool, Error?) -> Void)? = nil) {
        
        // enable local notifications (alarms in background)
        let authorizationOptions: UNAuthorizationOptions
        authorizationOptions = [.badge, .alert, .sound, .criticalAlert]
        
        UNUserNotificationCenter.current().requestAuthorization(options: authorizationOptions) { (granted, error) in
            // Enable or disable features based on authorization.
                dispatchOnMain {
                    completion?(granted, error)
                }
        }
    }
    
    /*
     * Trigger a local notification if alarm is activated (and the app is in background).
     */
    func notifyIfAlarmActivated() {
        
        // PRECONDITIONS:
        // 1. service should be enabled
        guard enabled else {
            return
        }
        
        // 2. alarm should be active
        guard let alarmActivationReason = AlarmRule.getAlarmActivationReason() else {
            return
        }

        // trigger notification
        let content = UNMutableNotificationContent()
        let nightscoutData = NightscoutCacheService.singleton.getCurrentNightscoutData()
        let units = UserDefaultsRepository.units.value.description

        content.title =
            "\(UnitsConverter.mgdlToDisplayUnits(nightscoutData.sgv)) " +
            "\(nightscoutData.bgdeltaArrow)\t\(UnitsConverter.mgdlToDisplayUnitsWithSign(nightscoutData.bgdeltaString)) " +
            "\(units)"
        content.body = "\(alarmActivationReason)"
        if let sgv = Float(UnitsConverter.mgdlToDisplayUnits(nightscoutData.sgv)) {
            // display the current sgv on appbadge only if the user actived it:
            if SharedUserDefaultsRepository.showBGOnAppBadge.value {
                content.badge = NSNumber(value: sgv)
            }
        }
        #if os(iOS)
        content.sound = UNNotificationSound.criticalSoundNamed(convertToUNNotificationSoundName("alarm-notification.m4a"), withAudioVolume: 0.6)
        #endif
        
        let request = UNNotificationRequest(identifier: "ALARM", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    /*
     * Trigger a local notification if alarm is activated (and the app is in background).
     */
    func notifyIfAlarmActivated(_ nightscoutData: NightscoutData) {
        
        // PRECONDITIONS:
        // 1. service should be enabled
        /*guard enabled else {
            return
        }*/
        
        // s. alarm should be active
        guard let alarmActivationReason = AlarmRule.determineAlarmActivationReasonBy(nightscoutData) else {
            return
        }

        // trigger notification
        let content = UNMutableNotificationContent()
        let units = UserDefaultsRepository.units.value.description

        content.title =
            "\(UnitsConverter.mgdlToDisplayUnits(nightscoutData.sgv)) " +
            "\(UnitsConverter.mgdlToDisplayUnitsWithSign(nightscoutData.bgdeltaString)) " +
            "\(units)"
        content.body = "\(alarmActivationReason)"
        if let sgv = Float(UnitsConverter.mgdlToDisplayUnits(nightscoutData.sgv)) {
            // display the current sgv on appbadge only if the user actived it:
            if SharedUserDefaultsRepository.showBGOnAppBadge.value {
                content.badge = NSNumber(value: sgv)
            }
        }
        content.sound = .defaultCritical
        
        let request = UNNotificationRequest(identifier: "ALARM", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Age Notifications

    func scheduleCannulaNotification(changeDate: Date) {
        let criticalHours = UserDefaultsRepository.cannulaAgeHoursUntilCritical.value
        scheduleAgeNotification(
            identifier: "CannulaAge",
            changeDate: changeDate,
            criticalHours: criticalHours,
            title: NSLocalizedString("Cannula Age Critical", comment: "Cannula Age Notification Title"),
            body: NSLocalizedString("Your cannula has reached its critical age.", comment: "Cannula Age Notification Body")
        )
    }

    func scheduleSensorNotification(changeDate: Date) {
        let criticalHours = UserDefaultsRepository.sensorAgeHoursUntilCritical.value
        scheduleAgeNotification(
            identifier: "SensorAge",
            changeDate: changeDate,
            criticalHours: criticalHours,
            title: NSLocalizedString("Sensor Age Critical", comment: "Sensor Age Notification Title"),
            body: NSLocalizedString("Your sensor has reached its critical age.", comment: "Sensor Age Notification Body")
        )
    }

    func scheduleBatteryNotification(changeDate: Date) {
        let criticalHours = UserDefaultsRepository.batteryAgeHoursUntilCritical.value
        scheduleAgeNotification(
            identifier: "BatteryAge",
            changeDate: changeDate,
            criticalHours: criticalHours,
            title: NSLocalizedString("Battery Age Critical", comment: "Battery Age Notification Title"),
            body: NSLocalizedString("Your pump battery has reached its critical age.", comment: "Battery Age Notification Body")
        )
    }

    private func scheduleAgeNotification(identifier: String, changeDate: Date, criticalHours: Int, title: String, body: String) {
        // Remove pending notification for this identifier first
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])

        guard PurchaseManager.shared.isProAccessAvailable else {
            print("Pro version not unlocked. Skipping \(identifier) notification.")
            return
        }

        guard enabled else { return }

        let calendar = Calendar.current
        guard let criticalDate = calendar.date(byAdding: .hour, value: criticalHours, to: changeDate) else { return }
        
        let timeInterval = criticalDate.timeIntervalSinceNow
        
        // If the date is in the past, show immediately (or skip if way too old, but sticking to "show immediately" for now)
        // If in future, schedule it.
        
        let trigger: UNNotificationTrigger
        if timeInterval <= 0 {
             trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        } else {
             trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling \(identifier) notification: \(error)")
            } else {
                print("Scheduled \(identifier) notification for \(criticalDate)")
            }
        }
    }
    
    private init() {
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUNNotificationSoundName(_ input: String) -> UNNotificationSoundName {
	return UNNotificationSoundName(rawValue: input)
}
