//
//  StatisticsRepository.swift
//  nightguard
//
//  Created by Dirk Hermanns on 07.07.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation

struct StatisticsDayLoadingTracker {
    private(set) var loadingDays: Set<Int> = []
    private(set) var failedDays: Set<Int> = []

    mutating func beginLoading(_ day: Int) -> Bool {
        guard !failedDays.contains(day) else { return false }
        return loadingDays.insert(day).inserted
    }

    mutating func finishLoading(_ day: Int, succeeded: Bool) {
        loadingDays.remove(day)
        if succeeded {
            failedDays.remove(day)
        } else {
            failedDays.insert(day)
        }
    }

    mutating func allowRetry(_ day: Int) {
        failedDays.remove(day)
    }

    mutating func allowRetryForFailedDays() {
        failedDays.removeAll()
    }
}

class StatisticsRepository {
    
    static let singleton = StatisticsRepository()

    var lastSave : Date?
    
    var cachedDays : [[BloodSugar]?] = [nil, nil, nil, nil, nil, nil]
    
    
    // Reads the day starting with day 0 (current day).
    // If the day is not available or older than 30 Minutes, nil will be returned
    func readDay(_ nr : Int) -> [BloodSugar]? {
        
        if lastSave == nil || TimeService.isOlderThan30Minutes(lastSave ?? Date()) {
            return nil
        }
        
        if nr > cachedDays.count {
            return []
        }
        
        if cachedDays[nr] == nil {
            // no values have been read so far => signal with nil that they have to be read once more
            return nil
        }
        return cachedDays[nr]
    }
    
    
    func saveDay(_ nr : Int, bloodSugarArray : [BloodSugar]) {
        
        lastSave = TimeService.getToday()
        
        cachedDays[nr] = bloodSugarArray
    }

    static func normalizeForChart(
        _ bgValues: [BloodSugar],
        calendar: Calendar = .current
    ) -> [BloodSugar] {
        let normalizedBgValues = bgValues.compactMap { bgValue -> BloodSugar? in
            let time = Date(timeIntervalSince1970: bgValue.timestamp / 1000)
            var components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: time)
            components.setValue(1971, for: .year)
            components.setValue(1, for: .month)
            components.setValue(1, for: .day)

            guard let normalizedTime = calendar.date(from: components) else { return nil }
            return BloodSugar(
                value: bgValue.value,
                timestamp: normalizedTime.timeIntervalSince1970 * 1000,
                isMeteredBloodGlucoseValue: bgValue.isMeteredBloodGlucoseValue,
                arrow: bgValue.arrow
            )
        }

        return normalizedBgValues.sorted { $0.timestamp < $1.timestamp }
    }
}
