//
//  SystemSmallView.swift
//  nightguard Widget Extension
//
//  Created by Philipp Pöml on 26.05.24.
//  Copyright © 2024 private. All rights reserved.
//

import Foundation
import SwiftUI
import WidgetKit

struct SystemSmallView : View {
    
    var entry: NightscoutDataEntry
    
    var body: some View {
            VStack     {
                Image ("WidgetImageBlack")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                HStack {
                    VStack {
                        ForEach(entry.lastBGValues, id: \.self.id) { bgEntry in
                            //Text("\(calculateAgeInMinutes(from:NSNumber(value: bgEntry.timestamp)))m")
                            if (entry.lastBGValues.first?.id == bgEntry.id) {
                                Text(Date.now.addingTimeInterval(-(Date.now.timeIntervalSince1970 - (bgEntry.timestamp / 1000))), style: .timer)
                                    .foregroundColor(Color(entry.sgvColor))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .monospacedDigit()
                                    .multilineTextAlignment(.trailing)
                            } else {
                                Text("+\(calculateAgeInMinutes(from:NSNumber(value: Date.now.timeIntervalSince1970 * 1000 + bgEntry.timestamp - (entry.lastBGValues.first?.timestamp ?? 0))))m")
                                    .foregroundColor(Color(entry.sgvColor))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                    .padding(.trailing, 20)
                    VStack {
                        ForEach(entry.lastBGValues, id: \.self.id) { bgEntry in
                            //Text("\(String(bgEntry.value)) \(bgEntry.delta)")
                            Text("\(String(bgEntry.value)) \(bgEntry.delta) \(bgEntry.arrow)")
                                .foregroundColor(Color(entry.sgvColor))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.leading, -20)
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
                //Text(entry.entryDate, style: .time)
                //Text("\(snoozedForMinutes(snoozeTimestamp: entry.snoozedUntilTimestamp))min Snoozed")
            }
        .widgetAccentable(true)
        .unredacted()
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
