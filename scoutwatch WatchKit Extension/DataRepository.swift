//
//  UserDefaults.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 27.12.15.
//  Copyright © 2015 private. All rights reserved.
//

import Foundation

// Repository to store BgData using the NSUserDefaults
class DataRepository {
    
    static let singleton = DataRepository()
    
    func storeCurrentBgData(bgData : BgData) {
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setObject(NSKeyedArchiver.archivedDataWithRootObject(bgData), forKey: "currentBgData")
    }
    
    func loadCurrentBgData() -> BgData {
        guard let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => return dummy-Data
            return BgData()
        }
        
        guard let data = defaults.objectForKey("currentBgData") as? NSData else {
            return BgData()
        }
        guard let bgData : BgData = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? BgData else {
            return BgData()
        }
        return bgData
    }
    
    
    func storeHistoricBgData(historicBgData : [Int]) {
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setObject(NSKeyedArchiver.archivedDataWithRootObject(historicBgData), forKey: "historicBgData")
    }
    
    func loadHistoricBgData() -> [Int] {
        guard let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => return dummy-Data
            return []
        }
        
        guard let data = defaults.objectForKey("historicBgData") as? NSData else {
            return []
        }
        
        guard let historicBgData = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? [Int] else {
            return []
        }
        return historicBgData
    }
}