//
//  CareController.swift
//  nightguard WatchKit Extension
//
//  Created by Dirk Hermanns on 11.10.20.
//  Copyright © 2020 private. All rights reserved.
//

import WatchKit
import Foundation
import SwiftUI

@available(watchOSApplicationExtension 6.0, *)
class TemporaryTargetController: WKHostingController<TemporaryTargetView> {
    override var body: TemporaryTargetView {
        return TemporaryTargetView()
    }
}
