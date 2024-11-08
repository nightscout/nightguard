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

extension View {
    
    func widgetBackground(backgroundView: some View) -> some View {
        if #available(watchOS 10.0, *) {
            return containerBackground(for: .widget) {
                backgroundView
            }
        } else {
            return background(backgroundView)
        }
    }
    
}

@main
struct NightguardWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NightguardDefaultWidgets()
        NightguardTimestampWidgets()
        NightguardGaugeWidgets()
    }
}

struct NightguardDefaultWidgets: Widget {
    
    var provider = NightguardTimelineProvider(displayName:
          NSLocalizedString("BG Text", comment: "Text Widget Display Name"))

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "org.duckdns.dhe.nightguard.NightguardDefaultWidgets",
            provider: provider
        ) { entry in
            NightguardEntryView(entry: entry)
        }
        .configurationDisplayName(
            NSLocalizedString("BG Values as Text", comment: "Widget Configuration Display Name"))
        .description(provider.displayName)
        .supportedFamilies([
            .accessoryInline,
            .accessoryCorner,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

struct NightguardTimestampWidgets: Widget {
    
    var provider = NightguardTimelineProvider(displayName:
        NSLocalizedString("BG Text", comment: "Text Widget Timestamp Display"))

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "org.duckdns.dhe.nightguard.NightguardTimestampWidgets",
            provider: provider
        ) { entry in
            NightguardTimestampEntryView(entry: entry)
        }
        .configurationDisplayName(
            NSLocalizedString("BG with absolute Time", comment: "Widget Configuration Display Name"))
        .description(provider.displayName)
        .supportedFamilies([
            .accessoryRectangular
        ])
    }
}

struct NightguardGaugeWidgets: Widget {
    
    var provider = NightguardTimelineProvider(displayName:
            NSLocalizedString("BG Gauge", comment: "Gauge Widget Display Name"))
    
    var body: some WidgetConfiguration {
        
        StaticConfiguration(
            kind: "org.duckdns.dhe.nightguard.NightguardGaugeWidgets",
            provider: provider
        ) { entry in
            NightguardGaugeEntryView(entry: entry)
        }
        .configurationDisplayName(
            NSLocalizedString("BG Values as Gauge", comment: "Gauge Widget Configuration Display Name"))
        .description(provider.displayName)
        .supportedFamilies([
            .accessoryCorner,
            .accessoryCircular
        ])
    }
}

struct nightguard_Complication_Extension_Previews: PreviewProvider {
    
    static var previews: some View {
        NightguardEntryView(entry: NightscoutDataEntry.previewValues)
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            .previewDisplayName("Acc_Rect")
        
        NightguardEntryView(entry: NightscoutDataEntry.previewValues)
            .previewContext(WidgetPreviewContext(family: .accessoryInline))
            .previewDisplayName("Acc_Inline")
        
        NightguardEntryView(entry: NightscoutDataEntry.previewValues)
            .previewContext(WidgetPreviewContext(family: .accessoryCorner))
            .previewDisplayName("Acc_Corner")
        
        NightguardEntryView(entry: NightscoutDataEntry.previewValues)
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Acc_Circ")
        
        NightguardGaugeEntryView(entry: NightscoutDataEntry.previewValues)
            .previewContext(WidgetPreviewContext(family: .accessoryCorner))
            .previewDisplayName("Gauge_Acc_Corner")
        
        NightguardGaugeEntryView(entry: NightscoutDataEntry.previewValues)
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Gauge_Acc_Circ")
    }
}

struct NightguardEntryView : View {
    
    @Environment(\.widgetFamily) var widgetFamily
    var entry: NightscoutDataEntry
    
    var body: some View {
        switch widgetFamily {
            case .accessoryCorner:
                AccessoryCornerView(entry: entry)
                .widgetBackground(backgroundView: background())
            case .accessoryCircular:
                AccessoryCircularView(entry: entry)
                .widgetBackground(backgroundView: background())
            case .accessoryInline:
                AccessoryInlineView(entry: entry)
            case .accessoryRectangular:
                AccessoryRectangularView(entry: entry)
                .widgetBackground(backgroundView: background())
            @unknown default:
                //mandatory as there are more widget families as in lockscreen widgets etc
                Text(NSLocalizedString("Not an implemented widget yet", comment: "Gauge Widget Not Implemented Error Message"))
        }
    }
}

struct NightguardTimestampEntryView : View {
    
    @Environment(\.widgetFamily) var widgetFamily
    var entry: NightscoutDataEntry
    
    var body: some View {
        switch widgetFamily {
            case .accessoryRectangular:
            AccessoryRectangularTimestampView(entry: entry)
                .widgetBackground(backgroundView: background())
        case .accessoryCorner, .accessoryCircular, .accessoryInline:
            //mandatory as there are more widget families as in lockscreen widgets etc
            Text(NSLocalizedString("Not an implemented widget yet", comment: "Timestmap Widget Not Implemented Error Message"))
        @unknown default:
                //mandatory as there are more widget families as in lockscreen widgets etc
                Text(NSLocalizedString("Not an implemented widget yet", comment: "Timestmap Widget Not Implemented Error Message"))
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
                .widgetBackground(backgroundView: background())
            case .accessoryCircular:
                AccessoryCircularGaugeView(entry: entry)
                .widgetBackground(backgroundView: background())
            default:
                //mandatory as there are more widget families as in lockscreen widgets etc
                Text(NSLocalizedString("No Gauge Support for this widget!", comment: "Gauge Widget Not Supported Error Message"))
        }
    }
}

//struct NightguardGaugePreviews: PreviewProvider {
//    static var previews: some View {
//        
//        NightguardEntryView(entry: NightscoutDataEntry.previewValues)
//            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
//        
//        NightguardEntryView(entry: NightscoutDataEntry.previewValues)
//            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
//        
//        NightguardEntryView(entry: NightscoutDataEntry.previewValues)
//            .previewContext(WidgetPreviewContext(family: .accessoryCorner))
//        
//        NightguardEntryView(entry: NightscoutDataEntry.previewValues)
//            .previewContext(WidgetPreviewContext(family: .accessoryInline))
//    }
//}
