//
//  GuiStateRepositoryTest.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 15.02.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation

import XCTest

class GuiStateRepositoryTest: XCTestCase {
    
    func testScreenLockStateIsSaved() {
        // Given
        let initialPosition : Bool = false
        
        // When
        GuiStateRepository.singleton.storeScreenlockSwitchState(initialPosition)
        let retrievedPosition = GuiStateRepository.singleton.loadScreenlockSwitchState()
        
        // Then
        XCTAssertEqual(retrievedPosition, initialPosition)
    }

}