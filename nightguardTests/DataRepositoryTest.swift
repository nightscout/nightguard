//
//  DataRepositoryTests.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 27.12.15.
//  Copyright © 2015 private. All rights reserved.
//

import XCTest

class DataRepositoryTest: XCTestCase {

    // Helper function to properly store device status data with Date support
    func storeDeviceStatusDataWithDateSupport(_ deviceStatusData: DeviceStatusData) {
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        NSKeyedArchiver.setClassName("DeviceStatusData", for: DeviceStatusData.self)
        defaults?.set(try? NSKeyedArchiver.archivedData(withRootObject: deviceStatusData, requiringSecureCoding: true), forKey: "deviceStatus")
    }

    // Helper function to properly load device status data with Date support
    func loadDeviceStatusDataWithDateSupport() -> DeviceStatusData {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            return DeviceStatusData()
        }

        guard let data = defaults.object(forKey: "deviceStatus") as? Data else {
            return DeviceStatusData()
        }

        NSKeyedUnarchiver.setClass(DeviceStatusData.self, forClassName: "DeviceStatusData")
        guard let deviceStatusData = (try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [DeviceStatusData.self, NSString.self, NSNumber.self, NSDate.self], from: data)) as? DeviceStatusData else {
            return DeviceStatusData()
        }
        return deviceStatusData
    }

    // Helper function to properly store temporary target data with Date support
    func storeTemporaryTargetDataWithDateSupport(_ temporaryTargetData: TemporaryTargetData) {
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        NSKeyedArchiver.setClassName("TemporaryTargetData", for: TemporaryTargetData.self)
        defaults?.set(try? NSKeyedArchiver.archivedData(withRootObject: temporaryTargetData, requiringSecureCoding: true), forKey: "temporaryTarget")
    }

    // Helper function to properly load temporary target data with Date support
    func loadTemporaryTargetDataWithDateSupport() -> TemporaryTargetData {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            return TemporaryTargetData()
        }

        guard let data = defaults.object(forKey: "temporaryTarget") as? Data else {
            return TemporaryTargetData()
        }

        NSKeyedUnarchiver.setClass(TemporaryTargetData.self, forClassName: "TemporaryTargetData")
        guard let temporaryTargetData = (try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [TemporaryTargetData.self, NSString.self, NSNumber.self, NSDate.self], from: data)) as? TemporaryTargetData else {
            return TemporaryTargetData()
        }
        return temporaryTargetData
    }

    override func setUp() {
        super.setUp()
        // Clear all data before each test to ensure isolation
        NightscoutDataRepository.singleton.clearAll()

        // Also clear device status and temporary target data
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults?.removeObject(forKey: "deviceStatus")
        defaults?.removeObject(forKey: "temporaryTarget")
    }

    override func tearDown() {
        // Clean up after each test
        NightscoutDataRepository.singleton.clearAll()

        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults?.removeObject(forKey: "deviceStatus")
        defaults?.removeObject(forKey: "temporaryTarget")

        super.tearDown()
    }

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

        // When - Using test helper with NSDate support
        storeDeviceStatusDataWithDateSupport(deviceStatusData)
        let retrievedDeviceStatusData = loadDeviceStatusDataWithDateSupport()

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

        // When - Using test helper with NSDate support
        storeTemporaryTargetDataWithDateSupport(temporaryTargetData)
        let retrievedTemporaryTargetData = loadTemporaryTargetDataWithDateSupport()

        // Then
        XCTAssertEqual(retrievedTemporaryTargetData.targetTop, 91)
        XCTAssertEqual(retrievedTemporaryTargetData.targetBottom, 90)
        XCTAssertEqual(retrievedTemporaryTargetData.activeUntilDate, datePlus10Minutes)
    }
}
