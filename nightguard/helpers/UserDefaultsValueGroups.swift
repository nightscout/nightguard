//
//  UserDefaultsValueGroups.swift
//  nightguard
//
//  Created by Florian Preknya on 1/29/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation

/// UserDefaultValue groups manager class, providing change observation capabilities (keep clients informed when a change occured in a given group).
class UserDefaultsValueGroups {
    
    class func values(from groupName: String) -> [UserDefaultsAnyValue]? {
        return groupNameToValues[groupName]
    }
    
    class func add(_ value: UserDefaultsAnyValue, to groupName: String) {
        
        // add to "value-key to groupNames" dictionary
        var groupNames = valueKeyToGroupNames[value.key] ?? []
        guard !groupNames.contains(groupName) else {
            
            // already added value to this group!
            return
        }
        
        groupNames.append(groupName)
        valueKeyToGroupNames[value.key] = groupNames
        
        // add to "groupName to value" dictionary
        var values = groupNameToValues[groupName] ?? []
        values.append(value)
        groupNameToValues[groupName] = values
    }
    
    @discardableResult
    class func observeChanges(in groupName: String, using closure: @escaping(UserDefaultsAnyValue, String) -> Void) -> ObservationToken {
        
        let id = UUID()
        
        var observers = groupNameToObservers[groupName] ?? [:]
        observers[id] = closure
        groupNameToObservers[groupName] = observers
        
        return ObservationToken {
            groupNameToObservers[groupName]?.removeValue(forKey: id)
        }
    }
    
    // called by UserDefaultsValue instances when value changes
    class func valueChanged(_ value: UserDefaultsAnyValue) {
        valueKeyToGroupNames[value.key]?.forEach() { groupName in
            notifyValueChanged(value, in: groupName)
        }
    }
    
    private class func notifyValueChanged(_ value: UserDefaultsAnyValue, in groupName: String) {
        groupNameToObservers[groupName]?.values.forEach { closure in
            closure(value, groupName)
        }
    }
    
    static private var groupNameToValues: [String: [UserDefaultsAnyValue]] = [:]
    static private var valueKeyToGroupNames: [String: [String]] = [:]
    static private var groupNameToObservers: [String: [UUID : (UserDefaultsAnyValue, String) -> Void]] = [:]
}

// user default values group definitions
extension UserDefaultsValueGroups {
    struct GroupNames {
        static let watchSync = "watchSync"
        static let alarm = "alarm"
    }
}
