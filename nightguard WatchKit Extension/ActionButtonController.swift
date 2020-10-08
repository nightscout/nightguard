//
//  ActionController.swift
//  nightguard WatchKit Extension
//
//  Created by Dirk Hermanns on 05.10.20.
//  Copyright © 2020 private. All rights reserved.
//

import WatchKit
import Foundation
import SwiftUI

@available(watchOSApplicationExtension 6.0, *)
class ActionButtonController: WKHostingController<ActionButtonView> {
    override var body: ActionButtonView {
        return ActionButtonView()
    }
}
