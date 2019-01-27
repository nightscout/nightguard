//
//  SnoozeMessage.swift
//  nightguard
//
//  Created by Florian Preknya on 1/25/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation

/// The Snooze message definition, contains the timestamp while the alarm is snoozed.
class SnoozeMessage: WatchMessage {
    
    // the snoozed until timestamp (if 0, snooze is off)
    let timestamp: TimeInterval
    
    var dictionary: [String : Any] {
        return ["snoozedUntilTimestamp": timestamp]
    }
    
    init(timestamp: TimeInterval) {
        self.timestamp = timestamp
    }
    
    required init?(dictionary: [String : Any]) {
        guard let timestamp = dictionary["snoozedUntilTimestamp"] as? TimeInterval else {
            return nil
        }
        
        self.timestamp = timestamp
    }
}
