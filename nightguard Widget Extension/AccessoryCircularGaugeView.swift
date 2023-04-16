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
        
        Gauge(value: Double(calculateAgeInMinutes(from: entry.time)) ?? 0, in: 0...60) {
            Text("\(entry.bgdeltaArrow)")
            .foregroundColor(
                Color(UIColorChanger.getDeltaLabelColor(entry.bgdelta)))
        } currentValueLabel: {
            Text(UnitsConverter.mgdlToDisplayUnits(entry.sgv))
            .foregroundColor(
                Color(UIColorChanger.getBgColor(UnitsConverter.mgdlToDisplayUnits(entry.sgv))))
        }
        .tint(
            Color(UIColorChanger.getTimeLabelColor(entry.time)))
        
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable(true)
        .unredacted()
    }
}


