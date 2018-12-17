//
//  ArrayExtension.swift
//  nightguard
//
//  Created by Florian Preknya on 12/14/18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation

extension Array {
    
    /// Returns the first N elements of the sequence that satisfies the given
    /// predicate.
    func prefix(_ maxLength: Int, where predicate: (Element) throws -> Bool) rethrows -> Array<Element> {
        
        var result = Array<Element>()
        
        var slice = self[...]
        while maxLength > result.count {
            guard let index = try slice.firstIndex(where: predicate) else {
                break
            }
            
            result.append(slice[index])
            
            // move over
            slice = self[(index+1)...]
        }
        
        return result
    }
    
    /// Returns the last N elements of the sequence that satisfies the given
    /// predicate.
    func suffix(_ maxLength: Int, where predicate: (Element) throws -> Bool) rethrows -> Array<Element> {
        
        var result = Array<Element>()
        
        var slice = self[...]
        while maxLength > result.count {
            guard let index = try slice.lastIndex(where: predicate) else {
                break
            }
            
            result.append(slice[index])
            
            // move over
            slice = self[..<index]
        }
        
        return result.reversed()
    }
}
