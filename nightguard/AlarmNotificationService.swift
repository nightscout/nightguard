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
        if #available(iOS 12.0, *) {
            authorizationOptions = [.badge, .alert, .sound, .criticalAlert]
        } else {
            authorizationOptions = [.badge, .alert, .sound]
        }
        
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
        
        // 2. app should be in background
        guard UIApplication.shared.applicationState != .active else {
            return
        }
        
        // 3. alarm should be active
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
        content.sound = UNNotificationSound.criticalSoundNamed(convertToUNNotificationSoundName("alarm-notification.m4a"), withAudioVolume: 0.6)
        
        let request = UNNotificationRequest(identifier: "ALARM", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    /*
     * Trigger a local notification if alarm is activated (and the app is in background).
     */
    func notifyIfAlarmActivated(_ nightscoutData: NightscoutData) {
        
        // PRECONDITIONS:
        // 1. service should be enabled
        guard enabled else {
            return
        }
        
        // s. alarm should be active
        guard let alarmActivationReason = AlarmRule.determineAlarmActivationReasonBy(nightscoutData) else {
            return
        }

        // trigger notification
        let content = UNMutableNotificationContent()
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
        content.sound = UNNotificationSound.criticalSoundNamed(convertToUNNotificationSoundName("alarm-notification.m4a"), withAudioVolume: 0.6)
        
        let request = UNNotificationRequest(identifier: "ALARM", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    private init() {
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUNNotificationSoundName(_ input: String) -> UNNotificationSoundName {
	return UNNotificationSoundName(rawValue: input)
}
