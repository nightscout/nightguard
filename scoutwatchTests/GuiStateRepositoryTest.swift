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
    
    func testStoreVolumeSliderPosition() {
        // Given
        let initialPosition : Float = 12.3
        
        // When
        GuiStateRepository.singleton.storeVolumeSliderPosition(initialPosition)
        let retrievedPosition = GuiStateRepository.singleton.loadVolumeSliderPosition()
        
        // Then
        XCTAssertEqual(retrievedPosition, initialPosition)
    }

}