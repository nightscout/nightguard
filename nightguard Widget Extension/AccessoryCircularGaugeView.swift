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

struct AccessoryCircularGaugeView : View {
    
    var entry: NightscoutDataEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Gauge(value: Double(
                calculateAgeInMinutes(
                    fromDouble: entry.lastBGValues.first?.timestamp ?? Date.now.timeIntervalSinceNow - 3600)) ?? 60,
                  in: 0...60) {
                Text("\(entry.lastBGValues.first?.delta ?? "?")")
                    .foregroundColor(
                        Color(UIColorChanger.getDeltaLabelColor(
                            Float(entry.lastBGValues.first?.delta ?? "99") ?? 99)))
            } currentValueLabel: {
                Text(entry.lastBGValues.first?.value ?? "??")
                    .foregroundColor(
                        Color(UIColorChanger.getBgColor(entry.lastBGValues.first?.value ?? "999")))
            }
            .tint(
                Color(UIColorChanger.getTimeLabelColor(
                    fromDouble: entry.lastBGValues.first?.timestamp ?? Date().timeIntervalSinceNow - 3600)))
            
            .gaugeStyle(.accessoryCircular)
            .widgetAccentable(true)
            .unredacted()
        }
    }
}


