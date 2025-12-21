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
        
        let myValue = self.value
        guard let stringValue = myValue as? String else {
            XCTFail("Tried to clear and enter text into a non string value")
            return
        }
        //self.tap()
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)

        if let newVal = newText { typeText(newVal) }
    }
}
