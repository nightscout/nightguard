//
//  UserDefaults.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 30.12.15.
//  Copyright © 2015 private. All rights reserved.
//

import Foundation
import UIKit


// https://stackoverflow.com/a/44806984
extension URL {
    func valueOf(_ queryParamaterName: String) -> String? {
        guard let url = URLComponents(string: self.absoluteString) else { return nil }
        return url.queryItems?.first(where: { $0.name == queryParamaterName })?.value
    }
}


/* 
 * This class provides access to general Application Data stored in the NSUserDefaults.
 * This is e.g. the Base-URI to the Nightscout Server.
 */
class UserDefaultsRepository {
    
    static var url: URL?
    static var token: String?

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
        parseBaseUri()
    }

    /* Parses the URI entered in the UI and extracts the token if one is present. */
    static func parseBaseUri() -> Void {
        url = nil
        token = nil
        let urlString = UserDefaultsRepository.readBaseUri()
        if !urlString.isEmpty {
            url = URL(string: urlString)!
            let tokenString = url?.valueOf("token")
            if ((tokenString) != nil) {
                token = String(describing: tokenString!)
                print(token!)
            }
        }
    }
    
    static let showRawBG = UserDefaultsValue<Bool>(key: "showRawBG", default: false)
    static let showBGOnAppBadge = UserDefaultsValue<Bool>(key: "showBGOnAppBadge", default: false)
    static let alarmNotificationState = UserDefaultsValue<Bool>(key: "alarmNotificationState", default: false)
    
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
    static let upperBound = UserDefaultsValue<Float>(key: "upperBound", default: (UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.object(forKey: "alertIfAboveValue") as? Float) ?? 180)
    static let lowerBound = UserDefaultsValue<Float>(key: "lowerBound", default: (UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.object(forKey: "alertIfBelowValue") as? Float) ?? 80)

    static let maximumBloodGlucoseDisplayed = UserDefaultsValue<Float>(key: "maximumBloodGlucoseDisplayed", default: 350)
    
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

    /* Construct the url from the URL entered in the UI, creates the URL from URLComponents and
     sets query parameters according to the passed in dictionary. */
    static func getUrlWithPathAndQueryParameters(path: String, queryParams: Dictionary<String, String>) -> URL? {
        if (url == nil) {
            parseBaseUri()
        }
        guard url != nil else {
            return nil
        }
        var requestUri = url!
        requestUri.appendPathComponent(path, isDirectory: false)
        var urlComponents = URLComponents(string: String(describing: requestUri))!
        urlComponents.queryItems = []
        for (queryParam, queryValue) in queryParams {
            urlComponents.queryItems?.append(URLQueryItem(name: queryParam, value: queryValue))
        }

        if (token != nil) {
            urlComponents.queryItems?.append(URLQueryItem(name: "token", value: String(describing: token!)))
        }
        print(urlComponents.url!)
        return urlComponents.url!
    }
}
