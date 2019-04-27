//
//  WatchSyncRequestMessage.swift
//  nightguard
//
//  Created by Florian Preknya on 2/18/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation

/// Message sent by watch for requesting a sync from phone if its data is not actual; it contains the watch "last watch sync update id" and the snooze timestamp; the phone app will compare those values with his own ones and send the corresponding update messages if needed.
class WatchSyncRequestMessage: WatchMessage {
    
    var dictionary: [String : Any]
    
    required init?(dictionary: [String : Any]) {
        self.dictionary = dictionary
    }
    
    init() {
        var dictionary = [String: Any]()
        dictionary[UserDefaultsRepository.lastWatchSyncUpdateId.key] = UserDefaultsRepository.lastWatchSyncUpdateId.anyValue
        dictionary["snoozedUntilTimestamp"] = AlarmRule.snoozedUntilTimestamp.value
        
        self.dictionary = dictionary
    }
}
