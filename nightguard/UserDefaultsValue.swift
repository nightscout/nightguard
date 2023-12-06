//
//  UserDefaultsValue.swift
//  nightguard
//
//  Created by Florian Preknya on 1/23/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation
import WidgetKit

/// A type that presents a key and a mutable value (type erased key-value)
protocol UserDefaultsAnyValue {
    var key: String { get }
    var anyValue: Any { get set }
}

/// A value holder that keeps its internal data (the value) synchronized with its UserDefaults value. The value is read from UserDefaults on initialization (if exists, otherwise a default value is used) and written when the value changes. Also a custom validation & onChange closure can be set on initialization.
///
/// Another feature of this class is that when the value changes, the change can be observed by multiple observers. There are two observation levels: the instance level, when the observers register directly to the UserDefaultsValue instance, and group level, if the UserDefaultsValue instance is embeded in a group (UserDefaultsValueGroups class manages the groups). It is very convenient to declare related values in the same group, so when one of them changes, the group observers are notified that a change occured in that group (no need to observe each particular UserDefaultsValue instance).
class UserDefaultsValue<T: AnyConvertible & Equatable> : UserDefaultsAnyValue {
    
    // user defaults key (UserDefaultsAnyValue protocol implementation)
    let key: String
    
    typealias ValueType = T
    
    // the value (strong typed)
    var defaultValue: T
    private var _value: T
    var value: T {
        set {
            
            // continue only if the new value is different than old value
            guard self._value != newValue else {
                return
            }

            if let validation = validation {
                guard let validatedValue = validation(newValue) else {
                    return
                }
                
                _value = validatedValue
            } else {
                _value = newValue
            }
            
            // store value to user defaults
            UserDefaultsValue.defaults.setValue(_value.toAny(), forKey: key)
            
            // execute custom closure
            onChange?(value)
            
            // notify observers
            observers.values.forEach { $0(_value) }
            
            // notify UserDefaultsValueGroups that value has changed
            UserDefaultsValueGroups.valueChanged(self)
            
            UserDefaultsValue.defaults.synchronize()
            WidgetCenter.shared.reloadAllTimelines()
        }
        get {
            
            return getUpdatedValueFromUserDefaults()
        }
    }
    
    /// get/set the value from Any value (UserDefaultsAnyValue protocol implementation)
    var anyValue: Any {
        get {
            return self._value.toAny()
        }
        
        set {
            guard let newValue = T.fromAny(newValue) as T? else {
                return
            }
            value = newValue
        }
    }
    
    /// is there this key already stored in UserDefaults?
    var exists: Bool {
        return UserDefaultsValue.defaults.object(forKey: key) != nil
    }
    
    // on change closure
    private let onChange: ((T) -> ())?
    
    // validate & transform closure : giving the new value, validate it; if validations passes, return the new value; if fails, transform the value, returning a modified version or ... return nil and the change will not gonna happen
    private let validation: ((T) -> T?)?
    
    // value change observers
    private var observers: [UUID : (T) -> Void] = [:]
    
    // user defaults used for persistence
    private class var defaults: UserDefaults {
        return UserDefaults(suiteName: AppConstants.APP_GROUP_ID)!
    }
    
    init(key: String, default defaultValue: T, onChange: ((T) -> Void)? = nil, validation: ((T) -> T?)? = nil) {
        self.key = key
        if let anyValue = UserDefaultsValue.defaults.object(forKey: key), let value = T.fromAny(anyValue) as T? {
            if let validation = validation {
                self._value = validation(value) ?? defaultValue
            } else {
                self._value = value
            }
        } else {
            self._value = defaultValue
        }
        self.onChange = onChange
        self.validation = validation
        self.defaultValue = defaultValue
    }
    
    func getUpdatedValueFromUserDefaults() -> T {
        if let anyValue = UserDefaultsValue.defaults.object(forKey: key), let value = T.fromAny(anyValue) as T? {
            if let validation = validation {
                return validation(value) ?? defaultValue
            } else {
                return value
            }
        } else {
            return defaultValue
        }
    }
    /// Insert this value in a group, useful for observing changes in the whole group, instead of particular values
    func group(_ groupName: String) -> Self {
        UserDefaultsValueGroups.add(self, to: groupName)
        return self
    }
    
    /// register observers, will be notified when value changes
    @discardableResult
    func observeChanges(using closure: @escaping(T) -> Void) -> ObservationToken {
        
        let id = UUID()
        observers[id] = closure
        
        return ObservationToken { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }
}
