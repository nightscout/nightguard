//
//  GuiStateRepository.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 15.02.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation

// Stores/Restores the state of the GUI. That is right now the screenlock-switch.
class GuiStateRepository {
    
    static let singleton = GuiStateRepository()

    func storeScreenlockSwitchState(_ isActivated : Bool) {
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.set(isActivated, forKey: "screenlockSwitchState")
    }
    
    func loadScreenlockSwitchState() -> Bool {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => screenlock should be deactivated
            return false
        }
        
        guard let isActivated = defaults.object(forKey: "screenlockSwitchState") as? Bool else {
            return false
        }
        return isActivated
    }
    
    func storeNightscoutUris(nightscoutUris : [String]) {
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.set(nightscoutUris, forKey: "nightscoutUris")
    }
    
    func loadNightscoutUris() -> [String] {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => screenlock should be deactivated
            return []
        }
        
        guard let nightscoutUris = defaults.object(forKey: "nightscoutUris") as? [String] else {
            return []
        }
        return nightscoutUris
    }
}
