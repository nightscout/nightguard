//
//  Units.swift
//  nightguard
//
//  Created by Dirk Hermanns on 14.06.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation

enum Units : String {
    case mgdl = "mgdl"
    case mmol = "mmol"
}

extension Units: CustomStringConvertible {
    var description: String {
        
        switch self {
        case .mgdl:
            return "mg/dL"
        case .mmol:
            return "mmol/L"
        }
    }
}

extension Units: AnyConvertible {
    
    func toAny() -> Any {
        return rawValue
    }
    
    static func fromAny(_ anyValue: Any) -> Units? {
        guard let rawValue = anyValue as? String else {
            return nil
        }
        
        return Units(rawValue: rawValue)
    }
}
