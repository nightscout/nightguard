//
//  TargetDataTest.swift
//  nightguard
//
//  Created by Dirk Hermanns on 17.03.21.
//  Copyright © 2021 private. All rights reserved.
//
import XCTest

class TargetDataTest : XCTestCase {
    
    func testParsingOfMmolTarget() {
        
        // Given
        let temporaryTargetDict = [
            "units": "mmol",
            "targetTop": Float(10.0)] as [String : Any]
        
        // When
        let temporaryTarget = TemporaryTarget.parse(temporaryTargetDict: temporaryTargetDict)
        
        // Then
        XCTAssertEqual(temporaryTarget.targetTop, 180, "Mmol should have been converted to mgdl")
    }
    
    func testParsingOfMgdlTarget() {
        
        // Given
        let temporaryTargetDict = [
            "targetTop": Int(180)] as [String : Any]
        
        // When
        let temporaryTarget = TemporaryTarget.parse(temporaryTargetDict: temporaryTargetDict)
        
        // Then
        XCTAssertEqual(temporaryTarget.targetTop, 180, "If no unit is available - it should treated as mgdl")
    }

    func testParsingV3TimestampAndNumericFields() {
        let timestamp = 1_724_198_400_000 as NSNumber
        let temporaryTarget = TemporaryTarget.parse(temporaryTargetDict: [
            "date": timestamp,
            "duration": 30.0,
            "targetTop": 120.0,
            "targetBottom": 90.0
        ])

        XCTAssertEqual(temporaryTarget.targetTop, 120)
        XCTAssertEqual(temporaryTarget.targetBottom, 90)
        XCTAssertEqual(temporaryTarget.duration, 30)
        XCTAssertNotNil(temporaryTarget.createdAt)
    }
}
