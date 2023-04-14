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
        Text("\(entry.bgdeltaArrow)")
            .font(.system(size: 20))
            .foregroundColor(
                Color(UIColorChanger.getDeltaLabelColor(entry.bgdelta)))
        .widgetLabel {
            Text("\(UnitsConverter.mgdlToDisplayUnits(entry.sgv))" +
                 "\(UnitsConverter.mgdlToDisplayUnits(entry.bgdeltaString)) " +
                 "\(calculateAgeInMinutes(from: entry.time))m")
                    .foregroundColor(
                        Color(UIColorChanger.getBgColor(UnitsConverter.mgdlToDisplayUnits(entry.sgv))))
        }
        .widgetAccentable(true)
        .unredacted()
    }
}


