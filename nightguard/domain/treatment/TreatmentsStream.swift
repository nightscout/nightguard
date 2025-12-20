//
//  TreatmentsStream.swift
//  nightguard
//
//  Created by Dirk Hermanns on 14.02.21.
//  Copyright © 2021 private. All rights reserved.
//

import Foundation

// Contains all Nightscout Treatments of the last day.
class TreatmentsStream {
    
    static let singleton = TreatmentsStream()
    
    var treatments : [Treatment] = []
    // Map to be able to check in o(1) that a treatment is already contained in the treatments array
    var containedIds : [String:String] = [:]
    
    // checks all passed JSon-Treatments and adds new ones to the Stream
    // of treatments
    public func addNewJsonTreatments(jsonTreatments : [[String: Any]]) {
        
        // loop through all treatments and check whether we have new ones
        for jsonTreatment in jsonTreatments {
            
            if let eventType = jsonTreatment["eventType"] as? String {
                
                switch eventType {
                case "Carb Correction":
                    extractCarbCorrection(jsonTreatment)
                case "Meal Bolus":
                    extractMealBolus(jsonTreatment)
                case "Correction Bolus":
                    extractCorrectionBolus(jsonTreatment)
                case "Bolus Wizard":
                    extractBolusWizard(jsonTreatment)
                default:
                    // ignore all the rest
                    continue
                }
            }
        }
        
        removeTreatmentsFromLastDay()
    }
    
    fileprivate func removeTreatmentsFromLastDay() {
        
        let startOfTime = TimeService.getStartOfCurrentDay()
        
        var treatmentsToKeep : [Treatment] = []
        for treatment in treatments {
            if treatment.timestamp >= startOfTime {
                treatmentsToKeep.append(treatment)
            }
        }
        
        treatments = treatmentsToKeep
    }
    
    fileprivate func extractCarbCorrection(_ jsonTreatment: [String : Any]) {
        
        if let id = jsonTreatment["_id"] as? String {
            if isNew(id: id) {
                if let date = jsonTreatment["mills"] as? Double {
                    let carbs = jsonTreatment["carbs"] as? Int ?? 0
                    
                    addTreatment(
                        treatment:
                            CarbCorrectionTreatment.init(id: id, timestamp: date, carbs: carbs))
                }
            }
        }
    }
    fileprivate func extractMealBolus(_ jsonTreatment: [String : Any]) {
        
        if let id = jsonTreatment["_id"] as? String {
            if isNew(id: id) {
                if let createdAt = jsonTreatment["created_at"] as? String {
                    let carbs = jsonTreatment["carbs"] as? Int ?? 0
                    let insulin = jsonTreatment["insulin"] as? Double ?? 0.0
                    
                    addTreatment(
                        treatment:
                            MealBolusTreatment.init(id: id, timestamp: Double.fromIsoString(isoTime: createdAt), carbs: carbs, insulin: insulin))
                }
            }
        }
    }
    
    fileprivate func extractCorrectionBolus(_ jsonTreatment: [String : Any]) {
        
        if let id = jsonTreatment["_id"] as? String {
            if isNew(id: id) {
                if let createdAt = jsonTreatment["created_at"] as? String {
                    let insulin = jsonTreatment["insulin"] as? Double ?? 0.0
                    
                    addTreatment(
                        treatment:
                            CorrectionBolusTreatment.init(id: id, timestamp: Double.fromIsoString(isoTime: createdAt), insulin: insulin))
                }
            }
        }
    }
    
    fileprivate func extractBolusWizard(_ jsonTreatment: [String : Any]) {
        
        if let id = jsonTreatment["_id"] as? String {
            if isNew(id: id) {
                if let createdAt = jsonTreatment["created_at"] as? String {
                    let insulin = jsonTreatment["insulin"] as? Double ?? 0.0
                    
                    addTreatment(
                        treatment:
                            BolusWizardTreatment.init(id: id, timestamp: Double.fromIsoString(isoTime: createdAt), insulin: insulin))
                }
            }
        }
    }
    
    // checks whether the stream already has a treatment with 'id'
    private func isNew(id : String) -> Bool {
        return containedIds[id] == nil;
    }
    
    // appends the treatment and remembers the id.
    private func addTreatment(treatment : Treatment) {
        containedIds[treatment.id] = treatment.id
        treatments.append(treatment)
    }
}
