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

    private func doSync(bgData: [BloodSugar]) {
        guard !bgData.isEmpty else { return }

        let unit: HKUnit = HKUnit.init(from: UserDefaultsRepository.units.value.description)
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
            let mostRecent: BloodSugar = bgData.max(by: { $0.date < $1.date })!
            UserDefaultsRepository.appleHealthLastSyncDate.value = mostRecent.date

            healthKitStore.save(hkQuantitySamples) { (success, error) in
                if let error = error {
                    print("Error saving glucose sample")
                }
            }
        }
    }

    private func getHkQuantityType() -> HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!
    }

    public func requestAuthorization() {
        healthKitStore.requestAuthorization(toShare: [getHkQuantityType()], read: nil, completion:  { (success, error) in
            return
        })
    }

    public func isAuthorized() -> Bool {
        return healthKitStore.authorizationStatus(for: getHkQuantityType()) == HKAuthorizationStatus.sharingAuthorized
    }

    public func sync() {
        guard HKHealthStore.isHealthDataAvailable(),
              isAuthorized()
        else { return }

        _ = NightscoutCacheService.singleton.loadTodaysData { [unowned self] result in
            guard let result = result else { return }

            if case .data(let bgData) = result {
                doSync(bgData: bgData)
            }
        }
    }
}
