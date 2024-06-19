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

extension View {
    
    func widgetBackground(backgroundView: some View) -> some View {
        if #available(iOS 17.0, *) {
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
            .systemSmall,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular,
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
            .accessoryCircular
        ])
    }
}

struct NightguardEntryView : View {
    
    @Environment(\.widgetFamily) var widgetFamily
    var entry: NightscoutDataEntry

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SystemSmallView(entry: entry)
            .widgetBackground(backgroundView: Color.black)
            case .accessoryCircular:
                AccessoryCircularView(entry: entry)
                .widgetBackground(backgroundView: background())
            case .accessoryInline:
                AccessoryInlineView(entry: entry)
            case .accessoryRectangular:
                AccessoryRectangularView(entry: entry)
                .widgetBackground(backgroundView: EmptyView())
            default:
                //mandatory as there are more widget families as in lockscreen widgets etc
                Text(
                    NSLocalizedString("Not an implemented widget yet", comment: "Gauge Widget Not Implemented Error Message"))
        }
    }
}

struct NightguardGaugeEntryView : View {
    
    @Environment(\.widgetFamily) var widgetFamily
    var entry: NightscoutDataEntry

    var body: some View {
        switch widgetFamily {
            case .accessoryCircular:
                AccessoryCircularGaugeView(entry: entry)
                .widgetBackground(backgroundView: background())
            default:
                //mandatory as there are more widget families as in lockscreen widgets etc
                Text(NSLocalizedString("No Gauge Support for this widget!", comment: "Gauge Widget Not Supported Error Message"))
        }
    }
}

struct nightguard_Widget_Extension_Previews: PreviewProvider {
    static var previews: some View {
        
        NightguardEntryView(entry: NightscoutDataEntry.previewValues)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("SysSmall")
         
        NightguardEntryView(entry: NightscoutDataEntry.previewValues)
            .previewContext(WidgetPreviewContext(family: .accessoryInline))
            .previewDisplayName("Inline")
        
        NightguardEntryView(entry: NightscoutDataEntry.previewValues)
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Circular")
        
        NightguardGaugeEntryView(entry: NightscoutDataEntry.previewValues)
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("CircularGauge")
        
        NightguardEntryView(entry: NightscoutDataEntry.previewValues)
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            .previewDisplayName("Rectangular")
    }
}
