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
    
    
    func storeHistoricBgData(_ historicBgData : [BloodSugar]) {
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.set(NSKeyedArchiver.archivedData(withRootObject: historicBgData), forKey: "historicBgData")
    }
    
    func loadHistoricBgData() -> [BloodSugar] {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => return dummy-Data
            return []
        }
        
        guard let data = defaults.object(forKey: "historicBgData") as? Data else {
            return []
        }
        
        guard let historicBgData = NSKeyedUnarchiver.unarchiveObject(with: data) as? [BloodSugar] else {
            return []
        }
        return historicBgData
    }
}
