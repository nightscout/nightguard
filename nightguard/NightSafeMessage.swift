//
//  NightSafeMessage.swift
//  nightguard
//
//  Created by Florian Preknya on 2/23/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation

/// request made by watch for collecting some "night safe" phone settings
class RequestNightSafeMessage: EmptyWatchMessage {}


/// Relevant phone settings for deciding if the alarms will be succesfully delivered (imagining a night scenario).
struct PhoneNightSafeSettings: Codable {
    
    // is the phone in active state?
    var isPhoneActive: Bool
    
    // is the screen lock ON?
    var isScreenLockActive: Bool
    
    // what is the volume level (overriden or actual)? - values beween [0...1]
    var volumeLevel: Float
}

class ResponseNightSafeMessage: GenericWatchMessage<PhoneNightSafeSettings> {}
