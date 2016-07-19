//
//  TimeServiceTest.swift
//  nightguard
//
//  Created by Dirk Hermanns on 07.07.16.
//  Copyright © 2016 private. All rights reserved.
//

import XCTest

class TimeServiceTest : XCTestCase {
    
    func testMinus29MinutesIsNotOlderThan30Minutes() {
        
        XCTAssertFalse(TimeService.isOlderThan30Minutes(NSDate.init().dateByAddingTimeInterval(-60 * 29)))
    }
    
    func testMinus31MinutesIsOlderThan30Minutes() {
        
        XCTAssertTrue(TimeService.isOlderThan30Minutes(NSDate.init().dateByAddingTimeInterval(-60 * 31)))
    }
}