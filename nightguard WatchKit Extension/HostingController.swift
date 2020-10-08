//
//  HostingController.swift
//  nightguard WatchKit Extension
//
//  Created by Dirk Hermanns on 08.09.20.
//  Copyright © 2020 private. All rights reserved.
//

import WatchKit
import Foundation
import SwiftUI

@available(watchOSApplicationExtension 6.0, *)
class HostingController: WKHostingController<ContentView> {
    override var body: ContentView {
        return ContentView(mainViewModel: MainViewModel())
    }
}
