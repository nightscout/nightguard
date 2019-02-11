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
            return "Do Nothing"
        case .showSnoozePopup:
            return "Show the Snooze Dialog"
        case .snoozeOneMinute:
            return "Snooze for 1 Minute"
        case .snoozeFiveMinutes:
            return "Snooze for 5 Minutes"
        case .snoozeTenMinutes:
            return "Snooze for 10 Minutes"
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
