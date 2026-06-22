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
    let displaySnapshot: NightguardDisplaySnapshot?
    
    var dictionary: [String : Any] {
        let encodedNightscoutData = try? JSONEncoder().encode(nightscoutData)
        var dictionary: [String : Any] = ["nightscoutData": encodedNightscoutData ?? Data()]
        if let displaySnapshot,
           let encodedDisplaySnapshot = try? JSONEncoder().encode(displaySnapshot) {
            dictionary["displaySnapshot"] = encodedDisplaySnapshot
        }
        return dictionary
    }
    
    init() {
        self.nightscoutData = NightscoutCacheService.singleton.getCurrentNightscoutData()
        self.displaySnapshot = NightscoutDataRepository.singleton.loadLatestDisplaySnapshot()
            ?? NightscoutDataRepository.singleton.storeLatestDisplaySnapshot(from: nightscoutData)
    }
    
    required init?(dictionary: [String : Any]) {
        guard let data = dictionary["nightscoutData"] as? Data, let nightscoutData = try? JSONDecoder().decode(NightscoutData.self, from: data) else {
            print("Invalid nightscout data received!")
            return nil
        }

        self.nightscoutData = nightscoutData
        if let displaySnapshotData = dictionary["displaySnapshot"] as? Data {
            self.displaySnapshot = try? JSONDecoder().decode(NightguardDisplaySnapshot.self, from: displaySnapshotData)
        } else {
            self.displaySnapshot = nil
        }
    }
}
