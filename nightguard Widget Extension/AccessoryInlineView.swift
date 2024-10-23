//
//  AccessoryInlineView.swift
//  nightguard
//
//  Created by Dirk Hermanns on 02.04.23.
//  Copyright © 2023 private. All rights reserved.
//

import Foundation
import SwiftUI
import WidgetKit

struct AccessoryInlineView : View {
    
    var entry: NightscoutDataEntry
    
    var body: some View {
        
        //AccessoryWidgetBackground() not supported in this Widget Family
        ZStack {
            let bgValue = entry.lastBGValues.first
            if let bgValue = bgValue {

                Text("\(String(bgValue.value)) \(bgValue.delta) \(bgValue.arrow) \(Date.now.addingTimeInterval(-(Date.now.timeIntervalSince1970 - (bgValue.timestamp / 1000))), style: .timer)")
#if os(watchOS)
                .foregroundColor(Color(entry.sgvColor))
#endif
            } else {
                Text("--:-- --- -")
            }
        }
        .widgetAccentable(true)
        .unredacted()
    }
}
