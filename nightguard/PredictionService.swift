//
//  PredictionService.swift
//  nightguard
//
//  Created by Florian Preknya on 12/18/18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation


/// The brain that predicts some future BG values by applying a 2-degree
/// polynomial regression on latest BG readings. Its prediction range is
/// extended on 60 minutes from current time on.
class PredictionService {
    
    static let shared = PredictionService()

    /// The next hour predictions (60 predictions, one value for each minute)
    var nextHour: [BloodSugar] {
        
        let readings = [BloodSugar].latestFromRepositories()
        guard !readings.isEmpty else {
            return []
        }

        // if a new reading was detected or the previous predictions expired (one minute expiration date), we'll have to update the predictions
        let newReadingDetected = readings.last!.timestamp > (preditionCurrentBG?.timestamp ?? 0)
        let predictionsExpired = prediction.isEmpty || prediction.first!.date.timeIntervalSinceNow < 0
        
        if newReadingDetected || predictionsExpired {
            updatePrediction(readings: readings)
        }
        
        return prediction
    }
    
    /// How many minutes until a low value is reached?
    /// Returns nil if there is no predicted value that goes below the low value in 60 minutes.
    func minutesTo(low lowValue: Float) -> Int?  {
        
        if let index = nextHour.firstIndex(where: { $0.value < lowValue }) {
            return index + 1
        }
        
        return nil
    }
    
    /// How many minutes until a high value is reached?
    /// Returns nil if there is no predicted value that goes above the high value in 60 minutes.
    func minutesTo(high highValue: Float) -> Int?  {
        
        if let index = nextHour.firstIndex(where: { $0.value > highValue }) {
            return index + 1
        }
        
        return nil
    }
    
    /// Updates the prediction cache.
    private func updatePrediction(readings: [BloodSugar]) {
        
        guard let regression = readings.regression else {
            
            // cannot create regression... probably not enough readings
            prediction = []
            return
        }
        
        let nextHour = (1...60).map { Date().addingTimeInterval(Double($0) * 60).timeIntervalSince1970 }
        print(Date(timeIntervalSince1970: nextHour.first!))
        
        let x = Matrix(columns: 1, rows: UInt(nextHour.count), values: nextHour)
        let y = regression.predict(x: x).values
        
        print(y)
        
        // cache the prediction...
        prediction = (0..<nextHour.count).map { index in
            return BloodSugar(value: Float(round(y[index])), timestamp: nextHour[index] * 1000)
        }
        
        print("Prediction update:")
        print(prediction)
        
        // ... and the current BG
        preditionCurrentBG = readings.last
    }
    
    private var prediction: [BloodSugar] = []
    private var preditionCurrentBG: BloodSugar?

    private init() {
    }
}
