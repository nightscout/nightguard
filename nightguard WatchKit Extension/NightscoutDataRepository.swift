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
    
    func storeCurrentNightscoutData(_ bgData : NightscoutData) {
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.set(NSKeyedArchiver.archivedData(withRootObject: bgData), forKey: "currentBgData")
    }
    
    func loadCurrentNightscoutData() -> NightscoutData {
        
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => return dummy-Data
            return NightscoutData()
        }
        
        guard let data = defaults.object(forKey: "currentBgData") as? Data else {
            return NightscoutData()
        }
        
        return NSKeyedUnarchiver.unarchiveObject(with: data) as! NightscoutData
    }
    
    func storeTodaysBgData(_ todaysBgData : [BloodSugar]) {
        
        storeBgData(keyName: "todaysBgData", todaysBgData)
    }
    
    func loadTodaysBgData() -> [BloodSugar] {
        
        return loadBgData(keyName: "todaysBgData")
    }
    
    func storeYesterdaysBgData(_ yesterdaysBgData : [BloodSugar]) {
        
        storeBgData(keyName: "yesterdaysBgData", yesterdaysBgData)
    }
    
    func loadYesterdaysBgData() -> [BloodSugar] {
        
        return loadBgData(keyName: "yesterdaysBgData")
    }
    
    func loadYesterdaysDayOfTheYear() -> Int {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => return dummy-Data
            return -1
        }
        
        return defaults.integer(forKey: "yesterdaysDayOfTheYear")
    }
    
    func storeYesterdaysDayOfTheYear(yesterdaysDayOfTheYear : Int) {
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.set(yesterdaysDayOfTheYear, forKey: "yesterdaysDayOfTheYear")
    }
    
    fileprivate func storeBgData(keyName : String, _ todaysBgData : [BloodSugar]) {
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.set(NSKeyedArchiver.archivedData(withRootObject: todaysBgData), forKey: keyName)
    }
    
    fileprivate func loadBgData(keyName : String) -> [BloodSugar] {
        
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => return dummy-Data
            return []
        }
        
        guard let data = defaults.object(forKey: keyName) as? Data else {
            return []
        }
        
        guard let todaysBgData = NSKeyedUnarchiver.unarchiveObject(with: data) as? [BloodSugar] else {
            return []
        }
        return todaysBgData
    }
}
