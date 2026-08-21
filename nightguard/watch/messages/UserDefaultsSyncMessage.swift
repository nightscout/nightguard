//
//  UserDefaultsSyncMessage.swift
//  nightguard
//
//  Created by Florian Preknya on 1/25/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation

class UserDefaultSyncMessage: WatchMessage {

    static let nightscoutTokenKey = "_nightscoutToken"
    
    var dictionary: [String : Any]
    
    required init?(dictionary: [String : Any]) {
        self.dictionary = dictionary
    }
    
    init() {
        var dictionary = [String: Any]()
        UserDefaultsValueGroups.values(from: UserDefaultsValueGroups.GroupNames.watchSync)?.forEach { value in
            dictionary[value.key] = value.anyValue
        }
        
        // add the last watch sync update id also in the dictionary
        dictionary[UserDefaultsRepository.lastWatchSyncUpdateId.key] = UserDefaultsRepository.lastWatchSyncUpdateId.anyValue
        dictionary[Self.nightscoutTokenKey] = UserDefaultsRepository.nightscoutToken
        
        self.dictionary = dictionary
    }
}
