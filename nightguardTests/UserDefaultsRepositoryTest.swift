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
    
    // Commented out - screenlockSwitchState property was removed from UserDefaultsRepository
    /*
    func testScreenLockStateIsSaved() {

        // Given
        let initialPosition : Bool = false

        // When
        UserDefaultsRepository.screenlockSwitchState.value = initialPosition
        let retrievedPosition = UserDefaultsRepository.screenlockSwitchState.value

        // Then
        XCTAssertEqual(retrievedPosition, initialPosition)
    }
    */
    
    func testSaveTreatments() {
        
        // Given
        var treatments : [Treatment] = []
        treatments.append(Treatment.init(id: "id0", timestamp: 0))
        treatments.append(Treatment.init(id: "id1", timestamp: 1))
        
        // When
        UserDefaultsRepository.treatments.value = treatments
        let retrievedTreatments : [Treatment] = UserDefaultsRepository.treatments.value
        
        // Then
        XCTAssertEqual(retrievedTreatments.count, 2)
        
        XCTAssertEqual(retrievedTreatments[0].id, "id0")
        XCTAssertEqual(retrievedTreatments[0].timestamp, 0)
        
        XCTAssertEqual(retrievedTreatments[1].id, "id1")
        XCTAssertEqual(retrievedTreatments[1].timestamp, 1)
    }
}
