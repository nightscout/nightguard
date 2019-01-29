//
//  UserDefaultsValue.swift
//  nightguard
//
//  Created by Florian Preknya on 1/23/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation

/// A type that presents a key and a mutable value (type erased key-value)
protocol UserDefaultsAnyValue {
    var key: String { get }
    var anyValue: Any { get set }
}

/// A value holder that keeps its internal data (the value) synchronized with its UserDefaults value. The value is read from UserDefaults on initialization (if exists, otherwise a default value is used) and written when the value changes. Also a custom validation & onChange closure can be set on initialization.
///
/// Another feature of this class is that when the value changes, the change can be observed by multiple observers if the value is embeded in a group (UserDefaultsValueGroups class manages the groups). It is very convenient to group related values in the same group, so when one of them changes, the observers are notified that a change occured in that group.
class UserDefaultsValue<T: AnyConvertible & Equatable> : UserDefaultsAnyValue {
    
    // user defaults key (UserDefaultsAnyValue protocol implementation)
    let key: String
    
    // the value (strong typed)
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
            UserDefaultsValueGroups.valueChanged(self)
        }
    }
    
    /// get/set the value from Any value (UserDefaultsAnyValue protocol implementation)
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
    
    // user defaults used for persistence
    private class var defaults: UserDefaults {
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
    
    /// Insert this value in a group, useful for observing changes in the whole group, instead of particular values
    func group(_ groupName: String) -> Self {
        UserDefaultsValueGroups.add(self, to: groupName)
        return self
    }
}
