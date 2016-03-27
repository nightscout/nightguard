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
    
    private var historicBgData : [Int] = []
    private var currentBgData : BgData = BgData()
    private var testBgData : BgData = BgData()
    
    func setTestBgData(testBgData : BgData) {
        self.testBgData = testBgData
    }
    
    func setHistoricBgData(historicBgData : [Int]) {
        self.historicBgData = historicBgData
    }
    
    func getHistoricBgData() -> [Int] {
        return historicBgData
    }
    
    func setCurrentBgData(currentBgData : BgData) {
        self.currentBgData = currentBgData
    }
    
    func getCurrentBgData() -> BgData {
        if inTestMode() {
            return generateHighBgTestData()
        } else {
            return currentBgData
        }
    }
    
    func inTestMode() -> Bool {
        let dic = NSProcessInfo.processInfo().environment
        return dic["TEST"] != nil
    }
    
    private func generateHighBgTestData() -> BgData {
        let bgData = BgData()
        bgData.sgv = "200"
        bgData.bgdelta = 0
        bgData.time = NSDate.init().timeIntervalSince1970
        
        return bgData
    }
}