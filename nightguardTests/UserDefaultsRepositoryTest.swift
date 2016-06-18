//
//  UserDefaultsRepositoryTest.swift
//  nightguard
//
//  Created by Dirk Hermanns on 15.06.16.
//  Copyright © 2016 private. All rights reserved.
//

import XCTest

class UserDefaultsRepositoryTest : XCTestCase {
    
    func testSaveUnitsWithMgdl() {
        
        UserDefaultsRepository.saveUnits(Units.mgdl)
        
        XCTAssertEqual(UserDefaultsRepository.readUnits(), Units.mgdl)
    }
    
    func testSaveUnitsWithMmoll() {
        
        UserDefaultsRepository.saveUnits(Units.mmol)
        
        XCTAssertEqual(UserDefaultsRepository.readUnits(), Units.mmol)
    }
}