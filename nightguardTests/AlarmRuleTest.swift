//
//  AlarmRuleTest.swift
//  nightguardTests
//
//  Created by Codex on 10.04.26.
//

import XCTest
class AlarmRuleTest: XCTestCase {

    private let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)

    override func setUp() {
        super.setUp()
        clearAlarmSettings()
        AlarmRule.resetProtectedDataFallbackStateForTesting()
    }

    override func tearDown() {
        clearAlarmSettings()
        AlarmRule.resetProtectedDataFallbackStateForTesting()
        super.tearDown()
    }

    func testDetermineAlarmActivationByUsesCachedMinutesWhenProtectedDataUnavailable() {
        defaults?.set(true, forKey: AlarmRule.noDataAlarmEnabled.key)
        defaults?.set(45, forKey: AlarmRule.minutesWithoutValues.key)
        AlarmRule.initializeSyncValues()

        defaults?.removeObject(forKey: AlarmRule.noDataAlarmEnabled.key)
        defaults?.removeObject(forKey: AlarmRule.minutesWithoutValues.key)
        AlarmRule.protectedDataAvailabilityOverride = false

        let activation = AlarmRule.determineAlarmActivationBy(makeNightscoutData(minutesAgo: 35))

        XCTAssertNil(activation)
    }

    func testDetermineAlarmActivationByUsesCachedDisabledNoDataSettingWhenProtectedDataUnavailable() {
        defaults?.set(false, forKey: AlarmRule.noDataAlarmEnabled.key)
        defaults?.set(20, forKey: AlarmRule.minutesWithoutValues.key)
        AlarmRule.initializeSyncValues()

        defaults?.removeObject(forKey: AlarmRule.noDataAlarmEnabled.key)
        defaults?.removeObject(forKey: AlarmRule.minutesWithoutValues.key)
        AlarmRule.protectedDataAvailabilityOverride = false

        let activation = AlarmRule.determineAlarmActivationBy(makeNightscoutData(minutesAgo: 40))

        XCTAssertNil(activation)
    }

    func testDetermineAlarmActivationByFallsBackToDefaultsWithoutCache() {
        AlarmRule.protectedDataAvailabilityOverride = false

        let activation = AlarmRule.determineAlarmActivationBy(makeNightscoutData(minutesAgo: 35))

        XCTAssertEqual(activation?.kind, .missedReadings)
    }

    private func makeNightscoutData(minutesAgo: Int) -> NightscoutData {
        let data = NightscoutData()
        data.sgv = "120"
        data.time = NSNumber(value: Date().addingTimeInterval(TimeInterval(-minutesAgo * 60)).timeIntervalSince1970 * 1000)
        return data
    }

    private func clearAlarmSettings() {
        let keys = [
            AlarmRule.noDataAlarmEnabled.key,
            AlarmRule.minutesWithoutValues.key,
            AlarmRule.snoozedUntilTimestamp.key
        ]

        for key in keys {
            defaults?.removeObject(forKey: key)
        }
    }
}
