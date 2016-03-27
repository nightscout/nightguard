//
//  GuiStateRepository.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 15.02.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation

// Stores/Restores the state of the GUI. That is the Volume-Slider Position
// and the screenlock-switch.
class GuiStateRepository {
    
    static let singleton = GuiStateRepository()
    
    func storeVolumeSliderPosition(let currentPosition : Float) {
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setObject(currentPosition, forKey: "volumeSliderPosition")
    }
    
    func loadVolumeSliderPosition() -> Float {
        guard let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => return slider position 0
            return 0
        }
        
        guard let currentPosition = defaults.objectForKey("volumeSliderPosition") as? Float else {
            return 0
        }
        return currentPosition
    }

    func storeScreenlockSwitchState(let isActivated : Bool) {
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setObject(isActivated, forKey: "screenlockSwitchState")
    }
    
    func loadScreenlockSwitchState() -> Bool {
        guard let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => screenlock should be deactivated
            return false
        }
        
        guard let isActivated = defaults.objectForKey("screenlockSwitchState") as? Bool else {
            return false
        }
        return isActivated
    }
}