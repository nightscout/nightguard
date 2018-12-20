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

        // if a new reading was detected, we'll have to update the predictions
        let newReadingDetected = readings.last!.timestamp > (trainingReferenceReading?.timestamp ?? 0)
        if newReadingDetected {
            updatePrediction(readings: readings)
        }
        
        return prediction
    }
    
    /// The next hour prediction respecting the gap (time distance) between two readings (5 minutes), taking as reference the current reading.
    var nextHourGapped: [BloodSugar] {
        let nextHourReadings = nextHour
        if nextHourReadings.isEmpty {
            return []
        }
        
        // try to select the first future reading at a distance of n*5 minutes of the current reading time
        var minutesDistance: Int = 0
        if let referenceReading = self.trainingReferenceReading {
            minutesDistance = Int(round((nextHourReadings.first?.date.timeIntervalSince(referenceReading.date) ?? 0) / 60))
        }
        
        let luckyIndex = (5 - minutesDistance) % 5
        let firstIndex = (minutesDistance == 0) ? 1 : 0 // skip first index if the very first prediction if too close to reference reading
        var result = (firstIndex..<nextHourReadings.count).filter({ $0 % 5 == luckyIndex }).map { nextHourReadings[$0] }
        
        print("First gapped prediction: \(result.first) (refereance reading: \(self.trainingReferenceReading))")
        return result
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
        
        guard let currentReading = readings.last else {
         
            // no readings at all?!?
            prediction = []
            return
        }
        
        if (self.regression == nil) || ((trainingReferenceReading?.timestamp ?? 0) < currentReading.timestamp) {
            
            // new reading was detected, get new training sample
            guard let readings = readings.lastConsecutive(3, maxMissedReadings: 2) else {
                
                // cannot create regression... not enough readings
                prediction = []
                return
            }
            
            print("Training regression from: \(readings)")
            
            let xValues = readings.map { Double(round($0.timestamp / 1000)) }
            let yValues = readings.map { Double($0.value) }

            self.regression = BestMatchRegression()
            self.regression!.train(x: xValues, y: yValues)
            
            // cache the current reading
            trainingReferenceReading = currentReading
        }
        
        // get predictions for the next hour, for each minute
        let nextHour = (0...59).map { Date().addingTimeInterval(Double($0) * 60).timeIntervalSince1970 }
        let y = nextHour.map { self.regression!.predict(x: $0) }
        
//        print(y)
        
        // cache the prediction...
        prediction = (0..<nextHour.count).map { index in
            return BloodSugar(value: Float(round(y[index])), timestamp: nextHour[index] * 1000)
        }
        
        print("Prediction update:")
        print(prediction)
    }
    
    private var regression: Regression?
    private var prediction: [BloodSugar] = []
    private var trainingReferenceReading: BloodSugar?

    private init() {
    }
}
