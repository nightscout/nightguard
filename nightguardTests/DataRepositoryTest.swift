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

    func testDisplaySnapshotUsesWidgetHistoryReduction() {
        // Given
        UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.set(Units.mgdl.rawValue, forKey: "units")
        let nightscoutData = NightscoutData()
        nightscoutData.sgv = "130"
        nightscoutData.bgdelta = 10
        nightscoutData.bgdeltaArrow = "->"
        nightscoutData.time = NSNumber(value: 400_000)

        let previousValues = [
            BloodSugar(value: 100, timestamp: 100_000, isMeteredBloodGlucoseValue: false, arrow: "->"),
            BloodSugar(value: 110, timestamp: 200_000, isMeteredBloodGlucoseValue: false, arrow: "->"),
            BloodSugar(value: 120, timestamp: 300_000, isMeteredBloodGlucoseValue: false, arrow: "->"),
            BloodSugar(value: 130, timestamp: 400_000, isMeteredBloodGlucoseValue: false, arrow: "->")
        ]

        // When
        let snapshot = NightguardDisplaySnapshot.make(from: nightscoutData, previousValues: previousValues)

        // Then
        XCTAssertEqual(snapshot.lastBGValues.map(\.value), ["130", "120", "110"])
        XCTAssertEqual(snapshot.lastBGValues.map(\.delta), ["+10", "+10", "+10"])
        XCTAssertEqual(snapshot.lastBGValues.map(\.timestamp), [400_000, 300_000, 200_000])
    }

    func testDisplaySnapshotIncludesCurrentValueWhenHistoryIsBehind() {
        // Given
        UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.set(Units.mgdl.rawValue, forKey: "units")
        let nightscoutData = NightscoutData()
        nightscoutData.sgv = "130"
        nightscoutData.bgdelta = 10
        nightscoutData.bgdeltaArrow = "->"
        nightscoutData.time = NSNumber(value: 400_000)

        let previousValues = [
            BloodSugar(value: 100, timestamp: 100_000, isMeteredBloodGlucoseValue: false, arrow: "->"),
            BloodSugar(value: 110, timestamp: 200_000, isMeteredBloodGlucoseValue: false, arrow: "->"),
            BloodSugar(value: 120, timestamp: 300_000, isMeteredBloodGlucoseValue: false, arrow: "->")
        ]

        // When
        let snapshot = NightguardDisplaySnapshot.make(from: nightscoutData, previousValues: previousValues)

        // Then
        XCTAssertEqual(snapshot.lastBGValues.map(\.value), ["130", "120", "110"])
        XCTAssertEqual(snapshot.lastBGValues.map(\.delta), ["+10", "+10", "+10"])
        XCTAssertEqual(snapshot.lastBGValues.map(\.timestamp), [400_000, 300_000, 200_000])
    }

    func testStoreDisplaySnapshotUsesStoredTodaysHistoryWhenPreviousValuesAreOmitted() {
        // Given
        UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.set(Units.mgdl.rawValue, forKey: "units")
        NightscoutDataRepository.singleton.storeTodaysBgData([
            BloodSugar(value: 100, timestamp: 100_000, isMeteredBloodGlucoseValue: false, arrow: "->"),
            BloodSugar(value: 110, timestamp: 200_000, isMeteredBloodGlucoseValue: false, arrow: "->"),
            BloodSugar(value: 120, timestamp: 300_000, isMeteredBloodGlucoseValue: false, arrow: "->")
        ])

        let nightscoutData = NightscoutData()
        nightscoutData.sgv = "130"
        nightscoutData.bgdelta = 10
        nightscoutData.bgdeltaArrow = "->"
        nightscoutData.time = NSNumber(value: 400_000)

        // When
        let snapshot = NightscoutDataRepository.singleton.storeLatestDisplaySnapshot(from: nightscoutData)

        // Then
        XCTAssertEqual(snapshot.lastBGValues.map(\.value), ["130", "120", "110"])
        XCTAssertEqual(snapshot.lastBGValues.map(\.delta), ["+10", "+10", "+10"])
        XCTAssertEqual(snapshot.lastBGValues.map(\.timestamp), [400_000, 300_000, 200_000])
    }

    func testDisplaySnapshotFallsBackToCurrentValueWithoutPreviousValues() {
        // Given
        UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.set(Units.mgdl.rawValue, forKey: "units")
        let nightscoutData = NightscoutData()
        nightscoutData.sgv = "120"
        nightscoutData.bgdelta = 5
        nightscoutData.bgdeltaArrow = "->"
        nightscoutData.time = NSNumber(value: 300_000)

        // When
        let snapshot = NightguardDisplaySnapshot.make(from: nightscoutData)

        // Then
        XCTAssertEqual(snapshot.lastBGValues.count, 1)
        XCTAssertEqual(snapshot.lastBGValues.first?.value, "120")
        XCTAssertEqual(snapshot.lastBGValues.first?.delta, "+5")
    }

    func testDisplaySnapshotReturnsAvailableHistoryWhenLessThanFourValuesExist() {
        // Given
        UserDefaults(suiteName: AppConstants.APP_GROUP_ID)?.set(Units.mgdl.rawValue, forKey: "units")
        let nightscoutData = NightscoutData()
        nightscoutData.sgv = "120"
        nightscoutData.bgdelta = 10
        nightscoutData.bgdeltaArrow = "->"
        nightscoutData.time = NSNumber(value: 300_000)

        let previousValues = [
            BloodSugar(value: 100, timestamp: 100_000, isMeteredBloodGlucoseValue: false, arrow: "->"),
            BloodSugar(value: 110, timestamp: 200_000, isMeteredBloodGlucoseValue: false, arrow: "->"),
            BloodSugar(value: 120, timestamp: 300_000, isMeteredBloodGlucoseValue: false, arrow: "->")
        ]

        // When
        let snapshot = NightguardDisplaySnapshot.make(from: nightscoutData, previousValues: previousValues)

        // Then
        XCTAssertEqual(snapshot.lastBGValues.map(\.value), ["120", "110"])
        XCTAssertEqual(snapshot.lastBGValues.map(\.delta), ["+10", "+10"])
        XCTAssertEqual(snapshot.lastBGValues.map(\.timestamp), [300_000, 200_000])
    }

    func testLiveActivityHistoryUsesLatestHourAndMaximumThirteenValues() {
        // Given
        let latestTimestamp = 10_000_000.0
        let fiveMinutesInMilliseconds = 5.0 * 60.0 * 1000.0
        let previousValues = (0..<15).map { index in
            BloodSugar(
                value: Float(100 + index),
                timestamp: latestTimestamp - Double(14 - index) * fiveMinutesInMilliseconds,
                isMeteredBloodGlucoseValue: false,
                arrow: "->"
            )
        } + [
            BloodSugar(
                value: 5,
                timestamp: latestTimestamp - fiveMinutesInMilliseconds,
                isMeteredBloodGlucoseValue: false,
                arrow: "->"
            )
        ]
        let nightscoutData = NightscoutData()
        nightscoutData.sgv = "140"
        nightscoutData.time = NSNumber(value: latestTimestamp)
        nightscoutData.bgdeltaArrow = "->"

        // When
        let history = NightguardDisplaySnapshot.makeLiveActivityHistory(
            from: previousValues,
            including: nightscoutData
        )

        // Then
        XCTAssertEqual(history.count, 13)
        XCTAssertEqual(history.first?.timestamp, latestTimestamp - 60 * 60 * 1000)
        XCTAssertEqual(history.last?.timestamp, latestTimestamp)
        XCTAssertEqual(history.last?.value, 140)
        XCTAssertEqual(history.filter { $0.timestamp == latestTimestamp }.count, 1)
        XCTAssertTrue(zip(history, history.dropFirst()).allSatisfy { $0.timestamp < $1.timestamp })
    }

    func testLiveActivityHistoryCanBeLimitedAndExcludesInvalidValues() {
        // Given
        let nightscoutData = NightscoutData()
        nightscoutData.sgv = "130"
        nightscoutData.time = NSNumber(value: 1_000_000)
        let previousValues = [
            BloodSugar(value: 100, timestamp: 700_000, isMeteredBloodGlucoseValue: false, arrow: "->"),
            BloodSugar(value: 5, timestamp: 800_000, isMeteredBloodGlucoseValue: false, arrow: "->"),
            BloodSugar(value: 120, timestamp: 900_000, isMeteredBloodGlucoseValue: false, arrow: "->")
        ]

        // When
        let history = NightguardDisplaySnapshot.makeLiveActivityHistory(
            from: previousValues,
            including: nightscoutData,
            maximumSampleCount: 2
        )

        // Then
        XCTAssertEqual(history.map(\.value), [100, 130])
    }

    func testLiveActivityMinuteSamplesCoverTheWholeHour() {
        let latestTimestamp = 10_000_000.0
        let values = (0...60).map { minute in
            BloodSugar(value: Float(100 + minute),
                       timestamp: latestTimestamp - Double(60 - minute) * 60_000,
                       isMeteredBloodGlucoseValue: false, arrow: "→")
        }
        let data = NightscoutData()
        data.sgv = "160"
        data.time = NSNumber(value: latestTimestamp)

        let history = NightguardDisplaySnapshot.makeLiveActivityHistory(from: values, including: data)

        XCTAssertEqual(history.map(\.timestamp), stride(from: 0, through: 60, by: 5).map {
            latestTimestamp - Double(60 - $0) * 60_000
        })
        XCTAssertEqual(history.last?.value, 160)
    }

    func testLiveActivityHistoryPreservesGapsAndHandlesSmallLimits() {
        let latestTimestamp = 10_000_000.0
        let minutes = [0, 1, 2, 3, 40, 41, 50, 59, 60]
        let values = minutes.map { minute in
            BloodSugar(value: Float(100 + minute),
                       timestamp: latestTimestamp - Double(60 - minute) * 60_000,
                       isMeteredBloodGlucoseValue: false, arrow: "→")
        }
        let data = NightscoutData()
        data.sgv = "160"
        data.time = NSNumber(value: latestTimestamp)

        let history = NightguardDisplaySnapshot.makeLiveActivityHistory(
            from: values, including: data, maximumSampleCount: 5)
        XCTAssertLessThanOrEqual(history.count, 5)
        XCTAssertEqual(history.first?.timestamp, values.first?.timestamp)
        XCTAssertEqual(history.last?.timestamp, latestTimestamp)
        XCTAssertTrue(history.allSatisfy { sample in values.contains { $0.timestamp == sample.timestamp } })
        XCTAssertTrue(zip(history, history.dropFirst()).contains { $1.timestamp - $0.timestamp > 15 * 60_000 })
        XCTAssertEqual(NightguardDisplaySnapshot.makeLiveActivityHistory(
            from: values, including: data, maximumSampleCount: 1).map(\.timestamp), [latestTimestamp])
        XCTAssertTrue(NightguardDisplaySnapshot.makeLiveActivityHistory(
            from: values, including: data, maximumSampleCount: 0).isEmpty)
    }

    #if canImport(ActivityKit)
    @available(iOS 16.1, *)
    func testLiveActivityContentStateDecodesPayloadWithoutChartFields() throws {
        // Given
        let state = NightguardActivityAttributes.ContentState(
            sgv: "120",
            delta: "+5",
            trendArrow: "->",
            date: Date(timeIntervalSince1970: 1_000),
            bgDelta: 5,
            sgvColorRed: 0,
            sgvColorGreen: 1,
            sgvColorBlue: 0,
            iob: "1.0U",
            cob: "10g",
            glucoseSamples: [
                NightguardActivityAttributes.GlucoseSample(value: 120, timestamp: 1_000_000)
            ],
            lowerTarget: 70,
            upperTarget: 190
        )
        let encodedState = try JSONEncoder().encode(state)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encodedState) as? [String: Any])
        json.removeValue(forKey: "glucoseSamples")
        json.removeValue(forKey: "lowerTarget")
        json.removeValue(forKey: "upperTarget")
        let oldStateData = try JSONSerialization.data(withJSONObject: json)

        // When
        let decodedState = try JSONDecoder().decode(
            NightguardActivityAttributes.ContentState.self,
            from: oldStateData
        )

        // Then
        XCTAssertTrue(decodedState.glucoseSamples.isEmpty)
        XCTAssertEqual(decodedState.lowerTarget, 80)
        XCTAssertEqual(decodedState.upperTarget, 180)
    }
    #endif

    func testDisplaySnapshotDecodesOldSnapshotWithoutHistory() throws {
        // Given
        let snapshot = NightguardDisplaySnapshot(
            sgv: "120",
            bgdeltaString: "+5",
            bgdeltaArrow: "->",
            bgdelta: 5,
            timestamp: 300_000,
            battery: "100",
            iob: "0.0U",
            cob: "0g",
            snoozedUntilTimestamp: 0,
            sgvColorRed: 0,
            sgvColorGreen: 1,
            sgvColorBlue: 0,
            bgdeltaColorRed: 1,
            bgdeltaColorGreen: 1,
            bgdeltaColorBlue: 1,
            createdAt: Date(),
            lastBGValues: []
        )
        let encodedSnapshot = try JSONEncoder().encode(snapshot)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encodedSnapshot) as? [String: Any])
        json.removeValue(forKey: "lastBGValues")
        let oldSnapshotData = try JSONSerialization.data(withJSONObject: json)

        // When
        let decodedSnapshot = try JSONDecoder().decode(NightguardDisplaySnapshot.self, from: oldSnapshotData)

        // Then
        XCTAssertEqual(decodedSnapshot.lastBGValues.count, 1)
        XCTAssertEqual(decodedSnapshot.lastBGValues.first?.value, "120")
        XCTAssertEqual(decodedSnapshot.lastBGValues.first?.delta, "+5")
        XCTAssertEqual(decodedSnapshot.lastBGValues.first?.timestamp, 300_000)
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
