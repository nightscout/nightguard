//
//  AccessoryRectangularView.swift
//  nightguard
//
//  Created by Dirk Hermanns on 02.04.23.
//  Copyright © 2023 private. All rights reserved.
//

import Foundation
import SwiftUI
import WidgetKit

struct AccessoryRectangularTimestampView : View {
    
    var entry: NightscoutDataEntry
    
    var body: some View {
        ZStack {
            //No background on watch
#if os(iOS)
            AccessoryWidgetBackground()
                .clipShape(RoundedRectangle(cornerRadius: 10))
#endif
            VStack {
                HStack {
                    VStack {
                        ForEach(entry.lastBGValues, id: \.self.id) { bgEntry in

                            // Use this in your Text view
                            Text("\(formatTimestamp(bgEntry.timestamp))")
#if os(watchOS)
                                .foregroundColor(Color(entry.sgvColor))
#endif
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    VStack {
                        ForEach(entry.lastBGValues, id: \.self.id) { bgEntry in
                            // Text("\(String(bgEntry.value)) \(bgEntry.delta)")
                            Text("\(String(bgEntry.value)) \(bgEntry.delta) \(bgEntry.arrow)")
#if os(watchOS)
                                .foregroundColor(Color(entry.sgvColor))
#endif
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if entry.lastBGValues.isEmpty {
                        VStack {
                            Text("--- --- ---")
                        }
                    }
                }
                if !entry.errorMessage.isEmpty {
                    Text("\(entry.errorMessage)")
                        .font(.system(size: 6))
                }
            }
        }
        .widgetAccentable(true)
        .unredacted()
    }

    // Function to format the timestamp as an absolute time
    func formatTimestamp(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    func snoozedForMinutes(snoozeTimestamp: TimeInterval) -> Int {
        let currentTimestamp = Date().timeIntervalSince1970
        let snoozedMinutes = Int((snoozeTimestamp - currentTimestamp) / 60)
        if snoozedMinutes < 0 {
            return 0
        }
        return snoozedMinutes
    }
}
