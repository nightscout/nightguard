//
//  Matrix+Append.swift
//  Regression
//
//  Created by Dominik Felber on 16.05.16.
//  Copyright © 2016 Dominik Felber. All rights reserved.
//

extension Matrix
{
    /// Appends a Matrix horizontally to the current Matrix.
    ///
    /// - parameter m: The Matrix that should be appended.
    /// - returns: A new Matrix based on the current Matrix and `m`.
    func appendHorizontal(_ m: Matrix) -> Matrix {
        let result = Matrix(columns: m.rows, rows: self.columns + m.columns)
        let a = self.transposed().values
        let b = m.transposed().values
        let values = concat(a, b)
        
        result.setValues(values)
        
        return result.transposed()
    }
    
    
    /// Appends a Matrix vertically to the current Matrix.
    ///
    /// - parameter m: The Matrix that should be appended.
    /// - returns: A new Matrix based on the current Matrix and `m`.
    func appendVertical(_ m: Matrix) -> Matrix {
        let result = Matrix(columns: m.rows, rows: self.columns + m.columns)
        let values = concat(self.values, m.values)
        result.setValues(values)
        
        return result
    }
}
