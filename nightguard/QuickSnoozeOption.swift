//
//  QuickSnoozingAction.swift
//  nightguard
//
//  Created by Florian Preknya on 2/10/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation

/// Quick Snoozing options
enum QuickSnoozeOption: Int {
    case doNothing = -1
    case showSnoozePopup = 0
    case snoozeOneMinute = 1
    case snoozeFiveMinutes = 5
    case snoozeTenMinutes = 10
}

extension QuickSnoozeOption: CustomStringConvertible {
    var description: String {
        
        switch self {
        case .doNothing:
            return NSLocalizedString("Will do Nothing", comment: "Will do Nothing Quick Snooze Option")
        case .showSnoozePopup:
            return NSLocalizedString("Will show the Snooze Dialog", comment: "Will show the Snooze Dialog Quick Snooze Option")
        case .snoozeOneMinute:
            return NSLocalizedString("Will snooze for 1 Minute", comment: "Will snooze for 1 Minute Dialog Quick Snooze Option")
        case .snoozeFiveMinutes:
            return NSLocalizedString("Will snooze for 5 Minutes", comment: "Will snooze for 5 Minutes Dialog Quick Snooze Option")
        case .snoozeTenMinutes:
            return NSLocalizedString("Will snooze for 10 Minutes", comment: "Will snooze for 10 Minutes Dialog Quick Snooze Option")
        }
    }
}

extension QuickSnoozeOption: AnyConvertible {
    
    func toAny() -> Any {
        return rawValue
    }
    
    static func fromAny(_ anyValue: Any) -> QuickSnoozeOption? {
        guard let rawValue = anyValue as? Int else {
            return nil
        }
        
        return QuickSnoozeOption(rawValue: rawValue)
    }
}
