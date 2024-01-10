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

struct AccessoryCornerView : View {
    
    @State var entry: NightscoutDataEntry
    
    var body: some View {
        Text("\(calculateAgeInMinutes(from: entry.time))m")
            .font(.system(size: 20))
            .foregroundColor(
                Color(entry.bgdeltaColor))
        .widgetLabel {
            Text("\(entry.sgv)" +
                 "\(entry.bgdeltaString)")
                    .foregroundColor(
                        Color(entry.sgvColor))
        }
        .widgetAccentable(true)
        .unredacted()
    }
}


