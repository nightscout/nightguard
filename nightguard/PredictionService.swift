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
    
    static let singleton = PredictionService()

    /// The next hour predictions (60 predictions, one value for each minute)
    var nextHour: [BloodSugar] {
        
        let readings = [BloodSugar].latestFromRepositories()
        guard !readings.isEmpty else {
            return []
        }

        // if prediction training readings has changed, we'll have to update the predictions
        let shouldUpdatePrediction = readings.predictionTrainingReadings != self.trainingReadings
        if shouldUpdatePrediction {
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
        let result = (firstIndex..<nextHourReadings.count).filter({ $0 % 5 == luckyIndex }).map { nextHourReadings[$0] }
        
        print("First gapped prediction: \(String(describing: result.first)) (refereance reading: \(String(describing: self.trainingReferenceReading)))")
        
        return result
    }
    
    /// How many minutes until a low value is reached?
    /// Returns nil if there is no predicted value that goes below the low value in 60 minutes.
    func minutesTo(low lowValue: Float) -> Int?  {
        
        let nextHourReadings = nextHour
        guard !nextHourReadings.isEmpty else {
            return nil
        }
        
        if nextHourReadings[0].value <= lowValue {

            // already low!
            return 0
        }
        
        let offsetMinutes = Int(Date().timeIntervalSince(nextHourReadings.first!.date) / 60)
        
        if let index = nextHourReadings.firstIndex(where: { $0.value < lowValue }) {
            return (index + 1) - offsetMinutes
        }
        
        return nil
    }
    
    /// How many minutes until a high value is reached?
    /// Returns nil if there is no predicted value that goes above the high value in 60 minutes.
    func minutesTo(high highValue: Float) -> Int?  {
        
        let nextHourReadings = nextHour
        guard !nextHourReadings.isEmpty else {
            return nil
        }
        
        if nextHourReadings[0].value >= highValue {
            
            // already high!
            return 0
        }

        
        let offsetMinutes = Int(Date().timeIntervalSince(nextHourReadings.first!.date) / 60)
        
        if let index = nextHourReadings.firstIndex(where: { $0.value > highValue }) {
            return (index + 1) - offsetMinutes
        }
        
        return nil
    }
    
    /// Updates the prediction cache.
    private func updatePrediction(readings: [BloodSugar]) {
        
        guard let currentReading = readings.last else {
         
            // no readings at all?!?
            reset()
            return
        }
        
        let predictionTrainingReadings = readings.predictionTrainingReadings
        if (self.regression == nil) || (predictionTrainingReadings != self.trainingReadings) {
            
            // new reading was detected, get new training sample
            guard let readings = predictionTrainingReadings else {
                
                // cannot create regression... not enough readings
                reset()
                return
            }
            
            print("Training regression from: \(readings)")
            
            let xValues = readings.map { Double(round($0.timestamp / 1000)) }
            let yValues = readings.map { Double($0.value) }

            self.regression = BestMatchRegression()
            self.regression!.train(x: xValues, y: yValues)
            
            // cache the training readings
            self.trainingReadings = predictionTrainingReadings
            
            // and the current reading
            trainingReferenceReading = currentReading
        }
        
        // get predictions for the next hour, for each minute
        let nextHour = (0...59).map { Date().addingTimeInterval(Double($0) * 60).timeIntervalSince1970 }
        let y = nextHour.map { self.regression!.predict(x: $0) }
        
//        print(y)
        
        // cache the prediction...
        prediction = (0..<nextHour.count).map { index in
            return BloodSugar(value: Float(round(y[index])), timestamp: nextHour[index] * 1000,
                              isMeteredBloodGlucoseValue: false)
        }
        
        print("Prediction update:")
        print(prediction)
    }
    
    private func reset() {
        prediction = []
        regression = nil
        trainingReferenceReading = nil
        trainingReadings = nil
    }
    
    private var regression: Regression?
    private var prediction: [BloodSugar] = []
    private var trainingReferenceReading: BloodSugar?
    private var trainingReadings: [BloodSugar]?

    private init() {
    }
}


fileprivate extension Array where Element: BloodSugar {
    
    // the last consecutive 2-3 values from the last 10-12 minutes are used for prediction
    var predictionTrainingReadings: [BloodSugar]? {

        guard let lastReadings = self.lastConsecutive(3, maxMissedReadings: 2) else {
            return nil
        }
        
        // NOTE: for the moment use the last consecutive 3 values (without time constraints)
        return lastReadings

//        let readingsFromLast12Minutes = lastReadings.suffix(3) { reading in
//            reading.date.addingTimeInterval(TimeInterval(12 * 60)) > Date()
//        }
//
//        return (readingsFromLast12Minutes.count >= 2) ? readingsFromLast12Minutes : nil
    }
    
}
