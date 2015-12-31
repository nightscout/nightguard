//
//  DataRepositoryTests.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 27.12.15.
//  Copyright © 2015 private. All rights reserved.
//

import XCTest

class DataRepositoryTest: XCTestCase {
    
    func testStoreCurrentBgData() {
        // Given
        let bgData = BgData()
        bgData.bgdeltaString = "111"
        
        // When
        DataRepository.singleton.storeCurrentBgData(bgData)
        let retrievedBgData = DataRepository.singleton.loadCurrentBgData()
        
        // Then
        XCTAssertEqual(retrievedBgData.bgdeltaString, "111")
    }
    
    func testStoreHistoricBgData() {
        // Given
        let historicBgData : [Int] = [1,2,3,4,5]
        
        // When
        DataRepository.singleton.storeHistoricBgData(historicBgData)
        let retrievedHistoricBgData = DataRepository.singleton.loadHistoricBgData()
        
        // Then
        XCTAssertEqual(retrievedHistoricBgData.count, 5)
        XCTAssertEqual(retrievedHistoricBgData[0], 1)
    }
}