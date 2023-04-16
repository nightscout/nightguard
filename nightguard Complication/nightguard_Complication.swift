//
//  nightguard_Complication_Extension.swift
//  nightguard Complication Extension
//
//  Created by Dirk Hermanns on 02.04.23.
//  Copyright © 2023 private. All rights reserved.
//

import WidgetKit
import SwiftUI
import Intents

@main
struct NightguardWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NightguardDefaultWidgets()
        NightguardGaugeWidgets()
    }
}

struct NightguardDefaultWidgets: Widget {
    
    var provider = NightguardTimelineProvider(displayName: "BG Text")

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "org.duckdns.dhe.nightguard.NightguardDefaultWidgets",
            provider: provider
        ) { entry in
            NightguardEntryView(entry: entry)
        }
        .configurationDisplayName("BG Values as Text")
        .description(provider.displayName)
        .supportedFamilies([
            .accessoryInline,
            .accessoryCorner,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

struct NightguardGaugeWidgets: Widget {
    
    var provider = NightguardTimelineProvider(displayName: "BG Gauge")
    
    var body: some WidgetConfiguration {
        
        StaticConfiguration(
            kind: "org.duckdns.dhe.nightguard.NightguardGaugeWidgets",
            provider: provider
        ) { entry in
            NightguardGaugeEntryView(entry: entry)
        }
        .configurationDisplayName("BG Values as Gauge")
        .description(provider.displayName)
        .supportedFamilies([
            .accessoryCorner,
            .accessoryCircular
        ])
    }
}

struct nightguard_Complication_Extension_Previews: PreviewProvider {
    static var previews: some View {
        NightguardEntryView(entry: NightscoutDataEntry(date: Date(), configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
        
        NightguardEntryView(entry: NightscoutDataEntry(date: Date(), configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .accessoryInline))
        
        NightguardEntryView(entry: NightscoutDataEntry(date: Date(), configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .accessoryCorner))
        
        NightguardEntryView(entry: NightscoutDataEntry(date: Date(), configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
        
        NightguardGaugeEntryView(entry: NightscoutDataEntry(date: Date(), configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .accessoryCorner))
        
        NightguardGaugeEntryView(entry: NightscoutDataEntry(date: Date(), configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
    }
}

struct NightguardEntryView : View {
    
    @Environment(\.widgetFamily) var widgetFamily
    var entry: NightscoutDataEntry

    var body: some View {
        switch widgetFamily {
            case .accessoryCorner:
                AccessoryCornerView(entry: entry)
            case .accessoryCircular:
                AccessoryCircularView(entry: entry)
            case .accessoryInline:
                AccessoryInlineView(entry: entry)
            case .accessoryRectangular:
                AccessoryRectangularView(entry: entry)
            @unknown default:
                //mandatory as there are more widget families as in lockscreen widgets etc
                Text("Not an implemented widget yet")
        }
    }
}

struct NightguardGaugeEntryView : View {
    
    @Environment(\.widgetFamily) var widgetFamily
    var entry: NightscoutDataEntry

    var body: some View {
        switch widgetFamily {
            case .accessoryCorner:
                AccessoryCornerGaugeView(entry: entry)
            case .accessoryCircular:
                AccessoryCircularGaugeView(entry: entry)
            default:
                //mandatory as there are more widget families as in lockscreen widgets etc
                Text("No Gauge Support for this widget!")
        }
    }
}

struct NightguardGaugePreviews: PreviewProvider {
    static var previews: some View {
        
        NightguardEntryView(entry: NightscoutDataEntry(date: Date(), sgv: "100", configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
        
        NightguardEntryView(entry: NightscoutDataEntry(date: Date(), sgv: "100", configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
        
        NightguardEntryView(entry: NightscoutDataEntry(date: Date(), sgv: "100", configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .accessoryCorner))
        
        NightguardEntryView(entry: NightscoutDataEntry(date: Date(), sgv: "100", configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .accessoryInline))
    }
}
