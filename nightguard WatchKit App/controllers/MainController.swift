//
//  MainController.swift
//  nightguard WatchKit Extension
//
//  Created by Dirk Hermanns on 08.09.20.
//  Copyright © 2020 private. All rights reserved.
//

import Foundation

// Simple container class to hold the shared MainViewModel
// This is kept for backwards compatibility with ExtensionDelegate
class MainController {
    static var mainViewModel = MainViewModel()
}
