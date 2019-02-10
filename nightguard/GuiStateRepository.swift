//
//  GuiStateRepository.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 15.02.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation
import UIKit

// Stores/Restores the state of the GUI. That is right now the screenlock-switch.
class GuiStateRepository {
    
    static let singleton = GuiStateRepository()

    let screenlockSwitchState = UserDefaultsValue<Bool>(
        key: "screenlockSwitchState",
        default: UIApplication.shared.isIdleTimerDisabled,
        onChange: { screenlock in
            UIApplication.shared.isIdleTimerDisabled = screenlock
    })
    
    let nightscoutUris = UserDefaultsValue<[String]>(key: "nightscoutUris", default: [])
}
