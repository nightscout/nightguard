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
        Text("| \(Date(timeIntervalSince1970: entry.time.doubleValue / 1000).toLocalTimeString()) " + "\(UnitsConverter.mgdlToDisplayUnits(entry.sgv))\(UnitsConverter.mgdlToDisplayUnits(entry.bgdeltaString))\(entry.bgdeltaArrow)")
        
            .widgetAccentable(true)
            .unredacted()
    }
}
