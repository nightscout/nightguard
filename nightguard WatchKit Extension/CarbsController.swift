//
//  CarbsController.swift
//  nightguard WatchKit Extension
//
//  Created by Dirk Hermanns on 18.10.20.
//  Copyright © 2020 private. All rights reserved.
//

import WatchKit
import Foundation
import SwiftUI

@available(watchOSApplicationExtension 6.0, *)
class CarbsController: WKHostingController<CarbsView> {
    override var body: CarbsView {
        return CarbsView()
    }
}
