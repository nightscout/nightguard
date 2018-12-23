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
    
    // trick: keep the extension delegate ALIVE (because it seems it hangs when the watch app moves in the backround and will stop processing background tasks)
    // the idea came from this solution (https://stackoverflow.com/questions/41156386/wkurlsessionrefreshbackgroundtask-isnt-called-when-attempting-to-do-background)
    private(set) static var singleton: ExtensionDelegate!
    
    var session: WCSession? {
        didSet {
            if let session = session {
                session.delegate = AppMessageService.singleton
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
    
    func applicationDidFinishLaunching() {
        
        // Initialize the BackgroundUrlSession. This has to be an singleton that is used throughout the whole app
//        BackgroundUrlSessionWrapper.setup(delegate: self)
        // Perform any final initialization of your application.
        activateWatchConnectivity()
        
        // keep myself in class property (see above why...)
        ExtensionDelegate.singleton = self
        
        BackgroundRefreshLogger.info("Application did finish launching")
        if #available(watchOSApplicationExtension 3.0, *) {
            scheduleBackgroundRefresh()
        }
        AppMessageService.singleton.keepAwakePhoneApp()
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
        AppMessageService.singleton.keepAwakePhoneApp()
    }
    
    func initializeApplicationDefaults() {
        
        // Setting the defaults if the users starts the application for the first time
        let initialDefaults: NSDictionary = ["maximumBloodGlucoseDisplayed": 350]
        UserDefaults.standard.register(defaults: initialDefaults as! [String : AnyObject])
    }

    @available(watchOSApplicationExtension 3.0, *)
    public func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        
        for task in backgroundTasks {
            
            // crash solving trick: acces the task user info to avoid a rare, but weird crash.. (https://forums.developer.apple.com/thread/96504 and https://stackoverflow.com/questions/46464660/wkrefreshbackgroundtask-cleanupstorage-error-attempting-to-reach-file)
            userInfoAccess = task.userInfo
            
            if let watchConnectivityBackgroundTask = task as? WKWatchConnectivityRefreshBackgroundTask {
                handleWatchConnectivityBackgroundTask(watchConnectivityBackgroundTask)
            } else if let snapshotTask = task as? WKSnapshotRefreshBackgroundTask {
                handleSnapshotTask(snapshotTask)
            } else if let sessionTask = task as? WKURLSessionRefreshBackgroundTask {
                handleURLSessionTask(sessionTask)
            } else if let refreshTask = task as? WKApplicationRefreshBackgroundTask, WKExtension.shared().applicationState == .background {
                handleRefreshTask(refreshTask)
            } else {
                // not handled!
                task.setTaskCompleted()
            }
        }
    }
}

extension ExtensionDelegate {
    
    // MARK:- Background update methods
    
    @available(watchOSApplicationExtension 3.0, *)
    func handleWatchConnectivityBackgroundTask (_ watchConnectivityBackgroundTask: WKWatchConnectivityRefreshBackgroundTask) {
    
        BackgroundRefreshLogger.info("WKWatchConnectivityRefreshBackgroundTask received")
        watchConnectivityBackgroundTask.setTaskCompleted()
    }
    
    @available(watchOSApplicationExtension 3.0, *)
    func handleSnapshotTask(_ snapshotTask : WKSnapshotRefreshBackgroundTask) {
        
        BackgroundRefreshLogger.info("WKSnapshotRefreshBackgroundTask received")
        
        // update user interface with current nightscout data (or error)
        let currentNightscoutData = NightscoutCacheService.singleton.getCurrentNightscoutData()
        let interfaceController = WKExtension.shared().rootInterfaceController as? InterfaceController
        interfaceController?.updateInterface(withNightscoutData: currentNightscoutData, error: self.sessionError)
        
        snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
    }
    
    @available(watchOSApplicationExtension 3.0, *)
    func handleRefreshTask(_ task : WKRefreshBackgroundTask) {
        
        BackgroundRefreshLogger.info("WKApplicationRefreshBackgroundTask received")
        BackgroundRefreshLogger.backgroundRefreshes += 1
        
        scheduleURLSessionIfNeeded()
        
        // schedule the next background refresh
        BackgroundRefreshScheduler.instance.schedule()
        
        task.setTaskCompleted()
    }
    
    @available(watchOSApplicationExtension 3.0, *)
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
        
        guard !nightscoutData.isOlderThanXMinutes(60) else {
            BackgroundRefreshLogger.info("📱Rejected nightscout data (>1hr old!)")
            return false
        }

        let updateComplication = message["updateComplication"] as? Bool ?? false
        BackgroundRefreshLogger.info("📱Updating nightscout data (update complication: \(updateComplication))")
        
        let updateResult = updateNightscoutData(nightscoutData, updateComplication: true) // always update complication!
        BackgroundRefreshLogger.nightscoutDataReceived(nightscoutData, updateResult: updateResult, updateSource: .phoneApp)
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
    
    @available(watchOSApplicationExtension 3.0, *)
    fileprivate func scheduleBackgroundRefresh() {
        BackgroundRefreshScheduler.instance.schedule()
    }
    
//    @available(watchOSApplicationExtension 3.0, *)
//    fileprivate func scheduleSnapshotRefresh() {
//
//        let scheduleTime = Date(timeIntervalSinceNow: 10) // do it now!
//        WKExtension.shared().scheduleSnapshotRefresh(withPreferredDate: scheduleTime, userInfo: nil) { (error: Error?) in
//
//            BackgroundRefreshLogger.info("Scheduled next snapshot refresh (NOW!)")
//
//            if let error = error {
//                BackgroundRefreshLogger.info("Error occurred while scheduling snapshot refresh: \(error.localizedDescription)")
//            }
//        }
//    }
    
    fileprivate func updateComplication() {
        
        let complicationServer = CLKComplicationServer.sharedInstance()
        for complication in complicationServer.activeComplications ?? [] {
            complicationServer.reloadTimeline(for: complication)
        }
    }
    
    enum UpdateSource {
        
        // the update was initiated by phone app
        case phoneApp
        
        // the update was initiated by watch (background URL session)
        case urlSession
    }
    
    enum UpdateResult {
        
        // update succeeded
        case updated
        
        // update data already exists (is the current nightscout data) - no need to update!
        case updateDataAlreadyExists
        
        // update data is older than current nightscout data
        case updateDataIsOld
    }
    
    fileprivate func updateNightscoutData(_ newNightscoutData: NightscoutData, updateComplication: Bool = true) -> UpdateResult {
        
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
//        if #available(watchOSApplicationExtension 3.0, *) {
//            scheduleSnapshotRefresh()
//        }
        
        if updateComplication {
            self.updateComplication()
        }
        
        return .updated
    }
    
    func scheduleURLSessionIfNeeded() {
        
//        let currentNightscoutData = NightscoutCacheService.singleton.getCurrentNightscoutData()
//        guard currentNightscoutData.isOlderThan5Minutes() else {
//            BackgroundRefreshLogger.info("Recent nightscout data, skipping URL session!")
//            return
//        }
        
        if self.backgroundSession != nil {
            
            if let sessionStartTime = self.sessionStartTime, Calendar.current.date(byAdding: .minute, value: BackgroundRefreshSettings.urlSessionTaskTimeout, to: sessionStartTime)! > Date() {
                
                // URL session running.. we'll let it do its work!
                BackgroundRefreshLogger.info("URL session already exists, cannot start a new one!")
                return
            } else {
                
                // timeout reached for URL session, we'll start a new one!
                BackgroundRefreshLogger.info("URL session timeout exceeded, finishing current and starting a new one!")
                completePendingURLSessionTask()
            }
        }
        
        guard let (backgroundSession, downloadTask) = scheduleURLSession() else {
            BackgroundRefreshLogger.info("URL session cannot be created, probably base uri is not configured!")
            return
        }
        
        self.sessionStartTime = Date()
        self.backgroundSession = backgroundSession
        self.downloadTask = downloadTask
        BackgroundRefreshLogger.backgroundURLSessions += 1
        BackgroundRefreshLogger.info("URL session started")
    }
}

extension ExtensionDelegate: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("Background download was finished.")
        
        // reset the session error
        self.sessionError = nil
        
        let nightscoutData = NSData(contentsOf: location as URL)
        
        // extract data on main thead
        DispatchQueue.main.async { [unowned self] in
            NightscoutService.singleton.extractData(data: nightscoutData! as Data, { [unowned self] result in
                
                switch result {
                case .error(let error):
                    self.sessionError = error
                    
                case .data(let newNightscoutData):
                    self.sessionError = nil

                    let updateResult = self.updateNightscoutData(newNightscoutData)
                    BackgroundRefreshLogger.nightscoutDataReceived(newNightscoutData, updateResult: updateResult, updateSource: .urlSession)
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
                }
            })
        }
        
        completePendingURLSessionTask()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("Background url session completed with error: \(String(describing: error))")
        if let error = error {
            BackgroundRefreshLogger.info("URL session did complete with error: \(error)")
            completePendingURLSessionTask()
        }
        
        // keep the session error (if any!)
        self.sessionError = error
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        BackgroundRefreshLogger.info("URL session did finish events")
//        completePendingURLSessionTask()
    }
    
    fileprivate func completePendingURLSessionTask() {
        
        self.backgroundSession?.invalidateAndCancel()
        self.backgroundSession = nil
        self.downloadTask = nil
        self.sessionStartTime = nil
        if #available(watchOSApplicationExtension 3.0, *) {
            (self.pendingBackgroundURLTask as? WKRefreshBackgroundTask)?.setTaskCompleted()
        }
        self.pendingBackgroundURLTask = nil
        
        BackgroundRefreshLogger.info("URL session COMPLETED")
    }
    
    func scheduleURLSession() -> (URLSession, URLSessionDownloadTask)? {
        
        let baseUri = UserDefaultsRepository.readBaseUri()
        if baseUri == "" {
            return nil
        }
        
        let backgroundConfigObject = URLSessionConfiguration.background(withIdentifier: NSUUID().uuidString)
        backgroundConfigObject.sessionSendsLaunchEvents = true
//        backgroundConfigObject.timeoutIntervalForRequest = 15 // 15 seconds timeout for request (after 15 seconds, the task is finished and a crash occurs, so... we have to stop it somehow!)
//        backgroundConfigObject.timeoutIntervalForResource = 15 // the same for retry interval (no retries!)
        let backgroundSession = URLSession(configuration: backgroundConfigObject, delegate: self, delegateQueue: nil)
        
        let downloadURL = URL(string: baseUri + "/pebble")!
        let downloadTask = backgroundSession.downloadTask(with: downloadURL)
        downloadTask.resume()
        
        return (backgroundSession, downloadTask)
    }
}
