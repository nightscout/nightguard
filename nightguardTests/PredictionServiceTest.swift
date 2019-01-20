//
//  PredictionServiceTest.swift
//  nightguardTests
//
//  Created by Florian Preknya on 1/13/19.
//  Copyright © 2019 private. All rights reserved.
//

import XCTest

class PredictionServiceTest: XCTestCase {
    
    let ascendingBgValues: [Float] = [
        108, 120, 130, 138, 143, 150
    ]
    
    let withoutTrendBgValues: [Float] = [
        130, 128, 127, 129
    ]
    
    func readings(for values: [Float]) -> [BloodSugar] {
        return [BloodSugar](values: values)
    }

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
//        NightscoutDataRepository.singleton.storeTodaysBgData(
//            readings(for: ascendingBgValues)
//        )
//        NightscoutCacheService.singleton.loadTodaysData { _ in }
        
        // clean the cache
        NightscoutCacheService.singleton.updateTodaysBgDataForTesting([])
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testNextHour() {
        
        let emptyNextHourReadings = PredictionService.singleton.nextHour
        XCTAssertEqual(emptyNextHourReadings.count, 0, "No readings in cache, prediction should be empty")
        
        storeReadingsInCache(readings(for: ascendingBgValues))
        
        let nextHourReadings = PredictionService.singleton.nextHour
        XCTAssertEqual(nextHourReadings.count, 60, "Should have 60 values, for each minute of the next hour")
        print(nextHourReadings)
        
        let nextHourReadingsAgain = PredictionService.singleton.nextHour
        XCTAssertEqual(nextHourReadings, nextHourReadingsAgain, "Two consecutive calls should return the same result")
        
        print(nextHourReadings[15].value)
        XCTAssertTrue((170...175).contains(nextHourReadings[15].value), "The predicted value in 15 minutes should be between 170 and 175")
    }
    
    func testNextHourGapped() {
        
        let emptyNextHourReadings = PredictionService.singleton.nextHourGapped
        XCTAssertEqual(emptyNextHourReadings.count, 0, "No readings in cache, prediction should be empty")
        
        storeReadingsInCache(readings(for: ascendingBgValues))
        
        let nextHourReadings = PredictionService.singleton.nextHourGapped
        XCTAssertEqual(nextHourReadings.count, 12, "Should have 12 values, for each 5 minutes a reading")
        print(nextHourReadings)
        
        let nextHourReadingsAgain = PredictionService.singleton.nextHourGapped
        XCTAssertEqual(nextHourReadings, nextHourReadingsAgain, "Two consecutive calls should return the same result")
        
        print(nextHourReadings[3].value)
        XCTAssertTrue((170...180).contains(nextHourReadings[3].value), "The predicted value in around 15-20 minutes should be between 170 and 180")
    }
    
    func testMinutesToLow() {
        
        XCTAssertNil(PredictionService.singleton.minutesTo(low: 80), "No readings in cache, no prediction")

        // NOTE that we're reversing the values (descending trend!)
        storeReadingsInCache(readings(for: ascendingBgValues.reversed()))

        let minutesToLow = PredictionService.singleton.minutesTo(low: 80)!
        print("Minutes to low: \(minutesToLow)")
        XCTAssertTrue((12...15).contains(minutesToLow), "In around 12-15 minutes, low is predicted")
    }
    
    private func storeReadingsInCache(_ readings: [BloodSugar]) {
        
        // this doesn't work, NightscoutDataRepository.loadTodaysBgData will fail unarchiving the [BloodSugar]
//        NightscoutDataRepository.singleton.storeTodaysBgData(
//            readings(for: ascendingBgValues)
//        )
//        NightscoutCacheService.singleton.loadTodaysData { _ in }

        NightscoutCacheService.singleton.updateTodaysBgDataForTesting(readings)
    }
}
