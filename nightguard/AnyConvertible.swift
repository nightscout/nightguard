//
//  AnyConvertible.swift
//  nightguard
//
//  Created by Florian Preknya on 1/27/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation

/// A type that can be converted to/from Any 
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

extension UUID: AnyConvertible {
    func toAny() -> Any {
        return self.uuidString
    }
    
    static func fromAny(_ anyValue: Any) -> UUID? {
        guard let uuidString = anyValue as? String else {
            return nil
        }
        
        return UUID(uuidString: uuidString)
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

extension Optional: AnyConvertible where Wrapped: AnyConvertible {
    func toAny() -> Any {
        switch self {
        case .some(let value):
            return value.toAny()
        case .none:
            return self as Any
        }
    }
    
    static func fromAny(_ anyValue: Any) -> Optional<Wrapped>? {
        return Wrapped.fromAny(anyValue)
    }
}

