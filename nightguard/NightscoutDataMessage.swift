//
//  NightscoutDataMessage.swift
//  nightguard
//
//  Created by Florian Preknya on 1/25/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation

class NightscoutDataMessage: WatchMessage {
    
    let nightscoutData: NightscoutData
    
    var dictionary: [String : Any] {
        let encodedNightscoutData = try? JSONEncoder().encode(nightscoutData)
        return ["nightscoutData": encodedNightscoutData ?? Data()]
    }
    
    init() {
        self.nightscoutData = NightscoutCacheService.singleton.getCurrentNightscoutData()
    }
    
    required init?(dictionary: [String : Any]) {
        guard let data = dictionary["nightscoutData"] as? Data, let nightscoutData = try? JSONDecoder().decode(NightscoutData.self, from: data) else {
            print("Invalid nightscout data received!")
            return nil
        }

        self.nightscoutData = nightscoutData
    }
}
