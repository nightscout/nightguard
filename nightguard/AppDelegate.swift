//
//  AppDelegate.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 20.11.15.
//  Copyright © 2015 private. All rights reserved.
//

import UIKit
import MediaPlayer
import WatchConnectivity
import BackgroundTasks
import SwiftUI

extension Notification.Name {
    static let showProPromotionRequest = Notification.Name("ShowProPromotionRequest")
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let appProcessingTaskId = "de.my-wan.dhe.nightguard.background"
    
    /// Global orientation lock - allow controlling allowed orientations from anywhere
    static var orientationLock = UIInterfaceOrientationMask.portrait

    static func updateOrientationLock(_ lock: UIInterfaceOrientationMask, rotateTo orientation: UIInterfaceOrientation? = nil) {
        orientationLock = lock

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            if let orientation = orientation {
                UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
            }
            UINavigationController.attemptRotationToDeviceOrientation()
            return
        }

        if #available(iOS 16.0, *) {
            windowScene.windows.first(where: \.isKeyWindow)?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()

            let geometryPreferences: UIWindowScene.GeometryPreferences.iOS
            if let orientation {
                geometryPreferences = .init(interfaceOrientations: UIInterfaceOrientationMask(orientation))
            } else {
                geometryPreferences = .init(interfaceOrientations: lock)
            }

            windowScene.requestGeometryUpdate(geometryPreferences) { error in
                #if MAIN_APP
                AppLogger.singleton.error("Error requesting orientation update: \(error.localizedDescription)")
                #endif
            }
        } else {
            if let orientation {
                UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
            }
            UINavigationController.attemptRotationToDeviceOrientation()
        }
    }
    
    // Delegate Requests from the Watch to the WatchMessageService
    var session: WCSession? {
        didSet {
            if let session = session {
                session.delegate = WatchMessageService.singleton
                session.activate()
            }
        }
    }
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        if CommandLine.arguments.contains("--uitesting") {
            configureAppForTesting()
        }

        // Override point for customization after application launch.
        UITabBar.appearance().tintColor = UIColor.white

        UITextField.appearance().keyboardAppearance = .dark
        
        // set "prevent screen lock" to ON when the app is started for the first time
        if !SharedUserDefaultsRepository.screenlockSwitchState.exists {
            SharedUserDefaultsRepository.screenlockSwitchState.value = true
        }
        
        // set the "prevent screen lock" option when the app is started
        UIApplication.shared.isIdleTimerDisabled = SharedUserDefaultsRepository.screenlockSwitchState.value
        
        AlarmSound.volumeChangeDetector.onVolumeChange = { [weak self] in
            self?.window?.rootViewController?.handleQuickSnooze(option: UserDefaultsRepository.volumeKeysOnAlertSnoozeOption.value)
        }
        
        activateWatchConnectivity()
        return true
    }

    func configureAppForTesting() -> Void {
        UIView.setAnimationsEnabled(false)
        // Ensure alarms are enabled so the actions menu button is visible for UI tests
        AlarmRule.areAlertsGenerallyDisabled.value = false
        // Suppress App Tour
        UserDefaultsRepository.appTourSeen.value = true
        // Suppress Disclaimer
        UserDefaultsRepository.disclaimerSeen.value = true
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        UserDefaultsRepository.initializeSyncValues()
        AlarmRule.initializeSyncValues()
        applyStartupAlarmSnoozeIfNeeded(application: application, launchOptions: launchOptions)

        // Initialize the stored UserDefaultsData
        TreatmentsStream.singleton.treatments = UserDefaultsRepository.treatments.value

        // Enable Background Updates
        BGTaskScheduler.shared.register(forTaskWithIdentifier: appProcessingTaskId, using: nil) { task in

            self.handelBackgroundProcessing(task as! BGProcessingTask)
        }

        return true
    }
    
    func handelBackgroundProcessing(_ task: BGProcessingTask) {

        task.expirationHandler = {
            AppLogger.singleton.warning("BG task expired", category: .backgroundUpdates)
            task.setTaskCompleted(success: false)
        }

        AppLogger.singleton.debug("BG task started", category: .backgroundUpdates)

        let _ = NightscoutCacheService.singleton.loadCurrentNightscoutData(forceRefresh: true) { result in

            guard let result = result else {
                AppLogger.singleton.warning("BG task: no result from Nightscout", category: .backgroundUpdates)
                task.setTaskCompleted(success: true)
                return
            }

            switch result {
            case .error(let error):
                AppLogger.singleton.error("BG task failed: \(error)", category: .backgroundUpdates)
                task.setTaskCompleted(success: false)
            case .data(let nightscoutData):
                AppLogger.singleton.debug("BG task succeeded, SGV: \(nightscoutData.sgv)", category: .backgroundUpdates)
                // The new data has already been stored locally. Use it to determine wheter alerts have to be send:
                AlarmNotificationService.singleton.notifyIfAlarmActivated(nightscoutData)
                WatchService.singleton.sendToWatchCurrentNightwatchData()

                if #available(iOS 16.1, *) {
                    LiveActivityManager.shared.update(with: nightscoutData)
                }

                // Also check device status for reservoir
                let _ = NightscoutCacheService.singleton.getDeviceStatusData { deviceStatusData in
                    AlarmNotificationService.singleton.notifyIfReservoirCritical(deviceStatusData.reservoirUnits)
                    // Finally schedule the next background task and call task completed:
                    self.scheduleBackgroundProcessing()
                    task.setTaskCompleted(success: true)
                }
            }
        }
    }
    
    func scheduleBackgroundProcessing() {
         let request = BGProcessingTaskRequest(identifier: appProcessingTaskId)
         request.requiresNetworkConnectivity = true
         request.earliestBeginDate = Date(timeIntervalSinceNow: 10 * 60)

         do {
             BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: appProcessingTaskId)
             try BGTaskScheduler.shared.submit(request)
             AppLogger.singleton.debug("BG task scheduled for \(request.earliestBeginDate?.description ?? "unknown")", category: .backgroundUpdates)
         } catch {
             #if MAIN_APP
             AppLogger.singleton.error("Could not schedule background fetch: \(error)", category: .backgroundUpdates)
             #endif
         }
     }
    
    func dimScreenOnIdle() {
        
        guard let window = self.window as? UserInteractionDetectorWindow else {
            return
        }
        
        let updateWindowUserInteractionTimeout = {
            if SharedUserDefaultsRepository.screenlockSwitchState.value {
                window.timeout = TimeInterval(UserDefaultsRepository.dimScreenWhenIdle.value * 60)
            } else {
                window.timeout = nil
            }
        }
        
        // bind dim screen settings with user interaction detector window timeout
        UserDefaultsRepository.dimScreenWhenIdle.observeChanges { _ in
            updateWindowUserInteractionTimeout()
        }
        SharedUserDefaultsRepository.screenlockSwitchState.observeChanges { _ in
            updateWindowUserInteractionTimeout()
        }
        
        updateWindowUserInteractionTimeout()
    }

    func activateWatchConnectivity() {
        if WCSession.isSupported() {
            session = WCSession.default
        
            handleWatchMessages()
        }
    }
    
    func handleWatchMessages() {
        
        // snooze message
        WatchMessageService.singleton.onMessage { (message: SnoozeMessage) in
            
            // update snooze from message
            AlarmRule.snoozeFromMessage(message)
        }
        
        // request night safe phone settings
        WatchMessageService.singleton.onRequest { (request: RequestNightSafeMessage) in
            return ResponseNightSafeMessage(
                PhoneNightSafeSettings(
                    isPhoneActive: UIApplication.shared.applicationState == .active,
                    isScreenLockActive: UIApplication.shared.isIdleTimerDisabled,
                    volumeLevel: AlarmSound.overrideSystemOutputVolume.value ? AlarmSound.systemOutputVolume.value : MPVolumeView.volume
                )
            )
        }        
        
        WatchMessageService.singleton.onMessage { (message: WatchSyncRequestMessage) in
            
            // compare the "last sync update id" received from watch and compare it with phone value: if not equal, the watch has not the latest user defaults data and a sync should be performed
            if let anyWatchUpdateId = message.dictionary[UserDefaultsRepository.lastWatchSyncUpdateId.key] {
                let watchUpdateId = type(of: UserDefaultsRepository.lastWatchSyncUpdateId).ValueType.fromAny(anyWatchUpdateId)
                if UserDefaultsRepository.lastWatchSyncUpdateId.value != watchUpdateId {

                    // perform sync!
                    UserDefaultSyncMessage().send()

                    #if MAIN_APP
                    AppLogger.singleton.debug("Handling WatchSyncRequestMessage: UUID on watch didn't match phone UUID")
                    #endif
                }
            }
            
            // same comparison for snoozing timestamp
            if let anyWatchSnoozeTimestamp = message.dictionary["snoozedUntilTimestamp"] {
                let watchSnoozeTimestamp = anyWatchSnoozeTimestamp as? TimeInterval
                if AlarmRule.snoozedUntilTimestamp.value != watchSnoozeTimestamp {

                    // send snooze data to watch!
                    SnoozeMessage(timestamp: AlarmRule.snoozedUntilTimestamp.value).send()

                    #if MAIN_APP
                    AppLogger.singleton.debug("Handling WatchSyncRequestMessage: Snooze timestamp on watch didn't match phone snooze timestamp")
                    #endif
                }
            }
        }

        WatchMessageService.singleton.onMessage { (_: ShowProPromotionMessage) in
            guard !PurchaseManager.shared.isProAccessAvailable else {
                return
            }

            NotificationCenter.default.post(name: .showProPromotionRequest, object: nil)
        }

        
        // whenever a value from the "watch sync" group changes, send the apropriate watch message containing all the group values
        UserDefaultsValueGroups.observeChanges(in: UserDefaultsValueGroups.GroupNames.watchSync) { _, _ in
            
            UserDefaultsRepository.lastWatchSyncUpdateId.value = UUID().uuidString
            UserDefaultSyncMessage().send()
        }
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        
        // Store all treatments in UserDefaults
        UserDefaultsRepository.treatments.value = TreatmentsStream.singleton.treatments
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        // Store the In-Memory Treatments
        UserDefaultsRepository.treatments.value = TreatmentsStream.singleton.treatments
        
        // Persist Main as the next startup tab, because applicationWillTerminate
        // is not reliably called when the app is later killed from the app switcher.
        UserDefaultsRepository.currentTab.value = .main
        
        // Schedule Background Updates:
        self.scheduleBackgroundProcessing()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        UserDefaultsRepository.currentTab.value = .main
    }
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }

    private func applyStartupAlarmSnoozeIfNeeded(application: UIApplication, launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard shouldApplyStartupAlarmSnooze(application: application, launchOptions: launchOptions) else {
            return
        }

        guard !AlarmRule.isSnoozed() else {
            return
        }

        AlarmRule.snoozeForStartup(seconds: 10)
    }

    static func shouldApplyStartupAlarmSnooze(
        applicationState: UIApplication.State,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if applicationState == .background {
            return false
        }
        return true
    }

    private func shouldApplyStartupAlarmSnooze(
        application: UIApplication,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        Self.shouldApplyStartupAlarmSnooze(
            applicationState: application.applicationState,
            launchOptions: launchOptions
        )
    }
}

private extension UIInterfaceOrientationMask {
    init(_ orientation: UIInterfaceOrientation) {
        switch orientation {
        case .portrait:
            self = .portrait
        case .portraitUpsideDown:
            self = .portraitUpsideDown
        case .landscapeLeft:
            self = .landscapeLeft
        case .landscapeRight:
            self = .landscapeRight
        default:
            self = .all
        }
    }
}
