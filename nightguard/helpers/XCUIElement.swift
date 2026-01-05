//
//  XCUIElement.swift
//  nightguardUITests
//
//  Created by Dirk Hermanns on 15.04.20.
//  Copyright © 2020 private. All rights reserved.
//
import XCTest

extension XCUIElement {
    
    func clearText(andReplaceWith newText:String? = nil) {
        
        // 1. Focus
        tap()
        
        // 2. Loop until empty (max attempts to prevent infinite loop)
        for _ in 0..<3 {
            let stringValue = (self.value as? String) ?? ""
            if stringValue.isEmpty { break }
            
            // Try Select All
            press(forDuration: 1.2)
            let selectAll = XCUIApplication().menuItems["Select All"]
            
            if selectAll.waitForExistence(timeout: 1.5) {
                selectAll.tap()
                typeText(XCUIKeyboardKey.delete.rawValue)
            } else {
                // Fallback: Burst delete
                let deleteCount = max(stringValue.count, 30)
                let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: deleteCount)
                typeText(deleteString)
            }
        }
        
        // 3. Final check
        let finalValue = (self.value as? String) ?? ""
        if !finalValue.isEmpty {
            // Last resort: brute force small batch
             let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: finalValue.count + 5)
             typeText(deleteString)
        }

        if let newVal = newText { typeText(newVal) }
    }

    func forceTap() {
        if self.exists {
            if self.isHittable {
                self.tap()
            } else {
                let coordinate = self.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                coordinate.tap()
            }
        }
    }
}
