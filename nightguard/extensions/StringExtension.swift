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
        return self.trimmingCharacters(in: CharacterSet.whitespaces)
    }
    
    // treat the String as float and round if regarding the first decimal.
    // If that doesn't work - return self
    var cleanFloatValue: String {
        
        guard let doubleValue = Double(self)?.cleanValue else {
            return self
        }
        return String(doubleValue)
    }
    
    // remove all characters in the middle of the String.
    // The new size of the string will be
    // keepPrefixCharacterCount + keepPostfixCharacterCount + 3
    func trimInfix(keepPrefixCharacterCount: Int, keepPostfixCharacterCount: Int) -> String {
        
        if self.count <= (keepPrefixCharacterCount + keepPostfixCharacterCount + 3) {
            // string is not too long => do nothing
            return self
        }
        
        return self.prefix(keepPrefixCharacterCount) + "..." + self.suffix(keepPostfixCharacterCount)
    }
    
    func removing(charactersOf string: String) -> String {
         let characterSet = CharacterSet(charactersIn: string)
         let components = self.components(separatedBy: characterSet)
         return components.joined(separator: "")
     }
}
