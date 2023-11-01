//
//  AccessoryInlineView.swift
//  nightguard
//
//  Created by Dirk Hermanns on 02.04.23.
//  Copyright © 2023 private. All rights reserved.
//

import Foundation
import SwiftUI
import WidgetKit

struct AccessoryInlineView : View {
    
    var entry: NightscoutDataEntry
    
    var body: some View {
        Text("| \(Date(timeIntervalSince1970:entry.lastBGValues.first?.timestamp ?? (Date().timeIntervalSinceNow - 3600) / 1000).toLocalTimeString()) " + "\(entry.lastBGValues.first?.value ?? "?")\(entry.lastBGValues.first?.delta ?? "?")")
            .widgetAccentable(true)
            .unredacted()
    }
}
