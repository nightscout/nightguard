//
//  AlarmNotificationService.swift
//  nightguard
//
//  Created by Florian Preknya on 12/10/18.
//  Copyright © 2018 private. All rights reserved.
//

import UIKit
import UserNotifications
import Combine

// Alarm notification authorization, triggering & handling logic.
class AlarmNotificationService: ObservableObject {
    
    static let singleton = AlarmNotificationService()
    
    @Published var publishedEnabled: Bool = UserDefaultsRepository.alarmNotificationState.value
    
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

    /*
     * Trigger a local notification if reservoir is critical.
     */
    func notifyIfReservoirCritical(_ reservoirUnits: Int) {
        guard enabled else { return }
        guard PurchaseManager.shared.isProAccessAvailable else { return }
        guard reservoirUnits > 0 else { return }
        guard reservoirUnits <= UserDefaultsRepository.reservoirUnitsCritical.value else {
            // Remove pending/delivered notification if not critical anymore
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["ReservoirCritical"])
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["ReservoirCritical"])
            return
        }

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Reservoir Critical", comment: "Reservoir Critical Notification Title")
        content.body = String(format: NSLocalizedString("Your reservoir is low.", comment: "Reservoir Critical Notification Body"), reservoirUnits)
        content.sound = .defaultCritical
        
        let request = UNNotificationRequest(identifier: "ReservoirCritical", content: content, trigger: nil)
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
        // We remove the base identifier and the possible indexed identifiers
        var identifiersToRemove = [identifier]
        for i in 0...15 {
            identifiersToRemove.append("\(identifier)-\(i)")
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)

        guard PurchaseManager.shared.isProAccessAvailable else {
            print("Pro version not unlocked. Skipping \(identifier) notification.")
            return
        }

        guard enabled else { return }

        let calendar = Calendar.current
        guard let criticalDate = calendar.date(byAdding: .hour, value: criticalHours, to: changeDate) else { return }
        
        // Determine start time for notifications
        let now = Date()
        let startTime = (criticalDate > now) ? criticalDate : now
        
        // Schedule 3 notifications per day for the next 5 days
        for i in 0..<15 {
            guard let notificationDate = calendar.date(byAdding: .hour, value: i * 8, to: startTime) else { continue }
            
            let timeInterval = notificationDate.timeIntervalSinceNow
            
            // Should be positive, but safe guard (min 1 second if it's "now")
            let validTimeInterval = max(timeInterval, 1)
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: validTimeInterval, repeats: false)

            let content = UNMutableNotificationContent()
            content.title = title
            let components = calendar.dateComponents([.day, .hour], from: changeDate, to: notificationDate)
            let days = components.day ?? 0
            let hours = components.hour ?? 0
            let ageString = "\(days)d \(hours)h"
            content.body = String(format: body, ageString)
            content.sound = .default
            
            // Use indexed identifier
            let requestId = "\(identifier)-\(i)"
            let request = UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling \(requestId) notification: \(error)")
                } else {
                    print("Scheduled \(requestId) notification for \(notificationDate)")
                }
            }
        }
        print("Scheduled hourly \(identifier) notifications starting at \(startTime)")
    }
    
    private init() {
        UserDefaultsRepository.alarmNotificationState.observeChanges { [weak self] newValue in
            DispatchQueue.main.async {
                self?.publishedEnabled = newValue
            }
        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUNNotificationSoundName(_ input: String) -> UNNotificationSoundName {
	return UNNotificationSoundName(rawValue: input)
}
