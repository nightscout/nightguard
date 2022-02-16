//
//  AppleHealthService.swift
//  nightguard
//
//  Created by Sebastian Deisel on 02.02.22.
//  Copyright © 2022 private. All rights reserved.
//

import Foundation
import HealthKit
import AVFoundation

class AppleHealthService: NSObject {

    static let singleton = AppleHealthService()

    let healthKitStore: HKHealthStore = HKHealthStore()
    
    let MAX_BACKFILL_COUNT: Int = 10000
    
    private func backFillAndSync(currentBgData: [BloodSugar]) -> Void {
        let earliest: Date = currentBgData.map { $0.date }.min()!
        let lastSyncDate: Date = UserDefaultsRepository.appleHealthLastSyncDate.value
        
        if (earliest <= lastSyncDate) {
            doSync(bgData: currentBgData)
        } else {
            NightscoutService.singleton.readChartDataWithinPeriodOfTime(oldValues: [], lastSyncDate, timestamp2: earliest) {[unowned self] (result: NightscoutRequestResult<[BloodSugar]>) in
                if case .data(let bgData) = result {
                    let filteredBgData: [BloodSugar] = bgData.filter{ bloodGlucose in bloodGlucose.date != earliest }
                    
                    if (filteredBgData.count == 0 || currentBgData.count >= MAX_BACKFILL_COUNT) {
                        doSync(bgData: currentBgData)
                    } else {
                        let filledBgData: [BloodSugar] = filteredBgData + currentBgData
                        backFillAndSync(currentBgData: filledBgData)
                    }
                }
            }
        }
    }

    private func doSync(bgData: [BloodSugar]) {
        guard !bgData.isEmpty else { return }

        let unit: HKUnit = getUnit()
        let lastSyncDate: Date = UserDefaultsRepository.appleHealthLastSyncDate.value

        let hkQuantitySamples: [HKQuantitySample] = bgData
            .filter{ bloodGlucose in bloodGlucose.date > lastSyncDate }
            .compactMap{ bloodGlucose in
                let date: Date = bloodGlucose.date
                let value: Double = Double(bloodGlucose.value)

                return HKQuantitySample(
                    type: getHkQuantityType(),
                    quantity: HKQuantity(unit: unit, doubleValue: value),
                    start: date,
                    end: date
                )
            }

        if (!hkQuantitySamples.isEmpty) {
            let mostRecent: Date = bgData.map{ $0.date }.max()!
            UserDefaultsRepository.appleHealthLastSyncDate.value = mostRecent

            healthKitStore.save(hkQuantitySamples) { (success, error) in
                if let error = error {
                    print("Error saving glucose sample: ", error)
                }
            }
        }
    }

    private func getHkQuantityType() -> HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!
    }
    
    private func getUnit() -> HKUnit {
        return UserDefaultsRepository.units.value == Units.mmol
            ? HKUnit.moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: HKUnit.liter())
            : HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.literUnit(with: .deci))
    }
    
    public func isAuthorized() -> Bool {
        return healthKitStore.authorizationStatus(for: getHkQuantityType()) == HKAuthorizationStatus.sharingAuthorized
    }

    public func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        healthKitStore.requestAuthorization(toShare: [getHkQuantityType()], read: nil, completion:  {[unowned self] (success, error) in
            sync()
        })
    }

    public func sync() {
        guard HKHealthStore.isHealthDataAvailable(),
              isAuthorized()
        else { return }
        
        let cachedBgData: [BloodSugar] = NightscoutDataRepository.singleton.loadTodaysBgData()

        if (!cachedBgData.isEmpty) {
            backFillAndSync(currentBgData: cachedBgData)
        }
    }
}
