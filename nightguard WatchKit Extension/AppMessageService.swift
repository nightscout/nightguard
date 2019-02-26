//
//  AppPushService.swift
//  nightguard
//
//  Created by Dirk Hermanns on 27.06.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation
import WatchKit
import WatchConnectivity

// This class handles values that are passed from the ios app.
class AppMessageService {
    
    static let singleton = AppMessageService()
        
    // send a dummy message to keep the phone app awake (start the app if is not started)
    func keepAwakePhoneApp() {
        KeepAwakeMessage().send()
    }
}
