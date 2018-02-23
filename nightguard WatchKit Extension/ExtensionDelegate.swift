//
//  ExtensionDelegate.swift
//  scoutwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 20.11.15.
//  Copyright © 2015 private. All rights reserved.
//

import WatchKit
import WatchConnectivity

class ExtensionDelegate: NSObject, WKExtensionDelegate, URLSessionDelegate {

    var session: WCSession? {
        didSet {
            if let session = session {
                session.delegate = AppMessageService.singleton
                session.activate()
            }
        }
    }
    
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
            scheduleBackgroundUpdate()
        }
    }
    
    func initializeApplicationDefaults() {
        
        // Setting the defaults if the users starts the application for the first time
        let initialDefaults: NSDictionary = ["maximumBloodGlucoseDisplayed": 350]
        UserDefaults.standard.register(defaults: initialDefaults as! [String : AnyObject])
    }

    @available(watchOSApplicationExtension 3.0, *)
    public func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        
        for task : WKRefreshBackgroundTask in backgroundTasks {
            print("received background task: \(task)\n")
            // only handle these while running in the background
            if (WKExtension.shared().applicationState == .background) {
                switch task {
                    case _ as WKApplicationRefreshBackgroundTask:
                        // this task is completed below, our app will then suspend while the download session runs
                        print("WKApplicationRefreshBackgroundTask received, start URL session")
                        //let _ = NightscoutCacheService.singleton.loadCurrentNightscoutDataInBackground()
                        task.setTaskCompleted()
                    case let sessionTask as WKURLSessionRefreshBackgroundTask:
                        
                         print("WKURLSessionRefreshTaskReceived, start URL session")
                         
                        let backgroundSession = BackgroundUrlSessionWrapper.singleton
//                        let backgroundConfigObject = URLSessionConfiguration.background(withIdentifier: sessionTask.sessionIdentifier)
//                        let backgroundSession = URLSession(
//                                configuration: backgroundConfigObject,
//                                delegate: self as URLSessionDelegate,
//                                delegateQueue: nil)
                    
                        print("Rejoining session ", backgroundSession)
                        scheduleBackgroundUpdate()
                        if #available(watchOSApplicationExtension 4.0, *) {
                            sessionTask.setTaskCompletedWithSnapshot(true)
                        } else {
                            // Fallback on earlier versions
                            sessionTask.setTaskCompleted()
                        }
                    default:
                        print("Ignoring task \(task)")
                        // make sure to complete all tasks, even ones you don't handle
                        task.setTaskCompleted()
                }
            }
        }
    }
    
    @available(watchOSApplicationExtension 3.0, *)
    fileprivate func scheduleBackgroundUpdate() {
        
        print("Schedule Background Update...\n")
        
        // Schedule a new refresh task in 15 Minutes (only 50 Updates are guaranteed from watchos per day :-/
        WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: Date(timeIntervalSinceNow: 60 * 15), userInfo: nil) { (error: Error?) in
            
            if let error = error {
                print("Error occurred while scheduling background refresh: \(error.localizedDescription)")
            }
        }
    }
        
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
    
    fileprivate func updateComplication() {
        let complicationServer = CLKComplicationServer.sharedInstance()
        for complication in complicationServer.activeComplications! {
            complicationServer.reloadTimeline(for: complication)
        }
    }
}
