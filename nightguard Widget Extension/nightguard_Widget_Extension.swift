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

struct nightguard_Widget_ExtensionEntryView : View {
    
    @Environment(\.widgetFamily)
    var widgetFamily
    var entry: NightscoutDataEntry

    var body: some View {
        
        switch widgetFamily {
            case .accessoryInline:
                AccessoryInlineView(entry: entry)
            case .accessoryRectangular:
                AccessoryRectangularView(entry: entry)
            case .accessoryCircular:
                VStack {
                    Text(Date(timeIntervalSince1970: entry.time.doubleValue / 1000).toLocalTimeString())
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
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: NightguardTimelineProvider()) { entry in
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
