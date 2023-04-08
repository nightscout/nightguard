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

struct AccessoryCircularView : View {
    
    var entry: NightscoutDataEntry
    
    var body: some View {
        VStack {
            Text(Date(timeIntervalSince1970: entry.time.doubleValue / 1000).toLocalTimeString())
            Text("\(UnitsConverter.mgdlToDisplayUnits(entry.sgv))\(UnitsConverter.mgdlToDisplayUnits(entry.bgdeltaString))")
            Text("\(entry.bgdeltaArrow)")
        }
        .widgetAccentable(true)
        .unredacted()
    }
}


