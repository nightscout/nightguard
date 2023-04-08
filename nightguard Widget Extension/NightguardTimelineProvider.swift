//
//  NightguardTimelineProvider.swift
//  nightguard
//
//  Created by Dirk Hermanns on 02.04.23.
//  Copyright © 2023 private. All rights reserved.
//

import Foundation
import WidgetKit

struct NightguardTimelineProvider: IntentTimelineProvider {
    
    func recommendations() -> [IntentRecommendation<ConfigurationIntent>] {
        return [
            IntentRecommendation(intent: ConfigurationIntent(), description: "BG Values")
        ]
    }
    
    func placeholder(in context: Context) -> NightscoutDataEntry {
        
        NightscoutDataEntry(configuration: ConfigurationIntent())
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (NightscoutDataEntry) -> ()) {
        
        completion(getTimelineData(configuration: configuration))
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<NightscoutDataEntry>) -> ()) {
        
        var entries: [NightscoutDataEntry] = []

        entries.append(getTimelineData(configuration: configuration))
        
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    private func getTimelineData(configuration: ConfigurationIntent) -> NightscoutDataEntry {
        
        let data = NightscoutDataRepository.singleton.loadCurrentNightscoutData()
        
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
            configuration: configuration)
        
        return entry
    }
}
