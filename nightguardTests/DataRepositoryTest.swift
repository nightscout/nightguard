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
        let nightscoutData = NightscoutData()
        nightscoutData.bgdeltaString = "12"
        
        // When
        NightscoutDataRepository.singleton.storeCurrentNightscoutData(nightscoutData)
        let retrievedBgData = NightscoutDataRepository.singleton.loadCurrentNightscoutData()
        
        // Then
        XCTAssertEqual(retrievedBgData.bgdeltaString, "12")
    }
    
    func testStoreDeviceStatusData() {
        
        // Given
        let datePlus10Minutes = Calendar.current.date(byAdding: .minute, value: 10, to: Date())!
        let deviceStatusData = DeviceStatusData()
        deviceStatusData.temporaryBasalRate = "110.0"
        deviceStatusData.pumpProfileActiveUntil = datePlus10Minutes
        deviceStatusData.activePumpProfile = "Test"
        deviceStatusData.temporaryBasalRateActiveUntil = datePlus10Minutes
        
        // When
        NightscoutDataRepository.singleton.storeDeviceStatusData(deviceStatusData: deviceStatusData)
        let retrievedDeviceStatusData = NightscoutDataRepository.singleton.loadDeviceStatusData()
        
        // Then
        XCTAssertEqual(retrievedDeviceStatusData.activePumpProfile, "Test")
        XCTAssertEqual(retrievedDeviceStatusData.pumpProfileActiveUntil, datePlus10Minutes)
        XCTAssertEqual(retrievedDeviceStatusData.temporaryBasalRate, "110.0")
        XCTAssertEqual(retrievedDeviceStatusData.temporaryBasalRateActiveUntil, datePlus10Minutes)
    }
    
    func testStoreTemporaryTargetData() {
        
        // Given
        let datePlus10Minutes = Calendar.current.date(byAdding: .minute, value: 10, to: Date())!
        let temporaryTargetData = TemporaryTargetData()
        temporaryTargetData.targetTop = 91
        temporaryTargetData.targetBottom = 90
        temporaryTargetData.activeUntilDate = datePlus10Minutes
        
        // When
        NightscoutDataRepository.singleton.storeTemporaryTargetData(temporaryTargetData: temporaryTargetData)
        let retrievedTemporaryTargetData = NightscoutDataRepository.singleton.loadTemporaryTargetData()
        
        // Then
        XCTAssertEqual(retrievedTemporaryTargetData.targetTop, 91)
        XCTAssertEqual(retrievedTemporaryTargetData.targetBottom, 90)
        XCTAssertEqual(retrievedTemporaryTargetData.activeUntilDate, datePlus10Minutes)
    }
}
