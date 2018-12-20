//
//  Regression.swift
//  Regression
//
//  Created by Dominik Felber on 15.05.16.
//  Copyright © 2016 Dominik Felber. All rights reserved.
//

import Foundation

class Regression {
    
    let degree: Int
    
    private (set) var betas: [Double] = []
    
    typealias FeatureConstructor = (Double) -> Double
    private let featureConstructors: [FeatureConstructor]
    
    // X normalization data
    typealias NormalizationData = (average: Double, standarDeviation: Double)
    private var normalization: [NormalizationData] = []
    
    init(x: Matrix, y: Matrix, degree: Int, featureConstructors: [FeatureConstructor] = []) {
        self.degree = degree
        self.featureConstructors = featureConstructors
        self.betas = self.findBetas(x: x, y: y, degree: degree)
    }
        
    private func createXWithExtraFeatures(_ x: Matrix) -> Matrix {
        
        var normalizationStack = normalization
        
        let normalize: (Matrix) -> Matrix = { x in
            if normalizationStack.isEmpty {
                self.normalization.append((average: x.values.average, x.values.standardDeviation))
                return x.normalized()
            } else {
                let normalizationData = normalizationStack.removeFirst()
                return x.normalized(average: normalizationData.average, standardDeviation: normalizationData.standarDeviation)
            }
        }
        
        var newX = normalize(x)
        if degree > 1 {
            for i in 2...degree {
                let degreeOfX = Matrix(columns: 1, rows: x.rows)
                degreeOfX.setValues(x.values.map({ $0^Double(i) }))
                newX = newX.appendHorizontal(normalize(degreeOfX))
            }
        }
        
        featureConstructors.forEach { featureConstructor in
            let feature = Matrix(columns: 1, rows: x.rows)
            feature.setValues(x.values.map { featureConstructor($0) } )
            newX = newX.appendHorizontal(normalize(feature))
        }
        
        return newX
    }
    
    private func findBetas(x: Matrix, y: Matrix, degree: Int) -> [Double] {
        let newX = createXWithExtraFeatures(x)
        let ones = Matrix(columns: 1, rows: y.rows, values: 1)
        let onedNewX = ones.appendHorizontal(newX)
        
        let a = (onedNewX.transposed() * onedNewX).values
        let b = (onedNewX.transposed() * y).values
        
        return solve(a, b)
    }
    
    
    func predict(x: Matrix) -> Matrix {
        let beta = Matrix(columns: 1, rows: UInt(betas.count), values: betas)
        let newX = createXWithExtraFeatures(x)
        let ones = Matrix(columns: 1, rows: newX.rows, values: 1)
        let onedNewX = ones.appendHorizontal(newX)
        
        return onedNewX * beta
    }
}
