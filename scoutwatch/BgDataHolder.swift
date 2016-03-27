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
    static let singleton = BgData()
    
    private var historicBgData : [Int] = []
    private var currentBgData : BgData = BgData()
}