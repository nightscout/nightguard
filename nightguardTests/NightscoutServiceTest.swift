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
    
    fileprivate var BASE_URI: String {
        
        let FALLBACKURL = "https://yournightscoutbackend.local"
        let bundle = Bundle(for: type(of: self))
        guard let filePath = bundle.path(forResource: ".env", ofType: nil) ?? Bundle.main.path(forResource: ".env", ofType: nil) else {
            print("Error: .env file not found in bundle")
            return FALLBACKURL // Fallback or empty? keeping original as default if missing to avoid breaking legacy setups without .env immediately
        }
        
        do {
            let contents = try String(contentsOfFile: filePath)
            let lines = contents.components(separatedBy: .newlines)
            for line in lines {
                let parts = line.split(separator: "=", maxSplits: 1).map { String($0) }
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if key == "BASE_URI" {
                        return value
                    }
                }
            }
        } catch {
            print("Error reading .env file: \(error)")
        }
        
        return FALLBACKURL
    }
    
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
