//
//  AccessoryCircularView.swift
//  nightguard Widget Extension
//
//  Created by Dirk Hermanns on 07.04.23.
//  Copyright © 2023 private. All rights reserved.
//

import Foundation
import SwiftUI
import WidgetKit

struct AccessoryCornerGaugeView : View {
    
    var entry: NightscoutDataEntry
    
    var body: some View {
        
        Text("\(entry.lastBGValues.first?.value ?? "??")")
            .font(.system(size: 20))
            .foregroundColor(
                Color(UIColorChanger.getBgColor(entry.lastBGValues.first?.value ?? "999")))
            .widgetLabel {
               ProgressView(value:
                                (Double(calculateAgeInMinutes(fromDouble: entry.lastBGValues.first?.timestamp ?? Date.now.timeIntervalSinceNow - 3600)) ?? 60) / 60)
               .tint(
                Color(UIColorChanger.getTimeLabelColor(
                    fromDouble: entry.lastBGValues.first?.timestamp ?? Date().timeIntervalSinceNow - 3600)))
           }
        .widgetAccentable(true)
        .unredacted()
    }
}


