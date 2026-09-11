//
//  UserDefaults.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 30.12.15.
//  Copyright © 2015 private. All rights reserved.
//

import Foundation
import Security
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
    fileprivate static var legacyToken: String?
    static var credentialStore: NightscoutCredentialStoring = NightscoutCredentialStore.shared
    
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

    static let watchProAccessAvailable = UserDefaultsValue<Bool>(key: "watchProAccessAvailable", default: false)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)
    
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
    static func parseBaseUri() {
        url = nil
        legacyToken = nil
        let urlString = baseUri.value
        if !urlString.isEmpty {
            guard let parsedURL = URL(string: urlString) else { return }
            legacyToken = normalizedToken(parsedURL.valueOf("token") ?? "")

            if let token = legacyToken, !token.isEmpty,
               let cleanURL = removingToken(from: parsedURL) {
                if credentialStore.setToken(token, for: cleanURL) {
                    url = cleanURL
                    if cleanURL.absoluteString != urlString {
                        baseUri.value = cleanURL.absoluteString
                    }
                } else {
                    // Do not remove the only durable copy of the credential.
                    // Keeping the legacy URL lets the app use the in-memory
                    // fallback and retry the migration on the next launch.
                    url = parsedURL
                }
            } else {
                url = parsedURL
            }
        }
        #if os(iOS)
        migrateLegacyURIHistory()
        #endif
    }

    static var nightscoutToken: String {
        if url == nil {
            parseBaseUri()
        }
        guard let serverURL = url else { return legacyToken ?? "" }
        return credentialStore.token(for: serverURL) ?? legacyToken ?? ""
    }

    @discardableResult
    static func setNightscoutCredentials(baseURL: URL, token: String) -> Bool {
        let cleanURL = removingToken(from: baseURL) ?? baseURL
        let explicitToken = normalizedToken(token)
        let embeddedToken = normalizedToken(baseURL.valueOf("token") ?? "")
        let trimmedToken = explicitToken.isEmpty ? embeddedToken : explicitToken
        let didStore = trimmedToken.isEmpty
            ? credentialStore.removeToken(for: cleanURL)
            : credentialStore.setToken(trimmedToken, for: cleanURL)
        guard didStore else { return false }

        legacyToken = nil
        url = cleanURL
        baseUri.value = cleanURL.absoluteString
        return true
    }

    static func storeSyncedNightscoutToken(_ token: String) {
        if url == nil {
            parseBaseUri()
        }
        guard let serverURL = url else { return }
        let trimmedToken = normalizedToken(token)
        if trimmedToken.isEmpty {
            _ = credentialStore.removeToken(for: serverURL)
        } else {
            _ = credentialStore.setToken(trimmedToken, for: serverURL)
        }
        legacyToken = nil
    }

    static func cleanBaseURL() -> URL? {
        if url == nil {
            parseBaseUri()
        }
        guard let currentURL = url else { return nil }
        return removingToken(from: currentURL) ?? currentURL
    }

    static func authenticatedWebURL() -> URL? {
        guard let baseURL = cleanBaseURL() else { return nil }
        let token = nightscoutToken
        guard !token.isEmpty, var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return baseURL
        }
        var items = components.queryItems ?? []
        items.removeAll { $0.name == "token" }
        items.append(URLQueryItem(name: "token", value: token))
        components.queryItems = items
        return components.url
    }

    private static func removingToken(from sourceURL: URL) -> URL? {
        guard var components = URLComponents(url: sourceURL, resolvingAgainstBaseURL: false) else { return nil }
        let remainingItems = (components.queryItems ?? []).filter { $0.name != "token" }
        components.queryItems = remainingItems.isEmpty ? nil : remainingItems
        return components.url
    }

    private static func normalizedToken(_ token: String) -> String {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("token=") ? String(trimmed.dropFirst("token=".count)) : trimmed
    }

    #if os(iOS)
    private static func migrateLegacyURIHistory() {
        let existing = nightscoutUris.value
        let migrated = existing.map { uri -> String in
            guard let parsedURL = URL(string: uri),
                  let cleanURL = removingToken(from: parsedURL),
                  let token = parsedURL.valueOf("token"),
                  !token.isEmpty,
                  credentialStore.setToken(normalizedToken(token), for: cleanURL) else {
                return uri
            }
            return cleanURL.absoluteString
        }
        if migrated != existing {
            nightscoutUris.value = Array(migrated.prefix(5))
        }
    }
    #endif
    
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
        var queryItems = (urlComponents.queryItems ?? []).filter {
            $0.name != "token" && queryParams[$0.name] == nil
        }
        queryItems.append(contentsOf: queryParams.sorted(by: { $0.key < $1.key }).map {
            URLQueryItem(name: $0.key, value: $0.value)
        })

        let token = nightscoutToken
        if !token.isEmpty {
            queryItems.append(URLQueryItem(name: "token", value: token))
        }
        urlComponents.queryItems = queryItems.isEmpty ? nil : queryItems
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

    static let reservoirUnitsWarning = UserDefaultsValue<Int>(
        key: "reservoirUnitsWarning",
        default: 70)
        .group(UserDefaultsValueGroups.GroupNames.watchSync)

    static let reservoirUnitsCritical = UserDefaultsValue<Int>(
        key: "reservoirUnitsCritical",
        default: 50)
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
    
    // App Review
    static let reviewFirstSuccessfulUseDate = UserDefaultsValue<Date>(key: "reviewFirstSuccessfulUseDate", default: .distantPast)
    static let reviewLastPromptDate = UserDefaultsValue<Date>(key: "reviewLastPromptDate", default: .distantPast)
    static let reviewDeclinedForever = UserDefaultsValue<Bool>(key: "reviewDeclinedForever", default: false)

    static func shouldShowProPromotion(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let lastSeen = proPromotionLastSeen.value

        guard lastSeen != .distantPast else {
            return true
        }

        return !calendar.isDate(lastSeen, equalTo: now, toGranularity: .month)
    }

    static func markProPromotionSeen(at date: Date = Date()) {
        proPromotionLastSeen.value = date
    }
    
    static func markReviewFirstSuccessfulUseIfNeeded(at date: Date = Date()) {
        guard reviewFirstSuccessfulUseDate.value == .distantPast else {
            return
        }
        
        reviewFirstSuccessfulUseDate.value = date
    }
    
    static func markReviewPromptShown(at date: Date = Date()) {
        reviewLastPromptDate.value = date
    }
    
    static func markReviewDeclinedForever() {
        reviewDeclinedForever.value = true
    }
    
    static func shouldShowReviewPrompt(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard !reviewDeclinedForever.value else {
            return false
        }
        
        let firstSuccessfulUseDate = reviewFirstSuccessfulUseDate.value
        guard firstSuccessfulUseDate != .distantPast else {
            return false
        }
        
        guard let earliestPromptDate = calendar.date(byAdding: .day, value: 14, to: firstSuccessfulUseDate),
              now > earliestPromptDate else {
            return false
        }
        
        let lastPromptDate = reviewLastPromptDate.value
        guard lastPromptDate == .distantPast || !calendar.isDate(lastPromptDate, equalTo: now, toGranularity: .month) else {
            return false
        }
        
        return true
    }

    static func initializeSyncValues() {
        _ = baseUri
        _ = units
        _ = upperBound
        _ = lowerBound
        _ = showCareAndLoopData
        _ = showYesterdaysBgs
        _ = checkBGEveryMinute
        _ = temporaryTargetReason
        _ = temporaryTargetDuration
        _ = temporaryTargetAmount
        _ = temporaryTargetActivityDefaultAmount
        _ = temporaryTargetTooLowDefaultAmount
        _ = temporaryTargetTooHighDefaultAmount
        _ = temporaryTargetMealSoonDefaultAmount
        _ = temporaryTargetActivityDefaultDuration
        _ = temporaryTargetTooLowDefaultDuration
        _ = temporaryTargetTooHighDefaultDuration
        _ = temporaryTargetMealSoonDefaultDuration
        _ = carbs
        _ = sensorAgeHoursUntilWarning
        _ = cannulaAgeHoursUntilWarning
        _ = batteryAgeHoursUntilWarning
        _ = sensorAgeHoursUntilCritical
        _ = cannulaAgeHoursUntilCritical
        _ = batteryAgeHoursUntilCritical
        _ = reservoirUnitsWarning
        _ = reservoirUnitsCritical
        _ = treatments
        _ = reviewFirstSuccessfulUseDate
        _ = reviewLastPromptDate
        _ = reviewDeclinedForever
        _ = watchProAccessAvailable
    }
}

protocol NightscoutCredentialStoring: AnyObject {
    func token(for serverURL: URL) -> String?
    func setToken(_ token: String, for serverURL: URL) -> Bool
    func removeToken(for serverURL: URL) -> Bool
}

final class NightscoutCredentialStore: NightscoutCredentialStoring {
    static let shared = NightscoutCredentialStore()

    private let service = "de.my-wan.dhe.nightguard.nightscout-token"
    private let accessGroup = "C8JJ9Q567Z.de.my-wan.dhe.nightguard.shared"

    private init() {}

    func token(for serverURL: URL) -> String? {
        var query = baseQuery(for: serverURL)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    @discardableResult
    func setToken(_ token: String, for serverURL: URL) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }
        let query = baseQuery(for: serverURL)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        var item = query
        attributes.forEach { item[$0.key] = $0.value }
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    func removeToken(for serverURL: URL) -> Bool {
        let status = SecItemDelete(baseQuery(for: serverURL) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private func baseQuery(for serverURL: URL) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: credentialKey(for: serverURL)
        ]
        #if !targetEnvironment(simulator)
        query[kSecAttrAccessGroup as String] = accessGroup
        #endif
        return query
    }

    private func credentialKey(for serverURL: URL) -> String {
        guard var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false) else {
            return serverURL.absoluteString
        }
        let scheme = components.scheme?.lowercased()
        let host = components.host?.lowercased()
        let queryItems = components.queryItems?
            .filter { $0.name != "token" }
            .sorted {
                if $0.name == $1.name { return ($0.value ?? "") < ($1.value ?? "") }
                return $0.name < $1.name
            }
        components.scheme = scheme
        components.host = host
        components.queryItems = queryItems
        components.fragment = nil
        return components.url?.absoluteString ?? serverURL.absoluteString
    }
}

enum TabIdentifier: String, CaseIterable, AnyConvertible, Equatable, Identifiable {
    case main = "main"
    case alarms = "alarms"
    case care = "care"
    case duration = "duration"
    case stats = "stats"
    case prefs = "prefs"
    case subscribePro = "subscribePro"
    case subscribeMax = "subscribeMax"
    
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
