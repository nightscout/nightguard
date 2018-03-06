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

    var session: WCSession? {
        didSet {
            if let session = session {
                session.delegate = AppMessageService.singleton
                session.activate()
                
                // https://developer.apple.com/library/content/samplecode/QuickSwitch/Listings/QuickSwitch_WatchKit_Extension_ExtensionDelegate_swift.html
                session.addObserver(self, forKeyPath: "activationState", options: [], context: nil)
                session.addObserver(self, forKeyPath: "hasContentPending", options: [], context: nil)
            }
        }
    }
    
    var watchConnectivityBackgroundTasks: [Any] = []
    
    // debugging info for background refresh
    var ndRequests: Int = 0
    var ndResponses: Int = 0
    var ndRequestErrorMessages: [String] = []
    var ndUpdates: Int = 0
    var ndUpdatesSucceded: Int = 0
    var ndOldUpdateData: Int = 0

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
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        DispatchQueue.main.async {
            if #available(watchOSApplicationExtension 3, *) {
                self.completeAllTasksIfReady()
            } else {
                // Fallback on earlier versions
            }
        }
    }

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
                handleSessionTask(sessionTask)
            } else if let refreshTask = task as? WKApplicationRefreshBackgroundTask {
                handleRefreshTask(refreshTask)
            } else {
//                // not handled!
//                task.setTaskCompleted()
                
                // do a refresh
                handleRefreshTask(task)
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

extension ExtensionDelegate {
    
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
        
        // request data from phone app only if watch data is old (do not consume app's background refresh quota)
        if NightscoutCacheService.singleton.getCurrentNightscoutData().isOlderThan5Minutes() {
            requestNightscoutDataFromPhoneApp()
        }
        
        // schedule the next background refresh
        scheduleBackgroundRefresh()
        
        task.setTaskCompleted()
    }
    
    @available(watchOSApplicationExtension 3.0, *)
    func handleSessionTask(_ sessionTask: WKURLSessionRefreshBackgroundTask) {
        
        print("WKURLSessionRefreshTaskReceived, start URL session")
        
//        let backgroundSession = BackgroundUrlSessionWrapper.singleton
//        let backgroundConfigObject = URLSessionConfiguration.background(withIdentifier: sessionTask.sessionIdentifier)
//        let backgroundSession = URLSession(
//            configuration: backgroundConfigObject,
//            delegate: self as URLSessionDelegate,
//            delegateQueue: nil)
        
        //                print("Rejoining session ", backgroundSession)
        //                scheduleBackgroundUpdate()
        //                if #available(watchOSApplicationExtension 4.0, *) {
        //                    sessionTask.setTaskCompletedWithSnapshot(true)
        //                } else {
        //                    // Fallback on earlier versions
        //                    sessionTask.setTaskCompleted()
        //                }

        sessionTask.setTaskCompleted()
    }
    
    @discardableResult
    func handleNightscoutDataMessage(_ message: [String: Any]) -> Bool {
        
        ndUpdates += 1
        guard let data = message["nightscoutData"] as? Data, let nightscoutData = try? JSONDecoder().decode(NightscoutData.self, from: data) else {
            print("Invalid nightscout data received from phone app!")
            return false
        }
        
        // check the data that already exists on the watch... maybe is newer that the received data
        let currentNightscoutData = NightscoutCacheService.singleton.getCurrentNightscoutData()
        if currentNightscoutData.time.doubleValue > nightscoutData.time.doubleValue {
            
            // Old data was received from phone app! This can happen because the watch can have newer data than the phone app (phone app background fetch is once in 5 minutes) or because the delivery is not instantaneous and ... and the watch can update its data in between (when the app enters foreground)
            print("Received older nightscout data from phone app than watch has!")
            ndOldUpdateData += 1
            return false
        } else if currentNightscoutData.time.doubleValue == nightscoutData.time.doubleValue {
            // already have this data...
            return true
        }
        
        print("Nightscout data was received from phone app!")
        NightscoutCacheService.singleton.updateCurrentNightscoutData(newNightscoutData: nightscoutData)
        ndUpdatesSucceded += 1
        updateComplication()
        return true
    }
    
    // MARK:- Internals
    
    @available(watchOSApplicationExtension 3.0, *)
    fileprivate func scheduleBackgroundRefresh() {
        
        print("Schedule Background Refresh...\n")
        
        // Schedule a new refresh task in 15 Minutes (only 50 Updates are guaranteed from watchos per day :-/
        WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: Date(timeIntervalSinceNow: 60 * 15), userInfo: nil) { (error: Error?) in
            
            if let error = error {
                print("Error occurred while scheduling background refresh: \(error.localizedDescription)")
            }
        }
    }
    
    fileprivate func requestNightscoutDataFromPhoneApp() {
        
        guard let session = self.session, session.isReachable else {
            print("Session is not reachable... cannot request nightscout data from phone app...")
            return
        }
        
        ndRequests += 1
        session.sendMessage(
            ["requestNightscoutData": ""],
            replyHandler: { [weak self] response in
                if self?.handleNightscoutDataMessage(response) == true {
                    self?.ndResponses += 1
                    self?.updateComplication()
                }
            },
            errorHandler: { [weak self] error in
                print(error)
                self?.ndRequestErrorMessages.append(error.localizedDescription)
        })
    }
    
    fileprivate func updateComplication() {
        
        let complicationServer = CLKComplicationServer.sharedInstance()
        for complication in complicationServer.activeComplications ?? [] {
            complicationServer.reloadTimeline(for: complication)
        }
    }
}

extension ExtensionDelegate: URLSessionDelegate {
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("Background download was finished.")
        
        let nightscoutData = NSData(contentsOf: location as URL)
        NightscoutService.singleton.extractData(data: nightscoutData! as Data, {(newNightscoutData, error) -> Void in
            
            guard let newNightscoutData = newNightscoutData else {
                return
            }
            
            NightscoutCacheService.singleton.updateCurrentNightscoutData(newNightscoutData: newNightscoutData)
            self.updateComplication()
        })
    }
}
