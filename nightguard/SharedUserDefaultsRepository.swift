//
//  SharedUserDefaultsRepository.swift
//  nightguard
//
//  Created by Dirk Hermanns on 18.09.22.
//  Copyright © 2022 private. All rights reserved.
//

import Foundation
import UIKit

/*
 * UserDefaults that need access to a shared reference.
 * This is separated from the UserDefaultsRepository, since it can't be used
 * from a Widget.
 */
class SharedUserDefaultsRepository {
    
    static let showBGOnAppBadge = UserDefaultsValue<Bool>(
        key: "showBGOnAppBadge",
        default: false,
        onChange: { show in
            #if os(iOS)
            if show {
                UIApplication.shared.setCurrentBGValueOnAppBadge()
            } else {
                UIApplication.shared.clearAppBadge()
            }
            #endif
    })
    
    #if os(iOS)
    static let screenlockSwitchState = UserDefaultsValue<Bool>(
        key: "screenlockSwitchState",
        default: UIApplication.shared.isIdleTimerDisabled,
        onChange: { screenlock in
            UIApplication.shared.isIdleTimerDisabled = screenlock
    })
    #endif
}
