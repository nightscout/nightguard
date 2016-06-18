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
    
    func storeCurrentNightscoutData(bgData : NightscoutData) {
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setObject(NSKeyedArchiver.archivedDataWithRootObject(bgData), forKey: "currentBgData")
    }
    
    func loadCurrentNightscoutData() -> NightscoutData {
        guard let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => return dummy-Data
            return NightscoutData()
        }
        
        guard let data = defaults.objectForKey("currentBgData") as? NSData else {
            return NightscoutData()
        }
        
        let decodedObject : NightscoutData = NSKeyedUnarchiver.unarchiveObjectWithData(data) as! NightscoutData
        guard let nightscoutData : NightscoutData = decodedObject as NightscoutData else {
            return NightscoutData()
        }
        return nightscoutData
    }
    
    
    func storeHistoricBgData(historicBgData : [BloodSugar]) {
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setObject(NSKeyedArchiver.archivedDataWithRootObject(historicBgData), forKey: "historicBgData")
    }
    
    func loadHistoricBgData() -> [BloodSugar] {
        guard let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => return dummy-Data
            return []
        }
        
        guard let data = defaults.objectForKey("historicBgData") as? NSData else {
            return []
        }
        
        guard let historicBgData = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? [BloodSugar] else {
            return []
        }
        return historicBgData
    }
}