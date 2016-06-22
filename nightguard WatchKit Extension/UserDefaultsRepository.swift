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