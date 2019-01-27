//
//  AnyConvertible.swift
//  nightguard
//
//  Created by Florian Preknya on 1/27/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation

protocol AnyConvertible {
    func toAny() -> Any
    static func fromAny(_ anyValue: Any) -> Self?
}

// common type implementations
extension Bool: AnyConvertible {
    func toAny() -> Any {
        return self
    }
    
    static func fromAny(_ anyValue: Any) -> Bool? {
        return anyValue as? Bool
    }
}

extension String: AnyConvertible {
    func toAny() -> Any {
        return self
    }
    
    static func fromAny(_ anyValue: Any) -> String? {
        return anyValue as? String
    }
}

extension Int: AnyConvertible {
    func toAny() -> Any {
        return self
    }
    
    static func fromAny(_ anyValue: Any) -> Int? {
        return anyValue as? Int
    }
}

extension Float: AnyConvertible {
    func toAny() -> Any {
        return self
    }
    
    static func fromAny(_ anyValue: Any) -> Float? {
        return anyValue as? Float
    }
}

extension Double: AnyConvertible {
    func toAny() -> Any {
        return self
    }
    
    static func fromAny(_ anyValue: Any) -> Double? {
        return anyValue as? Double
    }
}

extension Date: AnyConvertible {
    func toAny() -> Any {
        return self
    }
    
    static func fromAny(_ anyValue: Any) -> Date? {
        return anyValue as? Date
    }
}

extension Data: AnyConvertible {
    func toAny() -> Any {
        return self
    }
    
    static func fromAny(_ anyValue: Any) -> Data? {
        return anyValue as? Data
    }
}


//extension Array: AnyConvertible {
//    func toAny() -> Any {
//        return self
//    }
//
//    static func fromAny(_ anyValue: Any) -> Array? {
//        return anyValue as? Array
//    }
//}

extension Array: AnyConvertible where Element: AnyConvertible {
    func toAny() -> Any {
        return self.map { $0.toAny() }
    }
    
    static func fromAny(_ anyValue: Any) -> Array? {
        return (anyValue as? Array)?.compactMap { Element.fromAny($0) }
    }
}
