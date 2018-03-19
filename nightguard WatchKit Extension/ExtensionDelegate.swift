//
//  ExtensionDelegate.swift
//  scoutwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 20.11.15.
//  Copyright © 2015 private. All rights reserved.
//

import WatchKit
import WatchConnectivity

// fake, not used... the WKExtensionDelegate protocol was implemented by InterfaceController (https://stackoverflow.com/questions/41156386/wkurlsessionrefreshbackgroundtask-isnt-called-when-attempting-to-do-background)
class ExtensionDelegate: NSObject, WKExtensionDelegate {
}

@available(watchOSApplicationExtension 3.0, *)
extension InterfaceController: WKExtensionDelegate {
    
    func applicationDidFinishLaunching() {
        
        // Initialize the BackgroundUrlSession. This has to be an singleton that is used throughout the whole app
//        BackgroundUrlSessionWrapper.setup(delegate: self)
        // Perform any final initialization of your application.
        activateWatchConnectivity()
    }

    func activateWatchConnectivity() {
        if WCSession.isSupported() {
            session = WCSession.default
        }
    }
    
    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
        
        print("Application will resign active.")
        scheduleBackgroundRefresh()
    }
    
    func initializeApplicationDefaults() {
        
        // Setting the defaults if the users starts the application for the first time
        let initialDefaults: NSDictionary = ["maximumBloodGlucoseDisplayed": 350]
        UserDefaults.standard.register(defaults: initialDefaults as! [String : AnyObject])
    }

    @available(watchOSApplicationExtension 3.0, *)
    public func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        
        // only handle these while running in the background
        guard WKExtension.shared().applicationState == .background else {
            backgroundTasks.forEach { $0.setTaskCompleted() }
            return
        }
        
        for task in backgroundTasks {
            
            // crash solving trick: acces the task user info to avoid a rare, but weird crash.. (https://forums.developer.apple.com/thread/96504 and https://stackoverflow.com/questions/46464660/wkrefreshbackgroundtask-cleanupstorage-error-attempting-to-reach-file)
            userInfoAccess = task.userInfo
            
            if let watchConnectivityBackgroundTask = task as? WKWatchConnectivityRefreshBackgroundTask {
                handleWatchConnectivityBackgroundTask(watchConnectivityBackgroundTask)
            } else if let snapshotTask = task as? WKSnapshotRefreshBackgroundTask {
                handleSnapshotTask(snapshotTask)
            } else if let sessionTask = task as? WKURLSessionRefreshBackgroundTask {
                handleURLSessionTask(sessionTask)
            } else if let refreshTask = task as? WKApplicationRefreshBackgroundTask {
                handleRefreshTask(refreshTask)
            } else {
                // not handled!
                task.setTaskCompleted()
            }
        }
    }
}

@available(watchOSApplicationExtension 3.0, *)
extension InterfaceController {
    
    // MARK:- Background update methods
    
    func handleWatchConnectivityBackgroundTask (_ watchConnectivityBackgroundTask: WKWatchConnectivityRefreshBackgroundTask) {
    
        print("WKWatchConnectivityRefreshBackgroundTask received, what can I do now?!?")
        watchConnectivityBackgroundTask.setTaskCompleted()
    }
    
    func handleSnapshotTask(_ snapshotTask : WKSnapshotRefreshBackgroundTask) {
        
        BackgroundRefreshLogger.info("WKSnapshotRefreshBackgroundTask received")
        
        // update user interface with current nightscout data (or error)
        let currentNightscoutData = NightscoutCacheService.singleton.getCurrentNightscoutData()
        let interfaceController = WKExtension.shared().rootInterfaceController as? InterfaceController
        interfaceController?.updateInterface(withNightscoutData: currentNightscoutData, error: self.sessionError)
        
        snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
    }
    
    func handleRefreshTask(_ task : WKRefreshBackgroundTask) {
        
        BackgroundRefreshLogger.info("WKApplicationRefreshBackgroundTask received")
        BackgroundRefreshLogger.backgroundRefreshes += 1
        
        scheduleURLSessionIfNeeded()
        
        // schedule the next background refresh
        BackgroundRefreshScheduler.instance.schedule()
        
        task.setTaskCompleted()
    }
    
    func handleURLSessionTask(_ sessionTask: WKURLSessionRefreshBackgroundTask) {
        
        BackgroundRefreshLogger.info("WKURLSessionRefreshBackgroundTask received")
        
        let backgroundConfigObject = URLSessionConfiguration.background(withIdentifier: sessionTask.sessionIdentifier)
        let backgroundSession = URLSession(configuration: backgroundConfigObject, delegate: self, delegateQueue: nil)
        print("Rejoining session ", backgroundSession)

        // keep the session background task, it will be ended later... (https://stackoverflow.com/questions/41156386/wkurlsessionrefreshbackgroundtask-isnt-called-when-attempting-to-do-background)
        self.pendingBackgroundURLTask = sessionTask
    }
    
    @discardableResult
    func handleNightscoutDataMessage(_ message: [String: Any]) -> Bool {
        
        BackgroundRefreshLogger.phoneUpdates += 1
        guard let data = message["nightscoutData"] as? Data, let nightscoutData = try? JSONDecoder().decode(NightscoutData.self, from: data) else {
            print("Invalid nightscout data received from phone app!")
            return false
        }
        
        let updateResult = updateNightscoutData(nightscoutData)
        switch updateResult {
        case .updateDataIsOld:
            BackgroundRefreshLogger.phoneUpdatesWithOldData += 1
        case .updateDataAlreadyExists:
            BackgroundRefreshLogger.phoneUpdatesWithSameData += 1
        case .updated:
            BackgroundRefreshLogger.phoneUpdatesWithNewData += 1
        }
        
        return updateResult != .updateDataIsOld
    }
    
    // MARK:- Internals
    
    fileprivate func scheduleBackgroundRefresh() {
        BackgroundRefreshScheduler.instance.schedule()
    }
    
    fileprivate func scheduleSnapshotRefresh() {
        
        let scheduleTime = Date(timeIntervalSinceNow: 1) // do it now!
        WKExtension.shared().scheduleSnapshotRefresh(withPreferredDate: scheduleTime, userInfo: nil) { (error: Error?) in

            BackgroundRefreshLogger.info("Scheduled next snapshot refresh (NOW!)")

            if let error = error {
                BackgroundRefreshLogger.info("Error occurred while scheduling snapshot refresh: \(error.localizedDescription)")
            }
        }
    }
    
    fileprivate func updateComplication() {
        
        let complicationServer = CLKComplicationServer.sharedInstance()
        for complication in complicationServer.activeComplications ?? [] {
            complicationServer.reloadTimeline(for: complication)
        }
    }
    
    fileprivate enum UpdateResult {
        
        // update succeeded
        case updated
        
        // update data already exists (is the current nightscout data) - no need to update!
        case updateDataAlreadyExists
        
        // update data is older than current nightscout data
        case updateDataIsOld
    }
    fileprivate func updateNightscoutData(_ newNightscoutData: NightscoutData) -> UpdateResult {
        
        // check the data that already exists on the watch... maybe is newer that the received data
        let currentNightscoutData = NightscoutCacheService.singleton.getCurrentNightscoutData()
        if currentNightscoutData.time.doubleValue > newNightscoutData.time.doubleValue {
            
            // Old data was received from remote (phone app or URL session)! This can happen because:
            //      1. if receiving data from phone app: the watch can have newer data than the phone app (phone app background fetch is once in 5 minutes) or because the delivery is not instantaneous and ... and the watch can update its data in between (when the app enters foreground)
            //      2. if receiving data from a URL session: the session can complete later, when there are resources available on the watch to execute it... so there is a posibility than the watch app update itself till then
            print("Received older nightscout data than current watch nightscout data!")
            return .updateDataIsOld
            
        } else if currentNightscoutData.time.doubleValue == newNightscoutData.time.doubleValue {
            
            // already have this data...
            return .updateDataAlreadyExists
        }
        
        print("Nightscout data was received from remote (phone app or URL session)!")
        NightscoutCacheService.singleton.updateCurrentNightscoutData(newNightscoutData: newNightscoutData)
        scheduleSnapshotRefresh()
        updateComplication()
        
        return .updated
    }
    
    fileprivate func scheduleURLSessionIfNeeded() {
        
//        let currentNightscoutData = NightscoutCacheService.singleton.getCurrentNightscoutData()
//        guard currentNightscoutData.isOlderThan5Minutes() else {
//            BackgroundRefreshLogger.info("Recent nightscout data, skipping URL session!")
//            return
//        }
        
        guard self.backgroundSession == nil else {
            BackgroundRefreshLogger.info("URL session already exists, cannot start new one!")
            return
        }
        
        guard let (backgroundSession, downloadTask) = scheduleURLSession() else {
            BackgroundRefreshLogger.info("URL session cannot be created, probably base uri is not configured!")
            return
        }
        
        self.backgroundSession = backgroundSession
        self.downloadTask = downloadTask
        BackgroundRefreshLogger.backgroundURLSessions += 1
        BackgroundRefreshLogger.info("URL session started")
    }
}

@available(watchOSApplicationExtension 3.0, *)
extension InterfaceController: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("Background download was finished.")
        
        // reset the session error
        self.sessionError = nil
        
        let nightscoutData = NSData(contentsOf: location as URL)
        
        // extract data on main thead
        DispatchQueue.main.sync { [unowned self] in
            NightscoutService.singleton.extractData(data: nightscoutData! as Data, { [unowned self] (newNightscoutData, error) -> Void in
                
                // keep the error (if any)
                self.sessionError = error
                
                guard let newNightscoutData = newNightscoutData else {
                    return
                }
                
                let updateResult = self.updateNightscoutData(newNightscoutData)
                switch updateResult {
                case .updateDataIsOld:
                    BackgroundRefreshLogger.backgroundURLSessionUpdatesWithOldData += 1
                    BackgroundRefreshLogger.info("URL session data: OLD")
                case .updateDataAlreadyExists:
                    BackgroundRefreshLogger.backgroundURLSessionUpdatesWithSameData += 1
                    BackgroundRefreshLogger.info("URL session data: EXISTING")
                case .updated:
                    BackgroundRefreshLogger.backgroundURLSessionUpdatesWithNewData += 1
                    BackgroundRefreshLogger.info("URL session data: NEW")
                }
            })
        }
        
        completePendingURLSessionTask()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("Background url session completed with error: \(error)")
        if let error = error {
            BackgroundRefreshLogger.info("URL session did complete with error: \(error)")
        }
        
        // keep the session error (if any!)
        self.sessionError = error
        
        completePendingURLSessionTask()
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        BackgroundRefreshLogger.info("URL session did finish events")
        completePendingURLSessionTask()
    }
    
    fileprivate func completePendingURLSessionTask() {
        
        if self.backgroundSession != nil {
            
            // log only ONCE, as this method can be called more than once
             BackgroundRefreshLogger.info("URL session COMPLETED")
        }
        
        self.backgroundSession?.invalidateAndCancel()
        self.backgroundSession = nil
        self.downloadTask = nil
        (self.pendingBackgroundURLTask as? WKRefreshBackgroundTask)?.setTaskCompleted()
        self.pendingBackgroundURLTask = nil
    }
    
    func scheduleURLSession() -> (URLSession, URLSessionDownloadTask)? {
        
        let backgroundConfigObject = URLSessionConfiguration.background(withIdentifier: NSUUID().uuidString)
        backgroundConfigObject.sessionSendsLaunchEvents = true
//        backgroundConfigObject.timeoutIntervalForRequest = 15 // 10 seconds timeout for request (after 15 seconds, the task is finished and a crash occurs, so... we have to stop it somehow!)
//        backgroundConfigObject.timeoutIntervalForResource = 15 // the same for retry interval (no retries!)
        let backgroundSession = URLSession(configuration: backgroundConfigObject, delegate: self, delegateQueue: nil)
        
        let baseUri = UserDefaultsRepository.readBaseUri()
        if baseUri == "" {
            return nil
        }
        
        let downloadURL = URL(string: baseUri + "/pebble")!
        let downloadTask = backgroundSession.downloadTask(with: downloadURL)
        downloadTask.resume()
        
        return (backgroundSession, downloadTask)
    }
}
