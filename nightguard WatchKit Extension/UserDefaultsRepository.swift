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
        guard let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            return ""
        }
        
        guard let hostUri = defaults.stringForKey("hostUri") else {
            return ""
        }
        
        let trimmedUri = uriWithoutTrailingSlashes(hostUri).stringByTrimmingCharactersInSet(
            NSCharacterSet.whitespaceAndNewlineCharacterSet())
        
        if (!validateUrl(trimmedUri)) {
            return ""
        }
        
        return trimmedUri
    }
    
    static func saveBaseUri(baseUri : String) {
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(baseUri, forKey: "hostUri")
    }
    
    static func readUnits() -> Units {
        guard let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            print("Units are not saved so for. Assuming mg/dL in this case.")
            return Units.mgdl
        }
        
        guard let units = defaults.objectForKey("units") as? String else {
            print("Units are not saved so for. Assuming mg/dL in this case.")
            return Units.mgdl
        }
        return Units(rawValue: units)!
    }
    
    static func saveUnits(units : Units) {
        guard let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            return
        }
        
        defaults.setObject(units.rawValue, forKey: "units")
    }
    
    // Returns an array of which days should be displayed.
    // E.g. true, false, false, false, false if only the first day should be displayed
    // In the statistics view
    static func readDaysToBeDisplayed() -> [Bool] {
        guard let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            print("NSUserDefaults can't be accessed. Assuming that all 5 days should be displayed this case.")
            return [true, true, true, true, true]
        }
        
        guard let daysToDisplay = defaults.arrayForKey("daysToBeDisplayed") as? [Bool] else {
            print("DaysToDisplay are undefined so far. Assuming that all 5 days should be displayed this case.")
            return [true, true, true, true, true]
        }
        
        return daysToDisplay
    }
    
    // Stores an array defining what days should be displayed in the statistics view
    // E.g. [true, true, true, true, true] if all 5 days should be displayed
    static func saveDaysToBeDisplayed(daysToBeDisplayed : [Bool]) {
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setObject(daysToBeDisplayed, forKey: "daysToBeDisplayed")
    }
    
    private static func validateUrl(stringURL : NSString) -> Bool {
        
        // return nil if the URL has not a valid format
        let url : NSURL? = NSURL.init(string: stringURL as String)
        
        return url != nil
    }
    
    static func uriWithoutTrailingSlashes(hostUri : String) -> String {
        if !hostUri.hasSuffix("/") {
            return hostUri
        }
        
        return hostUri.substringToIndex(hostUri.endIndex.predecessor())
    }
}