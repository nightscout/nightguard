//
//  BackgroundRefreshSettings.swift
//  nightguard WatchKit Extension
//
//  Created by Florian Preknya on 3/22/18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation

/// All the configurable aspects related to background updates.
class BackgroundRefreshSettings {
    
    // enable background tasks in watch app that will schedule the URL sessions for requesting new nightscout data (used in watch app)
    static let enableBackgroundTasks: Bool = true
    
    // the background tasks scheduling rate (period between two schedules) (used in watch app)
    // NOTE that the current implementation (BackgroundRefreshScheduler class) will schedule background tasks at fixed moments taking as reference the current hour timeframe (for eg, if the refresh rate is 15 minutes, the scheduled times will be xx:00, xx:15, xx:30 and xx:45). Check BackgroundRefreshScheduler implementation for more info.
    static let backgroundTaskScheduleRate: Int = 15 /* minutes */
    
    // enable watch app updates from phone app when receives new nightscout data (used in phone app)
    static let enableWatchUpdate: Bool = true
    
    // watch app update frequency, initiated by phone app when receives new nightscout data (used in phone app)
    static let watchUpdateRate: Int = 5 /* minutes */
    
    // enable watch complication updates from phone app when receives new nightscout data (used in phone app)
    // NOTE: complication update is not really needed anymore if using regular watch updates (because both updates will arrive at same time, providing the same nightscout data - consuming only the watch app's background quota...)
    static let enableWatchComplicationUpdate: Bool = false

    // watch complication update frequency, initiated by phone app when receives new nightscout data (used in phone app)
    static let watchComplicationUpdateRate: Int = 30 /* minutes - (50 complication update per day guaranteed by Apple...)*/
    

    // enable/disable show of logs in the watch app Info screen, usefull for debugging background activity (used in watch app)
    static let showBackgroundTasksLogs: Bool = true
}
