//
//  BgData.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 23.01.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation

/* 
 * Class to hold the blood glucose data to be displayed.
 * The singleton can be used to set test data during UITests.
 */
class BgDataHolder {
    static let singleton = BgDataHolder()
    
    private var todaysBgData : [BloodSugar] = []
    private var currentNightscoutData = NightscoutData()
    private var testNightscoutData = NightscoutData()
    var hasNewValues : Bool = false
    
    func setTestBgData(testBgData : NightscoutData) {
        self.testNightscoutData = testBgData
    }
    
    func setTodaysBgData(todaysBgData : [BloodSugar]) {
        let oldBgData = self.todaysBgData
        hasNewValues = determineIfNewDataWasReceived(oldBgData, new: todaysBgData)
        
        self.todaysBgData = todaysBgData
    }
    
    func getTodaysBgData() -> [BloodSugar] {
        return todaysBgData
    }
    
    func setCurrentBgData(currentNightscoutData : NightscoutData) {
        self.currentNightscoutData = currentNightscoutData
    }
    
    func getCurrentBgData() -> NightscoutData {
        if inTestMode() {
            return generateHighBgTestData()
        } else {
            return currentNightscoutData
        }
    }
    
    func inTestMode() -> Bool {
        let dic = NSProcessInfo.processInfo().environment
        return dic["TEST"] != nil
    }
    
    private func determineIfNewDataWasReceived(old : [BloodSugar], new : [BloodSugar]) -> Bool {
        
        if old.count != new.count {
            return true
        } else if old.count == 0 {
            return false
        }
        
        // if both have the same length they are considered different, if the
        // last item differs
        return old.last?.timestamp != new.last?.timestamp
    }
    
    private func generateHighBgTestData() -> NightscoutData {
        let bgData = NightscoutData()
        bgData.sgv = "200"
        bgData.bgdelta = 0
        bgData.time = NSDate.init().timeIntervalSince1970
        
        return bgData
    }
}
