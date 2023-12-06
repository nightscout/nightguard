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

class MainController: WKHostingController<MainView> {
    
    static var mainViewModel = MainViewModel()
    
    override var body: MainView {
        return MainView(mainViewModel: MainController.mainViewModel)
    }
    
    
}
