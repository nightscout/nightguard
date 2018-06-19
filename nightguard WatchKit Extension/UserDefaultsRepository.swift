//
//  UserDefaults.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 30.12.15.
//  Copyright © 2015 private. All rights reserved.
//

import Foundation
import UIKit

/* 
 * This class provides access to general Application Data stored in the NSUserDefaults.
 * This is e.g. the Base-URI to the Nightscout Server.
 */
class UserDefaultsRepository {
    
    static func readBaseUri() -> String {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            return ""
        }
        
        guard let hostUri = defaults.string(forKey: "hostUri") else {
            return ""
        }
        
        let trimmedUri = uriWithoutTrailingSlashes(hostUri).trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines)
        
        if (!validateUrl(trimmedUri)) {
            return ""
        }
        
        return trimmedUri
    }
    
    static func saveBaseUri(_ baseUri : String) {
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(baseUri, forKey: "hostUri")
    }
    
    static func readShowRawBG() -> Bool {
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        return defaults?.bool(forKey: "showRawBG") ?? false
    }
    
    static func saveShowRawBG(_ showRawBG: Bool) {
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(showRawBG, forKey: "showRawBG")
    }
    
    // Returns true if the units (mmol or mg/dL) have already been retrieved
    // from the nightscout backend
    static func areUnitsDefined() -> Bool {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            return false
        }
        
        guard let _ = defaults.object(forKey: "units") as? String else {
            return false
        }
        return true
    }
    
    static func readUnits() -> Units {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            print("Units are not saved so far. Assuming mg/dL in this case.")
            return Units.mgdl
        }
        
        guard let units = defaults.object(forKey: "units") as? String else {
            print("Units are not saved so far. Assuming mg/dL in this case.")
            return Units.mgdl
        }
        return Units(rawValue: units)!
    }
    
    static func saveUnits(_ units : Units) {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            return
        }
        
        defaults.set(units.rawValue, forKey: "units")
    }
    
    // Returns an array of which days should be displayed.
    // E.g. true, false, false, false, false if only the first day should be displayed
    // In the statistics view
    static func readDaysToBeDisplayed() -> [Bool] {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            print("NSUserDefaults can't be accessed. Assuming that all 5 days should be displayed this case.")
            return [true, true, true, true, true]
        }
        
        guard let daysToDisplay = defaults.array(forKey: "daysToBeDisplayed") as? [Bool] else {
            print("DaysToDisplay are undefined so far. Assuming that all 5 days should be displayed this case.")
            return [true, true, true, true, true]
        }
        
        return daysToDisplay
    }
    
    // Stores an array defining what days should be displayed in the statistics view
    // E.g. [true, true, true, true, true] if all 5 days should be displayed
    static func saveDaysToBeDisplayed(_ daysToBeDisplayed : [Bool]) {
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.set(daysToBeDisplayed, forKey: "daysToBeDisplayed")
    }
    
    // Reads the defined value. The user would like to be alerted if the blood glucose
    // levels are above or below this range.
    static func readUpperLowerBounds() -> (upperBound : Float, lowerBound : Float) {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            print("Units are not saved so far. Assuming (180,80) in this case.")
            return (180, 80)
        }
        
        let upperBound = defaults.float(forKey: "alertIfAboveValue")
        if upperBound == 0 {
            // no values so for from the ios app received
            // => assume a default value in this case
            return (180, 80)
        }
        let lowerBound = defaults.float(forKey: "alertIfBelowValue")
        
        return (upperBound, lowerBound)
    }
    
    static func saveUpperLowerBounds(_ upperBounds : Float, lowerBounds : Float) {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            print("Upper/Lower Bounds can't be saved -> this should never happen!")
            return
        }
        
        defaults.set(upperBounds, forKey: "alertIfAboveValue")
        defaults.set(lowerBounds, forKey: "alertIfBelowValue")
    }
    
    static func saveMaximumBloodGlucoseDisplayed(_ maximumBloodGlucoseDisplayed : Float) {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            print("maximumBloodGlucoseDisplayedcan't be saved -> this should never happen!")
            return
        }
        
        defaults.set(maximumBloodGlucoseDisplayed, forKey: "maximumBloodGlucoseDisplayed")
    }
    
    static func readMaximumBloodGlucoseDisplayed() -> Float {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            print("NSUserdefaults can't be read. Assuming a maximumBloodGlucoseDisplayed of 350 in this case.")
            return 350
        }
        
        let value = defaults.float(forKey: "maximumBloodGlucoseDisplayed")
        if value == 0 {
            print("NSUserdefaults can't be read. Assuming a maximumBloodGlucoseDisplayed of 350 in this case.")
            return 350
        }
        return value
    }
    
    fileprivate static func validateUrl(_ stringURL : String) -> Bool {
        
        // return nil if the URL has not a valid format
        let url : URL? = URL.init(string: stringURL)
        
        return url != nil
    }
    
    static func uriWithoutTrailingSlashes(_ hostUri : String) -> String {
        if !hostUri.hasSuffix("/") {
            return hostUri
        }
        
        return String(hostUri[..<hostUri.index(before: hostUri.endIndex)])
    }
}
