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
        
        Text("\(UnitsConverter.mgdlToDisplayUnits(entry.sgv))")
            .font(.system(size: 20))
            .foregroundColor(
               Color(UIColorChanger.getBgColor(UnitsConverter.mgdlToDisplayUnits(entry.sgv))))
            .widgetLabel {
               ProgressView(value: (Double(calculateAgeInMinutes(from: entry.time)) ?? 100) / 60)
                 .tint(Color(UIColorChanger.getTimeLabelColor(entry.time)))
           }
        .widgetAccentable(true)
        .unredacted()
    }
}


