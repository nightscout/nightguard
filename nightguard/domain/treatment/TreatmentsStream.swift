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
    
    private(set) var treatments: [Treatment] = []
    // Map to be able to find and update a treatment in O(1).
    private var treatmentIndicesById: [String: Int] = [:]

    /// Restores persisted treatments and rebuilds the lookup index used for
    /// deduplication. Without rebuilding the index, the first server refresh
    /// after an app restart would append every persisted treatment again.
    func restoreTreatments(_ persistedTreatments: [Treatment]) {
        let startOfCurrentDay = TimeService.getStartOfCurrentDay()
        var restoredById: [String: Treatment] = [:]

        for treatment in persistedTreatments where treatment.timestamp >= startOfCurrentDay {
            restoredById[treatment.id] = treatment
        }

        treatments = restoredById.values.sorted { $0.timestamp < $1.timestamp }
        rebuildTreatmentIndex()
    }

    /// Clears the locally cached treatments so the next refresh can rebuild
    /// today's list from Nightscout.
    func resetForReload() {
        treatments.removeAll()
        treatmentIndicesById.removeAll()
    }
    
    // checks all passed JSon-Treatments and adds new ones to the Stream
    // of treatments
    @discardableResult
    public func addNewJsonTreatments(jsonTreatments: [[String: Any]]) -> Bool {
        let startOfCurrentDay = TimeService.getStartOfCurrentDay()
        var changed = removeTreatmentsBefore(startOfCurrentDay)

        // loop through all treatments and check whether we have new ones
        for jsonTreatment in jsonTreatments {
            // The API query is restricted to today's records as well. Keep
            // this client-side guard so a legacy fallback or a Nightscout
            // instance that ignores a filter cannot reintroduce old values.
            guard let timestamp = treatmentTimestamp(jsonTreatment),
                  timestamp >= startOfCurrentDay else {
                continue
            }

            guard let treatment = treatment(from: jsonTreatment, timestamp: timestamp) else {
                continue
            }

            changed = merge(treatment) || changed
        }

        if changed {
            treatments.sort { $0.timestamp < $1.timestamp }
            rebuildTreatmentIndex()
        }

        return changed
    }

    private func removeTreatmentsBefore(_ timestamp: Double) -> Bool {
        let treatmentsToKeep = treatments.filter { $0.timestamp >= timestamp }
        guard treatmentsToKeep.count != treatments.count else { return false }

        treatments = treatmentsToKeep
        rebuildTreatmentIndex()
        return true
    }

    private func treatment(from jsonTreatment: [String: Any], timestamp: Double) -> Treatment? {
        guard let id = treatmentIdentifier(jsonTreatment),
              let eventType = jsonTreatment["eventType"] as? String else {
            return nil
        }

        let carbs = integerValue(jsonTreatment["carbs"]) ?? 0
        let insulin = doubleValue(jsonTreatment["insulin"]) ?? 0

        switch eventType {
        case "Carb Correction":
            return CarbCorrectionTreatment(id: id, timestamp: timestamp, carbs: carbs)
        case "Meal Bolus":
            return MealBolusTreatment(id: id, timestamp: timestamp, carbs: carbs, insulin: insulin)
        case "Correction Bolus":
            return CorrectionBolusTreatment(id: id, timestamp: timestamp, insulin: insulin)
        case "Bolus Wizard":
            return BolusWizardTreatment(id: id, timestamp: timestamp, insulin: insulin)
        default:
            return nil
        }
    }

    private func treatmentIdentifier(_ treatment: [String: Any]) -> String? {
        return treatment["identifier"] as? String ?? treatment["_id"] as? String
    }

    private func treatmentTimestamp(_ treatment: [String: Any]) -> Double? {
        if let number = treatment["mills"] as? NSNumber { return number.doubleValue }
        if let number = treatment["date"] as? NSNumber { return number.doubleValue }
        if let string = treatment["mills"] as? String, let timestamp = Double(string) { return timestamp }
        if let string = treatment["date"] as? String, let timestamp = Double(string) { return timestamp }
        if let createdAt = treatment["created_at"] as? String { return Double.fromIsoString(isoTime: createdAt) }
        return nil
    }

    private func integerValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private func merge(_ treatment: Treatment) -> Bool {
        guard let existingIndex = treatmentIndicesById[treatment.id] else {
            treatmentIndicesById[treatment.id] = treatments.count
            treatments.append(treatment)
            return true
        }

        guard !hasSameChartContent(treatments[existingIndex], treatment) else {
            return false
        }

        treatments[existingIndex] = treatment
        return true
    }

    private func hasSameChartContent(_ lhs: Treatment, _ rhs: Treatment) -> Bool {
        guard type(of: lhs) == type(of: rhs), lhs.timestamp == rhs.timestamp else {
            return false
        }

        switch (lhs, rhs) {
        case let (left as MealBolusTreatment, right as MealBolusTreatment):
            return left.carbs == right.carbs && left.insulin == right.insulin
        case let (left as CorrectionBolusTreatment, right as CorrectionBolusTreatment):
            return left.insulin == right.insulin
        case let (left as BolusWizardTreatment, right as BolusWizardTreatment):
            return left.insulin == right.insulin
        case let (left as CarbCorrectionTreatment, right as CarbCorrectionTreatment):
            return left.carbs == right.carbs
        default:
            return true
        }
    }

    private func rebuildTreatmentIndex() {
        treatmentIndicesById = Dictionary(
            uniqueKeysWithValues: treatments.enumerated().map { ($0.element.id, $0.offset) }
        )
    }
}
