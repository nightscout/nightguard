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
                ForEach(entry.lastBGValues, id: \.self.id) { bgEntry in
                    Text("\(calculateAgeInMinutes(from:NSNumber(value: bgEntry.timestamp)))m")
                        .foregroundColor(Color(UIColorChanger.getBgColor(UnitsConverter.mgdlToDisplayUnits(entry.sgv))))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            VStack {
                ForEach(entry.lastBGValues, id: \.self.id) { bgEntry in
                    Text("\(UnitsConverter.mgdlToDisplayUnits(String(bgEntry.value))) \(UnitsConverter.mgdlToDisplayUnitsWithSign(bgEntry.delta.cleanSignedValue))")
                        .foregroundColor(Color(UIColorChanger.getBgColor(UnitsConverter.mgdlToDisplayUnits(entry.sgv))))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .widgetAccentable(true)
        .unredacted()
    }
}
