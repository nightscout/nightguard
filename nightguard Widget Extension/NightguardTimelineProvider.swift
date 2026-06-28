//
//  NightguardTimelineProvider.swift
//  nightguard
//
//  Created by Dirk Hermanns on 02.04.23.
//  Copyright © 2023 private. All rights reserved.
//

import Foundation
import WidgetKit
import UserNotifications
import SwiftUI

struct NightguardTimelineProvider: TimelineProvider {
    
    func getSnapshot(in context: Context, completion: @escaping (NightscoutDataEntry) -> Void) {
        
        if context.isPreview {
            completion(NightscoutDataEntry.previewValues)
            return
        }
        
        Task {
            getTimelineData { nightscoutDataEntry in
                completion(nightscoutDataEntry)
            }
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<NightscoutDataEntry>) -> Void) {
        
        Task {
            getTimelineData { nightscoutDataEntry in
                
                var entries: [NightscoutDataEntry] = []
                entries.append(nightscoutDataEntry)
                // ask for a refresh after 10 Minutes:
                completion(Timeline(entries: entries, policy:
                        .after(Calendar.current.date(byAdding: .minute, value: 10, to: Date()) ?? Date())))
            }
        }
    }
    
    
    var displayName: String = ""
    
    public init(displayName: String) {
        self.displayName = displayName
    }
    
    func recommendations() -> [IntentRecommendation<ConfigurationIntent>] {
        return [
            IntentRecommendation(intent: ConfigurationIntent(), description: displayName)
        ]
    }
    
    func placeholder(in context: Context) -> NightscoutDataEntry {
        
        NightscoutDataEntry(configuration: ConfigurationIntent())
    }
    
    private func getTimelineData(completion: @escaping (NightscoutDataEntry) -> Void) {
        
        BackgroundRefreshLogger.info("TimelineProvider is getting Timeline...")
        if let snapshot = NightscoutDataRepository.singleton.loadLatestDisplaySnapshot(),
           snapshot.isFresh() {
            BackgroundRefreshLogger.info("TimelineProvider is using latest display snapshot...")
            completion(NightscoutDataEntry(snapshot: snapshot))
            return
        }

        let oldData = NightscoutDataRepository.singleton.loadCurrentNightscoutData()
        let oldEntries = NightscoutDataRepository.singleton.loadTodaysBgData()

        if !oldData.isOlderThanXMinutes(15), !oldEntries.isEmpty {
            BackgroundRefreshLogger.info("TimelineProvider is using recently fetched app-group data...")
            let bgEntries = makeBgEntries(from: NightguardDisplaySnapshot.makeLastBGValues(from: oldEntries))
            completion(convertToTimelineEntry(oldData, bgEntries, ""))
            return
        }
        
        NightscoutService.singleton.readTodaysChartData(oldValues: []) { (result: NightscoutRequestResult<[BloodSugar]>) in
            
            BackgroundRefreshLogger.info("TimelineProvider received new nightscout data...")
            var bgEntries : [BgEntry]
            var errorMessage = ""
            if case .data(let bloodSugarValues) = result {
                NightscoutDataRepository.singleton.storeTodaysBgData(bloodSugarValues)
                bgEntries = makeBgEntries(from: NightguardDisplaySnapshot.makeLastBGValues(from: bloodSugarValues))
            } else if case .error(let error) = result {
                bgEntries = makeBgEntries(from: NightguardDisplaySnapshot.makeLastBGValues(from: oldEntries))
                errorMessage = error.localizedDescription
            } else {
                // use old values if no new could be retrieved
                bgEntries = makeBgEntries(from: NightguardDisplaySnapshot.makeLastBGValues(from: oldEntries))
            }
            
            // if no new values could be retrieved -> the old ones will be returned.
            let updatedData = updateDataWith(bgEntries, oldData)
            let entry = convertToTimelineEntry(updatedData, bgEntries, errorMessage)
            
            BackgroundRefreshLogger.info("TimelineProvider refreshed widgets...")
            // Notifications can be send from iOS only, so don't waste time for this in watchos:
            #if os(iOS)
            AlarmNotificationService.singleton.notifyIfAlarmActivated(updatedData)
            #endif
            
            completion(entry)
        }
    }
    
    private func updateDataWith(_ reducedEntries : [BgEntry], _ data: NightscoutData) -> NightscoutData{
        // use the more recent retrieved bgEntries (if available):
        guard let latestEntry = reducedEntries.first else {
            return data
        }
        
        let updatedNightscoutData = NightscoutData()
        updatedNightscoutData.sgv = UnitsConverter.displayValueToMgdlString(latestEntry.value)
        updatedNightscoutData.bgdeltaString = UnitsConverter.displayValueToMgdlString(latestEntry.delta)
        updatedNightscoutData.time = NSNumber(value: latestEntry.timestamp)
        
        return updatedNightscoutData
    }
    
    private func convertToTimelineEntry(_ data: NightscoutData, _ bgValues: [BgEntry], _ errorMessage: String) -> NightscoutDataEntry {
        
        return NightscoutDataEntry(
            date: Date(timeIntervalSince1970: data.time.doubleValue / 1000),
            sgv: UnitsConverter.mgdlToDisplayUnits(data.sgv),
            sgvColor: UIColorChanger.getBgColor(data.sgv),
            bgdeltaString: UnitsConverter.mgdlToDisplayUnitsWithSign(data.bgdeltaString),
            bgdeltaColor: UIColorChanger.getDeltaLabelColor(data.bgdelta),
            bgdeltaArrow: data.bgdeltaArrow,
            bgdelta: data.bgdelta,
            time: data.time,
            battery: data.battery,
            iob: data.iob,
            cob: data.cob,
            snoozedUntilTimestamp: 
                AlarmRule.snoozedUntilTimestamp.value,
            lastBGValues: bgValues,
            errorMessage: errorMessage,
            configuration: ConfigurationIntent())
    }

    private func makeBgEntries(from snapshotValues: [NightguardDisplaySnapshot.BgValue]) -> [BgEntry] {
        snapshotValues.map { bgValue in
            BgEntry(
                value: bgValue.value,
                valueColor: UIColor(
                    red: CGFloat(bgValue.valueColorRed),
                    green: CGFloat(bgValue.valueColorGreen),
                    blue: CGFloat(bgValue.valueColorBlue),
                    alpha: 1
                ),
                delta: bgValue.delta,
                timestamp: bgValue.timestamp,
                arrow: bgValue.arrow
            )
        }
    }
}
