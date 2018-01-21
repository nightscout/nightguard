//
//  UserDefaults.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 27.12.15.
//  Copyright © 2015 private. All rights reserved.
//

import Foundation

// Repository to store BgData using the NSUserDefaults
class NightscoutDataRepository {
    
    static let singleton = NightscoutDataRepository()
    
    struct Constants {
        static let currentBgData = "currentBgData"
        static let todaysBgData = "todaysBgData"
        static let yesterdaysBgData = "yesterdaysBgData"
        static let yesterdaysDayOfTheYear = "yesterdaysDayOfTheYear"
    }
    
    func clearAll() {
         let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults?.removeObject(forKey: Constants.currentBgData)
        defaults?.removeObject(forKey: Constants.todaysBgData)
        defaults?.removeObject(forKey: Constants.yesterdaysBgData)
        defaults?.removeObject(forKey: Constants.yesterdaysDayOfTheYear)
        // this shouldn't be necessary anymore - remove it later
        defaults?.synchronize()
    }
    
    func storeCurrentNightscoutData(_ bgData : NightscoutData) {
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.set(NSKeyedArchiver.archivedData(withRootObject: bgData), forKey: Constants.currentBgData)
    }
    
    func loadCurrentNightscoutData() -> NightscoutData {
        
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => return dummy-Data
            return NightscoutData()
        }
        
        guard let data = defaults.object(forKey: Constants.currentBgData) as? Data else {
            return NightscoutData()
        }
        
        return NSKeyedUnarchiver.unarchiveObject(with: data) as! NightscoutData
    }
    
    func storeTodaysBgData(_ todaysBgData : [BloodSugar]) {
        
        storeBgData(keyName: Constants.todaysBgData, todaysBgData)
    }
    
    func loadTodaysBgData() -> [BloodSugar] {
        
        return loadBgData(keyName: Constants.todaysBgData)
    }
    
    func storeYesterdaysBgData(_ yesterdaysBgData : [BloodSugar]) {
        
        storeBgData(keyName: Constants.yesterdaysBgData, yesterdaysBgData)
    }
    
    func loadYesterdaysBgData() -> [BloodSugar] {
        
        return loadBgData(keyName: Constants.yesterdaysBgData)
    }
    
    func loadYesterdaysDayOfTheYear() -> Int {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => return dummy-Data
            return -1
        }
        
        return defaults.integer(forKey: Constants.yesterdaysDayOfTheYear)
    }
    
    func storeYesterdaysDayOfTheYear(yesterdaysDayOfTheYear : Int) {
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.set(yesterdaysDayOfTheYear, forKey: Constants.yesterdaysDayOfTheYear)
    }
    
    fileprivate func storeBgData(keyName : String, _ bgData : [BloodSugar]) {
        
        print("Storing \(bgData.count) using key \(keyName)")
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.set(NSKeyedArchiver.archivedData(withRootObject: bgData), forKey: keyName)
    }
    
    fileprivate func loadBgData(keyName : String) -> [BloodSugar] {
        
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => return dummy-Data
            return []
        }
        
        guard let data = defaults.object(forKey: keyName) as? Data else {
            return []
        }
        
        guard let bgData = NSKeyedUnarchiver.unarchiveObject(with: data) as? [BloodSugar] else {
            return []
        }
        return bgData
    }
}
