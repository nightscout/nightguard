//
//  ExtensionDelegate.swift
//  scoutwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 20.11.15.
//  Copyright © 2015 private. All rights reserved.
//

import WatchKit
import WatchConnectivity

class ExtensionDelegate: NSObject, WKExtensionDelegate {
}

@available(watchOSApplicationExtension 3.0, *)
extension InterfaceController: WKExtensionDelegate {
    
    func applicationDidFinishLaunching() {
        
        // Initialize the BackgroundUrlSession. This has to be an singleton that is used throughout the whole app
        BackgroundUrlSessionWrapper.setup(delegate: self)
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
        if #available(watchOSApplicationExtension 3.0, *) {
            scheduleBackgroundRefresh()
        }
    }
    
    func initializeApplicationDefaults() {
        
        // Setting the defaults if the users starts the application for the first time
        let initialDefaults: NSDictionary = ["maximumBloodGlucoseDisplayed": 350]
        UserDefaults.standard.register(defaults: initialDefaults as! [String : AnyObject])
    }
    
//    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
//        DispatchQueue.main.async {
//            if #available(watchOSApplicationExtension 3, *) {
//                self.completeAllTasksIfReady()
//            } else {
//                // Fallback on earlier versions
//            }
//        }
//    }

    @available(watchOSApplicationExtension 3.0, *)
    public func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        
        // only handle these while running in the background
        guard WKExtension.shared().applicationState == .background else {
            backgroundTasks.forEach { $0.setTaskCompleted() }
            return
        }
        
        for task in backgroundTasks {
            if let watchConnectivityBackgroundTask = task as? WKWatchConnectivityRefreshBackgroundTask {
                handleWatchConnectivityBackgroundTask(watchConnectivityBackgroundTask)
            } else if let snapshotTask = task as? WKSnapshotRefreshBackgroundTask {
                handleSnapshotTask(snapshotTask)
            } else if let sessionTask = task as? WKURLSessionRefreshBackgroundTask {
                handleURLSessionTask(sessionTask)
//                return
            } else if let refreshTask = task as? WKApplicationRefreshBackgroundTask {
                handleRefreshTask(refreshTask)
            } else {
                // not handled!
                task.setTaskCompleted()
            }
        }
        
        completeAllTasksIfReady()
    }
    
    @available(watchOSApplicationExtension 3.0, *)
    func completeAllTasksIfReady() {
        
        guard let session = self.session else {
            return
        }
        
        // the session's properties only have valid values if the session is activated, so check that first
        if session.activationState == .activated && !session.hasContentPending {
            watchConnectivityBackgroundTasks.forEach { ($0 as! WKWatchConnectivityRefreshBackgroundTask).setTaskCompleted() }
            watchConnectivityBackgroundTasks.removeAll()
        }
    }
}

@available(watchOSApplicationExtension 3.0, *)
extension InterfaceController {
    
    // MARK:- Background update methods
    
    @available(watchOSApplicationExtension 3.0, *)
    func handleWatchConnectivityBackgroundTask (_ watchConnectivityBackgroundTask: WKWatchConnectivityRefreshBackgroundTask) {
        self.watchConnectivityBackgroundTasks.append(watchConnectivityBackgroundTask)
    }
    
    @available(watchOSApplicationExtension 3.0, *)
    func handleSnapshotTask(_ snapshotTask : WKSnapshotRefreshBackgroundTask) {
        
        // implement this if needed...
        
        snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
    }
    
    @available(watchOSApplicationExtension 3.0, *)
    func handleRefreshTask(_ task : WKRefreshBackgroundTask) {
        
        print("WKApplicationRefreshBackgroundTask received")
        
        // schedule an URL session..
        if self.backgroundSession == nil {
            let (backgroundSession, downloadTask) = scheduleURLSession()
            self.backgroundSession = backgroundSession
            self.downloadTask = downloadTask
            backgroundURLSessions += 1
            log("URL session started")
        } else {
            log("URL session already exists, cannot start new one!")
        }
        
        
        // ...and schedule the next background refresh
        scheduleBackgroundRefresh()
        
        task.setTaskCompleted()
    }
    
    @available(watchOSApplicationExtension 3.0, *)
    func handleURLSessionTask(_ sessionTask: WKURLSessionRefreshBackgroundTask) {
        
        print("WKURLSessionRefreshTaskReceived, start URL session")
        
        let backgroundConfigObject = URLSessionConfiguration.background(withIdentifier: sessionTask.sessionIdentifier)
        let backgroundSession = URLSession(configuration: backgroundConfigObject, delegate: self, delegateQueue: nil)
        print("Rejoining session ", backgroundSession)
        log("WKURLSessionRefreshBackgroundTask received")

        // keep the session background task, it will be ended later... (https://stackoverflow.com/questions/41156386/wkurlsessionrefreshbackgroundtask-isnt-called-when-attempting-to-do-background)
        self.pendingBackgroundURLTask = sessionTask
    }
    
    @discardableResult
    func handleNightscoutDataMessage(_ message: [String: Any]) -> Bool {
        
        phoneUpdates += 1
        guard let data = message["nightscoutData"] as? Data, let nightscoutData = try? JSONDecoder().decode(NightscoutData.self, from: data) else {
            print("Invalid nightscout data received from phone app!")
            return false
        }
        
        let updateResult = updateNightscoutData(nightscoutData)
        switch updateResult {
        case .updateDataIsOld:
            phoneUpdatesWithOldData += 1
        case .updateDataAlreadyExists:
            phoneUpdatesWithSameData += 1
        case .updated:
            phoneUpdatesWithNewData += 1

        }
        
        return updateResult != .updateDataIsOld
    }
    
    // MARK:- Internals
    
    @available(watchOSApplicationExtension 3.0, *)
    fileprivate func scheduleBackgroundRefresh() {
        
        print("Schedule Background Refresh...\n")
        
        // will do it around x:00, x:15, x:30 and x:45
        let now = Date()
        let unitFlags:Set<Calendar.Component> = [
            .hour, .day, .month,
            .year,.minute,.hour,.second,
            .calendar]
        var dateComponents = Calendar.current.dateComponents(unitFlags, from: now)
        
        // reset second
        dateComponents.second = 0
        
        let refreshRate = 12  // number of refreshes per hour
        let refreshPeriod = 60 / refreshRate
        
        let nextRefreshMinute = ((dateComponents.minute! / refreshPeriod) + 1) * refreshPeriod
        dateComponents.minute = nextRefreshMinute % 60
        
        var scheduleTime = Calendar.current.date(from: dateComponents)!
        if nextRefreshMinute >= 60 {
            scheduleTime = Calendar.current.date(byAdding: .hour, value: 1, to: scheduleTime)!
        }
        
        // Schedule a new refresh task in 15 Minutes (only 50 Updates are guaranteed from watchos per day :-/
        WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: scheduleTime, userInfo: nil) { (error: Error?) in
            
            if self.nextBackgroundRefreshTime != scheduleTime {
                self.nextBackgroundRefreshTime = scheduleTime
                
                // log it!
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm:ss"
                let dateString = timeFormatter.string(from: scheduleTime)
                self.log("Scheduled next background refresh at \(dateString)")
            }
            
            if let error = error {
                print("Error occurred while scheduling background refresh: \(error.localizedDescription)")
                self.log("Error occurred while scheduling background refresh: \(error.localizedDescription)")
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
        updateComplication()
        
        return .updated
    }
    
    fileprivate func log(_ text : String) {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let dateString = timeFormatter.string(from: Date())
        
        backgroundTasksLog.append(dateString + " " + text)
    }
}

@available(watchOSApplicationExtension 3.0, *)
extension InterfaceController: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("Background download was finished.")
        
        let nightscoutData = NSData(contentsOf: location as URL)
        
        // extract data on main thead
        DispatchQueue.main.sync { [unowned self] in
            NightscoutService.singleton.extractData(data: nightscoutData! as Data, { [unowned self] (newNightscoutData, error) -> Void in
                
                guard let newNightscoutData = newNightscoutData else {
                    return
                }
                
                let updateResult = self.updateNightscoutData(newNightscoutData)
                switch updateResult {
                case .updateDataIsOld:
                    self.backgroundURLSessionUpdatesWithOldData += 1
                    self.log("URL session data: OLD")
                case .updateDataAlreadyExists:
                    self.backgroundURLSessionUpdatesWithSameData += 1
                    self.log("URL session data: EXISTING")
                case .updated:
                    self.backgroundURLSessionUpdatesWithNewData += 1
                    self.log("URL session data: NEW")
                }
            })
        }
        
        completePendingURLSessionTask()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("Background url session completed with error: \(error)")
        if let error = error {
            log("URL session did complete with error: \(error)")
        }
        completePendingURLSessionTask()
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("Background url session did finish events")
        log("URL session did finish events")
        completePendingURLSessionTask()
    }
    
    fileprivate func completePendingURLSessionTask() {
        
        self.backgroundSession?.invalidateAndCancel()
        self.backgroundSession = nil
        self.downloadTask = nil
        if #available(watchOSApplicationExtension 3.0, *) {
            (self.pendingBackgroundURLTask as? WKRefreshBackgroundTask)?.setTaskCompleted()
        } else {
            // Fallback on earlier versions
        }
        self.pendingBackgroundURLTask = nil

        self.log("URL session COMPLETED")
    }
    
    func scheduleURLSession() -> (URLSession, URLSessionDownloadTask) {
        
        let backgroundConfigObject = URLSessionConfiguration.background(withIdentifier: NSUUID().uuidString)
        backgroundConfigObject.sessionSendsLaunchEvents = true
//        backgroundConfigObject.timeoutIntervalForRequest = 15 // 10 seconds timeout for request (after 15 seconds, the task is finished and a crash occurs, so... we have to stop it somehow!)
//        backgroundConfigObject.timeoutIntervalForResource = 15 // the same for retry interval (no retries!)
        let backgroundSession = URLSession(configuration: backgroundConfigObject, delegate: self, delegateQueue: nil)
        
        let downloadURL = URL(string: UserDefaultsRepository.readBaseUri() + "/pebble")!
        let downloadTask = backgroundSession.downloadTask(with: downloadURL)
        downloadTask.resume()
        
        return (backgroundSession, downloadTask)
    }
}
