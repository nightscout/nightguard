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
    
    fileprivate var todaysBgData : [BloodSugar] = []
    fileprivate var currentNightscoutData = NightscoutData()
    fileprivate var testNightscoutData = NightscoutData()
    var hasNewValues : Bool = false
    
    func setTestBgData(_ testBgData : NightscoutData) {
        self.testNightscoutData = testBgData
    }
    
    func setTodaysBgData(_ todaysBgData : [BloodSugar]) {
        let oldBgData = self.todaysBgData
        hasNewValues = determineIfNewDataWasReceived(oldBgData, new: todaysBgData)
        
        self.todaysBgData = todaysBgData
    }
    
    func getTodaysBgData() -> [BloodSugar] {
        return todaysBgData
    }
    
    func setCurrentBgData(_ currentNightscoutData : NightscoutData) {
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
        let dic = ProcessInfo.processInfo.environment
        return dic["TEST"] != nil
    }
    
    // Remove all cached data and retrieve them new
    // This will be called when the URI to the backend has changed
    func reset() {
        todaysBgData = []
        currentNightscoutData = NightscoutData()
    }
    
    fileprivate func determineIfNewDataWasReceived(_ old : [BloodSugar], new : [BloodSugar]) -> Bool {
        
        if old.count != new.count {
            return true
        } else if old.count == 0 {
            return false
        }
        
        // if both have the same length they are considered different, if the
        // last item differs
        return old.last?.timestamp != new.last?.timestamp
    }
    
    fileprivate func generateHighBgTestData() -> NightscoutData {
        let bgData = NightscoutData()
        bgData.sgv = "200"
        bgData.bgdelta = 0
        bgData.time = NSNumber(value: Date.init().timeIntervalSince1970)
        
        return bgData
    }
}
