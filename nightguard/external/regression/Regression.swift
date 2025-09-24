//
//  Regression.swift
//  Regression
//
//  Created by Dominik Felber on 15.05.16.
//  Copyright © 2016 Dominik Felber. All rights reserved.
//

import Foundation

/// Regression interface
protocol Regression: CustomStringConvertible {
    
    /// Train the regression giving the X values and the Y values (should have the size length).
    /// For each index i, y[i] = f(x[i]).
    func train(x: [Double], y: [Double])
    
    /// Predict an y value for an x value.
    /// This method should be always called after train method.
    func predict(x: Double) -> Double
    
    /// The error variance of the regression, calculated from training set
    var errorVariance: Double { get }
}

class BaseRegression: Regression {
    
    private(set) var x = Matrix(columns: 1, rows: 1)
    private(set) var y = Matrix(columns: 1, rows: 1)
    private(set) var beta = Matrix(columns: 1, rows: 1)
    
    // X normalization data
    typealias NormalizationData = (average: Double, standarDeviation: Double)
    private var normalization: [NormalizationData] = []
    
    // turns x normalization on/off
    var performNormalization: Bool = false
    
    // predicting ln Y?
    var logY: Bool = false
    
    var description: String {
        return "BaseRegression"
    }

    var errorVariance: Double {
        let x = self.x.values
        let y = logY ? self.y.values.map { exp($0) } : self.y.values
        let count = x.count
        
        print("\(description) errors:")
        for index in 0..<count {
            print("f(\(x[index])) = \(y[index]), predicted: \(predict(x: x[index]))")
        }
        
        return (0..<count).map({ index in
            pow(y[index] - predict(x: x[index]), 2)
        }).reduce(0, +) / Double(2 * count)
    }
    
    func train(x: [Double], y: [Double]) {
        assert(x.count == y.count, "x should have the same lenght as y")
        self.x = Matrix(columns: 1, rows: UInt(x.count), values: x)
        
        let yValues = logY ? y.map { log($0) } : y
        self.y = Matrix(columns: 1, rows: UInt(y.count), values: yValues)
        
        let newX = enhancedAndNormalized(x: self.x)
        let ones = Matrix(columns: 1, rows: UInt(self.x.rows), values: 1)
        let onedNewX = ones.appendHorizontal(newX)
        
        let a = (onedNewX.transposed() * onedNewX).values
        let b = (onedNewX.transposed() * self.y).values
        
        let solution = solve(a, b)
        beta = Matrix(columns: 1, rows: UInt(solution.count), values: solution)
    }
    
    func predict(x: Double) -> Double {
        let xm = Matrix(columns: 1, rows: 1, values: x)
        let newX = enhancedAndNormalized(x: xm)
        let ones = Matrix(columns: 1, rows: newX.rows, values: 1)
        let onedNewX = ones.appendHorizontal(newX)
        
        let result = (onedNewX * beta).values[0]
        return logY ? exp(result) : result
    }
    
    private func enhancedAndNormalized(x: Matrix) -> Matrix {
        
        var newX = enhanced(x: x)
        
        if performNormalization {
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

            // normalize each column
            let newXColumns = (0..<newX.columns).map { newX.column($0) }
            var normalizedNewXColumns = newXColumns.map { normalize($0) }
            newX = normalizedNewXColumns.removeFirst()
            normalizedNewXColumns.forEach { column in
                newX = newX.appendVertical(column)
            }
        }
        
        return newX
    }
    
    // override in subclasses for creating new features from x
    func enhanced(x: Matrix) -> Matrix {
        return x
    }
}

class PolynomialRegression: BaseRegression {
    
    let degree: Int
    
    init(degree: Int) {
        self.degree = degree
    }
    
    override var description: String {
        return "Polynomial(\(degree))"
    }
    
    override func enhanced(x: Matrix) -> Matrix {
        
        guard degree > 1 else {
            return x
        }
        
        var newX = x
        for i in 2...degree {
            let degreeOfX = Matrix(columns: 1, rows: newX.rows)
            degreeOfX.setValues(newX.values.map({ $0^Double(i) }))
            newX = newX.appendHorizontal(degreeOfX)//normalize(degreeOfX))
        }
        
        return newX
    }
}

class LogRegression: BaseRegression {
    
    let replaceX: Bool
    init(replaceX: Bool, logY: Bool) {
        self.replaceX = replaceX
        super.init()
        
        self.logY = logY
    }
    
    override var description: String {
        return "Log" + (replaceX ? "ReplaceX" : "") + (logY ? "LogY" : "")
    }
    
    override func enhanced(x: Matrix) -> Matrix {
        
        var newX = x

        let logX = Matrix(columns: 1, rows: newX.rows)
        logX.setValues(newX.values.map({ log($0) }))
        if replaceX {
            newX = logX
        } else {
            newX = newX.appendHorizontal(logX)
        }
        
        return newX
    }
}

class SqrtRegression: BaseRegression {
    
    override var description: String {
        return "Sqrt"
    }
    
    override func enhanced(x: Matrix) -> Matrix {
        
        var newX = x
        
        
        let sqrtX = Matrix(columns: 1, rows: newX.rows)
        sqrtX.setValues(newX.values.map({ sqrt($0) }))
        newX = sqrtX// newX.appendHorizontal(sqrtX)
        
        return newX
    }
}

class ExpRegression: BaseRegression {
    
    override init() {
        super.init()
        
        logY = true
    }
    
    override var description: String {
        return "Exp"
    }
}
class BestMatchRegression: Regression {
    
    let models: [Regression]
    var selected: Int = 0
    init() {
        models = [
            PolynomialRegression(degree: 1),
            PolynomialRegression(degree: 2),
            LogRegression(replaceX: false, logY: false),
            LogRegression(replaceX: false, logY: true),
            SqrtRegression(),
            ExpRegression()
        ]
    }
    
    var description: String {
        return "BestMatchRegression"
    }
    
    func train(x: [Double], y: [Double]) {
        
        // train each regression model
        models.forEach { regression in
            regression.train(x: x, y: y)
        }
        
        // select the best regression model (the one with the smallest error variance)
        var minErrorVariance = Double.infinity
        for i in 0..<models.count {
            let regression = models[i]
            let errorVariance = regression.errorVariance
            
            print("\(regression.description) regression, error variance: \(errorVariance)")
            
            if errorVariance < minErrorVariance {
                self.selected = i
                minErrorVariance = errorVariance
            }
        }
        
        print("Best matched model: \(models[selected].description)")
    }
    
    func predict(x: Double) -> Double {
        return models[selected].predict(x: x)
    }
    
    var errorVariance: Double {
        return models[selected].errorVariance
    }
}
