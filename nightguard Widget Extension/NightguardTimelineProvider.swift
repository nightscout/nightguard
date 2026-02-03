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
        let oldData = NightscoutDataRepository.singleton.loadCurrentNightscoutData()
        let oldEntries = NightscoutDataRepository.singleton.loadTodaysBgData()
        
        NightscoutService.singleton.readTodaysChartData(oldValues: []) { (result: NightscoutRequestResult<[BloodSugar]>) in
            
            BackgroundRefreshLogger.info("TimelineProvider received new nightscout data...")
            var bgEntries : [BgEntry]
            var errorMessage = ""
            if case .data(let bloodSugarValues) = result {
                NightscoutDataRepository.singleton.storeTodaysBgData(bloodSugarValues)
                bgEntries = bloodSugarValues.map() {bgValue in
                    return BgEntry(
                        value: UnitsConverter.mgdlToDisplayUnits(String(bgValue.value)),
                        valueColor: UIColorChanger.getBgColor(String(bgValue.value)),
                        delta: "0", timestamp: bgValue.timestamp, arrow: bgValue.arrow)
                }
            } else if case .error(let error) = result {
                bgEntries = oldEntries.map() {bgValue in
                    return BgEntry(
                        value: UnitsConverter.mgdlToDisplayUnits(String(bgValue.value)),
                        valueColor: UIColorChanger.getBgColor(String(bgValue.value)),
                        delta: "0", timestamp: bgValue.timestamp, arrow: bgValue.arrow)
                }
                errorMessage = error.localizedDescription
            } else {
                // use old values if no new could be retrieved
                bgEntries = oldEntries.map() {bgValue in
                    return BgEntry(
                        value: UnitsConverter.mgdlToDisplayUnits(String(bgValue.value)),
                        valueColor: UIColorChanger.getBgColor(String(bgValue.value)),
                        delta: "0", timestamp: bgValue.timestamp, arrow: bgValue.arrow)
                }
            }
            
            var reducedEntries = bgEntries
            if bgEntries.count > 3 {
                reducedEntries = []
                for i in bgEntries.count-4..<bgEntries.count {
                    reducedEntries.append(bgEntries[i])
                }
            }
            
            // if no new values could be retrieved -> the old ones will be returned.
            let reducedEntriesWithDelta = calculateDeltaValues(reducedEntries)
            let updatedData = updateDataWith(reducedEntriesWithDelta, oldData)
            let entry = convertToTimelineEntry(updatedData, reducedEntriesWithDelta, errorMessage)
            
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
        if reducedEntries.isEmpty {
            return data
        }
        
        let updatedNightscoutData = NightscoutData()
        updatedNightscoutData.sgv = UnitsConverter.displayValueToMgdlString(reducedEntries.last?.value ?? "?")
        updatedNightscoutData.bgdeltaString = UnitsConverter.displayValueToMgdlString(reducedEntries.last?.delta ?? "?")
        updatedNightscoutData.time = NSNumber(value: (reducedEntries.last?.timestamp ?? 0) * 1000)
        
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
            lastBGValues: bgValues.reversed(),
            errorMessage: errorMessage,
            configuration: ConfigurationIntent())
    }

    private func calculateDeltaValues(_ reducedEntries: [BgEntry]) -> [BgEntry] {
        
        var preceedingEntry: BgEntry?
        var newEntries: [BgEntry] = []
        for bgEntry in reducedEntries {
            if preceedingEntry?.value != nil {
                let v1AsFloat: Float = Float(bgEntry.value) ?? Float.zero
                let v2AsFloat: Float = Float(preceedingEntry?.value ?? bgEntry.value) ?? v1AsFloat
                let newEntry = BgEntry(
                    value: bgEntry.value,
                    valueColor: UIColorChanger.getBgColor(bgEntry.value),
                    delta: Float(v1AsFloat - v2AsFloat).cleanSignedValue,
                    timestamp: bgEntry.timestamp, arrow: bgEntry.arrow)
                newEntries.append(newEntry)
            }
            preceedingEntry = bgEntry
        }
        
        return newEntries
    }
}
