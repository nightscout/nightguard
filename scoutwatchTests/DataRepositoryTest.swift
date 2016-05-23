//
//  DataRepositoryTests.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 27.12.15.
//  Copyright © 2015 private. All rights reserved.
//

import XCTest

class DataRepositoryTest: XCTestCase {
    
    // deactivated --> seems to be a bug in the test environment
    func ignoretestStoreCurrentBgData() {
        // Given
        let nightscoutData = NightscoutData()
        nightscoutData.bgdeltaString = "12"
        
        // When
        DataRepository.singleton.storeCurrentNightscoutData(nightscoutData)
        let retrievedBgData = DataRepository.singleton.loadCurrentNightscoutData()
        
        // Then
        XCTAssertEqual(retrievedBgData.bgdeltaString, "12")
    }
    
    // deactivated --> seems to be a bug in the test environment
    func ignoretestStoreHistoricBgData() {
        // Given
        let historicBgData : [BloodSugar] =
            [BloodSugar.init(value: 1,timestamp: 1),
             BloodSugar.init(value: 2,timestamp: 2),
             BloodSugar.init(value: 3,timestamp: 3),
             BloodSugar.init(value: 4,timestamp: 4),
             BloodSugar.init(value: 5,timestamp: 5)]
        
        // When
        DataRepository.singleton.storeHistoricBgData(historicBgData)
        let retrievedHistoricBgData = DataRepository.singleton.loadHistoricBgData()
        
        // Then
        XCTAssertEqual(retrievedHistoricBgData.count, 5)
        XCTAssertEqual(retrievedHistoricBgData[0], 1)
    }
}