//
//  Helper.swift
//  Regression
//
//  Created by Dominik Felber on 16.05.16.
//  Copyright © 2016 Dominik Felber. All rights reserved.
//

import Foundation
import Accelerate


/// Dot product of two matrices
func dot(_ lhs: Matrix, _ rhs: Matrix) -> Double {
    var result = 0.0
    
    let length = vDSP_Length(lhs.values.count)
    
    vDSP_dotprD(lhs.values, 1, rhs.values, 1, &result, length)
    
    return result
}


/// Matrix multiplication
func * (lhs: Matrix, rhs: Matrix) -> Matrix {
    return multiply(lhs, rhs)
}


/// Matrix multiplication
func multiply(_ lhs: Matrix, _ rhs: Matrix) -> Matrix {
    var result = [Double](repeating : 0.0, count : Int(lhs.rows * rhs.columns))
    
    let rows1    = vDSP_Length(lhs.rows)
    let columns1 = vDSP_Length(lhs.columns)
    let columns2 = vDSP_Length(rhs.columns)
    
    vDSP_mmulD(lhs.values, 1, rhs.values, 1, &result, 1, rows1, columns2, columns1)
    
    return Matrix(columns: rhs.columns, rows: lhs.rows, values: result)
}


/// `lhs` to the power of `rhs`
func ^ (lhs: Double, rhs: Double) -> Double {
    return pow(lhs, rhs)
}


/// Concatenate two Double arrays
func concat(_ v1: [Double], _ v2: [Double]) -> [Double] {
    var values = [Double](repeating: 0, count: v1.count + v2.count)
    
    values[0..<v1.count] = ArraySlice(v1)
    values[v1.count..<v1.count + v2.count] = ArraySlice(v2)
    
    return values
}


/// Solves a system of linear equations
/// Thx to http://connor-johnson.com/2015/10/17/solving-linear-equations-with-swift-and-accelerate/
/// Use T for matrices with values in row-major order.
/// Use N for matrices with values in column-major order.
func solve(_ A: [Double], _ B: [Double], TRANS: String = "T") -> [Double] {
    var inMatrix: [Double] = A
    var solution: [Double] = B
    
    // Get the dimensions of the matrix. An NxN matrix has N^2
    // elements, so sqrt( N^2 ) will return N, the dimension
    var N: __CLPK_integer = __CLPK_integer( sqrt( Double( A.count ) ) )
    
    // Number of columns on the RHS
    var NRHS: __CLPK_integer = 1
    
    // Leading dimension of A and B
    var LDA: __CLPK_integer = N
    var LDB: __CLPK_integer = N
    
    // Initialize some arrays for the dgetrf_() function
    var pivots: [__CLPK_integer] = [__CLPK_integer](repeating: 0, count: Int(N))
    
    var error: __CLPK_integer = 0
    
    // Perform LU factorization
    
    var M = N
    dgetrf_(&M, &N, &inMatrix, &LDA, &pivots, &error)
    
    // Calculate solution from LU factorization
//    _ = TRANS.withCString {
        /// DGETRS solves a system of linear equations
        /// A * X = B  or  A**T * X = B
        /// with a general N-by-N matrix A using the LU factorization computed
        /// by DGETRF.
        /// - http://www.netlib.org/lapack/explore-html/dd/d9a/group__double_g_ecomputational.html#ga58e332cb1b8ab770270843221a48296d
        ///
        /// TRANS is CHARACTER*1
        ///        Specifies the form of the system of equations:
        ///        = 'N':  A * X = B (No transpose)
        ///        = 'T':  A**T* X = B  (Transpose)
        ///        = 'C':  A**T* X = B  (Conjugate transpose = Transpose)
        ///
        /// N is INTEGER
        ///        The order of the matrix A.  N >= 0.
        ///
        /// NRHS is INTEGER
        ///        The number of right hand sides, i.e., the number of columns
        ///        of the matrix B.  NRHS >= 0.
        ///
        /// A is DOUBLE PRECISION array, dimension (LDA,N)
        ///        The factors L and U from the factorization A = P*L*U
        ///        as computed by DGETRF.
        ///
        /// LDA is INTEGER
        ///        The leading dimension of the array A.  LDA >= max(1,N).
        ///
        /// IPIV is INTEGER array, dimension (N)
        ///        The pivot indices from DGETRF; for 1<=i<=N, row i of the
        ///        matrix was interchanged with row IPIV(i).
        ///
        /// B is DOUBLE PRECISION array, dimension (LDB,NRHS)
        ///        On entry, the right hand side matrix B.
        ///        On exit, the solution matrix X.
        ///
        /// LDB is INTEGER
        ///        The leading dimension of the array B.  LDB >= max(1,N).
        ///
        /// INFO: INFO is INTEGER
        ///        = 0:  successful exit
        ///        < 0:  if INFO = -i, the i-th argument had an illegal value
        ///
//        dgetrs_( UnsafeMutablePointer($0), &N, &NRHS, &inMatrix, &LDA, &pivots, &solution, &LDB, &error )
//    }
//    let cs = (TRANS as NSString).utf8String
//    var buffer = UnsafeMutablePointer<Int8>(cs)
    let buffer = UnsafeMutablePointer<Int8>(mutating: (TRANS as NSString).utf8String)
    dgetrs_(buffer, &N, &NRHS, &inMatrix, &LDA, &pivots, &solution, &LDB, &error )
    
    // Return zero instead of NaN when something failed.
    return solution.map({ $0.isNaN ? 0 : $0 })
}
