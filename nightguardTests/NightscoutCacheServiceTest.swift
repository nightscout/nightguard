//
//  NightscoutCacheServiceTest.swift
//  nightguardTests
//

import Foundation
import XCTest

final class NightscoutCacheServiceTest: XCTestCase {

    override func tearDown() {
        NightscoutCacheService.singleton.updateTodaysBgDataForTesting([])

        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        [
            AlarmRule.areAlertsGenerallyDisabled.key,
            AlarmRule.noDataAlarmEnabled.key,
            AlarmRule.minutesWithoutValues.key,
            AlarmRule.isEdgeDetectionAlarmEnabled.key,
            AlarmRule.isLowPredictionEnabled.key,
            AlarmRule.isSmartSnoozeEnabled.key,
            UserDefaultsRepository.upperBound.key,
            UserDefaultsRepository.lowerBound.key
        ].forEach { defaults?.removeObject(forKey: $0) }

        super.tearDown()
    }

    func testRemoveYesterdaysEntriesKeepsTheLastHourAcrossMidnight() {
        let currentDate = makeDate(year: 2026, month: 8, day: 21, hour: 0, minute: 5)
        let calendar = Calendar.current
        let startOfCurrentDay = calendar.startOfDay(for: currentDate)

        let readings = [
            reading(value: 100, date: startOfCurrentDay.addingTimeInterval(-61 * 60)),
            reading(value: 110, date: startOfCurrentDay.addingTimeInterval(-60 * 60)),
            reading(value: 120, date: startOfCurrentDay.addingTimeInterval(-5 * 60)),
            reading(value: 130, date: startOfCurrentDay.addingTimeInterval(5 * 60))
        ]

        let retainedReadings = NightscoutCacheService.singleton.removeYesterdaysEntries(
            bgValues: readings,
            currentDate: currentDate
        )

        XCTAssertEqual(retainedReadings.map(\.value), [110, 120, 130])
    }

    func testAlarmEvaluationUsesRecentlyRetainedReading() {
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults?.set(false, forKey: AlarmRule.areAlertsGenerallyDisabled.key)
        defaults?.set(true, forKey: AlarmRule.noDataAlarmEnabled.key)
        defaults?.set(30, forKey: AlarmRule.minutesWithoutValues.key)
        defaults?.set(false, forKey: AlarmRule.isEdgeDetectionAlarmEnabled.key)
        defaults?.set(false, forKey: AlarmRule.isLowPredictionEnabled.key)
        defaults?.set(false, forKey: AlarmRule.isSmartSnoozeEnabled.key)
        defaults?.set(Float(200), forKey: UserDefaultsRepository.upperBound.key)
        defaults?.set(Float(80), forKey: UserDefaultsRepository.lowerBound.key)

        let recentReading = reading(value: 120, date: Date().addingTimeInterval(-5 * 60))
        let currentData = NightscoutData()
        currentData.sgv = "120"
        currentData.time = NSNumber(value: recentReading.timestamp)
        NightscoutCacheService.singleton.updateCurrentNightscoutData(newNightscoutData: currentData)
        NightscoutCacheService.singleton.updateTodaysBgDataForTesting([recentReading])

        let activation = AlarmRule.getAlarmActivation(ignoreSnooze: true)

        XCTAssertNil(activation)
    }

    private func reading(value: Float, date: Date) -> BloodSugar {
        BloodSugar(
            value: value,
            timestamp: date.timeIntervalSince1970 * 1000,
            isMeteredBloodGlucoseValue: false,
            arrow: "-"
        )
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(
            calendar: calendar,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
