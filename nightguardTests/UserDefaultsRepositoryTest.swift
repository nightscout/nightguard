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
        
        UserDefaultsRepository.units.value = Units.mgdl
        
        XCTAssertEqual(UserDefaultsRepository.units.value, Units.mgdl)
    }
    
    func testSaveUnitsWithMmoll() {
        
        UserDefaultsRepository.units.value = Units.mmol
        
        XCTAssertEqual(UserDefaultsRepository.units.value, Units.mmol)
    }
}
