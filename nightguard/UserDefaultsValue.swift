//
//  UserDefaultsValue.swift
//  nightguard
//
//  Created by Florian Preknya on 1/23/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation

class UserDefaultsValue<T: AnyConvertible & Equatable> {
    
    // user defaults
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
            
            let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)!
            defaults.setValue(value.toAny(), forKey: key)
            onValueChanged(oldValue: oldValue)
            onChange?()
        }
    }
    
    // is value already stored in UserDefaults?
    var exists: Bool {
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)!
        return defaults.object(forKey: key) != nil
    }
    
    private let onChange: (() -> ())?
    
    // validate & transform: giving the new value, validate it; if validations passes, return the new value; if fails, transform the value, returning a modified version or ... return nil and the change will not gonna happen
    private let validation: ((T) -> T?)?
    
    init(key: String, default defaultValue: T, onChange: (() -> Void)? = nil, validation: ((T) -> T?)? = nil) {
        self.key = key
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)!
        if let anyValue = defaults.object(forKey: key), let value = T.fromAny(anyValue) as T? {
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
    
    func onValueChanged(oldValue: T) {
    }
}

/// A type erased key-value
protocol DictionaryElement {
    var key: String { get }
    var anyValue: Any { get set }
}

class UserDefaultsSyncValue<T: AnyConvertible & Equatable>: UserDefaultsValue<T>, DictionaryElement {
    
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
    
    override init(key: String, default defaultValue: T, onChange: (() -> Void)? = nil, validation: ((T) -> T?)? = nil) {
        super.init(key: key, default: defaultValue, onChange: onChange, validation: validation)
        
        UserDefaultsSyncValuesRegistry.register(self)
    }

    override func onValueChanged(oldValue: T) {
        super.onValueChanged(oldValue: oldValue)
        
        if value != oldValue {
            UserDefaultsSyncValuesRegistry.valueChanged(self)
        }
    }
}

class UserDefaultsSyncValuesRegistry {
    
    class func register(_ syncValue: DictionaryElement) {
        syncValues.append(syncValue)
    }
    
    static var dictionary: [String: Any] {
        
        var dictionary = [String: Any]()
        for element in syncValues {
            dictionary[element.key] = element.anyValue
        }
        
        return dictionary
    }
    
    static var onValueChanged: ((DictionaryElement) -> Void)?
    
    class func valueChanged(_ syncValue: DictionaryElement) {
        onValueChanged?(syncValue)
    }
    
    class func updateSyncValues(from dictionary: [String: Any]) {
        for var syncValue in syncValues {
            if let value = dictionary[syncValue.key] {
                syncValue.anyValue = value
            }
        }
    }
    
    static private var syncValues: [DictionaryElement] = []
}
