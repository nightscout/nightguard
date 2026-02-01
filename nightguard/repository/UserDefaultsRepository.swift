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
        onChange: { _ in
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
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
    
    static let alarmSoundUri = UserDefaultsValue<String>(
        key: "alarmSoundUri",
        default: "",
        validation: { alarmSoundUri in
            let trimmedUri = uriWithoutTrailingSlashes(alarmSoundUri).trimmingCharacters(
                in: CharacterSet.whitespacesAndNewlines)
            
            if (!validateUrl(trimmedUri)) {
                return ""
            }
            
            return trimmedUri
        })
    
    static let alarmSoundFileName = UserDefaultsValue<String>(
        key: "alarmSoundFileName",
        default: "")
    
    static let alarmNotificationState = UserDefaultsValue<Bool>(key: "alarmNotificationState", default: false)
    
    // If this is set to true, you can override the default units setting from your backend
    static let manuallySetUnits = UserDefaultsValue<Bool>(key: "manuallySetUnits", default: false)
    
    // Returns true if the units (mmol or mg/dL) have already been retrieved
    // from the nightscout backend
    static let units = UserDefaultsValue<Units>(key: "units", default: Units.mmol)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
    
    // The last watch sync update id
    static let lastWatchSyncUpdateId = UserDefaultsValue<String>(key: "lastWatchSyncUpdateId", default: "")
    
    // the array defining what days should be displayed in the statistics view
    // E.g. [true, true, true, true, true] if all 5 days should be displayed
    static let daysToBeDisplayed = UserDefaultsValue<[Bool]>(key: "daysToBeDisplayed", default: [true, true, true, true, true])
    
    // blood glucose upper/lower bounds (definition of user's bg range)
    static let upperBound = UserDefaultsValue<Float>(key: "upperBound", default: (UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.object(forKey: "alertIfAboveValue") as? Float) ?? 180)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
    static let lowerBound = UserDefaultsValue<Float>(key: "lowerBound", default: (UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.object(forKey: "alertIfBelowValue") as? Float) ?? 80)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)

    static let maximumBloodGlucoseDisplayed = UserDefaultsValue<Float>(key: "maximumBloodGlucoseDisplayed", default: 350)
    
    #if os(iOS)
    static let nightscoutUris = UserDefaultsValue<[String]>(key: "nightscoutUris", default: [])
    
    // minutes of idle (user inactivity) before dimming the screen (0 means never)
    static let dimScreenWhenIdle = UserDefaultsValue<Int>(key: "dimScreenWhenIdle", default: 0)

    // quick snooze options
    static let shakingOnAlertSnoozeOption = UserDefaultsValue<QuickSnoozeOption>(key: "shakingOnAlertSnoozeOption", default: .doNothing)
    static let volumeKeysOnAlertSnoozeOption = UserDefaultsValue<QuickSnoozeOption>(key: "volumeKeysOnAlertSnoozeOption", default: .doNothing)
    #endif
    
    // show/hide stats
    static let showStats = UserDefaultsValue<Bool>(key: "showStats", default: true)
    
    // show/hide Care and Loop Data
    static let showCareAndLoopData = UserDefaultsValue<Bool>(key: "showCareAndLoopData", default: true)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
    
    // show Yesterdays BGs in the chart
    static let showYesterdaysBgs = UserDefaultsValue<Bool>(key: "showYesterdaysBgs", default: true)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
    
    // check BG every minute
    static let checkBGEveryMinute = UserDefaultsValue<Bool>(key: "checkBGEveryMinute", default: false)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)

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
        guard var urlComponents = URLComponents(string: String(describing: requestUri)) else {
            return nil
        }
        urlComponents.queryItems = []
        for (queryParam, queryValue) in queryParams {
            urlComponents.queryItems?.append(URLQueryItem(name: queryParam, value: queryValue))
        }

        if (token != nil) {
            urlComponents.queryItems?.append(URLQueryItem(name: "token", value: String(describing: token!)))
        }
        print(urlComponents.url ?? "")
        return urlComponents.url
    }
    
    static let temporaryTargetReason = UserDefaultsValue<String>(key: "temporaryTargetReason", default: (UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.object(forKey: "temporaryTargeReasont") as? String) ?? "Too Low")
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
    
    static let temporaryTargetDuration = UserDefaultsValue<Int>(key: "temporaryTargetDuration", default: (UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.object(forKey: "temporaryTargetDuration") as? Int) ?? 60)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
    
    static let temporaryTargetAmount = UserDefaultsValue<Int>(key: "temporaryTargetAmount", default: (UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.object(forKey: "temporaryTargetAmount") as? Int) ?? 72)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
    
    
    static let temporaryTargetActivityDefaultAmount = UserDefaultsValue<Int>(key: "temporaryTargetActivityDefaultAmount", default: (UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.object(forKey: "temporaryTargetActivityDefaultAmount") as? Int) ?? 130)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
    
    static let temporaryTargetTooLowDefaultAmount = UserDefaultsValue<Int>(key: "temporaryTargetTooLowDefaultAmount", default: (UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.object(forKey: "temporaryTargetTooLowDefaultAmount") as? Int) ?? 120)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
    
    static let temporaryTargetTooHighDefaultAmount = UserDefaultsValue<Int>(key: "temporaryTargetTooHighDefaultAmount", default: (UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.object(forKey: "temporaryTargetTooHighDefaultAmount") as? Int) ?? 72)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
    
    static let temporaryTargetMealSoonDefaultAmount = UserDefaultsValue<Int>(key: "temporaryTargetMealSoonDefaultAmount", default: (UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.object(forKey: "temporaryTargetMealSoonDefaultAmount") as? Int) ?? 80)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)


    static let temporaryTargetActivityDefaultDuration = UserDefaultsValue<Int>(key: "temporaryTargetActivityDefaultDuration", default: (UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.object(forKey: "temporaryTargetActivityDefaultDuration") as? Int) ?? 120)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
    
    static let temporaryTargetTooLowDefaultDuration = UserDefaultsValue<Int>(key: "temporaryTargetTooLowDefaultDuration", default: (UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.object(forKey: "temporaryTargetTooLowDefaultDuration") as? Int) ?? 60)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
    
    static let temporaryTargetTooHighDefaultDuration = UserDefaultsValue<Int>(key: "temporaryTargetTooHighDefaultDuration", default: (UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.object(forKey: "temporaryTargetTooHighDefaultDuration") as? Int) ?? 60)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
    
    static let temporaryTargetMealSoonDefaultDuration = UserDefaultsValue<Int>(key: "temporaryTargetMealSoonDefaultDuration", default: (UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.object(forKey: "temporaryTargetMealSoonDefaultDuration") as? Int) ?? 60)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
    
    static func getDefaultTemporaryTargetAmountForReason() -> Int {
        
        switch UserDefaultsRepository.temporaryTargetReason.value {
            case "Activity":
                return UserDefaultsRepository.temporaryTargetActivityDefaultAmount.value
            case "Too High":
                return UserDefaultsRepository.temporaryTargetTooHighDefaultAmount.value
            case "Too Low":
                return UserDefaultsRepository.temporaryTargetTooLowDefaultAmount.value
            case "Meal Soon":
                return UserDefaultsRepository.temporaryTargetMealSoonDefaultAmount.value
            default:
                return UserDefaultsRepository.temporaryTargetActivityDefaultAmount.value
        }
    }
    
    static func getDefaultTemporaryTargetDurationForReason() -> Int {
        
        switch UserDefaultsRepository.temporaryTargetReason.value {
            case "Activity":
                return UserDefaultsRepository.temporaryTargetActivityDefaultDuration.value
            case "Too High":
                return UserDefaultsRepository.temporaryTargetTooHighDefaultDuration.value
            case "Too Low":
                return UserDefaultsRepository.temporaryTargetTooLowDefaultDuration.value
            case "Meal Soon":
                return UserDefaultsRepository.temporaryTargetMealSoonDefaultDuration.value
            default:
                return UserDefaultsRepository.temporaryTargetActivityDefaultDuration.value
        }
    }
    
    static let carbs = UserDefaultsValue<Int>(key: "carbs", default: (UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.object(forKey: "carbs") as? Int) ?? 3)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
    
    // Definition of the Age Colors

    static let sensorAgeHoursUntilWarning = UserDefaultsValue<Int>(
        key: "sensorAgeHoursUntilWarning",
        default: 216,  // 9 days
        validation: { value in
            // Round to full 24-hour blocks (full days)
            return (value + 12) / 24 * 24
        })
        .group(UserDefaultsValueGroups.GroupNames.watchSync)

    static let cannulaAgeHoursUntilWarning = UserDefaultsValue<Int>(
        key: "cannulaAgeHoursUntilWarning",
        default: 44)  // ~1.8 days
        .group(UserDefaultsValueGroups.GroupNames.watchSync)

    static let batteryAgeHoursUntilWarning = UserDefaultsValue<Int>(
        key: "batteryAgeHoursUntilWarning",
        default: 24 * 6,  // 6 days
        validation: { value in
            // Round to full 24-hour blocks (full days)
            return (value + 12) / 24 * 24
        })
        .group(UserDefaultsValueGroups.GroupNames.watchSync)

    static let sensorAgeHoursUntilCritical = UserDefaultsValue<Int>(
        key: "sensorAgeHoursUntilCritical",
        default: 24 * 13,  // 13 days
        validation: { value in
            // Round to full 24-hour blocks (full days)
            return (value + 12) / 24 * 24
        })
        .group(UserDefaultsValueGroups.GroupNames.watchSync)

    static let cannulaAgeHoursUntilCritical = UserDefaultsValue<Int>(
        key: "cannulaAgeHoursUntilCritical",
        default: 68)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)

    static let batteryAgeHoursUntilCritical = UserDefaultsValue<Int>(
        key: "batteryAgeHoursUntilCritical",
        default: 24 * 30,  // 30 days
        validation: { value in
            // Round to full 24-hour blocks (full days)
            return (value + 12) / 24 * 24
        })
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
    
    static let treatments = UserDefaultsValue<[Treatment]>(key: "treatments", default: (UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.object(forKey: "treatments") as? [Treatment]) ?? [])
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
    
    // Has the user seen the App Tour?
    static let appTourSeen = UserDefaultsValue<Bool>(key: "appTourSeen", default: false)
    
    // Has the user seen the disclaimer? (Mainly used for UI testing)
    static let disclaimerSeen = UserDefaultsValue<Bool>(key: "disclaimerSeen", default: false)
    
    static let currentTab = UserDefaultsValue<TabIdentifier>(key: "rootTabView.currentTab", default: .main)

    static let appleHealthLastSyncDate = UserDefaultsValue<Date>(key: "appleHealthLastSyncDate", default: .distantPast)

    // Pro Promotion
    static let proPromotionNotNowVersion = UserDefaultsValue<String>(key: "proPromotionNotNowVersion", default: "")
    static let proPromotionLastSeen = UserDefaultsValue<Date>(key: "proPromotionLastSeen", default: .distantPast)
}

enum TabIdentifier: String, CaseIterable, AnyConvertible, Equatable, Identifiable {
    case main = "main"
    case alarms = "alarms"
    case care = "care"
    case duration = "duration"
    case stats = "stats"
    case prefs = "prefs"
    
    var id: String { rawValue }

    // Default value
    static let defaultValue: TabIdentifier = .main
    
    // MARK: - AnyConvertible
    
    func toAny() -> Any {
        return self.rawValue
    }
    
    static func fromAny(_ anyValue: Any) -> TabIdentifier? {
        if let rawValue = anyValue as? String {
            return TabIdentifier(rawValue: rawValue)
        }
        
        // Migration support for old Int values
        if let intValue = anyValue as? Int {
            switch intValue {
            case 0: return .main
            case 1: return .alarms
            case 2: return .care
            case 3: return .duration
            case 4: return .stats
            case 5: return .prefs
            default: return .main
            }
        }
        
        return nil
    }
}
