//
//  ExtensionDelegate.swift
//  scoutwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 20.11.15.
//  Copyright © 2015 private. All rights reserved.
//

import WatchKit
import WatchConnectivity
import ClockKit
import WidgetKit

@main
class ExtensionDelegate: NSObject, WKApplicationDelegate {
    
    // trick: keep the extension delegate ALIVE (because it seems it hangs when the watch app moves in the backround and will stop processing background tasks)
    // the idea came from this solution (https://stackoverflow.com/questions/41156386/wkurlsessionrefreshbackgroundtask-isnt-called-when-attempting-to-do-background)
    private(set) static var singleton: ExtensionDelegate!
    
    var session: WCSession? {
        didSet {
            if let session = session {
                session.delegate = WatchMessageService.singleton
                session.activate()
            }
        }
    }
    
    var pendingBackgroundURLTask: Any?
    var backgroundSession: URLSession?
    var downloadTask: URLSessionDownloadTask?
    var sessionError: Error?
    var sessionStartTime: Date?
    var userInfoAccess: NSSecureCoding?
    let appProcessingTaskId = "de.my-wan.dhe.nightguard.background"
    
    func applicationDidFinishLaunching() {
        
        // Perform any final initialization of your application.
        activateWatchConnectivity()
        
        // keep myself in class property (see above why...)
        ExtensionDelegate.singleton = self
        
        BackgroundRefreshLogger.info("Application did finish launching")
        AppMessageService.singleton.keepAwakePhoneApp()
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
            
            MainController.mainViewModel.refreshData(forceRefresh: true, moveToLatestValue: false)
        }
        
        // user defaults sync message
        WatchMessageService.singleton.onMessage { (message: UserDefaultSyncMessage) in
            
            // update user default values from "watch sync" group, keeping track of which of them were updated
            var updatedKeys: [String] = []
            let observationToken = UserDefaultsValueGroups.observeChanges(in: UserDefaultsValueGroups.GroupNames.watchSync) { value, _ in
                updatedKeys.append(value.key)
            }
            defer {
                observationToken.cancel()
            }
            
            // do the update!
            for var value in (UserDefaultsValueGroups.values(from: UserDefaultsValueGroups.GroupNames.watchSync) ?? []) {
                if let anyValue = message.dictionary[value.key] {
                    value.anyValue = anyValue
                }
            }
            
            // update the "last watch sync update id" field
            if let lastWatchSyncUpdateId = message.dictionary[UserDefaultsRepository.lastWatchSyncUpdateId.key] {
                UserDefaultsRepository.lastWatchSyncUpdateId.anyValue = lastWatchSyncUpdateId
            }
            
            // we should repaint current value if some used defaults values were changed
            let hasChangedUri = updatedKeys.contains(UserDefaultsRepository.baseUri.key)
            let hasChangedUnits = updatedKeys.contains(UserDefaultsRepository.units.key)
            
            if hasChangedUri {
                
                // reset cache if uri has changed!
                print("ExtensionDelegate.handleWatchMessages - resetting cache!")
                NightscoutCacheService.singleton.resetCache()
            }
            
            let shouldRepaintCurrentBgData = hasChangedUri || hasChangedUnits
            let shouldRepaintCharts = true // do it always!
            if shouldRepaintCurrentBgData || shouldRepaintCharts {
                MainController.mainViewModel.refreshData(forceRefresh: true, moveToLatestValue: false)
            }
        }
    }
    
    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        AppState.isUIActive = true
//        NotificationCenter.default.post(name: .refreshDataOnAppBecameActive, object: nil)
        //let's try also applicationWillEnterForeground()
    }
    
    func applicationWillEnterForeground() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        NotificationCenter.default.post(name: .refreshDataOnAppBecameActive, object: nil)
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
        
        AppState.isUIActive = false
        
        print("Application will resign active.")
        AppMessageService.singleton.keepAwakePhoneApp()
    }
}
