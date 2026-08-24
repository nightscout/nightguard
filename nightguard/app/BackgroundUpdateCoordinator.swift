//
//  BackgroundUpdateCoordinator.swift
//  nightguard
//

import Foundation
import UIKit
#if canImport(WidgetKit)
import WidgetKit
#endif

enum BackgroundUpdateTrigger: String {
    case bgTask = "BGTask"
    case silentPush = "SilentPush"
}

struct BackgroundUpdateResult {
    let success: Bool
    let hasNewData: Bool
    let message: String
}

final class BackgroundUpdateCoordinator {
    static let shared = BackgroundUpdateCoordinator()

    private let completionLock = NSLock()
    private var isRunning = false

    private init() {}

    func run(trigger: BackgroundUpdateTrigger, completion: @escaping (BackgroundUpdateResult) -> Void) {
        completionLock.lock()
        guard !isRunning else {
            completionLock.unlock()
            completion(BackgroundUpdateResult(success: true, hasNewData: false, message: "Background update already running"))
            return
        }
        isRunning = true
        completionLock.unlock()

        AppLogger.singleton.debug("\(trigger.rawValue) background update started", category: .backgroundUpdates)

        let previousData = NightscoutDataRepository.singleton.loadCurrentNightscoutData()
        let previousTimestamp = previousData.time.doubleValue
        let _ = NightscoutService.singleton.readLatestEntriesHybrid { [weak self] result in
            guard let self = self else { return }

            func finish(_ result: BackgroundUpdateResult) {
                self.completionLock.lock()
                self.isRunning = false
                self.completionLock.unlock()
                AppLogger.singleton.debug(
                    "\(trigger.rawValue) background update finished success=\(result.success), hasNewData=\(result.hasNewData), message=\(result.message)",
                    category: .backgroundUpdates
                )
                completion(result)
            }

            switch result {
            case .error(let error):
                AppLogger.singleton.error("\(trigger.rawValue) background update failed: \(error)", category: .backgroundUpdates)
                finish(BackgroundUpdateResult(success: false, hasNewData: false, message: "Nightscout error"))
            case .data(let records):
                NightscoutService.singleton.makeCurrentData(from: records, enrichWithProperties: false) { currentResult in
                    switch currentResult {
                    case .error(let error):
                        AppLogger.singleton.error("\(trigger.rawValue) could not derive current glucose: \(error)", category: .backgroundUpdates)
                        finish(BackgroundUpdateResult(success: false, hasNewData: false, message: "No current glucose"))
                    case .data(let nightscoutData):
                        nightscoutData.battery = previousData.battery
                        nightscoutData.iob = previousData.iob
                        nightscoutData.cob = previousData.cob
                        nightscoutData.reservoirUnits = previousData.reservoirUnits
                        let fetchedHistory = records.compactMap(\.bloodSugar)
                        let storedHistory = NightscoutDataRepository.singleton.loadTodaysBgData()
                        let historyValues = self.mergeHistory(storedHistory + fetchedHistory, including: nightscoutData)

                        NightscoutCacheService.singleton.updateCurrentNightscoutData(newNightscoutData: nightscoutData)
                        NightscoutDataRepository.singleton.storeTodaysBgData(historyValues)
                        let snapshot = NightscoutDataRepository.singleton.storeLatestDisplaySnapshot(
                            from: nightscoutData,
                            previousValues: historyValues
                        )
                        let hasNewData = nightscoutData.time.doubleValue > previousTimestamp

                        AppLogger.singleton.info(
                            "\(trigger.rawValue) published display state: SGV=\(nightscoutData.sgv), timestamp=\(nightscoutData.time), history=\(historyValues.count), hasNewData=\(hasNewData)",
                            category: .backgroundUpdates
                        )

                        // Publish the critical display state before optional
                        // background work can consume the remaining budget.
                        AlarmNotificationService.singleton.notifyIfAlarmActivated(nightscoutData)
                        self.reloadWidgetTimelines(trigger: trigger)
                        WatchService.singleton.sendToWatchCurrentNightwatchData(
                            nightscoutData: nightscoutData,
                            displaySnapshot: snapshot
                        )

                        _ = NightscoutSyncCoordinator.shared.refreshTreatments { treatments in
                            TreatmentsStream.singleton.addNewJsonTreatments(jsonTreatments: treatments)
                        }

                        Task {
                            if #available(iOS 16.1, *) {
                                let updateResult = await LiveActivityManager.shared.refreshActivitiesForBackgroundUpdate(with: nightscoutData)
                                let logMessage = "\(trigger.rawValue) Live Activity refresh result: activities=\(updateResult.activityCount), endedExpired=\(updateResult.endedExpiredActivityCount), updated=\(updateResult.updatedActivityCount), started=\(updateResult.startedActivityCount), message=\(updateResult.message)"
                                if updateResult.didChangeAnyActivity {
                                    AppLogger.singleton.info(logMessage, category: .backgroundUpdates)
                                } else {
                                    AppLogger.singleton.warning(logMessage, category: .backgroundUpdates)
                                }
                            }

                            let deviceStatusData: DeviceStatusData = await withCheckedContinuation { continuation in
                                let _ = NightscoutCacheService.singleton.getDeviceStatusData { deviceStatusData in
                                    continuation.resume(returning: deviceStatusData)
                                }
                            }
                            AlarmNotificationService.singleton.notifyIfReservoirCritical(deviceStatusData.reservoirUnits)
                            finish(BackgroundUpdateResult(success: true, hasNewData: hasNewData, message: "Nightscout display state processed"))
                        }
                    }
                }
            }
        }
    }

    private func mergeHistory(_ values: [BloodSugar], including currentData: NightscoutData) -> [BloodSugar] {
        var valuesByKey: [String: BloodSugar] = [:]
        let withCurrent = NightguardDisplaySnapshot.historyValues(values, including: currentData)
        for value in withCurrent where value.isValid && value.timestamp > 0 {
            let type = value.isMeteredBloodGlucoseValue ? "mbg" : "sgv"
            valuesByKey["\(type):\(String(format: "%.0f", value.timestamp))"] = value
        }
        let sorted = valuesByKey.values.sorted { $0.timestamp < $1.timestamp }
        return NightscoutCacheService.singleton.removeYesterdaysEntries(bgValues: sorted)
    }

    private func reloadWidgetTimelines(trigger: BackgroundUpdateTrigger) {
        #if canImport(WidgetKit)
        if #available(iOS 14.0, *) {
            let widgetKinds = [
                "org.duckdns.dhe.nightguard.NightguardDefaultWidgets",
                "org.duckdns.dhe.nightguard.NightguardTimestampWidgets",
                "org.duckdns.dhe.nightguard.NightguardGaugeWidgets"
            ]

            for widgetKind in widgetKinds {
                WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
                AppLogger.singleton.debug("\(trigger.rawValue) requested widget timeline reload: \(widgetKind)", category: .backgroundUpdates)
            }
        }
        #endif
    }
}
