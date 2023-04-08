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
    
    var entry: NightscoutDataEntry
    
    var body: some View {
        Text("\(entry.bgdeltaArrow)")
            .font(.system(size: 20))
            .foregroundColor(
                Color(UIColorChanger.getDeltaLabelColor(entry.bgdelta)))
        .widgetLabel {
            Text("\(UnitsConverter.mgdlToDisplayUnits(entry.sgv))" +
                 "\(UnitsConverter.mgdlToDisplayUnits(entry.bgdeltaString)) " +
                 "\(calculateAgeInMinutes(from: entry.time))")
                    .foregroundColor(
                        Color(UIColorChanger.getBgColor(UnitsConverter.mgdlToDisplayUnits(entry.sgv))))
        }
        .widgetAccentable(true)
        .unredacted()
    }
    
    func calculateAgeInMinutes(from timestamp: NSNumber) -> String {
        let timestampAsDate = Date(timeIntervalSince1970: timestamp.doubleValue / 1000)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute], from: timestampAsDate, to: Date())
        if let ageInMinutes = components.minute {
            return "\(ageInMinutes)m"
        }
        return "?"
    }
}


