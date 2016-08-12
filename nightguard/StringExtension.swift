//
//  StringExtension.swift
//  nightguard
//
//  Created by Dirk Hermanns on 19.06.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation

extension String {
    
    // remove the decimal part of the float if it is ".0"
    var floatValue: Float {
        return NSString(string: self).floatValue
    }
    
    // remove whitespaces from string
    func trim() -> String {
        return self.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
    }
    
    // remove the decimal part of the float if it is ".0" and trim whitespaces
    var cleanFloatValue: String {
        
        if self.containsString(".0") {
            return self.substringToIndex(self.characters.indexOf(".")!)
        }
        
        return self
    }
}