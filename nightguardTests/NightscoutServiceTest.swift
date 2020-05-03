//
//  ServiceBoundaryTest.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 25.04.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation

import XCTest

class NightscoutServiceTest: XCTestCase {
    
    fileprivate let BASE_URI = "http://night.fritz.box"
    
    func testReadYesterdaysChartDataShouldReturnData() {
        
        // Given
        let serviceBoundary = NightscoutService.singleton;
        UserDefaultsRepository.baseUri.value = BASE_URI
        let expectation = self.expectation(description: "Remote Call was successful!")
        
        // When
        serviceBoundary.readYesterdaysChartData({(bloodSugarArray: [BloodSugar]) -> Void in
            
            if bloodSugarArray.count > 0 {
                if TimeService.isYesterday(bloodSugarArray[0].timestamp) {
                    expectation.fulfill();
                }
            }
        })
        
        // Then
        self.waitForExpectations(timeout: 3.0, handler: nil)
    }
    
    func testReadStatus() {
        
        // Given
        let nightscoutService = NightscoutService.singleton;
        UserDefaultsRepository.baseUri.value = BASE_URI
        let expectation = self.expectation(description: "Remote Call was successful!")
        
        // When
        nightscoutService.readStatus({(units: Units) -> Void in
            
            if units == Units.mgdl {
                expectation.fulfill()
            }
        })
        
        // Then
        self.waitForExpectations(timeout: 5.0, handler: nil)
    }
    
    func testReadLast2HoursShouldReturnData() {
        
        // Given
        let serviceBoundary = NightscoutService.singleton;
        UserDefaultsRepository.baseUri.value = BASE_URI
        let expectation = self.expectation(description: "Remote Call was successful!")
        
        // When
        serviceBoundary.readLastTwoHoursChartData({(response) -> Void in
            
            switch response {
            
            case .data(let bloodSugarArray):
                if bloodSugarArray.count > 0 {
                    let twoHoursBefore = TimeService.getToday().addingTimeInterval(-60*120).timeIntervalSince1970
                    var allExpectationsFulFilled : Bool = true
                    for bloodSugar in bloodSugarArray {
                        if !(twoHoursBefore < bloodSugar.timestamp) {
                            allExpectationsFulFilled = false
                        }
                    }
                    
                    if allExpectationsFulFilled {
                        expectation.fulfill()
                    }
                }
            case .error(_):
                break
            }
        })
        
        // Then
        self.waitForExpectations(timeout: 5.0, handler: nil)
    }
}
