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
}
