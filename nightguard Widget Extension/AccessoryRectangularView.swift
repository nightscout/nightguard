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

struct AccessoryRectangularView : View {
    
    var entry: NightscoutDataEntry
    
    var body: some View {
        HStack {
            VStack {
                Text("\(calculateAgeInMinutes(from: entry.time))m")
                    .foregroundColor(Color(UIColorChanger.getBgColor(UnitsConverter.mgdlToDisplayUnits(entry.sgv))))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                ForEach(entry.lastBGValues, id: \.self.id) { bgEntry in
                    Text("\(calculateAgeInMinutes(from:NSNumber(value: bgEntry.timestamp)))m")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            VStack {
                Text("\(UnitsConverter.mgdlToDisplayUnits(entry.sgv))\(UnitsConverter.mgdlToDisplayUnits(entry.bgdeltaString))\(entry.bgdeltaArrow)")
                    .foregroundColor(Color(UIColorChanger.getBgColor(UnitsConverter.mgdlToDisplayUnits(entry.sgv))))
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(entry.lastBGValues, id: \.self.id) { bgEntry in
                    Text("\(Int(UnitsConverter.mgdlToDisplayUnits(bgEntry.value)))")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .widgetAccentable(true)
        .unredacted()
    }
}
