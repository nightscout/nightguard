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
    static func toDisplayUnits(_ value : String) -> String {
        
        if value == "---" {
            return value
        }
        
        let units = UserDefaultsRepository.units.value
        if units == Units.mgdl {
            return removeDecimals(value)
        }
        
        // convert mg/dL to mmol/l
        let floatValue : Float = Float(value)! * 0.0555
        return String(floatValue.cleanValue)
    }
    
    // Converts the internally mg/dL to mmol if thats the defined
    // Unit to be used.
    static func toDisplayUnits(_ value : Float) -> Float {
        
        let units = UserDefaultsRepository.units.value
        if units == Units.mgdl {
            return removeDecimals(value)
        }
        
        // convert mg/dL to mmol/l
        return value * 0.0555
    }
    
    static func toDisplayUnits(_ value : CGFloat) -> CGFloat {
        
        return CGFloat(toDisplayUnits(Float(value)))
    }
    
    static func toDisplayUnits(_ mgValues : [BloodSugar]) -> [BloodSugar] {
        
        let units = UserDefaultsRepository.units.value
        if units == Units.mgdl {
            return mgValues
        }
        
        var mmolValues : [BloodSugar] = []
        for value in mgValues {
            mmolValues.append(toMmol(value))
        }
        
        return mmolValues
    }
    
    static func toDisplayUnits(_ days : [[BloodSugar]]) -> [[BloodSugar]] {
        
        var newDays : [[BloodSugar]] = []
        
        for day in days {
            newDays.append(toDisplayUnits(day))
        }
        
        return newDays
    }
    
    static func toMmol(_ bloodSugar : BloodSugar) -> BloodSugar {
        
        return BloodSugar.init(value: toMmol(bloodSugar.value), timestamp: bloodSugar.timestamp)
    }
    
    static func toMmol(_ mmolValue : Float) -> Float {
        return mmolValue * 0.0555
    }
    
    // Converts the value in Display Units to Mg/dL.
    static func toMgdl(_ value : Float) -> Float {
        let units = UserDefaultsRepository.units.value
        if units == Units.mgdl {
            return removeDecimals(value)
        }
        
        // convert mmol/l to mg/dL
        return value * 18.02
    }
    
    // Converts the value in Display Units to Mg/dL.
    static func toMgdl(_ value : String) -> Float {
        
        guard let floatValue = Float(value.trimmingCharacters(in: CharacterSet.whitespaces)) else {
            return 0
        }
        return toMgdl(floatValue)
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
