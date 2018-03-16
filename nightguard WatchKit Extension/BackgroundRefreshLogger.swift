//
//  BackgroundRefreshLogger.swift
//  nightguard WatchKit Extension
//
//  Created by Florian Preknya on 3/16/18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation

class BackgroundRefreshLogger {
    
    static var logs: [String] = []
    
    // keep some background refrehs related stats data...
    static var backgroundURLSessions: Int = 0
    static var backgroundURLSessionUpdatesWithNewData: Int = 0
    static var backgroundURLSessionUpdatesWithSameData: Int = 0
    static var backgroundURLSessionUpdatesWithOldData: Int = 0
    static var phoneUpdates: Int = 0
    static var phoneUpdatesWithNewData: Int = 0
    static var phoneUpdatesWithSameData: Int = 0
    static var phoneUpdatesWithOldData: Int = 0
    
    static func info(_ text: String) {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let dateString = timeFormatter.string(from: Date())
        
        logs.append(dateString + " " + text)
    }
}
