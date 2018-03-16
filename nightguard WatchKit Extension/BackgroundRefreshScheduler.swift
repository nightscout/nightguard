//
//  BackgroundRefreshScheduler.swift
//  nightguard WatchKit Extension
//
//  Created by Florian Preknya on 3/16/18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation
import WatchKit

/// This class is responsible with scheduling the next refreshes (background and snapshot). It will trigger a
/// background (or snapshot) refresh as configured by the refreshRate property, the exact refresh moment will
/// be determined by dividing the hour in periods (starting from 0 minutes -> 60 minutes), the most apropiate
/// period start will be the next scheduled value.
///
/// For example, if the refresh rate is 4 (4 refreshes per hour, the refresh period is 15 minutes), the
/// scheduled times will be xx:00, xx:15, xx:30 and xx:45. If calling schedule() at xx:18, the next refresh
/// will be scheduled at xx:30. NOTE that watchOS can delay (or even skip!) calling the WKExtensionDelegate.handle(_) method on scheduled time (the delay can be from seconds to some minutes).
@available(watchOSApplicationExtension 3.0, *)
class BackgroundRefreshScheduler {
    
    static let instance = BackgroundRefreshScheduler()
    
    // number of refreshes per hour (for e.g, if refreshRate = 6, it will trigger a refresh every 10 minute)
    var refreshRate: Int = 12 // every 5 minutes by default (even if the watchOS will not do it that often...)
    
    // alternate background refreshes with snapshot refreshes
    var alternateSnaphotRefreshes = true
    
    var lastScheduledWasSnapshotRefresh = false
    private var lastScheduledTime: Date?
    
    private init() {
    }
    
    func schedule() {
        
        // obtain base refresh time
        let scheduleTime = nextScheduleTime(refreshRate: self.refreshRate)
        
        // if the background refresh alternates with the snapshot refresh, the second schedule time will be the current schedule time delayed with a period (5 more minutes if the period is 5 minutes); if using only background refreshes, then still schedule snapshot refreshes every 15 minutes... just for triggering another schedule for the background refreshes (because some background refreshes can be skipped and the refresh scheduling will not be called anymore!)
        let refreshPeriod = 60 / refreshRate
        let secondScheduleTime = alternateSnaphotRefreshes ? Calendar.current.date(byAdding: .minute, value: refreshPeriod, to: scheduleTime)! : nextScheduleTime(refreshRate: 4)
        
        // log ONLY once
        let logRefreshTime = self.lastScheduledTime != scheduleTime
        self.lastScheduledTime = scheduleTime
        
        var backgroundRefreshTime = scheduleTime
        var snapshotRefreshTime = secondScheduleTime
        if alternateSnaphotRefreshes && !lastScheduledWasSnapshotRefresh {
            swap(&backgroundRefreshTime, &snapshotRefreshTime)
        }
        
        WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: backgroundRefreshTime, userInfo: nil) { (error: Error?) in
            
            if logRefreshTime {
                BackgroundRefreshLogger.info("Scheduled next background refresh at \(self.formatted(scheduleTime: backgroundRefreshTime))")
            }
            
            if let error = error {
                BackgroundRefreshLogger.info("Error occurred while scheduling background refresh: \(error.localizedDescription)")
            }
        }
        
        WKExtension.shared().scheduleSnapshotRefresh(withPreferredDate: snapshotRefreshTime, userInfo: nil) { (error: Error?) in
            
            if logRefreshTime {
                BackgroundRefreshLogger.info("Scheduled next snapshot refresh at \(self.formatted(scheduleTime: snapshotRefreshTime))")
            }
            
            if let error = error {
                BackgroundRefreshLogger.info("Error occurred while scheduling snapshot refresh: \(error.localizedDescription)")
            }
        }
    }
    
    private func nextScheduleTime(refreshRate: Int) -> Date {
        
        let now = Date()
        let unitFlags:Set<Calendar.Component> = [
            .hour, .day, .month,
            .year,.minute,.hour,.second,
            .calendar]
        var dateComponents = Calendar.current.dateComponents(unitFlags, from: now)
        
        // reset second
        dateComponents.second = 0
        
        let refreshPeriod = 60 / refreshRate
        
        let nextRefreshMinute = ((dateComponents.minute! / refreshPeriod) + 1) * refreshPeriod
        dateComponents.minute = nextRefreshMinute % 60
        
        var scheduleTime = Calendar.current.date(from: dateComponents)!
        if nextRefreshMinute >= 60 {
            scheduleTime = Calendar.current.date(byAdding: .hour, value: 1, to: scheduleTime)!
        }
        
        return scheduleTime
    }
    
    private func formatted(scheduleTime: Date) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        return timeFormatter.string(from: scheduleTime)
    }
}
