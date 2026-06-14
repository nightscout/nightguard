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
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(FirebaseCore) && canImport(FirebaseAppCheck)
import FirebaseCore
import FirebaseAppCheck
#endif
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

extension Notification.Name {
    static let showProPromotionRequest = Notification.Name("ShowProPromotionRequest")
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let appProcessingTaskId = "de.my-wan.dhe.nightguard.background"
    private var hasEnteredBackground = false
    
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

        configureFirebaseIfAvailable()

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

    private func configureFirebaseIfAvailable() {
        #if canImport(FirebaseCore) && canImport(FirebaseAppCheck)
        if FirebaseApp.app() == nil {
            guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
                AppLogger.singleton.warning("GoogleService-Info.plist missing; Firebase App Check is disabled", category: .backgroundUpdates)
                return
            }

            AppCheck.setAppCheckProviderFactory(NightguardAppCheckProviderFactory())
            FirebaseApp.configure()
        }
        #endif
        #if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = self
        #endif
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
        applyInitialLocalAudioSuppressionIfNeeded(application: application, launchOptions: launchOptions)

        // Initialize the stored UserDefaultsData
        TreatmentsStream.singleton.treatments = UserDefaultsRepository.treatments.value

        // Enable Background Updates
        BGTaskScheduler.shared.register(forTaskWithIdentifier: appProcessingTaskId, using: nil) { task in

            self.handelBackgroundProcessing(task as! BGProcessingTask)
        }

        MaxBackgroundPushRegistrationService.shared.configureForCurrentEntitlement()

        return true
    }
    
    func handelBackgroundProcessing(_ task: BGProcessingTask) {
        let completionLock = NSLock()
        var completed = false

        func completeTask(success: Bool, reason: String) {
            completionLock.lock()
            defer { completionLock.unlock() }

            guard !completed else {
                AppLogger.singleton.warning("BG task completion ignored because task already completed: \(reason)", category: .backgroundUpdates)
                return
            }

            completed = true
            AppLogger.singleton.debug("BG task completed success=\(success), reason=\(reason)", category: .backgroundUpdates)
            task.setTaskCompleted(success: success)
        }

        task.expirationHandler = {
            AppLogger.singleton.warning("BG task expired", category: .backgroundUpdates)
            completeTask(success: false, reason: "expired")
        }

        AppLogger.singleton.debug("BG task started", category: .backgroundUpdates)

        BackgroundUpdateCoordinator.shared.run(trigger: .bgTask) { result in
            self.scheduleBackgroundProcessing()
            completeTask(success: result.success, reason: result.message)
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
            guard !PurchaseManager.shared.hasProFeatureAccess else {
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
        hasEnteredBackground = true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        #if DEBUG
        Messaging.messaging().setAPNSToken(deviceToken, type: .sandbox)
        #else
        Messaging.messaging().setAPNSToken(deviceToken, type: .prod)
        #endif
        #endif
        MaxBackgroundPushRegistrationService.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        MaxBackgroundPushRegistrationService.shared.didFailToRegisterForRemoteNotifications(error: error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        AppLogger.singleton.debug("Received silent APNs background update", category: .backgroundUpdates)

        BackgroundUpdateCoordinator.shared.run(trigger: .silentPush) { result in
            self.scheduleBackgroundProcessing()
            if result.success {
                completionHandler(result.hasNewData ? .newData : .noData)
            } else {
                completionHandler(.failed)
            }
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        guard hasEnteredBackground else {
            return
        }

        hasEnteredBackground = false
        applyTransientLocalAudioSuppressionIfNeeded()
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

    private func applyInitialLocalAudioSuppressionIfNeeded(application: UIApplication, launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard shouldApplyInitialLocalAudioSuppression(application: application, launchOptions: launchOptions) else {
            return
        }

        applyTransientLocalAudioSuppressionIfNeeded()
    }

    private func applyTransientLocalAudioSuppressionIfNeeded() {
        guard !AlarmRule.isSnoozed(ignoreTransientLocalAudioSuppression: true) else {
            return
        }

        AlarmRule.suppressTransientLocalAudio(seconds: 10)
        AlarmSound.stop()
    }

    static func shouldApplyInitialLocalAudioSuppression(
        applicationState: UIApplication.State,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if applicationState == .background {
            return false
        }
        return true
    }

    private func shouldApplyInitialLocalAudioSuppression(
        application: UIApplication,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        Self.shouldApplyInitialLocalAudioSuppression(
            applicationState: application.applicationState,
            launchOptions: launchOptions
        )
    }
}

#if canImport(FirebaseCore) && canImport(FirebaseAppCheck)
private final class NightguardAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        if #available(iOS 14.0, *) {
            return AppAttestProvider(app: app) ?? DeviceCheckProviderFactory().createProvider(with: app)
        }

        return DeviceCheckProviderFactory().createProvider(with: app)
    }
}
#endif

#if canImport(FirebaseMessaging)
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, !fcmToken.isEmpty else { return }
        MaxBackgroundPushRegistrationService.shared.didReceiveFCMToken(fcmToken)
    }
}
#endif

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
