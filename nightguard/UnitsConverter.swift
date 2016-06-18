//
//  UnitsConverter.swift
//  nightguard
//
//  Created by Dirk Hermanns on 17.06.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation

// Converts mg/dL Unit to be displayed as mmol/l
// Internally, everything is handled as mg/dL, but the nightscout
// Backend can define that everything shold be displayed as mmol
class UnitsConverter {
    
    // Converts the internally mg/dL to mmol if thats the defined
    // Unit to be used.
    static func toDisplayUnits(value : String) -> String {
        
        if value == "---" {
            return value
        }
        
        let units = UserDefaultsRepository.readUnits()
        
        if units == Units.mgdl {
            return removeDecimals(value)
        }
        
        // convert mmol/l to mg/dL
        let floatValue : Float = Float(value)! * 0.0555
        return String(floatValue.cleanValue)
    }
    
    // Converts the internally mg/dL to mmol if thats the defined
    // Unit to be used.
    static func toDisplayUnits(value : Float) -> Float {
        let units = UserDefaultsRepository.readUnits()
        
        if units == Units.mgdl {
            return removeDecimals(value)
        }
        
        // convert mmol/l to mg/dL
        return value * 0.0555
    }
    
    // if a "." is contained, simply takes the left part of the string only
    static private func removeDecimals(value : String) -> String {
        if !value.containsString(".") {
            return value
        }
        
        return value.substringToIndex(value.characters.indexOf(".")!)
    }
    
    static private func removeDecimals(value : Float) -> Float {
        return Float(Int(value))
    }
}