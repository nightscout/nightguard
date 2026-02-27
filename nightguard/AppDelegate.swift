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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    let appProcessingTaskId = "de.my-wan.dhe.nightguard.background"
    
    /// Global orientation lock - allow controlling allowed orientations from anywhere
    static var orientationLock = UIInterfaceOrientationMask.portrait
    
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
        
        UNUserNotificationCenter.current().delegate = self
        requestPushPermission(application: application)
        
        return true
    }
    
    func application(
            _ application: UIApplication,
            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
        ) {

            let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
            Logger.log("Push registration success: \(token)")
            
            let environment = DeviceRegistrationService.shared.apnsEnvironment()
            DeviceRegistrationService.shared.updateDeviceToken(token, environment: environment)
        }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Logger.log("Push registration failed: \(error)")
    }

    // push handler
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {

        Logger.log("Silent push received")

        var hasCompleted = false
        let lock = NSLock()
        
        var timeoutWorkItem: DispatchWorkItem?

        func finish(_ result: UIBackgroundFetchResult) {
            lock.lock()
            defer { lock.unlock() }

            guard !hasCompleted else { return }
            hasCompleted = true
            timeoutWorkItem!.cancel()
            completionHandler(result)
        }
        
        timeoutWorkItem = DispatchWorkItem {
            Logger.log("Background task timeout fallback")
            finish(.noData)
        }

        // Timeout safety
        DispatchQueue.global().asyncAfter(
            deadline: .now() + 25,
            execute: timeoutWorkItem!
        )

        performNightscoutSync { success in
            Logger.log("Sync result: \(success)")
            finish(success ? .newData : .noData)
        }
    }
 
    
    private func requestPushPermission(application: UIApplication) {

            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    if let error = error {
                        Logger.log("requestPushPermission Authorization error: \(error.localizedDescription)")
                               return
                           }

                    Logger.log("requestPushPermission Permission granted: \(granted)")
                    if granted {
                        DispatchQueue.main.async {
                            application.registerForRemoteNotifications()
                        }
                    }
                }
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

        // Initialize the stored UserDefaultsData
        TreatmentsStream.singleton.treatments = UserDefaultsRepository.treatments.value

        // Use SwiftUI RootTabView
        let rootTabView = RootTabView()
        let hostingController = UIHostingController(rootView: rootTabView)

        self.window = UserInteractionDetectorWindow(frame: UIScreen.main.bounds)
        if #available(iOS 13.0, *) {
            // Always force a dark theme for nightguard. Otherwise e.g. the file picker would be white ^^
            self.window?.overrideUserInterfaceStyle = .dark
        }
        self.window?.rootViewController = hostingController
        self.window?.makeKeyAndVisible()
        self.window?.tintColor = UIColor.nightguardAccent()

        dimScreenOnIdle()

        // Enable Background Updates
        BGTaskScheduler.shared.register(forTaskWithIdentifier: appProcessingTaskId, using: nil) { task in

            self.handelBackgroundProcessing(task as! BGProcessingTask)
        }

        return true
    }
    
    func performNightscoutSync(
        completion: @escaping (Bool) -> Void
    ) {
        
        Logger.log("performNightscoutSync started")
        
        let _ = NightscoutCacheService.singleton.loadCurrentNightscoutData { result in
            
            guard let result = result else {
                Logger.log("Failed with empty result")
                completion(false)
                return
            }
            
            switch result {
            case .error(let error):
                Logger.log("Unable to load current Nightscout Data:: \(error)")
                completion(false)
            case .data(let nightscoutData):
                
                // The new data has already been stored locally. Use it to determine wheter alerts have to be sent:
                AlarmNotificationService.singleton.notifyIfAlarmActivated(nightscoutData)
                WatchService.singleton.sendToWatchCurrentNightwatchData()
                
                if #available(iOS 16.1, *) {
                    LiveActivityManager.shared.update(with: nightscoutData)
                }
                
                // Also check device status for reservoir
                let _ = NightscoutCacheService.singleton.getDeviceStatusData { deviceStatusData in
                        AlarmNotificationService.singleton.notifyIfReservoirCritical(deviceStatusData.reservoirUnits)
                    }
                
                completion(true)
            }
        }
    }
    
    
    func handelBackgroundProcessing(_ task: BGProcessingTask) {
        Logger.log("handleBackgroundProcessing called")
        
        task.expirationHandler = {
                Logger.log("Background task expired")
            }
            
        performNightscoutSync { success in
            Logger.log("background sync success: \(success)")
                task.setTaskCompleted(success: true)
            }
           
        scheduleBackgroundProcessing()
    }
    
    func scheduleBackgroundProcessing() {
         let request = BGProcessingTaskRequest(identifier: appProcessingTaskId)
         request.requiresNetworkConnectivity = true
         request.earliestBeginDate = Date(timeIntervalSinceNow: 10 * 60)

         do {
             BGTaskScheduler.shared.cancelAllTaskRequests()
             try BGTaskScheduler.shared.submit(request)
         } catch {
             print("Could not schedule background fetch: \(error)")
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
                
                    print("Handling WatchSyncRequestMessage: UUID on watch didn't match phone UUID")
                }
            }
            
            // same comparison for snoozing timestamp
            if let anyWatchSnoozeTimestamp = message.dictionary["snoozedUntilTimestamp"] {
                let watchSnoozeTimestamp = anyWatchSnoozeTimestamp as? TimeInterval
                if AlarmRule.snoozedUntilTimestamp.value != watchSnoozeTimestamp {
                    
                    // send snooze data to watch!
                    SnoozeMessage(timestamp: AlarmRule.snoozedUntilTimestamp.value).send()
                    
                    print("Handling WatchSyncRequestMessage: Snooze timestamp on watch didn't match phone snooze timestamp")
                }
            }
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
        
        // Schedule Background Updates:
        self.scheduleBackgroundProcessing()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        if !AlarmRule.isSnoozed() {
            AlarmRule.snoozeSeconds(10)
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        UserDefaultsRepository.currentTab.value = .main
    }
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}


extension AppDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
        @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

