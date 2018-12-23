//
//  Matrix.swift
//  Regression
//
//  Created by Dominik Felber on 15.05.16.
//  Copyright © 2016 Dominik Felber. All rights reserved.
//

import Foundation
import Accelerate

extension Array where Iterator.Element == Double {
    
    var average: Double {
        return self.reduce(0, {$0 + $1}) / Double(self.count)
    }
    
    var standardDeviation: Double {
        let sumOfSquaredAvgDiff = self.map { pow($0 - average, 2.0)}.reduce(0, +)
        return sqrt(sumOfSquaredAvgDiff / Double(self.count))
    }
}

/// Matrix, storing its values in row-major order.
class Matrix
{
    /// The raw values of the Matrix in row-major order.
    private (set) var values: [Double]
    
    /// The columns of the Matrix.
    let columns: UInt
    
    /// The rows of the Matrix.
    let rows: UInt
    
    
    init(columns: UInt, rows: UInt, values: [Double]? = nil) {
        self.columns = columns
        self.rows = rows
        self.values = values ?? [Double](repeating: 0, count: Int(columns * rows))
    }
    
    
    init(columns: UInt, rows: UInt, values value: Double) {
        self.columns = columns
        self.rows = rows
        self.values = [Double](repeating: value, count: Int(columns * rows))
    }
    
    // Get a given column from Matrix as a new Matrix
    func column(_ index: UInt) -> Matrix {
        
        if self.columns == 1 {
            return self
        }
        
        let columnValues = (0..<self.values.count).filter({ UInt($0) % self.columns == index}).map { self.values[$0] }
        return Matrix(columns: 1, rows: self.rows, values: columnValues)
        
    }
    
    /// Returns the transposed version of the Matrix
    func transposed() -> Matrix {
        var result = self.values
        
        let columns = vDSP_Length(self.rows)
        let rows    = vDSP_Length(self.columns)
        
        vDSP_mtransD(self.values, 1, &result, 1, rows, columns)
        
        return Matrix(columns: columns, rows: rows, values: result)
    }
    
    
    /// Returns the inverted version of the Matrix
    func inverted() -> Matrix {
        var result = self.values
        
        var pivot: __CLPK_integer = 0
        var error: __CLPK_integer = 0
        var workspace = 0.0
        
        var N = __CLPK_integer(sqrt(Double(self.values.count)))
        var M = N
        var LDA = N
        dgetrf_(&M, &N, &result, &LDA, &pivot, &error)
        
        guard error == 0 else {
            return self
        }
        
        var lwork = N
        dgetri_(&N, &result, &LDA, &pivot, &workspace, &lwork, &error)
        
        return Matrix(columns: self.rows, rows: self.columns, values: result)
    }
    
    /// Normalize the matrix from its own values, resulting a new matrix (used by training set)
    func normalized() -> Matrix {
        let average = self.values.average
        let standardDeviation = self.values.standardDeviation
        
        let normalizedValues = self.values.map { ($0 - average) / standardDeviation }
        return Matrix(columns: columns, rows: rows, values: normalizedValues)
    }
    
    /// Normalize the matrix with training set average & standard deviation (used
    func normalized(average: Double, standardDeviation: Double) -> Matrix {
        let normalizedValues = self.values.map { ($0 - average) / standardDeviation }
        return Matrix(columns: columns, rows: rows, values: normalizedValues)
    }
    
    /// Sets all values to `value`.
    func setValues(_ value: Double) {
        values = [Double](repeating: value, count: values.count)
    }
    
    
    /// Replaces `values` with `newValues`.
    ///
    /// - parameter newValues:
    ///        The new values of the Matrix.
    ///        The count of `newValues` must match the count of `values`.
    ///
    func setValues(_ newValues: [Double]) {
        guard newValues.count == values.count else {
            return
        }
        
        values = newValues
    }
    
    
    /// Get/Set the value at `column` and `row`.
    subscript (column: UInt, row: UInt) -> Double {
        get {
            let index = columns * row + column
            guard index < UInt(self.values.count) else {
                return Double.nan
            }
            
            return self.values[Int(index)]
        }
        
        set {
            let index = columns * row + column
            guard index < UInt(self.values.count) else {
                return
            }
            
            values[Int(index)] = newValue
        }
    }
    
    
    /// Get/Set the values at range `r`.
    subscript(r: Range<Int>) -> [Double] {
        get {
            return Array(values[r])
        }
        
        set {
            values[r] = ArraySlice(newValue)
        }
    }
}
