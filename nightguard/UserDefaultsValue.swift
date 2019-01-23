//
//  UserDefaultsValue.swift
//  nightguard
//
//  Created by Florian Preknya on 1/23/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation

class UserDefaultsValue<T> {
    
    let key: String
    
    var value: T {
        didSet {
            let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)!
            defaults.setValue(value, forKey: key)
        }
    }
    
    init(key: String, default defaultValue: T) {
        self.key = key
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)!
        if let anyValue = defaults.object(forKey: key), let value = UserDefaultsValue.fromAny(anyValue) {
            self.value = value
        } else {
            self.value = defaultValue
        }
    }
    
    class func fromAny(_ anyValue: Any) -> T? {
        return anyValue as? T
    }
}
