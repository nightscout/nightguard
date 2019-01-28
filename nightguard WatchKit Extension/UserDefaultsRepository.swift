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
    
    fileprivate static var url: URL?
    fileprivate static var token: String?
    
    static let baseUri = UserDefaultsValue<String>(
        key: "hostUri",
        default: "",
        onChange: {
            parseBaseUri()
        },
            validation: { hostUri in
                let trimmedUri = uriWithoutTrailingSlashes(hostUri).trimmingCharacters(
                    in: CharacterSet.whitespacesAndNewlines)
                
                if (!validateUrl(trimmedUri)) {
                    return ""
                }
                
                return trimmedUri
        })
        .group(UserDefaultsValues.GroupNames.watchSync)
    
    static let showRawBG = UserDefaultsValue<Bool>(key: "showRawBG", default: false)
        .group(UserDefaultsValues.GroupNames.watchSync)
    static let showBGOnAppBadge = UserDefaultsValue<Bool>(key: "showBGOnAppBadge", default: false)
    static let alarmNotificationState = UserDefaultsValue<Bool>(key: "alarmNotificationState", default: false)
    
    // Returns true if the units (mmol or mg/dL) have already been retrieved
    // from the nightscout backend
    static let units = UserDefaultsValue<Units>(key: "units", default: Units.mgdl)
        .group(UserDefaultsValues.GroupNames.watchSync)
    
    // the array defining what days should be displayed in the statistics view
    // E.g. [true, true, true, true, true] if all 5 days should be displayed
    static let daysToBeDisplayed = UserDefaultsValue<[Bool]>(key: "daysToBeDisplayed", default: [true, true, true, true, true])
    
    // blood glucose upper/lower bounds (definition of user's bg range)
    static let upperBound = UserDefaultsValue<Float>(key: "upperBound", default: (UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.object(forKey: "alertIfAboveValue") as? Float) ?? 180)
        .group(UserDefaultsValues.GroupNames.watchSync)
    static let lowerBound = UserDefaultsValue<Float>(key: "lowerBound", default: (UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.object(forKey: "alertIfBelowValue") as? Float) ?? 80)
        .group(UserDefaultsValues.GroupNames.watchSync)

    static let maximumBloodGlucoseDisplayed = UserDefaultsValue<Float>(key: "maximumBloodGlucoseDisplayed", default: 350)
    
    /* Parses the URI entered in the UI and extracts the token if one is present. */
    fileprivate static func parseBaseUri() {
        url = nil
        token = nil
        let urlString = baseUri.value
        if !urlString.isEmpty {
            url = URL(string: urlString)!
            let tokenString = url?.valueOf("token")
            if ((tokenString) != nil) {
                token = String(describing: tokenString!)
                print(token!)
            }
        }
    }
    
    fileprivate static func validateUrl(_ stringURL : String) -> Bool {
        
        // return nil if the URL has not a valid format
        let url : URL? = URL.init(string: stringURL)
        
        return url != nil
    }
    
    fileprivate static func uriWithoutTrailingSlashes(_ hostUri : String) -> String {
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
