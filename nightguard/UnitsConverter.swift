//
//  UnitsConverter.swift
//  nightguard
//
//  Created by Dirk Hermanns on 17.06.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation
import UIKit

// Converts mg/dL Unit to be displayed as mmol/l
// Internally, everything is handled as mg/dL, but the nightscout
// Backend can define that everything shold be displayed as mmol
class UnitsConverter {
    
    // Converts the internally mg/dL to mmol if thats the defined
    // Unit to be used.
    static func mgdlToDisplayUnits(_ value : String) -> String {
        
        if value == "---" {
            return value
        }
        
        // if the UI is locked, looks like we are not allowed to access the userdefaults
        // so do this on main Thread only:
        var units = Units.mmol
        //dispatchOnMain {
        units = Units.fromAny(UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.value(forKey: "units") ?? Units.mmol.rawValue) ?? Units.mmol
        //}
       
        if units == Units.mgdl {
            // nothing to do here - just remove decimals
            if value.contains(".") {
                return String(value.prefix(upTo: value.firstIndex(of: ".") ?? value.endIndex))
            }
            return value
        }
        
        return toMmol(value)
    }
    
    // Converts the internally mg/dL to mmol if thats the defined
    // Unit to be used. To save some space, the mmol values are rounded.
    // This is used to display the values on the circular complication
    static func mgdlToShortDisplayUnits(_ value : String) -> String {
        
        if value == "---" {
            return value
        }
        
        // if the UI is locked, looks like we are not allowed to access the userdefaults
        // so do this on main Thread only:
        var units = Units.mmol
        dispatchOnMain {
            units = UserDefaultsRepository.units.value
        }
       
        if units == Units.mgdl {
            // nothing to do here - just remove decimals
            if value.contains(".") {
                return String(value.prefix(upTo: value.firstIndex(of: ".") ?? value.endIndex))
            }
            return value
        }
        
        return toRoundedMmol(value)
    }
    
    static func mgdlToDisplayUnitsWithSign(_ value : String) -> String {
        
        let valueInDisplayUnits = mgdlToDisplayUnits(value)
        if valueInDisplayUnits == "---" {
            return valueInDisplayUnits
        }
        
        // add a sign
        guard let floatValue = Float(valueInDisplayUnits) else {
            return valueInDisplayUnits
        }
        
        if floatValue >= 0 {
            // remove .0 decimals and add a sign
            return "\(floatValue.cleanSignedValue)"
        }
        
        return valueInDisplayUnits
    }
    
    // Converts the internally mg/dL to mmol if thats the defined
    // Unit to be used.
    static func mgdlToDisplayUnits(_ value : Float) -> Float {
        
        // if the UI is locked, looks like we are not allowed to access the userdefaults
        // so do this on main Thread only:
        var units = Units.mmol
        dispatchOnMain {
            units = UserDefaultsRepository.units.value
        }
        
        if units == Units.mgdl {
            return removeDecimals(value)
        }
        
        // convert mg/dL to mmol/l
        return value * 0.0555
    }
    
    static func toMmol(_ mmolValue : Float) -> Float {
        return Float(mmolValue * 0.0555).round(to: 1)
    }
    
    static func toMmol(_ mgdlValue : String) -> String {
        
        guard let mmolValue = Float(mgdlValue) else {
            return "??"
        }
        return (mmolValue * 0.0555).cleanValue
    }
    
    static func toRoundedMmol(_ mgdlValue : String) -> String {
        
        guard let mmolValue = Float(mgdlValue) else {
            return "??"
        }
        return (mmolValue * 0.0555).round(to: 0).cleanValue
    }
    
    // Converts the value in Display Units to Mg/dL.
    static func displayValueToMgdl(_ value : Float) -> Float {
        let units = UserDefaultsRepository.units.value
        if units == Units.mgdl {
            return removeDecimals(value)
        }
        
        // convert mmol/l to mg/dL
        return value * 18.02
    }
    
    // Converts the value in Display Units to Mg/dL.
    static func displayValueToMgdl(_ value : String) -> Float {
        
        guard let floatValue = Float(value.trimmingCharacters(in: CharacterSet.whitespaces)) else {
            return 0
        }
        return displayValueToMgdl(floatValue)
    }
    
    static func mmolToMgdl(_ mmolValue : Float) -> Float {
        
        return mmolValue * 18.02
    }
    
    static func toMgdl(_ uncertainValue : String) -> String {
        
        guard var floatValue : Float = Float(uncertainValue) else {
            return uncertainValue
        }

        floatValue = floatValue * (1 / 0.0555)
        return String(floatValue.cleanValue)
    }
    
    // if a "." is contained, simply takes the left part of the string only
    static fileprivate func removeDecimals(_ value : String) -> String {
        if !value.contains(".") {
            return value
        }
        
        return String(value[..<value.firstIndex(of: ".")!])
    }
    
    static fileprivate func removeDecimals(_ value : Float) -> Float {
        return Float(Int(value))
    }
}
