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
                session.activateSession()
            }
        }
    }
    
    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
        activateWatchConnectivity()
    }

    func activateWatchConnectivity() {
        if WCSession.isSupported() {
            session = WCSession.defaultSession()
        }
    }
    
    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
    }
    
    func initializeApplicationDefaults() {
        
        // Setting the defaults if the users starts the application for the first time
        let initialDefaults: NSDictionary = ["maximumBloodGlucoseDisplayed": 250]
        NSUserDefaults.standardUserDefaults().registerDefaults(initialDefaults as! [String : AnyObject])
    }
}
