//
//  nightguard_Widget_Extension.swift
//  nightguard Widget Extension
//
//  Created by Dirk Hermanns on 14.09.22.
//  Copyright © 2022 private. All rights reserved.
//

import WidgetKit
import SwiftUI
import Intents

struct Provider: IntentTimelineProvider {
    
    func placeholder(in context: Context) -> NightscoutDataEntry {
        
        NightscoutDataEntry(configuration: ConfigurationIntent())
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (NightscoutDataEntry) -> ()) {
        
        completion(getTimelineData(configuration: configuration))
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        
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

struct NightscoutDataEntry: TimelineEntry {
    
    var date: Date = Date()
    
    var sgv : String = "---"
    // the delta Value in Display Units
    var bgdeltaString : String = "---"
    var bgdeltaArrow : String = "-"
    // the delta value in mgdl
    var bgdelta : Float = 0.0
    var hourAndMinutes : String {
        get {
            if time == 0 {
                return "??:??"
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            
            let date = Date.init(timeIntervalSince1970: Double(time.int64Value / 1000))
            return formatter.string(from: date)
        }
    }
    var timeString : String {
        get {
            if time == 0 {
                return "-min"
            }
            
            // trick: when displaying the time, we'll add 30 seconds to current time for showing the difference like Nightscout does (0-30 seconds: "0 mins", 31-90 seconds: "1 min", ...)
            let thirtySeconds = Int64(30 * 1000)
            
            // calculate how old the current data is
            let currentTime = Int64(Date().timeIntervalSince1970 * 1000) + thirtySeconds
            let difference = (currentTime - time.int64Value) / 60000
            if difference > 59 {
                return ">1Hr"
            }
            return String(difference) + "min"
        }
    }
    var time : NSNumber = 0
    var battery : String = "---"
    var iob : String = ""
    var cob : String = ""
    let configuration: ConfigurationIntent
}

struct nightguard_Widget_ExtensionEntryView : View {
    
    @Environment(\.widgetFamily)
    var widgetFamily
    var entry: Provider.Entry

    var body: some View {
        
        switch widgetFamily {
            case .accessoryInline:
            Text("| \(entry.hourAndMinutes) \(UnitsConverter.mgdlToDisplayUnits(entry.sgv))\(UnitsConverter.mgdlToDisplayUnits(entry.bgdeltaString))\(entry.bgdeltaArrow)")
            case .accessoryRectangular:
                VStack(alignment: .leading) {
                        Text(Date(timeIntervalSince1970: entry.time.doubleValue / 1000), style: .relative)
                        Text("\(UnitsConverter.mgdlToDisplayUnits(entry.sgv))\(UnitsConverter.mgdlToDisplayUnits(entry.bgdeltaString))\(entry.bgdeltaArrow)")
                        Text("\(entry.cob) \(entry.iob)")
                }
            case .accessoryCircular:
                VStack {
                    Text(entry.hourAndMinutes)
                    Text("\(UnitsConverter.mgdlToDisplayUnits(entry.sgv))\(UnitsConverter.mgdlToDisplayUnits(entry.bgdeltaString))")
                    Text("\(entry.bgdeltaArrow)")
                }
                
            default:
                Text("Not implemented.")
        }
    }
}

@main
struct nightguard_Widget_Extension: Widget {
    let kind: String = "nightguard_Widget_Extension"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            nightguard_Widget_ExtensionEntryView(entry: entry)
        }
        .configurationDisplayName("nightguard widgets")
        .description("Nightguard lockscreen widgets.")
        .supportedFamilies(
            [.accessoryInline,
             .accessoryCircular,
             .accessoryRectangular])
    }
}

struct nightguard_Widget_Extension_Previews: PreviewProvider {
    static var previews: some View {
        
        nightguard_Widget_ExtensionEntryView(entry: NightscoutDataEntry(date: Date(), configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .accessoryInline))
            .previewDisplayName("Inline")
        
        nightguard_Widget_ExtensionEntryView(entry: NightscoutDataEntry(date: Date(), configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Circular")
        
        nightguard_Widget_ExtensionEntryView(entry: NightscoutDataEntry(date: Date(), configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            .previewDisplayName("Rectangular")
    }
}
