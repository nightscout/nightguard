//
//  UserDefaultsValue.swift
//  nightguard
//
//  Created by Florian Preknya on 1/23/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation

/// A type erased key-value
protocol UserDefaultsAnyValue {
    var key: String { get }
    var anyValue: Any { get set }
}

class UserDefaultsValue<T: AnyConvertible & Equatable> : UserDefaultsAnyValue {
    
    // user defaults key
    let key: String
    
    var value: T {
        didSet {
            
            // continue only if the new value is different than old value
            guard self.value != oldValue else {
                return
            }

            if let validation = validation {
                guard let validatedValue = validation(value) else {
                    value = oldValue
                    return
                }
                
                value = validatedValue
            }
            
            // store value to user defaults
            UserDefaultsValue.defaults.setValue(value.toAny(), forKey: key)
            
            // execute custom closure
            onChange?()
            
            // signal UserDefaultsValues that value has changed
            UserDefaultsValues.valueChanged(self)
        }
    }
    
    var anyValue: Any {
        get {
            return self.value.toAny()
        }
        
        set {
            guard let newValue = T.fromAny(newValue) as T? else {
                return
            }
            
            self.value = newValue
        }
    }
    
    // on change closure
    private let onChange: (() -> ())?
    
    // validate & transform closure : giving the new value, validate it; if validations passes, return the new value; if fails, transform the value, returning a modified version or ... return nil and the change will not gonna happen
    private let validation: ((T) -> T?)?
    
    class var defaults: UserDefaults {
        return UserDefaults(suiteName: AppConstants.APP_GROUP_ID)!
    }
    
    init(key: String, default defaultValue: T, onChange: (() -> Void)? = nil, validation: ((T) -> T?)? = nil) {
        self.key = key
        if let anyValue = UserDefaultsValue.defaults.object(forKey: key), let value = T.fromAny(anyValue) as T? {
            if let validation = validation {
                self.value = validation(value) ?? defaultValue
            } else {
                self.value = value
            }
        } else {
            self.value = defaultValue
        }
        self.onChange = onChange
        self.validation = validation
    }
    
    func group(_ groupName: String) -> Self {
        UserDefaultsValues.add(self, to: groupName)
        return self
    }
}


class ObservationToken {
    
    private let cancellationClosure: () -> Void
    
    init(cancellationClosure: @escaping () -> Void) {
        self.cancellationClosure = cancellationClosure
    }
    
    func cancel() {
        cancellationClosure()
    }
}

class UserDefaultsValues {
    
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
extension UserDefaultsValues {
    struct GroupNames {
        static let watchSync = "watchSync"
        static let alarm = "alarm"
    }
}
