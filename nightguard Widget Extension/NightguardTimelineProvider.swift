//
//  NightguardTimelineProvider.swift
//  nightguard
//
//  Created by Dirk Hermanns on 02.04.23.
//  Copyright © 2023 private. All rights reserved.
//

import Foundation
import WidgetKit

struct NightguardTimelineProvider: TimelineProvider {
    
    func getSnapshot(in context: Context, completion: @escaping (NightscoutDataEntry) -> Void) {
        
        completion(getTimelineData())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<NightscoutDataEntry>) -> Void) {
        
        var entries: [NightscoutDataEntry] = []

        entries.append(getTimelineData())
        
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
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

    /*func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (NightscoutDataEntry) -> ()) {
        
        completion(getTimelineData(configuration: configuration))
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<NightscoutDataEntry>) -> ()) {
        
        var entries: [NightscoutDataEntry] = []

        entries.append(getTimelineData())
        
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }*/
    
    private func getTimelineData() -> NightscoutDataEntry {
        
        let data = NightscoutDataRepository.singleton.loadCurrentNightscoutData()
        let bloodSugarValues = NightscoutCacheService.singleton.loadTodaysData {_ in }
        
        let bgEntries = bloodSugarValues.map() {bgValue in
            return BgEntry(value: bgValue.value, delta: 0, timestamp: bgValue.timestamp)
        }
        var reducedEntries = bgEntries
        if bgEntries.count > 3 {
            reducedEntries = []
            for i in bgEntries.count-4..<bgEntries.count {
                reducedEntries.append(bgEntries[i])
            }
        }
        
        let reducedEntriesWithDelta = calculateDeltaValues(reducedEntries.reversed())
        
        let entry = NightscoutDataEntry(
            date: Date(timeIntervalSince1970: data.time.doubleValue / 1000),
            sgv: data.sgv,
            bgdeltaString: data.bgdeltaString,
            bgdeltaArrow: data.bgdeltaArrow,
            bgdelta: data.bgdelta,
            time: data.time,
            battery: data.battery,
            iob: data.iob,
            cob: data.cob,
            lastBGValues: reducedEntriesWithDelta,
            configuration: ConfigurationIntent())
        
        return entry
    }
    
    private func calculateDeltaValues(_ reducedEntries: [BgEntry]) -> [BgEntry] {
        
        var preceedingEntry: BgEntry?
        var newEntries: [BgEntry] = []
        for bgEntry in reducedEntries {
            if preceedingEntry?.value != nil {
                let newEntry = BgEntry(
                    value: bgEntry.value,
                    delta: bgEntry.value - (preceedingEntry?.value ?? bgEntry.value),
                    timestamp: bgEntry.timestamp)
                newEntries.append(newEntry)
            }
            preceedingEntry = bgEntry
        }
        
        return newEntries
    }
}
