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

    /// Clears the locally cached treatments so the next refresh can rebuild
    /// today's list from Nightscout.
    func resetForReload() {
        treatments.removeAll()
        containedIds.removeAll()
    }
    
    // checks all passed JSon-Treatments and adds new ones to the Stream
    // of treatments
    public func addNewJsonTreatments(jsonTreatments : [[String: Any]]) {
        let startOfCurrentDay = TimeService.getStartOfCurrentDay()
        
        // loop through all treatments and check whether we have new ones
        for jsonTreatment in jsonTreatments {
            // The API query is restricted to today's records as well. Keep
            // this client-side guard so a legacy fallback or a Nightscout
            // instance that ignores a filter cannot reintroduce old values.
            guard let timestamp = treatmentTimestamp(jsonTreatment),
                  timestamp >= startOfCurrentDay else {
                continue
            }
            
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
        var removedTreatmentIDs: [String] = []
        for treatment in treatments {
            if treatment.timestamp >= startOfTime {
                treatmentsToKeep.append(treatment)
            } else {
                removedTreatmentIDs.append(treatment.id)
            }
        }
        
        treatments = treatmentsToKeep
        removedTreatmentIDs.forEach { containedIds.removeValue(forKey: $0) }
    }
    
    fileprivate func extractCarbCorrection(_ jsonTreatment: [String : Any]) {
        if let id = treatmentIdentifier(jsonTreatment) {
            if isNew(id: id) {
                if let date = treatmentTimestamp(jsonTreatment) {
                    let carbs = jsonTreatment["carbs"] as? Int ?? 0
                    
                    addTreatment(
                        treatment:
                            CarbCorrectionTreatment.init(id: id, timestamp: date, carbs: carbs))
                }
            }
        }
    }
    fileprivate func extractMealBolus(_ jsonTreatment: [String : Any]) {
        if let id = treatmentIdentifier(jsonTreatment) {
            if isNew(id: id) {
                if let timestamp = treatmentTimestamp(jsonTreatment) {
                    let carbs = jsonTreatment["carbs"] as? Int ?? 0
                    let insulin = jsonTreatment["insulin"] as? Double ?? 0.0
                    
                    addTreatment(
                        treatment:
                            MealBolusTreatment.init(id: id, timestamp: timestamp, carbs: carbs, insulin: insulin))
                }
            }
        }
    }
    
    fileprivate func extractCorrectionBolus(_ jsonTreatment: [String : Any]) {
        if let id = treatmentIdentifier(jsonTreatment) {
            if isNew(id: id) {
                if let timestamp = treatmentTimestamp(jsonTreatment) {
                    let insulin = jsonTreatment["insulin"] as? Double ?? 0.0
                    
                    addTreatment(
                        treatment:
                            CorrectionBolusTreatment.init(id: id, timestamp: timestamp, insulin: insulin))
                }
            }
        }
    }
    
    fileprivate func extractBolusWizard(_ jsonTreatment: [String : Any]) {
        if let id = treatmentIdentifier(jsonTreatment) {
            if isNew(id: id) {
                if let timestamp = treatmentTimestamp(jsonTreatment) {
                    let insulin = jsonTreatment["insulin"] as? Double ?? 0.0
                    
                    addTreatment(
                        treatment:
                            BolusWizardTreatment.init(id: id, timestamp: timestamp, insulin: insulin))
                }
            }
        }
    }

    private func treatmentIdentifier(_ treatment: [String: Any]) -> String? {
        return treatment["identifier"] as? String ?? treatment["_id"] as? String
    }

    private func treatmentTimestamp(_ treatment: [String: Any]) -> Double? {
        if let number = treatment["mills"] as? NSNumber { return number.doubleValue }
        if let number = treatment["date"] as? NSNumber { return number.doubleValue }
        if let createdAt = treatment["created_at"] as? String { return Double.fromIsoString(isoTime: createdAt) }
        return nil
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
