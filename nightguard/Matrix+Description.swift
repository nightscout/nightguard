//
//  Matrix+Description.swift
//  Regression
//
//  Created by Dominik Felber on 16.05.16.
//  Copyright © 2016 Dominik Felber. All rights reserved.
//

extension Matrix: CustomStringConvertible
{
    var description: String {
        var desc = "*** Matrix(\(self.columns)x\(self.rows)) ***\n"
        
        for row in 0..<rows {
            let startIdx: Int = Int(columns * row)
            let endIdx: Int = Int(columns * row + columns)
            desc += "\t\(self.values[startIdx..<endIdx])\n"
        }
        
        return desc
    }
}
