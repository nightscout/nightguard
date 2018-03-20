//
//  BackgroundRefreshLogger.swift
//  nightguard WatchKit Extension
//
//  Created by Florian Preknya on 3/16/18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation

// A debugging tool that keeps info about the nightscout data updates obtained through background tasks (URL sessions) or updates received from the phone app (that also relies on background fetch for refreshing its data).
class BackgroundRefreshLogger {
    
    static var logs: [String] = []
    static var receivedData: [String] = []
    
    // keep some background refrehs related stats data...
    static var backgroundRefreshes: Int = 0
    static var backgroundURLSessions: Int = 0
    static var backgroundURLSessionUpdatesWithNewData: Int = 0
    static var backgroundURLSessionUpdatesWithSameData: Int = 0
    static var backgroundURLSessionUpdatesWithOldData: Int = 0
    static var phoneUpdates: Int = 0
    static var phoneUpdatesWithNewData: Int = 0
    static var phoneUpdatesWithSameData: Int = 0
    static var phoneUpdatesWithOldData: Int = 0
    
    static var backgroundRefreshesPerHour: Double {
        guard let logStartTime = BackgroundRefreshLogger.logStartTime else {
            return 0
        }
        
        let minutes: Double = Date().timeIntervalSince(logStartTime) / 60
        let refreshesPerMinute = Double(backgroundRefreshes) / minutes
        return refreshesPerMinute * 60
    }
    
    static var formattedBackgroundRefreshesPerHour: String {
        return String(format: "%.2f", backgroundRefreshesPerHour)
    }
    
    static var backgroundRefreshesStartingURLSessions: Double {
        return backgroundRefreshes != 0 ? Double(backgroundURLSessions) / Double(backgroundRefreshes) : 0
    }
    
    static var formattedBackgroundRefreshesStartingURLSessions: String {
        return "\(Int(backgroundRefreshesStartingURLSessions * 100))%"
    }
    
    private static var logStartTime: Date?
    private static let showLogs = (Bundle.main.infoDictionary?["ShowLogsFromBackgroundRefreshTasks"] as? Bool) ?? false
    
    static func info(_ text: String) {
        resetStatsDataIfNeeded()
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let dateString = timeFormatter.string(from: Date())
        let logEntry = dateString + " " + text
        NSLog(logEntry)
        
        if showLogs {
            logs.append(logEntry)
        }
    }
    
    
    static func nightscoutDataReceived(_ nightscoutData: NightscoutData, updateResult: ExtensionDelegate.UpdateResult, updateSource: ExtensionDelegate.UpdateSource) {
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let dateString = timeFormatter.string(from: Date())
        
        var updateSourceString = ""
        switch updateSource {
        case .phoneApp :
            updateSourceString = "📱"
        default:
            updateSourceString = "⌚"
        }
        
        var updateResultString = ""
        switch updateResult {
        case .updated:
            updateResultString = "NEW"
        case .updateDataAlreadyExists:
            updateResultString = "EXISTING"
        case .updateDataIsOld:
            updateResultString = "OLD"
        }
        
        let nightscoutDataTime = Date(timeIntervalSince1970: nightscoutData.time.doubleValue / 1000)
        timeFormatter.dateFormat = "HH:mm"
        let nightscoutDataTimeString = timeFormatter.string(from: nightscoutDataTime)
        
        let logEntry = dateString + " " + updateSourceString + updateResultString + " (\(nightscoutData.sgv)@\(nightscoutDataTimeString))"
        NSLog(logEntry)
        
        if showLogs {
            receivedData.append(logEntry)
        }
        
    }
    
    private static func resetStatsDataIfNeeded() {
        
        guard let logStartTime = BackgroundRefreshLogger.logStartTime else {
            BackgroundRefreshLogger.logStartTime = Date()
            return
        }
        
        let now = Date()
        let unitFlags:Set<Calendar.Component> = [.day]
        let nowDateComponents = Calendar.current.dateComponents(unitFlags, from: logStartTime)
        let logStartDateComponents = Calendar.current.dateComponents(unitFlags, from: now)

        // keep log data only for one day (from 00:00 until 23:59)
        if logStartDateComponents.day != nowDateComponents.day {
            
            // reset log data
            logs.removeAll()
            receivedData.removeAll()
            
            backgroundRefreshes = 0
            backgroundURLSessions = 0
            backgroundURLSessionUpdatesWithNewData = 0
            backgroundURLSessionUpdatesWithSameData = 0
            backgroundURLSessionUpdatesWithOldData = 0
            phoneUpdates = 0
            phoneUpdatesWithNewData = 0
            phoneUpdatesWithSameData = 0
            phoneUpdatesWithOldData = 0
        }
    }
}
