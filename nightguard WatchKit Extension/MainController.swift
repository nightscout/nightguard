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
class MainController: WKHostingController<MainView> {
    
    static var mainViewModel = MainViewModel()
    
    override var body: MainView {
        return MainView(mainViewModel: MainController.mainViewModel)
    }
}
