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

@main
struct nightguard_Complication_Extension: Widget {
    let kind: String = "nightguard_Complication_Extension"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: NightguardTimelineProvider()) { entry in
            nightguard_Complication_ExtensionEntryView(entry: entry)
        }
        .configurationDisplayName("BG Values")
        .description("Nightguard BG Values Complication")
    }
}

struct nightguard_Complication_Extension_Previews: PreviewProvider {
    static var previews: some View {
        nightguard_Complication_ExtensionEntryView(entry: NightscoutDataEntry(date: Date(), configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }
}
