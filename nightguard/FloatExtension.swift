//
//  FloatExtension.swift
//  nightguard
//
//  Created by Dirk Hermanns on 18.06.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation

extension Float {
    
    // remove the decimal part of the float if it is ".0"
    var cleanValue: String {
        return self % 1 == 0 ? String(format: "%.0f", self) : String(format: "%.1f", self)
    }
}