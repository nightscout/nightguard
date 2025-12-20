//
//  EmptyWatchMessage.swift
//  nightguard
//
//  Created by Florian Preknya on 1/25/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation

class EmptyWatchMessage: WatchMessage {
    
    var dictionary: [String : Any] {
        return [:]
    }
    
    init() {
    }
    
    required init?(dictionary: [String : Any]) {
    }
}
