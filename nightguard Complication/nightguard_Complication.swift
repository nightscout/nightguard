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
struct NightguardWidgetsBudle: WidgetBundle {
    var body: some Widget {
        NightguardDefaultWidgets()
        NightguardGaugeWidgets()
    }
}

struct NightguardDefaultWidgets: Widget {
    let kind: String = "NightguardDefaultWidgets"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: NightguardTimelineProvider()) { entry in
            nightguard_Complication_ExtensionEntryView(entry: entry)
        }
        .configurationDisplayName("BG Text")
        .description("Nightguard BG Values Text Complication")
    }
}

struct NightguardGaugeWidgets: Widget {
    let kind: String = "NightguardGaugeWidgets"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: NightguardTimelineProvider()) { entry in
            NightguardGaugeEntryView(entry: entry)
        }
        .configurationDisplayName("BG Gauge")
        .description("Nightguard BG Values as Gauge Complication")
    }
}

struct nightguard_Complication_Extension_Previews: PreviewProvider {
    static var previews: some View {
        nightguard_Complication_ExtensionEntryView(entry: NightscoutDataEntry(date: Date(), configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }
}

struct nightguard_Complication_ExtensionEntryView : View {
    
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
            @unknown default:
                //mandatory as there are more widget families as in lockscreen widgets etc
                Text("Not an implemented widget yet")
        }
    }
}

struct NightguardGaugePreviews: PreviewProvider {
    static var previews: some View {
        
        nightguard_Complication_ExtensionEntryView(entry: NightscoutDataEntry(date: Date(), sgv: "100", configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }
}
